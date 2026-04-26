#!/usr/bin/env bats

load '../helpers.bash'

setup() {
  mosaic_setup_server
  mosaic_use_algorithm master-stack
}

teardown() {
  mosaic_teardown_server
}

set_orientation() {
  mosaic_t set-option -wq -t "${1:-t:1}" "@mosaic-orientation" "${2:?orientation required}"
}

set_nmaster() {
  mosaic_t set-option -wq -t "${1:-t:1}" "@mosaic-nmaster" "${2:?nmaster required}"
}

pane_field() {
  mosaic_t list-panes -t "${1:-t:1}" -F '#{pane_index} #{pane_left} #{pane_top} #{pane_width} #{pane_height}' |
    awk -v idx="${2:?pane index required}" -v field="${3:?field required}" '$1 == idx { print $field }'
}

layout_outer() {
  mosaic_layout "${1:-t:1}" | awk 'match($0, /[\[{]/) { print substr($0, RSTART, 1) }'
}

assert_orientation_layout() {
  local orient="${1:?orientation required}" outer
  set_orientation t:1 "$orient"
  for _ in 1 2 3; do mosaic_split; done
  outer=$(layout_outer)

  case "$orient" in
  left)
    [ "$outer" = "{" ]
    [ "$(pane_field t:1 1 2)" = "0" ]
    [ "$(pane_field t:1 1 5)" -gt "$(pane_field t:1 2 5)" ]
    ;;
  right)
    [ "$outer" = "{" ]
    [ "$(pane_field t:1 1 2)" -gt 0 ]
    [ "$(pane_field t:1 1 5)" -gt "$(pane_field t:1 2 5)" ]
    ;;
  top)
    [ "$outer" = "[" ]
    [ "$(pane_field t:1 1 3)" = "0" ]
    [ "$(pane_field t:1 1 4)" -gt "$(pane_field t:1 2 4)" ]
    ;;
  bottom)
    [ "$outer" = "[" ]
    [ "$(pane_field t:1 1 3)" -gt 0 ]
    [ "$(pane_field t:1 1 4)" -gt "$(pane_field t:1 2 4)" ]
    ;;
  esac
}

@test "plugin load: defaults are set" {
  run mosaic_t show-option -gqv @mosaic-mfact
  [ "$status" -eq 0 ]
  [ "$output" = "50" ]

  run mosaic_t show-option -gwqv @mosaic-algorithm
  [ "$status" -eq 0 ]
  [ -z "$output" ]

  run mosaic_t show-option -gwqv @mosaic-orientation
  [ "$status" -eq 0 ]
  [ "$output" = "left" ]

  run mosaic_t show-option -gwqv @mosaic-nmaster
  [ "$status" -eq 0 ]
  [ "$output" = "1" ]
}

@test "plugin load: hooks are registered" {
  run mosaic_t show-hooks -g after-split-window
  [ "$status" -eq 0 ]
  [[ "$output" == *"relayout"* ]]

  run mosaic_t show-hooks -g after-kill-pane
  [[ "$output" == *"relayout"* ]]
}

@test "single pane: relayout is no-op" {
  [ "$(mosaic_pane_count)" = "1" ]
  mosaic_op relayout
  [ "$(mosaic_pane_count)" = "1" ]
}

@test "split: hook applies main-vertical" {
  mosaic_split
  layout=$(mosaic_layout)
  [[ "$layout" == *"{"* ]]
  [[ "$layout" == *"["* ]] || [ "$(mosaic_pane_count)" = "2" ]
}

@test "orientation left keeps the master on the left" {
  assert_orientation_layout left
}

@test "orientation right keeps the master on the right" {
  assert_orientation_layout right
}

@test "orientation top keeps the master on the top" {
  assert_orientation_layout top
}

@test "orientation bottom keeps the master on the bottom" {
  assert_orientation_layout bottom
}

