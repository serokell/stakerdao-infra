#! /usr/bin/env bash
set -euo pipefail
ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )/.."

TARGET_USER=buildkite
SSHOPTS=(-o 'StrictHostKeyChecking=no' -o 'UserKnownHostsFile=/dev/null')
export NIX_SSHOPTS="${SSHOPTS[*]}"

# For first deployment to bare server
if [[ ${1:-} == '--prime' ]]; then
  shift

  BARE_SERVER=1
  TARGET_USER=root
  LOCAL_KEY="$(readlink -f "$ROOT/nix.key")"

  if [[ ! -r $LOCAL_KEY ]]; then
    echo "Couldn't find nix.key in project root. Required to locally sign closures. Aborting."
    exit 1
  fi
fi

if [[ -z ${1:-} ]]; then
  echo 'Specify deployment environment: staging, production.'
  exit 1
fi

TARGET_MACHINE="$1"

if [[ -z ${2:-} ]]; then
  echo 'Specify deployment closure type: system, service.'
  exit 1
fi

# If AGORA_REF is set, we were triggered from Agora CI
if [[ -z ${AGORA_REF:-} ]]; then
  DEPLOY_TYPE="$2"
else
  DEPLOY_TYPE=service
fi

##
# Push the closure to the server using `nix copy`. Sign closure first if
# deploying from workstation.
function push_closure() {
  if [[ -z ${1:-} ]]; then
    echo 'Missing target host.'
    echo 'Usage: push_closure <target_host> <closure store path>.'
    exit 1
  fi

  if [[ ! -d ${2:-} ]]; then
    echo 'Missing or invalid closure store path'
    echo 'Usage: push_closure <target_host> <closure store path>'
    exit 1
  fi

  ##
  # First deployment is done from local workstation, sign keys explicitly.
  if [[ -n ${LOCAL_KEY:-} ]]; then
    nix sign-paths -r -k "$LOCAL_KEY" "$2"
  fi

  nix copy --substitute-on-destination --to "ssh://$TARGET_USER@$1" "$2"
}

##
# Activate system closure remotely by running its `switch-to-configuration`.
# If deploying to a bare server, activate directly instead of calling sudo input-validation script.
function activate_system() {
  if [[ -z ${1:-} ]]; then
    echo 'Missing target host.'
    echo 'Usage: activate_system <target_host> <closure store path>'
    exit 1
  fi

  if [[ ! -d ${2:-} ]]; then
    echo 'Missing or invalid closure store path'
    echo 'Usage: activate_system <target_host> <closure store path>'
    exit 1
  fi

  # shellcheck disable=SC2029
  if [[ -z ${BARE_SERVER:-} ]]; then
    ssh "${SSHOPTS[@]}" "$TARGET_USER@$1" "sudo system-activate $2"
  else
    ssh "${SSHOPTS[@]}" "$TARGET_USER@$1" "$2/bin/switch-to-configuration switch"
  fi
}

##
# Activate service closure remotely by switching the `agora` profile to it, then running its `activate` script
# If deploying to a bare server, activate directly instead of calling sudo input-validation script.
function activate_service() {
  if [[ -z ${1:-} ]]; then
    echo 'Missing target host.'
    echo 'Usage: activate_service <target_host> <environment path>'
    exit 1
  fi

  if [[ -z ${2:-} ]]; then
    echo 'Missing profile environment store path.'
    echo 'Usage: activate_service <target_host> <environment path>'
    exit 1
  fi

  local profile='/nix/var/nix/profiles/agora'

  # shellcheck disable=SC2029
  if [[ -z ${BARE_SERVER:-} ]]; then
    ssh "${SSHOPTS[@]}" "$TARGET_USER@$1" "sudo service-activate $profile $2"
  else
    ssh "${SSHOPTS[@]}" "$TARGET_USER@$1" "nix-env --profile $profile --set $2 && systemctl restart agora"
  fi
}

##
# Prepare agora repository in `agora` folder. If not in CI, symlink sibling path.
function prepare_service_repo() {
  if [[ -z ${1:-} ]]; then
    echo 'Missing ref.'
    echo 'Usage: prepare_service_repo <git ref>'
    exit 1
  fi

  local ref

  rm -rf "$ROOT/agora"

  # Volkswagen to make it work on my computer
  if [[ -z ${BUILDKITE:-} ]]; then
    ref=HEAD
    ln -s ../stakerdao-agora "$ROOT/agora"
  else
    ref="$1"
    git clone git@github.com:serokell/stakerdao-agora.git "$ROOT/agora"
    pushd "$ROOT/agora" || exit 1
      git clean -fdx
      git checkout "$ref"
    popd || exit 1
  fi
}

case "$TARGET_MACHINE" in
  staging)
    # FIXME: Update to DNS name after switching
    TARGET='3.9.146.241'

    # FIXME: Point at staging branch after PR merge
    REF='staging'

    NODE=staging
    ;;
  production)
    # FIXME: Update to DNS name after switching
    TARGET='35.177.67.81'

    # FIXME: Point at staging branch after PR merge
    REF='production'

    NODE=production
    ;;
  *)
    echo 'Invalid deployment target, specify one of: production, staging.'
    exit 1
esac

case "$DEPLOY_TYPE" in
  service)
    prepare_service_repo "${AGORA_REF:-$REF}"
    pushd "$ROOT/agora" || exit 1
    SERVICE="$(nix-build --no-out-link -A deploy)"
    popd || exit 1
    push_closure "$TARGET" "$SERVICE"
    activate_service "$TARGET" "$SERVICE"
    ;;

  system)
    prepare_service_repo "${AGORA_REF:-$REF}"
    pushd "$ROOT/agora" || exit 1
    SERVICE="$(nix-build --no-out-link -A deploy)"
    popd || exit 1
    SYSTEM="$(nix-build --no-out-link "$ROOT/default.nix" -A "$NODE")"

    push_closure "$TARGET" "$SYSTEM"
    push_closure "$TARGET" "$SERVICE"

    activate_system "$TARGET" "$SYSTEM"
    activate_service "$TARGET" "$SERVICE"
    ;;

  *)
    echo 'Invalid closure type, specify one of: system, service.'
    exit 1
    ;;
esac

echo 'Done.'
