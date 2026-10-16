# Repository guidance

## Project and layout

This repository configures personal NixOS systems using flakes, flake-parts,
import-tree, and the Dendritic pattern:
https://github.com/mightyiam/dendritic

- `flake.nix`: inputs and top-level module loading.
- `modules/parts.nix`: supported flake systems.
- `modules/features/`: reusable feature modules and their supporting assets.
- `modules/hosts/<host>/`: host composition, hardware, disks, and overrides.
- `config/`: application configuration and generated hardware configuration.
- `README.md`: installation and operational instructions.

The current NixOS configuration outputs are `laptop` and `vm`.
The flake's supported systems list does not imply every feature supports
every platform.

## Dendritic module conventions

- Nix files under `modules/` are top-level flake-parts modules loaded
  automatically by import-tree, including host `default.nix` files.
- Organize modules around features. Keep a feature's package definitions,
  wrappers, and NixOS integration together where practical.
- Follow existing interfaces: `flake.nixosModules.<name>` for NixOS modules
  and `perSystem.packages.<name>` for configured packages.
- Define lower-level NixOS modules inside top-level modules. Do not add bare
  NixOS modules to the automatically imported tree.
- Importing a feature's NixOS module should enable that feature. Avoid adding
  redundant custom enable options.
- Multiple files may contribute to the same named module; preserve module
  merging rather than inventing a separate module name for every file.
- Use top-level lexical scope, `self`, and `withSystem` to share values and
  access packages for the target system. Avoid introducing `specialArgs`
  or `extraSpecialArgs` plumbing without a concrete need.
- Keep generated hardware modules and other non-flake-parts Nix expressions
  outside the automatically imported tree, and import them explicitly.
- Follow the established architecture. Propose architectural migrations
  separately from feature work.

## Host boundaries and portability

- Shared features describe reusable behavior and personal defaults.
- Keep machine-specific settings in `modules/hosts/<host>/`, including
  device paths, GPU selection, display connectors and modes, disk layouts,
  boot configuration, and hardware workarounds.
- Hosts select features and apply their own overrides. Shared features must
  not inspect hostnames to choose machine-specific behavior.
- Example: the laptop's Niri `render-drm-device` override belongs under
  `modules/hosts/laptop/`. The VM's `Virtual-1` display mode belongs under
  `modules/hosts/vm/`. Neither belongs in the shared Niri feature.
- Preserve the wrapper pattern: define the shared configured package in the
  feature, then specialize it in the host when needed.
- Use ordinary module merging where possible. Use `lib.mkDefault` for
  intended defaults and `lib.mkForce` only when a deliberate override
  requires it; explain non-obvious overrides.
- Consider every host importing a feature when changing shared behavior.
  Generalize repeated behavior when it has a clear shared purpose.

## Editing conventions

- Read the relevant feature, its consuming hosts, and any supporting
  configuration before changing behavior.
- Inspect `git status` and the relevant diff first. Preserve existing user
  changes and work being performed in other sessions.
- Keep changes focused. Match surrounding formatting and naming; avoid
  unrelated reformatting or cleanup.
- Prefer declarative Nix configuration and existing wrapper interfaces.
- Verify options and wrapper APIs against the pinned inputs. Do not assume
  examples for another revision apply.
- Keep input updates and `flake.lock` changes separate unless the task
  requires them.
- Do not change `system.stateVersion` as part of a routine upgrade.
- Document why hardware workarounds exist and what would justify removing
  them.
- Update these instructions when repository conventions change. Keep
  temporary task status and session-specific restrictions in conversation.

## Validation

Run commands from the repository root. Choose checks appropriate to the
change; documentation-only edits do not require a system build.

For Nix changes, start with:

```sh
git diff --check
nix flake check --no-build --no-update-lock-file
```

Evaluate each affected host explicitly, replacing `<host>` with `laptop`
or `vm`:

```sh
nix eval --raw --no-update-lock-file \
  .#nixosConfigurations.<host>.config.system.build.toplevel.drvPath
```

For changes requiring build validation:

```sh
nix build --no-link --no-update-lock-file \
  .#nixosConfigurations.<host>.config.system.build.toplevel
```

- Shared feature changes require checking all consuming hosts.
- Evaluation success does not establish build success or runtime behavior.
- Run relevant existing application tests when changing application code.
- New files must be included in the Git source used by flake evaluation.
  Check for untracked files if Nix reports a missing new file; do not commit
  or stage unrelated work.
- Do not overlap expensive builds with another session's rebuild.
- Report which checks passed, which were not run, and any remaining runtime
  verification. Distinguish pre-existing failures from regressions.

## Operational boundaries

- Building a configuration and activating it are separate actions.
- Run `nixos-rebuild switch`, `test`, or `boot`, restart services, or reboot
  only when the user's request authorizes those actions.
- Disk formatting, installation, partition changes, and destructive cleanup
  require explicit authorization for the concrete operation.
- Never place plaintext secrets or private keys in repository files,
  generated configuration, build outputs, logs, or the Nix store. Follow
  existing runtime secret retrieval conventions.
- Do not commit or push unless requested.
