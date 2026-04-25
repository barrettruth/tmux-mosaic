# even-vertical

`even-vertical` keeps panes in one column with equal heights using tmux's native
`even-vertical` layout.

## Behavior

- panes are stacked top to bottom in a single column
- heights stay equal-split, with at most a one-cell remainder from tmux's
  geometry
- splits and kills re-apply the column layout while `@mosaic-algorithm` is set
  on the window
- there is no primary pane, so `promote` and `resize-master` are not implemented

## Supported operations

| Op                 | Support | Behavior                                       |
| ------------------ | ------- | ---------------------------------------------- |
| `toggle`           | yes     | Turn the current window layout off             |
| `relayout`         | yes     | Re-apply `even-vertical` to the current window |
| `promote`          | no      | Surfaces a tmux message                        |
| `resize-master ±N` | no      | Surfaces a tmux message                        |

## Relevant options

No layout-specific options. Set `@mosaic-algorithm` to `even-vertical` to
select it. Unset `@mosaic-algorithm` to disable mosaic on that window.
`@mosaic-orientation`, `@mosaic-mfact`, and `@mosaic-step` are ignored.

## Example use

```tmux
set-option -wq @mosaic-algorithm even-vertical
```

Use stock tmux commands for focus movement, swapping, and zoom.
