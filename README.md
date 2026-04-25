# tmux-mosaic

**Master/stack pane tiling for tmux**

A focused tmux plugin that brings dynamic-WM tiling to panes — Hyprland's
master layout, faithful to the source. Algorithm-pluggable, opt-in per window,
no key grabs.

```
┌────────────┬────────────┐
│            │   stack    │
│            ├────────────┤
│   master   │   stack    │
│            ├────────────┤
│            │   stack    │
└────────────┴────────────┘
```

## Features

- Hyprland master-layout semantics (verified against `MasterAlgorithm.cpp`)
- Ring-traversal `swap-next` / `swap-prev` (master ↔ stack-top wraps included)
- Per-window opt-in — disabled windows are entirely untouched
- Strategy pattern under `scripts/algorithms/` for adding new layouts
- Native tmux primitives only — no hand-rolled layout strings, no CRC-16

## Requirements

- tmux 3.2+ (uses `display-popup`-era hooks and `main-pane-width <pct>%`)

## Installation

### Nix (flake input)

```nix
inputs.tmux-mosaic.url = "github:barrettruth/tmux-mosaic";

# In your tmux wrapper config:
run-shell ${tmux-mosaic.packages.${system}.default}/share/tmux-plugins/mosaic/mosaic.tmux
```

### TPM

```tmux
set -g @plugin 'barrettruth/tmux-mosaic'
```

### Manual

```sh
git clone https://github.com/barrettruth/tmux-mosaic ~/.config/tmux/plugins/tmux-mosaic
```

```tmux
run-shell ~/.config/tmux/plugins/tmux-mosaic/mosaic.tmux
```

## Use

Mosaic is **opt-in per window**:

```tmux
set-option -wq @mosaic-enabled 1
```

Bind whichever ops you want. The plugin exports `@mosaic-exec` so paths
resolve cleanly across nix-store / TPM / manual installs:

```tmux
bind a run '#{E:@mosaic-exec} focus-next'
bind f run '#{E:@mosaic-exec} focus-prev'
bind d run '#{E:@mosaic-exec} swap-next'
bind u run '#{E:@mosaic-exec} swap-prev'
bind Enter run '#{E:@mosaic-exec} promote'
bind -r , run '#{E:@mosaic-exec} resize-master -5'
bind -r . run '#{E:@mosaic-exec} resize-master +5'
bind z run '#{E:@mosaic-exec} toggle-zoom'
bind T run '#{E:@mosaic-exec} toggle'
bind M run '#{E:@mosaic-exec} focus-master'
```

## Operations

| Op | Behavior |
|---|---|
| `focus-next` / `focus-prev` | Cycle focus through panes (ring, wraps) |
| `focus-master` | Focus the master pane |
| `swap-next` / `swap-prev` | Move focused pane through the layout ring (Hyprland `swapnext` / `swapprev`) |
| `promote` | Move focused stack pane to master. On master: swap with stack-top |
| `resize-master ±N` | Adjust master width by N percent (clamped 5–95) |
| `toggle-zoom` | Tmux native zoom (monocle equivalent) |
| `toggle` | Enable/disable tiling on the current window |
| `relayout` | Force re-apply the current algorithm |

## Options

| Option | Scope | Default | Purpose |
|---|---|---|---|
| `@mosaic-enabled` | window | unset | Set to `1` to tile this window |
| `@mosaic-algorithm` | window | (uses default) | Per-window algorithm override |
| `@mosaic-default-algorithm` | global | `master-stack` | Default for windows without override |
| `@mosaic-mfact` | window→global | `50` | Master width as percent (window-scoped value wins) |
| `@mosaic-step` | global | `5` | Default `resize-master` step |
| `@mosaic-debug` | global | `0` | Set to `1` to log to `@mosaic-log-file` |
| `@mosaic-log-file` | global | `${TMPDIR:-/tmp}/tmux-mosaic-$(uid).log` | Log path when debug on |

## Algorithms

Each algorithm is one file under `scripts/algorithms/<name>.sh` exposing a
fixed contract:

```
algo_relayout <window-id>          # required
algo_promote                       # optional
algo_resize_master <delta>         # optional
algo_sync_state <window-id>        # optional — sync mosaic state from current tmux state
algo_toggle                        # optional
algo_focus_next / algo_focus_prev  # optional (default: select-pane -t :.+/-)
algo_focus_master                  # optional (default: focus pane at pane-base-index)
algo_swap_next / algo_swap_prev    # optional (default: swap-pane -D/-U)
algo_toggle_zoom                   # optional (default: resize-pane -Z)
```

The dispatcher (`scripts/ops.sh`) sources the file selected by
`@mosaic-algorithm` (or `@mosaic-default-algorithm`) and calls the matching
`algo_*` function. Adding an algorithm is a one-file change: drop it into
`algorithms/`, define the contract, set `@mosaic-algorithm` on a window.

### master-stack

Faithful to Hyprland's master layout with `nmaster=1`, `new_status=slave`,
`new_on_top=false`. Implemented atop tmux's native `main-vertical` +
`main-pane-width <pct>%` + `swap-pane -D/-U`. The `swap-pane -D/-U` ring
matches `MasterAlgorithm::getNextTarget` — same-category neighbor first,
falls back across the master/stack boundary at the ring edges.

## FAQ

**Q: Why doesn't `promote` toggle when I'm already master?**

It does, by default. On master, `promote` swaps master with stack-top
(matches Hyprland's `swapwithmaster auto`). XMonad's no-op semantic is
intentionally rejected — toggle is more discoverable.

**Q: My splits don't auto-rebalance.**

Mosaic is opt-in per window. Run `set-option -wq @mosaic-enabled 1` on the
window, or bind `toggle` to a key.

**Q: Can I tile some windows and leave others alone?**

Yes — that's the design. Hooks check `@mosaic-enabled` per window before
acting. Unset windows are inert.

## Known Limitations

- **Single master.** Tmux's `main-vertical` is hardcoded to one master pane.
  Multi-master would require hand-rolled layout strings; intentionally out of
  scope for v0.x.

- **Single orientation (left-master).** Top/right/bottom orientations are
  achievable with `main-horizontal` and `*-mirrored` variants but require
  per-orientation algorithm files. Not yet shipped.

- **No per-pane height factors.** Hyprland's `percSize` lets you bias one
  slave taller than the others. Tmux can express this via custom layout
  strings, but mosaic uses native layouts only and stack heights are always
  equal-split with running remainder.

- **Hooks fire only on tmux's structural events.** mosaic intercepts
  `after-split-window`, `after-kill-pane`, `pane-exited`, `pane-died`, and
  `after-resize-pane`. Operations that bypass these (e.g. direct
  `select-layout` to a non-master-vertical layout, or `move-pane`
  reordering) won't trigger relayout. Run `relayout` explicitly if needed.

# Acknowledgements

- [Hyprland](https://github.com/hyprwm/Hyprland) — `MasterAlgorithm.cpp` is
  the reference for `swap-next` ring semantics
- [dwm](https://dwm.suckless.org/) and
  [XMonad](https://xmonad.org/) — the master/stack family that started it all
- [saysjonathan/dwm.tmux](https://github.com/saysjonathan/dwm.tmux) — closest
  prior art for the feature space
- [tmux-plugins/tmux-resurrect](https://github.com/tmux-plugins/tmux-resurrect)
  — the `strategies/` pattern this plugin's `algorithms/` layout borrows from
