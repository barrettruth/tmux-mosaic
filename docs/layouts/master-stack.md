# master-stack

`master-stack` keeps one primary pane and an equal-split stack using tmux's
`main-*` layouts.

## Behavior

- `left` uses `main-vertical`
- `right` uses `main-vertical-mirrored`
- `top` uses `main-horizontal`
- `bottom` uses `main-horizontal-mirrored`
- the master is the first pane in tmux's pane order: pane 1 when
  `pane-base-index` is 1, or pane 0 when it is 0
- killing the master promotes the stack-top on the next relayout
- drag-resizing the master updates `@mosaic-mfact`, so the next relayout keeps
  that size
- zoomed panes do not rewrite `@mosaic-mfact`

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

## Example use

```tmux
set-option -wq @mosaic-algorithm master-stack
set-option -wq @mosaic-orientation right

bind Enter run '#{E:@mosaic-exec} promote'
bind -r , run '#{E:@mosaic-exec} resize-master -5'
bind -r . run '#{E:@mosaic-exec} resize-master +5'
```

Unset `@mosaic-algorithm` to turn it off on that window.

Stock tmux still handles focus movement, swapping through the ring, and zoom:

```tmux
bind a select-pane -t :.+
bind f select-pane -t :.-
bind d swap-pane -D
bind u swap-pane -U
bind z resize-pane -Z
```