@test "5 panes: master + equal-split stack" {
  for _ in 1 2 3 4; do mosaic_split; done
  [ "$(mosaic_pane_count)" = "5" ]
  layout=$(mosaic_layout)
  [[ "$layout" == *"{"* ]]
  [[ "$layout" == *"["* ]]
  pane2_h=$(mosaic_t list-panes -F '#{pane_index} #{pane_height}' | awk '$1==2{print $2}')
  pane3_h=$(mosaic_t list-panes -F '#{pane_index} #{pane_height}' | awk '$1==3{print $2}')
  diff=$((pane2_h - pane3_h))
  [ "${diff#-}" -le 1 ]
}

@test "nmaster 3: first three panes share the master area" {
  set_nmaster t:1 3
  for _ in 1 2 3 4; do mosaic_split; done

  [ "$(pane_field t:1 1 2)" = "0" ]
  [ "$(pane_field t:1 2 2)" = "0" ]
  [ "$(pane_field t:1 3 2)" = "0" ]
  [ "$(pane_field t:1 4 2)" -gt 0 ]

  pane1_h=$(pane_field t:1 1 5)
  pane2_h=$(pane_field t:1 2 5)
  pane3_h=$(pane_field t:1 3 5)
  diff12=$((pane1_h - pane2_h))
  diff23=$((pane2_h - pane3_h))
  [ "${diff12#-}" -le 1 ]
  [ "${diff23#-}" -le 1 ]
}

@test "nmaster 2 and right orientation keep both masters on the right" {
  set_nmaster t:1 2
  set_orientation t:1 right
  for _ in 1 2 3; do mosaic_split; done

  [ "$(pane_field t:1 1 2)" -gt 0 ]
  [ "$(pane_field t:1 2 2)" -gt 0 ]
  [ "$(pane_field t:1 3 2)" = "0" ]

  pane1_w=$(pane_field t:1 1 4)
  pane2_w=$(pane_field t:1 2 4)
  [ "$pane1_w" = "$pane2_w" ]
}

@test "promote from stack: focused pane becomes master" {
  for _ in 1 2 3; do mosaic_split; done
  mosaic_t select-pane -t t:1.3
  pid=$(mosaic_t display-message -p -t t:1 '#{pane_id}')

  mosaic_op promote
  [ "$(mosaic_pane_index)" = "1" ]
  [ "$(mosaic_t display-message -p -t t:1 '#{pane_id}')" = "$pid" ]
}

@test "promote on master: swaps with stack-top (Hyprland swapwithmaster)" {
  for _ in 1 2 3; do mosaic_split; done
  mosaic_t select-pane -t t:1.1
  master_pid=$(mosaic_pane_id_at t:1.1)
  stack_top_pid=$(mosaic_pane_id_at t:1.2)

  mosaic_op promote
  [ "$(mosaic_pane_id_at t:1.1)" = "$stack_top_pid" ]
  [ "$(mosaic_pane_id_at t:1.2)" = "$master_pid" ]
}

@test "promote from stack with nmaster 2 bubbles the focused pane to primary" {
  set_nmaster t:1 2
  for _ in 1 2 3; do mosaic_split; done
  master1_pid=$(mosaic_pane_id_at t:1.1)
  master2_pid=$(mosaic_pane_id_at t:1.2)
  chosen_pid=$(mosaic_pane_id_at t:1.4)
  mosaic_t select-pane -t t:1.4

  mosaic_op promote

  [ "$(mosaic_pane_index)" = "1" ]
  [ "$(mosaic_pane_id_at t:1.1)" = "$chosen_pid" ]
  [ "$(mosaic_pane_id_at t:1.2)" = "$master1_pid" ]
  [ "$(mosaic_pane_id_at t:1.3)" = "$master2_pid" ]
}

