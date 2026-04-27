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

@test "ownership bootstrap: single-pane window gets generation and owns its sole pane" {
  local pane gen
  _mosaic_use_layout master-stack
  _mosaic_wait_window_generation_set t:1
  _mosaic_wait_window_state managed t:1

  pane=$(_mosaic_pane_id_at t:1.1)
  gen=$(_mosaic_window_generation t:1)
  [ -n "$gen" ]
  [ "$(_mosaic_pane_owner_generation "$pane")" = "$gen" ]
}

@test "ownership bootstrap: multi-pane window adopts current panes when metadata is absent" {
  for _ in 1 2 3; do _mosaic_split; done
  [ -z "$(_mosaic_window_generation t:1)" ]

  _mosaic_use_layout master-stack
  _mosaic_wait_window_generation_set t:1
  _mosaic_wait_window_state managed t:1

  assert_all_panes_owned t:1
}

@test "ownership move: pane moved into another window stays foreign there" {
  local src_pane src_gen dst_gen
  _mosaic_split
  _mosaic_use_layout master-stack
  _mosaic_wait_window_generation_set t:1
  _mosaic_wait_window_state managed t:1

  src_pane=$(_mosaic_pane_id_at t:1.2)
  src_gen=$(_mosaic_window_generation t:1)
  [ "$(_mosaic_pane_owner_generation "$src_pane")" = "$src_gen" ]

  _mosaic_t new-window -d -t t: -n other "sleep 3600"
  _mosaic_use_layout master-stack t:2
  _mosaic_wait_window_generation_set t:2
  _mosaic_wait_window_state managed t:2
  dst_gen=$(_mosaic_window_generation t:2)
  [ "$src_gen" != "$dst_gen" ]

  _mosaic_t join-pane -s "$src_pane" -t t:2.1
  _mosaic_wait_pane_count 1 t:1
  _mosaic_wait_pane_count 2 t:2

  [ "$(_mosaic_pane_owner_generation "$src_pane")" = "$src_gen" ]
  [ "$(_mosaic_pane_owner_generation "$src_pane")" != "$dst_gen" ]
}

@test "ownership move: pane owner metadata survives cross-session moves" {
  local pane gen
  _mosaic_split
  _mosaic_use_layout master-stack
  _mosaic_wait_window_generation_set t:1
  _mosaic_wait_window_state managed t:1

  pane=$(_mosaic_pane_id_at t:1.2)
  gen=$(_mosaic_window_generation t:1)
  [ "$(_mosaic_pane_owner_generation "$pane")" = "$gen" ]

  _mosaic_t new-session -d -s u -x 200 -y 50 "sleep 3600"
  _mosaic_t join-pane -s "$pane" -t u:1.1
  _mosaic_wait_until 3000 \
    bash -c "[ \"\$(tmux -L $(_mosaic_socket) list-panes -t u:1 -F '#{pane_id}' | grep -c '$pane')\" = '1' ]"

  [ "$(_mosaic_pane_owner_generation "$pane")" = "$gen" ]
}

@test "ownership state: linked windows share generation and layout state" {
  local win gen
  _mosaic_use_layout master-stack
  _mosaic_wait_window_generation_set t:1
  _mosaic_wait_window_state managed t:1

  win=$(_mosaic_t list-windows -t t -F '#{window_id}' | head -n1)
  gen=$(_mosaic_window_generation t:1)
  _mosaic_t new-session -d -s u -x 200 -y 50 "sleep 3600"
  _mosaic_t link-window -s t:1 -t u:2

  [ "$(_mosaic_t display-message -p -t u:2 '#{window_id}')" = "$win" ]
  [ "$(_mosaic_window_generation u:2)" = "$gen" ]
  [ "$(_mosaic_window_state u:2)" = "managed" ]
  [ "$(_mosaic_t show-option -wqv -t u:2 @mosaic-layout)" = "master-stack" ]
}

@test "ownership cleanup: disabling Mosaic clears window and pane ownership state" {
  local pane
  for _ in 1 2; do _mosaic_split; done
  _mosaic_use_layout master-stack
  _mosaic_wait_window_generation_set t:1
  _mosaic_wait_window_state managed t:1

  _mosaic_disable_layout
  _mosaic_wait_window_ownership_cleared t:1

  [ -z "$(_mosaic_window_generation t:1)" ]
  [ -z "$(_mosaic_window_state t:1)" ]
  while IFS= read -r pane; do
    [ -z "$(_mosaic_pane_owner_generation "$pane")" ]
  done < <(_mosaic_t list-panes -t t:1 -F '#{pane_id}')
}
