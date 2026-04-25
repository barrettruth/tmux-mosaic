# grid

`grid` uses tmux's native `tiled` layout for an equal-size grid.

## Behavior

- tmux chooses the row and column shape from the current pane count
- with four panes, the layout becomes a 2x2 grid
- there is no primary pane, so `promote` and `resize-master` are not implemented

## Supported operations

| Op                 | Support | Behavior                               |
| ------------------ | ------- | -------------------------------------- |
| `toggle`           | yes     | Turn the current window layout off     |
| `relayout`         | yes     | Re-apply tmux's `tiled` layout         |
| `promote`          | no      | Surfaces a tmux message                |
| `resize-master ±N` | no      | Surfaces a tmux message                |

## Example config

```tmux
bind G set-option -wq @mosaic-algorithm grid
bind T run '#{E:@mosaic-exec} toggle'
bind U set-option -wqu @mosaic-algorithm
```