@test "promote on primary master with nmaster 2 rotates the next master forward" {
  set_nmaster t:1 2
  for _ in 1 2 3; do mosaic_split; done
  master1_pid=$(mosaic_pane_id_at t:1.1)
  master2_pid=$(mosaic_pane_id_at t:1.2)
  mosaic_t select-pane -t t:1.1

  mosaic_op promote

  [ "$(mosaic_pane_id_at t:1.1)" = "$master2_pid" ]
  [ "$(mosaic_pane_id_at t:1.2)" = "$master1_pid" ]
}

@test "resize-master adjusts mfact (window-scoped) and clamps" {
  mosaic_split
  [ "$(mosaic_t show-option -gqv @mosaic-mfact)" = "50" ]
  [ -z "$(mosaic_t show-option -wqv -t t:1 @mosaic-mfact)" ]

  mosaic_op resize-master +10
  [ "$(mosaic_t show-option -wqv -t t:1 @mosaic-mfact)" = "60" ]
  [ "$(mosaic_t show-option -gqv @mosaic-mfact)" = "50" ]

  mosaic_op resize-master -100
  [ "$(mosaic_t show-option -wqv -t t:1 @mosaic-mfact)" = "5" ]

  mosaic_op resize-master +200
  [ "$(mosaic_t show-option -wqv -t t:1 @mosaic-mfact)" = "95" ]
}

@test "resize-master in top orientation writes main-pane-height" {
  for _ in 1 2 3; do mosaic_split; done
  set_orientation t:1 top
  mosaic_op relayout

  fp=$(mosaic_fingerprint t:1)

  mosaic_op resize-master +10
  mosaic_wait_fingerprint_changed_from "$fp" t:1

  [ "$(mosaic_t show-option -wqv -t t:1 @mosaic-mfact)" = "60" ]
  [ "$(mosaic_t show-option -wqv -t t:1 main-pane-height)" = "60%" ]
}

@test "resize-master with nmaster 2 resizes the whole master region" {
  set_nmaster t:1 2
  for _ in 1 2 3; do mosaic_split; done

  fp=$(mosaic_fingerprint t:1)

  mosaic_op resize-master +10
  mosaic_wait_fingerprint_changed_from "$fp" t:1

  [ "$(mosaic_t show-option -wqv -t t:1 @mosaic-mfact)" = "60" ]
  pane1_w=$(pane_field t:1 1 4)
  pane2_w=$(pane_field t:1 2 4)
  pane3_w=$(pane_field t:1 3 4)
  [ "$pane1_w" = "$pane2_w" ]
  [ "$pane1_w" -ge 118 ]
  [ "$pane1_w" -le 121 ]
  [ "$pane1_w" -gt "$pane3_w" ]
}

@test "resize-master on two windows is independent" {
  mosaic_split
  mosaic_t new-window -t t: "sleep 3600"
  mosaic_use_algorithm master-stack t:2
  mosaic_t split-window -t t:2 "sleep 3600"
  mosaic_wait_pane_count 2 t:2
  mosaic_quiesce

  mosaic_t select-window -t t:1
  mosaic_op resize-master +20

  mosaic_t select-window -t t:2
  mosaic_op resize-master -10

  [ "$(mosaic_t show-option -wqv -t t:1 @mosaic-mfact)" = "70" ]
  [ "$(mosaic_t show-option -wqv -t t:2 @mosaic-mfact)" = "40" ]
}

@test "kill stack pane: hook auto-rebalances stack" {
  for _ in 1 2 3 4; do mosaic_split; done
  [ "$(mosaic_pane_count)" = "5" ]
  mosaic_t kill-pane -t t:1.3
  mosaic_wait_pane_count_gt 0 t:1.3
  mosaic_quiesce
  [ "$(mosaic_pane_count)" = "4" ]
  pane2_h=$(mosaic_t list-panes -F '#{pane_index} #{pane_height}' | awk '$1==2{print $2}')
  pane3_h=$(mosaic_t list-panes -F '#{pane_index} #{pane_height}' | awk '$1==3{print $2}')
  diff=$((pane2_h - pane3_h))
  [ "${diff#-}" -le 1 ]
}

