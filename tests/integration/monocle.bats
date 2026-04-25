#!/usr/bin/env bats

load '../helpers.bash'

setup() {
  mosaic_setup_server
  mosaic_t set-option -wq -t t:1 "@mosaic-algorithm" "monocle"
}

teardown() {
  mosaic_teardown_server
}

window_zoomed() {
  mosaic_t display-message -p -t "${1:-t:1}" '#{window_zoomed_flag}'
}

active_pane_id() {
  mosaic_t display-message -p -t "${1:-t:1}" '#{pane_id}'
}

@test "monocle: toggle on zooms the focused pane" {
  for _ in 1 2; do mosaic_split; done
  mosaic_t select-pane -t t:1.2
  pid=$(active_pane_id)

  [ "$(window_zoomed)" = "0" ]

  mosaic_op toggle
  sleep 0.2

  [ "$(mosaic_t show-option -wqv -t t:1 @mosaic-enabled)" = "1" ]
  [ "$(window_zoomed)" = "1" ]
  [ "$(active_pane_id)" = "$pid" ]
}

@test "monocle: split keeps the new pane zoomed" {
  mosaic_op toggle
  sleep 0.2

  mosaic_split

  [ "$(mosaic_pane_count)" = "2" ]
  [ "$(window_zoomed)" = "1" ]
  [ "$(mosaic_pane_index)" = "2" ]
}

@test "monocle: selecting the next pane re-zooms the new active pane" {
  for _ in 1 2; do mosaic_split; done

  mosaic_op toggle
  sleep 0.2

  before=$(active_pane_id)

  mosaic_t select-pane -t :.+
  sleep 0.2

  after=$(active_pane_id)
  [ "$after" != "$before" ]
  [ "$(window_zoomed)" = "1" ]
}
