# tmux-mosaic

**Opt-in pane tiling layouts for tmux**

A small tmux plugin for per-window pane tiling. Mosaic uses native tmux layouts
where possible and installs no default keybindings.

## Dependencies

- tmux 3.2+
- bash

## [Installation](INSTALLATION.md)

TPM, manual, and nix setup live in [INSTALLATION.md](INSTALLATION.md).

## Algorithms

- `master-stack` — default; one master pane plus equal-split stack
- `even-vertical` — equal-height column
- `even-horizontal` — equal-width row
- `grid` — tmux `tiled`
- `monocle` — keep the focused pane zoomed

Full behavior, supported ops, and relevant options live in
[docs/algorithms](docs/algorithms/README.md).

## Quick start

Enable mosaic on the current window:

```tmux
set-option -wq @mosaic-enabled 1
```

Pick a non-default algorithm if you want one:

```tmux
set-option -wq @mosaic-algorithm grid
```

Add your own bindings if you want them. Mosaic exports `@mosaic-exec` so the
same bindings work across TPM, manual, and nix installs.

```tmux
bind Enter run '#{E:@mosaic-exec} promote'
bind -r , run '#{E:@mosaic-exec} resize-master -5'
bind -r . run '#{E:@mosaic-exec} resize-master +5'
bind T run '#{E:@mosaic-exec} toggle'
```

Bindings shown here are examples only. Mosaic does not install any bindings by
default.

## Operations

| Op                 | Behavior                                                                                 |
| ------------------ | ---------------------------------------------------------------------------------------- |
| `toggle`           | Enable or disable tiling on the current window                                           |
| `promote`          | Move the focused stack pane to master. On master: swap with stack-top                    |
| `resize-master ±N` | Adjust master size by N percent, clamped to 5–95                                         |
| `relayout`         | Force re-apply the current algorithm when you need to recover from manual layout changes |

Not every algorithm implements every op. `master-stack` implements the full set;
the other layouts support `toggle` and `relayout` only. See
[Algorithms](docs/algorithms/README.md).

`@mosaic-enabled` is window-scoped. Unset windows are untouched.

For focus movement, swapping through the ring, and zoom, use stock tmux
directly:

| Want                                    | Tmux command                                              |
| --------------------------------------- | --------------------------------------------------------- |
| Focus next or previous pane in the ring | `select-pane -t :.+` / `:.-`                              |
| Focus the master                        | `select-pane -t :.1` (or `:.0` if `pane-base-index` is 0) |
| Swap the focused pane through the ring  | `swap-pane -D` / `-U`                                     |
| Zoom the focused pane                   | `resize-pane -Z`                                          |

## Options

| Option                      | Scope         | Default                                    | Purpose                                                 |
| --------------------------- | ------------- | ------------------------------------------ | ------------------------------------------------------- |
| `@mosaic-enabled`           | window        | unset                                      | Set to `1` to tile this window                          |
| `@mosaic-algorithm`         | window        | (uses default)                             | Per-window algorithm override                           |
| `@mosaic-default-algorithm` | global        | `master-stack`                             | Default for windows without override                    |
| `@mosaic-orientation`       | window→global | `left`                                     | For `master-stack`: `left`, `right`, `top`, or `bottom` |
| `@mosaic-mfact`             | window→global | `50`                                       | Master size as percent                                  |
| `@mosaic-step`              | global        | `5`                                        | Default `resize-master` step                            |
| `@mosaic-debug`             | global        | `0`                                        | Set to `1` to log to `@mosaic-log-file`                 |
| `@mosaic-log-file`          | global        | `${TMPDIR:-/tmp}/tmux-mosaic-$(id -u).log` | Log path when debug is on                               |

## Limits

- Single master only. Tmux's native `main-*` layouts are hardcoded to one master
  pane.
- No per-pane stack size factors. Mosaic uses native tmux layouts, not
  hand-rolled layout strings.
- Hooks cover tmux structural events plus `after-select-pane`. If you force a
  different layout or reorder panes manually, run `relayout`.

## Acknowledgements

- [Hyprland](https://github.com/hyprwm/Hyprland)
- [dwm](https://dwm.suckless.org/) and [XMonad](https://xmonad.org/)
- [saysjonathan/dwm.tmux](https://github.com/saysjonathan/dwm.tmux)
- [tmux-plugins/tmux-resurrect](https://github.com/tmux-plugins/tmux-resurrect)