@test "kill master: stack-top promoted via renumber + relayout" {
  for _ in 1 2; do mosaic_split; done
  [ "$(mosaic_pane_count)" = "3" ]
  stack_top=$(mosaic_pane_id_at t:1.2)
  mosaic_t kill-pane -t t:1.1
  mosaic_wait_pane_count_gt 0 t:1.1
  mosaic_quiesce
  [ "$(mosaic_pane_count)" = "2" ]
  [ "$(mosaic_pane_id_at t:1.1)" = "$stack_top" ]
  layout=$(mosaic_layout)
  [[ "$layout" == *"{"* ]]
}

@test "disabled window: splits do NOT retile" {
  mosaic_clear_algorithm
  mosaic_split
  mosaic_split
  layout=$(mosaic_layout)
  [[ "$layout" != *"{"* ]] || [ "$(mosaic_pane_count)" -le 1 ]
}

@test "global algorithm: windows without a local override inherit it" {
  mosaic_clear_algorithm
  mosaic_use_global_algorithm master-stack
  mosaic_split
  mosaic_op relayout
  layout=$(mosaic_layout)
  [[ "$layout" == *"{"* ]]
}

@test "global algorithm: new windows inherit it" {
  mosaic_t new-window -t t: "sleep 3600"
  mosaic_use_global_algorithm master-stack
  mosaic_split t:2
  layout=$(mosaic_layout t:2)
  [[ "$layout" == *"{"* ]]
}

@test "window-local algorithm overrides the global default" {
  mosaic_clear_algorithm
  mosaic_use_global_algorithm master-stack
  mosaic_use_algorithm even-vertical
  mosaic_split
  mosaic_split
  layout=$(mosaic_layout)
  [[ "$layout" == *"["* ]]
  [[ "$layout" != *"{"* ]]
}

@test "window-local off disables the global default" {
  mosaic_clear_algorithm
  mosaic_use_global_algorithm master-stack
  mosaic_disable_algorithm
  mosaic_split
  mosaic_split
  layout=$(mosaic_layout)
  [[ "$layout" != *"{"* ]] || [ "$(mosaic_pane_count)" -le 1 ]
}

@test "toggle: clears the current window layout when no global default exists" {
  [ "$(mosaic_t show-option -wqv -t t:1 @mosaic-algorithm)" = "master-stack" ]
  mosaic_op toggle
  [ -z "$(mosaic_t show-option -wqv -t t:1 @mosaic-algorithm)" ]
}

@test "toggle: window without a layout stays inert" {
  mosaic_clear_algorithm
  mosaic_op toggle
  [ -z "$(mosaic_t show-option -wqv -t t:1 @mosaic-algorithm)" ]
}

@test "toggle: clearing the window layout disables relayout when no global default exists" {
  mosaic_t set-option -wq -t t:1 "@mosaic-algorithm" "even-vertical"
  for _ in 1 2; do mosaic_split; done

  layout=$(mosaic_layout)
  [[ "$layout" == *"["* ]]
  [[ "$layout" != *"{"* ]]

  mosaic_op toggle
  [ -z "$(mosaic_t show-option -wqv -t t:1 @mosaic-algorithm)" ]

  mosaic_t select-layout -t t:1 even-horizontal
  mosaic_op relayout

  layout=$(mosaic_layout)
  [[ "$layout" == *"{"* ]]
  [[ "$layout" != *"["* ]]
}

@test "toggle: inherited global layout writes local off" {
  mosaic_clear_algorithm
  mosaic_use_global_algorithm master-stack
  for _ in 1 2; do mosaic_split; done
  [ -z "$(mosaic_t show-option -wqv -t t:1 @mosaic-algorithm)" ]

  mosaic_op toggle
  [ "$(mosaic_t show-option -wqv -t t:1 @mosaic-algorithm)" = "off" ]

  mosaic_t select-layout -t t:1 even-vertical
  mosaic_op relayout

  layout=$(mosaic_layout)
  [[ "$layout" != *"{"* ]] || [ "$(mosaic_pane_count)" -le 1 ]
}

