#!/usr/bin/env bats

load '../helpers.bash'

setup() {
  _mosaic_setup_server
  _mosaic_use_layout master-stack
  _mosaic_wait_window_generation_set t:1
  _mosaic_wait_window_state managed t:1
  _mosaic_wait_option_set @mosaic-_fingerprint t:1
}

teardown() {
  _mosaic_teardown_server
}

reset_log() { _mosaic_reset_log; }
relayout_count() { _mosaic_log_relayout_count; }
sync_count() { _mosaic_log_sync_count; }

raw_split() {
  local target="${1:-t:1}" before
  before=$(_mosaic_pane_count "$target")
  _mosaic_t split-window -t "$target" "sleep 3600"
  _mosaic_wait_pane_count_gt "$before" "$target"
  _mosaic_quiesce
}

last_pane_id() {
  _mosaic_t list-panes -t "${1:-t:1}" -F '#{pane_id}' | tail -n1
}

@test "auto-apply full: raw split adopts the new pane" {
  local gen pane
  _mosaic_t set-option -wq -t t:1 "@mosaic-auto-apply" "full"
  gen=$(_mosaic_window_generation t:1)
  reset_log

  raw_split t:1
  pane=$(last_pane_id t:1)

  _mosaic_wait_pane_owner_generation "$pane" "$gen"
  [ "$(_mosaic_window_state t:1)" = "managed" ]
  [ "$(relayout_count)" -ge 1 ]
}

@test "auto-apply managed: raw split suspends and leaves the new pane foreign" {
  local pane
  _mosaic_t set-option -wq -t t:1 "@mosaic-auto-apply" "managed"
  reset_log

  raw_split t:1
  pane=$(last_pane_id t:1)

  _mosaic_wait_window_state suspended t:1
  _mosaic_wait_pane_owner_generation "$pane" ""
  [ "$(relayout_count)" -eq 0 ]
}

@test "auto-apply managed: suspended windows do not sync mfact from foreign panes" {
  _mosaic_t set-option -wq -t t:1 "@mosaic-auto-apply" "managed"
  _mosaic_t set-option -wq -t t:1 "@mosaic-mfact" "50"
  raw_split t:1
  _mosaic_wait_window_state suspended t:1
  reset_log

  _mosaic_t resize-pane -t t:1.1 -x 160
  _mosaic_quiesce

  [ "$(_mosaic_t show-option -wqv -t t:1 @mosaic-mfact)" = "50" ]
  [ "$(sync_count)" -eq 0 ]
  [ "$(relayout_count)" -eq 0 ]
}

@test "auto-apply managed: killing the last foreign pane clears suspension" {
  local pane
  _mosaic_t set-option -wq -t t:1 "@mosaic-auto-apply" "managed"
  raw_split t:1
  pane=$(last_pane_id t:1)
  _mosaic_wait_window_state suspended t:1

  _mosaic_t kill-pane -t "$pane"
  _mosaic_wait_pane_count 1 t:1
  _mosaic_wait_window_state managed t:1

  [ "$(_mosaic_window_state t:1)" = "managed" ]
}

@test "auto-apply none: raw split does not relayout or adopt the new pane" {
  local pane
  _mosaic_t set-option -wq -t t:1 "@mosaic-auto-apply" "none"
  reset_log

  raw_split t:1
  pane=$(last_pane_id t:1)

  _mosaic_wait_pane_owner_generation "$pane" ""
  [ "$(relayout_count)" -eq 0 ]
}
