/**
  Module: syncthing.nix
  Description: A self-hosted open-source alternative to Dropbox
  * Detailed info:
    https://search.nixos.org/options?query=services.syncthing
    Basic configuration without strictly managing devices/folders
*/
{
  ...
}:

let
  dataDir = "/var/lib/syncthing";
in
{
  sysOpts.persist.directories = [
    {
      directory = "${dataDir}";
      user = "syncthing";
      group = "syncthing";
    }
  ];

  services.syncthing = {
    inherit dataDir;
    enable = true;
    openDefaultPorts = true;
    overrideFolders = false;
    overrideDevices = false;
    settings.gui = {
      # insecureSkipHostcheck = true;
      # Will handle admin access via tunnel
      insecureAdminAccess = true;
    };
  };
}
