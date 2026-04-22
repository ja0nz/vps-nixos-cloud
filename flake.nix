{
  description = "devShell tooling";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { nixpkgs, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      scripts = import ./scripts { inherit pkgs; };
    in
    {
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
      };
    };
}
