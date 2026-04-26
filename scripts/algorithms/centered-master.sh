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

algo_layout_checksum() {
  local layout="$1" csum=0 i ch
  for ((i = 0; i < ${#layout}; i++)); do
    printf -v ch '%d' "'${layout:i:1}"
    csum=$(((csum >> 1) | ((csum & 1) << 15)))
    csum=$(((csum + ch) & 0xffff))
  done
  printf '%04x\n' "$csum"
}

algo_layout_leaf_id=0

algo_layout_leaf() {
  local __out="$1" sx="$2" sy="$3" x="$4" y="$5" id="$algo_layout_leaf_id"
  algo_layout_leaf_id=$((algo_layout_leaf_id + 1))
  printf -v "$__out" '%sx%s,%s,%s,%s' "$sx" "$sy" "$x" "$y" "$id"
}

algo_layout_split_sizes() {
  local total="$1" count="$2" usable base rem i size out=()
  if [[ "$count" -le 1 ]]; then
    printf '%s\n' "$total"
    return
  fi
  usable=$((total - count + 1))
  base=$((usable / count))
  rem=$((usable % count))
  for ((i = 0; i < count; i++)); do
    size=$base
    [[ "$i" -lt "$rem" ]] && size=$((size + 1))
    out+=("$size")
  done
  printf '%s\n' "${out[*]}"
}

algo_layout_column() {
  local __out="$1" sx="$2" sy="$3" x="$4" y="$5" count="$6"
  local node leaf size ycur
  local -a sizes

  if [[ "$count" -eq 1 ]]; then
    algo_layout_leaf node "$sx" "$sy" "$x" "$y"
    printf -v "$__out" '%s' "$node"
    return
  fi

  read -r -a sizes <<<"$(algo_layout_split_sizes "$sy" "$count")"
  node="${sx}x${sy},${x},${y}["
  ycur=$y
  for size in "${sizes[@]}"; do
    algo_layout_leaf leaf "$sx" "$size" "$x" "$ycur"
    node+="$leaf,"
    ycur=$((ycur + size + 1))
  done
  node="${node%,}]"
  printf -v "$__out" '%s' "$node"
}

algo_layout_body() {
  local __out="$1" sx="$2" sy="$3" n="$4" nmaster="$5" mfact="$6"
  local stack mw maxw sw left_w right_w left_n right_n layout master left right

  algo_layout_leaf_id=0

  if [[ "$n" -eq 1 ]]; then
    algo_layout_leaf layout "$sx" "$sy" 0 0
    printf -v "$__out" '%s' "$layout"
    return
  fi

  if [[ "$nmaster" -ge "$n" ]]; then
    algo_layout_column layout "$sx" "$sy" 0 0 "$n"
    printf -v "$__out" '%s' "$layout"
    return
  fi

  stack=$((n - nmaster))
  mw=$((sx * mfact / 100))

  if [[ "$stack" -le 1 ]]; then
    maxw=$((sx - 2))
    [[ "$maxw" -lt 1 ]] && maxw=1
    [[ "$mw" -gt "$maxw" ]] && mw=$maxw
    [[ "$mw" -lt 1 ]] && mw=1
    sw=$((sx - mw - 1))
    algo_layout_column master "$mw" "$sy" 0 0 "$nmaster"
    algo_layout_column right "$sw" "$sy" "$((mw + 1))" 0 "$stack"
    layout="${sx}x${sy},0,0{$master,$right}"
    printf -v "$__out" '%s' "$layout"
    return
  fi

  maxw=$((sx - 4))
  [[ "$maxw" -lt 1 ]] && maxw=1
  [[ "$mw" -gt "$maxw" ]] && mw=$maxw
  [[ "$mw" -lt 1 ]] && mw=1
  sw=$((sx - mw - 2))
  left_w=$((sw / 2))
  right_w=$((sw - left_w))
  right_n=$(((stack + 1) / 2))
  left_n=$((stack / 2))

  algo_layout_column left "$left_w" "$sy" 0 0 "$left_n"
  algo_layout_column master "$mw" "$sy" "$((left_w + 1))" 0 "$nmaster"
  algo_layout_column right "$right_w" "$sy" "$((left_w + mw + 2))" 0 "$right_n"
  layout="${sx}x${sy},0,0{$left,$master,$right}"
  printf -v "$__out" '%s' "$layout"
}

algo_apply_layout() {
  local win="$1" n="$2" nmaster="$3" mfact="$4"
  local sx sy body
  sx=$(tmux display-message -p -t "$win" '#{window_width}' 2>/dev/null)
  sy=$(tmux display-message -p -t "$win" '#{window_height}' 2>/dev/null)
  [[ -z "$sx" || -z "$sy" ]] && return 0
  algo_layout_body body "$sx" "$sy" "$n" "$nmaster" "$mfact"
  tmux select-layout -t "$win" "$(algo_layout_checksum "$body"),$body" 2>/dev/null || true
}

algo_left_stack_count() {
  local n="$1" nmaster="$2" stack
  stack=$((n - nmaster))
  if [[ "$stack" -le 1 ]]; then
    printf '%s\n' 0
  else
    printf '%s\n' $((stack / 2))
  fi
}

algo_master_base() {
  local n="$1" nmaster="$2" pbase="$3" left_n
  left_n=$(algo_left_stack_count "$n" "$nmaster")
  printf '%s\n' $((pbase + left_n))
}

algo_stack_top() {
  local n="$1" nmaster="$2" pbase="$3" master_base="$4" left_n
  left_n=$(algo_left_stack_count "$n" "$nmaster")
  if [[ "$left_n" -gt 0 ]]; then
    printf '%s\n' "$pbase"
  else
    printf '%s\n' $((master_base + nmaster))
  fi
}

algo_relayout() {
  local win n mfact nmaster pbase master_base
  win=$(mosaic_resolve_window "${1:-}")
  n=$(mosaic_window_pane_count "$win")
  mosaic_can_relayout_window "$win" "$n" || return 0
  mfact=$(algo_mfact_for "$win")
  nmaster=$(mosaic_effective_nmaster "$win" "$n")
  pbase=$(algo_pane_base)
  master_base=$(algo_master_base "$n" "$nmaster" "$pbase")

  algo_apply_layout "$win" "$n" "$nmaster" "$mfact"

  mosaic_log "relayout: win=$win n=$n layout=centered-master nmaster=$nmaster mfact=$mfact pbase=$pbase master_base=$master_base"
}

algo_toggle() { mosaic_toggle_window; }

algo_promote() {
  local idx n win nmaster pbase master_base stack_top
  idx=$(algo_pane_index)
  win=$(mosaic_current_window)
  n=$(mosaic_window_pane_count "$win")
  nmaster=$(mosaic_effective_nmaster "$win" "$n")
  pbase=$(algo_pane_base)
  master_base=$(algo_master_base "$n" "$nmaster" "$pbase")

  [[ "$n" -le 1 ]] && return 0

  if [[ "$idx" -eq "$master_base" ]]; then
    if [[ "$nmaster" -gt 1 ]]; then
      mosaic_swap_keep_focus -s ":.$master_base" -t ":.$((master_base + 1))"
    else
      stack_top=$(algo_stack_top "$n" "$nmaster" "$pbase" "$master_base")
      [[ "$stack_top" -ne "$master_base" ]] && mosaic_swap_keep_focus -s ":.$master_base" -t ":.$stack_top"
    fi
  else
    mosaic_bubble_keep_focus "$idx" "$master_base"
  fi
  algo_relayout
}

algo_resize_master() {
  local delta="${1:-}"
  if [[ -z "$delta" ]]; then
    delta=$(mosaic_get "@mosaic-step" "5")
  fi
  local win cur new
  win=$(mosaic_current_window)
  cur=$(algo_mfact_for "$win")
  new=$((cur + delta))
  [[ "$new" -lt 5 ]] && new=5
  [[ "$new" -gt 95 ]] && new=95
  tmux set-option -wq -t "$win" "@mosaic-mfact" "$new"
}

algo_sync_state() {
  local win="$1"
  mosaic_enabled "$win" || return 0
  [[ "$(mosaic_window_zoomed "$win")" == "1" ]] && return 0

  local n nmaster
  n=$(mosaic_window_pane_count "$win")
  [[ "$n" -le 1 ]] && return 0
  nmaster=$(mosaic_effective_nmaster "$win" "$n")
  [[ "$nmaster" -ge "$n" ]] && return 0

  local pbase master_base pane_size window_size pct
  pbase=$(algo_pane_base)
  master_base=$(algo_master_base "$n" "$nmaster" "$pbase")
  pane_size=$(tmux display-message -p -t "$win.$master_base" '#{pane_width}' 2>/dev/null)
  window_size=$(tmux display-message -p -t "$win" '#{window_width}' 2>/dev/null)
  [[ -z "$pane_size" ]] && return 0
  [[ -z "$window_size" || "$window_size" -le 0 ]] && return 0

  pct=$((pane_size * 100 / window_size))
  [[ "$pct" -lt 5 ]] && pct=5
  [[ "$pct" -gt 95 ]] && pct=95

  tmux set-option -wq -t "$win" "@mosaic-mfact" "$pct"
  mosaic_log "sync-state: win=$win layout=centered-master master_base=$master_base pane_size=$pane_size window_size=$window_size pct=$pct"
}
