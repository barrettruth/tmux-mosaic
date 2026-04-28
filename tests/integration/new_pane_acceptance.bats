#!/usr/bin/env bats

load '../helpers.bash'

setup() {
  _mosaic_setup_server
}

teardown() {
  _mosaic_teardown_server
}

setup_layout() {
  local layout="${1:?layout required}" splits="${2:?split count required}"
  _mosaic_use_layout "$layout"
  _mosaic_wait_option_set @mosaic-_fingerprint t:1
  for ((i = 0; i < splits; i++)); do
    _mosaic_split
  done
}

setup_master_stack_transition() {
  local orientation="${1:?orientation required}" nmaster="${2:?nmaster required}"
  _mosaic_use_layout master-stack
  _mosaic_t set-option -wq -t t:1 "@mosaic-orientation" "$orientation"
  _mosaic_t set-option -wq -t t:1 "@mosaic-nmaster" "$nmaster"
  _mosaic_wait_option_set @mosaic-_fingerprint t:1
  for ((i = 1; i < nmaster; i++)); do
    _mosaic_split
  done
}

@test "new-pane acceptance: dwindle tail growth is an exact local split" {
  local first second third tail pane
  local first_rect second_rect third_rect
  local left top width height new_left new_top new_width new_height

  setup_layout dwindle 3
  first=$(_mosaic_pane_id_at t:1.1)
  second=$(_mosaic_pane_id_at t:1.2)
  third=$(_mosaic_pane_id_at t:1.3)
  tail=$(_mosaic_pane_id_at t:1.4)
  first_rect=$(_mosaic_pane_rect "$first")
  second_rect=$(_mosaic_pane_rect "$second")
  third_rect=$(_mosaic_pane_rect "$third")
  read -r left top width height <<<"$(_mosaic_pane_rect "$tail")"

  pane=$(_mosaic_new_pane)

  [ "$(_mosaic_pane_rect "$first")" = "$first_rect" ]
  [ "$(_mosaic_pane_rect "$second")" = "$second_rect" ]
  [ "$(_mosaic_pane_rect "$third")" = "$third_rect" ]
  read -r new_left new_top new_width new_height <<<"$(_mosaic_pane_rect "$pane")"
  _mosaic_rect_contains "$left" "$top" "$width" "$height" "$new_left" "$new_top" "$new_width" "$new_height"
}

@test "new-pane acceptance: even-horizontal append equalizes the row" {
  local first tail pane
  local first_width
  local left top width height new_left new_top new_width new_height

  setup_layout even-horizontal 2
  first=$(_mosaic_pane_id_at t:1.1)
  tail=$(_mosaic_pane_id_at t:1.3)
  first_width=$(_mosaic_pane_width "$first")
  read -r left top width height <<<"$(_mosaic_pane_rect "$tail")"

  pane=$(_mosaic_new_pane)

  read -r new_left new_top new_width new_height <<<"$(_mosaic_pane_rect "$pane")"
  _mosaic_rect_contains "$left" "$top" "$width" "$height" "$new_left" "$new_top" "$new_width" "$new_height"
  [ "$(_mosaic_pane_width "$first")" -lt "$first_width" ]
}

@test "new-pane acceptance: master-stack left all-masters transition compresses masters into the left branch while the new pane stays right" {
  local top_master bottom_master pane
  local top_master_left bottom_master_left

  setup_master_stack_transition left 2
  top_master=$(_mosaic_pane_id_at t:1.1)
  bottom_master=$(_mosaic_pane_id_at t:1.2)

  pane=$(_mosaic_new_pane)
  top_master_left=$(_mosaic_pane_left "$top_master")
  bottom_master_left=$(_mosaic_pane_left "$bottom_master")

  [ "$top_master_left" -eq 0 ]
  [ "$bottom_master_left" -eq 0 ]
  [ "$(_mosaic_pane_left "$pane")" -gt "$top_master_left" ]
}

@test "new-pane acceptance: master-stack right all-masters transition compresses masters into the right branch while the new pane stays left" {
  local top_master bottom_master pane
  local top_master_left bottom_master_left

  setup_master_stack_transition right 2
  top_master=$(_mosaic_pane_id_at t:1.1)
  bottom_master=$(_mosaic_pane_id_at t:1.2)

  pane=$(_mosaic_new_pane)
  top_master_left=$(_mosaic_pane_left "$top_master")
  bottom_master_left=$(_mosaic_pane_left "$bottom_master")

  [ "$top_master_left" -gt 0 ]
  [ "$bottom_master_left" -gt 0 ]
  [ "$(_mosaic_pane_left "$pane")" -lt "$top_master_left" ]
}

