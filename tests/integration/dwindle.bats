#!/usr/bin/env bats

load '../helpers.bash'

setup() {
  _mosaic_setup_server
  _mosaic_use_layout dwindle
}

teardown() {
  _mosaic_teardown_server
}

pane_field() {
  _mosaic_t list-panes -t "${1:-t:1}" -F '#{pane_index} #{pane_left} #{pane_top} #{pane_width} #{pane_height}' |
    awk -v idx="${2:?pane index required}" -v field="${3:?field required}" '$1 == idx { print $field }'
}

@test "dwindle: 2 panes keep the master pane on the left" {
  _mosaic_split
  [ "$(_mosaic_pane_count)" = "2" ]

  [ "$(pane_field t:1 1 2)" = "0" ]
  [ "$(pane_field t:1 2 2)" -gt 0 ]
  [ "$(pane_field t:1 1 4)" -gt "$(pane_field t:1 2 4)" ]
  [ "$(pane_field t:1 1 5)" = "$(pane_field t:1 2 5)" ]
}

@test "dwindle: 3 panes place the third pane below the second" {
  for _ in 1 2; do _mosaic_split; done
  [ "$(_mosaic_pane_count)" = "3" ]

  layout=$(_mosaic_layout)
  [[ "$layout" == *"{"* ]]
  [[ "$layout" == *"["* ]]

  [ "$(pane_field t:1 2 2)" -gt 0 ]
  [ "$(pane_field t:1 3 2)" = "$(pane_field t:1 2 2)" ]
  [ "$(pane_field t:1 3 3)" -gt "$(pane_field t:1 2 3)" ]
  [ "$(pane_field t:1 1 4)" -gt "$(pane_field t:1 2 4)" ]
}

@test "dwindle: 4 panes split the lower-right area left then right" {
  for _ in 1 2 3; do _mosaic_split; done
  [ "$(_mosaic_pane_count)" = "4" ]

  [ "$(pane_field t:1 3 3)" -gt "$(pane_field t:1 2 3)" ]
  [ "$(pane_field t:1 4 3)" = "$(pane_field t:1 3 3)" ]
  [ "$(pane_field t:1 4 2)" -gt "$(pane_field t:1 3 2)" ]
  [ "$(pane_field t:1 2 4)" -gt "$(pane_field t:1 3 4)" ]
}

@test "dwindle: 5 panes keep shrinking down the right edge" {
  for _ in 1 2 3 4; do _mosaic_split; done
  [ "$(_mosaic_pane_count)" = "5" ]

  [ "$(pane_field t:1 4 2)" -gt "$(pane_field t:1 3 2)" ]
  [ "$(pane_field t:1 5 2)" = "$(pane_field t:1 4 2)" ]
  [ "$(pane_field t:1 5 3)" -gt "$(pane_field t:1 4 3)" ]
  [ "$(pane_field t:1 4 4)" = "$(pane_field t:1 5 4)" ]
}

@test "dwindle: 6 panes keep shrinking into the lower-right corner" {
  for _ in 1 2 3 4 5; do _mosaic_split; done
  [ "$(_mosaic_pane_count)" = "6" ]

  [ "$(pane_field t:1 5 3)" -gt "$(pane_field t:1 4 3)" ]
  [ "$(pane_field t:1 6 3)" = "$(pane_field t:1 5 3)" ]
  [ "$(pane_field t:1 6 2)" -gt "$(pane_field t:1 5 2)" ]
  [ "$(pane_field t:1 5 4)" = "$(pane_field t:1 6 4)" ]
}

@test "dwindle: promote from a deep pane makes it the master pane" {
  for _ in 1 2 3 4; do _mosaic_split; done
  _mosaic_t select-pane -t t:1.5
  pid=$(_mosaic_t display-message -p -t t:1 '#{pane_id}')

  _mosaic_op promote

  [ "$(_mosaic_pane_index)" = "1" ]
  [ "$(_mosaic_pane_id_at t:1.1)" = "$pid" ]
}

@test "dwindle: promote on the master pane swaps with the next pane" {
  for _ in 1 2; do _mosaic_split; done
  master_pid=$(_mosaic_pane_id_at t:1.1)
  next_pid=$(_mosaic_pane_id_at t:1.2)
  _mosaic_t select-pane -t t:1.1

  _mosaic_op promote

  [ "$(_mosaic_pane_id_at t:1.1)" = "$next_pid" ]
  [ "$(_mosaic_pane_id_at t:1.2)" = "$master_pid" ]
}

@test "dwindle: resize-master changes the first split width" {
  for _ in 1 2; do _mosaic_split; done

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

@test "dwindle: kill-pane keeps the recursive shape" {
  for _ in 1 2 3 4 5; do _mosaic_split; done
  [ "$(_mosaic_pane_count)" = "6" ]
  fp=$(_mosaic_fingerprint t:1)

  _mosaic_t kill-pane -t t:1.5
  _mosaic_wait_pane_count_gt 0 t:1.5
  _mosaic_wait_fingerprint_changed_from "$fp" t:1
  _mosaic_quiesce

  [ "$(_mosaic_pane_count)" = "5" ]
  [ "$(pane_field t:1 4 2)" -gt "$(pane_field t:1 3 2)" ]
  [ "$(pane_field t:1 5 2)" = "$(pane_field t:1 4 2)" ]
  [ "$(pane_field t:1 5 3)" -gt "$(pane_field t:1 4 3)" ]
}

@test "dwindle: drag-resize syncs mfact from the master width" {
  for _ in 1 2; do _mosaic_split; done
  _mosaic_t resize-pane -t t:1.1 -x 120
  _mosaic_wait_option @mosaic-mfact 60 t:1
  [ "$(_mosaic_t show-option -wqv -t t:1 @mosaic-mfact)" = "60" ]

  _mosaic_split
  pane1_w=$(pane_field t:1 1 4)
  [ "$pane1_w" -ge 118 ]
  [ "$pane1_w" -le 121 ]
}
