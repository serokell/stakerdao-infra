use duct::cmd;
use clap::Clap;
use std::str::FromStr;
use std::path::PathBuf;
use std::rc::Rc;
use std::assert;
use mktemp::Temp;

#[derive(Clone)]
#[derive(Clap)]
#[clap(version = "0.1.0", author = "Serokell")]
struct Opts {
    #[clap(short = "p", long = "prime")]
    prime: bool,
    #[clap(short = "r", long = "repo", default_value = "ssh://git@github.com/serokell/stakerdao-agora")]
    repo: String,
    #[clap(long = "ref", default_value = "mkaito/sdao89-profile-env")]
    reference: String,
    #[clap(long = "ip")]
    ip: Option<String>,
    #[clap(short = "k", long = "key")]
    key: Option<String>,
    node: String,
    deployment: String,
}

fn nix_copy(dest: &String, path: &String) {
    cmd!("nix", "copy", "--substitute-on-destination", "--to", dest, path).run().unwrap();
}

fn nix_sign(key: &String, path: &String) {
    cmd!("nix", "sign-paths", "-r", "-k", key, path).run().unwrap();
}

fn ssh(target_user: &String, host: &String, command: &String) {
    cmd!("ssh", format!("{}@{}", target_user, host), command).run().unwrap();
}

fn nix_build(dir: String, attr: Option<&String>) -> Result<PathBuf, std::io::Error> {
    let stdout = if let Some(a) = attr {
        cmd!("nix-build", "--no-out-link", dir, "-A", a).read()?
    } else {
        cmd!("nix-build", "--no-out-link", dir).read()?
    };

    Ok(PathBuf::from_str(stdout.as_str()).unwrap())
}

struct Target {
    ip: String,
    node: String,
    target_user: String
}

impl From<Opts> for Target {
    fn from(opts: Opts) -> Target {
        let target_user = if opts.prime { "root" } else { "buildkite" };
        match opts.node.as_str() {
            "s" | "staging" => Target {
                ip: opts.ip.unwrap_or("3.9.146.241".to_string()),
                node: "staging".to_string(),
                target_user: target_user.to_string()
            },
            "p" | "production" => Target {
                ip: opts.ip.unwrap_or("35.177.67.81".to_string()),
                node: "production".to_string(),
                target_user: target_user.to_string()
            },
            _ => panic!("Choose one of staging/s, production/p")
        }
    }
}

impl Target {
    fn push(&self, path: &String, key: &Option<String>) {
        if let Some(k) = key {
            nix_sign(k, path)
        };
        nix_copy(&format!("ssh://{}@{}", self.target_user, self.ip), path);
    }
}

struct Repository { path: String }

impl From<Opts> for Repository {
    fn from(opts: Opts) -> Repository {
        Repository {
            path: cmd!("nix", "eval", "--raw",
                       format!("(builtins.fetchGit {{ url = ''{}''; ref = ''{}''; }})",
                               opts.repo, opts.reference)).read().unwrap()
        }
    }
}

impl std::fmt::Display for Repository {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{}", self.path)
    }
}


#[derive(Clone)]
enum Deployment {
    System,
    Service(String)
}

impl From<Opts> for Deployment {
    fn from(opts: Opts) -> Deployment {
        if opts.deployment == "system" {
            Deployment::System
        } else {
            Deployment::Service(opts.deployment.to_string())
        }
    }
}

impl Deployment {
    fn activate_command(self, path: &String, prime: bool) -> String {
        match self {
            Deployment::System => if prime {
                format!("sudo system-activate {}", path)
            } else {
                format!("{}/bin/switch-to-configuration switch", path)
            },
            Deployment::Service(s) => if prime {
                format!("sudo service-activate /nix/var/nix/profiles/{0} {1}", s, path)

            } else {
                format!("nix-env --profile /nix/var/nix/profiles/{0} --set {1} && systemctl restart {0}", s, path)
            }
        }
    }
    fn build(self, repo: &Repository, target: &Target) -> Result<PathBuf, std::io::Error> {
        let Repository { path } = repo;
        match self {
            Deployment::System => nix_build(path.to_string(), Some(&target.node)),
            Deployment::Service(_s) => nix_build(path.to_string(), Some(&"deploy".to_string()))
        }
    }
    fn activate(&self, path: &String, target: &Target, prime: bool) {
        ssh(&target.target_user, &target.ip, &self.clone().activate_command(path, prime));
    }
    fn deploy(&self, repo: Repository, target: &Target, key: &Option<String>, prime: bool) {
        let path = self.clone().build(&repo, target).unwrap();
        let ps = path.to_str().unwrap().to_string();
        target.push(&ps, key);
        self.activate(&ps, &target, prime);
        if let Deployment::System = self {
            Deployment::Service("agora".to_string()).deploy(repo, &target, key, prime)
        }
    }

}

fn main() {
    let opts: Opts = Opts::parse();

    if opts.prime {
        assert!(opts.key != None, "When doing a deployment for the first time, you must specify a key");
    }

    let target = Target::from(opts.clone());

    let repo = Repository::from(opts.clone());

    let deployment = Deployment::from(opts.clone());

    deployment.deploy(repo, &target, &opts.key, opts.prime);
}
