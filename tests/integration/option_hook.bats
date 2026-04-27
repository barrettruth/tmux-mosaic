#!/usr/bin/env bats

load '../helpers.bash'

setup() {
  _mosaic_setup_server
  _mosaic_use_layout master-stack
  for _ in 1 2 3; do _mosaic_split; done
}

teardown() {
  _mosaic_teardown_server
}

reset_log() { _mosaic_reset_log; }
relayout_count() { _mosaic_log_relayout_count; }
sync_count() { _mosaic_log_sync_count; }
_layout_outer() { _mosaic_layout_outer t:1; }
show_hook() { _mosaic_t show-hooks -g "${1:?hook required}" 2>/dev/null; }
mosaic_hook_count() { show_hook "${1:?hook required}" | grep -F -c "$REPO_ROOT/scripts/ops.sh" || true; }

assert_relayout_count() {
  local expected="$1" wait_ms="${2:-5000}"
  if [[ "$expected" -gt 0 ]]; then
    _mosaic_wait_relayout_count_ge "$expected" "$wait_ms"
  fi
  _mosaic_quiesce
  local actual
  actual=$(relayout_count)
  if [[ "$actual" -ne "$expected" ]]; then
    {
      printf 'expected %s relayouts, got %s\nlog:\n' "$expected" "$actual"
      cat "$(_mosaic_log_file)"
    } >&2
    return 1
  fi
}

@test "re-sourcing mosaic.tmux does not duplicate mosaic hooks" {
  local hook
  for hook in after-split-window after-kill-pane pane-exited pane-died after-select-pane after-resize-pane after-set-option; do
    [ "$(mosaic_hook_count "$hook")" -eq 1 ]
  done

  _mosaic_t run-shell "$REPO_ROOT/mosaic.tmux"

  for hook in after-split-window after-kill-pane pane-exited pane-died after-select-pane after-resize-pane after-set-option; do
    [ "$(mosaic_hook_count "$hook")" -eq 1 ]
  done
}

@test "re-sourcing mosaic.tmux replaces stale mosaic hook paths" {
  local old
  old="/tmp/old/tmux-mosaic/scripts/ops.sh"
  _mosaic_t set-hook -ga after-split-window \
    "run-shell -b '$old relayout #{window_id}'"
  _mosaic_t set-hook -ga after-resize-pane \
    "run-shell -b '$old _sync-state #{window_id}'"
  _mosaic_t set-hook -ga after-set-option \
    "if-shell -bF '1' \"run-shell -b '$old _on-set-option #{hook_argument_0} #{window_id}'\""

  _mosaic_t run-shell "$REPO_ROOT/mosaic.tmux"

  run show_hook after-split-window
  [ "$status" -eq 0 ]
  [[ "$output" != *"$old"* ]]
  [ "$(mosaic_hook_count after-split-window)" -eq 1 ]

  run show_hook after-resize-pane
  [ "$status" -eq 0 ]
  [[ "$output" != *"$old"* ]]
  [ "$(mosaic_hook_count after-resize-pane)" -eq 1 ]

  run show_hook after-set-option
  [ "$status" -eq 0 ]
  [[ "$output" != *"$old"* ]]
  [ "$(mosaic_hook_count after-set-option)" -eq 1 ]
}

@test "after-set-option hook: registered with the layout-option filter" {
  run _mosaic_t show-hooks -g after-set-option
  [ "$status" -eq 0 ]
  [[ "$output" == *"if-shell"* ]]
  [[ "$output" == *"@mosaic-layout"* ]]
  [[ "$output" == *"@mosaic-orientation"* ]]
  [[ "$output" == *"@mosaic-nmaster"* ]]
  [[ "$output" == *"@mosaic-mfact"* ]]
  [[ "$output" == *"_on-set-option"* ]]
}

@test "after-set-option: set @mosaic-layout grid switches layout in one event" {
  [ "$(_layout_outer)" = "{" ]

  reset_log
  _mosaic_t set-option -wq -t t:1 "@mosaic-layout" "grid"
  _mosaic_wait_layout_outer '[' t:1

  [ "$(_layout_outer)" = "[" ]
  assert_relayout_count 1
}

@test "after-set-option: set @mosaic-orientation right relayouts to right master" {
  reset_log
  _mosaic_t set-option -wq -t t:1 "@mosaic-orientation" "right"
  _mosaic_wait_pane_left_gt 1 0

  pane1_left=$(_mosaic_t list-panes -t t:1 -F '#{pane_index} #{pane_left}' | awk '$1 == 1 { print $2 }')
  [ "$pane1_left" -gt 0 ]
  assert_relayout_count 1
}

@test "after-set-option: set @mosaic-nmaster 2 relayouts" {
  reset_log
  _mosaic_t set-option -wq -t t:1 "@mosaic-nmaster" "2"
  _mosaic_wait_log_match 'nmaster=2'

  assert_relayout_count 1
  grep -q 'nmaster=2' "$(_mosaic_log_file)"
}

@test "after-set-option: set @mosaic-mfact 70 relayouts" {
  reset_log
  _mosaic_t set-option -wq -t t:1 "@mosaic-mfact" "70"
  _mosaic_wait_option main-pane-width "70%" t:1

  [ "$(_mosaic_t show-option -wqv -t t:1 main-pane-width)" = "70%" ]
  assert_relayout_count 1
}

@test "after-set-option: set @mosaic-debug does NOT relayout" {
  reset_log
  _mosaic_t set-option -gq "@mosaic-debug" "0"
  _mosaic_t set-option -gq "@mosaic-debug" "1"

  assert_relayout_count 0
}

