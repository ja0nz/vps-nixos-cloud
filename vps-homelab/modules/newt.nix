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

{
  sops = {
    secrets."newt_id" = {
      sopsFile = ../secrets/homelab.enc.yaml;
    };
    secrets."newt_secret" = {
      sopsFile = ../secrets/homelab.enc.yaml;
    };
    templates."newt.env" = {
      content = ''
        NEWT_ID=${config.sops.placeholder."newt_id"}
        NEWT_SECRET=${config.sops.placeholder."newt_secret"}
      '';
    };
  };

  services.newt = {
    enable = true;
    settings = {
      endpoint = "https://pangolin.${vars.DOMAIN}";
    };
    environmentFile = config.sops.templates."newt.env".path;
    blueprint = {
      public-resources = config.home-manager.users.containers.hmOpts.pangolin.blueprints;
    };
  };
}
