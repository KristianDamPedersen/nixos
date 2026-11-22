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
*/
{ inputs, ... }: {
  flake.nixosModules.woodpeckerCi =
    { config, lib, pkgs, ... }:
    let
      secrets = "/var/lib/woodpecker-secrets";
      agentHome = "/var/lib/woodpecker-agent";
    in
    {
      virtualisation.docker = {
        enable = true;
        autoPrune = {
          enable = true;
          dates = "weekly";
        };
      };

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
    };
}
