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

assert_all_panes_owned() {
  local target="${1:-t:1}" gen pane
  gen=$(_mosaic_window_generation "$target")
  [ -n "$gen" ]
  while IFS= read -r pane; do
    [ "$(_mosaic_pane_owner_generation "$pane")" = "$gen" ]
  done < <(_mosaic_t list-panes -t "$target" -F '#{pane_id}')
}

suspend_window_with_foreign_pane() {
  _mosaic_t set-option -wq -t t:1 "@mosaic-auto-apply" "managed"
  _mosaic_t split-window -t t:1 "sleep 3600"
  _mosaic_wait_pane_count 2 t:1
  _mosaic_wait_window_state suspended t:1
}

@test "adopt: suspended window adopts all current panes and relayouts once" {
  local old_gen
  suspend_window_with_foreign_pane
  old_gen=$(_mosaic_window_generation t:1)
  reset_log

  run _mosaic_exec_direct adopt
  [ "$status" -eq 0 ]

  _mosaic_wait_window_state managed t:1
  [ "$(_mosaic_window_generation t:1)" != "$old_gen" ]
  assert_all_panes_owned t:1
  [ "$(relayout_count)" -eq 1 ]
}

@test "adopt: already managed window rotates ownership without breaking it" {
  local old_gen
  _mosaic_split
  old_gen=$(_mosaic_window_generation t:1)

  run _mosaic_exec_direct adopt
  [ "$status" -eq 0 ]

  _mosaic_wait_window_state managed t:1
  [ "$(_mosaic_window_generation t:1)" != "$old_gen" ]
  assert_all_panes_owned t:1
}

@test "promote: suspended window refuses cleanly" {
  suspend_window_with_foreign_pane

  run _mosaic_exec_direct promote
  [ "$status" -eq 1 ]
  [[ "$output" == *"mosaic: window is suspended; adopt panes first"* ]]
}

@test "resize-master: suspended window refuses cleanly" {
  suspend_window_with_foreign_pane

  run _mosaic_exec_direct resize-master +5
  [ "$status" -eq 1 ]
  [[ "$output" == *"mosaic: window is suspended; adopt panes first"* ]]
}

@test "explicit local layout change adopts panes and clears suspension" {
  local old_gen
  suspend_window_with_foreign_pane
  old_gen=$(_mosaic_window_generation t:1)

  _mosaic_t set-option -wq -t t:1 "@mosaic-layout" "grid"
  _mosaic_wait_layout_outer '[' t:1
  _mosaic_wait_window_state managed t:1

  [ "$(_mosaic_window_generation t:1)" != "$old_gen" ]
  assert_all_panes_owned t:1
}
