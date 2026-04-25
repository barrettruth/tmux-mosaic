# tmux-mosaic

**Pane tiling layouts for tmux**

A tmux plugin that adds master-stack, grid, monocle, and other layouts with global defaults and per-window overrides.

## Dependencies

- [tmux](https://github.com/tmux/tmux) 3.2+
- [bash](https://git.savannah.gnu.org/cgit/bash.git)

## Installation

`tmux-mosaic` supports TPM, manual, and nix installs. It requires tmux 3.2+.

Mosaic installs no default keybindings. It sets `@mosaic-exec` so your own
bindings work across install methods.

<details>
<summary>TPM</summary>

### TPM

1. Add mosaic to your tmux config:

```tmux
set -g @plugin 'barrettruth/tmux-mosaic'
```

2. Install the plugin with TPM
</details>

<details>
<summary>Manual</summary>

### Manual

1. Clone the repo somewhere tmux can reach it:

```console
git clone git@github.com:barrettruth/tmux-mosaic \
    ${XDG_DATA_HOME:-$HOME/.local/share}/tmux/plugins/tmux-mosaic
```

2. Source the plugin from your tmux config:

```tmux
run-shell ${XDG_DATA_HOME:-$HOME/.local/share}/tmux/plugins/tmux-mosaic/mosaic.tmux
```
</details>

<details>
<summary>Nix</summary>

### Nix

1. Add the flake input:

```nix
inputs.tmux-mosaic.url = "github:barrettruth/tmux-mosaic";
```

2. Source the packaged plugin from your tmux wrapper config:

```tmux
run-shell ${tmux-mosaic.packages.${system}.default}/share/tmux-plugins/mosaic/mosaic.tmux
```
</details>

## Quick Start

First, make the `master-stack` layout the global default:

```tmux
set-option -gwq @mosaic-algorithm master-stack
```

Then, configure some keybindings for it:

```tmux
bind Enter run '#{E:@mosaic-exec} promote'
bind -r ,  run '#{E:@mosaic-exec} resize-master -5'
bind -r .  run '#{E:@mosaic-exec} resize-master +5'
bind T     run '#{E:@mosaic-exec} toggle'
```

If one window looks better with a `grid` layout, switch just that window:

```tmux
bind G     set-option -wq @mosaic-algorithm grid
```

If you change your mind, go back to the global default:

```tmux
bind U     set-option -wqu @mosaic-algorithm
```

## Layouts

Layouts are the pane arrangements Mosaic can apply. The following are provided:

<details>
<summary><code>master-stack</code> — one primary pane plus equal-split stack</summary>

### Behavior

This uses tmux's `main-*` layouts and keeps the master as the first pane in
tmux's pane order. `@mosaic-orientation` chooses whether the master sits on the
left, right, top, or bottom. If you kill the master, the stack-top becomes the
new master on the next relayout, and if you drag-resize it, Mosaic syncs that
size back into `@mosaic-mfact`.

### Supported operations

| Op | Behavior |
| --- | --- |
| `toggle` | Turn `master-stack` off on the current window |
| `relayout` | Re-apply the current orientation and current `@mosaic-mfact` |
| `promote` | Focused stack pane becomes master. On master: swap with stack-top |
| `resize-master ±N` | Change `@mosaic-mfact` for the current window, clamped to 5–95 |

### Relevant options

| Option | Scope | Default | Effect |
| --- | --- | --- | --- |
| `@mosaic-orientation` | window→global | `left` | Chooses `left`, `right`, `top`, or `bottom` |
| `@mosaic-mfact` | window→global | `50` | Stores the master size as a percent |
| `@mosaic-step` | global | `5` | Used by `resize-master` when you call it without an explicit N |

### Example config

```tmux
set-option -gwq @mosaic-algorithm master-stack
set-option -gwq @mosaic-orientation right

bind Enter run '#{E:@mosaic-exec} promote'
bind -r , run '#{E:@mosaic-exec} resize-master -5'
bind -r . run '#{E:@mosaic-exec} resize-master +5'
bind T run '#{E:@mosaic-exec} toggle'
bind U set-option -wqu @mosaic-algorithm
```
</details>

<details>
<summary><code>even-vertical</code> — equal-height panes in one column</summary>

### Behavior

This keeps panes in a single top-to-bottom column with equal heights. While it
is active, splits and kills re-apply the same column layout. There is no
primary pane, so `promote` and `resize-master` are not implemented.

### Supported operations

| Op | Behavior |
| --- | --- |
| `toggle` | Turn the current window layout off |
| `relayout` | Re-apply `even-vertical` to the current window |

### Example config

```tmux
bind V set-option -wq @mosaic-algorithm even-vertical
bind T run '#{E:@mosaic-exec} toggle'
bind U set-option -wqu @mosaic-algorithm
```
</details>

<details>
<summary><code>even-horizontal</code> — equal-width panes in one row</summary>

### Behavior

This keeps panes in a single left-to-right row with equal widths. While it is
active, splits and kills re-apply the same row layout. There is no primary
pane, so `promote` and `resize-master` are not implemented.

### Supported operations

| Op | Behavior |
| --- | --- |
| `toggle` | Turn the current window layout off |
| `relayout` | Re-apply `even-horizontal` to the current window |

### Example config

```tmux
bind H set-option -wq @mosaic-algorithm even-horizontal
bind T run '#{E:@mosaic-exec} toggle'
bind U set-option -wqu @mosaic-algorithm
```
</details>

<details>
<summary><code>grid</code> — equal-size tiled grid</summary>

### Behavior

This uses tmux's `tiled` layout and lets tmux choose the row and column shape
from the current pane count. With four panes, it becomes a 2x2 grid. There is
no primary pane, so `promote` and `resize-master` are not implemented.

### Supported operations

| Op | Behavior |
| --- | --- |
| `toggle` | Turn the current window layout off |
| `relayout` | Re-apply tmux's `tiled` layout |

### Example config

```tmux
bind G set-option -wq @mosaic-algorithm grid
bind T run '#{E:@mosaic-exec} toggle'
bind U set-option -wqu @mosaic-algorithm
```
</details>

<details>
<summary><code>monocle</code> — keep the focused pane zoomed</summary>

### Behavior

This keeps the focused pane zoomed on windows with more than one pane.
Splitting the zoomed pane keeps the new pane zoomed, and changing focus
re-zooms the new active pane because Mosaic relayouts on `after-select-pane`.
There is no primary pane or master size, so `promote` and `resize-master` are
not implemented.

### Supported operations

| Op | Behavior |
| --- | --- |
| `toggle` | Turn the current window layout off |
| `relayout` | Re-zoom the active pane on the current window |

### Example config

```tmux
bind Z set-option -wq @mosaic-algorithm monocle
bind T run '#{E:@mosaic-exec} toggle'
bind U set-option -wqu @mosaic-algorithm
bind n select-pane -t :.+
bind p select-pane -t :.-
```
</details>

## Acknowledgements

- [Hyprland](https://github.com/hyprwm/Hyprland)
- [dwm](https://dwm.suckless.org/) and [XMonad](https://xmonad.org/)
- [saysjonathan/dwm.tmux](https://github.com/saysjonathan/dwm.tmux)
- [tmux-plugins/tmux-resurrect](https://github.com/tmux-plugins/tmux-resurrect)
