#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FLAKE_FILE="${MOSAIC_FLAKE_FILE:-$ROOT_DIR/flake.nix}"

usage() {
  printf '%s\n' "usage: $0 <get|set|assert-stable|assert-dev|next-patch-dev|tag|base|nightly-tag> [version] [sha]" >&2
}

read_version() {
  local version
  version="$(awk -F'"' '/version = "/ { print $2; exit }' "$FLAKE_FILE")"
  [[ -n "$version" ]] || {
    printf '%s\n' "mosaic: could not read version from $FLAKE_FILE" >&2
    return 1
  }
  printf '%s\n' "$version"
}

is_stable() {
  [[ "$1" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]
}

is_dev() {
  [[ "$1" =~ ^[0-9]+\.[0-9]+\.[0-9]+-dev$ ]]
}

assert_stable() {
  is_stable "$1" || {
    printf '%s\n' "mosaic: expected stable semver, got $1" >&2
    return 1
  }
}

assert_dev() {
  is_dev "$1" || {
    printf '%s\n' "mosaic: expected dev semver, got $1" >&2
    return 1
  }
}

assert_git_sha() {
  [[ "$1" =~ ^[0-9a-fA-F]{7,40}$ ]] || {
    printf '%s\n' "mosaic: expected git sha, got $1" >&2
    return 1
  }
}

set_version() {
  local target="$1" current tmp
  current="$(read_version)"
  tmp="$(mktemp)"
  awk -v current="$current" -v target="$target" '
    BEGIN { done = 0 }
    {
      if (!done) {
        pattern = "version = \"" current "\";"
        replacement = "version = \"" target "\";"
        if (index($0, pattern)) {
          sub(pattern, replacement)
          done = 1
        }
      }
      print
    }
    END { if (!done) exit 1 }
  ' "$FLAKE_FILE" >"$tmp"
  cat "$tmp" >"$FLAKE_FILE"
  rm -f "$tmp"
}

base_version() {
  local version="$1"
  if is_dev "$version"; then
    printf '%s\n' "${version%-dev}"
  else
    printf '%s\n' "$version"
  fi
}

next_patch_dev() {
  local major minor patch
  assert_stable "$1"
  IFS=. read -r major minor patch <<<"$1"
  printf '%s\n' "$major.$minor.$((patch + 1))-dev"
}

release_tag() {
  assert_stable "$1"
  printf '%s\n' "v$1"
}

nightly_tag() {
  local version="$1" sha="$2"
  assert_dev "$version"
  assert_git_sha "$sha"
  sha="${sha,,}"
  printf '%s\n' "nightly-$version-${sha:0:7}"
}

cmd="${1:-}"
arg="${2:-}"
arg2="${3:-}"

case "$cmd" in
get)
  read_version
  ;;
set)
  [[ -n "$arg" ]] || {
    usage
    exit 1
  }
  set_version "$arg"
  ;;
assert-stable)
  assert_stable "${arg:-$(read_version)}"
  ;;
assert-dev)
  assert_dev "${arg:-$(read_version)}"
  ;;
next-patch-dev)
  next_patch_dev "${arg:-$(read_version)}"
  ;;
tag)
  release_tag "${arg:-$(read_version)}"
  ;;
base)
  base_version "${arg:-$(read_version)}"
  ;;
nightly-tag)
  if [ -n "$arg2" ]; then
    nightly_tag "$arg" "$arg2"
  elif [ -n "$arg" ]; then
    nightly_tag "$(read_version)" "$arg"
  else
    usage
    exit 1
  fi
  ;;
*)
  usage
  exit 1
  ;;
esac
