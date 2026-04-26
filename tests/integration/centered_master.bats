#!/usr/bin/env bats

load '../helpers.bash'

setup() {
  mosaic_setup_server
  mosaic_use_algorithm centered-master
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

@test "centered-master: 3 panes center the master between left and right stacks" {
  for _ in 1 2; do mosaic_split; done
  [ "$(mosaic_pane_count)" = "3" ]

  layout=$(mosaic_layout)
  [[ "$layout" == *"{"* ]]

  [ "$(pane_field t:1 1 2)" = "0" ]
  [ "$(pane_field t:1 2 2)" -gt 0 ]
  [ "$(pane_field t:1 3 2)" -gt "$(pane_field t:1 2 2)" ]
  [ "$(pane_field t:1 2 4)" -gt "$(pane_field t:1 1 4)" ]

  pane1_w=$(pane_field t:1 1 4)
  pane3_w=$(pane_field t:1 3 4)
  diff=$((pane1_w - pane3_w))
  [ "${diff#-}" -le 1 ]
}

@test "centered-master: 4 panes give the extra stack pane to the right" {
  for _ in 1 2 3; do mosaic_split; done
  [ "$(mosaic_pane_count)" = "4" ]

  [ "$(pane_field t:1 1 2)" = "0" ]
  [ "$(pane_field t:1 2 2)" -gt 0 ]
  [ "$(pane_field t:1 3 2)" -gt "$(pane_field t:1 2 2)" ]
  [ "$(pane_field t:1 4 2)" = "$(pane_field t:1 3 2)" ]

  pane3_h=$(pane_field t:1 3 5)
  pane4_h=$(pane_field t:1 4 5)
  diff=$((pane3_h - pane4_h))
  [ "${diff#-}" -le 1 ]
}

@test "centered-master: 5 panes split the side stacks evenly" {
  for _ in 1 2 3 4; do mosaic_split; done
  [ "$(mosaic_pane_count)" = "5" ]

  [ "$(pane_field t:1 1 2)" = "0" ]
  [ "$(pane_field t:1 2 2)" = "0" ]
  [ "$(pane_field t:1 3 2)" -gt 0 ]
  [ "$(pane_field t:1 4 2)" -gt "$(pane_field t:1 3 2)" ]
  [ "$(pane_field t:1 5 2)" = "$(pane_field t:1 4 2)" ]

  left_diff=$(($(pane_field t:1 1 5) - $(pane_field t:1 2 5)))
  right_diff=$(($(pane_field t:1 4 5) - $(pane_field t:1 5 5)))
  [ "${right_diff#-}" -le 1 ]
  [ "${left_diff#-}" -le 1 ]
}

@test "centered-master: nmaster 2 keeps both masters in the center column" {
  set_nmaster t:1 2
  for _ in 1 2 3; do mosaic_split; done

  [ "$(pane_field t:1 1 2)" = "0" ]
  [ "$(pane_field t:1 2 2)" -gt 0 ]
  [ "$(pane_field t:1 3 2)" = "$(pane_field t:1 2 2)" ]
  [ "$(pane_field t:1 4 2)" -gt "$(pane_field t:1 2 2)" ]

  pane2_h=$(pane_field t:1 2 5)
  pane3_h=$(pane_field t:1 3 5)
  diff=$((pane2_h - pane3_h))
  [ "${diff#-}" -le 1 ]
}

@test "centered-master: promote from stack makes the focused pane primary master" {
  for _ in 1 2 3; do mosaic_split; done
  mosaic_t select-pane -t t:1.4
  pid=$(mosaic_t display-message -p -t t:1 '#{pane_id}')

  mosaic_op promote

  [ "$(mosaic_pane_index)" = "2" ]
  [ "$(mosaic_pane_id_at t:1.2)" = "$pid" ]
}

@test "centered-master: promote on primary master with nmaster 2 rotates the next master forward" {
  set_nmaster t:1 2
  for _ in 1 2 3; do mosaic_split; done
  master1_pid=$(mosaic_pane_id_at t:1.2)
  master2_pid=$(mosaic_pane_id_at t:1.3)
  mosaic_t select-pane -t t:1.2

  mosaic_op promote

  [ "$(mosaic_pane_id_at t:1.2)" = "$master2_pid" ]
  [ "$(mosaic_pane_id_at t:1.3)" = "$master1_pid" ]
}

@test "centered-master: resize-master changes the center width" {
  for _ in 1 2 3; do mosaic_split; done

  fp=$(mosaic_fingerprint t:1)

  mosaic_op resize-master +10
  mosaic_wait_fingerprint_changed_from "$fp" t:1

  [ "$(mosaic_t show-option -wqv -t t:1 @mosaic-mfact)" = "60" ]
  pane2_w=$(pane_field t:1 2 4)
  pane1_w=$(pane_field t:1 1 4)
  [ "$pane2_w" -ge 118 ]
  [ "$pane2_w" -le 121 ]
  [ "$pane2_w" -gt "$pane1_w" ]
}

@test "centered-master: kill-pane keeps the master centered on relayout" {
  for _ in 1 2 3 4; do mosaic_split; done
  [ "$(mosaic_pane_count)" = "5" ]

  mosaic_t kill-pane -t t:1.4
  mosaic_wait_pane_count_gt 0 t:1.4
  mosaic_quiesce

  [ "$(mosaic_pane_count)" = "4" ]
  [ "$(pane_field t:1 1 2)" = "0" ]
  [ "$(pane_field t:1 2 2)" -gt 0 ]
  [ "$(pane_field t:1 3 2)" -gt "$(pane_field t:1 2 2)" ]
  [ "$(pane_field t:1 4 2)" = "$(pane_field t:1 3 2)" ]
}

@test "centered-master: drag-resize syncs mfact from the center width" {
  for _ in 1 2; do mosaic_split; done
  mosaic_t resize-pane -t t:1.2 -x 120
  mosaic_wait_option @mosaic-mfact 60 t:1
  [ "$(mosaic_t show-option -wqv -t t:1 @mosaic-mfact)" = "60" ]

  mosaic_split
  pane2_w=$(pane_field t:1 2 4)
  [ "$pane2_w" -ge 118 ]
  [ "$pane2_w" -le 121 ]
}
