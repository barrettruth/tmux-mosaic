#!/usr/bin/env bats

load '../helpers.bash'

setup() {
  _mosaic_setup_server
  _mosaic_use_layout master-stack
  _mosaic_wait_window_generation_set t:1
  _mosaic_wait_window_state managed t:1
}

teardown() {
  _mosaic_teardown_server
}

reset_log() { _mosaic_reset_log; }
relayout_count() { _mosaic_log_relayout_count; }

@test "new-pane: creates an owned pane without suspending a managed window" {
  local pane gen before before_count
  _mosaic_t set-option -wq -t t:1 "@mosaic-auto-apply" "managed"
  gen=$(_mosaic_window_generation t:1)
  reset_log
  before=$(_mosaic_pane_ids t:1)
  before_count=$(_mosaic_pane_count t:1)

  run _mosaic_exec_direct new-pane
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  _mosaic_wait_pane_count_gt "$before_count" t:1
  pane=$(_mosaic_new_pane_id_from "$before" t:1)
  [[ "$pane" == %* ]]

  _mosaic_wait_pane_present "$pane" t:1
  _mosaic_wait_pane_owner_generation "$pane" "$gen"
  _mosaic_wait_window_state managed t:1

  [ "$(_mosaic_pane_count t:1)" -eq 2 ]
  [ "$(relayout_count)" -eq 1 ]
}

@test "new-pane: preserves the current pane path" {
  local before pane after before_panes before_count
  before=$(_mosaic_pane_current_path t:1.1)
  before_panes=$(_mosaic_pane_ids t:1)
  before_count=$(_mosaic_pane_count t:1)

  run _mosaic_exec_direct new-pane
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  _mosaic_wait_pane_count_gt "$before_count" t:1
  pane=$(_mosaic_new_pane_id_from "$before_panes" t:1)

  _mosaic_wait_pane_present "$pane" t:1
  after=$(_mosaic_pane_current_path "$pane")
  [ "$after" = "$before" ]
}

@test "new-pane: explicit op still works when auto-apply is none" {
  local pane gen before before_count
  _mosaic_t set-option -wq -t t:1 "@mosaic-auto-apply" "none"
  gen=$(_mosaic_window_generation t:1)
  reset_log
  before=$(_mosaic_pane_ids t:1)
  before_count=$(_mosaic_pane_count t:1)

  run _mosaic_exec_direct new-pane
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  _mosaic_wait_pane_count_gt "$before_count" t:1
  pane=$(_mosaic_new_pane_id_from "$before" t:1)

  _mosaic_wait_pane_present "$pane" t:1
  _mosaic_wait_pane_owner_generation "$pane" "$gen"
  _mosaic_wait_window_state managed t:1
  [ "$(_mosaic_pane_count t:1)" -eq 2 ]
  [ "$(relayout_count)" -eq 1 ]
}
