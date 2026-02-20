{
  pkgs,
  port,
  config,
  vars,
  ...
}:

let
  # --- CONFIG BLOCK ---
  cfg = {
    wp = {
      image = "docker.io/library/wordpress:latest";
      containerPort = "80";
      hostPort = port.wordpress;
    };
    db = {
      image = "docker.io/library/mariadb:latest";
      port = "3306";
    };
    networks = {
      public = "podman"; # Talk to Caddy
      internal = "wordpress-net"; # Talk to DB
    };
    domain = "${vars.DOMAIN}";
  };

in
{
  services.caddy.virtualHosts."${cfg.domain}" = {
    extraConfig = ''
      import tinyauth_forwarder
      reverse_proxy localhost:${cfg.wp.hostPort}
    '';
  };

  sops.secrets."wordpress_db_password" = { };
  sops.secrets."wordpress_root_password" = { };
  sops.templates."mariaDB.env" = {
    content = ''
      MYSQL_ROOT_PASSWORD=${config.sops.placeholder."wordpress_root_password"}
      MYSQL_DATABASE=wordpress
      MYSQL_USER=wordpress
      MYSQL_PASSWORD=${config.sops.placeholder."wordpress_db_password"}
    '';
  };
  sops.templates."wordpress.env" = {
    content = ''
      WORDPRESS_DB_NAME=wordpress
      WORDPRESS_DB_USER=wordpress
      WORDPRESS_DB_HOST=wordpress-db:${cfg.db.port}
      WORDPRESS_DB_PASSWORD=${config.sops.placeholder."wordpress_db_password"}
    '';
  };

  virtualisation.oci-containers.containers = {
    wordpress = {
      image = cfg.wp.image;
      ports = [ "${cfg.wp.hostPort}:${cfg.wp.containerPort}" ];
      environmentFiles = [
        config.sops.templates."wordpress.env".path
      ];
      dependsOn = [ "wordpress-db" ];
      volumes = [ "wordpress-data:/var/www/html" ];
      networks = [
        cfg.networks.public
        cfg.networks.internal
      ];
      extraOptions = [
        "--security-opt=no-new-privileges"
      ];
    };

    # wordpress-cli = {
    #   image = "docker.io/library/wordpress:cli-php8.5";
    #   environmentFiles = [
    #     config.sops.templates."wordpress.env".path
    #   ];
    #   dependsOn = [ "wordpress" ];
    #   volumes = [ "wordpress-data:/var/www/html" ];
    #   networks = [
    #     cfg.networks.public
    #     cfg.networks.internal
    #   ];
    # };

    wordpress-db = {
      image = cfg.db.image;
      environmentFiles = [
        config.sops.templates."mariaDB.env".path
      ];
      volumes = [ "wordpress-db-data:/var/lib/mysql" ];
      networks = [ cfg.networks.internal ];
      extraOptions = [
        "--security-opt=no-new-privileges"
      ];
    };
  };

  # Stack-specific internal network
  systemd.services.create-wordpress-network = {
    serviceConfig.Type = "oneshot";
    wantedBy = [
      "podman-wordpress.service"
      "podman-wordpress-db.service"
    ];
    script = ''
      ${pkgs.podman}/bin/podman network exists ${cfg.networks.internal} || \
      ${pkgs.podman}/bin/podman network create --internal ${cfg.networks.internal}
    '';
  };
}
