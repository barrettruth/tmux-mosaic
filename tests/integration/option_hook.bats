#!/usr/bin/env bats

load '../helpers.bash'

setup() {
  mosaic_setup_server
  mosaic_use_algorithm master-stack
  for _ in 1 2 3; do mosaic_split; done
}

teardown() {
  mosaic_teardown_server
}

reset_log() { mosaic_reset_log; }
relayout_count() { mosaic_log_relayout_count; }
sync_count() { mosaic_log_sync_count; }
layout_outer() { mosaic_layout_outer t:1; }

assert_relayout_count() {
  local expected="$1" wait_ms="${2:-5000}"
  if [[ "$expected" -gt 0 ]]; then
    mosaic_wait_relayout_count_ge "$expected" "$wait_ms"
  fi
  mosaic_quiesce
  local actual
  actual=$(relayout_count)
  if [[ "$actual" -ne "$expected" ]]; then
    {
      printf 'expected %s relayouts, got %s\nlog:\n' "$expected" "$actual"
      cat "$(mosaic_log_file)"
    } >&2
    return 1
  fi
}

@test "after-set-option hook: registered with the layout-option filter" {
  run mosaic_t show-hooks -g after-set-option
  [ "$status" -eq 0 ]
  [[ "$output" == *"if-shell"* ]]
  [[ "$output" == *"@mosaic-algorithm"* ]]
  [[ "$output" == *"@mosaic-orientation"* ]]
  [[ "$output" == *"@mosaic-nmaster"* ]]
  [[ "$output" == *"@mosaic-mfact"* ]]
  [[ "$output" == *"_on-set-option"* ]]
}

@test "after-set-option: set @mosaic-algorithm grid switches layout in one event" {
  [ "$(layout_outer)" = "{" ]

  reset_log
  mosaic_t set-option -wq -t t:1 "@mosaic-algorithm" "grid"
  mosaic_wait_layout_outer '[' t:1

  [ "$(layout_outer)" = "[" ]
  assert_relayout_count 1
}

@test "after-set-option: set @mosaic-orientation right relayouts to right master" {
  reset_log
  mosaic_t set-option -wq -t t:1 "@mosaic-orientation" "right"
  mosaic_wait_pane_left_gt 1 0

  pane1_left=$(mosaic_t list-panes -t t:1 -F '#{pane_index} #{pane_left}' | awk '$1 == 1 { print $2 }')
  [ "$pane1_left" -gt 0 ]
  assert_relayout_count 1
}

@test "after-set-option: set @mosaic-nmaster 2 relayouts" {
  reset_log
  mosaic_t set-option -wq -t t:1 "@mosaic-nmaster" "2"
  mosaic_wait_log_match 'nmaster=2'

  assert_relayout_count 1
  grep -q 'nmaster=2' "$(mosaic_log_file)"
}

@test "after-set-option: set @mosaic-mfact 70 relayouts" {
  reset_log
  mosaic_t set-option -wq -t t:1 "@mosaic-mfact" "70"
  mosaic_wait_option main-pane-width "70%" t:1

  [ "$(mosaic_t show-option -wqv -t t:1 main-pane-width)" = "70%" ]
  assert_relayout_count 1
}

@test "after-set-option: set @mosaic-debug does NOT relayout" {
  reset_log
  mosaic_t set-option -gq "@mosaic-debug" "0"
  mosaic_t set-option -gq "@mosaic-debug" "1"

  assert_relayout_count 0
}

@test "after-set-option: set @mosaic-step does NOT relayout" {
  reset_log
  mosaic_t set-option -gq "@mosaic-step" "10"

  assert_relayout_count 0
}

@test "after-set-option: set unrelated tmux option does NOT relayout" {
  reset_log
  mosaic_t set-option -gq "mouse" "on"
  mosaic_t set-option -gq "status-left" "test"

  assert_relayout_count 0
}

@test "after-set-option: invalid algorithm name surfaces an error" {
  run mosaic_exec_direct relayout
  [ "$status" -eq 0 ]

  mosaic_t set-option -wq -t t:1 "@mosaic-algorithm" "nonexistent-algo"
  mosaic_quiesce

  mosaic_t set-option -wq -t t:1 "@mosaic-algorithm" "grid"
  mosaic_wait_layout_outer '[' t:1
  [ "$(layout_outer)" = "[" ]
}

