{
  defaults = { lib, ... }:
  {
    ## https://github.com/NixOS/nixops/issues/1216
    # deployment.targetEnv = "libvirtd";
    # deployment.libvirtd = {
    #   headless = true;
    #   memorySize = 2048;
    #   vcpu = 2;
    # };

    # # Serial console over `virsh`
    # boot.kernelParams = [ "console=ttyS0,115200" ];
    # deployment.libvirtd.extraDevicesXML = ''
    #   <serial type='pty'>
    #     <target port='0'/>
    #   </serial>
    #   <console type='pty'>
    #     <target type='serial' port='0'/>
    #   </console>
    # '';

    deployment.targetEnv = "virtualbox";
    deployment.virtualbox = {
      memorySize = 2048;
      vcpu = 2;
      headless = true;
    };
  };

  staging = { imports = [ (import <stakerdao-infra/profiles/nodes.nix> {}).staging ]; };
  production = { imports = [ (import <stakerdao-infra/profiles/nodes.nix> {}).production ]; };
}
