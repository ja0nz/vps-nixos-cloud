{
  vars,
  ...
}:

{
  system.stateVersion = "24.05";
  time.timeZone = "Europe/Berlin";

  # SOPS-NIX
  sops = {
    defaultSopsFormat = "yaml";
    defaultSopsFile = ../secrets/secrets.enc.yaml;
    age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
  };

  # Networking
  networking = {
    hostName = "vps";
    hostId = "dbb1698a"; # random; needed for zfs
    firewall = {
      enable = true;
      trustedInterfaces = [ "podman1" ];
      allowedTCPPorts = [
        22
      ];
    };
  };

  # Swap
  zramSwap.enable = true;

  # SSH
  services.openssh = {
    enable = true;
    hostKeys = [
      {
        path = "/etc/ssh/ssh_host_ed25519_key";
        type = "ed25519";
      }
    ];
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
    };
  };

  # Some helpers
  environment.shellAliases = {
    sd = "sudo shutdown now";
    sc = "systemctl";
    scs = "systemctl status";
    scu = "systemctl --user";
    start = "sudo systemctl start";
    stop = "sudo systemctl stop";
    restart = "sudo systemctl restart";
    jc = "journalctl";
    jcx = "journalctl -xeu";
    jcf = "journalctl -f";
    jcb = "journalctl -b";
    jcu = "journalctl -u";
    jcuu = "journalctl --user -u";
    jcuf = "journalctl --user -f -u";
    p = "sudo podman";
    root = "sudo -s";
    containers = "sudo machinectl shell containers@";
    pr = "sudo podman exec -ti";
    ".." = "cd ..";
  };

  # User for ssh login
  users.users.${vars.USER} = {
    isNormalUser = true;
    uid = 1000;
    description = "User for ssh login";
    extraGroups = [
      "wheel"
    ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIP6hyrcaxriF0JMMbommFpT3MwSUw9GxskGrhyONBtgk"
    ];
  };
  nix.settings.trusted-users = [
    "root"
    "@wheel"
  ];

  security.sudo.extraRules = [
    {
      users = [ "${vars.USER}" ];
      commands = [
        {
          command = "ALL";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];

  imports = [
    (
      { lib, ... }:
      {
        options.sysOpts.persist.directories = lib.mkOption {
          type = lib.types.listOf (
            lib.types.submodule {
              options = {
                directory = lib.mkOption {
                  type = lib.types.str;
                };
                user = lib.mkOption {
                  type = lib.types.str;
                  default = "root";
                };
                group = lib.mkOption {
                  type = lib.types.str;
                  default = "root";
                };
                mode = lib.mkOption {
                  type = lib.types.str;
                  default = "0700";
                };
              };
            }
          );
          default = [ ];
          description = "Define impermanence directories.";
        };
      }
    )
  ];
}