@test "no double relayout: resize-master via op fires exactly once" {
  reset_log
  fp=$(mosaic_fingerprint t:1)

  mosaic_op resize-master +10
  mosaic_wait_fingerprint_changed_from "$fp" t:1

  [ "$(mosaic_t show-option -wqv -t t:1 @mosaic-mfact)" = "60" ]
  assert_relayout_count 1
}

@test "no double relayout: toggle off->on fires exactly once" {
  mosaic_disable_algorithm
  mosaic_wait_option_empty @mosaic-_fingerprint t:1
  reset_log

  mosaic_use_global_algorithm master-stack
  mosaic_op toggle

  assert_relayout_count 1
}

@test "no double relayout: drag-resize sync triggers one relayout" {
  reset_log
  mosaic_t resize-pane -t t:1.1 -x 160
  mosaic_wait_log_match 'sync-state:'

  mosaic_quiesce
  [ "$(sync_count)" -eq 1 ]
  [ "$(relayout_count)" -eq 1 ]
}

@test "after-set-option: set @mosaic-algorithm to off preserves layout" {
  before=$(mosaic_layout t:1)

  reset_log
  mosaic_t set-option -wq -t t:1 "@mosaic-algorithm" "off"

  assert_relayout_count 0
  after=$(mosaic_layout t:1)
  [ "$before" = "$after" ]
}

@test "after-set-option: unset window option falls back to global" {
  mosaic_use_global_algorithm grid
  mosaic_use_algorithm master-stack t:1
  mosaic_wait_layout_outer '{' t:1
  [ "$(layout_outer)" = "{" ]

  reset_log
  mosaic_t set-option -wqu -t t:1 "@mosaic-algorithm"
  mosaic_wait_layout_outer '[' t:1

  [ "$(layout_outer)" = "[" ]
  assert_relayout_count 1
}

@test "fingerprint cache: setting @mosaic-mfact to its current value triggers zero relayouts" {
  mosaic_t set-option -wq -t t:1 "@mosaic-mfact" "70"
  mosaic_wait_option main-pane-width "70%" t:1
  reset_log

  mosaic_t set-option -wq -t t:1 "@mosaic-mfact" "70"
  assert_relayout_count 0
}

@test "fingerprint cache: setting @mosaic-orientation to its current value triggers zero relayouts" {
  mosaic_t set-option -wq -t t:1 "@mosaic-orientation" "right"
  mosaic_wait_pane_left_gt 1 0
  reset_log

  mosaic_t set-option -wq -t t:1 "@mosaic-orientation" "right"
  assert_relayout_count 0
}

@test "fingerprint cache: setting @mosaic-algorithm to its current value triggers zero relayouts" {
  reset_log

  mosaic_t set-option -wq -t t:1 "@mosaic-algorithm" "master-stack"
  assert_relayout_count 0
}

@test "fingerprint cache: two distinct orientation changes fire two relayouts" {
  reset_log
  mosaic_t set-option -wq -t t:1 "@mosaic-orientation" "right"
  mosaic_wait_relayout_count_ge 1
  mosaic_t set-option -wq -t t:1 "@mosaic-orientation" "left"

  assert_relayout_count 2
}

@test "fingerprint cache: cleared on transition to off so re-enable always relayouts" {
  reset_log

  mosaic_disable_algorithm
  mosaic_wait_option_empty @mosaic-_fingerprint t:1
  [ -z "$(mosaic_t show-option -wqv -t t:1 @mosaic-_fingerprint)" ]

  mosaic_use_algorithm master-stack
  mosaic_wait_option_set @mosaic-_fingerprint t:1
  [ -n "$(mosaic_t show-option -wqv -t t:1 @mosaic-_fingerprint)" ]
  [ "$(relayout_count)" -ge 1 ]
}

@test "sync short-circuit: drag-resize whose pct is unchanged does not write @mosaic-mfact" {
  mosaic_t set-option -wq -t t:1 "@mosaic-mfact" "50"
  mosaic_wait_option main-pane-width "50%" t:1
  reset_log

  mosaic_t resize-pane -t t:1.1 -x 100
  mosaic_quiesce
  mosaic_quiesce

  [ "$(mosaic_t show-option -wqv -t t:1 @mosaic-mfact)" = "50" ]
  [ "$(relayout_count)" -eq 0 ]
}
