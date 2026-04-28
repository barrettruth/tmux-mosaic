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
