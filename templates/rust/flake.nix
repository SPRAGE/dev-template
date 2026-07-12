{
  description = "PROJECTNAME";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    flake-utils.url = "github:numtide/flake-utils";
    claude-code = {
      # SECURITY: Pin to a specific rev for production use
      # url = "github:sadjow/claude-code-nix/<rev>";
      url = "github:sadjow/claude-code-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    custom-codex-release.url = "git+ssh://pai@192.168.0.7/srv/git/custom-codex-release.git?ref=latest";
  };

  outputs = { self, nixpkgs, rust-overlay, flake-utils, claude-code, custom-codex-release, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        overlays = [ (import rust-overlay) ];
        pkgs = import nixpkgs { inherit system overlays; };
        agentPython = pkgs.python3.withPackages (ps: [ ps.pyyaml ]);
        codexPackage = custom-codex-release.packages.${system}.codex or pkgs.codex;

        rustToolchain = pkgs.rust-bin.stable.latest.default.override {
          extensions = [
            "rust-src"
            "rust-analyzer"
            "clippy"
            "rustfmt"
          ];
        };
      in
      {
        devShells.default = pkgs.mkShell {
          buildInputs = [
            rustToolchain
            pkgs.pkg-config
            pkgs.openssl
            pkgs.cargo-edit
            pkgs.cargo-watch
            pkgs.git
            pkgs.ripgrep
            pkgs.fd
            pkgs.jq
            pkgs.tree
            pkgs.just
            agentPython
            claude-code.packages.${system}.default
            codexPackage
          ] ++ pkgs.lib.optionals pkgs.stdenv.isLinux [
            pkgs.bubblewrap
          ];

          env = {
            RUST_BACKTRACE = "1";
            PKG_CONFIG_PATH = "${pkgs.openssl.dev}/lib/pkgconfig";
          };

          shellHook = ''
            echo "PROJECTNAME dev shell ready"
          '';
        };
      }
    );
}
