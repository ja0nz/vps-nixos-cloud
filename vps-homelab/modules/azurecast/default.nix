{
  port,
  vars,
  ...
}:

let
  # --- CONFIG BLOCK ---
  cfg = {
    image = "ghcr.io/azuracast/azuracast:latest";
    containerPort = "80";
    hostPort = port.azurecast;
    network = "podman";
    domain = "azura.${vars.DOMAIN}";
  };
in
{
  networking.firewall.allowedTCPPorts = [
    2022 # SFTP for Music Uploads
  ]
  ++ (builtins.genList (x: x + 8000) 51); # Opens 8000-8050 for Stations/DJs

  services.caddy.virtualHosts."${cfg.domain}" = {
    extraConfig = ''
      import tinyauth_forwarder
      reverse_proxy localhost:${cfg.hostPort}
    '';
  };

  virtualisation.oci-containers.containers.azuracast = {
    inherit (cfg) image;
    ports = [
      "${cfg.hostPort}:${cfg.containerPort}"
      "2022:2022" # SFTP
      "8000-8050:8000-8050" # Radio Streams & Inbound DJ Sources
    ];
    # https://www.azuracast.com/docs/getting-started/settings/
    environment = {
      LANG = "en_US"; # maybe: de_DE
      APPLICATION_ENV = "production";
      COMPOSER_PLUGIN_MODE = "false"; # should only use it if you use one or more plugins with their own Composer dependencies.
      AUTO_ASSIGN_PORT_MIN = "8000";
      AUTO_ASSIGN_PORT_MAX = "8050";
      ENABLE_WEB_UPDATER = "false";
      MYSQL_RANDOM_ROOT_PASSWORD = "yes";
      MYSQL_PASSWORD = "azur4c457"; # default value, db internal only
    };
    volumes = [
      "azuracast_station_data:/var/azuracast/stations"
      "azuracast_backups:/var/azuracast/backups"
      "azuracast_db_data:/var/lib/mysql"
      "azuracast_uploads:/var/azuracast/storage/uploads"
      "azuracast_shoutcast:/var/azuracast/storage/shoutcast2"
      "azuracast_stereo_tool:/var/azuracast/storage/stereo_tool"
      "azuracast_geoip:/var/azuracast/storage/geoip"
      "azuracast_sftpgo:/var/azuracast/storage/sftpgo"
      # Keep your music library as a direct bind mount (read-only)
      # "/home/yourUser/media/music:/var/azuracast/myMusic/remote:ro"
      # "azuracast_metadata:/var/azuracast/myMusic"
    ];
    networks = [ cfg.network ];

    extraOptions = [
      "--security-opt=no-new-privileges"
      "--ulimit=nofile=65536:65536"
    ];
  };
}
