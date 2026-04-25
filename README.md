# tmux-mosaic

**Pane tiling layouts for tmux**

## Dependencies

- [tmux](https://github.com/tmux/tmux) 3.2+
- [bash](https://git.savannah.gnu.org/cgit/bash.git)

## Installation

`tmux-mosaic` supports TPM, manual, and nix installs. It requires tmux 3.2+.

Mosaic installs no default keybindings. It sets `@mosaic-exec` so your own
bindings work across install methods.

### TPM

Add mosaic to your tmux config:

```tmux
set -g @plugin 'barrettruth/tmux-mosaic'
```

Install plugins with `prefix + I` if you use TPM.

### Manual

Clone the repo somewhere tmux can reach it:

```sh
git clone https://github.com/barrettruth/tmux-mosaic ~/.config/tmux/plugins/tmux-mosaic
```

Source the plugin from your tmux config:

```tmux
run-shell ~/.config/tmux/plugins/tmux-mosaic/mosaic.tmux
```

### Nix

Add the flake input:

```nix
inputs.tmux-mosaic.url = "github:barrettruth/tmux-mosaic";
```

Source the packaged plugin from your tmux wrapper config:

```tmux
run-shell ${tmux-mosaic.packages.${system}.default}/share/tmux-plugins/mosaic/mosaic.tmux
```

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

Most windows now inherit `master-stack`. Hit `G` in the one window that wants
`grid`. Hit `U` to go back to the global default.

See the layout folds below for per-layout behavior and examples.

## Layouts

Layouts are the pane arrangements Mosaic can apply. The table below lists the
available layouts, the tmux primitive behind each one, and which operations
they support.

| Layout | Backing tmux layout | `promote` | `resize-master` | Notes |
| --- | --- | --- | --- | --- |
| `master-stack` | `main-*` family | yes | yes | One master pane plus equal-split stack |
| `even-vertical` | `even-vertical` | no | no | Equal-height panes in one column |
| `even-horizontal` | `even-horizontal` | no | no | Equal-width panes in one row |
| `grid` | `tiled` | no | no | Equal-size grid using tmux's tiled layout |
| `monocle` | tmux zoom | no | no | Keeps the focused pane zoomed |

<details>
<summary><code>master-stack</code> — one master pane plus equal-split stack</summary>

### master-stack

`master-stack` keeps one primary pane and an equal-split stack using tmux's
`main-*` layouts.

#### Behavior

- `left`, `right`, `top`, and `bottom` map to tmux's `main-*` layouts
- the master is the first pane in tmux's pane order
- killing the master promotes the stack-top on the next relayout
- drag-resizing the master updates `@mosaic-mfact` for the next relayout

#### Supported operations

| Op | Behavior |
| --- | --- |
| `toggle` | Turn `master-stack` off on the current window |
| `relayout` | Re-apply the current orientation and current `@mosaic-mfact` |
| `promote` | Focused stack pane becomes master. On master: swap with stack-top |
| `resize-master ±N` | Change `@mosaic-mfact` for the current window, clamped to 5–95 |

#### Relevant options

| Option | Scope | Default | Effect |
| --- | --- | --- | --- |
| `@mosaic-orientation` | window→global | `left` | Chooses `left`, `right`, `top`, or `bottom` |
| `@mosaic-mfact` | window→global | `50` | Stores the master size as a percent |
| `@mosaic-step` | global | `5` | Used by `resize-master` when you call it without an explicit N |

#### Example config

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

### even-vertical

`even-vertical` keeps panes in one column with equal heights using tmux's native
`even-vertical` layout.

#### Behavior

- panes are stacked top to bottom in a single column
- splits and kills re-apply the column layout while `even-vertical` is active
  on the window
- there is no primary pane, so `promote` and `resize-master` are not implemented

#### Supported operations

| Op | Support | Behavior |
| --- | --- | --- |
| `toggle` | yes | Turn the current window layout off |
| `relayout` | yes | Re-apply `even-vertical` to the current window |
| `promote` | no | Surfaces a tmux message |
| `resize-master ±N` | no | Surfaces a tmux message |

#### Example config

```tmux
bind V set-option -wq @mosaic-algorithm even-vertical
bind T run '#{E:@mosaic-exec} toggle'
bind U set-option -wqu @mosaic-algorithm
```
</details>

<details>
<summary><code>even-horizontal</code> — equal-width panes in one row</summary>

### even-horizontal

`even-horizontal` keeps panes in one row with equal widths using tmux's native
`even-horizontal` layout.

#### Behavior

- panes are arranged left to right in a single row
- splits and kills re-apply the row layout while `even-horizontal` is active on
  the window
- there is no primary pane, so `promote` and `resize-master` are not implemented

#### Supported operations

| Op | Support | Behavior |
| --- | --- | --- |
| `toggle` | yes | Turn the current window layout off |
| `relayout` | yes | Re-apply `even-horizontal` to the current window |
| `promote` | no | Surfaces a tmux message |
| `resize-master ±N` | no | Surfaces a tmux message |

#### Example config

```tmux
bind H set-option -wq @mosaic-algorithm even-horizontal
bind T run '#{E:@mosaic-exec} toggle'
bind U set-option -wqu @mosaic-algorithm
```
</details>

<details>
<summary><code>grid</code> — equal-size grid using tmux's tiled layout</summary>

### grid

`grid` uses tmux's native `tiled` layout for an equal-size grid.

#### Behavior

- tmux chooses the row and column shape from the current pane count
- with four panes, the layout becomes a 2x2 grid
- there is no primary pane, so `promote` and `resize-master` are not implemented

#### Supported operations

| Op | Support | Behavior |
| --- | --- | --- |
| `toggle` | yes | Turn the current window layout off |
| `relayout` | yes | Re-apply tmux's `tiled` layout |
| `promote` | no | Surfaces a tmux message |
| `resize-master ±N` | no | Surfaces a tmux message |

#### Example config

```tmux
bind G set-option -wq @mosaic-algorithm grid
bind T run '#{E:@mosaic-exec} toggle'
bind U set-option -wqu @mosaic-algorithm
```
</details>

<details>
<summary><code>monocle</code> — keep the focused pane zoomed</summary>

### monocle

`monocle` keeps the focused pane zoomed using tmux's native zoom support.

#### Behavior

- when selected on a window with more than one pane, the focused pane stays
  zoomed
- splitting the zoomed pane keeps the new pane zoomed
- selecting another pane re-zooms the new active pane because mosaic relayouts
  on `after-select-pane`
- there is no primary pane or master size, so `promote` and `resize-master` are
  not implemented

#### Supported operations

| Op | Support | Behavior |
| --- | --- | --- |
| `toggle` | yes | Turn the current window layout off |
| `relayout` | yes | Re-zoom the active pane on the current window |
| `promote` | no | Surfaces a tmux message |
| `resize-master ±N` | no | Surfaces a tmux message |

#### Example config

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
