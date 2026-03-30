/**
  Module: beszelhub.nix
  Description: Lightweight server monitoring hub with historical data, docker stats, and alerts
  * Detailed info:
  - Persist & Backup: /var/lib/private (done in impermanence anyway)
  - See: shared-modules/beszelhub.nix
  - IMPORTANT: In reverse proxy add rule to bypass: api/beszel/agent-connect
  - Proxy: http://localhost:8090
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
