/**
  Module: backrest.nix
  Description: A remote and encrypted backup service based on restic
  * Detailed info:
  - Permissions: chown backrest:backrest
  - Persist & Backup: /var/lib/backrest
*/
{
  pkgs,
  ...
}:

let
  dataDir = "/var/lib/backrest";
in
{
  # Impermanence dependency
  # Either shared-modules/dev-opts.nix (stub) OR impermanence.nixosModules.impermanence
  environment.persistence."/persist" = {
    directories = [
      {
        directory = dataDir;
        user = "backrest";
        group = "backrest";
      }
    ];
  };

  systemd.tmpfiles.rules = [ "d '${dataDir}' 0700 backrest backrest - -" ];

  systemd.services.backrest = {
    description = "Backrest Backup UI";
    wantedBy = [ "multi-user.target" ];
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
    startLimitIntervalSec = 86400;
    startLimitBurst = 5;

    serviceConfig = {
      Type = "simple";
      User = "backrest";
      Group = "backrest";
      ExecStart = "${pkgs.backrest}/bin/backrest";

      # -- Capability Hardening --
      # Only grant what is strictly needed: reading files (DAC_READ_SEARCH).
      AmbientCapabilities = [ "cap_dac_read_search" ];
      CapabilityBoundingSet = [ "cap_dac_read_search" ];

      # -- Process & System Hardening --
      NoNewPrivileges = true;
      ProtectControlGroups = true;
      ProtectKernelModules = true;
      ProtectKernelTunables = true;
      ProtectKernelLogs = true;
      ProtectClock = true;

      # -- Network Hardening --
      # Restrict to only IPv4/IPv6 networking
      RestrictAddressFamilies = [
        "AF_INET"
        "AF_INET6"
      ];
      # -- Filesystem Hardening --
      ProtectSystem = "full";
      PrivateTmp = true;
      PrivateDevices = true;
      PrivateUsers = false; # Set to true only if backrest doesn't need to see system IDs

      # --- The "Zero-Trust" Whitelist ---
      ProtectHome = true;
      InaccessiblePaths = [
        "/home"
        "/root"
        "/etc/ssh"
        "/var/lib/nixos"
        "/var/lib/private"
        "/var/db"
        "/var/cache"
        "/run/secrets"
        "/run/secrets.d"
      ];

      # Environment variables
      Environment = ''
        BACKREST_PORT=127.0.0.1:9898
      '';
      Restart = "on-failure";
      LimitNPROC = 64;
      LimitNOFILE = 1048576;
      ReadWritePaths = [ dataDir ];
      RuntimeDirectory = "backrest";
      WorkingDirectory = dataDir;
    };
  };

  # Create the user/group for security
  users.users.backrest = {
    group = "backrest";
    home = dataDir;
    isSystemUser = true;
    createHome = true;
  };
  users.groups.backrest = { };
}
