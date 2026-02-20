/**
  Module: ddclient.nix
  Description: DynDNS module for changing A records (currently at cloudflare)
  * Detailed info:
  - Consumes: CF_DNS_API_TOKEN
*/
{
  config,
  vars,
  ...
}:

{
  sops.secrets."cf_dns_api_token" = { };

  # https://search.nixos.org/options?query=ddclient
  # https://github.com/ddclient/ddclient/blob/main/ddclient.conf.in
  services.ddclient = {
    enable = true;
    usev4 = "webv4, webv4=api.ipify.org, webv4=ipv4.icanhazip.com";
    usev6 = "webv6, webv6=api6.ipify.org, webv6=icanhazip.com";
    protocol = "cloudflare";
    zone = "${vars.DOMAIN}";
    username = "token";
    passwordFile = config.sops.secrets."cf_dns_api_token".path;
    domains = [
      "${vars.DOMAIN}"
      "*.${vars.DOMAIN}"
    ];
  };
}
