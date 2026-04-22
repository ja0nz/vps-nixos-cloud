/**
  Module: beszelagent.nix
  Description: Lightweight server monitoring hub with historical data, docker stats, and alerts
  * Detailed info:
  - Persist & Backup: /var/lib/private (done in impermanence anyway)
*/
{
  config,
  vars,
  ...
}:

let
  dataDir = "/var/lib/beszel-agent";
in
{
  sops = {
    secrets."beszel_token" = { };
    secrets."beszel_sshKey" = { };
    templates."beszel.env" = {
      content = ''
        DATA_DIR=${dataDir}
        KEY=${config.sops.placeholder."beszel_sshKey"}
        TOKEN=${config.sops.placeholder."beszel_token"}
        HUB_URL=https://monitor.${vars.DOMAIN}
      '';
    };
  };

  systemd.services.beszel-agent.serviceConfig.StateDirectory = "beszel-agent";
  services.beszel.agent = {
    enable = true;
    openFirewall = false; # agent initiates outbound WebSocket to hub, so not needed
    environmentFile = config.sops.templates."beszel.env".path;
  };
}
