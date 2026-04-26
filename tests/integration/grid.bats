#!/usr/bin/env bats

load '../helpers.bash'

setup() {
  _mosaic_setup_server
  _mosaic_t set-option -wq -t t:1 "@mosaic-layout" "grid"
}

teardown() {
  _mosaic_teardown_server
}

@test "grid: 4 panes use tiled layout" {
  for _ in 1 2 3; do _mosaic_split; done
  _mosaic_op relayout
  [ "$(_mosaic_pane_count)" = "4" ]

  layout=$(_mosaic_layout)
  [[ "$layout" == *"["* ]]
  [[ "$layout" == *"{"* ]]

  lefts=$(_mosaic_t list-panes -t t:1 -F '#{pane_left}' | sort -un)
  tops=$(_mosaic_t list-panes -t t:1 -F '#{pane_top}' | sort -un)
  widths=$(_mosaic_t list-panes -t t:1 -F '#{pane_width}' | sort -n)
  heights=$(_mosaic_t list-panes -t t:1 -F '#{pane_height}' | sort -n)

  [ "$(printf '%s\n' "$lefts" | wc -l)" = "2" ]
  [ "$(printf '%s\n' "$tops" | wc -l)" = "2" ]
  [ $(($(printf '%s\n' "$widths" | tail -n1) - $(printf '%s\n' "$widths" | head -n1))) -le 1 ]
  [ $(($(printf '%s\n' "$heights" | tail -n1) - $(printf '%s\n' "$heights" | head -n1))) -le 1 ]
}

@test "grid: promote surfaces the missing operation message in direct cli use" {
  run _mosaic_exec_direct promote
  [ "$status" -eq 0 ]
  [[ "$output" == *"mosaic: grid does not implement promote"* ]]
}

@test "grid: resize-master surfaces the missing operation message in direct cli use" {
  run _mosaic_exec_direct resize-master +5
  [ "$status" -eq 0 ]
  [[ "$output" == *"mosaic: grid does not implement resize-master"* ]]
}
