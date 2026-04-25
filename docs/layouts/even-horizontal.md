# even-horizontal

`even-horizontal` keeps panes in one row with equal widths using tmux's native
`even-horizontal` layout.

## Behavior

- panes are arranged left to right in a single row
- widths stay equal-split, with at most a one-cell remainder from tmux's
  geometry
- splits and kills re-apply the row layout while mosaic is enabled
- there is no primary pane, so `promote` and `resize-master` are not implemented

## Supported operations

| Op                 | Support | Behavior                                         |
| ------------------ | ------- | ------------------------------------------------ |
| `toggle`           | yes     | Enable or disable tiling on the current window   |
| `relayout`         | yes     | Re-apply `even-horizontal` to the current window |
| `promote`          | no      | Surfaces a tmux message                          |
| `resize-master ±N` | no      | Surfaces a tmux message                          |

## Relevant options

No layout-specific options. Set `@mosaic-algorithm` to `even-horizontal` to
select it; that implies enabled unless `@mosaic-enabled` is explicitly `0`.
`@mosaic-orientation`, `@mosaic-mfact`, and `@mosaic-step` are ignored.

## Example use

```tmux
set-option -wq @mosaic-algorithm even-horizontal
```

Use stock tmux commands for focus movement, swapping, and zoom.
