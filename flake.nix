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
          description = "Base project with Nix devShell, Claude Code, Ruflo, direnv";
        };

        rust = {
          path = ./templates/rust;
          description = "Rust project with rust-overlay, Claude Code, Ruflo, cargo tools";
        };

        python = {
          path = ./templates/python;
          description = "Python project with uv, Claude Code, Ruflo";
        };
      };
    }
    //
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
      in
      {
        devShells.default = pkgs.mkShell {
          packages = [
            pkgs.git
            claude-code.packages.${system}.default
            ruflo-nix.packages.${system}.default
          ];

          shellHook = ''
            echo "dev-template — use 'nix flake init -t .' to test templates locally"
          '';
        };

        apps.sync-skills =
          let
            skills-src = ./template/.claude/skills;
            script = pkgs.writeShellScriptBin "sync-skills" ''
              set -euo pipefail

              SOURCE="${skills-src}"
              TARGET="$PWD/.claude/skills"

              if [ ! -d "$PWD/.claude" ] && [ ! -f "$PWD/flake.nix" ]; then
                echo "error: no .claude/ directory or flake.nix found here"
                echo "Run this from your project root."
                exit 1
              fi

              mkdir -p "$TARGET"

              echo "sync-skills: syncing from dev-template"
              echo ""

              count_added=0
              count_updated=0
              count_unchanged=0

              for skill_dir in "$SOURCE"/*/; do
                [ -d "$skill_dir" ] || continue
                skill_name=$(basename "$skill_dir")

                if [ -d "$TARGET/$skill_name" ]; then
                  if ! diff -rq "$SOURCE/$skill_name" "$TARGET/$skill_name" >/dev/null 2>&1; then
                    rm -rf "$TARGET/$skill_name"
                    cp -rL "$SOURCE/$skill_name" "$TARGET/$skill_name"
                    chmod -R u+w "$TARGET/$skill_name"
                    echo "  ~ $skill_name (updated)"
                    count_updated=$((count_updated + 1))
                  else
                    echo "  = $skill_name (up to date)"
                    count_unchanged=$((count_unchanged + 1))
                  fi
                else
                  cp -rL "$SOURCE/$skill_name" "$TARGET/$skill_name"
                  chmod -R u+w "$TARGET/$skill_name"
                  echo "  + $skill_name (added)"
                  count_added=$((count_added + 1))
                fi
              done

              echo ""
              echo "Done: $count_added added, $count_updated updated, $count_unchanged unchanged"
            '';
          in
          {
            type = "app";
            program = "${script}/bin/sync-skills";
          };
      }
    );
}