@test "after-set-option: set @mosaic-step does NOT relayout" {
  reset_log
  _mosaic_t set-option -gq "@mosaic-step" "10"

  assert_relayout_count 0
}

@test "after-set-option: set unrelated tmux option does NOT relayout" {
  reset_log
  _mosaic_t set-option -gq "mouse" "on"
  _mosaic_t set-option -gq "status-left" "test"

  assert_relayout_count 0
}

@test "after-set-option: invalid layout name surfaces an error" {
  run _mosaic_exec_direct relayout
  [ "$status" -eq 0 ]

  _mosaic_t set-option -wq -t t:1 "@mosaic-layout" "nonexistent-layout"
  _mosaic_quiesce

  _mosaic_t set-option -wq -t t:1 "@mosaic-layout" "grid"
  _mosaic_wait_layout_outer '[' t:1
  [ "$(_layout_outer)" = "[" ]
}

@test "no double relayout: resize-master via op fires exactly once" {
  reset_log
  fp=$(_mosaic_fingerprint t:1)

  _mosaic_op resize-master +10
  _mosaic_wait_fingerprint_changed_from "$fp" t:1

  [ "$(_mosaic_t show-option -wqv -t t:1 @mosaic-mfact)" = "60" ]
  assert_relayout_count 1
}

@test "no double relayout: toggle off->on fires exactly once" {
  _mosaic_disable_layout
  _mosaic_wait_option_empty @mosaic-_fingerprint t:1
  reset_log

  _mosaic_use_global_layout master-stack
  _mosaic_op toggle

  assert_relayout_count 1
}

@test "no double relayout: drag-resize sync triggers one relayout" {
  fp=$(_mosaic_fingerprint t:1)
  reset_log
  _mosaic_t resize-pane -t t:1.1 -x 160
  _mosaic_wait_log_match 'sync-state:'
  _mosaic_wait_fingerprint_changed_from "$fp" t:1

  _mosaic_quiesce
  [ "$(sync_count)" -eq 1 ]
  [ "$(relayout_count)" -eq 1 ]
}

@test "after-set-option: set @mosaic-layout to off preserves layout" {
  before=$(_mosaic_layout t:1)

  reset_log
  _mosaic_t set-option -wq -t t:1 "@mosaic-layout" "off"

  assert_relayout_count 0
  after=$(_mosaic_layout t:1)
  [ "$before" = "$after" ]
}

@test "after-set-option: unset window option falls back to global" {
  _mosaic_use_global_layout grid
  _mosaic_use_layout master-stack t:1
  _mosaic_wait_layout_outer '{' t:1
  [ "$(_layout_outer)" = "{" ]

  reset_log
  _mosaic_t set-option -wqu -t t:1 "@mosaic-layout"
  _mosaic_wait_layout_outer '[' t:1

  [ "$(_layout_outer)" = "[" ]
  assert_relayout_count 1
}

@test "fingerprint cache: setting @mosaic-mfact to its current value triggers zero relayouts" {
  _mosaic_t set-option -wq -t t:1 "@mosaic-mfact" "70"
  _mosaic_wait_option main-pane-width "70%" t:1
  reset_log

  _mosaic_t set-option -wq -t t:1 "@mosaic-mfact" "70"
  assert_relayout_count 0
}

@test "fingerprint cache: setting @mosaic-orientation to its current value triggers zero relayouts" {
  _mosaic_t set-option -wq -t t:1 "@mosaic-orientation" "right"
  _mosaic_wait_pane_left_gt 1 0
  reset_log

  _mosaic_t set-option -wq -t t:1 "@mosaic-orientation" "right"
  assert_relayout_count 0
}

@test "fingerprint cache: setting @mosaic-layout to its current value triggers zero relayouts" {
  reset_log

  _mosaic_t set-option -wq -t t:1 "@mosaic-layout" "master-stack"
  assert_relayout_count 0
}

@test "fingerprint cache: two distinct orientation changes fire two relayouts" {
  reset_log
  _mosaic_t set-option -wq -t t:1 "@mosaic-orientation" "right"
  _mosaic_wait_relayout_count_ge 1
  _mosaic_quiesce
  _mosaic_t set-option -wq -t t:1 "@mosaic-orientation" "left"

  assert_relayout_count 2
}

@test "fingerprint cache: cleared on transition to off so re-enable always relayouts" {
  reset_log

  _mosaic_disable_layout
  _mosaic_wait_option_empty @mosaic-_fingerprint t:1
  [ -z "$(_mosaic_t show-option -wqv -t t:1 @mosaic-_fingerprint)" ]

  _mosaic_use_layout master-stack
  _mosaic_wait_option_set @mosaic-_fingerprint t:1
  [ -n "$(_mosaic_t show-option -wqv -t t:1 @mosaic-_fingerprint)" ]
  [ "$(relayout_count)" -ge 1 ]
}

@test "sync short-circuit: drag-resize whose pct is unchanged does not write @mosaic-mfact" {
  _mosaic_t set-option -wq -t t:1 "@mosaic-mfact" "50"
  _mosaic_wait_option main-pane-width "50%" t:1
  reset_log

  _mosaic_t resize-pane -t t:1.1 -x 100
  _mosaic_quiesce
  _mosaic_quiesce

  [ "$(_mosaic_t show-option -wqv -t t:1 @mosaic-mfact)" = "50" ]
  [ "$(relayout_count)" -eq 0 ]
}