@test "new-pane acceptance: spiral four-to-five pushes the old tail inward while the new pane stays outer right" {
  local old_inner old_tail pane
  local old_tail_left old_tail_top

  setup_layout spiral 3
  old_inner=$(_mosaic_pane_id_at t:1.3)
  old_tail=$(_mosaic_pane_id_at t:1.4)
  old_tail_left=$(_mosaic_pane_left "$old_tail")
  old_tail_top=$(_mosaic_pane_top "$old_tail")

  pane=$(_mosaic_new_pane)

  [ "$(_mosaic_pane_left "$old_tail")" -lt "$old_tail_left" ]
  [ "$(_mosaic_pane_left "$old_tail")" -eq "$(_mosaic_pane_left "$old_inner")" ]
  [ "$(_mosaic_pane_top "$old_tail")" -gt "$(_mosaic_pane_top "$old_inner")" ]
  [ "$(_mosaic_pane_left "$pane")" -eq "$old_tail_left" ]
  [ "$(_mosaic_pane_top "$pane")" -eq "$old_tail_top" ]
}

@test "new-pane acceptance: centered-master two-to-three introduces the left stack while keeping the new pane on the right" {
  local left old_right pane
  local old_right_left

  setup_layout centered-master 1
  left=$(_mosaic_pane_id_at t:1.1)
  old_right=$(_mosaic_pane_id_at t:1.2)
  old_right_left=$(_mosaic_pane_left "$old_right")

  pane=$(_mosaic_new_pane)

  [ "$(_mosaic_pane_left "$left")" -eq 0 ]
  [ "$(_mosaic_pane_left "$old_right")" -lt "$old_right_left" ]
  [ "$(_mosaic_pane_left "$old_right")" -gt "$(_mosaic_pane_left "$left")" ]
  [ "$(_mosaic_pane_left "$pane")" -gt "$old_right_left" ]
}

@test "new-pane acceptance: centered-master four-to-five shifts pane roles locally" {
  local master right
  local master_left right_left

  setup_layout centered-master 3
  master=$(_mosaic_pane_id_at t:1.2)
  right=$(_mosaic_pane_id_at t:1.3)
  master_left=$(_mosaic_pane_left "$master")
  right_left=$(_mosaic_pane_left "$right")

  _mosaic_new_pane >/dev/null

  [ "$(_mosaic_pane_left "$master")" -lt "$master_left" ]
  [ "$(_mosaic_pane_left "$right")" -lt "$right_left" ]
  [ "$(_mosaic_pane_left "$right")" -eq "$master_left" ]
}

@test "new-pane acceptance: three-column three-to-four moves the old right pane into the middle while the new pane stays right" {
  local middle old_right pane
  local old_right_left

  setup_layout three-column 2
  middle=$(_mosaic_pane_id_at t:1.2)
  old_right=$(_mosaic_pane_id_at t:1.3)
  old_right_left=$(_mosaic_pane_left "$old_right")

  pane=$(_mosaic_new_pane)

  [ "$(_mosaic_pane_left "$middle")" -gt 0 ]
  [ "$(_mosaic_pane_left "$old_right")" -lt "$old_right_left" ]
  [ "$(_mosaic_pane_left "$old_right")" -eq "$(_mosaic_pane_left "$middle")" ]
  [ "$(_mosaic_pane_left "$pane")" -gt "$(_mosaic_pane_left "$old_right")" ]
}

@test "new-pane acceptance: grid two-to-three moves the old bottom pane into the top row while the new pane stays on the bottom" {
  local old_top old_bottom pane
  local old_bottom_top

  setup_layout grid 1
  old_top=$(_mosaic_pane_id_at t:1.1)
  old_bottom=$(_mosaic_pane_id_at t:1.2)
  old_bottom_top=$(_mosaic_pane_top "$old_bottom")

  pane=$(_mosaic_new_pane)

  [ "$(_mosaic_pane_top "$old_top")" -eq 0 ]
  [ "$(_mosaic_pane_top "$old_bottom")" -lt "$old_bottom_top" ]
  [ "$(_mosaic_pane_top "$old_bottom")" -eq "$(_mosaic_pane_top "$old_top")" ]
  [ "$(_mosaic_pane_top "$pane")" -gt "$(_mosaic_pane_top "$old_top")" ]
}

@test "new-pane acceptance: grid four-to-five is a global reshape" {
  local first second third fourth pane
  local first_rect second_rect third_rect fourth_rect
  local new_left new_top new_width new_height

  setup_layout grid 3
  first=$(_mosaic_pane_id_at t:1.1)
  second=$(_mosaic_pane_id_at t:1.2)
  third=$(_mosaic_pane_id_at t:1.3)
  fourth=$(_mosaic_pane_id_at t:1.4)
  first_rect=$(_mosaic_pane_rect "$first")
  second_rect=$(_mosaic_pane_rect "$second")
  third_rect=$(_mosaic_pane_rect "$third")
  fourth_rect=$(_mosaic_pane_rect "$fourth")

  pane=$(_mosaic_new_pane)
  read -r new_left new_top new_width new_height <<<"$(_mosaic_pane_rect "$pane")"

  ! _mosaic_rect_contains $first_rect "$new_left" "$new_top" "$new_width" "$new_height"
  ! _mosaic_rect_contains $second_rect "$new_left" "$new_top" "$new_width" "$new_height"
  ! _mosaic_rect_contains $third_rect "$new_left" "$new_top" "$new_width" "$new_height"
  ! _mosaic_rect_contains $fourth_rect "$new_left" "$new_top" "$new_width" "$new_height"
}

