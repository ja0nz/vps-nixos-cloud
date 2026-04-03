/**
  Module: microvm-configuration.nix
  Description: Configure a development microvm for rapid testing
*/
{
  config,
  lib,
  vars,
  ...
}:

{
  # Disable login prompt / SSH only
  systemd.services."serial-getty@ttyS0".enable = false;

  # Mount SSH keys early on
  fileSystems."/etc/ssh/mnt".neededForBoot = true;

  microvm = {
    mem = 4096;
    vcpu = 4;
    hypervisor = "qemu";
    socket = "control.socket";
    vsock.cid = vars.SSH_PORT_LOCAL; # Has to be unique anyway
    volumes = [
      {
        mountPoint = "/var/tmp";
        image = "./.var-tmp-dev.img";
        size = 2000; # 2GB
      }
    ];
    shares = [
      {
        proto = "9p";
        tag = "ro-store";
        source = "/nix/store";
        mountPoint = "/nix/.ro-store";
        readOnly = true;
      }
      {
        proto = "9p";
        tag = "dev-host-key";
        source = ".dev-host-key";
        mountPoint = "/etc/ssh/mnt";
      }
    ];

    interfaces = [
      {
        type = "user";
        id = "vm-eth0";
        mac = "02:00:00:00:00:01";
      }
    ];
    forwardPorts = [
      {
        from = "host";
        host.port = vars.SSH_PORT_LOCAL;
        guest.port = 22;
      }
    ];

  };

  # [22.01.2026] Fix: fix for hanging endless in shutdown sequence
  # See:
  # https://github.com/microvm-nix/microvm.nix/commit/736d43ae8552653ea8ad51fc8c79288668c866a5
  # https://github.com/microvm-nix/microvm.nix/pull/381
  systemd.mounts = lib.mkIf config.boot.initrd.systemd.enable [
    {
      what = "store";
      where = "/nix/store";
      # Generate a `nix-store.mount.d/overrides.conf`
      overrideStrategy = "asDropin";
      unitConfig.DefaultDependencies = false;
    }
  ];
}
