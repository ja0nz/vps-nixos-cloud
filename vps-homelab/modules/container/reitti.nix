{
  vars,
  config,
  osConfig,
  ...
}:

let
  # Common
  subDomain = "places";
  publicNet = "reitti-net";
  internalNet = "reitti-internal-net";
  versionTag = "4";
  url = "${subDomain}.${vars.DOMAIN}";

  # Server
  server = {
    id = "reitti-server";
    containerPort = "8080";
  };

  # Postgis
  postgis = {
    id = "reitti-postgis";
    versionTag = "18-3.6-alpine";
  };

  # Tile Cache
  tileCache = {
    id = "reitti-tile-cache";
  };

  # Redis
  redis = {
    id = "reitti-redis";
  };

in
{

  sops.secrets."reitti_postgis_password" = { };
  sops.templates."${server.id}.env" = {
    content = ''
      POSTGIS_USER=reitti
      POSTGIS_PASSWORD=${config.sops.placeholder."reitti_postgis_password"}
      POSTGIS_DB=${postgis.id}
      POSTGIS_HOST=${postgis.id}
    '';
  };

  sops.templates."${postgis.id}.env" = {
    content = ''
      POSTGRES_USER=reitti
      POSTGRES_DB=${postgis.id}
      POSTGRES_INITDB_ARGS='--data-checksums'

      POSTGRES_PASSWORD=${config.sops.placeholder."reitti_postgis_password"}
    '';
  };

  # Define pangolin public-resources
  # Options: ../containers.nix
  hmOpts.pangolin.blueprints."${server.id}" = {
    name = server.id;
    full-domain = url;
    protocol = "http";
    auth = {
      sso-enabled = true;
    };
    targets = [
      {
        hostname = "localhost";
        method = "http";
        port = 80;
        # healthcheck = {
        #   hostname = "localhost";
        #   port = 80;
        #   path = "/api/server/ping";
        #   headers = [
        #     {
        #       name = "Host";
        #       value = url;
        #     }
        #   ];
        # };
      }
    ];
  };

  virtualisation.quadlet.networks."${publicNet}" = { };
  virtualisation.quadlet.networks."${internalNet}" = {
    networkConfig = {
      internal = true;
    };
  };
  virtualisation.quadlet.volumes."${server.id}" = { };
  virtualisation.quadlet.containers.${server.id} = {
    unitConfig = {
      After = [
        "${redis.id}.service"
        "${postgis.id}.service"
        "${tileCache.id}.service"
      ];
      Requires = [
        "${redis.id}.service"
        "${postgis.id}.service"
        "${tileCache.id}.service"
      ];
    };
    containerConfig = {
      image = "ghcr.io/dedicatedcode/reitti:${versionTag}";
      dropCapabilities = [ "ALL" ];
      addCapabilities = [
        "CHOWN"
        "SETGID"
        "SETUID"
      ];
      noNewPrivileges = true;
      environmentFiles = [ config.sops.templates."${server.id}.env".path ];
      environments.TZ = osConfig.time.timeZone;
      networks = [
        "${publicNet}"
        "${internalNet}"
      ];
      volumes = [
        "${server.id}:/data/"
      ];
      labels = {
        "traefik.enable" = "true";
        "traefik.http.routers.${server.id}.rule" = "Host(`${url}`)";
        "traefik.http.services.${server.id}.loadbalancer.server.port" = server.containerPort;
      };
    };
  };

  virtualisation.quadlet.volumes."${tileCache.id}" = { };
  virtualisation.quadlet.containers.${tileCache.id} = {
    containerConfig = {
      image = "ghcr.io/dedicatedcode/reitti-tile-cache:${versionTag}";
      dropCapabilities = [ "ALL" ];
      addCapabilities = [
        "CHOWN"
        "SETUID"
        "SETGID"
        "NET_BIND_SERVICE"
      ];
      noNewPrivileges = true;
      environments.TZ = osConfig.time.timeZone;
      networks = [
        "${publicNet}"
        "${internalNet}"
      ];
      volumes = [
        "${tileCache.id}:/var/cache/nginx"
      ];
    };
  };


  virtualisation.quadlet.volumes."${postgis.id}" = { };
  virtualisation.quadlet.containers.${postgis.id} = {
    containerConfig = {
      image = "docker.io/postgis/postgis:${postgis.versionTag}";
      shmSize = "128mb";
      environmentFiles = [ config.sops.templates."${postgis.id}.env".path ];
      environments.TZ = osConfig.time.timeZone;
      networks = [ "${internalNet}" ];
      volumes = [
        "${postgis.id}:/var/lib/postgresql"
      ];
    };
  };

  virtualisation.quadlet.containers.${redis.id} = {
    containerConfig = {
      image = "docker.io/redis:7-alpine";
      environments.TZ = osConfig.time.timeZone;
      networks = [ "${internalNet}" ];
      healthCmd = "redis-cli ping | grep -q PONG";
      healthRetries = 2;
      healthInterval = "30s";
      healthTimeout = "10s";
      healthStartPeriod = "120s";
      healthStartupInterval = "5s";
    };
  };
}
