{
  description = "dev-template — project scaffolding with Nix + Claude Code and Codex";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    claude-code = {
      url = "github:sadjow/claude-code-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    custom-codex-release.url = "git+ssh://git@github.com/SPRAGE/custom-codex-release.git?ref=latest";
  };

  outputs = { self, nixpkgs, flake-utils, claude-code, custom-codex-release, ... }:
    {
      templates = {
        default = {
          path = ./template;
          description = "Base project with Nix devShell, Claude Code, Codex, direnv";
        };

        rust = {
          path = ./templates/rust;
          description = "Rust project with rust-overlay, Claude Code, Codex, cargo tools";
        };

        python = {
          path = ./templates/python;
          description = "Python project with uv, Claude Code, Codex";
        };
      };
    }
    //
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
        codexPackage = custom-codex-release.packages.${system}.codex;
      in
      rec {
        devShells.default = pkgs.mkShell {
          packages = [
            pkgs.git
            pkgs.ripgrep
            pkgs.fd
            pkgs.jq
            pkgs.tree
            pkgs.just
            pkgs.zip
            pkgs.unzip
            (pkgs.python3.withPackages (ps: [ ps.pyyaml ]))
            claude-code.packages.${system}.default
            codexPackage
          ] ++ pkgs.lib.optionals pkgs.stdenv.isLinux [
            pkgs.bubblewrap
          ];

          shellHook = ''
            echo "dev-template — use 'nix flake init -t .' to test templates locally"
          '';
        };

        apps.sync-skills =
          let
            skills-src = ./template/.ai/skills;
            hooks-src = ./template/.claude/hooks;
            codex-src = ./template/.codex;
            agents-src = ./template/.agents;
            ai-src = ./template/.ai;
            ai-md-src = ./template/AI.md;
            claude-md-src = ./template/CLAUDE.md;
            agents-md-src = ./template/AGENTS.md;
            codex-md-src = ./template/CODEX.md;
            script = pkgs.writeShellScriptBin "sync-skills" ''
              set -euo pipefail

              SOURCE="${skills-src}"

              marker_found=0
              for marker in .git flake.nix package.json Cargo.toml pyproject.toml go.mod; do
                if [ -e "$PWD/$marker" ]; then
                  marker_found=1
                  break
                fi
              done

              if [ "$marker_found" -ne 1 ]; then
                echo "error: no project root indicators found (flake.nix, .git, package.json, Cargo.toml, pyproject.toml, go.mod)"
                echo "Run this from your project root."
                exit 1
              fi

              echo "sync-skills: syncing from dev-template"
              echo ""

              # Sync shared skill catalog for Codex-compatible and future agents.
              SHARED_SKILLS_TARGET="$PWD/.ai/skills"
              mkdir -p "$SHARED_SKILLS_TARGET"

              echo "sync-skills: syncing shared agent skills"
              shared_added=0
              shared_updated=0
              shared_unchanged=0

              for skill_dir in "$SOURCE"/*/; do
                [ -d "$skill_dir" ] || continue
                skill_name=$(basename "$skill_dir")

                if [ -d "$SHARED_SKILLS_TARGET/$skill_name" ]; then
                  if ! diff -rq "$SOURCE/$skill_name" "$SHARED_SKILLS_TARGET/$skill_name" >/dev/null 2>&1; then
                    rm -rf "$SHARED_SKILLS_TARGET/$skill_name"
                    cp -rL "$SOURCE/$skill_name" "$SHARED_SKILLS_TARGET/$skill_name"
                    chmod -R u+w "$SHARED_SKILLS_TARGET/$skill_name"
                    echo "  ~ $skill_name (updated)"
                    shared_updated=$((shared_updated + 1))
                  else
                    echo "  = $skill_name (up to date)"
                    shared_unchanged=$((shared_unchanged + 1))
                  fi
                else
                  cp -rL "$SOURCE/$skill_name" "$SHARED_SKILLS_TARGET/$skill_name"
                  chmod -R u+w "$SHARED_SKILLS_TARGET/$skill_name"
                  echo "  + $skill_name (added)"
                  shared_added=$((shared_added + 1))
                fi
              done

              link_skill_view() {
                target="$1"
                label="$2"
                link_target="../.ai/skills"
                link_added=0
                link_updated=0
                link_unchanged=0
                link_skipped=0

                mkdir -p "$(dirname "$target")"
                if [ -L "$target" ]; then
                  current=$(readlink "$target")
                  if [ "$current" = "$link_target" ]; then
                    echo "  = $label -> $link_target (linked)"
                    link_unchanged=1
                    return 0
                  fi
                  rm -f "$target"
                  ln -s "$link_target" "$target"
                  echo "  ~ $label -> $link_target (relinked)"
                  link_updated=1
                  return 0
                fi

                if [ -d "$target" ]; then
                  can_convert=1
                  for skill_dir in "$target"/*/; do
                    [ -d "$skill_dir" ] || continue
                    skill_name=$(basename "$skill_dir")
                    if [ ! -d "$SHARED_SKILLS_TARGET/$skill_name" ]; then
                      cp -rL "$skill_dir" "$SHARED_SKILLS_TARGET/$skill_name"
                      chmod -R u+w "$SHARED_SKILLS_TARGET/$skill_name"
                      echo "  + .ai/skills/$skill_name (migrated from $label)"
                    elif ! diff -rq "$skill_dir" "$SHARED_SKILLS_TARGET/$skill_name" >/dev/null 2>&1; then
                      echo "  = $label/$skill_name differs from .ai/skills/$skill_name; not converting $label"
                      can_convert=0
                    else
                      :
                    fi
                  done
                  if [ "$can_convert" -eq 1 ]; then
                    rm -rf "$target"
                    ln -s "$link_target" "$target"
                    echo "  ~ $label -> $link_target (deduplicated)"
                    link_updated=1
                  else
                    link_skipped=1
                  fi
                  return 0
                fi

                if [ -e "$target" ]; then
                  echo "  = $label (customized file, not replacing with link)"
                  link_skipped=1
                  return 0
                fi

                ln -s "$link_target" "$target"
                echo "  + $label -> $link_target (linked)"
                link_added=1
              }

              echo ""
              echo "sync-skills: linking provider skill views"
              agents_skill_added=0
              agents_skill_updated=0
              agents_skill_unchanged=0
              agents_skill_skipped=0
              claude_added=0
              claude_updated=0
              claude_unchanged=0
              claude_skipped=0
              codex_added=0
              codex_updated=0
              codex_unchanged=0
              codex_skipped=0

              link_skill_view "$PWD/.agents/skills" ".agents/skills"
              agents_skill_added=$link_added
              agents_skill_updated=$link_updated
              agents_skill_unchanged=$link_unchanged
              agents_skill_skipped=$link_skipped

              AGENTS_CONFIG_SOURCE="${agents-src}"
              agents_readme_added=0
              agents_readme_updated=0
              agents_readme_unchanged=0
              agents_readme_skipped=0
              if [ -f "$AGENTS_CONFIG_SOURCE/README.md" ]; then
                if [ ! -f "$PWD/.agents/README.md" ]; then
                  cp -L "$AGENTS_CONFIG_SOURCE/README.md" "$PWD/.agents/README.md"
                  chmod u+w "$PWD/.agents/README.md"
                  echo "  + .agents/README.md (added)"
                  agents_readme_added=1
                elif cmp -s "$AGENTS_CONFIG_SOURCE/README.md" "$PWD/.agents/README.md"; then
                  echo "  = .agents/README.md (up to date)"
                  agents_readme_unchanged=1
                elif grep -Eq "Codex Skill (Mirror|Link)" "$PWD/.agents/README.md" 2>/dev/null; then
                  cp -L "$AGENTS_CONFIG_SOURCE/README.md" "$PWD/.agents/README.md"
                  chmod u+w "$PWD/.agents/README.md"
                  echo "  ~ .agents/README.md (updated)"
                  agents_readme_updated=1
                else
                  echo "  = .agents/README.md (customized, not overwriting)"
                  agents_readme_skipped=1
                fi
              fi

              link_skill_view "$PWD/.claude/skills" ".claude/skills"
              claude_added=$link_added
              claude_updated=$link_updated
              claude_unchanged=$link_unchanged
              claude_skipped=$link_skipped

              link_skill_view "$PWD/.codex/skills" ".codex/skills"
              codex_added=$link_added
              codex_updated=$link_updated
              codex_unchanged=$link_unchanged
              codex_skipped=$link_skipped

              CODEX_SOURCE="${codex-src}"
              codex_readme_added=0
              codex_readme_updated=0
              codex_readme_unchanged=0
              codex_readme_skipped=0
              if [ -f "$CODEX_SOURCE/README.md" ]; then
                if [ ! -f "$PWD/.codex/README.md" ]; then
                  cp -L "$CODEX_SOURCE/README.md" "$PWD/.codex/README.md"
                  chmod u+w "$PWD/.codex/README.md"
                  echo "  + README.md (added)"
                  codex_readme_added=1
                elif cmp -s "$CODEX_SOURCE/README.md" "$PWD/.codex/README.md"; then
                  echo "  = README.md (up to date)"
                  codex_readme_unchanged=1
                elif grep -Eq "Codex (Runtime Mirror|Project Config)" "$PWD/.codex/README.md" 2>/dev/null; then
                  cp -L "$CODEX_SOURCE/README.md" "$PWD/.codex/README.md"
                  chmod u+w "$PWD/.codex/README.md"
                  echo "  ~ README.md (updated)"
                  codex_readme_updated=1
                else
                  echo "  = README.md (customized, not overwriting)"
                  codex_readme_skipped=1
                fi
              fi

              codex_config_added=0
              codex_config_updated=0
              codex_config_unchanged=0
              codex_config_skipped=0
              if [ -f "$CODEX_SOURCE/config.toml" ]; then
                if [ ! -f "$PWD/.codex/config.toml" ]; then
                  cp -L "$CODEX_SOURCE/config.toml" "$PWD/.codex/config.toml"
                  chmod u+w "$PWD/.codex/config.toml"
                  echo "  + config.toml (added)"
                  codex_config_added=1
                elif cmp -s "$CODEX_SOURCE/config.toml" "$PWD/.codex/config.toml"; then
                  echo "  = config.toml (up to date)"
                  codex_config_unchanged=1
                elif grep -q "Project-scoped Codex config generated by dev-template" "$PWD/.codex/config.toml" 2>/dev/null; then
                  cp -L "$CODEX_SOURCE/config.toml" "$PWD/.codex/config.toml"
                  chmod u+w "$PWD/.codex/config.toml"
                  echo "  ~ config.toml (updated)"
                  codex_config_updated=1
                else
                  echo "  = config.toml (customized, not overwriting)"
                  codex_config_skipped=1
                fi
              fi

              codex_agents_added=0
              codex_agents_updated=0
              codex_agents_unchanged=0
              codex_agents_skipped=0
              if [ -d "$CODEX_SOURCE/agents" ]; then
                mkdir -p "$PWD/.codex/agents"
                echo ""
                echo "sync-skills: syncing Codex custom agents"
                for agent_file in "$CODEX_SOURCE/agents"/*.toml; do
                  [ -f "$agent_file" ] || continue
                  agent_name=$(basename "$agent_file")
                  target="$PWD/.codex/agents/$agent_name"
                  if [ ! -f "$target" ]; then
                    cp -L "$agent_file" "$target"
                    chmod u+w "$target"
                    echo "  + $agent_name (added)"
                    codex_agents_added=$((codex_agents_added + 1))
                  elif cmp -s "$agent_file" "$target"; then
                    echo "  = $agent_name (up to date)"
                    codex_agents_unchanged=$((codex_agents_unchanged + 1))
                  elif grep -q "Dev-template Codex custom agent" "$target" 2>/dev/null; then
                    cp -L "$agent_file" "$target"
                    chmod u+w "$target"
                    echo "  ~ $agent_name (updated)"
                    codex_agents_updated=$((codex_agents_updated + 1))
                  else
                    echo "  = $agent_name (customized, not overwriting)"
                    codex_agents_skipped=$((codex_agents_skipped + 1))
                  fi
                done
              fi

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

              is_template_stub() {
                file="$1"
                grep -q "PROJECTNAME" "$file" 2>/dev/null || grep -q "TODO:" "$file" 2>/dev/null
              }

              is_managed_adapter() {
                file="$1"
                grep -Eq "^# (Codex Adapter|Claude Code Adapter)$" "$file" 2>/dev/null ||
                  grep -q "Read \`AI.md\` first" "$file" 2>/dev/null ||
                  grep -q "Read these provider-neutral files before non-trivial work" "$file" 2>/dev/null
              }

              # Seed or refresh provider-agnostic top-level guide. Never overwrite customized project guidance.
              AI_MD_SOURCE="${ai-md-src}"
              ai_md_added=0
              ai_md_updated=0
              ai_md_unchanged=0
              ai_md_skipped=0
              if [ -f "$AI_MD_SOURCE" ]; then
                echo ""
                echo "sync-skills: checking shared top-level guide"
                if [ ! -f "$PWD/AI.md" ]; then
                  cp -L "$AI_MD_SOURCE" "$PWD/AI.md"
                  chmod u+w "$PWD/AI.md"
                  echo "  + AI.md (added)"
                  ai_md_added=1
                elif cmp -s "$AI_MD_SOURCE" "$PWD/AI.md"; then
                  echo "  = AI.md (up to date)"
                  ai_md_unchanged=1
                elif is_template_stub "$PWD/AI.md"; then
                  cp -L "$AI_MD_SOURCE" "$PWD/AI.md"
                  chmod u+w "$PWD/AI.md"
                  echo "  ~ AI.md (updated template stub)"
                  ai_md_updated=1
                else
                  echo "  = AI.md (customized, not overwriting)"
                  ai_md_skipped=1
                fi
              fi

              # Seed or refresh provider adapters. Customized adapters are preserved.
              CLAUDE_MD_SOURCE="${claude-md-src}"
              claude_md_added=0
              claude_md_updated=0
              claude_md_unchanged=0
              claude_md_skipped=0
              if [ -f "$CLAUDE_MD_SOURCE" ]; then
                echo ""
                echo "sync-skills: checking Claude Code adapter"
                if [ ! -f "$PWD/CLAUDE.md" ]; then
                  cp -L "$CLAUDE_MD_SOURCE" "$PWD/CLAUDE.md"
                  chmod u+w "$PWD/CLAUDE.md"
                  echo "  + CLAUDE.md (added)"
                  claude_md_added=1
                elif cmp -s "$CLAUDE_MD_SOURCE" "$PWD/CLAUDE.md"; then
                  echo "  = CLAUDE.md (up to date)"
                  claude_md_unchanged=1
                elif is_managed_adapter "$PWD/CLAUDE.md"; then
                  cp -L "$CLAUDE_MD_SOURCE" "$PWD/CLAUDE.md"
                  chmod u+w "$PWD/CLAUDE.md"
                  echo "  ~ CLAUDE.md (updated adapter)"
                  claude_md_updated=1
                else
                  echo "  = CLAUDE.md (customized, not overwriting)"
                  claude_md_skipped=1
                fi
              fi

              CODEX_MD_SOURCE="${codex-md-src}"
              codex_md_added=0
              codex_md_updated=0
              codex_md_unchanged=0
              codex_md_skipped=0
              if [ -f "$CODEX_MD_SOURCE" ]; then
                echo ""
                echo "sync-skills: checking Codex named adapter"
                if [ ! -f "$PWD/CODEX.md" ]; then
                  cp -L "$CODEX_MD_SOURCE" "$PWD/CODEX.md"
                  chmod u+w "$PWD/CODEX.md"
                  echo "  + CODEX.md (added)"
                  codex_md_added=1
                elif cmp -s "$CODEX_MD_SOURCE" "$PWD/CODEX.md"; then
                  echo "  = CODEX.md (up to date)"
                  codex_md_unchanged=1
                elif is_managed_adapter "$PWD/CODEX.md"; then
                  cp -L "$CODEX_MD_SOURCE" "$PWD/CODEX.md"
                  chmod u+w "$PWD/CODEX.md"
                  echo "  ~ CODEX.md (updated adapter)"
                  codex_md_updated=1
                else
                  echo "  = CODEX.md (customized, not overwriting)"
                  codex_md_skipped=1
                fi
              fi

              # Codex auto-load adapter
              AGENTS_SOURCE="${agents-md-src}"
              agent_added=0
              agent_updated=0
              agent_unchanged=0
              agent_skipped=0
              if [ -f "$AGENTS_SOURCE" ]; then
                echo ""
                echo "sync-skills: checking Codex auto-load adapter"
                if [ ! -f "$PWD/AGENTS.md" ]; then
                  cp -L "$AGENTS_SOURCE" "$PWD/AGENTS.md"
                  chmod u+w "$PWD/AGENTS.md"
                  echo "  + AGENTS.md (added)"
                  agent_added=1
                elif cmp -s "$AGENTS_SOURCE" "$PWD/AGENTS.md"; then
                  echo "  = AGENTS.md (up to date)"
                  agent_unchanged=1
                elif is_managed_adapter "$PWD/AGENTS.md"; then
                  cp -L "$AGENTS_SOURCE" "$PWD/AGENTS.md"
                  chmod u+w "$PWD/AGENTS.md"
                  echo "  ~ AGENTS.md (updated adapter)"
                  agent_updated=1
                else
                  echo "  = AGENTS.md (customized, not overwriting)"
                  agent_skipped=1
                fi
              fi

              echo ""
              echo "Done: shared skills: $shared_added added, $shared_updated updated, $shared_unchanged unchanged | Codex repo skill link: $agents_skill_added added, $agents_skill_updated updated, $agents_skill_unchanged unchanged, $agents_skill_skipped skipped | Claude skill link: $claude_added added, $claude_updated updated, $claude_unchanged unchanged, $claude_skipped skipped | Codex compatibility skill link: $codex_added added, $codex_updated updated, $codex_unchanged unchanged, $codex_skipped skipped | .agents README: $agents_readme_added added, $agents_readme_updated updated, $agents_readme_unchanged unchanged, $agents_readme_skipped skipped | .codex README: $codex_readme_added added, $codex_readme_updated updated, $codex_readme_unchanged unchanged, $codex_readme_skipped skipped | .codex config: $codex_config_added added, $codex_config_updated updated, $codex_config_unchanged unchanged, $codex_config_skipped skipped | .codex agents: ''${codex_agents_added:-0} added, ''${codex_agents_updated:-0} updated, ''${codex_agents_unchanged:-0} unchanged, ''${codex_agents_skipped:-0} skipped | hooks: ''${hooks_added:-0} added, ''${hooks_updated:-0} updated, ''${hooks_unchanged:-0} unchanged | AI context: $ai_added added, $ai_skipped skipped | AI.md: $ai_md_added added, $ai_md_updated updated, $ai_md_unchanged unchanged, $ai_md_skipped skipped | CLAUDE.md: $claude_md_added added, $claude_md_updated updated, $claude_md_unchanged unchanged, $claude_md_skipped skipped | CODEX.md: $codex_md_added added, $codex_md_updated updated, $codex_md_unchanged unchanged, $codex_md_skipped skipped | AGENTS.md: $agent_added added, $agent_updated updated, $agent_unchanged unchanged, $agent_skipped skipped"
            '';
          in
          {
            type = "app";
            program = "${script}/bin/sync-skills";
            meta = {
              description = "Sync latest dev-template AI.md, managed adapters, shared skills, provider skill links, Codex config/custom agents, hooks, and provider-neutral AI context templates into a project";
            };
          };

        apps.fresh-start =
          let
            skills-src = ./template/.ai/skills;
            ai-src = ./template/.ai;
            codex-src = ./template/.codex;
            agents-src = ./template/.agents;
            hooks-src = ./template/.claude/hooks;
            settings-src = ./template/.claude/settings.json;
            mcp-src = ./template/.mcp.json;
            flake-src = ./template/flake.nix;
            ai-md-src = ./template/AI.md;
            claude-md-src = ./template/CLAUDE.md;
            agents-md-src = ./template/AGENTS.md;
            codex-md-src = ./template/CODEX.md;
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
              preserve_dir=$(mktemp -d)
              trap 'rm -rf "$preserve_dir"' EXIT

              echo "fresh-start: This will REMOVE ALL shared AI, Codex, and Claude Code configuration, replace flake.nix, and re-sync from template."
              echo ""
              echo "  Targets:"
              echo "    flake.nix             (replaced from template)"
              [ -f "$PWD/flake.lock" ]     && echo "    flake.lock            (removed; regenerated by next nix command)"
              [ -d "$PWD/.ai" ]            && echo "    .ai/                  (shared AI instructions and context)"
              [ -d "$PWD/.agents" ]        && echo "    .agents/              (Codex repo skills and local agent runtime state)"
              [ -d "$PWD/.claude" ]        && echo "    .claude/              (Claude Code skill link, hooks, settings, rules)"
              [ -d "$PWD/.codex" ]         && echo "    .codex/               (Codex config, custom agents, skill link, and local runtime state)"
              [ -f "$PWD/AI.md" ]          && echo "    AI.md"
              [ -f "$PWD/CLAUDE.md" ]      && echo "    CLAUDE.md"
              [ -f "$PWD/CODEX.md" ]       && echo "    CODEX.md"
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
              echo "Removing shared AI, Codex, and Claude Code configuration..."

              if [ -f "$PWD/flake.nix" ]; then
                rm -f "$PWD/flake.nix"
                echo "  - flake.nix"
              fi

              if [ -f "$PWD/flake.lock" ]; then
                rm -f "$PWD/flake.lock"
                echo "  - flake.lock"
              fi

              if [ -d "$PWD/.ai" ]; then
                rm -rf "$PWD/.ai"
                echo "  - .ai/"
              fi

              if [ -d "$PWD/.agents" ]; then
                for local_dir in local tmp sessions logs; do
                  if [ -e "$PWD/.agents/$local_dir" ]; then
                    mkdir -p "$preserve_dir/.agents"
                    mv "$PWD/.agents/$local_dir" "$preserve_dir/.agents/$local_dir"
                  fi
                done
                rm -rf "$PWD/.agents"
                echo "  - .agents/"
              fi

              if [ -d "$PWD/.claude" ]; then
                rm -rf "$PWD/.claude"
                echo "  - .claude/"
              fi

              if [ -d "$PWD/.codex" ]; then
                for local_dir in local tmp sessions logs; do
                  if [ -e "$PWD/.codex/$local_dir" ]; then
                    mkdir -p "$preserve_dir/.codex"
                    mv "$PWD/.codex/$local_dir" "$preserve_dir/.codex/$local_dir"
                  fi
                done
                rm -rf "$PWD/.codex"
                echo "  - .codex/"
              fi

              if [ -f "$PWD/CLAUDE.md" ]; then
                rm -f "$PWD/CLAUDE.md"
                echo "  - CLAUDE.md"
              fi

              if [ -f "$PWD/AI.md" ]; then
                rm -f "$PWD/AI.md"
                echo "  - AI.md"
              fi

              if [ -f "$PWD/CODEX.md" ]; then
                rm -f "$PWD/CODEX.md"
                echo "  - CODEX.md"
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

              # Nix flake
              cp -L "${flake-src}" "$PWD/flake.nix"
              chmod u+w "$PWD/flake.nix"
              echo "  + flake.nix"

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

              skill_count=$(ls -d "$PWD/.ai/skills"/*/ 2>/dev/null | wc -l)

              # Provider skill views point to the shared .ai/skills source.
              ln -s ../.ai/skills "$PWD/.claude/skills"
              echo "  + .claude/skills -> ../.ai/skills ($skill_count skills)"

              # Codex official repo-scoped skill link
              mkdir -p "$PWD/.agents"
              cp -L "${agents-src}/README.md" "$PWD/.agents/README.md"
              chmod u+w "$PWD/.agents/README.md"
              ln -s ../.ai/skills "$PWD/.agents/skills"
              if [ -d "$preserve_dir/.agents" ]; then
                for local_dir in "$preserve_dir/.agents"/*; do
                  [ -e "$local_dir" ] || continue
                  mv "$local_dir" "$PWD/.agents/$(basename "$local_dir")"
                done
              fi
              echo "  + .agents/skills -> ../.ai/skills ($skill_count skills)"

              # Codex project config and compatibility skill link
              mkdir -p "$PWD/.codex"
              cp -L "${codex-src}/README.md" "$PWD/.codex/README.md"
              chmod u+w "$PWD/.codex/README.md"
              cp -L "${codex-src}/config.toml" "$PWD/.codex/config.toml"
              chmod u+w "$PWD/.codex/config.toml"
              mkdir -p "$PWD/.codex/agents"
              for agent_file in "${codex-src}/agents"/*.toml; do
                [ -f "$agent_file" ] || continue
                cp -L "$agent_file" "$PWD/.codex/agents/$(basename "$agent_file")"
                chmod u+w "$PWD/.codex/agents/$(basename "$agent_file")"
              done
              ln -s ../.ai/skills "$PWD/.codex/skills"
              if [ -d "$preserve_dir/.codex" ]; then
                for local_dir in "$preserve_dir/.codex"/*; do
                  [ -e "$local_dir" ] || continue
                  mv "$local_dir" "$PWD/.codex/$(basename "$local_dir")"
                done
              fi
              codex_agent_count=$(ls "$PWD/.codex/agents"/*.toml 2>/dev/null | wc -l)
              echo "  + .codex/config.toml"
              echo "  + .codex/agents/ ($codex_agent_count agents)"
              echo "  + .codex/skills -> ../.ai/skills ($skill_count compatibility skills)"

              # AI.md
              cp -L "${ai-md-src}" "$PWD/AI.md"
              chmod u+w "$PWD/AI.md"
              echo "  + AI.md"

              # .mcp.json
              cp -L "${mcp-src}" "$PWD/.mcp.json"
              chmod u+w "$PWD/.mcp.json"
              echo "  + .mcp.json"

              # CLAUDE.md
              cp -L "${claude-md-src}" "$PWD/CLAUDE.md"
              chmod u+w "$PWD/CLAUDE.md"
              echo "  + CLAUDE.md (Claude Code adapter)"

              # CODEX.md
              cp -L "${codex-md-src}" "$PWD/CODEX.md"
              chmod u+w "$PWD/CODEX.md"
              echo "  + CODEX.md (Codex named adapter)"

              # AGENTS.md
              cp -L "${agents-md-src}" "$PWD/AGENTS.md"
              chmod u+w "$PWD/AGENTS.md"
              echo "  + AGENTS.md"

              echo ""
              echo "Fresh start complete. Read AI.md, then .ai/instructions.md. Shared skills live in .ai/skills; provider skill paths link from .agents/skills, .claude/skills, and .codex/skills."
            '';
          in
          {
            type = "app";
            program = "${script}/bin/fresh-start";
            meta = {
              description = "Reset flake.nix, AI.md, managed adapters, shared AI context, shared skills, Codex repo skills/config/custom agents, and Claude config in a project and restore dev-template defaults";
            };
          };

        apps.onboard =
          let
            skills-src = ./template/.ai/skills;
            ai-src = ./template/.ai;
            codex-src = ./template/.codex;
            agents-src = ./template/.agents;
            hooks-src = ./template/.claude/hooks;
            settings-src = ./template/.claude/settings.json;
            mcp-src = ./template/.mcp.json;
            ai-md-src = ./template/AI.md;
            claude-md-src = ./template/CLAUDE.md;
            agents-md-src = ./template/AGENTS.md;
            codex-md-src = ./template/CODEX.md;
            script = pkgs.writeShellScriptBin "onboard" ''
              set -euo pipefail

              # Must be run from a project root
              if [ ! -f "$PWD/flake.nix" ] && [ ! -d "$PWD/.git" ] && [ ! -f "$PWD/package.json" ] && [ ! -f "$PWD/Cargo.toml" ] && [ ! -f "$PWD/pyproject.toml" ] && [ ! -f "$PWD/go.mod" ]; then
                echo "error: no project root indicators found (flake.nix, .git, package.json, Cargo.toml, pyproject.toml, go.mod)"
                echo "Run this from your project root."
                exit 1
              fi

              # Detect state — if already onboarded, suggest refresh instead
              if [ -d "$PWD/.ai/skills" ] && [ -d "$PWD/.agents/skills" ] && [ -d "$PWD/.claude/skills" ] && [ -d "$PWD/.codex/skills" ] && [ -f "$PWD/.codex/config.toml" ] && [ -d "$PWD/.codex/agents" ] && [ -f "$PWD/AI.md" ] && [ -f "$PWD/CLAUDE.md" ] && [ -f "$PWD/CODEX.md" ] && [ -f "$PWD/AGENTS.md" ] && [ -f "$PWD/.ai/context/active-context.md" ]; then
                echo "This project appears already onboarded (.ai/context, .ai/skills, .agents/skills, .claude/skills, .codex/skills, .codex/config.toml, .codex/agents, AI.md, AGENTS.md, CODEX.md, and CLAUDE.md exist)."
                echo "Run /cc-refresh inside Claude Code to update existing configuration."
                echo "Or run 'nix run .#fresh-start' to nuke and re-sync from template."
                exit 0
              fi

              # Full bootstrap
              echo "onboard: bootstrapping shared AI context, shared skills, Codex repo skills/config, and Claude Code for this project"
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

              # Shared skills for Codex-compatible and future agents
              mkdir -p "$PWD/.ai/skills"
              shared_skill_count=0
              for skill_dir in "${skills-src}"/*/; do
                [ -d "$skill_dir" ] || continue
                skill_name=$(basename "$skill_dir")
                if [ -d "$PWD/.ai/skills/$skill_name" ]; then
                  if ! diff -rq "$skill_dir" "$PWD/.ai/skills/$skill_name" >/dev/null 2>&1; then
                    rm -rf "$PWD/.ai/skills/$skill_name"
                    cp -rL "$skill_dir" "$PWD/.ai/skills/$skill_name"
                    chmod -R u+w "$PWD/.ai/skills/$skill_name"
                    echo "  ~ .ai/skills/$skill_name (updated)"
                  else
                    echo "  = .ai/skills/$skill_name (up to date)"
                  fi
                else
                  cp -rL "$skill_dir" "$PWD/.ai/skills/$skill_name"
                  chmod -R u+w "$PWD/.ai/skills/$skill_name"
                  echo "  + .ai/skills/$skill_name"
                fi
                shared_skill_count=$((shared_skill_count + 1))
              done
              echo "  = .ai/skills/ ($shared_skill_count shared skills available)"

              link_provider_skills() {
                target="$1"
                label="$2"
                link_target="../.ai/skills"
                mkdir -p "$(dirname "$target")"
                if [ -L "$target" ]; then
                  current=$(readlink "$target")
                  if [ "$current" = "$link_target" ]; then
                    echo "  = $label -> $link_target (linked)"
                  else
                    rm -f "$target"
                    ln -s "$link_target" "$target"
                    echo "  ~ $label -> $link_target (relinked)"
                  fi
                elif [ -d "$target" ]; then
                  can_convert=1
                  for skill_dir in "$target"/*/; do
                    [ -d "$skill_dir" ] || continue
                    skill_name=$(basename "$skill_dir")
                    if [ ! -d "$PWD/.ai/skills/$skill_name" ]; then
                      cp -rL "$skill_dir" "$PWD/.ai/skills/$skill_name"
                      chmod -R u+w "$PWD/.ai/skills/$skill_name"
                      echo "  + .ai/skills/$skill_name (migrated from $label)"
                    elif ! diff -rq "$skill_dir" "$PWD/.ai/skills/$skill_name" >/dev/null 2>&1; then
                      echo "  = $label/$skill_name differs from .ai/skills/$skill_name; not converting $label"
                      can_convert=0
                    fi
                  done
                  if [ "$can_convert" -eq 1 ]; then
                    rm -rf "$target"
                    ln -s "$link_target" "$target"
                    echo "  ~ $label -> $link_target (deduplicated)"
                  fi
                elif [ -e "$target" ]; then
                  echo "  = $label (customized file, not replacing with link)"
                else
                  ln -s "$link_target" "$target"
                  echo "  + $label -> $link_target"
                fi
              }

              # Official Codex repo-scoped skill link
              mkdir -p "$PWD/.agents"
              if [ -f "${agents-src}/README.md" ]; then
                if [ -f "$PWD/.agents/README.md" ]; then
                  echo "  = .agents/README.md (already exists, skipped)"
                else
                  cp -L "${agents-src}/README.md" "$PWD/.agents/README.md"
                  chmod u+w "$PWD/.agents/README.md"
                  echo "  + .agents/README.md"
                fi
              fi
              link_provider_skills "$PWD/.agents/skills" ".agents/skills"

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
              link_provider_skills "$PWD/.claude/skills" ".claude/skills"

              # Codex project config and compatibility skill link
              mkdir -p "$PWD/.codex"
              if [ -f "${codex-src}/README.md" ]; then
                if [ -f "$PWD/.codex/README.md" ]; then
                  echo "  = .codex/README.md (already exists, skipped)"
                else
                  cp -L "${codex-src}/README.md" "$PWD/.codex/README.md"
                  chmod u+w "$PWD/.codex/README.md"
                  echo "  + .codex/README.md"
                fi
              fi
              if [ -f "${codex-src}/config.toml" ]; then
                if [ -f "$PWD/.codex/config.toml" ]; then
                  echo "  = .codex/config.toml (already exists, skipped)"
                else
                  cp -L "${codex-src}/config.toml" "$PWD/.codex/config.toml"
                  chmod u+w "$PWD/.codex/config.toml"
                  echo "  + .codex/config.toml"
                fi
              fi
              if [ -d "${codex-src}/agents" ]; then
                mkdir -p "$PWD/.codex/agents"
                for agent_file in "${codex-src}/agents"/*.toml; do
                  [ -f "$agent_file" ] || continue
                  agent_name=$(basename "$agent_file")
                  if [ -f "$PWD/.codex/agents/$agent_name" ]; then
                    echo "  = .codex/agents/$agent_name (already exists, skipped)"
                  else
                    cp -L "$agent_file" "$PWD/.codex/agents/$agent_name"
                    chmod u+w "$PWD/.codex/agents/$agent_name"
                    echo "  + .codex/agents/$agent_name"
                  fi
                done
              fi
              link_provider_skills "$PWD/.codex/skills" ".codex/skills"

              # .mcp.json
              if [ ! -f "$PWD/.mcp.json" ]; then
                cp -L "${mcp-src}" "$PWD/.mcp.json"
                chmod u+w "$PWD/.mcp.json"
                echo "  + .mcp.json"
              else
                echo "  = .mcp.json (already exists, skipped)"
              fi

              # AI.md
              if [ ! -f "$PWD/AI.md" ]; then
                cp -L "${ai-md-src}" "$PWD/AI.md"
                chmod u+w "$PWD/AI.md"
                echo "  + AI.md (shared top-level guide)"
              else
                echo "  = AI.md (already exists, skipped)"
              fi

              # CLAUDE.md
              if [ ! -f "$PWD/CLAUDE.md" ]; then
                cp -L "${claude-md-src}" "$PWD/CLAUDE.md"
                chmod u+w "$PWD/CLAUDE.md"
                echo "  + CLAUDE.md (Claude Code adapter)"
              else
                echo "  = CLAUDE.md (already exists, skipped)"
              fi

              # CODEX.md
              if [ ! -f "$PWD/CODEX.md" ]; then
                cp -L "${codex-md-src}" "$PWD/CODEX.md"
                chmod u+w "$PWD/CODEX.md"
                echo "  + CODEX.md (Codex named adapter)"
              else
                echo "  = CODEX.md (already exists, skipped)"
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
              echo "  2. Read AI.md, then .ai/instructions.md"
              echo "  3. Open Claude Code or Codex"
              echo "  4. Use skills by name in Codex, or slash commands in Claude Code"
              echo "  5. In Codex, trust the project to load .codex/config.toml and custom agents"
            '';
          in
          {
            type = "app";
            program = "${script}/bin/onboard";
            meta = {
              description = "Bootstrap AI.md, managed adapters, shared AI context, shared skills, provider skill links, Codex config/custom agents, and Claude Code config into an existing project";
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

              check_skill_link() {
                local link=$1
                local label=$2
                local expected="../.ai/skills"

                if [ -L "$link" ]; then
                  target=$(readlink "$link")
                  if [ "$target" = "$expected" ]; then
                    pass "$label links to $expected"
                  else
                    warn "$label points to $target, expected $expected"
                  fi
                else
                  warn "$label is not a symlink to $expected"
                fi

                if [ -n "$shared_skills_root" ] && [ -d "$link" ]; then
                  local missing=0
                  for shared_skill in "$shared_skills_root"/*; do
                    [ -d "$shared_skill" ] || continue
                    skill_name=$(basename "$shared_skill")
                    if [ ! -d "$link/$skill_name" ]; then
                      warn "$label missing shared skill $skill_name"
                      missing=$((missing + 1))
                    fi
                  done
                  if [ "$missing" -eq 0 ]; then
                    pass "$label resolves shared skills from $shared_skills_root"
                  fi
                fi
              }

              echo "ai-doctor: checking AI development context in $PWD"
              echo ""
              shared_skills_root=""

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

              if [ -f AI.md ]; then
                pass "AI.md present"
              else
                warn "AI.md missing"
              fi

              if [ -f AGENTS.md ]; then
                pass "AGENTS.md present"
              else
                warn "AGENTS.md missing"
              fi

              if [ -f CODEX.md ]; then
                pass "CODEX.md present"
              else
                warn "CODEX.md missing"
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

                shared_skills_root=""
                if [ -d .ai/skills ]; then
                  shared_skills_root=".ai/skills"
                  pass ".ai/skills/ present"
                elif [ -d template/.ai/skills ]; then
                  shared_skills_root="template/.ai/skills"
                  pass "template/.ai/skills/ present"
                fi

                if [ -n "$shared_skills_root" ]; then
                  shared_skill_count=0
                  for skill_dir in "$shared_skills_root"/*; do
                    [ -d "$skill_dir" ] || continue
                    shared_skill_count=$((shared_skill_count + 1))
                    if [ -f "$skill_dir/SKILL.md" ]; then
                      pass "$skill_dir has SKILL.md"
                    else
                      fail "$skill_dir missing SKILL.md"
                    fi
                  done
                  [ "$shared_skill_count" -gt 0 ] || fail "$shared_skills_root has no skills"
                else
                  fail ".ai/skills/ missing"
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
                  check_skill_link ".claude/skills" ".claude/skills"
                else
                  warn ".claude/skills/ missing"
                fi
              else
                warn ".claude/ missing"
              fi

              agents_root=""
              if [ -d .agents ]; then
                agents_root=".agents"
                pass ".agents/ present"
              elif [ -d template/.agents ]; then
                agents_root="template/.agents"
                pass "template/.agents/ present"
              fi

              if [ -n "$agents_root" ]; then
                if [ -f "$agents_root/README.md" ]; then
                  pass "$agents_root/README.md present"
                else
                  warn "$agents_root/README.md missing"
                fi

                if [ -d "$agents_root/skills" ]; then
                  agents_skill_count=0
                  for skill_dir in "$agents_root"/skills/*; do
                    [ -d "$skill_dir" ] || continue
                    agents_skill_count=$((agents_skill_count + 1))
                    if [ -f "$skill_dir/SKILL.md" ]; then
                      pass "$skill_dir has SKILL.md"
                    else
                      fail "$skill_dir missing SKILL.md"
                    fi
                  done
                  [ "$agents_skill_count" -gt 0 ] || warn "$agents_root/skills has no skills"
                  check_skill_link "$agents_root/skills" "$agents_root/skills"
                else
                  warn "$agents_root/skills/ missing"
                fi
              else
                warn ".agents/ missing"
              fi

              codex_root=""
              if [ -d .codex ]; then
                codex_root=".codex"
                pass ".codex/ present"
              elif [ -d template/.codex ]; then
                codex_root="template/.codex"
                pass "template/.codex/ present"
              fi

              if [ -n "$codex_root" ]; then
                if [ -f "$codex_root/README.md" ]; then
                  pass "$codex_root/README.md present"
                else
                  warn "$codex_root/README.md missing"
                fi

                if [ -f "$codex_root/config.toml" ]; then
                  pass "$codex_root/config.toml present"
                else
                  warn "$codex_root/config.toml missing"
                fi

                if [ -d "$codex_root/agents" ]; then
                  codex_agent_count=0
                  for agent_file in "$codex_root"/agents/*.toml; do
                    [ -f "$agent_file" ] || continue
                    codex_agent_count=$((codex_agent_count + 1))
                    if grep -q '^name = ' "$agent_file" && grep -q '^description = ' "$agent_file" && grep -q '^developer_instructions = ' "$agent_file"; then
                      pass "$agent_file has required custom agent fields"
                    else
                      fail "$agent_file missing required custom agent fields"
                    fi
                  done
                  [ "$codex_agent_count" -gt 0 ] || warn "$codex_root/agents has no custom agents"
                else
                  warn "$codex_root/agents/ missing"
                fi

                if [ -d "$codex_root/skills" ]; then
                  codex_skill_count=0
                  for skill_dir in "$codex_root"/skills/*; do
                    [ -d "$skill_dir" ] || continue
                    codex_skill_count=$((codex_skill_count + 1))
                    if [ -f "$skill_dir/SKILL.md" ]; then
                      pass "$skill_dir has SKILL.md"
                    else
                      fail "$skill_dir missing SKILL.md"
                    fi
                  done
                  [ "$codex_skill_count" -gt 0 ] || warn "$codex_root/skills has no skills"
                  check_skill_link "$codex_root/skills" "$codex_root/skills"
                else
                  warn "$codex_root/skills/ missing"
                fi
              else
                warn ".codex/ missing"
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
              description = "Validate AI development context files, shared skills, provider skill links, hooks, and skill layout in the current project";
            };
          };

        packages = {
          "codex-redesign" = codexPackage;
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
