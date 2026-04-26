#!/usr/bin/env bats

load '../helpers.bash'

setup() {
  _mosaic_setup_server
  _mosaic_t set-option -wq -t t:1 "@mosaic-layout" "monocle"
}

teardown() {
  _mosaic_teardown_server
}

window_zoomed() {
  _mosaic_t display-message -p -t "${1:-t:1}" '#{window_zoomed_flag}'
}

active_pane_id() {
  _mosaic_t display-message -p -t "${1:-t:1}" '#{pane_id}'
}

@test "monocle: window layout keeps the focused pane zoomed" {
  for _ in 1 2; do _mosaic_split; done
  _mosaic_t select-pane -t t:1.2
  pid=$(active_pane_id)

  _mosaic_wait_window_zoomed 1 t:1

  [ "$(window_zoomed)" = "1" ]
  [ "$(active_pane_id)" = "$pid" ]
}

@test "monocle: split keeps the new pane zoomed" {
  _mosaic_split

  [ "$(_mosaic_pane_count)" = "2" ]
  [ "$(window_zoomed)" = "1" ]
  [ "$(_mosaic_pane_index)" = "2" ]
}

@test "monocle: selecting the next pane re-zooms the new active pane" {
  for _ in 1 2; do _mosaic_split; done

  before=$(active_pane_id)

  _mosaic_t select-pane -t :.+
  _mosaic_wait_window_zoomed 1 t:1

  after=$(active_pane_id)
  [ "$after" != "$before" ]
  [ "$(window_zoomed)" = "1" ]
}

@test "monocle: _sync-state stays silent when unsupported" {
  _mosaic_split

  run _mosaic_exec_direct _sync-state t:1

  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "monocle: promote surfaces the missing operation message in direct cli use" {
  run _mosaic_exec_direct promote
  [ "$status" -eq 0 ]
  [[ "$output" == *"mosaic: monocle does not implement promote"* ]]
}

@test "monocle: resize-master surfaces the missing operation message in direct cli use" {
  run _mosaic_exec_direct resize-master +5
  [ "$status" -eq 0 ]
  [[ "$output" == *"mosaic: monocle does not implement resize-master"* ]]
}
