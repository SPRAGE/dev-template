{
  description = "PROJECTNAME";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    claude-code = {
      # SECURITY: Pin to a specific rev for production use
      # url = "github:sadjow/claude-code-nix/<rev>";
      url = "github:sadjow/claude-code-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    custom-codex-release.url = "git+ssh://pai@192.168.0.7/srv/git/custom-codex-release.git?ref=latest";
  };

  outputs = { self, nixpkgs, flake-utils, claude-code, custom-codex-release, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
        python = pkgs.python313.withPackages (ps: [ ps.pyyaml ]);
        codexPackage = custom-codex-release.packages.${system}.codex or pkgs.codex;
      in
      {
        devShells.default = pkgs.mkShell {
          packages = [
            python
            pkgs.uv
            pkgs.git
            pkgs.ripgrep
            pkgs.fd
            pkgs.jq
            pkgs.tree
            pkgs.just
            claude-code.packages.${system}.default
            codexPackage
          ] ++ pkgs.lib.optionals pkgs.stdenv.isLinux [
            pkgs.bubblewrap
          ];

          shellHook = ''
            echo "PROJECTNAME dev shell ready"
          '';
        };
      }
    );
}
