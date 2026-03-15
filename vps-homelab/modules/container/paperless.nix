{
  vars,
  pkgs,
  config,
  osConfig,
  ...
}:

let
  # Common
  subDomain = "docs.jan";
  publicNet = "paperless-net";
  internalNet = "paperless-internal-net";
  url = "${subDomain}.${vars.DOMAIN}";

  # Server
  id = "paperless-server";
  idMedia = "paperless-media";
  idConsume= "paperless-consume";
  containerPort = "8000";

  # Database
  idDB = "paperless-database";
  versionDBTag = "18";

  # Redis
  idRedis = "paperless-redis";

in
{
  sops.secrets."paperless_db_password" = { };
  sops.secrets."paperless_secret_key" = { };
  sops.templates."${id}.env" = {
    content = ''
      # https://docs.paperless-ngx.com/configuration/

      PAPERLESS_URL=https://${url}
      PAPERLESS_APP_TITLE=Docs

      PAPERLESS_REDIS=redis://${idRedis}
      PAPERLESS_DBHOST=${idDB}
      PAPERLESS_DBPASS=${config.sops.placeholder."paperless_db_password"}
      PAPERLESS_SECRET_KEY=${config.sops.placeholder."paperless_secret_key"}

      PAPERLESS_FILENAME_FORMAT={{ created_year }}/{{ correspondent }}/{{ title }}
      PAPERLESS_FILENAME_FORMAT_REMOVE_NONE=true
      PAPERLESS_OCR_LANGUAGE=deu

      # PAPERLESS_APPS=allauth.socialaccount.providers.openid_connect
      # PAPERLESS_SOCIALACCOUNT_PROVIDERS={"openid_connect":{"SCOPE":["openid","profile","email"],"OAUTH_PKCE_ENABLED":true,"APPS":[{"provider_id":"pocket-id","name":"Pocket-ID","client_id":"Place the Client ID","secret":"Place the Client Secret","settings":{"server_url":"https://pocketid.example.com"}}]}}
    '';
  };

  sops.templates."${idDB}.env" = {
    content = ''
      POSTGRES_DB=paperless
      POSTGRES_USER=paperless
      POSTGRES_INITDB_ARGS='--data-checksums'

      POSTGRES_PASSWORD=${config.sops.placeholder."paperless_db_password"}
    '';
  };

  # Define pangolin public-resources
  # Options: ../containers.nix
  hmOpts.pangolin.blueprints."${id}" = {
    name = id;
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
        healthcheck = {
          hostname = "localhost";
          port = 80;
          path = "/api/remote_version/";
          headers = [
            {
              name = "Host";
              value = url;
            }
          ];
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
  virtualisation.quadlet.volumes."${idMedia}" = { };
  virtualisation.quadlet.volumes."${idConsume}" = { };
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
      image = "ghcr.io/paperless-ngx/paperless-ngx:latest";
      dropCapabilities = [ "ALL" ];
      addCapabilities = [
        "SETUID"
        "SETGID"
        "CHOWN"
        "DAC_OVERRIDE"
      ];
      noNewPrivileges = true;
      environmentFiles = [ config.sops.templates."${id}.env".path ];
      environments.TZ = osConfig.time.timeZone;
      networks = [
        "${publicNet}"
        "${internalNet}"
      ];
      volumes = [
        "${id}:/usr/src/paperless/data"
        "${idMedia}:/usr/src/paperless/media"
        "${idConsume}:/usr/src/paperless/consume"
      ];
      labels = {
        "traefik.enable" = "true";
        "traefik.http.routers.${id}.rule" = "Host(`${url}`)";
        "traefik.http.services.${id}.loadbalancer.server.port" = containerPort;
      };
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
      image = "docker.io/postgres:${versionDBTag}";
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
      name = "paperless-db-backup";
      runtimeInputs = [ pkgs.gzip ];
      text = ''
        set -euo pipefail

        DB_USER=$(podman exec ${idDB} printenv POSTGRES_USER)
        DUMP_FILE="$HOME/paperless-db-dump.sql.gz"

        echo "==> Backing up PostgreSQL..."
        podman exec ${idDB} \
          pg_dumpall --clean --if-exists --username="$DB_USER" \
          | gzip > "$DUMP_FILE"
        echo "    Backup written to $DUMP_FILE"

        echo "==> Stopping paperless services..."
        systemctl --user stop ${id} ${idDB}

        echo "==> Wiping data volume..."
        podman volume rm ${idDB}

        echo ""
        echo "*** Now switch your Nix config with the new version                        ***"
        echo "*** Then run: paperless-db-restore                                            ***"
        echo ""
      '';
    })
    (pkgs.writeShellApplication {
      name = "paperless-db-restore";
      runtimeInputs = [ pkgs.gzip ];
      text = ''
        set -euo pipefail

        DUMP_FILE="$HOME/paperless-db-dump.sql.gz"
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

        echo "==> Starting all paperless services..."
        systemctl --user start ${id}

        echo "==> Cleaning up dump file..."
        rm "$DUMP_FILE"

        echo "Done."
      '';
    })
  ];
}
