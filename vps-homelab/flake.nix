{
  description = "Homelab";

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
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
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
      tooling,
      ...
    }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};

      specialArgs = {
        inherit inputs;
        vars = builtins.fromJSON (builtins.readFile ./env.json);
      };

      sharedModules = [
        ./shared-modules/base.nix
        ./shared-modules/backrest.nix
        ./modules/newt.nix
        ./modules/containers.nix
        inputs.sops-nix.nixosModules.sops
        inputs.quadlet-nix.nixosModules.quadlet
        inputs.home-manager.nixosModules.home-manager
        { home-manager.extraSpecialArgs = specialArgs; }
      ];

      mkConfig =
        {
          extraModules ? [ ],
          system ? "x86_64-linux",
        }:
        nixpkgs.lib.nixosSystem {
          inherit system;
          inherit specialArgs;
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
          ./modules/cloudflared.nix
          ./shared-modules/microvm-configuration.nix

          # Special Development settings
          (
            { ... }:
            {
              microvm = {
                # Home Manager
                writableStoreOverlay = "/nix/.rw-store";
                # Podman user
                volumes = [
                  {
                    mountPoint = "/home/containers";
                    image = "./.home-container.img";
                    size = 8000; # 8GB
                  }
                ];
              };
              systemd.services.fix-container-home-permissions = {
                script = ''
                  chown -R containers:users /home/containers
                  chmod 700 /home/containers
                '';
                wantedBy = [ "multi-user.target" ];
                before = [ "home-manager-containers.service" ]; # Run BEFORE HM tries to link files
                serviceConfig = {
                  Type = "oneshot";
                  RemainAfterExit = true;
                };
              };
            }
          )
        ];
      };

      nixosConfigurations.prod-remote = mkConfig {
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
