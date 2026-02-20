{
  description = "Pangolin Proxy";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    impermanence.url = "github:nix-community/impermanence";
    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";
    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";
    microvm.url = "github:microvm-nix/microvm.nix";
    microvm.inputs.nixpkgs.follows = "nixpkgs";
  };

  nixConfig = {
    extra-substituters = [ "https://microvm.cachix.org" ];
    extra-trusted-public-keys = [ "microvm.cachix.org-1:oXnBc6hRE3eX5rSYdRyMYXnfzcCxC7yKPTbZXALsqys=" ];
    download-buffer-size = 536870912; # 512MB
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      ...
    }:
    let
      system = "x86_64-linux";

      sharedModules = [
        ./shared-modules/base.nix
        inputs.sops-nix.nixosModules.sops
      ];

      mkConfig =
        {
          extraModules ? [ ],
          system ? "x86_64-linux",
        }:
        nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = {
            vars = builtins.fromJSON (builtins.readFile ./env.json);
          };
          modules = sharedModules ++ extraModules;
        };
    in
    {
      packages.${system} = {
        default = self.packages.${system}.dev-local;
        dev-local = self.nixosConfigurations.dev-local.config.microvm.declaredRunner;
      };

      nixosConfigurations.dev-local = mkConfig {
        extraModules = [
          inputs.microvm.nixosModules.microvm
          ./shared-modules/microvm-configuration.nix
          ./modules/cloudflared.nix

          # CF tunnel overwrites
          # WARNING: while you can play a bit with the dashboard, pangolin will
          # NOT work over CF tunnel which - in its free version - is a TCP tunnel only
          # hence *Wireguard utilizing UDP* will fail
          (
            { vars, ... }:
            {
              imports = [ ./modules/pangolin.nix ];
              services.pangolin = {
                dashboardDomain = "dev-pangolin.${vars.DOMAIN}";
              };
            }
          )
        ];
      };

      nixosConfigurations.prod-remote = mkConfig {
        system = "aarch64-linux";
        extraModules = [
          inputs.disko.nixosModules.disko
          inputs.impermanence.nixosModules.impermanence
          ./modules/pangolin.nix
          ./modules/ddclient.nix
          ./shared-modules/vps-configuration.nix
          ./shared-modules/hardware-configuration.nix
          ./shared-modules/impermanence.nix
        ];
      };
    };
}
