#!/usr/bin/env bats

load '../helpers.bash'

setup() {
  mosaic_setup_server
  mosaic_use_algorithm master-stack
}

teardown() {
  mosaic_teardown_server
}

pane_field() {
  mosaic_t list-panes -t "${1:-t:1}" -F '#{pane_index} #{pane_left} #{pane_top} #{pane_width} #{pane_height}' |
    awk -v idx="${2:?pane index required}" -v field="${3:?field required}" '$1 == idx { print $field }'
}

wait_pane1_left_gt_zero() {
  mosaic_wait_until 3000 \
    bash -c "[ \"\$(tmux -L $(mosaic_socket) list-panes -t t:1 -F '#{pane_index} #{pane_left}' | awk '\$1 == 1 { print \$2 }')\" -gt 0 ]"
}

wait_main_pane_width_eq() {
  local expected="$1"
  mosaic_wait_until 3000 \
    bash -c "[ \"\$(tmux -L $(mosaic_socket) show-option -wqv -t t:1 main-pane-width 2>/dev/null)\" = \"$expected\" ]"
}

@test "global -gwq @mosaic-orientation is honored when window has no local override" {
  mosaic_t set-option -gwq "@mosaic-orientation" "right"
  for _ in 1 2 3; do mosaic_split; done
  wait_pane1_left_gt_zero

  pane1_left=$(pane_field t:1 1 2)
  [ "$pane1_left" -gt 0 ]
}

@test "global -gwq @mosaic-orientation top puts the master on top" {
  mosaic_t set-option -gwq "@mosaic-orientation" "top"
  for _ in 1 2 3; do mosaic_split; done
  mosaic_wait_until 3000 \
    bash -c "[ \"\$(tmux -L $(mosaic_socket) list-panes -t t:1 -F '#{pane_index} #{pane_top}' | awk '\$1 == 2 { print \$2 }')\" -gt 0 ]"

  pane1_top=$(pane_field t:1 1 3)
  pane1_height=$(pane_field t:1 1 5)
  pane2_top=$(pane_field t:1 2 3)
  [ "$pane1_top" = "0" ]
  [ "$pane2_top" -ge "$pane1_height" ]
}

@test "global -gwq @mosaic-nmaster is honored when window has no local override" {
  mosaic_t set-option -gwq "@mosaic-nmaster" "2"
  for _ in 1 2 3; do mosaic_split; done
  mosaic_wait_until 3000 \
    bash -c "[ \"\$(tmux -L $(mosaic_socket) list-panes -t t:1 -F '#{pane_index} #{pane_top}' | awk '\$1 == 2 { print \$2 }')\" -gt 0 ]"

  pane1_left=$(pane_field t:1 1 2)
  pane2_left=$(pane_field t:1 2 2)
  pane3_left=$(pane_field t:1 3 2)
  pane1_top=$(pane_field t:1 1 3)
  pane2_top=$(pane_field t:1 2 3)
  [ "$pane1_left" = "0" ]
  [ "$pane2_left" = "0" ]
  [ "$pane3_left" -gt 0 ]
  [ "$pane2_top" -gt "$pane1_top" ]
}

@test "global -gwq @mosaic-mfact is honored when window has no local override" {
  mosaic_t set-option -gwq "@mosaic-mfact" "70"
  for _ in 1 2; do mosaic_split; done
  wait_main_pane_width_eq "70%"

  pane1_w=$(pane_field t:1 1 4)
  total_w=$(mosaic_t display-message -p -t t:1 '#{window_width}')
  expected_low=$((total_w * 65 / 100))
  expected_high=$((total_w * 75 / 100))
  [ "$pane1_w" -ge "$expected_low" ]
  [ "$pane1_w" -le "$expected_high" ]
}

@test "window-local override beats -gwq global default" {
  mosaic_t set-option -gwq "@mosaic-orientation" "right"
  mosaic_t set-option -wq -t t:1 "@mosaic-orientation" "left"
  for _ in 1 2 3; do mosaic_split; done

  pane1_left=$(pane_field t:1 1 2)
  [ "$pane1_left" = "0" ]
}

@test "removing window-local override falls back to -gwq global" {
  mosaic_t set-option -gwq "@mosaic-orientation" "right"
  mosaic_t set-option -wq -t t:1 "@mosaic-orientation" "left"
  for _ in 1 2 3; do mosaic_split; done

  pane1_left=$(pane_field t:1 1 2)
  [ "$pane1_left" = "0" ]

  mosaic_t set-option -wqu -t t:1 "@mosaic-orientation"
  wait_pane1_left_gt_zero

  pane1_left=$(pane_field t:1 1 2)
  [ "$pane1_left" -gt 0 ]
}

@test "fingerprint reflects -gwq global when window has no local override" {
  mosaic_t set-option -gwq "@mosaic-nmaster" "2"
  mosaic_split
  mosaic_wait_until 3000 \
    bash -c "[[ \"\$(tmux -L $(mosaic_socket) show-option -wqv -t t:1 @mosaic-_fingerprint)\" == *'|2|'* ]]"

  fp=$(mosaic_t show-option -wqv -t t:1 @mosaic-_fingerprint)
  [[ "$fp" == *"|2|"* ]]
}
