#!/usr/bin/env bash

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=scripts/helpers.sh
source "$CURRENT_DIR/scripts/helpers.sh"
# shellcheck source=scripts/defaults.sh
source "$CURRENT_DIR/scripts/defaults.sh"

tmux set-option -gq "@mosaic-exec" "$(printf 'bash %q' "$CURRENT_DIR/scripts/ops.sh")"

_mosaic_set_defaults
_mosaic_register_hooks
