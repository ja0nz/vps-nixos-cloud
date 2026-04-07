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
  server = {
    id = "paperless-server";
    idMedia = "paperless-media";
    containerPort = "8000";
  };

  # Database
  db = {
    id = "paperless-database";
    versionTag = "18";
  };

  # Redis
  redis = {
    id = "paperless-redis";
  };
in
{
  sops.secrets."paperless_db_password" = { };
  sops.secrets."paperless_secret_key" = { };
  sops.templates."${server.id}.env" = {
    content = ''
      # https://docs.paperless-ngx.com/configuration/

      PAPERLESS_URL=https://${url}
      PAPERLESS_APP_TITLE=Docs

      PAPERLESS_REDIS=redis://${redis.id}
      PAPERLESS_DBHOST=${db.id}
      PAPERLESS_DBPASS=${config.sops.placeholder."paperless_db_password"}
      PAPERLESS_SECRET_KEY=${config.sops.placeholder."paperless_secret_key"}

      PAPERLESS_FILENAME_FORMAT={{ created_year }}/{{ correspondent }}/{{ title }}
      PAPERLESS_FILENAME_FORMAT_REMOVE_NONE=true
      PAPERLESS_OCR_LANGUAGE=deu

      # PAPERLESS_APPS=allauth.socialaccount.providers.openid_connect
      # PAPERLESS_SOCIALACCOUNT_PROVIDERS={"openid_connect":{"SCOPE":["openid","profile","email"],"OAUTH_PKCE_ENABLED":true,"APPS":[{"provider_id":"pocket-id","name":"Pocket-ID","client_id":"Place the Client ID","secret":"Place the Client Secret","settings":{"server_url":"https://pocketid.example.com"}}]}}
    '';
  };

  sops.templates."${db.id}.env" = {
    content = ''
      POSTGRES_DB=paperless
      POSTGRES_USER=paperless
      POSTGRES_INITDB_ARGS='--data-checksums'

      POSTGRES_PASSWORD=${config.sops.placeholder."paperless_db_password"}
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
  virtualisation.quadlet.volumes."${server.id}" = { };
  virtualisation.quadlet.volumes."${server.idMedia}" = { };
  virtualisation.quadlet.containers.${server.id} = {
    unitConfig = {
      After = [
        "${redis.id}.service"
        "${db.id}.service"
      ];
      Requires = [
        "${redis}.service"
        "${db.id}.service"
      ];
    };
    containerConfig = {
      image = "ghcr.io/paperless-ngx/paperless-ngx:latest";
      dropCapabilities = [ "ALL" ];
      addCapabilities = [
        "SETUID"
        "SETGID"
        "CHOWN"
      ];
      noNewPrivileges = true;
      environmentFiles = [ config.sops.templates."${server.id}.env".path ];
      environments.TZ = osConfig.time.timeZone;
      networks = [
        "${publicNet}"
        "${internalNet}"
      ];
      volumes = [
        "${server.id}:/usr/src/paperless/data:U"
        "${server.idMedia}:/usr/src/paperless/media:U"
      ];
      labels = {
        "traefik.enable" = "true";
        "traefik.http.routers.${server.id}.rule" = "Host(`${url}`)";
        "traefik.http.services.${server.id}.loadbalancer.server.port" = server.containerPort;
      };
    };
  };

  virtualisation.quadlet.containers.${redis.id} = {
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

  virtualisation.quadlet.volumes."${db.id}" = { };
  virtualisation.quadlet.containers.${db.id} = {
    containerConfig = {
      image = "docker.io/postgres:${db.versionTag}";
      shmSize = "128mb";
      environmentFiles = [ config.sops.templates."${db.id}.env".path ];
      environments.TZ = osConfig.time.timeZone;
      networks = [ "${internalNet}" ];
      volumes = [
        "${db.id}:/var/lib/postgresql"
      ];
    };
  };
  home.packages = [
    (pkgs.writeShellApplication {
      name = "paperless-db-backup";
      runtimeInputs = [ pkgs.gzip ];
      text = ''
        set -euo pipefail

        DB_USER=$(podman exec ${db.id} printenv POSTGRES_USER)
        DUMP_FILE="$HOME/paperless-db-dump.sql.gz"

        echo "==> Backing up PostgreSQL..."
        podman exec ${db.id} \
          pg_dumpall --clean --if-exists --username="$DB_USER" \
          | gzip > "$DUMP_FILE"
        echo "    Backup written to $DUMP_FILE"

        echo "==> Stopping paperless services..."
        systemctl --user stop ${server.id} ${db.id}

        echo "==> Wiping data volume..."
        podman volume rm ${db.id}

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
        systemctl --user start ${db.id}

        echo "==> Waiting for database to be ready..."
        until podman exec ${db.id} pg_isready 2>/dev/null; do
          sleep 2
        done

        echo "==> Restoring backup..."
        DB_USER=$(podman exec ${db.id} printenv POSTGRES_USER)
        gunzip < "$DUMP_FILE" \
          | podman exec -i ${db.id} psql --username="$DB_USER"

        echo "==> Starting all paperless services..."
        systemctl --user start ${server.id}

        echo "==> Cleaning up dump file..."
        rm "$DUMP_FILE"

        echo "Done."
      '';
    })
  ];
}
