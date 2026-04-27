#!/usr/bin/env bats

load '../helpers.bash'

setup() {
  _mosaic_setup_server
}

teardown() {
  _mosaic_teardown_server
}

assert_new_pane_appends_to_end() {
  local layout="${1:?layout required}" splits="${2:?split count required}" pane before before_count
  _mosaic_use_layout "$layout"
  _mosaic_wait_option_set @mosaic-_fingerprint t:1
  for ((i = 0; i < splits; i++)); do
    _mosaic_split
  done
  _mosaic_t select-pane -t t:1.1
  before=$(_mosaic_pane_ids t:1)
  before_count=$(_mosaic_pane_count t:1)

  run _mosaic_exec_direct new-pane
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  _mosaic_wait_pane_count_gt "$before_count" t:1
  pane=$(_mosaic_new_pane_id_from "$before" t:1)

  _mosaic_wait_pane_present "$pane" t:1
  [ "$(last_pane_id)" = "$pane" ]
}

last_pane_id() {
  _mosaic_t list-panes -t t:1 -F '#{pane_id}' | tail -n1
}

@test "master-stack: new-pane appends to the stack end" {
  assert_new_pane_appends_to_end master-stack 3
}

@test "centered-master: new-pane appends to the pane order end" {
  assert_new_pane_appends_to_end centered-master 4
}

@test "three-column: new-pane appends to the pane order end" {
  assert_new_pane_appends_to_end three-column 4
}

@test "spiral: new-pane appends to the pane order end" {
  assert_new_pane_appends_to_end spiral 3
}

@test "dwindle: new-pane appends to the pane order end" {
  assert_new_pane_appends_to_end dwindle 3
}

@test "grid: new-pane appends to the pane order end" {
  assert_new_pane_appends_to_end grid 3
}

@test "even-vertical: new-pane appends to the pane order end" {
  assert_new_pane_appends_to_end even-vertical 3
}

@test "even-horizontal: new-pane appends to the pane order end" {
  assert_new_pane_appends_to_end even-horizontal 3
}

@test "monocle: new-pane appends to the pane order end" {
  assert_new_pane_appends_to_end monocle 3
}
