{
  ...
}:

{
  # Basic system configuration
  boot = {
    supportedFilesystems = [ "zfs" ];
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };
    initrd.systemd = {
      enable = true;
      services.rollback = {
        description = "Rollback root ZFS dataset to blank snapshot";
        wantedBy = [ "initrd.target" ];
        after = [ "zfs-import-zroot.service" ];
        before = [ "sysroot.mount" ];
        unitConfig.DefaultDependencies = "no";
        serviceConfig.Type = "oneshot";
        script = ''
          zfs rollback -r zroot/local/root@blank
        '';
      };
    };
  };
  nix = {
    settings = {
      auto-optimise-store = true;
    };
    gc = {
      automatic = true;
      dates = "weekly";
      randomizedDelaySec = "45min";
      options = "--delete-older-than 30d";
    };
  };
  services.zfs.autoSnapshot.enable = true;
}
