# Tiling window managers for macOS (November 2026)

Research for `inspari-macbook` (Apple Silicon, macOS 27.2 build 26B123, SIP
enabled per `csrutil status`). The goal is a setup that feels close to Niri.

Pinned inputs used throughout (from `flake.lock`):

- nixpkgs `c59305bab2065cfecc4944690d9eedbb56f3a9fa` (2026-10-01), source
  `/nix/store/fd5qgysvbfx27wj651swlr899w6jnbwd-source`
- nix-darwin `ff0e21a414d4547183396da1b44a66f2577b65e9` (2026-10-31), source
  `/nix/store/1cqkj5qbw1732p35qwq9j3gmr1d2fd0x-source`

GitHub activity and release data were read from the GitHub API on 2026-11-03.

## Recommendation

**OmniWM** is the closest match for a Niri user. Its default layout is
Niri-style scrolling columns, with tabbed columns, an overview, animations,
and its own workspaces. It runs with SIP enabled, supports macOS 26+ on Apple
Silicon only, and is the most active project in this list
([README](https://github.com/OmniNull/OmniWM#readme),
[limitations](https://omniwm.app/help/known-limitations/)). The cost is Nix
integration: pinned nixpkgs ships `omniwm` 0.7.1 (upstream stable is 0.7.6),
nix-darwin has no `services.omniwm` module, and its strict, GUI-written
`settings.toml` is awkward to manage declaratively.

If declarative config matters more than polish, **Paneru** is the
alternative. It is a Niri-inspired scrolling tiler whose own flake exports
`darwinModules.paneru` with `services.paneru.settings`, so the TOML can live
in this repo ([nix/README.md](https://github.com/karinushka/paneru/blob/main/nix/README.md)).
It uses native Spaces rather than its own workspaces, and it is not in
nixpkgs.

**AeroSpace** remains the conservative choice: mature, first-class
`services.aerospace` in nix-darwin, no SIP. It is an i3-style tree, not a
scrolling tiler, so it will feel like i3/Sway rather than Niri.

## Comparison

| | Model | Niri feel | SIP | Spaces | Config / hotkeys | Latest release | nixpkgs (pinned) | nix-darwin (pinned) |
|---|---|---|---|---|---|---|---|---|
| OmniWM | Niri scrolling columns + Dwindle BSP, per workspace | Closest | Not required | Own workspaces; one native Space per display | `settings.toml` + GUI; built-in hotkeys | v0.7.6, 2026-10-08 (canaries daily) | `omniwm` 0.7.1 | None |
| Paneru | Infinite horizontal strip per Space | Close | Not required (some layering features want it) | Native Spaces + experimental virtual rows | TOML or Lua; built-in bindings | v0.5.2, 2026-10-02 | Absent | Upstream flake module `services.paneru` |
| rift | Tiling, BSP, master-stack, scrolling, stack, floating | Close (scrolling mode) | Not required | Virtual workspaces; separate Spaces on | TOML; built-in `[keys]` | v0.7.2, 2026-10-29 | `rift-wm` 0.5.5 | None |
| PaperWM.spoon | Scrollable columns (PaperWM) | Close | None documented | Native Spaces | Lua in Hammerspoon | No releases; `release` branch 2026-10-30 | Hammerspoon absent | None |
| AeroSpace | i3 tree (tiles, accordion) | i3-like | Not required, never will be | Own workspaces; ignores Spaces | TOML; built-in hotkeys | v0.21.3-Beta, 2026-07-16 | `aerospace` 0.21.3-Beta | `services.aerospace` |
| yabai + skhd | BSP, stack, float | No | Partial disable for many features | Native Spaces | Shell `yabairc` + separate skhd | v7.1.25, 2026-05-08 | `yabai` 7.1.25, `skhd` 0.3.9 | `services.yabai`, `services.skhd` |
| Amethyst | xmonad layouts (tall, wide, column, BSP, ...) | No | Not documented as needed | Native Spaces | YAML + GUI; built-in hotkeys | v0.24.3, 2026-04-02 (v0.25.0b pre, 2026-11-01) | Absent | None |
| Glide | i3-like tree; experimental scroll | Partial | Not documented | Native Spaces, opt-in per Space | TOML; built-in `[keys]` | v0.2.17, 2026-10-27 | Absent | None |
| Rectangle / Loop | Snapping, not tiling | No | No | n/a | GUI | Rectangle v2.0.4, 2026-10-20; Loop 1.4.2, 2026-01-26 | `rectangle` 1.100, `loopwm` 1.4.2 | None |

## Candidates

### OmniWM

- **Model.** Two engines chosen per workspace: "Niri (orientation-aware
  scrolling containers)" where windows form columns that scroll left and
  right, and Hyprland-style Dwindle BSP. Columns can be tabbed. Niri layout
  options live in a `[niri]` table
  ([layouts](https://github.com/OmniNull/OmniWM/blob/main/website/src/content/docs/guides/layouts.md),
  [configuration](https://github.com/OmniNull/OmniWM/blob/main/website/src/content/docs/config/configuration.md)).
  Defaults include Niri-style actions such as focus column 1-9, move column
  to workspace, and first/last column
  ([README keyboard tables](https://github.com/OmniNull/OmniWM#keyboard-shortcuts)).
  It also has an overview, scratchpads, a command palette, a workspace bar,
  and a quake terminal.
- **SIP.** "Official OmniWM releases do not require disabling System Integrity
  Protection." It uses public frameworks plus "selected Apple private APIs"
  ([limitations](https://github.com/OmniNull/OmniWM/blob/main/website/src/content/docs/help/known-limitations.md)).
- **Multi-monitor and Spaces.** Requires "Displays have separate Spaces" on;
  window management pauses while it is off. Keep one native Space per
  display and navigate with OmniWM workspaces; windows on other native Spaces
  are left to macOS. The docs ask for a "staircase" macOS display arrangement
  and a separate OmniWM routing map for directional moves, saved per set of
  connected displays ([README multi-monitor](https://github.com/OmniNull/OmniWM#multi-monitor-setup)).
- **Config and hotkeys.** `~/.config/omniwm/settings.toml`, live-reloaded and
  also written by the Settings GUI. The schema is strict: in schema version 5,
  a missing required key or an unknown hotkey action rejects the whole file.
  Hotkeys are built in (needs Input Monitoring). CLI/IPC via `omniwmctl`, off
  by default ([configuration](https://github.com/OmniNull/OmniWM/blob/main/website/src/content/docs/config/configuration.md)).
- **Maintenance.** Stable v0.7.6 (2026-10-08); daily signed canaries, latest
  2026-11-03; 100+ commits since 2026-10-01; last commit 2026-11-03. Releases
  are Developer ID signed and notarized. Requires macOS 26+ on Apple Silicon;
  some extras require macOS 27 (GitHub API; [README requirements](https://github.com/OmniNull/OmniWM#requirements)).
- **Nix.** Pinned nixpkgs `omniwm` 0.7.1 (released 2026-09-19), `aarch64-darwin`
  only, repackaged signed binary
  (`/nix/store/fd5qgysvbfx27wj651swlr899w6jnbwd-source/pkgs/by-name/om/omniwm/package.nix`).
  No nix-darwin module in the pinned source (`modules/services/` has no
  omniwm). Upstream points to a Home Manager `programs.omniwm` module, which
  this repo does not use. The README warns that a settings file backed by a
  read-only store path "cannot be saved from the GUI".
- **Conflicts.** It refuses to manage windows while AeroSpace, Amethyst, Glide,
  Paneru, Rift, yabai and others are running
  ([limitations](https://github.com/OmniNull/OmniWM/blob/main/website/src/content/docs/help/known-limitations.md)).

### Paneru

- **Model.** "Arranges windows on an infinite strip, extending to the right";
  opening a window never resizes existing ones. One strip per monitor.
  Explicitly "Niri-like Behavior on MacOS", inspired by Niri and PaperWM.spoon.
  Supports preset column widths, touchpad sliding, focus-follows-mouse,
  native tabs, session restore
  ([README](https://github.com/karinushka/paneru#readme)).
- **SIP.** "Disabling System Integrity Protection (SIP) is not required, but
  without it Paneru has limited control over window layering"
  ([CONFIGURATION.md](https://github.com/karinushka/paneru/blob/main/CONFIGURATION.md)).
  It uses Accessibility and SkyLight APIs.
- **Multi-monitor and Spaces.** Works with native Spaces, one strip per
  Space; experimental virtual workspaces stack extra strips within a Space.
  Needs "Displays have separate spaces". Because hidden windows are pushed
  off-screen, side-by-side displays misbehave; the README recommends
  arranging displays above/below and offers `horizontal_mouse_warp`.
- **Config and hotkeys.** `~/.paneru.toml` or
  `$XDG_CONFIG_HOME/paneru/paneru.toml`, or a Lua `init.lua` that replaces the
  TOML. Bindings are built in (`[bindings]`).
- **Maintenance.** v0.5.2 (2026-10-02); 49 commits since 2026-10-01; last
  push 2026-11-02. A macOS 27 Accessibility rename issue (#401) was closed
  2026-09-16 (GitHub API).
- **Nix.** Not in pinned nixpkgs. Upstream flake exports
  `darwinModules.paneru` with `services.paneru.{enable,package,settings,config,extraPackages,luaConfig.enable,lua,extraLuaPackages}`
  and a `launchd.user.agents.paneru` agent
  ([nix/README.md](https://github.com/karinushka/paneru/blob/main/nix/README.md),
  [nix/darwin.nix](https://github.com/karinushka/paneru/blob/main/nix/darwin.nix)).
  Adding it means a new flake input.

### rift

- **Model.** Multiple layouts: traditional (i3/sway), BSP, master-stack,
  "scrolling columns (niri-style)", stack, floating; set per workspace via
  `workspace_rules`. Animations, Niri-style mission control, trackpad
  gestures ([README](https://github.com/acsandmann/rift#readme),
  [rift.default.toml](https://github.com/acsandmann/rift/blob/main/rift.default.toml)).
  Default mode is `traditional`.
- **SIP.** "does **not** require disabling SIP"; uses private APIs reverse
  engineered by yabai and others.
- **Multi-monitor and Spaces.** Virtual workspaces (`[virtual_workspaces]`);
  requires "Displays have separate Spaces" on.
- **Config and hotkeys.** `~/.config/rift/config.toml`, hot-reloadable;
  built-in `[keys]`. Mach-port IPC and `rift-cli`.
- **Maintenance.** v0.7.2 (2026-10-29); 100+ commits since 2026-10-01; self
  described as beta ([roadmap](https://github.com/acsandmann/rift/blob/main/roadmap.md)).
  Open macOS 27 issue #628 (clicks stop registering after days of uptime).
- **Nix.** Pinned nixpkgs `rift-wm` 0.5.5 (released 2026-09-01), two minor
  versions behind
  (`/nix/store/fd5qgysvbfx27wj651swlr899w6jnbwd-source/pkgs/by-name/ri/rift-wm/package.nix`).
  No nix-darwin module.

### PaperWM.spoon (Hammerspoon)

- **Model.** "Tiled scrollable window manager for MacOS", modelled on GNOME
  PaperWM. Columns with slurp/barf, cycle widths, accordion stacking per
  column ([README](https://github.com/mogenson/PaperWM.spoon#readme)).
- **SIP.** The README documents no SIP requirement.
- **Multi-monitor and Spaces.** Uses native Mission Control Spaces. Needs
  "Displays have separate Spaces" on and "Automatically rearrange Spaces"
  off. macOS will not move a window fully off-screen, so off-screen tiles
  sit in a visible edge margin; stack displays vertically to avoid windows
  bleeding across.
- **Config and hotkeys.** Lua in `~/.hammerspoon/init.lua`; hotkeys via
  Hammerspoon (`PaperWM:bindHotkeys`).
- **Maintenance.** No GitHub releases; `release` branch updated 2026-10-30.
  Space moves broke on macOS 27 (Mission Control's accessibility tree moved
  to WindowManager); fixed by PR #174, merged 2026-09-23. Hammerspoon itself:
  1.1.1 (2026-02-26), last commit 2026-07-08, with open macOS 27 `hs.spaces`
  issues #3897 and #3904 (GitHub API).
- **Nix.** Hammerspoon is not in pinned nixpkgs (`nix eval ... nixpkgs#hammerspoon`
  fails); the Spoon is not packaged. nix-darwin has no module. Would need
  `homebrew.casks` (exists in `modules/homebrew.nix` of the pinned
  nix-darwin) or a custom derivation.

### AeroSpace

- **Model.** i3-inspired tree. Four layouts: `h_tiles`, `v_tiles`,
  `h_accordion`, `v_accordion`
  ([guide](https://github.com/nikitabobko/AeroSpace/blob/main/docs/guide.adoc)).
  The horizontal accordion is the nearest thing to a scrolling strip, but it
  stacks windows rather than laying them side by side. "Dynamic TWM" is
  listed as post-1.0 ([README](https://github.com/nikitabobko/AeroSpace#project-status)).
- **SIP.** "Doesn't require disabling SIP" and "will never require you to
  disable SIP". Uses one private API, `_AXUIElementGetWindow`.
- **Multi-monitor and Spaces.** Emulates its own workspaces by moving inactive
  windows to a screen corner; it "doesn't acknowledge the existence of macOS
  Spaces". Every monitor needs free space in a bottom corner. The guide
  recommends turning "Displays have separate Spaces" off for stability.
- **Config and hotkeys.** `aerospace.toml`; built-in binding modes
  (`[mode.main.binding]`). CLI-first.
- **Maintenance.** Public beta. Latest v0.21.3-Beta (2026-07-16); 100+
  commits since 2026-10-01; last commit 2026-11-02. Binary runs on macOS 13+.
  I found no statement on macOS 27 testing (unverified).
- **Nix.** Pinned nixpkgs `aerospace` 0.21.3-Beta, matching upstream
  (`.../pkgs/by-name/ae/aerospace/package.nix`). nix-darwin
  `services.aerospace` (see below). It pairs with `services.jankyborders` for
  borders and `swipeaerospace` (in nixpkgs) for trackpad workspace swipes.

### yabai + skhd

- **Model.** BSP, plus `stack` and `float` layouts; no scrolling
  ([README](https://github.com/asmvik/yabai#readme)). The repo moved from
  `koekeishiya` to `asmvik`.
- **SIP.** Optional partial disable to inject a scripting addition into
  Dock.app. Needed for: move/swap/create/destroy space, removing shadows,
  transparency, animations, scratchpads, window layers, sticky windows, PiP.
  On Apple Silicon macOS 13+: `csrutil enable --without fs --without debug --without nvram`
  plus `nvram boot-args=-arm64e_preview_abi`
  ([wiki](https://github.com/asmvik/yabai/wiki/Disabling-System-Integrity-Protection)).
  7.1.25 restored moving windows between spaces with SIP enabled
  ([CHANGELOG](https://github.com/asmvik/yabai/blob/master/CHANGELOG.md)).
- **Multi-monitor and Spaces.** Extends native Spaces; requires "Displays have
  separate Spaces".
- **Config and hotkeys.** `yabairc` shell script of `yabai -m config ...`;
  hotkeys need a separate daemon (skhd).
- **Maintenance.** v7.1.25 (2026-05-08); last commit 2026-06-14; no commits
  since 2026-08-01. README lists support up to Tahoe 26. macOS 27 is
  unresolved: issues #2802, #2822, #2832, #2842, #2844 are open, and the
  maintainer wrote on #2822 (2026-08-26) that "The SIP-enabled version broke
  in macOS 27." skhd: last tag v0.3.9 (2023-05-27), last commit 2025-12-09.
- **Nix.** Pinned nixpkgs `yabai` 7.1.25, `skhd` 0.3.9. nix-darwin
  `services.yabai.{enable,package,enableScriptingAddition,config,extraConfig}`
  and `services.skhd.{enable,package,skhdConfig}`
  (`/nix/store/1cqkj5qbw1732p35qwq9j3gmr1d2fd0x-source/modules/services/yabai/default.nix`,
  `.../skhd/default.nix`). `enableScriptingAddition` adds a `yabai-sa` launch
  daemon and a sudoers rule pinned to the binary's sha256.

### Amethyst

- **Model.** xmonad-style automatic layouts: tall, wide, 3-column variants,
  fullscreen, column, row, floating, BSP, and custom JavaScript layouts. No
  scrolling ([README](https://github.com/ianyh/Amethyst#readme)).
- **SIP.** The README documents no SIP requirement.
- **Multi-monitor and Spaces.** Native Spaces; recommends turning
  "Automatically rearrange Spaces" off.
- **Config and hotkeys.** `~/.amethyst.yml` or
  `~/.config/amethyst/amethyst.yml`, plus a GUI; built-in hotkeys on `mod1`
  to `mod4` ([configuration-files.md](https://github.com/ianyh/Amethyst/blob/development/docs/configuration-files.md)).
- **Maintenance.** v0.24.3 (2026-04-02); v0.25.0b prerelease 2026-11-01; last
  commit 2026-11-01. A macOS 27.0.1 crash, #1900, was closed 2026-10-16.
- **Nix.** Not in pinned nixpkgs; no nix-darwin module.

### Glide

- **Model.** i3/Sway/Hyprland-inspired tree; a `scroll` layout kind exists
  behind `settings.experimental.scroll.enable`
  ([glide.default.toml](https://github.com/tmandry/glide/blob/main/glide.default.toml)).
- **Spaces.** Integrates with native Spaces; you opt each Space in with
  `Alt+Z` ([README](https://github.com/tmandry/glide#readme)). SIP is not
  mentioned in the README (unverified either way).
- **Maintenance.** v0.2.17 (2026-10-27); last push 2026-11-02. Not in nixpkgs.

### Rectangle and Loop (snapping only)

Both move and resize windows to snap regions via hotkeys or drags; neither
tiles automatically. Rectangle: v2.0.4 (2026-10-20), pinned nixpkgs
`rectangle` 1.100. Loop: 1.4.2 (2026-01-26), macOS 13+, pinned nixpkgs
`loopwm` 1.4.2. Neither has a nix-darwin module. They can coexist with
AeroSpace as a mouse-driven fallback; OmniWM's conflict list does not name
them (unverified whether they interfere).

## nix-darwin integration sketch: OmniWM

The pinned nix-darwin has no OmniWM module. This sketch uses only options that
exist in the pinned source: `environment.systemPackages`,
`launchd.user.agents` (`modules/launchd/default.nix`), and
`system.defaults.spaces.spans-displays` / `system.defaults.dock.mru-spaces`
(`modules/system/defaults/{spaces,dock}.nix`). A feature file would follow
the repo's convention of a `flake.darwinModules.<name>` imported by the host.

```nix
# modules/features/omniwm.nix (sketch, not added)
{ ... }: {
  flake.darwinModules.omniwm = { pkgs, ... }: {
    key = "omniwm";

    # Installs OmniWM.app (linked into /Applications/Nix Apps by nix-darwin)
    # plus `OmniWM` and `omniwmctl` on PATH. Pinned version is 0.7.1.
    environment.systemPackages = [ pkgs.omniwm ];

    # OmniWM pauses window management unless each display has its own Spaces.
    # false = separate Spaces per display (macOS default). Requires logout.
    system.defaults.spaces.spans-displays = false;
    system.defaults.dock.mru-spaces = false;

    # Optional: run under launchd instead of OmniWM's own "Start at Login".
    launchd.user.agents.omniwm = {
      serviceConfig = {
        ProgramArguments = [ "${pkgs.omniwm}/Applications/OmniWM.app/Contents/MacOS/OmniWM" ];
        RunAtLoad = true;
        KeepAlive = true;
        ProcessType = "Interactive";
      };
    };
  };
}
```

Notes on the sketch:

- Leave `~/.config/omniwm/settings.toml` mutable. The schema is strict and
  the GUI writes back, so a store-backed file would need every required key
  and could not be saved from Settings. If you want it in the repo, commit a
  complete file exported from a configured install and link it; nix-darwin
  has no per-user file option without Home Manager.
- Accessibility and Input Monitoring grants must be given by hand. Whether
  TCC keeps them when the store path changes on upgrade is unverified; the
  binary is Developer ID signed, which usually keeps grants keyed to the
  signature.
- 0.7.1 trails upstream 0.7.6. Newer versions need an override of
  `pkgs.omniwm` or a later nixpkgs bump (keep that separate from feature
  work).

For comparison, AeroSpace needs only the module that already exists:

```nix
services.aerospace = {
  enable = true;
  settings = {
    gaps.inner.horizontal = 8;
    mode.main.binding = { alt-h = "focus left"; alt-l = "focus right"; };
  };
};
```

The module writes the TOML to the store and runs
`AeroSpace.app/Contents/MacOS/AeroSpace --config-path <file>` from a launchd
user agent. It asserts `start-at-login = false` and
`after-login-command = []`. Its typed `on-window-detected.*.if` is a
submodule (`app-id`, `workspace`, ...), which is the syntax the 0.21.3 guide
calls "soft deprecated" in favour of a string `if = 'test ...'`
(`/nix/store/1cqkj5qbw1732p35qwq9j3gmr1d2fd0x-source/modules/services/aerospace/default.nix`;
[guide at v0.21.3-Beta](https://github.com/nikitabobko/AeroSpace/blob/v0.21.3-Beta/docs/guide.adoc#legacy-on-window-detected-syntax)).

## Keymap: Niri binds on OmniWM

This compares the Niri binds in `modules/features/niri.nix` with OmniWM's
assignable actions. The laptop host adds no binds of its own. OmniWM sources:
[README keyboard shortcuts](https://github.com/OmniNull/OmniWM#keyboard-shortcuts)
and the
[settings reference](https://github.com/OmniNull/OmniWM/blob/main/website/src/content/docs/config/settings-reference.md)
(`general`, `hotkeys`), both read from `main` on 2026-11-03.

### Niri layout today

- `Mod` (Super) is the base, layered with Shift, Alt, Ctrl and Shift+Alt.
- Workspaces `ws-01` to `ws-10` sit on the number keys, generated from a
  key list.
- Resizing uses the two keys right of 0 on the Danish layout (`plus`,
  `dead_acute`), in steps of 100 px, 25 px with Alt, and 300 px with Ctrl.

### Choosing a modifier

Super has no clean macOS equivalent. Command clashes with app shortcuts (⌘W,
⌘Q, ⌘Tab, ⌘Space). OmniWM defaults to Option, but the Danish Mac layout uses
Option to type characters such as brackets and braces.

OmniWM's Hyper key solves this. `general.systemHyperTrigger = "CapsLock"`
makes Caps Lock act as Hyper (this needs Input Monitoring).
`general.hyperKeyModifiers = "Control+Option+Command"` keeps Shift out of
Hyper, so Mod+Shift maps to Hyper+Shift. Hyper already contains Option and
Control, so Niri's Mod+Alt and Mod+Ctrl layers have no direct equivalent.
Those actions either come built into OmniWM's arrow behaviour or move to
keyboard modes, where each action can have a single-key `modeKey` separate
from its `binding`.

`binding` strings are `+`-joined modifiers (or `Hyper`) and a key name, and
each action may appear once in `[[hotkeys]]`. A duplicate or unknown action ID
rejects the whole file.

### Mapping

H is Caps Lock acting as Hyper (Control+Option+Command).

| Niri | OmniWM action | Proposed binding |
|---|---|---|
| Mod+Space launcher | `openCommandPalette.applications` | H+Space |
| Mod+Return kitty | No launch action. Options: Quake terminal with the Kitty provider (a drop-down, not a new window), or one external hotkey via skhd or Hammerspoon | H+Return |
| Mod+W, Mod+Q close | Close Focused Window. One binding per action | H+W |
| Mod+T float | Toggle Focused Window Floating | H+T |
| Mod+F fullscreen | Toggle OmniWM Fullscreen | H+F |
| Mod+Alt+F maximize column | Toggle Container Full Primary Span | H+Shift+F |
| Mod+Ctrl+F windowed fullscreen | No equivalent | dropped |
| Mod+arrows focus | Focus Left / Right / Up / Down | H+arrows |
| Mod+Shift+Left/Right swap | Move Container Left / Right | H+Shift+Left/Right |
| Mod+Shift+Up/Down reorder in column | Move Up / Down | H+Shift+Up/Down |
| Mod+Alt+Left/Right consume or expel | Move Left / Right, which consumes and expels in horizontal orientation | mode key |
| Mod+G tabbed column | Toggle Tabbed Mode for Focused Column | H+G |
| Mod+Alt+Tab, Mod+Ctrl+Left/Right cycle within column | Focus Next / Previous Window (Wrap), which wraps within the active column | mode keys |
| Mod+Alt+1–5 window in column | `focusWindowInColumn.1`–`5` | mode keys |
| Mod+1–0 workspace | `switchWorkspace.0`–`9` (zero-based; workspace 10 must be defined) | H+1–0 |
| Mod+Shift+1–0 move and follow | Move Focused Window to Workspace N | H+Shift+1–0 |
| Mod+Shift+Alt+1–0 move without following | No separate action documented | dropped |
| Mod+Tab, Mod+Shift+Tab | Switch to Next / Previous Workspace | H+Tab, H+Shift+Tab |
| Mod+Ctrl+Tab previous workspace | Switch to Last Active Workspace | Control+Option+Tab (default) |
| Ctrl+Alt+Tab (+Shift) monitor | Focus Next / Previous Monitor in Order | Control+Command+Tab (+Shift) |
| Mod+Shift+Alt+arrows workspace to monitor | Move Workspace to Monitor on Left / Right / Above / Below | mode keys |
| Mod+plus/´ column width, +Shift window height | Shrink / Grow Container Primary Span, Shrink / Grow Window Secondary Span | H+plus/´, H+Shift+plus/´ |
| Alt and Ctrl fine and coarse resize steps | One step size only (10%, per the v4 to v5 action rename) | dropped; Cycle Size on H+. and H+, covers presets |
| Mod+wheel workspaces | No scroll-wheel bindings; mouse buttons only | trackpad gestures |

## Unverified

- AeroSpace behaviour on macOS 27: no upstream statement found.
- Whether Glide, Amethyst, and PaperWM.spoon need SIP changes for any
  feature: their READMEs are silent.
- Whether macOS keeps OmniWM's Accessibility grant across Nix store path
  changes.
- Whether Rectangle or Loop conflict with OmniWM at runtime.
- Day-to-day feel and stability. Nothing here was installed or run.
- OmniWM action IDs on the pinned 0.7.1. The keymap above uses `main` docs,
  and IDs have changed between schema versions.
- Whether OmniWM's Move Focused Window to Workspace follows the window.
- Whether OmniWM key names refer to physical positions or layout characters,
  which decides whether `-`/`=` or `+`/`´` lands on the keys right of 0 on a
  Danish keyboard.
