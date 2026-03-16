/**
  Module: beszelagent.nix
  Description: Lightweight server monitoring hub with historical data, docker stats, and alerts
  * Detailed info:
  - Persist & Backup: /var/lib/beszel-agent
*/
{
  config,
  vars,
  ...
}:

# let
#   dataDir = "/var/lib/beszel-agent";
# in
{
  # sysOpts.persist.directories = [
  #   {
  #     directory = dataDir;
  #     user = "beszel-agent";
  #   }
  # ];

  sops.secrets."beszel_token" = { };
  sops.secrets."beszel_sshKey" = { };
  sops.templates."beszel.env" = {
    content = ''
      # DATA_DIR=dataDir
      KEY=${config.sops.placeholder."beszel_sshKey"}
      TOKEN=${config.sops.placeholder."beszel_token"}
      HUB_URL=https://mon.${vars.DOMAIN}
    '';
  };

  services.beszel.agent = {
    enable = true;
    openFirewall = false; # agent initiates outbound WebSocket to hub, so not needed
    environmentFile = config.sops.templates."beszel.env".path;
  };
}
