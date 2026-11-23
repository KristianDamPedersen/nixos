/*
  Woodpecker CI: server and one local-backend agent on the same machine

  The agent runs pipeline steps directly in a shell on this machine, so
  repositories can run their own devenv tasks with Nix, Docker and k3d. Only
  run pipelines from repositories whose contributors you trust: the agent's
  user is in the docker group, which is root-equivalent.

  Secrets stay out of the store. Create them by hand, mode 0600, root-owned:
    /var/lib/woodpecker-secrets/server.env
      WOODPECKER_GITHUB_CLIENT=...
      WOODPECKER_GITHUB_SECRET=...
      WOODPECKER_AGENT_SECRET=...
    /var/lib/woodpecker-secrets/agent.env
      WOODPECKER_AGENT_SECRET=...

  The host sets WOODPECKER_HOST and publishes the server, for example with
  `tailscale funnel --bg 8000`.

  Repositories and their secrets are declared in woodpeckerCi.repositories.
  After every rebuild, woodpecker-repositories.service activates them and
  applies their settings and secrets through the API. It needs a Woodpecker
  access token of an admin (User settings → CLI & API); until it has one it
  does nothing. It never removes repositories or secrets that aren't declared.

  The access token and the secret values come from 1Password references
  (op://vault/item/field), read with a 1Password service account whose token
  is the one file kept on disk (woodpeckerCi.onePassword.tokenFile), or from
  root-only files.
*/
{ inputs, ... }: {
  flake.nixosModules.woodpeckerCi =
    { config, lib, pkgs, ... }:
    let
      secrets = "/var/lib/woodpecker-secrets";
      agentHome = "/var/lib/woodpecker-agent";
      cfg = config.woodpeckerCi;
      events = lib.types.enum [
        "push"
        "pull_request"
        "pull_request_closed"
        "pull_request_metadata"
        "tag"
        "release"
        "deployment"
        "cron"
        "manual"
      ];

      # What the API gets: settings without unset values, and where each secret
      # comes from (the values are read at runtime and never enter the store).
      declared = pkgs.writeText "woodpecker-repositories.json" (
        builtins.toJSON (
          lib.mapAttrs (_: repo: {
            inherit (repo) forgeRemoteId;
            settings = lib.filterAttrs (_: v: v != null) {
              timeout = repo.timeout;
              require_approval = repo.requireApproval;
              cancel_previous_pipeline_events = repo.cancelPreviousPipelineEvents;
            };
            secrets = lib.mapAttrs (_: secret: { inherit (secret) reference file events; }) repo.secrets;
          }) cfg.repositories
        )
      );

      reconcile = pkgs.writeShellApplication {
        name = "woodpecker-repositories";
        runtimeInputs = [
          pkgs.curl
          pkgs.jq
          config.programs._1password.package
        ];
        text = ''
          server=http://${config.services.woodpecker-server.environment.WOODPECKER_SERVER_ADDR}

          if [ -s ${cfg.onePassword.tokenFile} ]; then
            OP_SERVICE_ACCOUNT_TOKEN=$(<${cfg.onePassword.tokenFile})
            export OP_SERVICE_ACCOUNT_TOKEN
          fi

          # Prints a secret without a trailing newline: from a 1Password reference
          # ($1) if given, otherwise from a file ($2).
          read_value() {
            if [ -n "$1" ]; then
              if [ -z "''${OP_SERVICE_ACCOUNT_TOKEN:-}" ]; then
                echo "No 1Password service account token in ${cfg.onePassword.tokenFile}." >&2
                return 1
              fi
              op read --no-newline "$1"
            else
              local value
              value=$(<"$2")
              printf '%s' "$value"
            fi
          }

          # A missing token is the normal state before the first sign-in, so it isn't a failure.
          if ! token=$(read_value "${toString cfg.apiToken.reference}" "${cfg.apiToken.file}") || [ -z "$token" ]; then
            echo "No Woodpecker access token yet (see the error above); repositories not applied."
            exit 0
          fi

          # The token reaches curl as a header file from a builtin, so it never shows in the process list.
          api() {
            local method=$1 path=$2
            shift 2
            curl -fsS -X "$method" -H @<(printf 'Authorization: Bearer %s\n' "$token") \
              -H 'Content-Type: application/json' "$server/api$path" "$@"
          }

          for _ in $(seq 60); do
            curl -fsS "$server/healthz" >/dev/null 2>&1 && break
            sleep 1
          done

          jq -r 'keys[]' ${declared} | while read -r name; do
            remote=$(jq -r --arg n "$name" '.[$n].forgeRemoteId' ${declared})
            if ! repo=$(api GET "/repos/lookup/$name" 2>/dev/null) || [ "$(jq -r .active <<<"$repo")" != true ]; then
              repo=$(api POST "/repos?forge_remote_id=$remote")
              echo "$name: activated"
            fi
            id=$(jq -r .id <<<"$repo")

            jq -c --arg n "$name" '.[$n].settings' ${declared} | api PATCH "/repos/$id" --data @- >/dev/null
            echo "$name: settings applied"

            jq -r --arg n "$name" '.[$n].secrets | keys[]' ${declared} | while read -r secret; do
              reference=$(jq -r --arg n "$name" --arg s "$secret" '.[$n].secrets[$s].reference // ""' ${declared})
              file=$(jq -r --arg n "$name" --arg s "$secret" '.[$n].secrets[$s].file // ""' ${declared})
              events=$(jq -c --arg n "$name" --arg s "$secret" '.[$n].secrets[$s].events' ${declared})
              # The value reaches jq on stdin, never as an argument.
              body=$(read_value "$reference" "$file" | jq -n --arg name "$secret" --rawfile value /dev/stdin \
                --argjson events "$events" '{name: $name, value: $value, events: $events}')
              if api GET "/repos/$id/secrets/$secret" >/dev/null 2>&1; then
                api PATCH "/repos/$id/secrets/$secret" --data @- >/dev/null <<<"$body"
              else
                api POST "/repos/$id/secrets" --data @- >/dev/null <<<"$body"
              fi
              echo "$name: secret $secret applied"
            done
          done
        '';
      };
    in
    {
      options.woodpeckerCi = {
        onePassword.tokenFile = lib.mkOption {
          type = lib.types.str;
          default = "${secrets}/op-service-account-token";
          description = "File with a 1Password service account token, used to read op:// references.";
        };

        apiToken = {
          reference = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            example = "op://CI/Woodpecker asus-srv/credential";
            description = "1Password reference to a Woodpecker admin access token. Overrides `file`.";
          };
          file = lib.mkOption {
            type = lib.types.str;
            default = "${secrets}/api-token";
            description = "File with a Woodpecker admin access token, used when `reference` is null.";
          };
        };

        repositories = lib.mkOption {
          default = { };
          description = "Repositories to activate, by full name (owner/name), with their settings and secrets.";
          type = lib.types.attrsOf (
            lib.types.submodule {
              options = {
                forgeRemoteId = lib.mkOption {
                  type = lib.types.int;
                  description = "The repository's ID on the forge: `gh api repos/<owner>/<name> --jq .id`.";
                };
                timeout = lib.mkOption {
                  type = lib.types.nullOr lib.types.int;
                  default = null;
                  description = "Pipeline timeout in minutes; null keeps the server's default.";
                };
                requireApproval = lib.mkOption {
                  type = lib.types.nullOr (lib.types.enum [ "none" "forks" "pull_requests" "all_events" ]);
                  default = null;
                };
                cancelPreviousPipelineEvents = lib.mkOption {
                  type = lib.types.nullOr (lib.types.listOf events);
                  default = null;
                  description = "Events whose older pipelines a newer one cancels.";
                };
                secrets = lib.mkOption {
                  default = { };
                  description = "Repository secrets by name, each read at runtime from a 1Password reference or a root-only file.";
                  type = lib.types.attrsOf (
                    lib.types.submodule {
                      options = {
                        reference = lib.mkOption {
                          type = lib.types.nullOr lib.types.str;
                          default = null;
                          example = "op://CI/GitHub read token/credential";
                        };
                        file = lib.mkOption {
                          type = lib.types.nullOr lib.types.str;
                          default = null;
                        };
                        events = lib.mkOption { type = lib.types.listOf events; };
                      };
                    }
                  );
                };
              };
            }
          );
        };
      };

      config = {
      assertions = lib.flatten (
        lib.mapAttrsToList (
          repo: r:
          lib.mapAttrsToList (name: secret: {
            assertion = (secret.reference == null) != (secret.file == null);
            message = "woodpeckerCi.repositories.${repo}.secrets.${name}: set exactly one of reference and file.";
          }) r.secrets
        ) cfg.repositories
      );

      virtualisation.docker = {
        enable = true;
        autoPrune = {
          enable = true;
          dates = "weekly";
        };
      };

      # Pipelines run binaries that package managers download for generic Linux
      # (npm packages such as biome); nix-ld lets NixOS run them.
      programs.nix-ld.enable = true;

      # k3d clusters and Docker Compose stacks exhaust the default inotify
      # limits; a third local cluster hangs at create otherwise.
      boot.kernel.sysctl = {
        "fs.inotify.max_user_instances" = 1024;
        "fs.inotify.max_user_watches" = 524288;
      };

      systemd.tmpfiles.rules = [ "d ${secrets} 0700 root root -" ];

      users.groups.woodpecker-agent = { };
      users.users.woodpecker-agent = {
        isSystemUser = true;
        group = "woodpecker-agent";
        home = agentHome;
        createHome = true;
        extraGroups = [ "docker" ];
      };

      services.woodpecker-server = {
        enable = true;
        environment = {
          WOODPECKER_SERVER_ADDR = "127.0.0.1:8000";
          WOODPECKER_GRPC_ADDR = "127.0.0.1:9000";
          WOODPECKER_GITHUB = "true";
          WOODPECKER_OPEN = "false";
          WOODPECKER_ADMIN = "KristianDamPedersen";
          # Statuses named after the workflow (check, pr-metadata), like the
          # GitHub Actions jobs, so branch rules keep the same required names.
          WOODPECKER_STATUS_CONTEXT_FORMAT = "{{ .workflow }}";
          # Fetching the pipeline files from GitHub timed out at the default 5 s while a heavy pipeline ran, which
          # errors the new pipeline without a status.
          WOODPECKER_FORGE_TIMEOUT = "30s";
        };
        environmentFile = [ "${secrets}/server.env" ];
      };

      services.woodpecker-agents.agents.local = {
        enable = true;
        environment = {
          WOODPECKER_SERVER = "127.0.0.1:9000";
          WOODPECKER_BACKEND = "local";
          # One workflow at a time: a full check brings up its own
          # dependencies and cluster, and two at once overload the machine.
          WOODPECKER_MAX_WORKFLOWS = "1";
          HOME = agentHome;
        };
        environmentFile = [ "${secrets}/agent.env" ];
        path = with pkgs; [
          # Clone and run steps.
          git
          git-lfs
          woodpecker-plugin-git
          bash
          coreutils
          findutils
          gnugrep
          gnused
          gnutar
          gzip
          curl
          jq
          # What pipelines call: the repositories bring the rest through devenv.
          config.nix.package
          inputs.devenv.packages.${pkgs.stdenv.hostPlatform.system}.devenv
          docker
          gh
        ];
      };

      # The module's agent unit is hardened for container backends. The local
      # backend runs devenv tasks on the host, which that hardening breaks, so
      # these settings are relaxed for this agent:
      systemd.services.woodpecker-agent-local.serviceConfig = {
        # A fixed user with a home: devenv and Nix need a writable home and
        # cache, and the docker group must apply (PrivateUsers hides it).
        DynamicUser = lib.mkForce false;
        User = "woodpecker-agent";
        Group = "woodpecker-agent";
        PrivateUsers = lib.mkForce false;
        StateDirectory = "woodpecker-agent";
        # The .NET runtime's JIT needs writable and executable memory.
        MemoryDenyWriteExecute = lib.mkForce false;
        # Build tools and test runners use syscalls outside the module's
        # filter; the user and its groups are the boundary here.
        SystemCallFilter = lib.mkForce [ ];
        # Workspaces live under /tmp, and the Docker daemon (outside this
        # unit) must see them for Compose and k3d bind mounts.
        PrivateTmp = lib.mkForce false;
        # "strict" would make the shared /tmp read-only; "full" still protects
        # /usr, /boot and /etc.
        ProtectSystem = lib.mkForce "full";
      };

      systemd.services.woodpecker-repositories = lib.mkIf (cfg.repositories != { }) {
        description = "Apply the declared Woodpecker repositories";
        wantedBy = [ "multi-user.target" ];
        after = [ "woodpecker-server.service" ];
        requires = [ "woodpecker-server.service" ];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = lib.getExe reconcile;
          # The 1Password CLI needs a writable, private config directory.
          RuntimeDirectory = "woodpecker-repositories";
          RuntimeDirectoryMode = "0700";
          Environment = [ "HOME=/run/woodpecker-repositories" ];
          # Root reads the root-only secret files; the rest of the system stays read-only.
          ProtectSystem = "strict";
          ProtectHome = true;
          PrivateTmp = true;
          NoNewPrivileges = true;
        };
      };
      };
    };
}
