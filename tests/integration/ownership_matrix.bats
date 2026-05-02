#!/usr/bin/env bats

load '../helpers.bash'

setup() {
  _mosaic_setup_server
}

teardown() {
  _mosaic_teardown_server
}

assert_all_panes_owned() {
  local target="${1:-t:1}" gen pane
  gen=$(_mosaic_window_generation "$target")
  [ -n "$gen" ]
  while IFS= read -r pane; do
    [ "$(_mosaic_pane_owner_generation "$pane")" = "$gen" ]
  done < <(_mosaic_t list-panes -t "$target" -F '#{pane_id}')
}

show_hook() {
  _mosaic_t show-hooks -g "${1:?hook required}" 2>/dev/null
}

mosaic_hook_count() {
  show_hook "${1:?hook required}" | grep -F -c "$REPO_ROOT/scripts/ops.sh" || true
}

@test "ownership bootstrap: windows without a resolved layout stay unowned" {
  _mosaic_t split-window -t t:1 "sleep 3600"
  _mosaic_wait_pane_count 2 t:1
  _mosaic_quiesce

  [ -z "$(_mosaic_window_generation t:1)" ]
  [ -z "$(_mosaic_window_state t:1)" ]
}

@test "ownership move: swap-pane across windows keeps both panes foreign in their new homes" {
  local pane1 pane2 gen1 gen2
  _mosaic_use_layout master-stack t:1
  _mosaic_wait_window_generation_set t:1
  _mosaic_wait_window_state managed t:1

  _mosaic_t new-window -d -t t: -n other "sleep 3600"
  _mosaic_use_layout master-stack t:2
  _mosaic_wait_window_generation_set t:2
  _mosaic_wait_window_state managed t:2

  pane1=$(_mosaic_pane_id_at t:1.1)
  pane2=$(_mosaic_pane_id_at t:2.1)
  gen1=$(_mosaic_window_generation t:1)
  gen2=$(_mosaic_window_generation t:2)

  _mosaic_t swap-pane -s "$pane1" -t "$pane2"
  _mosaic_wait_pane_present "$pane1" t:2
  _mosaic_wait_pane_present "$pane2" t:1

  [ "$(_mosaic_pane_owner_generation "$pane1")" = "$gen1" ]
  [ "$(_mosaic_pane_owner_generation "$pane1")" != "$gen2" ]
  [ "$(_mosaic_pane_owner_generation "$pane2")" = "$gen2" ]
  [ "$(_mosaic_pane_owner_generation "$pane2")" != "$gen1" ]
}

@test "auto-apply managed: raw split-window -h suspends the window" {
  local pane
  _mosaic_use_layout master-stack
  _mosaic_wait_window_generation_set t:1
  _mosaic_wait_window_state managed t:1
  _mosaic_wait_fingerprint_current t:1
  _mosaic_t set-option -wq -t t:1 "@mosaic-auto-apply" "managed"

  pane=$(_mosaic_t split-window -P -F '#{pane_id}' -h -t t:1 "sleep 3600")
  _mosaic_wait_pane_present "$pane" t:1
  _mosaic_wait_window_state_stable suspended t:1
  [ -z "$(_mosaic_pane_owner_generation "$pane")" ]
}

@test "auto-apply managed: raw split-window -v suspends the window" {
  local pane
  _mosaic_use_layout master-stack
  _mosaic_wait_window_generation_set t:1
  _mosaic_wait_window_state managed t:1
  _mosaic_wait_fingerprint_current t:1
  _mosaic_t set-option -wq -t t:1 "@mosaic-auto-apply" "managed"

  pane=$(_mosaic_t split-window -P -F '#{pane_id}' -v -t t:1 "sleep 3600")
  _mosaic_wait_pane_present "$pane" t:1
  _mosaic_wait_window_state_stable suspended t:1
  [ -z "$(_mosaic_pane_owner_generation "$pane")" ]
}

@test "auto-apply managed: dead foreign panes with remain-on-exit stay suspended until removed" {
  local pane
  _mosaic_use_layout master-stack
  _mosaic_wait_window_generation_set t:1
  _mosaic_wait_window_state managed t:1
  _mosaic_t set-option -wq -t t:1 "@mosaic-auto-apply" "managed"
  _mosaic_t set-option -wq -t t:1 remain-on-exit on

  pane=$(_mosaic_t split-window -P -F '#{pane_id}' -t t:1 'sh -c "exit 0"')
  _mosaic_wait_pane_present "$pane" t:1
  _mosaic_wait_pane_dead "$pane"
  _mosaic_wait_window_state_stable suspended t:1

  [ -z "$(_mosaic_pane_owner_generation "$pane")" ]

  _mosaic_t kill-pane -t "$pane"
  _mosaic_wait_pane_count 1 t:1
  _mosaic_wait_window_state_stable managed t:1
}

@test "re-sourcing mosaic.tmux preserves hook de-dup and ownership state" {
  local gen
  _mosaic_use_layout master-stack
  for _ in 1 2; do
    _mosaic_split
  done
  _mosaic_wait_window_generation_set t:1
  _mosaic_wait_window_state managed t:1
  gen=$(_mosaic_window_generation t:1)

  _mosaic_source_plugin

  [ "$(mosaic_hook_count after-split-window)" -eq 1 ]
  [ "$(mosaic_hook_count after-resize-pane)" -eq 1 ]
  [ "$(_mosaic_window_generation t:1)" = "$gen" ]
  [ "$(_mosaic_window_state t:1)" = "managed" ]
  assert_all_panes_owned t:1
}
