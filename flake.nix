{
  description = "devShell tooling";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { nixpkgs, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in
    {
      formatter.x86_64-linux = pkgs.nixfmt-tree;

      devShells.${system}.default = pkgs.mkShell {
        buildInputs = with pkgs; [
          mise
          deadnix
          age
          cloudflared
          sops
          pre-commit
          # LSP Server
          tombi
          bash-language-server
          nixd
        ];
        shellHook = ''
          echo "Mise environment active"
        '';
      };

    };
}
