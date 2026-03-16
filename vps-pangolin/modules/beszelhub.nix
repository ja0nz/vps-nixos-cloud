/**
  Module: beszelhub.nix
  Description: Lightweight server monitoring hub with historical data, docker stats, and alerts
  * Detailed info:
  - Persist & Backup: /var/lib/private (done in impermanence anyway)
*/
{
  ...
}:

let
  dataDir = "/var/lib/beszel-hub";
in
{
  services.beszel = {
    hub = {
      inherit dataDir;
      enable = true;
      port = 8090; # Default port
      environmentFile = null;
    };
  };
}

# TODO
# # The Agent (Metrics Collector)
# agent = {
#   enable = true;
#   smartmon.enable = true;
#   openFirewall = false; # 45876 by default, via pangolin
#   environment = {
#     PORT = "45876";
#     KEY = "ssh-ed25519 AAAA..."; # You get this from the Hub web UI
#   };
# };
