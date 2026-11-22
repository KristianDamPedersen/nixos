# AI agent sandboxes with Nix

Researched 2026-10-16. This is a design recommendation, not an implemented or
security-tested configuration. Existing host configuration and inputs were
left unchanged. Upstream documentation below describes current upstream code;
an implementation must pin revisions and verify their actual interfaces.

## Recommendation

Use Nix to build and pin the environment, with a disposable NixOS microVM as
the outer boundary for autonomous agents or untrusted repositories. Give it a
separate working copy, its own agent state, a guest-local Nix daemon, and
restricted outbound networking. Keep publishing and host activation outside
the guest. A bubblewrap wrapper is a useful lighter option for routine work
when sharing the host kernel is acceptable.

This recommendation is a design judgment: a VM has its own kernel, while
bubblewrap isolates processes using host-kernel facilities. Neither eliminates
hypervisor, kernel, implementation, or policy mistakes. Bubblewrap explicitly
leaves the security policy to its caller: installing it alone does not define
a secure sandbox. [bubblewrap documentation](https://github.com/containers/bubblewrap)

## What needs protecting

Assume repository text, dependencies, build scripts, tests, and tool output can
cause the agent to execute unwanted commands. Protect unrelated repositories,
home files, credentials, host services, network destinations, and the running
NixOS system. The agent should be able to damage only its disposable working
copy and consume resources within an explicit budget. These are proposed
requirements, not claims about the current machine.

For this repository specifically, exclude personal and company files, SSH
keys, 1Password integration, GitHub credentials, mail/Org secrets, and desktop
runtime sockets. Read-only access still permits copying data. A credential
deliberately supplied to the agent must be treated as available to code it
runs. A model endpoint is itself a permitted data-export destination, so a
sandbox cannot decide which client data may be sent there. See the repository's
[proposed security baseline](../SECURITY.md) for the surrounding data policy.

## The available boundaries

| Option | Useful property | Main limitation | Fit here |
| --- | --- | --- | --- |
| `nix develop` | Recreates a development environment | Does not itself confine an interactive agent | Use inside the chosen boundary |
| Nix-built bubblewrap wrapper | Explicit filesystem views and process/network namespaces | Shares the host kernel; policy is your responsibility | Lightweight interactive tier |
| Hardened systemd service | Declarative identity, filesystem restrictions and process hardening | Service settings need deliberate composition; not a VM | Background broker or fixed worker |
| NixOS containers | Declarative NixOS instances sharing the host store | Official manual warns against untrusted root in the container | Not the preferred hostile-code boundary |
| NixOS microVM | Separate guest kernel and explicit guest configuration | More lifecycle, networking and storage work | Preferred autonomous tier |

`nix develop` starts a shell with a derivation's build environment. Nix's build
sandbox applies to derivation builders, not every command later launched in a
development shell. Linux build sandboxing also has a network exception for
fixed-output derivations. Reproducibility, evaluation purity, and runtime
confinement are different controls. [nix develop](https://nix.dev/manual/nix/2.35/command-ref/new-cli/nix3-develop.html),
[Nix sandbox settings](https://nix.dev/manual/nix/2.35/command-ref/conf-file.html#conf-sandbox)

For a systemd worker, inspect `ProtectSystem`, `ProtectHome`, `PrivateTmp`,
`PrivateDevices`, `NoNewPrivileges`, capability restrictions, bind mounts and
network isolation. `ProtectSystem=strict` is not a read-confidentiality policy;
it primarily restricts writes. User-service support for filesystem namespacing
depends on kernel and user-namespace support. Validate the actual unit and its
runtime behavior. [systemd execution documentation](https://github.com/systemd/systemd/blob/main/man/systemd.exec.xml)

NixOS containers share the host's Nix store. The NixOS manual explicitly warns
that container root can affect the host and should not be given to untrusted
users. This makes them an unsuitable default recommendation when the agent
may compromise the guest. [NixOS container manual](https://nixos.org/manual/nixos/stable/#ch-containers)

## Nix-native projects worth evaluating

These are candidates, not independently audited recommendations.

**microvm.nix** provides reusable NixOS guest configuration and host lifecycle
integration. Its API includes CPU/RAM settings, volumes, filesystem shares,
network interfaces, and a writable guest-store overlay. A deliberately small
guest can avoid sharing the entire host store by packaging its required store
contents into its image. If sharing directories, set access explicitly:
`microvm.shares.*.readOnly` defaults to false. Check hypervisor-specific
exceptions before relying on a read-only share. [options](https://microvm-nix.github.io/microvm.nix/microvm-options.html),
[declarative hosts](https://microvm-nix.github.io/microvm.nix/declarative.html)

User-mode networking provides outbound connectivity, not an outbound allowlist.
For a stricter design, use a dedicated network and a host-enforced egress
gateway; block host/LAN destinations, arbitrary DNS and direct internet access
except through that gateway. This gateway design is a recommendation, not a
microvm.nix default. [networking documentation](https://microvm-nix.github.io/microvm.nix/interfaces.html)

**braiins/llm-jail** is a concrete QEMU/NixOS agent runner: ephemeral guest root,
read-only host store, separate persistent agent profiles, optional guest store
storage, and network filtering. It is an attractive prototype candidate.
Its documented conveniences need review: it forwards `AWS_*` and selected
provider variables, copies Git configuration, and exposes host package paths.
Its network policy resolves allowed DNS names into permitted destination IPs;
that is not equivalent to checking each HTTP destination, especially on shared
hosting (inference). Do not use its dangerous mode before testing the boundary.
[project documentation](https://github.com/braiins/llm-jail)

**archie-judd/agent-sandbox.nix** provides a declarative bubblewrap wrapper,
filesystem grants, environment filtering and optional HTTP(S) proxy filtering.
Internet access is open unless `allowedDomains` is configured. Workspace access
defaults to the launch directory, so never launch it from home or `/`.
`allowNix` is off by default; enabling it exposes the host daemon and full store.
Its documentation acknowledges that daemon network activity bypasses the
wrapper's domain policy. It also documents Codex nesting problems and a bypass
workaround; verify compatibility with the pinned Codex before adopting that.
[project documentation](https://github.com/archie-judd/agent-sandbox.nix)

**jailed-agents** supplies agent configurations using the bubblewrap-based
`jail.nix` library. **NixPak** supplies general Nix runtime sandboxing. Both
are alternatives to hand-writing bubblewrap arguments; neither name alone
establishes the filesystem or network policy required here.
[jailed-agents](https://github.com/andersonjoseph/jailed-agents),
[NixPak](https://github.com/nixpak/nixpak)

Anthropic's **sandbox-runtime** also exposes filesystem and network controls
for arbitrary processes using native OS sandbox facilities. It is relevant if
choosing an existing agent-compatible runtime rather than a Nix-specific
library; Nix can package a runtime without supplying its policy.
[upstream documentation](https://github.com/anthropics/sandbox-runtime)

## Policy that matters more than the wrapper

1. **Working files:** prefer a disposable clone with its own `.git` directory.
   A linked worktree may refer back to the main repository's Git administration
   directory; explicitly inspect any additional paths a wrapper exposes. Review
   and transfer the resulting diff outside the sandbox.
2. **Secrets and sockets:** use separate per-project agent state and only the
   required provider credential, retrieved at runtime. Do not expose the SSH
   agent, Docker/Podman socket, D-Bus, Wayland, 1Password or orchestration
   sockets. A socket is authority even when its directory is read-only.
3. **Networking:** default-deny outbound access and allow only necessary model
   endpoints. Fetch dependencies separately where practical. An allowlisted
   GitHub or package-registry endpoint can still carry data; GET requests can
   encode secrets in URLs. Test raw IPs, IPv6, DNS, redirects and host/LAN access.
4. **Nix:** prebuild the required tool closure on the host where possible. For
   builds performed by the agent, prefer a guest-local store and daemon. Never
   grant the agent host Nix trusted-user status: Nix warns that trusted users
   are effectively equivalent to root.
   [Nix trusted-users documentation](https://nix.dev/manual/nix/2.35/command-ref/conf-file.html#conf-trusted-users)
5. **Persistence:** bound CPU, RAM, disk and task lifetime; reset temporary
   files and state intentionally. Persistent agent settings, Git hooks and
   generated scripts are executable input on later runs. Inspect outputs before
   running them on the host.

Keep secrets out of the Nix store even when sharing it read-only. Limit external
MCP servers, connectors and orchestration APIs separately: a shell sandbox does
not constrain actions performed by an authorized service outside it.

## A phased setup for this repository

**First, prototype the boundary without changing host policy.** Pin and inspect
llm-jail in a separate experiment, using a disposable sample repository and a
sanitized environment. Compare its defaults to a minimal microvm.nix guest.
Measure interactive performance, nested virtualization availability on `vm`,
dependency-build requirements, and provider authentication behavior. Do not
start the experiment with real client material or privileged credentials.

**Then integrate the chosen runner declaratively.** Keep the package and policy
in a reusable feature following this repository's Dendritic convention. Define
`perSystem.packages.<name>` for a configured runner and, if host services are
needed, a nested `flake.nixosModules.<name>`. Host files should own KVM/hardware,
network devices and machine-specific storage. Use existing lexical inputs and
`self` rather than copying upstream `specialArgs` examples. Keep new input and
lock changes explicit and scoped to this feature.

**Finally, add separate profiles.** A light bubblewrap profile can serve trusted
interactive tasks; a VM profile can serve autonomous tasks. Keep the agent's
own approvals enabled initially. Official Codex documentation describes Linux
bubblewrap/seccomp isolation and possible nesting failures; verify the installed
CLI's help and test behavior rather than copying older bypass flags.
[Codex security documentation](https://learn.chatgpt.com/docs/agent-approvals-security)

## Acceptance tests before enabling autonomous execution

Use harmless canary files and dummy credentials. Record results for each pinned
runner/host combination; documentation and evaluation success are insufficient.

- Agent can edit its working copy and run the intended development tools/tests.
- Reading unrelated home files, the primary checkout, `/etc` secrets and host
  process environments fails; writing outside declared state fails.
- Host agent/keychain/container/orchestration sockets are absent or unusable.
- Approved endpoint access works; unapproved HTTP(S), raw IPs, alternate DNS,
  IPv6, localhost, LAN and link-local destinations fail.
- Guest builds cannot reach the host daemon, change host Nix configuration or
  bypass the network boundary through a host-side helper.
- CPU/RAM/disk limits and shutdown work; restarting a session removes ephemeral
  changes while retaining only the selected state.
- Symlinks, linked Git worktrees, hooks and credential helpers do not introduce
  unexpected host access. The host never executes generated hooks automatically.

No Nix configuration or build was changed for this research. The proposed
runner, compatibility, network enforcement and escape tests remain unverified.
