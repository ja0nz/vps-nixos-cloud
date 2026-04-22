{
  description = "devShell tooling";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    pre-commit-hooks.url = "github:cachix/git-hooks.nix";
  };

  outputs =
    {
      self,
      nixpkgs,
      pre-commit-hooks,
      ...
    }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      scripts = import ./scripts { inherit pkgs; };
      helpText = builtins.concatStringsSep "\\n" (
        map (name: "  \\033[1;36m${name}\\033[0m — ${scripts.${name}.meta.description}") (
          builtins.attrNames scripts
        )
      );
    in
    {
      checks.${system}.pre-commit-check = pre-commit-hooks.lib.x86_64-linux.run {
        src = ./.;
        hooks = {
          nixfmt-rfc-style.enable = true; # or nixpkgs-fmt
          statix.enable = true; # lints anti-patterns
          deadnix.enable = true; # removes unused bindings
          flake-checker.enable = true; # checks flake inputs health
        };
      };

      formatter.x86_64-linux = pkgs.nixfmt-tree;
      devShells.${system}.default = pkgs.mkShell {
        buildInputs =
          with pkgs;
          [
            deadnix
            age
            cloudflared
            sops
            pre-commit
            # LSP Server
            bash-language-server
            nixd
            # Connect to Pangolin instance
            pangolin-cli
          ]
          ++ (builtins.attrValues scripts);
        shellHook = self.checks.${system}.pre-commit-check.shellHook + ''
          echo -e "\033[1;33m╭─── 🛠  available commands ───────────────────╮\033[0m"
          echo -e "${helpText}"
          echo -e "\033[1;33m╰──────────────────────────────────────────────╯\033[0m"
          echo ""
          echo -e "\033[1;33m╭─── 🌍 environment variables ─────────────────╮\033[0m"
          echo -e "  \033[1;35mDOMAIN\033[0m       — $DOMAIN"
          echo -e "  \033[1;35mDEV_SSH_PORT\033[0m — $DEV_SSH_PORT"
          echo -e "  \033[1;35mREMOTE_IP4\033[0m   — ''${REMOTE_IP4:-not set}"
          echo -e "  \033[1;35mCF_TUNNEL\033[0m    — $CF_TUNNEL"
          echo -e "\033[1;33m╰──────────────────────────────────────────────╯\033[0m"
        '';
      };
    };
}
