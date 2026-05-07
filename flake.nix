{
  description = "dev-template — project scaffolding with Nix + Claude Code";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    claude-code = {
      url = "github:sadjow/claude-code-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, flake-utils, claude-code, ... }:
    {
      templates = {
        default = {
          path = ./template;
          description = "Base project with Nix devShell, Claude Code, direnv";
        };

        rust = {
          path = ./templates/rust;
          description = "Rust project with rust-overlay, Claude Code, cargo tools";
        };

        python = {
          path = ./templates/python;
          description = "Python project with uv, Claude Code";
        };
      };
    }
    //
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
      in
      rec {
        devShells.default = pkgs.mkShell {
          packages = [
            pkgs.git
            pkgs.ripgrep
            pkgs.fd
            pkgs.jq
            pkgs.tree
            pkgs.zip
            pkgs.unzip
            (pkgs.python3.withPackages (ps: [ ps.pyyaml ]))
            claude-code.packages.${system}.default
            pkgs.codex
          ];

          shellHook = ''
            echo "dev-template — use 'nix flake init -t .' to test templates locally"
          '';
        };

        apps.sync-skills =
          let
            skills-src = ./template/.claude/skills;
            hooks-src = ./template/.claude/hooks;
            ai-src = ./template/.ai;
            agents-md-src = ./template/AGENTS.md;
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

              # Sync hooks (always overwrite — hooks are template-owned)
              HOOKS_SOURCE="${hooks-src}"
              HOOKS_TARGET="$PWD/.claude/hooks"
              if [ -d "$HOOKS_SOURCE" ] && [ "$(ls -A "$HOOKS_SOURCE" 2>/dev/null)" ]; then
                mkdir -p "$HOOKS_TARGET"
                echo ""
                echo "sync-skills: syncing hooks"
                hooks_added=0
                hooks_updated=0
                hooks_unchanged=0
                for hook_file in "$HOOKS_SOURCE"/*; do
                  [ -f "$hook_file" ] || continue
                  hook_name=$(basename "$hook_file")
                  [ "$hook_name" = ".gitkeep" ] && continue
                  if [ -f "$HOOKS_TARGET/$hook_name" ]; then
                    if ! diff -q "$HOOKS_SOURCE/$hook_name" "$HOOKS_TARGET/$hook_name" >/dev/null 2>&1; then
                      cp -L "$HOOKS_SOURCE/$hook_name" "$HOOKS_TARGET/$hook_name"
                      chmod u+w "$HOOKS_TARGET/$hook_name"
                      chmod +x "$HOOKS_TARGET/$hook_name"
                      echo "  ~ $hook_name (updated)"
                      hooks_updated=$((hooks_updated + 1))
                    else
                      echo "  = $hook_name (up to date)"
                      hooks_unchanged=$((hooks_unchanged + 1))
                    fi
                  else
                    cp -L "$HOOKS_SOURCE/$hook_name" "$HOOKS_TARGET/$hook_name"
                    chmod u+w "$HOOKS_TARGET/$hook_name"
                    chmod +x "$HOOKS_TARGET/$hook_name"
                    echo "  + $hook_name (added)"
                    hooks_added=$((hooks_added + 1))
                  fi
                done
              fi

              # Sync provider-neutral AI context templates (never overwrite populated files)
              AI_SOURCE="${ai-src}"
              AI_TARGET="$PWD/.ai"
              ai_added=0
              ai_skipped=0
              if [ -d "$AI_SOURCE" ]; then
                mkdir -p "$AI_TARGET/context"
                echo ""
                echo "sync-skills: syncing AI context templates"

                if [ -f "$AI_SOURCE/instructions.md" ]; then
                  if [ -f "$AI_TARGET/instructions.md" ]; then
                    echo "  = .ai/instructions.md (exists, not overwriting)"
                    ai_skipped=$((ai_skipped + 1))
                  else
                    cp -L "$AI_SOURCE/instructions.md" "$AI_TARGET/instructions.md"
                    chmod u+w "$AI_TARGET/instructions.md"
                    echo "  + .ai/instructions.md (added)"
                    ai_added=$((ai_added + 1))
                  fi
                fi

                for context_file in "$AI_SOURCE/context"/*; do
                  [ -f "$context_file" ] || continue
                  context_name=$(basename "$context_file")
                  if [ -f "$AI_TARGET/context/$context_name" ]; then
                    echo "  = .ai/context/$context_name (exists, not overwriting)"
                    ai_skipped=$((ai_skipped + 1))
                  else
                    cp -L "$context_file" "$AI_TARGET/context/$context_name"
                    chmod u+w "$AI_TARGET/context/$context_name"
                    echo "  + .ai/context/$context_name (added)"
                    ai_added=$((ai_added + 1))
                  fi
                done

                if [ -f "$AI_SOURCE/context/.gitignore" ]; then
                  if [ -f "$AI_TARGET/context/.gitignore" ]; then
                    echo "  = .ai/context/.gitignore (exists, not overwriting)"
                    ai_skipped=$((ai_skipped + 1))
                  else
                    cp -L "$AI_SOURCE/context/.gitignore" "$AI_TARGET/context/.gitignore"
                    chmod u+w "$AI_TARGET/context/.gitignore"
                    echo "  + .ai/context/.gitignore (added)"
                    ai_added=$((ai_added + 1))
                  fi
                fi
              fi

              # Seed cross-agent instructions (never overwrite project guidance)
              AGENTS_SOURCE="${agents-md-src}"
              agent_added=0
              agent_skipped=0
              if [ -f "$AGENTS_SOURCE" ]; then
                echo ""
                echo "sync-skills: checking agent instructions"
                if [ -f "$PWD/AGENTS.md" ]; then
                  echo "  = AGENTS.md (exists, not overwriting)"
                  agent_skipped=1
                else
                  cp -L "$AGENTS_SOURCE" "$PWD/AGENTS.md"
                  chmod u+w "$PWD/AGENTS.md"
                  echo "  + AGENTS.md (added)"
                  agent_added=1
                fi
              fi

              echo ""
              echo "Done: skills: $count_added added, $count_updated updated, $count_unchanged unchanged | hooks: ''${hooks_added:-0} added, ''${hooks_updated:-0} updated, ''${hooks_unchanged:-0} unchanged | AI context: $ai_added added, $ai_skipped skipped | AGENTS.md: $agent_added added, $agent_skipped skipped"
            '';
          in
          {
            type = "app";
            program = "${script}/bin/sync-skills";
            meta = {
              description = "Sync dev-template Claude Code skills, hooks, and provider-neutral AI context templates into a project";
            };
          };

        apps.fresh-start =
          let
            skills-src = ./template/.claude/skills;
            ai-src = ./template/.ai;
            hooks-src = ./template/.claude/hooks;
            settings-src = ./template/.claude/settings.json;
            mcp-src = ./template/.mcp.json;
            claude-md-src = ./template/CLAUDE.md;
            agents-md-src = ./template/AGENTS.md;
            script = pkgs.writeShellScriptBin "fresh-start" ''
              set -euo pipefail

              # Must be run from a project root
              if [ ! -f "$PWD/flake.nix" ] && [ ! -d "$PWD/.git" ] && [ ! -f "$PWD/package.json" ] && [ ! -f "$PWD/Cargo.toml" ] && [ ! -f "$PWD/pyproject.toml" ] && [ ! -f "$PWD/go.mod" ]; then
                echo "error: no project root indicators found (flake.nix, .git, package.json, Cargo.toml, pyproject.toml, go.mod)"
                echo "Run this from your project root."
                exit 1
              fi

              # Sanitize CWD for auto-memory path (replaces / with -)
              sanitized_cwd=$(echo "$PWD" | sed 's|/|-|g')
              memory_dir="$HOME/.claude/projects/$sanitized_cwd"

              echo "fresh-start: This will REMOVE ALL AI and Claude Code configuration and re-sync from template."
              echo ""
              echo "  Targets:"
              [ -d "$PWD/.ai" ]            && echo "    .ai/                  (shared AI instructions and context)"
              [ -d "$PWD/.claude" ]        && echo "    .claude/              (Claude Code skills, hooks, settings, rules)"
              [ -f "$PWD/CLAUDE.md" ]      && echo "    CLAUDE.md"
              [ -f "$PWD/AGENTS.md" ]      && echo "    AGENTS.md"
              [ -f "$PWD/.mcp.json" ]      && echo "    .mcp.json"
              [ -f "$PWD/.claude.local.md" ] && echo "    .claude.local.md"
              [ -d "$memory_dir" ]         && echo "    $memory_dir/ (preserved)"
              echo ""
              printf "  Continue? [y/N] "
              read -r confirm
              case "$confirm" in
                [yY]) ;;
                *) echo "Aborted."; exit 0 ;;
              esac

              echo ""

              # === NUKE PHASE ===
              echo "Removing AI and Claude Code configuration..."

              if [ -d "$PWD/.ai" ]; then
                rm -rf "$PWD/.ai"
                echo "  - .ai/"
              fi

              if [ -d "$PWD/.claude" ]; then
                rm -rf "$PWD/.claude"
                echo "  - .claude/"
              fi

              if [ -f "$PWD/CLAUDE.md" ]; then
                rm -f "$PWD/CLAUDE.md"
                echo "  - CLAUDE.md"
              fi

              if [ -f "$PWD/AGENTS.md" ]; then
                rm -f "$PWD/AGENTS.md"
                echo "  - AGENTS.md"
              fi

              if [ -f "$PWD/.mcp.json" ]; then
                rm -f "$PWD/.mcp.json"
                echo "  - .mcp.json"
              fi

              if [ -f "$PWD/.claude.local.md" ]; then
                rm -f "$PWD/.claude.local.md"
                echo "  - .claude.local.md"
              fi

              if [ -d "$memory_dir" ]; then
                echo "  = auto-memory preserved ($memory_dir/)"
              fi

              echo ""

              # === RESTORE PHASE ===
              echo "Restoring from template..."

              # Provider-neutral AI context
              mkdir -p "$PWD/.ai"
              cp -rL "${ai-src}/." "$PWD/.ai/"
              chmod -R u+w "$PWD/.ai"
              echo "  + .ai/"

              # Settings
              mkdir -p "$PWD/.claude"
              cp -L "${settings-src}" "$PWD/.claude/settings.json"
              chmod u+w "$PWD/.claude/settings.json"
              echo "  + .claude/settings.json"

              # Hooks
              mkdir -p "$PWD/.claude/hooks"
              for f in "${hooks-src}"/*; do
                [ -f "$f" ] || continue
                fname=$(basename "$f")
                [ "$fname" = ".gitkeep" ] && continue
                cp -L "$f" "$PWD/.claude/hooks/$fname"
                chmod u+w "$PWD/.claude/hooks/$fname"
                chmod +x "$PWD/.claude/hooks/$fname"
              done
              echo "  + .claude/hooks/"

              # Skills
              mkdir -p "$PWD/.claude/skills"
              for skill_dir in "${skills-src}"/*/; do
                [ -d "$skill_dir" ] || continue
                skill_name=$(basename "$skill_dir")
                cp -rL "$skill_dir" "$PWD/.claude/skills/$skill_name"
                chmod -R u+w "$PWD/.claude/skills/$skill_name"
              done
              skill_count=$(ls -d "$PWD/.claude/skills"/*/ 2>/dev/null | wc -l)
              echo "  + .claude/skills/ ($skill_count skills)"

              # .mcp.json
              cp -L "${mcp-src}" "$PWD/.mcp.json"
              chmod u+w "$PWD/.mcp.json"
              echo "  + .mcp.json"

              # CLAUDE.md
              cp -L "${claude-md-src}" "$PWD/CLAUDE.md"
              chmod u+w "$PWD/CLAUDE.md"
              echo "  + CLAUDE.md (template stub)"

              # AGENTS.md
              cp -L "${agents-md-src}" "$PWD/AGENTS.md"
              chmod u+w "$PWD/AGENTS.md"
              echo "  + AGENTS.md"

              echo ""
              echo "Fresh start complete. Read .ai/instructions.md, then open Claude Code or Codex. In Claude Code, run /cc-setup for Claude-specific setup."
            '';
          in
          {
            type = "app";
            program = "${script}/bin/fresh-start";
            meta = {
              description = "Reset shared AI context and Claude Code config in a project and restore dev-template defaults";
            };
          };

        apps.onboard =
          let
            skills-src = ./template/.claude/skills;
            ai-src = ./template/.ai;
            hooks-src = ./template/.claude/hooks;
            settings-src = ./template/.claude/settings.json;
            mcp-src = ./template/.mcp.json;
            claude-md-src = ./template/CLAUDE.md;
            agents-md-src = ./template/AGENTS.md;
            script = pkgs.writeShellScriptBin "onboard" ''
              set -euo pipefail

              # Must be run from a project root
              if [ ! -f "$PWD/flake.nix" ] && [ ! -d "$PWD/.git" ] && [ ! -f "$PWD/package.json" ] && [ ! -f "$PWD/Cargo.toml" ] && [ ! -f "$PWD/pyproject.toml" ] && [ ! -f "$PWD/go.mod" ]; then
                echo "error: no project root indicators found (flake.nix, .git, package.json, Cargo.toml, pyproject.toml, go.mod)"
                echo "Run this from your project root."
                exit 1
              fi

              # Detect state — if already onboarded, suggest refresh instead
              if [ -d "$PWD/.claude/skills" ] && [ -f "$PWD/CLAUDE.md" ] && [ -f "$PWD/AGENTS.md" ] && [ -f "$PWD/.ai/context/active-context.md" ]; then
                echo "This project appears already onboarded (.ai/context, .claude/skills, AGENTS.md, and CLAUDE.md exist)."
                echo "Run /cc-refresh inside Claude Code to update existing configuration."
                echo "Or run 'nix run .#fresh-start' to nuke and re-sync from template."
                exit 0
              fi

              # Full bootstrap
              echo "onboard: bootstrapping shared AI context and Claude Code for this project"
              echo ""

              # Provider-neutral AI context
              mkdir -p "$PWD/.ai/context"
              if [ -f "${ai-src}/instructions.md" ]; then
                if [ -f "$PWD/.ai/instructions.md" ]; then
                  echo "  = .ai/instructions.md (already exists, skipped)"
                else
                  cp -L "${ai-src}/instructions.md" "$PWD/.ai/instructions.md"
                  chmod u+w "$PWD/.ai/instructions.md"
                  echo "  + .ai/instructions.md"
                fi
              fi
              for f in "${ai-src}/context"/*; do
                [ -f "$f" ] || continue
                fname=$(basename "$f")
                if [ -f "$PWD/.ai/context/$fname" ]; then
                  echo "  = .ai/context/$fname (already exists, skipped)"
                else
                  cp -L "$f" "$PWD/.ai/context/$fname"
                  chmod u+w "$PWD/.ai/context/$fname"
                  echo "  + .ai/context/$fname"
                fi
              done
              if [ -f "${ai-src}/context/.gitignore" ]; then
                if [ -f "$PWD/.ai/context/.gitignore" ]; then
                  echo "  = .ai/context/.gitignore (already exists, skipped)"
                else
                  cp -L "${ai-src}/context/.gitignore" "$PWD/.ai/context/.gitignore"
                  chmod u+w "$PWD/.ai/context/.gitignore"
                  echo "  + .ai/context/.gitignore"
                fi
              fi

              # .claude/ directory
              mkdir -p "$PWD/.claude"

              # Settings
              if [ ! -f "$PWD/.claude/settings.json" ]; then
                cp -L "${settings-src}" "$PWD/.claude/settings.json"
                chmod u+w "$PWD/.claude/settings.json"
                echo "  + .claude/settings.json"
              else
                echo "  = .claude/settings.json (already exists, skipped)"
              fi

              # Hooks
              mkdir -p "$PWD/.claude/hooks"
              for f in "${hooks-src}"/*; do
                [ -f "$f" ] || continue
                fname=$(basename "$f")
                [ "$fname" = ".gitkeep" ] && continue
                cp -L "$f" "$PWD/.claude/hooks/$fname"
                chmod u+w "$PWD/.claude/hooks/$fname"
                chmod +x "$PWD/.claude/hooks/$fname"
                echo "  + .claude/hooks/$fname"
              done

              # Skills
              mkdir -p "$PWD/.claude/skills"
              skill_count=0
              for skill_dir in "${skills-src}"/*/; do
                [ -d "$skill_dir" ] || continue
                skill_name=$(basename "$skill_dir")
                if [ -d "$PWD/.claude/skills/$skill_name" ]; then
                  if ! diff -rq "$skill_dir" "$PWD/.claude/skills/$skill_name" >/dev/null 2>&1; then
                    rm -rf "$PWD/.claude/skills/$skill_name"
                    cp -rL "$skill_dir" "$PWD/.claude/skills/$skill_name"
                    chmod -R u+w "$PWD/.claude/skills/$skill_name"
                    echo "  ~ .claude/skills/$skill_name (updated)"
                  else
                    echo "  = .claude/skills/$skill_name (up to date)"
                  fi
                else
                  cp -rL "$skill_dir" "$PWD/.claude/skills/$skill_name"
                  chmod -R u+w "$PWD/.claude/skills/$skill_name"
                  echo "  + .claude/skills/$skill_name"
                fi
                skill_count=$((skill_count + 1))
              done
              echo "  = .claude/skills/ ($skill_count skills available)"

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
                echo "  + CLAUDE.md (stub — run /cc-setup to populate)"
              else
                echo "  = CLAUDE.md (already exists, skipped)"
              fi

              # AGENTS.md
              if [ ! -f "$PWD/AGENTS.md" ]; then
                cp -L "${agents-md-src}" "$PWD/AGENTS.md"
                chmod u+w "$PWD/AGENTS.md"
                echo "  + AGENTS.md (cross-agent guidance)"
              else
                echo "  = AGENTS.md (already exists, skipped)"
              fi

              echo ""
              echo "Bootstrap complete."
              echo ""
              echo "Next steps:"
              echo "  1. direnv allow          (if using direnv)"
              echo "  2. Read .ai/instructions.md"
              echo "  3. Open Claude Code or Codex"
              echo "  4. Run /cc-setup in Claude Code if you want Claude-specific setup"
            '';
          in
          {
            type = "app";
            program = "${script}/bin/onboard";
            meta = {
              description = "Bootstrap shared AI context and Claude Code config into an existing project";
            };
          };

        apps.ai-doctor =
          let
            script = pkgs.writeShellScriptBin "ai-doctor" ''
              set -euo pipefail

              JQ="${pkgs.jq}/bin/jq"
              failures=0
              warnings=0

              fail() {
                echo "FAIL: $*"
                failures=$((failures + 1))
              }

              warn() {
                echo "WARN: $*"
                warnings=$((warnings + 1))
              }

              pass() {
                echo "OK: $*"
              }

              check_json() {
                local file=$1
                if [ -f "$file" ]; then
                  if "$JQ" empty "$file" >/dev/null 2>&1; then
                    pass "$file is valid JSON"
                  else
                    fail "$file is not valid JSON"
                  fi
                else
                  warn "$file missing"
                fi
              }

              echo "ai-doctor: checking AI development context in $PWD"
              echo ""

              marker_found=0
              for marker in .git flake.nix package.json Cargo.toml pyproject.toml go.mod; do
                if [ -e "$PWD/$marker" ]; then
                  marker_found=1
                  break
                fi
              done

              if [ "$marker_found" -eq 1 ]; then
                pass "project root marker found"
              else
                warn "no common project root marker found"
              fi

              if [ -f CLAUDE.md ]; then
                pass "CLAUDE.md present"
              else
                warn "CLAUDE.md missing"
              fi

              if [ -f AGENTS.md ]; then
                pass "AGENTS.md present"
              else
                warn "AGENTS.md missing"
              fi

              check_json ".mcp.json"

              if [ -d .ai ]; then
                pass ".ai/ present"
                if [ -f .ai/instructions.md ]; then
                  pass ".ai/instructions.md present"
                else
                  fail ".ai/instructions.md missing"
                fi

                if [ -d .ai/context ]; then
                  pass ".ai/context/ present"
                  for file in active-context.md architecture-snapshot.md conventions.md decisions.md stale-log.md; do
                    if [ -f ".ai/context/$file" ]; then
                      pass ".ai/context/$file present"
                    else
                      fail ".ai/context/$file missing"
                    fi
                  done
                  if grep -R "TODO:" .ai/context >/dev/null 2>&1; then
                    warn ".ai/context still contains template TODOs"
                  fi
                else
                  fail ".ai/context/ missing"
                fi
              else
                fail ".ai/ missing"
              fi

              if [ -d .claude ]; then
                pass ".claude/ present"
                if [ -f .claude/settings.json ]; then
                  check_json ".claude/settings.json"
                else
                  fail ".claude/settings.json missing"
                fi

                if [ -d .claude/knowledge ]; then
                  warn ".claude/knowledge/ is legacy; .ai/context is the shared source of truth"
                fi

                if [ -d .claude/hooks ]; then
                  hook_count=0
                  for hook in .claude/hooks/*.sh; do
                    [ -e "$hook" ] || continue
                    hook_count=$((hook_count + 1))
                    if [ -x "$hook" ]; then
                      pass "$hook executable"
                    else
                      fail "$hook is not executable"
                    fi
                  done
                  [ "$hook_count" -gt 0 ] || warn ".claude/hooks has no shell hooks"
                else
                  warn ".claude/hooks/ missing"
                fi

                if [ -d .claude/skills ]; then
                  skill_count=0
                  for skill_dir in .claude/skills/*; do
                    [ -d "$skill_dir" ] || continue
                    skill_count=$((skill_count + 1))
                    if [ -f "$skill_dir/SKILL.md" ]; then
                      pass "$skill_dir has SKILL.md"
                    else
                      fail "$skill_dir missing SKILL.md"
                    fi
                  done
                  [ "$skill_count" -gt 0 ] || warn ".claude/skills has no skills"
                else
                  warn ".claude/skills/ missing"
                fi
              else
                warn ".claude/ missing"
              fi

              echo ""
              if [ "$failures" -gt 0 ]; then
                echo "ai-doctor failed: $failures failure(s), $warnings warning(s)."
                exit 1
              fi

              echo "ai-doctor passed: $warnings warning(s)."
            '';
          in
          {
            type = "app";
            program = "${script}/bin/ai-doctor";
            meta = {
              description = "Validate AI development context files, hooks, and skill layout in the current project";
            };
          };

        packages = {
          "sync-skills" = pkgs.runCommand "sync-skills" { } ''
            mkdir -p $out/bin
            ln -s ${apps.sync-skills.program} $out/bin/sync-skills
          '';
          "fresh-start" = pkgs.runCommand "fresh-start" { } ''
            mkdir -p $out/bin
            ln -s ${apps.fresh-start.program} $out/bin/fresh-start
          '';
          onboard = pkgs.runCommand "onboard" { } ''
            mkdir -p $out/bin
            ln -s ${apps.onboard.program} $out/bin/onboard
          '';
          "ai-doctor" = pkgs.runCommand "ai-doctor" { } ''
            mkdir -p $out/bin
            ln -s ${apps.ai-doctor.program} $out/bin/ai-doctor
          '';
        };
      }
    );
}
