#!/usr/bin/env bash

algo_pane_count() { tmux display-message -p '#{window_panes}'; }
algo_pane_index() { tmux display-message -p '#{pane_index}'; }
algo_pane_base() { tmux display-message -p '#{e|+|:0,#{?pane-base-index,#{pane-base-index},0}}'; }

algo_mfact_for() {
    local win="$1"
    local val
    val=$(tmux show-option -wqv -t "$win" "@mosaic-mfact" 2>/dev/null)
    [[ -n "$val" ]] && {
        echo "$val"
        return
    }
    mosaic_get "@mosaic-mfact" "50"
}

algo_swap_keep_focus() {
    local pid
    pid=$(tmux display-message -p '#{pane_id}')
    tmux swap-pane "$@"
    tmux select-pane -t "$pid"
}

algo_relayout() {
    local win="${1:-}"
    [[ -z "$win" ]] && win=$(tmux display-message -p '#{window_id}')

    if ! mosaic_enabled "$win"; then
        mosaic_log "relayout: disabled on $win, skipping"
        return 0
    fi

    local n
    n=$(tmux list-panes -t "$win" 2>/dev/null | wc -l)
    [[ "$n" -le 1 ]] && return 0

    local mfact
    mfact=$(algo_mfact_for "$win")

    tmux set-window-option -t "$win" main-pane-width "${mfact}%" 2>/dev/null || true
    tmux select-layout -t "$win" main-vertical 2>/dev/null || true

    mosaic_log "relayout: win=$win n=$n mfact=$mfact"
}

algo_toggle() {
    local win
    win=$(tmux display-message -p '#{window_id}')
    if mosaic_enabled "$win"; then
        tmux set-option -wqu -t "$win" "@mosaic-enabled" 2>/dev/null
        tmux display-message "mosaic: off"
    else
        tmux set-option -wq -t "$win" "@mosaic-enabled" 1
        tmux display-message "mosaic: on"
        algo_relayout "$win"
    fi
}

algo_focus_next() { tmux select-pane -t :.+; }
algo_focus_prev() { tmux select-pane -t :.-; }
algo_focus_master() { tmux select-pane -t ":.$(algo_pane_base)"; }

algo_swap_next() {
    [[ "$(algo_pane_count)" -le 1 ]] && return 0
    tmux swap-pane -D
}

algo_swap_prev() {
    [[ "$(algo_pane_count)" -le 1 ]] && return 0
    tmux swap-pane -U
}

algo_promote() {
    local idx n pbase
    idx=$(algo_pane_index)
    n=$(algo_pane_count)
    pbase=$(algo_pane_base)

    [[ "$n" -le 1 ]] && return 0

    if [[ "$idx" -eq "$pbase" ]]; then
        algo_swap_keep_focus -s ":.$pbase" -t ":.$((pbase + 1))"
    else
        algo_swap_keep_focus -s ":.$idx" -t ":.$pbase"
    fi
    algo_relayout
}

algo_resize_master() {
    local delta="${1:-}"
    if [[ -z "$delta" ]]; then
        delta=$(mosaic_get "@mosaic-step" "5")
    fi
    local win cur new
    win=$(tmux display-message -p '#{window_id}')
    cur=$(algo_mfact_for "$win")
    new=$((cur + delta))
    [[ "$new" -lt 5 ]] && new=5
    [[ "$new" -gt 95 ]] && new=95
    tmux set-option -wq -t "$win" "@mosaic-mfact" "$new"
    algo_relayout "$win"
}

algo_toggle_zoom() { tmux resize-pane -Z; }

algo_sync_state() {
    local win="$1"
    mosaic_enabled "$win" || return 0
    [[ "$(tmux display-message -p -t "$win" '#{window_zoomed_flag}')" == "1" ]] && return 0

    local n
    n=$(tmux list-panes -t "$win" 2>/dev/null | wc -l)
    [[ "$n" -le 1 ]] && return 0

    local pbase pane_w window_w pct
    pbase=$(algo_pane_base)
    pane_w=$(tmux display-message -p -t "$win.$pbase" '#{pane_width}' 2>/dev/null)
    window_w=$(tmux display-message -p -t "$win" '#{window_width}' 2>/dev/null)
    [[ -z "$pane_w" ]] && return 0
    [[ -z "$window_w" || "$window_w" -le 0 ]] && return 0

    pct=$((pane_w * 100 / window_w))
    [[ "$pct" -lt 5 ]] && pct=5
    [[ "$pct" -gt 95 ]] && pct=95

    tmux set-option -wq -t "$win" "@mosaic-mfact" "$pct"
    mosaic_log "sync-state: win=$win pane_w=$pane_w window_w=$window_w pct=$pct"
}
