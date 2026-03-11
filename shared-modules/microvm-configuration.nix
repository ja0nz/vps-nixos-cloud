/**
  Module: microvm-configuration.nix
  Description: Configure a development microvm for rapid testing
  * Detailed info:
  - HACK: ssh_host_ed25519_key
*/
{
  config,
  lib,
  vars,
  ...
}:

{
  # TODO A bit of a hack
  # There is also `microvm.credentialFiles` but I could not get it working
  # For production this does not matter as credentials are mounted before activation
  # Further reference: https://github.com/microvm-nix/microvm.nix/pull/337#issuecomment-2671084885
  environment.etc."ssh/ssh_host_ed25519_key" = {
    source = ../secrets/temp/ssh_host_ed25519_key;
    mode = "0600";
  };

  # Disable login prompt / SSH only
  systemd.services."serial-getty@ttyS0".enable = false;

  microvm = {
    mem = 1024;
    hypervisor = "qemu";
    socket = "control.socket";
    vsock.cid = vars.SSH_PORT_LOCAL; # Has to be unique anyway
    volumes = [
      {
        mountPoint = "/var/lib";
        image = "./.var-lib-dev.img";
        size = 500; # 500MB
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
