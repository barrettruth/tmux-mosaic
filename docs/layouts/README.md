# Layouts

Layouts are the pane arrangements Mosaic can apply. The table below lists the
available layouts, the tmux primitive behind each one, and which operations
they support.

## Global options

| Option                | Default | Effect                                              |
| --------------------- | ------- | --------------------------------------------------- |
| `@mosaic-algorithm`   | unset   | Global default layout for windows without a local override |
| `@mosaic-orientation` | `left`  | For `master-stack`: `left`, `right`, `top`, or `bottom` |
| `@mosaic-mfact`       | `50`    | For `master-stack`: master size as a percent        |
| `@mosaic-step`        | `5`     | Default `resize-master` step                        |

| Layout            | Backing tmux layout | `promote` | `resize-master` | Notes                                     | Page                                  |
| ----------------- | ------------------- | --------- | --------------- | ----------------------------------------- | ------------------------------------- |
| `master-stack`    | `main-*` family     | yes       | yes             | One master pane plus equal-split stack    | [master-stack](master-stack.md)       |
| `even-vertical`   | `even-vertical`     | no        | no              | Equal-height panes in one column          | [even-vertical](even-vertical.md)     |
| `even-horizontal` | `even-horizontal`   | no        | no              | Equal-width panes in one row              | [even-horizontal](even-horizontal.md) |
| `grid`            | `tiled`             | no        | no              | Equal-size grid using tmux's tiled layout | [grid](grid.md)                       |
| `monocle`         | tmux zoom           | no        | no              | Keeps the focused pane zoomed             | [monocle](monocle.md)                 |
