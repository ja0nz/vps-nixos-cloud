{
  pkgs,
  ...
}:

let
  # Caddy helper
  port = {
    tinyauth = "3000";
    whoami = "8081";
    wordpress = "8082";
    azurecast = "8083";
  };
in
{
  imports = [
    ./whoami
    #  ./tinyauth
    #  ./wordpress
    #  ./azurecast
  ];
  _module.args = { inherit port; };

  # --- GLOBAL SETTINGS ---
  services.caddy = {
    enable = true;
    email = "radio.pepper.cert@ja.nz";
    extraConfig = ''
      (tinyauth_forwarder) {
        forward_auth localhost:${port.tinyauth} {
          uri /api/auth/caddy
        }
      }

      # Example of how to use the snippet in VirtualHosts extraConfig:
      #   import tinyauth_forwarder
      #   reverse_proxy localhost:8080
    '';
  };

  virtualisation.quadlet = {
    enable = true;
    autoUpdate = true;
    calendar = "monthly";
  };
  virtualisation.podman.autoPrune.enable = true;

  # --- GLOBAL NETWORK ---
  systemd.services.create-default-network = {
    serviceConfig.Type = "oneshot";
    wantedBy = [ "multi-user.target" ];
    script = ''
      ${pkgs.podman}/bin/podman network exists podman || \
      ${pkgs.podman}/bin/podman network create podman
    '';
  };
}
