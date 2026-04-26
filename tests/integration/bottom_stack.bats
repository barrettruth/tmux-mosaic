#!/usr/bin/env bats

load '../helpers.bash'

setup() {
  mosaic_setup_server
  mosaic_use_algorithm bottom-stack
}

teardown() {
  mosaic_teardown_server
}

set_nmaster() {
  mosaic_t set-option -wq -t "${1:-t:1}" "@mosaic-nmaster" "${2:?nmaster required}"
}

pane_field() {
  mosaic_t list-panes -t "${1:-t:1}" -F '#{pane_index} #{pane_left} #{pane_top} #{pane_width} #{pane_height}' |
    awk -v idx="${2:?pane index required}" -v field="${3:?field required}" '$1 == idx { print $field }'
}

@test "bottom-stack: 4 panes keep the master on top and the stack below" {
  for _ in 1 2 3; do mosaic_split; done
  [ "$(mosaic_pane_count)" = "4" ]

  layout=$(mosaic_layout)
  [[ "$layout" == *"["* ]]
  [[ "$layout" == *"{"* ]]

  [ "$(pane_field t:1 1 3)" = "0" ]
  [ "$(pane_field t:1 2 3)" -gt 0 ]
  [ "$(pane_field t:1 1 4)" -gt "$(pane_field t:1 2 4)" ]

  pane2_w=$(pane_field t:1 2 4)
  pane3_w=$(pane_field t:1 3 4)
  diff=$((pane2_w - pane3_w))
  [ "${diff#-}" -le 1 ]
}

@test "bottom-stack: nmaster 2 keeps both masters in the top row" {
  set_nmaster t:1 2
  for _ in 1 2 3; do mosaic_split; done

  [ "$(pane_field t:1 1 3)" = "0" ]
  [ "$(pane_field t:1 2 3)" = "0" ]
  [ "$(pane_field t:1 3 3)" -gt 0 ]

  pane1_w=$(pane_field t:1 1 4)
  pane2_w=$(pane_field t:1 2 4)
  diff=$((pane1_w - pane2_w))
  [ "${diff#-}" -le 1 ]
}

@test "bottom-stack: promote from stack makes the focused pane primary master" {
  for _ in 1 2 3; do mosaic_split; done
  mosaic_t select-pane -t t:1.3
  pid=$(mosaic_t display-message -p -t t:1 '#{pane_id}')

  mosaic_op promote

  [ "$(mosaic_pane_index)" = "1" ]
  [ "$(mosaic_t display-message -p -t t:1 '#{pane_id}')" = "$pid" ]
}

@test "bottom-stack: resize-master writes main-pane-height" {
  for _ in 1 2 3; do mosaic_split; done

  fp=$(mosaic_fingerprint t:1)


  mosaic_op resize-master +10
  mosaic_wait_fingerprint_changed_from "$fp" t:1 || true

  [ "$(mosaic_t show-option -wqv -t t:1 @mosaic-mfact)" = "60" ]
  [ "$(mosaic_t show-option -wqv -t t:1 main-pane-height)" = "60%" ]
}

@test "bottom-stack: kill rebalances the bottom stack" {
  for _ in 1 2 3 4; do mosaic_split; done
  [ "$(mosaic_pane_count)" = "5" ]

  mosaic_t kill-pane -t t:1.3
  mosaic_wait_pane_count_gt 0 t:1.3 || true
  mosaic_quiesce

  [ "$(mosaic_pane_count)" = "4" ]
  pane2_w=$(pane_field t:1 2 4)
  pane3_w=$(pane_field t:1 3 4)
  diff=$((pane2_w - pane3_w))
  [ "${diff#-}" -le 1 ]
}

@test "bottom-stack: drag-resize syncs mfact from the master height" {
  mosaic_split
  mosaic_t resize-pane -t t:1.1 -y 30
  mosaic_wait_option_changed_from @mosaic-mfact 50 t:1 || true
  mfact=$(mosaic_t show-option -wqv -t t:1 @mosaic-mfact)
  [ "$mfact" -ge 55 ]
  [ "$mfact" -le 65 ]

  mosaic_split
  pane_h=$(pane_field t:1 1 5)
  [ "$pane_h" -ge 28 ]
  [ "$pane_h" -le 31 ]
}
