# master-stack

`master-stack` keeps one primary pane and an equal-split stack using tmux's
`main-*` layouts.

## Behavior

- `left`, `right`, `top`, and `bottom` map to tmux's `main-*` layouts
- the master is the first pane in tmux's pane order
- killing the master promotes the stack-top on the next relayout
- drag-resizing the master updates `@mosaic-mfact` for the next relayout

## Supported operations

| Op                 | Behavior                                                          |
| ------------------ | ----------------------------------------------------------------- |
| `toggle`           | Turn `master-stack` off on the current window                     |
| `relayout`         | Re-apply the current orientation and current `@mosaic-mfact`      |
| `promote`          | Focused stack pane becomes master. On master: swap with stack-top |
| `resize-master ±N` | Change `@mosaic-mfact` for the current window, clamped to 5–95    |

## Relevant options

| Option                | Scope         | Default | Effect                                                         |
| --------------------- | ------------- | ------- | -------------------------------------------------------------- |
| `@mosaic-orientation` | window→global | `left`  | Chooses `left`, `right`, `top`, or `bottom`                    |
| `@mosaic-mfact`       | window→global | `50`    | Stores the master size as a percent                            |
| `@mosaic-step`        | global        | `5`     | Used by `resize-master` when you call it without an explicit N |

## Example config

```tmux
set-option -gwq @mosaic-algorithm master-stack
set-option -gwq @mosaic-orientation right

bind Enter run '#{E:@mosaic-exec} promote'
bind -r , run '#{E:@mosaic-exec} resize-master -5'
bind -r . run '#{E:@mosaic-exec} resize-master +5'
bind T run '#{E:@mosaic-exec} toggle'
bind U set-option -wqu @mosaic-algorithm
```
