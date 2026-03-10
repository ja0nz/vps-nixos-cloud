{
  config,
  lib,
  pkgs,
  ...
}:

let
  dataDir = "/var/lib/backrest";
in
{
  options.services.shared-backrest = {
    enable = lib.mkEnableOption "Enable backrest service";
    extraPaths = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "List of additional paths to expose to the backrest service.";
    };
    extraGroups = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "List of additional groups for backup permission.";
    };
  };

  config = lib.mkIf config.services.shared-backrest.enable {
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

        # Environment variables
        Environment = "BACKREST_PORT=127.0.0.1:9898";
        Restart = "on-failure";
        AmbientCapabilities = "cap_net_bind_service";
        CapabilityBoundingSet = "cap_net_bind_service";
        NoNewPrivileges = true;
        LimitNPROC = 64;
        LimitNOFILE = 1048576;
        PrivateTmp = true;
        PrivateDevices = true;
        ProtectHome = true;
        ProtectSystem = "full";
        ReadWritePaths = [ dataDir ];
        BindReadOnlyPaths = config.services.shared-backrest.extraPaths;
        RuntimeDirectory = "backrest";
        WorkingDirectory = dataDir;
      };
    };

    # Create the user/group for security
    users.users.backrest = {
      group = "backrest";
      extraGroups = config.services.shared-backrest.extraGroups;
      home = dataDir;
      isSystemUser = true;
      createHome = true;
    };
    users.groups.backrest = { };
  };
}
