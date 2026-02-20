/**
  Module: pangolin.nix
  Description: Tunneled reverse proxy server with identity and access control
  * Detailed info:
  - Permissions: chown pangolin:fossorial
  - Persist: /var/lib/pangolin
  - Consumes: CF_DNS_API_TOKEN, CF_API_EMAIL, lets encrypt renew email
*/
{
  config,
  vars,
  ...
}:

{
  sops.secrets."cf_api_email" = { };
  sops.secrets."cf_dns_api_token" = { };
  sops.templates."traefik.env" = {
    content = ''
      CF_API_EMAIL=${config.sops.placeholder."cf_api_email"}
      CF_DNS_API_TOKEN=${config.sops.placeholder."cf_dns_api_token"}
    '';
  };

  sops.secrets."pangolin_server_secret" = { };
  sops.secrets."pangolin_setup_token" = { };
  sops.templates."pangolin.env" = {
    content = ''
      SERVER_SECRET=${config.sops.placeholder."pangolin_server_secret"}
      PANGOLIN_SETUP_TOKEN=${config.sops.placeholder."pangolin_setup_token"}
    '';
  };

  networking.firewall.allowedTCPPorts = [
    80
    443
  ];
  security.acme.defaults.email = "acme.visible258@aleeas.com";
  services.pangolin = {
    enable = true;
    openFirewall = true;
    baseDomain = vars.DOMAIN;
    environmentFile = config.sops.templates."pangolin.env".path;
    dnsProvider = "cloudflare";
    settings = {
      domains = {
        domain1 = {
          prefer_wildcard_cert = true;
        };
      };
      # https://docs.pangolin.net/self-host/advanced/config-file#feature-flags
      flags = {
        # Whether to require email verification for new users.
        require_email_verification = false; # default
        # Whether to disable public user registration.
        disable_signup_without_invite = true;
        # Whether to prevent users from creating organizations.
        disable_user_create_org = true;
        # Whether to disable product help banners in the UI at the top of screens.
        disable_product_help_banners = false; # default
        # Whether to disable features that are only available in the Enterprise Edition from showing in the UI.
        disable_enterprise_features = true;
      };
    };
  };

  services.traefik = {
    environmentFiles = [
      config.sops.templates."traefik.env".path
    ];
    # Current bug
    # dynamic.dir = "/var/lib/pangolin/traefik/dynamic";
  };
}
