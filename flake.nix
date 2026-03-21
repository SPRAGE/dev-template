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

        apps.onboard =
          let
            knowledge-src = ./template/.claude/knowledge;
            hooks-src = ./template/.claude/hooks;
            settings-src = ./template/.claude/settings.json;
            mcp-src = ./template/.mcp.json;
            claude-md-src = ./template/CLAUDE.md;
            script = pkgs.writeShellScriptBin "onboard" ''
              set -euo pipefail

              # Must be run from a project root
              if [ ! -f "$PWD/flake.nix" ] && [ ! -d "$PWD/.git" ] && [ ! -f "$PWD/package.json" ] && [ ! -f "$PWD/Cargo.toml" ] && [ ! -f "$PWD/pyproject.toml" ] && [ ! -f "$PWD/go.mod" ]; then
                echo "error: no project root indicators found (flake.nix, .git, package.json, Cargo.toml, pyproject.toml, go.mod)"
                echo "Run this from your project root."
                exit 1
              fi

              # Detect state
              if [ -d "$PWD/.claude/knowledge" ] && [ -f "$PWD/.claude/knowledge/active-context.md" ]; then
                # Check if knowledge files have been populated (not just templates)
                if grep -q "TEMPLATE" "$PWD/.claude/knowledge/active-context.md" 2>/dev/null; then
                  echo "Knowledge store exists but is unpopulated. Proceeding with bootstrap..."
                else
                  echo "This project appears already onboarded (.claude/knowledge/ exists with content)."
                  echo "Run /cc-refresh inside Claude Code to update existing configuration."
                  exit 0
                fi
              fi

              if [ -d "$PWD/.claude" ] && [ ! -d "$PWD/.claude/knowledge" ]; then
                echo "onboard: .claude/ exists but no knowledge store. Adding knowledge store + hooks..."
                echo ""

                # Knowledge store only
                mkdir -p "$PWD/.claude/knowledge"
                for f in "${knowledge-src}"/*; do
                  [ -f "$f" ] || continue
                  fname=$(basename "$f")
                  cp -L "$f" "$PWD/.claude/knowledge/$fname"
                  chmod u+w "$PWD/.claude/knowledge/$fname"
                done

                # Hooks
                mkdir -p "$PWD/.claude/hooks"
                for f in "${hooks-src}"/*; do
                  [ -f "$f" ] || continue
                  fname=$(basename "$f")
                  cp -L "$f" "$PWD/.claude/hooks/$fname"
                  chmod u+w "$PWD/.claude/hooks/$fname"
                  chmod +x "$PWD/.claude/hooks/$fname"
                done

                echo "Done. Knowledge store and hooks added."
                echo ""
                echo "Next: open Claude Code and run /cc-onboard to scan your codebase."
                exit 0
              fi

              # Full bootstrap
              echo "onboard: bootstrapping Claude Code for this project"
              echo ""

              # .claude/ directory
              mkdir -p "$PWD/.claude"

              # Settings
              cp -L "${settings-src}" "$PWD/.claude/settings.json"
              chmod u+w "$PWD/.claude/settings.json"
              echo "  + .claude/settings.json"

              # Knowledge store
              mkdir -p "$PWD/.claude/knowledge"
              for f in "${knowledge-src}"/*; do
                [ -f "$f" ] || continue
                fname=$(basename "$f")
                cp -L "$f" "$PWD/.claude/knowledge/$fname"
                chmod u+w "$PWD/.claude/knowledge/$fname"
                echo "  + .claude/knowledge/$fname"
              done

              # Hooks
              mkdir -p "$PWD/.claude/hooks"
              for f in "${hooks-src}"/*; do
                [ -f "$f" ] || continue
                fname=$(basename "$f")
                cp -L "$f" "$PWD/.claude/hooks/$fname"
                chmod u+w "$PWD/.claude/hooks/$fname"
                chmod +x "$PWD/.claude/hooks/$fname"
                echo "  + .claude/hooks/$fname"
              done

              # .mcp.json
              if [ ! -f "$PWD/.mcp.json" ]; then
                cp -L "${mcp-src}" "$PWD/.mcp.json"
                chmod u+w "$PWD/.mcp.json"
                echo "  + .mcp.json"
              else
                echo "  = .mcp.json (already exists, skipped)"
              fi

              # CLAUDE.md
              if [ ! -f "$PWD/CLAUDE.md" ]; then
                cp -L "${claude-md-src}" "$PWD/CLAUDE.md"
                chmod u+w "$PWD/CLAUDE.md"
                echo "  + CLAUDE.md (stub — run /cc-onboard to populate)"
              else
                echo "  = CLAUDE.md (already exists, skipped)"
              fi

              echo ""
              echo "Bootstrap complete."
              echo ""
              echo "Next steps:"
              echo "  1. direnv allow          (if using direnv)"
              echo "  2. Open Claude Code"
              echo "  3. Run /cc-onboard       (scans codebase and generates tailored config)"
            '';
          in
          {
            type = "app";
            program = "${script}/bin/onboard";
          };
      }
    );
}
