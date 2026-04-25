# grid

`grid` uses tmux's native `tiled` layout for an equal-size grid.

## Behavior

- tmux chooses the row and column shape from the current pane count
- with four panes, the layout becomes a 2x2 grid
- pane widths and heights stay balanced, with at most a one-cell remainder from
  tmux's geometry
- there is no primary pane, so `promote` and `resize-master` are not implemented

## Supported operations

| Op                 | Support | Behavior                               |
| ------------------ | ------- | -------------------------------------- |
| `toggle`           | yes     | Turn the current window layout off     |
| `relayout`         | yes     | Re-apply tmux's `tiled` layout         |
| `promote`          | no      | Surfaces a tmux message                |
| `resize-master ±N` | no      | Surfaces a tmux message                |

## Relevant options

No layout-specific options. Set `@mosaic-algorithm` to `grid` to select it.
Unset `@mosaic-algorithm` to disable mosaic on that window.
`@mosaic-orientation`, `@mosaic-mfact`, and `@mosaic-step` are ignored.

## Example use

```tmux
set-option -wq @mosaic-algorithm grid
```

Use stock tmux commands for focus movement, swapping, and zoom.
