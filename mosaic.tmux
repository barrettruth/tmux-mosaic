#!/usr/bin/env bash

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=scripts/helpers.sh
source "$CURRENT_DIR/scripts/helpers.sh"
# shellcheck source=scripts/defaults.sh
source "$CURRENT_DIR/scripts/defaults.sh"

tmux set-option -gq "@mosaic-exec" "$CURRENT_DIR/scripts/ops.sh"

mosaic_set_defaults
mosaic_register_hooks