@test "toggle: local off can re-enable the global layout" {
  mosaic_clear_algorithm
  mosaic_use_global_algorithm master-stack
  mosaic_disable_algorithm
  for _ in 1 2; do mosaic_split; done

  mosaic_op toggle
  mosaic_wait_option_empty @mosaic-algorithm t:1
  mosaic_wait_layout_outer '{' t:1
  [ -z "$(mosaic_t show-option -wqv -t t:1 @mosaic-algorithm)" ]

  layout=$(mosaic_layout)
  [[ "$layout" == *"{"* ]]
}

@test "unknown algorithm: dispatcher errors cleanly" {
  mosaic_t set-option -wq -t t:1 "@mosaic-algorithm" "nonexistent-algo"
  run mosaic_exec_direct relayout
  [ "$status" -ne 0 ]
  [[ "$output" == *"unknown algorithm"* ]]
}

@test "drag-resize: master width survives next split" {
  mosaic_split
  mosaic_t resize-pane -t t:1.1 -x 160
  mosaic_wait_option @mosaic-mfact 80 t:1
  [ "$(mosaic_t show-option -wqv -t t:1 @mosaic-mfact)" = "80" ]

  mosaic_split
  pane_w=$(mosaic_t list-panes -t t:1 -F '#{pane_index} #{pane_width}' | awk '$1==1{print $2}')
  [ "$pane_w" -ge 158 ]
  [ "$pane_w" -le 161 ]
}

@test "drag-resize with nmaster 2 syncs mfact from the master region" {
  set_nmaster t:1 2
  for _ in 1 2; do mosaic_split; done
  mosaic_t resize-pane -t t:1.1 -x 120
  mosaic_wait_option @mosaic-mfact 60 t:1
  [ "$(mosaic_t show-option -wqv -t t:1 @mosaic-mfact)" = "60" ]

  mosaic_split
  pane1_w=$(pane_field t:1 1 4)
  pane2_w=$(pane_field t:1 2 4)
  [ "$pane1_w" = "$pane2_w" ]
  [ "$pane1_w" -ge 118 ]
  [ "$pane1_w" -le 121 ]
}

@test "drag-resize: zoomed pane does not poison mfact" {
  mosaic_split
  mosaic_t resize-pane -t t:1.1 -x 120
  mosaic_wait_option @mosaic-mfact 60 t:1
  [ "$(mosaic_t show-option -wqv -t t:1 @mosaic-mfact)" = "60" ]

  mosaic_t select-pane -t t:1.1
  mosaic_t resize-pane -Z
  mosaic_wait_option @mosaic-mfact 60 t:1
  [ "$(mosaic_t show-option -wqv -t t:1 @mosaic-mfact)" = "60" ]

  mosaic_t resize-pane -Z
  mosaic_wait_option @mosaic-mfact 60 t:1
  [ "$(mosaic_t show-option -wqv -t t:1 @mosaic-mfact)" = "60" ]
}

@test "drag-resize in top orientation syncs mfact from height" {
  set_orientation t:1 top
  mosaic_split
  mosaic_t resize-pane -t t:1.1 -y 30
  mosaic_wait_option_changed_from @mosaic-mfact 50 t:1

  mfact=$(mosaic_t show-option -wqv -t t:1 @mosaic-mfact)
  [ "$mfact" -ge 55 ]
  [ "$mfact" -le 65 ]

  mosaic_split
  pane_h=$(mosaic_t list-panes -t t:1 -F '#{pane_index} #{pane_height}' | awk '$1==1 { print $2 }')
  [ "$pane_h" -ge 28 ]
  [ "$pane_h" -le 31 ]
}
