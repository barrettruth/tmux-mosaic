#!/usr/bin/env bats

load '../helpers.bash'

setup() {
  mosaic_setup_server
  mosaic_t set-option -wq -t t:1 "@mosaic-algorithm" "grid"
}

teardown() {
  mosaic_teardown_server
}

@test "grid: 4 panes use tiled layout" {
  for _ in 1 2 3; do mosaic_split; done
  mosaic_op relayout
  [ "$(mosaic_pane_count)" = "4" ]

  layout=$(mosaic_layout)
  [[ "$layout" == *"["* ]]
  [[ "$layout" == *"{"* ]]

  lefts=$(mosaic_t list-panes -t t:1 -F '#{pane_left}' | sort -un)
  tops=$(mosaic_t list-panes -t t:1 -F '#{pane_top}' | sort -un)
  widths=$(mosaic_t list-panes -t t:1 -F '#{pane_width}' | sort -n)
  heights=$(mosaic_t list-panes -t t:1 -F '#{pane_height}' | sort -n)

  [ "$(printf '%s\n' "$lefts" | wc -l)" = "2" ]
  [ "$(printf '%s\n' "$tops" | wc -l)" = "2" ]
  [ $(($(printf '%s\n' "$widths" | tail -n1) - $(printf '%s\n' "$widths" | head -n1))) -le 1 ]
  [ $(($(printf '%s\n' "$heights" | tail -n1) - $(printf '%s\n' "$heights" | head -n1))) -le 1 ]
}

@test "grid: promote surfaces the missing operation message in direct cli use" {
  run mosaic_exec_direct promote
  [ "$status" -eq 0 ]
  [[ "$output" == *"mosaic: grid does not implement promote"* ]]
}
