# tmux-mosaic

**Pane tiling layouts for tmux**

## Dependencies

- [tmux](https://github.com/tmux/tmux) 3.2+
- [bash](https://git.savannah.gnu.org/cgit/bash.git)

## [Installation](INSTALLATION.md)

TPM, manual, and nix setup live in [INSTALLATION.md](INSTALLATION.md).

## [Layouts](docs/layouts/)

- [`master-stack`](docs/layouts/master-stack.md#master-stack) — one master pane
  plus equal-split stack
- [`even-vertical`](docs/layouts/even-vertical.md#even-vertical) — equal-height
  column
- [`even-horizontal`](docs/layouts/even-horizontal.md#even-horizontal) —
  equal-width row
- [`grid`](docs/layouts/grid.md#grid) — tmux `tiled`
- [`monocle`](docs/layouts/monocle.md#monocle) — keep the focused pane zoomed

## Quick Start

tmux-mosaic does _not_ bundle keymaps. You choose layouts with
`@mosaic-algorithm`, and you bind operations yourself with `@mosaic-exec`.

To use `master-stack` on every window by default:

```tmux
set-option -gwq @mosaic-algorithm master-stack
```

To override just the current window:

```tmux
set-option -wq @mosaic-algorithm grid
```

To disable mosaic on just the current window:

```tmux
set-option -wq @mosaic-algorithm off
```

Unset the window-local value to fall back to the global setting again:

```tmux
set-option -wqu @mosaic-algorithm
```

Then, add your custom keybinds with `@mosaic-exec`:

```tmux
bind Enter run '#{E:@mosaic-exec} promote'
bind -r ,  run '#{E:@mosaic-exec} resize-master -5'
bind -r .  run '#{E:@mosaic-exec} resize-master +5'
bind T     run '#{E:@mosaic-exec} toggle'
```

## Acknowledgements

- [Hyprland](https://github.com/hyprwm/Hyprland)
- [dwm](https://dwm.suckless.org/) and [XMonad](https://xmonad.org/)
- [saysjonathan/dwm.tmux](https://github.com/saysjonathan/dwm.tmux)
- [tmux-plugins/tmux-resurrect](https://github.com/tmux-plugins/tmux-resurrect)
