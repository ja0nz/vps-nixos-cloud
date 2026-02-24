/**
  Module: newt.nix
  Description: The other end of a pangolin tunnel
  * Detailed info:
*/
{
  config,
  vars,
  ...
}:

let
  homelab = {
    site = "wavy-alpine-chipmunk";
    hostname = "localhost";
    method = "http";
    port = 80;
  };
in
{
  sops.secrets."newt_id" = {
    sopsFile = ../secrets/homelab.enc.yaml;
  };
  sops.secrets."newt_secret" = {
    sopsFile = ../secrets/homelab.enc.yaml;
  };
  sops.templates."newt.env" = {
    content = ''
      NEWT_ID=${config.sops.placeholder."newt_id"}
      NEWT_SECRET=${config.sops.placeholder."newt_secret"}
    '';
  };

  services.newt = {
    enable = true;
    settings = {
      endpoint = "https://pangolin.${vars.DOMAIN}";
    };
    environmentFile = config.sops.templates."newt.env".path;
    blueprint = {
      public-resources = {
        dashboard = {
          name = "Traefik Dashboard";
          full-domain = "traefik.${vars.DOMAIN}";
          protocol = "http";
          auth = {
            sso-enabled = true;
          };
          targets = [
            {
              site = "wavy-alpine-chipmunk";
              hostname = "localhost";
              method = "http";
              port = 8080;
            }
          ];
        };
        whoami = {
          name = "Whoami test page";
          full-domain = "whoami.${vars.DOMAIN}";
          protocol = "http";
          targets = [ homelab ];
        };
      };
    };
  };
}
