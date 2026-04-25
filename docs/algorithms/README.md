# Algorithms

This directory is the start of the algorithm reference. This first pass creates
the structure and a minimal support matrix; the per-algorithm pages are still
templates.

| Algorithm         | Default | Backing tmux layout | Implemented ops                                  | Page                                  |
| ----------------- | ------- | ------------------- | ------------------------------------------------ | ------------------------------------- |
| `master-stack`    | yes     | `main-*` family     | `toggle`, `promote`, `resize-master`, `relayout` | [master-stack](master-stack.md)       |
| `even-vertical`   | no      | `even-vertical`     | `toggle`, `relayout`                             | [even-vertical](even-vertical.md)     |
| `even-horizontal` | no      | `even-horizontal`   | `toggle`, `relayout`                             | [even-horizontal](even-horizontal.md) |
| `grid`            | no      | `tiled`             | `toggle`, `relayout`                             | [grid](grid.md)                       |
| `monocle`         | no      | tmux zoom           | `toggle`, `relayout`                             | [monocle](monocle.md)                 |

Algorithms that do not implement an operation will surface a message when you
call it directly.
