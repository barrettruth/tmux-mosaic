#!/usr/bin/env bash

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=helpers.sh
source "$CURRENT_DIR/helpers.sh"

current_window() { tmux display-message -p '#{window_id}'; }

algorithm_for_window() {
    local win="$1"
    local algo
    algo=$(mosaic_get_w "@mosaic-algorithm" "" "$win")
    if [[ -z "$algo" ]]; then
        algo=$(mosaic_get "@mosaic-default-algorithm" "master-stack")
    fi
    echo "$algo"
}

load_algorithm() {
    local algo="$1"
    if [[ ! "$algo" =~ ^[a-z][a-z0-9-]*$ ]]; then
        echo "mosaic: invalid algorithm name: $algo" >&2
        return 1
    fi
    local file="$CURRENT_DIR/algorithms/$algo.sh"
    if [[ ! -f "$file" ]]; then
        echo "mosaic: unknown algorithm: $algo" >&2
        return 1
    fi
    # shellcheck source=algorithms/master-stack.sh
    source "$file"
    return 0
}

cmd="${1:-}"
shift || true

WIN_ARG=""
case "$cmd" in
relayout)
    WIN_ARG="${1:-}"
    ;;
esac

target_window="${WIN_ARG:-$(current_window)}"
algo=$(algorithm_for_window "$target_window")

if ! load_algorithm "$algo"; then
    exit 1
fi

case "$cmd" in
relayout) algo_relayout "$target_window" ;;
toggle) algo_toggle ;;
focus-next) algo_focus_next ;;
focus-prev) algo_focus_prev ;;
focus-master) algo_focus_master ;;
swap-next) algo_swap_next ;;
swap-prev) algo_swap_prev ;;
promote) algo_promote ;;
resize-master) algo_resize_master "$@" ;;
toggle-zoom) algo_toggle_zoom ;;
'')
    echo "usage: $0 <op> [args]" >&2
    exit 1
    ;;
*)
    echo "mosaic: unknown op: $cmd" >&2
    exit 1
    ;;
esac
