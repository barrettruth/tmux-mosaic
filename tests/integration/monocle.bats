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

@test "monocle: window algorithm keeps the focused pane zoomed" {
  for _ in 1 2; do mosaic_split; done
  mosaic_t select-pane -t t:1.2
  pid=$(active_pane_id)

  mosaic_wait_window_zoomed 1 t:1 || true

  [ "$(window_zoomed)" = "1" ]
  [ "$(active_pane_id)" = "$pid" ]
}

@test "monocle: split keeps the new pane zoomed" {
  mosaic_split

  [ "$(mosaic_pane_count)" = "2" ]
  [ "$(window_zoomed)" = "1" ]
  [ "$(mosaic_pane_index)" = "2" ]
}

@test "monocle: selecting the next pane re-zooms the new active pane" {
  for _ in 1 2; do mosaic_split; done

  before=$(active_pane_id)

  mosaic_t select-pane -t :.+
  mosaic_wait_window_zoomed 1 t:1 || true

  after=$(active_pane_id)
  [ "$after" != "$before" ]
  [ "$(window_zoomed)" = "1" ]
}

@test "monocle: _sync-state stays silent when unsupported" {
  mosaic_split

  run mosaic_exec_direct _sync-state t:1

  [ "$status" -eq 0 ]
  [ -z "$output" ]
}
