{
  description = "Homelab";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    impermanence.url = "github:nix-community/impermanence";
    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";
    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";
    microvm.url = "github:microvm-nix/microvm.nix";
    microvm.inputs.nixpkgs.follows = "nixpkgs";
    quadlet-nix.url = "github:SEIAROTg/quadlet-nix";
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
        # ./modules/containers.nix
        inputs.sops-nix.nixosModules.sops
        inputs.quadlet-nix.nixosModules.quadlet
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
          ./modules/newt.nix
          ./modules/cloudflared.nix
          ./shared-modules/microvm-configuration.nix
        ];
      };

      nixosConfigurations.prod-remote = mkConfig {
        extraModules = [
          inputs.disko.nixosModules.disko
          inputs.impermanence.nixosModules.impermanence
          ./shared-modules/vps-configuration.nix
          ./shared-modules/hardware-configuration.nix
          ./shared-modules/impermanence.nix
        ];
      };
    };
}
