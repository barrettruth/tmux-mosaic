# tmux-mosaic

**Pane tiling layouts for tmux**

A tmux plugin for pane tiling layouts. Mosaic uses native tmux layouts
where possible and installs no default keybindings.

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

Use `master-stack` on the current window:

```tmux
set-option -wq @mosaic-algorithm master-stack
```

Add your own bindings if you want them. Mosaic exports `@mosaic-exec` so the
same bindings work across TPM, manual, and nix installs.

```tmux
bind M set-option -wq @mosaic-algorithm master-stack
bind Enter run '#{E:@mosaic-exec} promote'
bind -r , run '#{E:@mosaic-exec} resize-master -5'
bind -r . run '#{E:@mosaic-exec} resize-master +5'
bind T run '#{E:@mosaic-exec} toggle'
```

Unset it to turn mosaic off on that window:

```tmux
set-option -wqu @mosaic-algorithm
```

Bindings shown here are examples only. Mosaic does not install any bindings by
default.

For other layouts, layout-specific behavior, and the per-layout support matrix,
see [Layouts](docs/layouts/).

## Acknowledgements

- [Hyprland](https://github.com/hyprwm/Hyprland)
- [dwm](https://dwm.suckless.org/) and [XMonad](https://xmonad.org/)
- [saysjonathan/dwm.tmux](https://github.com/saysjonathan/dwm.tmux)
- [tmux-plugins/tmux-resurrect](https://github.com/tmux-plugins/tmux-resurrect)
