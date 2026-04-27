#!/usr/bin/env bash

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=helpers.sh
source "$CURRENT_DIR/helpers.sh"

load_layout() {
  local layout="$1"
  [[ "$layout" =~ ^[a-z][a-z0-9-]*$ ]] || return 2
  local file="$CURRENT_DIR/layouts/$layout.sh"
  [[ -f "$file" ]] || return 3
  # shellcheck source=layouts/master-stack.sh
  source "$file"
  return 0
}

show_load_error() {
  local rc="$1" layout="$2"
  case "$rc" in
  2) _mosaic_show_message "mosaic: invalid layout name: $layout" ;;
  3) _mosaic_show_message "mosaic: unknown layout: $layout" ;;
  esac
}

cmd="${1:-}"
[[ $# -gt 0 ]] && shift

WIN_ARG=""
CHANGED_OPT=""
case "$cmd" in
relayout | _sync-state)
  if [[ -n "$(_mosaic_window_structural_guard_get "$target_window")" ]]; then
    _mosaic_window_structural_guard_unset "$target_window"
    exit 0
  fi
  WIN_ARG="${1:-}"
  ;;
_on-set-option)
  CHANGED_OPT="${1:-}"
  WIN_ARG="${2:-}"
  ;;
esac

target_window=$(_mosaic_resolve_window "$WIN_ARG")
local_layout=$(_mosaic_local_layout "$target_window")
layout=$(_mosaic_layout_for_window "$target_window")

if [[ "$cmd" == "toggle" && -z "$layout" && "$local_layout" == "off" ]]; then
  layout=$(_mosaic_global_layout)
fi

if [[ -z "$layout" ]]; then
  case "$cmd" in
  _on-set-option)
    _mosaic_window_ownership_clear "$target_window"
    _mosaic_fingerprint_unset "$target_window"
    _mosaic_pending_fingerprint_unset "$target_window"
    exit 0
    ;;
  relayout | _sync-state) exit 0 ;;
  toggle | new-pane | promote | resize-master)
    _mosaic_show_message "mosaic: no layout configured"
    exit 0
    ;;
  esac
fi

load_layout "$layout"
load_rc=$?
if [[ $load_rc -ne 0 ]]; then
  case "$cmd" in
  relayout | toggle | new-pane | promote | resize-master) show_load_error "$load_rc" "$layout" ;;
  _on-set-option)
    [[ "$CHANGED_OPT" == "@mosaic-layout" ]] && show_load_error "$load_rc" "$layout"
    ;;
  esac
  exit 1
fi

case "$cmd" in
relayout | _on-set-option | _sync-state | promote | resize-master)
  _mosaic_window_bootstrap_ownership "$target_window"
  ;;
esac

case "$cmd" in
relayout | _sync-state)
  auto_apply=$(_mosaic_auto_apply_for "$target_window")
  case "$auto_apply" in
  none)
    exit 0
    ;;
  full)
    _mosaic_window_adopt_current_panes "$target_window"
    ;;
  managed)
    _mosaic_window_refresh_state "$target_window"
    [[ "$(_mosaic_window_state_get "$target_window")" == "suspended" ]] && exit 0
    ;;
  esac
  ;;
esac

if [[ "$cmd" == "_on-set-option" ]]; then
  fingerprint=$(_mosaic_compute_fingerprint "$target_window" "$layout")
  pending=$(_mosaic_pending_fingerprint_get "$target_window")
  cached="${pending:-$(_mosaic_fingerprint_get "$target_window")}"
  if [[ -n "$cached" && "$cached" == "$fingerprint" ]]; then
    exit 0
  fi
  _mosaic_pending_fingerprint_set "$target_window" "$fingerprint"
fi

dispatch_optional() {
  local fn="$1" message
  shift
  if declare -f "$fn" >/dev/null; then
    "$fn" "$@"
  else
    message="mosaic: $layout does not implement $cmd"
    _mosaic_show_message "$message"
  fi
}

case "$cmd" in
relayout | _on-set-option) _layout_relayout "$target_window" ;;
toggle) _layout_toggle ;;
_sync-state)
  if declare -f _layout_sync_state >/dev/null; then
    _layout_sync_state "$target_window"
  fi
  ;;
new-pane)
  if [[ "$(_mosaic_window_state_get "$target_window")" == "suspended" ]]; then
    _mosaic_show_message "mosaic: window is suspended; adopt panes first"
    exit 1
  fi
  _mosaic_window_structural_guard_set "$target_window" "$RANDOM-$$"
  if declare -f _layout_new_pane >/dev/null; then
    pane=$(_layout_new_pane "$target_window")
  else
    pane=$(_mosaic_new_pane_default)
  fi
  rc=$?
  if [[ "$rc" -ne 0 || -z "$pane" ]]; then
    _mosaic_window_structural_guard_unset "$target_window"
    exit "${rc:-1}"
  fi
  generation=$(_mosaic_window_generation_ensure "$target_window")
  _mosaic_pane_owner_generation_set "$pane" "$generation"
  _mosaic_window_state_set "$target_window" "managed"
  _layout_relayout "$target_window"
  printf '%s\n' "$pane"
  ;;
promote) dispatch_optional _layout_promote ;;
resize-master) dispatch_optional _layout_resize_master "$@" ;;
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
relayout | _on-set-option | promote | new-pane)
  applied_fingerprint=$(_mosaic_compute_fingerprint "$target_window" "$layout")
  _mosaic_fingerprint_set "$target_window" "$applied_fingerprint"
  _mosaic_pending_fingerprint_unset "$target_window"
  ;;
esac
