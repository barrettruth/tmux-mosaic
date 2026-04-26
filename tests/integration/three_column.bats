#!/usr/bin/env bats

load '../helpers.bash'

setup() {
  _mosaic_setup_server
  _mosaic_use_layout three-column
}

teardown() {
  _mosaic_teardown_server
}

set_nmaster() {
  _mosaic_t set-option -wq -t "${1:-t:1}" "@mosaic-nmaster" "${2:?nmaster required}"
}

pane_field() {
  _mosaic_t list-panes -t "${1:-t:1}" -F '#{pane_index} #{pane_left} #{pane_top} #{pane_width} #{pane_height}' |
    awk -v idx="${2:?pane index required}" -v field="${3:?field required}" '$1 == idx { print $field }'
}

@test "three-column: 2 panes fall back to master plus one slave column" {
  _mosaic_split
  [ "$(_mosaic_pane_count)" = "2" ]

  [ "$(pane_field t:1 1 2)" = "0" ]
  [ "$(pane_field t:1 2 2)" -gt 0 ]
  [ "$(pane_field t:1 1 4)" -gt "$(pane_field t:1 2 4)" ]
}

@test "three-column: 3 panes create master, middle, and right columns" {
  for _ in 1 2; do _mosaic_split; done
  [ "$(_mosaic_pane_count)" = "3" ]

  layout=$(_mosaic_layout)
  [[ "$layout" == *"{"* ]]

  [ "$(pane_field t:1 1 2)" = "0" ]
  [ "$(pane_field t:1 2 2)" -gt 0 ]
  [ "$(pane_field t:1 3 2)" -gt "$(pane_field t:1 2 2)" ]
  [ "$(pane_field t:1 1 4)" -gt "$(pane_field t:1 2 4)" ]

  diff=$(($(pane_field t:1 2 4) - $(pane_field t:1 3 4)))
  [ "${diff#-}" -le 1 ]
}

@test "three-column: 4 panes give the extra slave pane to the middle column" {
  for _ in 1 2 3; do _mosaic_split; done
  [ "$(_mosaic_pane_count)" = "4" ]

  [ "$(pane_field t:1 1 2)" = "0" ]
  [ "$(pane_field t:1 2 2)" -gt 0 ]
  [ "$(pane_field t:1 3 2)" = "$(pane_field t:1 2 2)" ]
  [ "$(pane_field t:1 4 2)" -gt "$(pane_field t:1 2 2)" ]

  diff=$(($(pane_field t:1 2 5) - $(pane_field t:1 3 5)))
  [ "${diff#-}" -le 1 ]
}

@test "three-column: 5 panes split the slave columns evenly" {
  for _ in 1 2 3 4; do _mosaic_split; done
  [ "$(_mosaic_pane_count)" = "5" ]

  [ "$(pane_field t:1 2 2)" = "$(pane_field t:1 3 2)" ]
  [ "$(pane_field t:1 4 2)" = "$(pane_field t:1 5 2)" ]
  [ "$(pane_field t:1 4 2)" -gt "$(pane_field t:1 2 2)" ]

  middle_diff=$(($(pane_field t:1 2 5) - $(pane_field t:1 3 5)))
  right_diff=$(($(pane_field t:1 4 5) - $(pane_field t:1 5 5)))
  [ "${middle_diff#-}" -le 1 ]
  [ "${right_diff#-}" -le 1 ]
}

@test "three-column: nmaster 2 keeps both masters in the left column" {
  set_nmaster t:1 2
  for _ in 1 2 3; do _mosaic_split; done

  [ "$(pane_field t:1 1 2)" = "0" ]
  [ "$(pane_field t:1 2 2)" = "0" ]
  [ "$(pane_field t:1 3 2)" -gt 0 ]
  [ "$(pane_field t:1 4 2)" -gt "$(pane_field t:1 3 2)" ]

  diff=$(($(pane_field t:1 1 5) - $(pane_field t:1 2 5)))
  [ "${diff#-}" -le 1 ]
}

@test "three-column: promote from a slave pane makes it the first master" {
  for _ in 1 2 3; do _mosaic_split; done
  _mosaic_t select-pane -t t:1.4
  pid=$(_mosaic_t display-message -p -t t:1 '#{pane_id}')

  _mosaic_op promote

  [ "$(_mosaic_pane_index)" = "1" ]
  [ "$(_mosaic_pane_id_at t:1.1)" = "$pid" ]
}

@test "three-column: promote on the first master rotates the next master forward when nmaster is 2" {
  set_nmaster t:1 2
  for _ in 1 2 3; do _mosaic_split; done
  master1_pid=$(_mosaic_pane_id_at t:1.1)
  master2_pid=$(_mosaic_pane_id_at t:1.2)
  _mosaic_t select-pane -t t:1.1

  _mosaic_op promote

  [ "$(_mosaic_pane_id_at t:1.1)" = "$master2_pid" ]
  [ "$(_mosaic_pane_id_at t:1.2)" = "$master1_pid" ]
}

@test "three-column: resize-master changes the master column width" {
  for _ in 1 2 3; do _mosaic_split; done

  fp=$(_mosaic_fingerprint t:1)

  _mosaic_op resize-master +10
  _mosaic_wait_fingerprint_changed_from "$fp" t:1

  [ "$(_mosaic_t show-option -wqv -t t:1 @mosaic-mfact)" = "60" ]
  pane1_w=$(pane_field t:1 1 4)
  pane2_w=$(pane_field t:1 2 4)
  [ "$pane1_w" -ge 118 ]
  [ "$pane1_w" -le 121 ]
  [ "$pane1_w" -gt "$pane2_w" ]
}

@test "three-column: kill-pane keeps the three-column shape" {
  for _ in 1 2 3 4; do _mosaic_split; done
  [ "$(_mosaic_pane_count)" = "5" ]

  _mosaic_t kill-pane -t t:1.3
  _mosaic_wait_pane_count_gt 0 t:1.3
  _mosaic_quiesce

  [ "$(_mosaic_pane_count)" = "4" ]
  [ "$(pane_field t:1 1 2)" = "0" ]
  [ "$(pane_field t:1 2 2)" -gt 0 ]
  [ "$(pane_field t:1 3 2)" = "$(pane_field t:1 2 2)" ]
  [ "$(pane_field t:1 4 2)" -gt "$(pane_field t:1 2 2)" ]
}

@test "three-column: drag-resize syncs mfact from the master width" {
  for _ in 1 2; do _mosaic_split; done
  _mosaic_t resize-pane -t t:1.1 -x 120
  _mosaic_wait_option @mosaic-mfact 60 t:1
  [ "$(_mosaic_t show-option -wqv -t t:1 @mosaic-mfact)" = "60" ]

  _mosaic_split
  pane1_w=$(pane_field t:1 1 4)
  [ "$pane1_w" -ge 118 ]
  [ "$pane1_w" -le 121 ]
}
