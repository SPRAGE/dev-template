{
  description = "PROJECTNAME";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
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
    dev-template = {
      url = "github:SPRAGE/dev-template";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, rust-overlay, flake-utils, ruflo-nix, claude-code, dev-template, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        overlays = [ (import rust-overlay) ];
        pkgs = import nixpkgs { inherit system overlays; };

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
            claude-code.packages.${system}.default
            ruflo-nix.packages.${system}.default
          ];

          env = {
            RUST_BACKTRACE = "1";
            PKG_CONFIG_PATH = "${pkgs.openssl.dev}/lib/pkgconfig";
          };

          shellHook = ''
            # Auto-sync skills from dev-template
            _src="${dev-template}/template/.claude/skills"
            _dst="$PWD/.claude/skills"
            if [ -d "$_src" ]; then
              mkdir -p "$_dst"
              _n=0
              for _d in "$_src"/*/; do
                [ -d "$_d" ] || continue
                _s=$(basename "$_d")
                if [ ! -d "$_dst/$_s" ] || ! diff -rq "$_src/$_s" "$_dst/$_s" >/dev/null 2>&1; then
                  rm -rf "$_dst/$_s"
                  cp -rL "$_src/$_s" "$_dst/$_s"
                  chmod -R u+w "$_dst/$_s"
                  _n=$((_n + 1))
                fi
              done
              [ "$_n" -gt 0 ] && echo "synced $_n skill(s) from dev-template"
            fi
            echo "PROJECTNAME dev shell ready"
            echo "Rust: $(rustc --version)"
          '';
        };
      }
    );
}
