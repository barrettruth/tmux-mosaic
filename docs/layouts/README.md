# Layouts

Set a global layout default for all windows with:

```tmux
set-option -gwq @mosaic-algorithm master-stack
```

Override just the current window with:

```tmux
set-option -wq @mosaic-algorithm grid
```

Disable mosaic on just the current window with:

```tmux
set-option -wq @mosaic-algorithm off
```

Unset the window-local value to fall back to the global setting again:

```tmux
set-option -wqu @mosaic-algorithm
```

Each layout page includes a short tmux.conf example for using that layout in a
real setup.

All layouts support `toggle` and `relayout`. Unsupported operations surface a
tmux message instead of failing hard. `toggle` disables the current window; if
the window is locally `off` and a global layout is configured, `toggle`
re-enables the global setting. Mosaic only relayouts windows whose effective
`@mosaic-algorithm` resolves to a layout and that have more than one pane.
Invalid algorithm names fail when an operation tries to load them.

| Layout            | Backing tmux layout | `promote` | `resize-master` | Notes                                     | Page                                  |
| ----------------- | ------------------- | --------- | --------------- | ----------------------------------------- | ------------------------------------- |
| `master-stack`    | `main-*` family     | yes       | yes             | One master pane plus equal-split stack    | [master-stack](master-stack.md)       |
| `even-vertical`   | `even-vertical`     | no        | no              | Equal-height panes in one column          | [even-vertical](even-vertical.md)     |
| `even-horizontal` | `even-horizontal`   | no        | no              | Equal-width panes in one row              | [even-horizontal](even-horizontal.md) |
| `grid`            | `tiled`             | no        | no              | Equal-size grid using tmux's tiled layout | [grid](grid.md)                       |
| `monocle`         | tmux zoom           | no        | no              | Keeps the focused pane zoomed             | [monocle](monocle.md)                 |
