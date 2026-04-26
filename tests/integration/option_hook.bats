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

reset_log() { : >/tmp/tmux-mosaic-test.log; }
relayout_count() { grep -c '^[^ ]* \[[0-9]*\] relayout:' /tmp/tmux-mosaic-test.log || true; }
sync_count() { grep -c '^[^ ]* \[[0-9]*\] sync-state:' /tmp/tmux-mosaic-test.log || true; }
layout_outer() {
  mosaic_layout t:1 | awk 'match($0, /[\[{]/) { print substr($0, RSTART, 1) }'
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
  sleep 0.2

  [ "$(layout_outer)" = "[" ]
  [ "$(relayout_count)" = "1" ]
}

@test "after-set-option: set @mosaic-orientation right relayouts to right master" {
  reset_log
  mosaic_t set-option -wq -t t:1 "@mosaic-orientation" "right"
  sleep 0.2

  pane1_left=$(mosaic_t list-panes -t t:1 -F '#{pane_index} #{pane_left}' | awk '$1 == 1 { print $2 }')
  [ "$pane1_left" -gt 0 ]
  [ "$(relayout_count)" = "1" ]
}

@test "after-set-option: set @mosaic-nmaster 2 relayouts" {
  reset_log
  mosaic_t set-option -wq -t t:1 "@mosaic-nmaster" "2"
  sleep 0.2

  [ "$(relayout_count)" = "1" ]
  grep -q 'nmaster=2' /tmp/tmux-mosaic-test.log
}

@test "after-set-option: set @mosaic-mfact 70 relayouts" {
  reset_log
  mosaic_t set-option -wq -t t:1 "@mosaic-mfact" "70"
  sleep 0.2

  [ "$(mosaic_t show-option -wqv -t t:1 main-pane-width)" = "70%" ]
  [ "$(relayout_count)" = "1" ]
}

@test "after-set-option: set @mosaic-debug does NOT relayout" {
  reset_log
  mosaic_t set-option -gq "@mosaic-debug" "0"
  mosaic_t set-option -gq "@mosaic-debug" "1"
  sleep 0.2

  [ "$(relayout_count)" = "0" ]
}

@test "after-set-option: set @mosaic-step does NOT relayout" {
  reset_log
  mosaic_t set-option -gq "@mosaic-step" "10"
  sleep 0.2

  [ "$(relayout_count)" = "0" ]
}

@test "after-set-option: set unrelated tmux option does NOT relayout" {
  reset_log
  mosaic_t set-option -gq "mouse" "on"
  mosaic_t set-option -gq "status-left" "test"
  sleep 0.2

  [ "$(relayout_count)" = "0" ]
}

@test "after-set-option: invalid algorithm name surfaces an error" {
  run mosaic_exec_direct relayout
  [ "$status" -eq 0 ]

  mosaic_t set-option -wq -t t:1 "@mosaic-algorithm" "nonexistent-algo"
  sleep 0.2

  mosaic_t set-option -wq -t t:1 "@mosaic-algorithm" "grid"
  sleep 0.2
  [ "$(layout_outer)" = "[" ]
}

@test "no double relayout: resize-master via op fires exactly once" {
  reset_log
  mosaic_op resize-master +10
  sleep 0.2

  [ "$(mosaic_t show-option -wqv -t t:1 @mosaic-mfact)" = "60" ]
  [ "$(relayout_count)" = "1" ]
}

@test "no double relayout: toggle off->on fires exactly once" {
  mosaic_disable_algorithm
  sleep 0.2
  reset_log

  mosaic_use_global_algorithm master-stack
  mosaic_op toggle
  sleep 0.2

  [ "$(relayout_count)" = "1" ]
}

@test "no double relayout: drag-resize sync triggers one relayout" {
  reset_log
  mosaic_t resize-pane -t t:1.1 -x 160
  sleep 0.3

  [ "$(sync_count)" = "1" ]
  [ "$(relayout_count)" = "1" ]
}

@test "after-set-option: set @mosaic-algorithm to off preserves layout" {
  before=$(mosaic_layout t:1)

  reset_log
  mosaic_t set-option -wq -t t:1 "@mosaic-algorithm" "off"
  sleep 0.2

  after=$(mosaic_layout t:1)
  [ "$before" = "$after" ]
  [ "$(relayout_count)" = "0" ]
}

@test "after-set-option: unset window option falls back to global" {
  mosaic_use_global_algorithm grid
  mosaic_use_algorithm master-stack t:1
  sleep 0.2
  [ "$(layout_outer)" = "{" ]

  reset_log
  mosaic_t set-option -wqu -t t:1 "@mosaic-algorithm"
  sleep 0.2

  [ "$(layout_outer)" = "[" ]
  [ "$(relayout_count)" = "1" ]
}
