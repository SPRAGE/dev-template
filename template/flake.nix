{
  description = "PROJECTNAME";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    ruflo-nix = {
      # SECURITY: Pin to a specific rev for production use
      # url = "github:SPRAGE/ruflo-nix/<rev>";
      url = "github:SPRAGE/ruflo-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    claude-code = {
      # SECURITY: Pin to a specific rev for production use
      # url = "github:sadjow/claude-code-nix/<rev>";
      url = "github:sadjow/claude-code-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, flake-utils, ruflo-nix, claude-code, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
      in
      {
        devShells.default = pkgs.mkShell {
          packages = [
            claude-code.packages.${system}.default
            ruflo-nix.packages.${system}.default
            # TODO: add project dependencies
          ];

          shellHook = ''
            echo "PROJECTNAME dev shell ready"
          '';
        };
      }
    );
}
