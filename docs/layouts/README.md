# Layouts

Select a layout per window with:

```tmux
set-option -wq @mosaic-algorithm grid
```

Unset it to turn mosaic off on that window:

```tmux
set-option -wqu @mosaic-algorithm
```

All layouts support `toggle` and `relayout`. Unsupported operations surface a
tmux message instead of failing hard. `toggle` turns the current window layout
off. Mosaic only relayouts windows whose `@mosaic-algorithm` is set and that
have more than one pane. Invalid algorithm names fail when an operation tries
to load them.

| Layout            | Backing tmux layout | `promote` | `resize-master` | Notes                                     | Page                                  |
| ----------------- | ------------------- | --------- | --------------- | ----------------------------------------- | ------------------------------------- |
| `master-stack`    | `main-*` family     | yes       | yes             | One master pane plus equal-split stack    | [master-stack](master-stack.md)       |
| `even-vertical`   | `even-vertical`     | no        | no              | Equal-height panes in one column          | [even-vertical](even-vertical.md)     |
| `even-horizontal` | `even-horizontal`   | no        | no              | Equal-width panes in one row              | [even-horizontal](even-horizontal.md) |
| `grid`            | `tiled`             | no        | no              | Equal-size grid using tmux's tiled layout | [grid](grid.md)                       |
| `monocle`         | tmux zoom           | no        | no              | Keeps the focused pane zoomed             | [monocle](monocle.md)                 |
