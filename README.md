# tmux-mosaic

**Pane tiling layouts for tmux**

## Dependencies

- [tmux](https://github.com/tmux/tmux) 3.2+
- [bash](https://git.savannah.gnu.org/cgit/bash.git)

## [Installation](INSTALLATION.md)

TPM, manual, and nix setup live in [INSTALLATION.md](INSTALLATION.md).

## Quick Start

tmux-mosaic does _not_ bundle keymaps. Say you like `master-stack` everywhere
by default, but one window looks better as `grid`. Set the global default, bind
the `master-stack` ops you care about, and add a few per-window layout
switches:

```tmux
set-option -gwq @mosaic-algorithm master-stack
bind Enter run '#{E:@mosaic-exec} promote'
bind -r ,  run '#{E:@mosaic-exec} resize-master -5'
bind -r .  run '#{E:@mosaic-exec} resize-master +5'
bind T     run '#{E:@mosaic-exec} toggle'
bind G     set-option -wq @mosaic-algorithm grid
bind V     set-option -wq @mosaic-algorithm even-vertical
bind H     set-option -wq @mosaic-algorithm even-horizontal
bind Z     set-option -wq @mosaic-algorithm monocle
bind U     set-option -wqu @mosaic-algorithm
```

Most windows now inherit `master-stack`. If one window wants `grid`, hit `G`
there. If you want to go back to the global default, hit `U`.

See [Layouts](docs/layouts/) for the layout pages and global options.

## [Layouts](docs/layouts/)

- [`master-stack`](docs/layouts/master-stack.md#master-stack) — one master pane
  plus equal-split stack
- [`even-vertical`](docs/layouts/even-vertical.md#even-vertical) — equal-height
  column
- [`even-horizontal`](docs/layouts/even-horizontal.md#even-horizontal) —
  equal-width row
- [`grid`](docs/layouts/grid.md#grid) — tmux `tiled`
- [`monocle`](docs/layouts/monocle.md#monocle) — keep the focused pane zoomed

## Acknowledgements

- [Hyprland](https://github.com/hyprwm/Hyprland)
- [dwm](https://dwm.suckless.org/) and [XMonad](https://xmonad.org/)
- [saysjonathan/dwm.tmux](https://github.com/saysjonathan/dwm.tmux)
- [tmux-plugins/tmux-resurrect](https://github.com/tmux-plugins/tmux-resurrect)
