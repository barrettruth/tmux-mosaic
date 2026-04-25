# monocle

`monocle` keeps the focused pane zoomed using tmux's native zoom support.

## Behavior

- when enabled on a window with more than one pane, the focused pane stays
  zoomed
- splitting the zoomed pane keeps the new pane zoomed
- selecting another pane re-zooms the new active pane because mosaic relayouts
  on `after-select-pane`
- there is no primary pane or master size, so `promote` and `resize-master` are
  not implemented

## Supported operations

| Op                 | Support | Behavior                                         |
| ------------------ | ------- | ------------------------------------------------ |
| `toggle`           | yes     | Enable or disable monocle on the current window  |
| `relayout`         | yes     | Re-zoom the active pane if the window is enabled |
| `promote`          | no      | Surfaces a tmux message                          |
| `resize-master ±N` | no      | Surfaces a tmux message                          |

## Relevant options

No algorithm-specific options. Set `@mosaic-algorithm` to `monocle` to select
it; that implies enabled unless `@mosaic-enabled` is explicitly `0`.
`@mosaic-orientation`, `@mosaic-mfact`, and `@mosaic-step` are ignored.

## Example use

```tmux
set-option -wq @mosaic-algorithm monocle
```

Mosaic does not install focus bindings. Use stock tmux commands to choose which
pane becomes zoomed:

```tmux
bind n select-pane -t :.+
bind p select-pane -t :.-
```
