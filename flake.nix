{
  description = "dev-template — project scaffolding with Nix + Claude Code and Codex";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    # Prebuilt official release retained on the dataserver.
    # Refresh explicitly with: nix flake update codex-release
    codex-release.url = "git+ssh://pai@192.168.0.7/srv/git/codex-release.git?ref=latest";
    flake-utils.url = "github:numtide/flake-utils";
    claude-code = {
      url = "github:sadjow/claude-code-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, codex-release, flake-utils, claude-code, ... }:
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
    flake-utils.lib.eachSystem [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" ] (system:
      let
        pkgs = import nixpkgs { inherit system; };
        codexPackage =
          if system == "x86_64-linux" then
            codex-release.packages.${system}.default
          else
            pkgs.codex;
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
          ] ++ pkgs.lib.optionals pkgs.stdenv.hostPlatform.isLinux [
            pkgs.bubblewrap
          ];

          shellHook = ''
            echo "dev-template — use 'nix flake init -t .' to test templates locally"
          '';
        };

        apps =
          let
            python = pkgs.python3.withPackages (ps: [ ps.pyyaml ]);
            templateApp = name: command: description:
              let
                script = pkgs.writeShellScriptBin name ''
                  exec ${python}/bin/python ${self}/tools/template.py --repo ${self} ${command} "$@"
                '';
              in
              {
                type = "app";
                program = "${script}/bin/${name}";
                meta.description = description;
              };
          in
          {
            sync-skills = templateApp "sync-skills" "sync" "Synchronize managed dev-template guidance and runtime files";
            onboard = templateApp "onboard" "onboard" "Onboard the current project with dev-template guidance";
            fresh-start = templateApp "fresh-start" "reset" "Replace managed project guidance after preserving supported local state";
            ai-doctor = templateApp "ai-doctor" "doctor" "Validate dev-template guidance and runtime files in the current project";
            migrate = templateApp "migrate" "migrate" "Migrate the current project to the current dev-template schema";
            agent-profile = templateApp "agent-profile" "profile" "Show the current project agent profile";
            agent-restore = templateApp "agent-restore" "restore" "Restore supported project agent state";
            migrate-v2 =
              let
                script = pkgs.writeShellScriptBin "migrate-v2" ''
                  exec ${python}/bin/python ${self}/tools/migrate_v2.py \
                    --template ${./compat/v2} \
                    --manifest ${./migrations/v1-to-v2.yaml} \
                    "$@"
                '';
              in
              {
                type = "app";
                program = "${script}/bin/migrate-v2";
                meta.description = "Dry-run or apply the fingerprint-gated, recoverable dev-template schema-v1 to schema-v2 migration";
              };
          };

        packages =
          let
            appPackage = name: pkgs.runCommand name { } ''
              mkdir -p $out/bin
              ln -s ${apps.${name}.program} $out/bin/${name}
            '';
          in
          {
            codex = codexPackage;
            sync-skills = appPackage "sync-skills";
            migrate-v2 = appPackage "migrate-v2";
            fresh-start = appPackage "fresh-start";
            onboard = appPackage "onboard";
            ai-doctor = appPackage "ai-doctor";
            migrate = appPackage "migrate";
            agent-profile = appPackage "agent-profile";
            agent-restore = appPackage "agent-restore";
          };
      }
    );
}
