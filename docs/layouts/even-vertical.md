# even-vertical

`even-vertical` keeps panes in one column with equal heights using tmux's native
`even-vertical` layout.

## Behavior

- panes are stacked top to bottom in a single column
- splits and kills re-apply the column layout while `even-vertical` is active
  on the window
- there is no primary pane, so `promote` and `resize-master` are not implemented

## Supported operations

| Op                 | Support | Behavior                                       |
| ------------------ | ------- | ---------------------------------------------- |
| `toggle`           | yes     | Turn the current window layout off             |
| `relayout`         | yes     | Re-apply `even-vertical` to the current window |
| `promote`          | no      | Surfaces a tmux message                        |
| `resize-master ±N` | no      | Surfaces a tmux message                        |

## Example config

```tmux
bind V set-option -wq @mosaic-algorithm even-vertical
bind T run '#{E:@mosaic-exec} toggle'
bind U set-option -wqu @mosaic-algorithm
```
