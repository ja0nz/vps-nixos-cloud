{
  vars,
  pkgs,
  config,
  osConfig,
  ...
}:

let
  # Common
  subDomain = "photos";
  publicNet = "immich-net";
  internalNet = "immich-internal-net";
  versionTag = "v2";
  url = "Host(`${subDomain}.${vars.DOMAIN}`)";

  # Server
  id = "immich-server";
  containerPort = "2283";

  # Machine Learning
  idML = "immich-machine-learning";

  # Database
  idDB = "immich-database";
  versionDBTag = "18-vectorchord0.5.3";

  # Redis
  idRedis = "immich-redis";

in
{
  sops.secrets."immich_db_password" = { };
  sops.templates."${id}.env" = {
    content = ''
      IMMICH_MACHINE_LEARNING_URL=http://${idML}:3003
      REDIS_HOSTNAME=${idRedis}
      DB_HOSTNAME=${idDB}
      DB_USERNAME=immich
      DB_DATABASE_NAME=immich

      DB_PASSWORD=${config.sops.placeholder."immich_db_password"}
    '';
  };

  sops.templates."${idDB}.env" = {
    content = ''
      POSTGRES_DB=immich
      POSTGRES_USER=immich
      POSTGRES_INITDB_ARGS='--data-checksums'

      POSTGRES_PASSWORD=${config.sops.placeholder."immich_db_password"}
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
        healthcheck = {
          hostname = "localhost";
          port = 80;
          path = "/api/server/ping";
        };
      }
    ];
  };

  virtualisation.quadlet.networks."${publicNet}" = { };
  virtualisation.quadlet.networks."${internalNet}" = {
    networkConfig = {
      internal = true;
    };
  };
  virtualisation.quadlet.volumes."${id}" = { };
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
      image = "ghcr.io/immich-app/immich-server:${versionTag}";
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
        "${id}:/data"
      ];
      labels = {
        "traefik.enable" = "true";
        "traefik.http.routers.${id}.rule" = url;
        "traefik.http.services.${id}.loadbalancer.server.port" = containerPort;
      };
    };
  };

  virtualisation.quadlet.volumes."${idML}" = { };
  virtualisation.quadlet.containers.${idML} = {
    containerConfig = {
      image = "ghcr.io/immich-app/immich-machine-learning:${versionTag}";
      dropCapabilities = [ "ALL" ];
      addCapabilities = [ ];
      noNewPrivileges = true;
      environments.TZ = osConfig.time.timeZone;
      networks = [ "${internalNet}" ];
      volumes = [
        "${idML}:/cache"
      ];
    };
  };

  virtualisation.quadlet.containers.${idRedis} = {
    containerConfig = {
      image = "docker.io/valkey/valkey:9";
      environments.TZ = osConfig.time.timeZone;
      networks = [ "${internalNet}" ];
      healthCmd = "valkey-cli ping | grep -q PONG";
      healthRetries = 2;
      healthInterval = "30s";
      healthTimeout = "10s";
      healthStartPeriod = "120s";
      healthStartupInterval = "5s";
    };
  };

  virtualisation.quadlet.volumes."${idDB}" = { };
  virtualisation.quadlet.containers.${idDB} = {
    containerConfig = {
      image = "ghcr.io/immich-app/postgres:${versionDBTag}";
      shmSize = "128mb";
      environmentFiles = [ config.sops.templates."${idDB}.env".path ];
      environments.TZ = osConfig.time.timeZone;
      networks = [ "${internalNet}" ];
      volumes = [
        "${idDB}:/var/lib/postgresql"
      ];
    };
  };
  home.packages = [
    (pkgs.writeShellApplication {
      name = "immich-db-backup";
      runtimeInputs = [ pkgs.gzip ];
      text = ''
        set -euo pipefail

        DB_USER=$(podman exec ${idDB} printenv POSTGRES_USER)
        DUMP_FILE="$HOME/immich-db-dump.sql.gz"

        echo "==> Backing up PostgreSQL..."
        podman exec ${idDB} \
          pg_dumpall --clean --if-exists --username="$DB_USER" \
          | gzip > "$DUMP_FILE"
        echo "    Backup written to $DUMP_FILE"

        echo "==> Stopping immich services..."
        systemctl --user stop ${id} ${idML} ${idDB}

        echo "==> Wiping data volume..."
        podman volume rm ${idDB}

        echo ""
        echo "*** Now switch your Nix config with the new version                        ***"
        echo "*** Then run: immich-db-restore                                            ***"
        echo ""
      '';
    })
    (pkgs.writeShellApplication {
      name = "immich-db-restore";
      runtimeInputs = [ pkgs.gzip ];
      text = ''
        set -euo pipefail

        DUMP_FILE="$HOME/immich-db-dump.sql.gz"
        if [[ ! -f "$DUMP_FILE" ]]; then
          echo "No dump file found at $DUMP_FILE"
          exit 1
        fi

        echo "==> Starting new database container..."
        systemctl --user start ${idDB}

        echo "==> Waiting for database to be ready..."
        until podman exec ${idDB} pg_isready 2>/dev/null; do
          sleep 2
        done

        echo "==> Restoring backup..."
        DB_USER=$(podman exec ${idDB} printenv POSTGRES_USER)
        gunzip < "$DUMP_FILE" \
          | podman exec -i ${idDB} psql --username="$DB_USER"

        echo "==> Starting all immich services..."
        systemctl --user start ${id} ${idML}

        echo "==> Cleaning up dump file..."
        rm "$DUMP_FILE"

        echo "Done."
      '';
    })
    (pkgs.writeShellApplication {
      name = "immich-db-list-versions";
      runtimeInputs = [
        pkgs.curl
        pkgs.jq
      ];
      text = ''
        set -euo pipefail

        CURRENT_TAG="${versionDBTag}"
        PREFIX="''${CURRENT_TAG%%-*}"
        MAJOR="''${PREFIX%%.*}"
        NEXT_MAJOR=$(( MAJOR + 1 ))

        echo "Current tag in use: $CURRENT_TAG"
        echo ""

        PAGE=$(curl -sSf \
              "https://github.com/immich-app/base-images/pkgs/container/postgres/versions?filters%5Bversion_type%5D=tagged")

        echo "==> Available tags matching current major version ($PREFIX):"
        echo "$PAGE" \
          | grep -oP "$PREFIX-vectorchord[0-9]+\.[0-9]+\.[0-9]+" \
          | sort -V

        echo ""
        echo "==> Major version update check (looking for prefix \"$NEXT_MAJOR\"):"
        NEXT=$(echo "$PAGE" \
          | grep -oP "$NEXT_MAJOR-vectorchord[0-9]+\.[0-9]+\.[0-9]+" \
          | sort -V)

        if [[ -n "$NEXT" ]]; then
          echo "$NEXT"
        else
          echo "No major update available yet"
        fi
      '';
    })
  ];
}
