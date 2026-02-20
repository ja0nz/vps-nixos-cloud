/**
  Module: newt.nix
  Description: The other end of a pangolin tunnel
  * Detailed info:
*/
{
  pkgs,
  ...
}:

{
  environment.systemPackages = with pkgs; [
    fosrl-newt
  ];
  # services.newt = {
  #   enable = true;
  #   blueprint = {
  #     # proxy-resources = {
  #     #   jellyfin = {
  #     #     auth = {
  #     #       sso-enabled = true;
  #     #     };
  #     #     full-domain = "jfn.example.com";
  #     #     name = "Jellyfin";
  #     #     protocol = "http";
  #     #     targets = [
  #     #       {
  #     #         hostname = "localhost";
  #     #         method = "http";
  #     #         port = 8096;
  #     #       }
  #     #     ];
  #     #   };
  #     # };
  #   };
  # };
}
