#!/usr/bin/env bash

mosaic_get() {
    local opt="$1" default="$2"
    local val
    val=$(tmux show-option -gqv "$opt" 2>/dev/null)
    if [[ -z "$val" ]]; then
        echo "$default"
    else
        echo "$val"
    fi
}

mosaic_get_w() {
    local opt="$1" default="$2" target="${3:-}"
    local val
    if [[ -n "$target" ]]; then
        val=$(tmux show-option -wqv -t "$target" "$opt" 2>/dev/null)
    else
        val=$(tmux show-option -wqv "$opt" 2>/dev/null)
    fi
    if [[ -z "$val" ]]; then
        echo "$default"
    else
        echo "$val"
    fi
}

mosaic_enabled() {
    local target="${1:-}"
    local val
    val=$(mosaic_get_w "@mosaic-enabled" "0" "$target")
    [[ "$val" == "1" ]] || [[ "$val" == "on" ]] || [[ "$val" == "true" ]]
}

mosaic_log() {
    local debug
    debug=$(mosaic_get "@mosaic-debug" "0")
    [[ "$debug" != "1" ]] && return 0
    local logfile default_log
    default_log="${TMPDIR:-/tmp}/tmux-mosaic-$(id -u).log"
    logfile=$(mosaic_get "@mosaic-log-file" "$default_log")
    printf '%s [%d] %s\n' "$(date +%H:%M:%S.%N)" "$$" "$*" >>"$logfile"
}
