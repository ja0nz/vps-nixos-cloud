{
  vars,
  config,
  ...
}:

{
  fileSystems."/persist".neededForBoot = true;
  environment.persistence."/persist" = {
    directories = [
      "/var/log"
      "/var/lib/nixos" # CRITICAL for User/Group ID consistency
      "/var/lib/systemd" # Keeps timers and back-end state
      {
        directory = "/var/lib/private";
        mode = "0700";
      }
    ]
    ++ config.sysOpts.persist.directories;
    files = [
      "/etc/machine-id" # CRITICAL for journald and network logs
      "/etc/ssh/mnt/ssh_host_ed25519_key"
      "/etc/ssh/mnt/ssh_host_ed25519_key.pub"
      "/etc/zfs/zpool.cache"
    ];
    users.${vars.USER} = {
      files = [
        ".bash_history" # Keep command history for convenience
      ];
    };
  };
}
