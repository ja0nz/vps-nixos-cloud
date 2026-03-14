{
  vars,
  config,
  osConfig,
  ...
}:

let
  # Common
  subDomain = "photos";
  publicNet = "immich-net";
  internalNet = "immich-internal-net";
  version = "v2";
  dataDir = "immich-data";
  url = "Host(`${subDomain}.${vars.DOMAIN}`)";

  # Server
  id = "immich-server";
  containerPort = "2283";

  # Machine Learning
  idML = "immich-machine-learning";
  cacheDir = "immich-cache";

  # Database
  idDB = "immich-database";
  dbDir = "immich-db";

  # Redis
  idRedis = "immich-redis";

in
{
  sops.secrets."immich_db_username" = { };
  sops.secrets."immich_db_password" = { };
  sops.templates."${id}.env" = {
    content = ''
      IMMICH_MACHINE_LEARNING_URL=http://${idML}:3003
      REDIS_HOSTNAME=${idRedis}
      DB_HOSTNAME=${idDB}
      DB_DATABASE_NAME=immich

      DB_USERNAME=${config.sops.placeholder."immich_db_username"}
      DB_PASSWORD=${config.sops.placeholder."immich_db_password"}
    '';
  };

  sops.templates."${idDB}.env" = {
    content = ''
      POSTGRES_USER=${config.sops.placeholder."immich_db_username"}
      POSTGRES_PASSWORD=${config.sops.placeholder."immich_db_password"}
      POSTGRES_DB=immich
      POSTGRES_INITDB_ARGS='--data-checksums'
    '';
  };

  # Define pangolin public-resources
  # Options: ../containers.nix
  hmOpts.pangolin.blueprints."${id}" = {
    name = id;
    full-domain = "${subDomain}.${vars.DOMAIN}";
    protocol = "http";
    auth = {
      sso-enabled = true;
    };
    targets = [
      {
        hostname = "localhost";
        method = "http";
        port = 80;
      }
    ];
  };

  virtualisation.quadlet.networks."${publicNet}" = { };
  virtualisation.quadlet.networks."${internalNet}" = {
    networkConfig = {
      internal = true;
    };
  };
  virtualisation.quadlet.volumes."${dataDir}" = { };
  virtualisation.quadlet.containers.${id} = {
    unitConfig = {
      After = [
        "${idRedis}.service"
        "${idDB}.service"
      ];
      Requires = [
        "${idRedis}.service"
        "${idDB}.service"
      ];
    };
    containerConfig = {
      image = "ghcr.io/immich-app/immich-server:${version}";
      dropCapabilities = [ "ALL" ];
      addCapabilities = [ ];
      noNewPrivileges = true;
      environmentFiles = [ config.sops.templates."${id}.env".path ];
      environments.TZ = osConfig.time.timeZone;
      networks = [
        "${publicNet}"
        "${internalNet}"
      ];
      volumes = [
        "${dataDir}:/data"
      ];
      labels = {
        "traefik.enable" = "true";
        "traefik.http.routers.${id}.rule" = url;
        "traefik.http.services.${id}.loadbalancer.server.port" = containerPort;
      };
    };
  };

  virtualisation.quadlet.volumes."${cacheDir}" = { };
  virtualisation.quadlet.containers.${idML} = {
    containerConfig = {
      image = "ghcr.io/immich-app/immich-machine-learning:${version}";
      dropCapabilities = [ "ALL" ];
      addCapabilities = [ ];
      noNewPrivileges = true;
      environments.TZ = osConfig.time.timeZone;
      networks = [ "${internalNet}" ];
      volumes = [
        "${cacheDir}:/cache"
      ];
    };
  };

  virtualisation.quadlet.containers.${idRedis} = {
    containerConfig = {
      image = "docker.io/valkey/valkey:9";
      environments.TZ = osConfig.time.timeZone;
      networks = [ "${internalNet}" ];
      healthCmd = "redis-cli ping || exit 1";
      healthRetries = 3;
      healthInterval = "30s";
      healthTimeout = "5s";
    };
  };

  virtualisation.quadlet.volumes."${dbDir}" = { };
  virtualisation.quadlet.containers.${idDB} = {
    containerConfig = {
      image = "ghcr.io/immich-app/postgres:18-vectorchord0.5.3";
      shmSize = "128mb";
      environmentFiles = [ config.sops.templates."${idDB}.env".path ];
      environments.TZ = osConfig.time.timeZone;
      networks = [ "${internalNet}" ];
      volumes = [
        "${dbDir}:/var/lib/postgresql"
      ];
    };
  };
}
