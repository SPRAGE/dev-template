{
  description = "dev-template — project scaffolding with Nix + Claude Code + Ruflo";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    ruflo-nix = {
      url = "github:SPRAGE/ruflo-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    claude-code = {
      url = "github:sadjow/claude-code-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, flake-utils, ruflo-nix, claude-code, ... }:
    {
      templates = {
        default = {
          path = ./template;
          description = "Base project with Nix devShell, Ruflo, direnv, Claude Code config";
        };

        rust = {
          path = ./templates/rust;
          description = "Rust project with rust-overlay, Ruflo, cargo tools, Claude Code config";
        };

        python = {
          path = ./templates/python;
          description = "Python project with uv, Ruflo, Claude Code config";
        };
      };
    }
    //
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfreePredicate = pkg:
            builtins.elem (nixpkgs.lib.getName pkg) [ "claude-code" ];
          overlays = [
            ruflo-nix.overlays.default
            claude-code.overlays.default
          ];
        };
      in
      {
        devShells.default = pkgs.mkShell {
          packages = [
            pkgs.git
            pkgs.ruflo
            pkgs.claude-code
          ];

          shellHook = ''
            echo "dev-template — use 'nix flake init -t .' to test templates locally"
          '';
        };
      }
    );
}
