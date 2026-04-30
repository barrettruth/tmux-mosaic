#!/usr/bin/env bats

load '../helpers.bash'

setup() {
  _mosaic_setup_server
}

teardown() {
  _mosaic_teardown_server
}

helper_eval() {
  local cmd="${1:?command required}" sock
  sock=$(_mosaic_socket_path)
  TMUX="$sock,$$,0" bash -c "source '$REPO_ROOT/scripts/helpers.sh'; $cmd"
}

@test "new-pane helpers: window last pane returns the semantic tail" {
  local tail
  _mosaic_t split-window -t t:1 "sleep 3600"
  _mosaic_wait_pane_count 2 t:1
  _mosaic_t split-window -t t:1 "sleep 3600"
  _mosaic_wait_pane_count 3 t:1
  tail=$(_mosaic_pane_id_at t:1.3)

  run helper_eval "_mosaic_window_last_pane 't:1'"
  [ "$status" -eq 0 ]
  [ "$output" = "$tail" ]
}

@test "new-pane helpers: targeted split uses the target pane but the current pane path" {
  local current_dir target_dir target pane current_rect
  current_dir="$BATS_TEST_TMPDIR/current"
  target_dir="$BATS_TEST_TMPDIR/target"
  mkdir -p "$current_dir" "$target_dir"

  _mosaic_t respawn-pane -k -t t:1.1 -c "$current_dir" "sleep 3600"
  _mosaic_wait_pane_count 1 t:1
  _mosaic_t split-window -t t:1.1 -c "$target_dir" "sleep 3600"
  _mosaic_wait_pane_count 2 t:1
  _mosaic_t select-pane -t t:1.1
  target=$(_mosaic_pane_id_at t:1.2)
  current_rect=$(_mosaic_pane_rect t:1.1)
  [ "$(_mosaic_pane_current_path "$target")" = "$target_dir" ]

  run helper_eval "_mosaic_new_pane_split '$target'"
  [ "$status" -eq 0 ]
  pane="$output"

  _mosaic_wait_pane_present "$pane" t:1
  [ "$(_mosaic_pane_rect t:1.1)" = "$current_rect" ]
  [ "$(_mosaic_pane_current_path "$pane")" = "$current_dir" ]
}

@test "new-pane helpers: targeted split accepts explicit side flags" {
  local pane original
  original=$(_mosaic_pane_id_at t:1.1)

  run helper_eval "_mosaic_new_pane_split '$original' -h -b"
  [ "$status" -eq 0 ]
  pane="$output"

  _mosaic_wait_pane_present "$pane" t:1
  [ "$(_mosaic_pane_left "$pane")" = "0" ]
  [ "$(_mosaic_pane_left "$original")" -gt 0 ]
}

@test "new-pane helpers: move wrapper preserves focus" {
  local focus source target
  _mosaic_t split-window -t t:1 "sleep 3600"
  _mosaic_wait_pane_count 2 t:1
  _mosaic_t split-window -t t:1 "sleep 3600"
  _mosaic_wait_pane_count 3 t:1
  _mosaic_t select-pane -t t:1.2
  focus=$(_mosaic_pane_id_at t:1.2)
  source=$(_mosaic_pane_id_at t:1.1)
  target=$(_mosaic_pane_id_at t:1.3)

  run helper_eval "_mosaic_move_keep_focus -s '$source' -t '$target'"
  [ "$status" -eq 0 ]

  [ "$(_mosaic_t display-message -p -t t:1 '#{pane_id}')" = "$focus" ]
  [ "$(_mosaic_pane_id_at t:1.3)" = "$source" ]
}
