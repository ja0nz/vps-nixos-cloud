{
  vars,
  ...
}:

{
  system.stateVersion = "24.05";

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
        vars.SSH_PORT
      ];
    };
  };

  # SSH
  services.openssh = {
    enable = true;
    ports = [
      vars.SSH_PORT
    ];
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
}
