# tmux-mosaic

**Pane tiling layouts for tmux**

A tmux plugin that applies tiling layouts, tracks which panes belong to them, and lets native tmux pane operations either join or stay outside the layout.

## Dependencies

- [tmux](https://github.com/tmux/tmux) 3.2+
- [bash](https://git.savannah.gnu.org/cgit/bash.git)

## Installation

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

Use the `master-stack` layout and set `@mosaic-auto-apply` to `managed`, which
keeps plain tmux splits outside the layout until you explicitly adopt them:

```tmux
set-option -gwq @mosaic-layout master-stack
set-option -gwq @mosaic-auto-apply managed
```

Because those are global settings, new windows inherit the same default layout
and apply mode. A fresh one-pane window still looks ordinary until you split it
or add panes.

Set up some default mappings for adopting panes into the layout, creating owned
panes, and working the current layout:

```tmux
bind Enter run '#{E:@mosaic-exec} promote'
bind -r ,  run '#{E:@mosaic-exec} resize-master -5'
bind -r .  run '#{E:@mosaic-exec} resize-master +5'
bind N     run '#{E:@mosaic-exec} new-pane'
bind A     run '#{E:@mosaic-exec} adopt'
bind T     run '#{E:@mosaic-exec} toggle'
```

Sometimes another layout works better for your task. Change the current window
layout to grid:

```tmux
bind G     set-option -wq @mosaic-layout grid
```

or reset back to the global default:

```tmux
bind U     set-option -wqu @mosaic-layout
```

The section below explains what `managed` changes and how the other apply modes
behave.

See [Layouts](#layouts) for layout-specific mappings and example bindings.

## Pane Ownership Model

Once a tmux window can contain both panes that should participate in a Mosaic
layout and panes created or moved in outside it, Mosaic needs a way to tell
which panes it owns before it can safely relayout, sync sizes, or recover.

`@mosaic-layout` picks a layout for a window. Mosaic separately tracks whether
the panes in that window belong to the current managed layout. When Mosaic
first manages a window, it stamps the current panes with a window-specific
generation. Panes created or moved in outside Mosaic can stay foreign until
you adopt them.

### `@mosaic-auto-apply`

The main user-facing choice is `@mosaic-auto-apply`, which decides what native
tmux structural commands should do when they create or expose panes that may
not belong to the current layout.

| Value     | Raw `split-window` | When to use it |
| --------- | ------------------ | -------------- |
| `full`    | Default. Adopt the new pane before structural relayout, so raw tmux splits join Mosaic. | You want native tmux pane commands to behave like part of the active layout. |
| `managed` | Leave the new pane foreign, mark the window suspended, and skip structural auto-relayout and size sync until you recover. | You want temporary helper panes that Mosaic ignores until you explicitly adopt them. |
| `none`    | Leave the new pane foreign and skip structural auto-apply. Explicit `new-pane`, `adopt`, and local `@mosaic-layout` changes still work. | You want Mosaic only for explicit actions. |

Under the hood, that ownership tracking still leaves each window in one of
three states: `managed` when all panes belong to the current generation,
`suspended` when foreign panes are present and Mosaic has stopped structural
auto-apply, and unowned when no layout is active for the window.

### Explicit actions and recovery

Those modes mainly affect what happens when you use tmux's built-in structural
commands. Mosaic's explicit actions are the tools for adding owned panes on
purpose or recovering a window after foreign panes appear.

| Action     | What it does |
| ---------- | ------------ |
| `new-pane` | Creates an owned pane, preserves the current path, appends it to the end of the layout's pane order, and relayouts once. |
| `adopt`    | Rotates the window generation, claims all current panes, and relayouts once. |

In `managed` mode, a raw `split-window` suspends the window until you close the
foreign pane, run `adopt`, or set a new local `@mosaic-layout`.

`new-pane`, `promote`, and `resize-master` refuse suspended windows with
`mosaic: window is suspended; adopt panes first`.

## Layouts

The sections below describe the pane arrangements once a window is managed by
Mosaic. `new-pane` always appends to the end of the layout's pane order; the
notes below describe what that means visually for each layout. The ownership
and auto-apply rules above determine whether native tmux pane operations join
the layout automatically.

The following are provided:

<details>
<summary><code>master-stack</code> — one or more master panes plus equal-split stack</summary>

### Behavior

This keeps the first `@mosaic-nmaster` panes in the master area and the rest in
an equal-split stack. `@mosaic-orientation` chooses whether the master area
sits on the left, right, top, or bottom. `resize-master` changes the size of
the whole master area, not individual master panes. If you kill inside the
master area, the next pane in tmux's pane order fills the gap on the next
relayout, and if you drag-resize the master/stack boundary, Mosaic syncs that
size back into `@mosaic-mfact`. If `@mosaic-nmaster` is at least the pane
count, all panes become masters and Mosaic falls back to an equal split in the
chosen axis.

### Preview

![master-stack layout preview](https://github.com/user-attachments/assets/df9167e1-8e5b-4260-941d-b036049bd1e3)

### Core actions

| Command                        | Behavior                                                                  |
| ------------------------------ | ------------------------------------------------------------------------- |
| `toggle`                       | Turn `master-stack` off on the current window.                            |
| `relayout`                     | Re-apply the current orientation and `@mosaic-mfact`.                     |
| `new-pane`                     | Create an owned pane and append it to the end of pane order; with a stack present, it lands at the stack end. |
| `promote`                      | Focused pane becomes the first master. On the first master, rotate the next pane forward. |
| `resize-master ±N`             | Change the whole master-region size for the current window, clamped to 5–95. |
| `select-pane -t :.-` (builtin) | Focus the previous pane in stack order.                                   |
| `select-pane -t :.+` (builtin) | Focus the next pane in stack order.                                       |
| `swap-pane -U` (builtin)       | Move the current pane up the stack.                                       |
| `swap-pane -D` (builtin)       | Move the current pane down the stack.                                     |
| `split-window` (builtin)       | Add a pane and rebalance master plus stack.                               |
| `kill-pane` (builtin)          | Remove a pane and rebalance; killing the master promotes the stack-top.   |
| `resize-pane` (builtin)        | Resize the master live, then sync the new size back into `@mosaic-mfact`. |

### Relevant options

| Option                | Scope         | Default | Effect                                                         |
| --------------------- | ------------- | ------- | -------------------------------------------------------------- |
| `@mosaic-orientation` | window→global | `left`  | Chooses `left`, `right`, `top`, or `bottom`                    |
| `@mosaic-nmaster`     | window→global | `1`     | Keeps the first N panes in the master area                     |
| `@mosaic-mfact`       | window→global | `50`    | Stores the master size as a percent                            |
| `@mosaic-step`        | global        | `5`     | Used by `resize-master` when you call it without an explicit N |

### Example config

```tmux
set-option -gwq @mosaic-layout master-stack
set-option -gwq @mosaic-orientation right
set-option -gwq @mosaic-nmaster 2

bind Enter run '#{E:@mosaic-exec} promote'
bind -r , run '#{E:@mosaic-exec} resize-master -5'
bind -r . run '#{E:@mosaic-exec} resize-master +5'
bind T run '#{E:@mosaic-exec} toggle'
bind U set-option -wqu @mosaic-layout
```

</details>

<details>
<summary><code>centered-master</code> — center master with side stacks</summary>

### Behavior

This keeps `@mosaic-nmaster` panes in a center column and splits the remaining
panes into left and right stacks. If there is only one stack pane, it falls
back to master plus right stack; otherwise the master stays centered, and an odd
extra stack pane goes to the right. `resize-master` changes the width of the
whole center region, and drag-resizing that boundary syncs back into
`@mosaic-mfact`.

### Preview

![centered-master layout preview](https://github.com/user-attachments/assets/0950960d-5f4f-4564-ac38-4f9fbdd45436)

### Core actions

| Command                        | Behavior                                                                        |
| ------------------------------ | ------------------------------------------------------------------------------- |
| `toggle`                       | Turn `centered-master` off on the current window.                               |
| `relayout`                     | Re-apply the centered master column and side stacks with the current `@mosaic-mfact`. |
| `new-pane`                     | Create an owned pane and append it to the end of pane order; with side stacks present, it joins them instead of displacing current masters. |
| `promote`                      | Focused pane becomes the first master. On the first master, rotate the next master forward. |
| `resize-master ±N`             | Change the whole center-region width for the current window, clamped to 5–95.   |
| `select-pane -t :.-` (builtin) | Focus the previous pane in tmux pane order.                                     |
| `select-pane -t :.+` (builtin) | Focus the next pane in tmux pane order.                                         |
| `swap-pane -U` (builtin)       | Move the current pane earlier in tmux pane order.                               |
| `swap-pane -D` (builtin)       | Move the current pane later in tmux pane order.                                 |
| `split-window` (builtin)       | Add a pane and rebalance the center column plus both side stacks.               |
| `kill-pane` (builtin)          | Remove a pane and rebalance the centered layout.                                |
| `resize-pane` (builtin)        | Resize the center column live, then sync the new width back into `@mosaic-mfact`. |

### Relevant options

| Option            | Scope         | Default | Effect                                              |
| ----------------- | ------------- | ------- | --------------------------------------------------- |
| `@mosaic-nmaster` | window→global | `1`     | Keeps N panes in the center master column           |
| `@mosaic-mfact`   | window→global | `50`    | Stores the center-region width as a percent         |
| `@mosaic-step`    | global        | `5`     | Used by `resize-master` when you call it without N  |

### Example config

```tmux
bind C set-option -wq @mosaic-layout centered-master
bind Enter run '#{E:@mosaic-exec} promote'
bind -r , run '#{E:@mosaic-exec} resize-master -5'
bind -r . run '#{E:@mosaic-exec} resize-master +5'
bind T run '#{E:@mosaic-exec} toggle'
bind U set-option -wqu @mosaic-layout
```

</details>

<details>
<summary><code>three-column</code> — master column plus two slave columns</summary>

### Behavior

This is the plain left-master sibling of `centered-master`. It keeps
`@mosaic-nmaster` panes in a master column on the left and splits the remaining
panes into middle and right slave columns. If there is only one stack pane, it
falls back to master plus right stack; otherwise an odd extra stack pane goes to
the middle column. `resize-master` changes the width of the whole master region,
and drag-resizing that boundary syncs back into `@mosaic-mfact`.

### Preview

![three-column layout preview](https://github.com/user-attachments/assets/f9bc3aea-6b9f-4b8e-a0c4-38e89c23bd9a)

### Core actions

| Command                        | Behavior                                                                        |
| ------------------------------ | ------------------------------------------------------------------------------- |
| `toggle`                       | Turn `three-column` off on the current window.                                  |
| `relayout`                     | Re-apply the left master column and two slave columns with the current `@mosaic-mfact`. |
| `new-pane`                     | Create an owned pane and append it to the end of pane order; with slave columns present, it joins them instead of displacing current masters. |
| `promote`                      | Focused pane becomes the first master. On the first master, rotate the next pane forward. |
| `resize-master ±N`             | Change the whole master-column width for the current window, clamped to 5–95.     |
| `select-pane -t :.-` (builtin) | Focus the previous pane in tmux pane order.                                     |
| `select-pane -t :.+` (builtin) | Focus the next pane in tmux pane order.                                         |
| `swap-pane -U` (builtin)       | Move the current pane earlier in tmux pane order.                               |
| `swap-pane -D` (builtin)       | Move the current pane later in tmux pane order.                                 |
| `split-window` (builtin)       | Add a pane and rebalance the master column plus both slave columns.               |
| `kill-pane` (builtin)          | Remove a pane and rebalance the three-column layout.                            |
| `resize-pane` (builtin)        | Resize the master column live, then sync the new width back into `@mosaic-mfact`. |

### Relevant options

| Option            | Scope         | Default | Effect                                              |
| ----------------- | ------------- | ------- | --------------------------------------------------- |
| `@mosaic-nmaster` | window→global | `1`     | Keeps N panes in the left master column               |
| `@mosaic-mfact`   | window→global | `50`    | Stores the master-region width as a percent           |
| `@mosaic-step`    | global        | `5`     | Used by `resize-master` when you call it without N  |

### Example config

```tmux
bind 3 set-option -wq @mosaic-layout three-column
bind Enter run '#{E:@mosaic-exec} promote'
bind -r , run '#{E:@mosaic-exec} resize-master -5'
bind -r . run '#{E:@mosaic-exec} resize-master +5'
bind T run '#{E:@mosaic-exec} toggle'
bind U set-option -wqu @mosaic-layout
```

</details>

<details>
<summary><code>spiral</code> — dwm-style Fibonacci spiral</summary>

### Behavior

This follows the dwm fibonacci `spiral` layout. The first pane gets a master
region on the left sized by `@mosaic-mfact`, and the remaining panes recurse
through the leftover space in a clockwise spiral. `promote` bubbles the focused
pane into the master slot, `resize-master` changes the first split, and
drag-resizing that master boundary syncs back into `@mosaic-mfact`.

### Preview

![spiral layout preview](https://github.com/user-attachments/assets/4fd5f5a8-10fb-46d9-9ef8-d299fb3b90b6)

### Core actions

| Command                        | Behavior                                                                |
| ------------------------------ | ----------------------------------------------------------------------- |
| `toggle`                       | Turn `spiral` off on the current window.                                |
| `relayout`                     | Re-apply the current Fibonacci spiral with the current `@mosaic-mfact`. |
| `new-pane`                     | Create an owned pane and append it to the end of pane order so it becomes the newest leaf in the spiral pattern. |
| `promote`                      | Focused pane becomes the master pane. On the master pane, rotate the next pane forward. |
| `resize-master ±N`             | Change the first split width for the current window, clamped to 5–95.   |
| `select-pane -t :.-` (builtin) | Focus the previous pane in tmux pane order.                             |
| `select-pane -t :.+` (builtin) | Focus the next pane in tmux pane order.                                 |
| `swap-pane -U` (builtin)       | Move the current pane earlier in tmux pane order.                       |
| `swap-pane -D` (builtin)       | Move the current pane later in tmux pane order.                         |
| `split-window` (builtin)       | Add a pane and rebalance the recursive spiral.                          |
| `kill-pane` (builtin)          | Remove a pane and rebalance the recursive spiral.                       |
| `resize-pane` (builtin)        | Resize the master pane live, then sync the new width back into `@mosaic-mfact`. |

### Relevant options

| Option          | Scope         | Default | Effect                                              |
| --------------- | ------------- | ------- | --------------------------------------------------- |
| `@mosaic-mfact` | window→global | `50`    | Stores the master-split width as a percent         |
| `@mosaic-step`  | global        | `5`     | Used by `resize-master` when you call it without N  |

### Example config

```tmux
bind S set-option -wq @mosaic-layout spiral
bind Enter run '#{E:@mosaic-exec} promote'
bind -r , run '#{E:@mosaic-exec} resize-master -5'
bind -r . run '#{E:@mosaic-exec} resize-master +5'
bind T run '#{E:@mosaic-exec} toggle'
bind U set-option -wqu @mosaic-layout
```

</details>

<details>
<summary><code>dwindle</code> — shrinking Fibonacci sibling of spiral</summary>

### Behavior

This is the shrinking sibling of `spiral`, following the dwm fibonacci
`dwindle` layout. The first pane gets a master region on the left sized by
`@mosaic-mfact`, and the remaining panes recurse through the leftover space in
a steadily shrinking bottom-right pattern. `promote` bubbles the focused pane
into the master slot, `resize-master` changes the first split, and
drag-resizing that master boundary syncs back into `@mosaic-mfact`.

### Preview

![dwindle layout preview](https://github.com/user-attachments/assets/8b583c94-da5e-4e96-808c-669b3657f820)

### Core actions

| Command                        | Behavior                                                                  |
| ------------------------------ | ------------------------------------------------------------------------- |
| `toggle`                       | Turn `dwindle` off on the current window.                                 |
| `relayout`                     | Re-apply the current shrinking Fibonacci layout with the current `@mosaic-mfact`. |
| `new-pane`                     | Create an owned pane and append it to the end of pane order so it becomes the newest leaf in the dwindle pattern. |
| `promote`                      | Focused pane becomes the master pane. On the master pane, rotate the next pane forward. |
| `resize-master ±N`             | Change the first split width for the current window, clamped to 5–95.     |
| `select-pane -t :.-` (builtin) | Focus the previous pane in tmux pane order.                               |
| `select-pane -t :.+` (builtin) | Focus the next pane in tmux pane order.                                   |
| `swap-pane -U` (builtin)       | Move the current pane earlier in tmux pane order.                         |
| `swap-pane -D` (builtin)       | Move the current pane later in tmux pane order.                           |
| `split-window` (builtin)       | Add a pane and rebalance the recursive dwindle pattern.                   |
| `kill-pane` (builtin)          | Remove a pane and rebalance the recursive dwindle pattern.                |
| `resize-pane` (builtin)        | Resize the master pane live, then sync the new width back into `@mosaic-mfact`. |

### Relevant options

| Option          | Scope         | Default | Effect                                              |
| --------------- | ------------- | ------- | --------------------------------------------------- |
| `@mosaic-mfact` | window→global | `50`    | Stores the master-split width as a percent         |
| `@mosaic-step`  | global        | `5`     | Used by `resize-master` when you call it without N  |

### Example config

```tmux
bind D set-option -wq @mosaic-layout dwindle
bind Enter run '#{E:@mosaic-exec} promote'
bind -r , run '#{E:@mosaic-exec} resize-master -5'
bind -r . run '#{E:@mosaic-exec} resize-master +5'
bind T run '#{E:@mosaic-exec} toggle'
bind U set-option -wqu @mosaic-layout
```

</details>

<details>
<summary><code>even-vertical</code> — equal-height panes in one column</summary>

### Behavior

This keeps panes in a single top-to-bottom column with equal heights. While it
is active, splits and kills re-apply the same column layout. There is no
master pane, so `promote` and `resize-master` are not implemented.

### Preview

![even-vertical layout preview](https://github.com/user-attachments/assets/b6ede77c-547a-4f9a-99c2-924abfa7f12a)

### Core actions

| Command                    | Behavior                                               |
| -------------------------- | ------------------------------------------------------ |
| `toggle`                   | Turn `even-vertical` off on the current window.        |
| `relayout`                 | Re-apply the equal-height column.                      |
| `new-pane`                 | Create an owned pane and append it to the bottom of the column. |
| `select-pane -U` (builtin) | Focus the pane above.                                  |
| `select-pane -D` (builtin) | Focus the pane below.                                  |
| `swap-pane -U` (builtin)   | Move the current pane toward the top of the column.    |
| `swap-pane -D` (builtin)   | Move the current pane toward the bottom of the column. |
| `split-window` (builtin)   | Add a pane and rebalance the column.                   |
| `kill-pane` (builtin)      | Remove a pane and rebalance the column.                |

### Example config

```tmux
bind V set-option -wq @mosaic-layout even-vertical
bind T run '#{E:@mosaic-exec} toggle'
bind U set-option -wqu @mosaic-layout
```

</details>

<details>
<summary><code>even-horizontal</code> — equal-width panes in one row</summary>

### Behavior

This keeps panes in a single left-to-right row with equal widths. While it is
active, splits and kills re-apply the same row layout. There is no master
pane, so `promote` and `resize-master` are not implemented.

### Preview

![even-horizontal layout preview](https://github.com/user-attachments/assets/7939f8c8-cd37-4718-bd5d-f51936974ab1)

### Core actions

| Command                    | Behavior                                                |
| -------------------------- | ------------------------------------------------------- |
| `toggle`                   | Turn `even-horizontal` off on the current window.       |
| `relayout`                 | Re-apply the equal-width row.                           |
| `new-pane`                 | Create an owned pane and append it to the right end of the row. |
| `select-pane -L` (builtin) | Focus the pane on the left.                             |
| `select-pane -R` (builtin) | Focus the pane on the right.                            |
| `swap-pane -U` (builtin)   | Move the current pane toward the left side of the row.  |
| `swap-pane -D` (builtin)   | Move the current pane toward the right side of the row. |
| `split-window` (builtin)   | Add a pane and rebalance the row.                       |
| `kill-pane` (builtin)      | Remove a pane and rebalance the row.                    |

### Example config

```tmux
bind H set-option -wq @mosaic-layout even-horizontal
bind T run '#{E:@mosaic-exec} toggle'
bind U set-option -wqu @mosaic-layout
```

</details>

<details>
<summary><code>grid</code> — equal-size tiled grid</summary>

### Behavior

This uses tmux's `tiled` layout and lets tmux choose the row and column shape
from the current pane count. With four panes, it becomes a 2x2 grid. There is
no master pane, so `promote` and `resize-master` are not implemented.

### Preview

![grid layout preview](https://github.com/user-attachments/assets/9fd14c83-0c57-4fc7-b90b-a10caf0c4116)

### Core actions

| Command                    | Behavior                                     |
| -------------------------- | -------------------------------------------- |
| `toggle`                   | Turn `grid` off on the current window.       |
| `relayout`                 | Re-apply tmux's `tiled` layout.              |
| `new-pane`                 | Create an owned pane and append it to the end of pane order, then let tmux retile the grid. |
| `select-pane -L` (builtin) | Focus the pane on the left when one exists.  |
| `select-pane -R` (builtin) | Focus the pane on the right when one exists. |
| `select-pane -U` (builtin) | Focus the pane above when one exists.        |
| `select-pane -D` (builtin) | Focus the pane below when one exists.        |
| `split-window` (builtin)   | Add a pane and retile the grid.              |
| `kill-pane` (builtin)      | Remove a pane and retile the grid.           |

### Example config

```tmux
bind G set-option -wq @mosaic-layout grid
bind T run '#{E:@mosaic-exec} toggle'
bind U set-option -wqu @mosaic-layout
```

</details>

<details>
<summary><code>monocle</code> — keep the focused pane zoomed</summary>

### Behavior

This keeps the focused pane zoomed on windows with more than one pane.
Splitting the zoomed pane keeps the new pane zoomed, and changing focus
re-zooms the new active pane because Mosaic relayouts on `after-select-pane`.
There is no master pane or master size, so `promote` and `resize-master` are
not implemented.

### Preview

![monocle layout preview](https://github.com/user-attachments/assets/629c872f-01a4-464b-818f-3ddec143d7cb)

### Core actions

| Command                        | Behavior                                               |
| ------------------------------ | ------------------------------------------------------ |
| `toggle`                       | Turn `monocle` off on the current window.              |
| `relayout`                     | Re-zoom the active pane.                               |
| `new-pane`                     | Create an owned pane, append it to the end of pane order, and keep the new pane zoomed. |
| `select-pane -t :.-` (builtin) | Show the previous pane and keep it zoomed.             |
| `select-pane -t :.+` (builtin) | Show the next pane and keep it zoomed.                 |
| `split-window` (builtin)       | Add a pane and keep the new pane zoomed.               |
| `kill-pane` (builtin)          | Remove a pane; any remaining active pane stays zoomed. |

### Example config

```tmux
bind Z set-option -wq @mosaic-layout monocle
bind T run '#{E:@mosaic-exec} toggle'
bind U set-option -wqu @mosaic-layout
bind n select-pane -t :.+
bind p select-pane -t :.-
```

</details>

## Acknowledgements

- [Hyprland](https://github.com/hyprwm/Hyprland)
- [dwm](https://dwm.suckless.org/) and [XMonad](https://xmonad.org/)
- [saysjonathan/dwm.tmux](https://github.com/saysjonathan/dwm.tmux)
- [tmux-plugins/tmux-resurrect](https://github.com/tmux-plugins/tmux-resurrect)
