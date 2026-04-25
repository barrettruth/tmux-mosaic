# Algorithms

Select an algorithm per window with:

```tmux
set-option -wq @mosaic-algorithm grid
```

Setting `@mosaic-algorithm` on a window implies enabled.

Use `@mosaic-enabled 1` when you want the current window to use the default
algorithm without setting a window override:

```tmux
set-option -wq @mosaic-enabled 1
```

If an enabled window does not set `@mosaic-algorithm`, mosaic falls back to
`@mosaic-default-algorithm`, which defaults to `master-stack`.

```tmux
set-option -gq @mosaic-default-algorithm monocle
```

All algorithms support `toggle` and `relayout`. Unsupported operations surface a
tmux message instead of failing hard. Mosaic only relayouts windows that are
enabled and have more than one pane. Set `@mosaic-enabled` to `0` if you want to
suppress a window-specific `@mosaic-algorithm`.

| Algorithm         | Default | Backing tmux layout | `promote` | `resize-master` | Notes                                     | Page                                  |
| ----------------- | ------- | ------------------- | --------- | --------------- | ----------------------------------------- | ------------------------------------- |
| `master-stack`    | yes     | `main-*` family     | yes       | yes             | One master pane plus equal-split stack    | [master-stack](master-stack.md)       |
| `even-vertical`   | no      | `even-vertical`     | no        | no              | Equal-height panes in one column          | [even-vertical](even-vertical.md)     |
| `even-horizontal` | no      | `even-horizontal`   | no        | no              | Equal-width panes in one row              | [even-horizontal](even-horizontal.md) |
| `grid`            | no      | `tiled`             | no        | no              | Equal-size grid using tmux's tiled layout | [grid](grid.md)                       |
| `monocle`         | no      | tmux zoom           | no        | no              | Keeps the focused pane zoomed             | [monocle](monocle.md)                 |
