#!/usr/bin/env bash

set -euo pipefail

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
tag="${1:?usage: $0 <tag> [changelog]}"
changelog="${2:-$CURRENT_DIR/../CHANGELOG.md}"

notes="$(
  awk -v tag="$tag" '
    $0 ~ "^## " tag "( - .*)?$" { in_section = 1; next }
    $0 ~ "^## " && in_section { exit }
    in_section { print }
  ' "$changelog"
)"

if [[ -z "$(printf '%s' "$notes" | tr -d '[:space:]')" ]]; then
  echo "mosaic: missing changelog section for $tag" >&2
  exit 1
fi

printf '%s\n' "$notes"
