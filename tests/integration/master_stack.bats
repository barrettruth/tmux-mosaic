#!/usr/bin/env bats

load '../helpers.bash'

setup() {
    mosaic_setup_server
    mosaic_enable
}

teardown() {
    mosaic_teardown_server
}

@test "plugin load: defaults are set" {
    run mosaic_t show-option -gqv @mosaic-mfact
    [ "$status" -eq 0 ]
    [ "$output" = "50" ]

    run mosaic_t show-option -gqv @mosaic-default-algorithm
    [ "$status" -eq 0 ]
    [ "$output" = "master-stack" ]
}

@test "plugin load: hooks are registered" {
    run mosaic_t show-hooks -g after-split-window
    [ "$status" -eq 0 ]
    [[ "$output" == *"_relayout"* ]]

    run mosaic_t show-hooks -g after-kill-pane
    [[ "$output" == *"_relayout"* ]]
}

@test "single pane: relayout is no-op" {
    [ "$(mosaic_pane_count)" = "1" ]
    mosaic_op _relayout
    [ "$(mosaic_pane_count)" = "1" ]
}

@test "split: hook applies main-vertical" {
    mosaic_split
    layout=$(mosaic_layout)
    [[ "$layout" == *"{"* ]]
    [[ "$layout" == *"["* ]] || [ "$(mosaic_pane_count)" = "2" ]
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

@test "swap-next ring: master cycles through stack and back" {
    for _ in 1 2 3; do mosaic_split; done
    mosaic_t select-pane -t t:1.1
    pid=$(mosaic_t display-message -p -t t:1 '#{pane_id}')

    for expected_idx in 2 3 4 1; do
        mosaic_op swap-next
        actual_idx=$(mosaic_pane_index)
        actual_pid=$(mosaic_t display-message -p -t t:1 '#{pane_id}')
        [ "$actual_pid" = "$pid" ]
        [ "$actual_idx" = "$expected_idx" ]
    done
}

@test "swap-prev ring: master jumps to last slave, walks back" {
    for _ in 1 2 3; do mosaic_split; done
    mosaic_t select-pane -t t:1.1
    pid=$(mosaic_t display-message -p -t t:1 '#{pane_id}')

    for expected_idx in 4 3 2 1; do
        mosaic_op swap-prev
        actual_idx=$(mosaic_pane_index)
        actual_pid=$(mosaic_t display-message -p -t t:1 '#{pane_id}')
        [ "$actual_pid" = "$pid" ]
        [ "$actual_idx" = "$expected_idx" ]
    done
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

@test "focus-next/prev cycle through ring" {
    for _ in 1 2 3; do mosaic_split; done
    mosaic_t select-pane -t t:1.1
    [ "$(mosaic_pane_index)" = "1" ]

    for expected in 2 3 4 1; do
        mosaic_op focus-next
        [ "$(mosaic_pane_index)" = "$expected" ]
    done

    for expected in 4 3 2 1; do
        mosaic_op focus-prev
        [ "$(mosaic_pane_index)" = "$expected" ]
    done
}

@test "focus-master jumps to pane 1" {
    for _ in 1 2 3; do mosaic_split; done
    mosaic_t select-pane -t t:1.4
    mosaic_op focus-master
    [ "$(mosaic_pane_index)" = "1" ]
}

@test "resize-master adjusts mfact and clamps" {
    [ "$(mosaic_t show-option -gqv @mosaic-mfact)" = "50" ]
    mosaic_op resize-master +10
    [ "$(mosaic_t show-option -gqv @mosaic-mfact)" = "60" ]
    mosaic_op resize-master -100
    [ "$(mosaic_t show-option -gqv @mosaic-mfact)" = "5" ]
    mosaic_op resize-master +200
    [ "$(mosaic_t show-option -gqv @mosaic-mfact)" = "95" ]
}

@test "kill stack pane: hook auto-rebalances stack" {
    for _ in 1 2 3 4; do mosaic_split; done
    [ "$(mosaic_pane_count)" = "5" ]
    mosaic_t kill-pane -t t:1.3
    sleep 0.2
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
    sleep 0.2
    [ "$(mosaic_pane_count)" = "2" ]
    [ "$(mosaic_pane_id_at t:1.1)" = "$stack_top" ]
    layout=$(mosaic_layout)
    [[ "$layout" == *"{"* ]]
}

@test "toggle-zoom toggles window_zoomed_flag" {
    mosaic_split
    [ "$(mosaic_t display-message -p -t t:1 '#{window_zoomed_flag}')" = "0" ]
    mosaic_op toggle-zoom
    [ "$(mosaic_t display-message -p -t t:1 '#{window_zoomed_flag}')" = "1" ]
    mosaic_op toggle-zoom
    [ "$(mosaic_t display-message -p -t t:1 '#{window_zoomed_flag}')" = "0" ]
}

@test "disabled window: splits do NOT retile" {
    mosaic_t set-option -wqu -t t:1 "@mosaic-enabled"
    mosaic_split
    mosaic_split
    layout=$(mosaic_layout)
    [[ "$layout" != *"{"* ]] || [ "$(mosaic_pane_count)" -le 1 ]
}

@test "toggle: enable/disable transitions correctly" {
    mosaic_t set-option -wqu -t t:1 "@mosaic-enabled"
    [ -z "$(mosaic_t show-option -wqv -t t:1 @mosaic-enabled)" ]
    mosaic_op toggle
    [ "$(mosaic_t show-option -wqv -t t:1 @mosaic-enabled)" = "1" ]
    mosaic_op toggle
    [ -z "$(mosaic_t show-option -wqv -t t:1 @mosaic-enabled)" ]
}

@test "unknown algorithm: dispatcher errors cleanly" {
    mosaic_t set-option -gq "@mosaic-default-algorithm" "nonexistent-algo"
    run mosaic_exec_direct focus-next
    [ "$status" -ne 0 ]
    [[ "$output" == *"unknown algorithm"* ]]
}
