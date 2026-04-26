#!/usr/bin/env bash

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=helpers.sh
source "$CURRENT_DIR/helpers.sh"

load_algorithm() {
  local algo="$1"
  [[ "$algo" =~ ^[a-z][a-z0-9-]*$ ]] || return 2
  local file="$CURRENT_DIR/algorithms/$algo.sh"
  [[ -f "$file" ]] || return 3
  # shellcheck source=algorithms/master-stack.sh
  source "$file"
  return 0
}

show_load_error() {
  local rc="$1" algo="$2"
  case "$rc" in
  2) mosaic_show_message "mosaic: invalid algorithm name: $algo" ;;
  3) mosaic_show_message "mosaic: unknown algorithm: $algo" ;;
  esac
}

cmd="${1:-}"
[[ $# -gt 0 ]] && shift

WIN_ARG=""
CHANGED_OPT=""
case "$cmd" in
relayout | _sync-state)
  WIN_ARG="${1:-}"
  ;;
_on-set-option)
  CHANGED_OPT="${1:-}"
  WIN_ARG="${2:-}"
  ;;
esac

target_window=$(mosaic_resolve_window "$WIN_ARG")
local_algo=$(mosaic_local_algorithm "$target_window")
algo=$(mosaic_algorithm_for_window "$target_window")

if [[ "$cmd" == "toggle" && -z "$algo" && "$local_algo" == "off" ]]; then
  algo=$(mosaic_global_algorithm)
fi

if [[ -z "$algo" ]]; then
  case "$cmd" in
  _on-set-option)
    tmux set-option -wqu -t "$target_window" "@mosaic-_fingerprint" 2>/dev/null
    exit 0
    ;;
  relayout | _sync-state) exit 0 ;;
  toggle | promote | resize-master)
    mosaic_show_message "mosaic: no layout configured"
    exit 0
    ;;
  esac
fi

load_algorithm "$algo"
load_rc=$?
if [[ $load_rc -ne 0 ]]; then
  case "$cmd" in
  relayout | toggle | promote | resize-master) show_load_error "$load_rc" "$algo" ;;
  _on-set-option)
    [[ "$CHANGED_OPT" == "@mosaic-algorithm" ]] && show_load_error "$load_rc" "$algo"
    ;;
  esac
  exit 1
fi

if [[ "$cmd" == "_on-set-option" ]]; then
  fingerprint=$(mosaic_compute_fingerprint "$target_window" "$algo")
  cached=$(mosaic_fingerprint_get "$target_window")
  if [[ -n "$cached" && "$cached" == "$fingerprint" ]]; then
    exit 0
  fi
fi

dispatch_optional() {
  local fn="$1" message
  shift
  if declare -f "$fn" >/dev/null; then
    "$fn" "$@"
  else
    message="mosaic: $algo does not implement ${fn#algo_}"
    mosaic_show_message "$message"
  fi
}

case "$cmd" in
relayout | _on-set-option) algo_relayout "$target_window" ;;
toggle) algo_toggle ;;
_sync-state)
  if declare -f algo_sync_state >/dev/null; then
    algo_sync_state "$target_window"
  fi
  ;;
promote) dispatch_optional algo_promote ;;
resize-master) dispatch_optional algo_resize_master "$@" ;;
'')
  echo "usage: $0 <op> [args]" >&2
  exit 1
  ;;
*)
  echo "mosaic: unknown op: $cmd" >&2
  exit 1
  ;;
esac

case "$cmd" in
relayout | _on-set-option | promote)
  mosaic_fingerprint_set "$target_window" \
    "$(mosaic_compute_fingerprint "$target_window" "$algo")"
  ;;
esac
