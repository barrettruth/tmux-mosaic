# tmux-mosaic

Composable, well-tested pane tiling for tmux.

A small, focused plugin that brings dynamic-WM tiling semantics — master/stack,
grid, monocle — to tmux panes. Algorithm-pluggable, opt-in per window, no key
grabs by default.

## Status

v0.1: master-stack only. Faithful to Hyprland's `master` layout (verified
against `MasterAlgorithm.cpp`). Grid and monocle planned. Other algorithms
on demand.

## Install

### Nix

This repo exposes a flake package built with `mkTmuxPlugin`:

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

Then in your `tmux.conf`:

```tmux
run-shell ~/.config/tmux/plugins/tmux-mosaic/mosaic.tmux
```

## Use

mosaic is **opt-in per window**. Loading the plugin does nothing visible until
you enable a window:

```tmux
tmux set-option -wq @mosaic-enabled 1
```

Then bind whichever ops you want. The plugin exports `@mosaic-exec` for paths
that resolve cleanly across nix store / TPM / manual installs:

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
| `swap-next` / `swap-prev` | Move focused pane through the layout ring (Hyprland `swapnext`/`swapprev` semantics) |
| `promote` | Move focused stack pane to master. On master: swap with stack-top |
| `resize-master ±N` | Adjust master width by N percent (clamped 5–95) |
| `toggle-zoom` | Tmux native zoom (monocle) |
| `toggle` | Enable/disable tiling on current window |
| `relayout` | Force re-apply current algorithm |

## Options

| Option | Scope | Default | Purpose |
|---|---|---|---|
| `@mosaic-enabled` | window | unset | Set to `1` to tile this window |
| `@mosaic-algorithm` | window | (uses default) | Per-window algorithm override |
| `@mosaic-default-algorithm` | global | `master-stack` | Default for windows without override |
| `@mosaic-mfact` | global | `50` | Master width as percentage |
| `@mosaic-step` | global | `5` | Default `resize-master` step |
| `@mosaic-debug` | global | `0` | Set to `1` to log to `@mosaic-log-file` |
| `@mosaic-log-file` | global | `/tmp/tmux-mosaic.log` | Log path when debug is on |

## Algorithms

Each algorithm is a single shell file under `scripts/algorithms/<name>.sh`
exposing a fixed contract (`algo_relayout`, `algo_focus_next`, `algo_swap_next`,
…). Adding one is a one-file change.

### master-stack (v0.1)

Faithful to Hyprland's master layout with `nmaster=1`, `new_status=slave`,
`new_on_top=false`. Master pane on the left, stack on the right at equal
heights. Configurable master width via `@mosaic-mfact`.

`swap-next`/`swap-prev` traverse a ring through master + stack, matching
`MasterAlgorithm::getNextTarget` semantics.

## Develop

```sh
direnv allow              # nix dev shell with bats, shellcheck, shfmt, tmux
just test                 # run integration tests
just lint                 # shellcheck + shfmt diff
just ci                   # everything
```

Tests use an isolated `tmux -L mosaic-test` socket — your real session is
never touched.

## License

MIT
