{
  lib,
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
    initrd.postDeviceCommands = lib.mkAfter ''
      # Verify pool is imported
      if ! zpool list zroot >/dev/null 2>&1; then
        echo "Importing zroot pool..."
        zpool import -f zroot
      fi

      # Rollback to blank snapshot
      echo "Rolling back root to blank state..."
      zfs rollback -r zroot/local/root@blank
    '';
  };
  nix = {
    settings = {
      auto-optimise-store = true;
      trusted-users = [
        "root"
        "@wheel"
      ];
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