@test "new-pane acceptance: grid six-to-seven is also a global reshape" {
  local pane
  local new_left new_top new_width new_height
  local -a rects

  setup_layout grid 5
  while IFS= read -r old; do
    [[ -n "$old" ]] || continue
    rects+=("$(_mosaic_pane_rect "$old")")
  done < <(_mosaic_pane_ids t:1)

  pane=$(_mosaic_new_pane)
  read -r new_left new_top new_width new_height <<<"$(_mosaic_pane_rect "$pane")"

  for rect in "${rects[@]}"; do
    ! _mosaic_rect_contains $rect "$new_left" "$new_top" "$new_width" "$new_height"
  done
}

@test "new-pane acceptance: tmux cannot get mirrored side and append order from one horizontal split" {
  local old right left

  old=$(_mosaic_pane_id_at t:1.1)

  right=$(_mosaic_raw_split -h -t t:1.1)
  _mosaic_wait_pane_present "$right" t:1
  [ "$(_mosaic_last_pane_id t:1)" = "$right" ]
  [ "$(_mosaic_pane_left "$right")" -gt "$(_mosaic_pane_left "$old")" ]

  _mosaic_t kill-pane -t "$right"
  _mosaic_wait_pane_count 1 t:1

  left=$(_mosaic_raw_split -h -b -t t:1.1)
  _mosaic_wait_pane_present "$left" t:1
  [ "$(_mosaic_pane_left "$left")" -lt "$(_mosaic_pane_left "$old")" ]
  [ "$(_mosaic_last_pane_id t:1)" = "$old" ]
}

@test "new-pane acceptance: monocle snaps zoom and focus to the new pane" {
  local active_before pane

  setup_layout monocle 2
  active_before=$(_mosaic_t display-message -p -t t:1 '#{pane_id}')
  [ "$(_mosaic_t display-message -p -t t:1 '#{window_zoomed_flag}')" = "1" ]

  pane=$(_mosaic_new_pane)

  [ "$(_mosaic_t display-message -p -t t:1 '#{window_zoomed_flag}')" = "1" ]
  [ "$(_mosaic_t display-message -p -t t:1 '#{pane_id}')" = "$pane" ]
  [ "$pane" != "$active_before" ]
}

@test "new-pane acceptance: master-stack falls back when the stack tail is too small" {
  local tail pane

  _mosaic_teardown_server
  _mosaic_setup_server 20 10
  _mosaic_use_layout master-stack
  _mosaic_wait_option_set @mosaic-_fingerprint t:1
  for _ in 1 2 3; do
    _mosaic_split
  done
  tail=$(_mosaic_pane_id_at t:1.4)
  _mosaic_t select-pane -t "$tail"

  pane=$(_mosaic_new_pane)

  [ "$(_mosaic_pane_count t:1)" = "5" ]
  [ "$(_mosaic_last_pane_id t:1)" = "$pane" ]
}

@test "new-pane acceptance: centered-master falls back when the side tail is too small" {
  local tail pane

  _mosaic_teardown_server
  _mosaic_setup_server 20 10
  _mosaic_use_layout centered-master
  _mosaic_wait_option_set @mosaic-_fingerprint t:1
  for _ in 1 2 3 4 5; do
    _mosaic_split
  done
  tail=$(_mosaic_pane_id_at t:1.6)
  _mosaic_t select-pane -t "$tail"

  pane=$(_mosaic_new_pane)

  [ "$(_mosaic_pane_count t:1)" = "7" ]
  [ "$(_mosaic_last_pane_id t:1)" = "$pane" ]
}

@test "new-pane acceptance: raw split reports no space on a tiny pane" {
  local pane

  _mosaic_teardown_server
  _mosaic_setup_server 10 6

  pane=$(_mosaic_raw_split -h -t t:1.1)
  _mosaic_wait_pane_present "$pane" t:1
  pane=$(_mosaic_raw_split -h -t t:1.1)
  _mosaic_wait_pane_present "$pane" t:1
  pane=$(_mosaic_raw_split -v -t t:1.1)
  _mosaic_wait_pane_present "$pane" t:1

  run _mosaic_raw_split -h -t t:1.1
  [ "$status" -eq 1 ]
  [[ "$output" == *"no space for new pane"* ]]
}
