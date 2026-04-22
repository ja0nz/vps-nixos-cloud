{
  description = "Syncthing";

  inputs = {
    nixpkgs.follows = "tooling/nixpkgs";
    tooling.url = "path:..";

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
      tooling,
      ...
    }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};

      sharedModules = [
        ./shared-modules/base.nix
        ./shared-modules/backrest.nix
        ./modules/syncthing.nix
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

      formatter.x86_64-linux = pkgs.nixfmt-tree;
      devShells.${system}.default = pkgs.mkShell (
        {
          inputsFrom = [ tooling.devShells.${system}.default ];
          shellHook = ''
            export FLAKE_ROOT="$(${pkgs.lib.getExe pkgs.git} rev-parse --show-toplevel)"
            export SECRETS="$FLAKE_ROOT/secrets/secrets.enc.yaml"
          '';
        }
        // builtins.fromJSON (builtins.readFile ./env.json)
      );

      nixosConfigurations.dev-local = mkConfig {
        extraModules = [
          inputs.microvm.nixosModules.microvm
          ./shared-modules/microvm-configuration.nix
          ./modules/cloudflared.nix
        ];
      };

      nixosConfigurations.prod-remote = mkConfig {
        system = "aarch64-linux";
        extraModules = [
          inputs.disko.nixosModules.disko
          inputs.impermanence.nixosModules.impermanence
          ./shared-modules/vps-configuration.nix
          ./shared-modules/hardware-configuration.nix
          ./shared-modules/impermanence.nix
          ./shared-modules/beszelagent.nix
        ];
      };
    };
}
