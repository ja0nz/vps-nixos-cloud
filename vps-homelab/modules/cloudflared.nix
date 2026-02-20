/**
  Module: cloudflared.nix
  Description: Handy CF tunnels for developing locally
  * Detailed info:
    While developing locally cloudflare tunnels are super useful. Try things
    out locally before building remote.
  - Prepare:
    - cloudflared locally installed and authenticated (on you dev machine)
    - Run: `cloudflared tunnel create "<Name>"`
    - `cat` the generated credential to a please where you could reference it
       via *credentialsFile* (in this case sops-nix)
    - Adapt the tunnel name to the uuid given
    - Define ingress rules
  - Run:
    - Attention: check those after running at the dashboard - they are sometimes
      not set automatically
    - Run check: `cloudflared tunnel info "<Name>"
  - Consumes: CF tunnel credentials
*/
{ config, vars, ... }:

{
  sops.secrets."cf_tunnel_homelab" = { };

  services.cloudflared = {
    enable = true;
    tunnels = {
      # cloudflared tunnel create Homelab
      "${vars.CF_TUNNEL}" = {
        credentialsFile = config.sops.secrets."cf_tunnel_homelab".path;
        default = "http_status:404";
        ingress = {
          "ping.${vars.DOMAIN}" = "http://localhost:80";
        };
      };
    };
  };
}
