# even-horizontal

`even-horizontal` keeps panes in one row with equal widths using tmux's native
`even-horizontal` layout.

## Behavior

- panes are arranged left to right in a single row
- splits and kills re-apply the row layout while `even-horizontal` is active on
  the window
- there is no primary pane, so `promote` and `resize-master` are not implemented

## Supported operations

| Op                 | Support | Behavior                                         |
| ------------------ | ------- | ------------------------------------------------ |
| `toggle`           | yes     | Turn the current window layout off               |
| `relayout`         | yes     | Re-apply `even-horizontal` to the current window |
| `promote`          | no      | Surfaces a tmux message                          |
| `resize-master ±N` | no      | Surfaces a tmux message                          |

## Example config

```tmux
bind H set-option -wq @mosaic-algorithm even-horizontal
bind T run '#{E:@mosaic-exec} toggle'
bind U set-option -wqu @mosaic-algorithm
```
