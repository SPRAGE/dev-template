{
  description = "PROJECTNAME";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    # Prebuilt official release retained on the dataserver.
    # Refresh explicitly with: nix flake update codex-release
    codex-release.url = "git+ssh://pai@192.168.0.7/srv/git/codex-release.git?ref=latest";
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
  };

  outputs = { self, nixpkgs, codex-release, rust-overlay, flake-utils, claude-code, ... }:
    flake-utils.lib.eachSystem [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" ] (system:
      let
        overlays = [ (import rust-overlay) ];
        pkgs = import nixpkgs { inherit system overlays; };
        agentPython = pkgs.python3.withPackages (ps: [ ps.pyyaml ]);
        codexPackage =
          if system == "x86_64-linux" then
            codex-release.packages.${system}.default
          else
            pkgs.codex;

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
          ] ++ pkgs.lib.optionals pkgs.stdenv.hostPlatform.isLinux [
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
