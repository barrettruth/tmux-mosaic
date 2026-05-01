#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION_SCRIPT="$ROOT_DIR/scripts/release-version.sh"

usage() {
  printf '%s\n' "usage: $0 <prepare|publish|nightly>" >&2
}

die() {
  printf 'mosaic release: %s\n' "$*" >&2
  exit 1
}

api_url="${FORGEJO_API_URL:-${GITHUB_API_URL:-}}"
server_url="${FORGEJO_SERVER_URL:-${GITHUB_SERVER_URL:-}}"
repository="${FORGEJO_REPOSITORY:-${GITHUB_REPOSITORY:-}}"
token="${FORGEJO_TOKEN:-${GITHUB_TOKEN:-}}"

require_api_context() {
  [ -n "$api_url" ] || die "FORGEJO_API_URL is required"
  [ -n "$server_url" ] || die "FORGEJO_SERVER_URL is required"
  [ -n "$repository" ] || die "FORGEJO_REPOSITORY is required"
  [ -n "$token" ] || die "FORGEJO_TOKEN is required"
}

api_capture() {
  local method="$1" path="$2" output="$3" data="${4:-}"
  local args=(
    -sS
    -o "$output"
    -w "%{http_code}"
    -X "$method"
    -H "Authorization: token $token"
    -H "Accept: application/json"
  )
  if [ -n "$data" ]; then
    args+=(
      -H "Content-Type: application/json"
      --data-binary "@$data"
    )
  fi
  curl "${args[@]}" "$api_url/$path"
}

api_required() {
  local method="$1" path="$2" expected="$3" data="${4:-}" output status
  output="$(mktemp)"
  status="$(api_capture "$method" "$path" "$output" "$data")"
  case " $expected " in
  *" $status "*)
    cat "$output"
    rm -f "$output"
    ;;
  *)
    cat "$output" >&2 || true
    rm -f "$output"
    die "$method $path returned HTTP $status, expected $expected"
    ;;
  esac
}

set_git_identity() {
  local host
  host="${server_url#https://}"
  host="${host#http://}"
  host="${host%%/*}"
  git config user.name "forgejo-actions[bot]"
  git config user.email "forgejo-actions[bot]@$host"
}

configure_origin_for_push() {
  local host
  host="${server_url#https://}"
  host="${host#http://}"
  host="${host%%/*}"
  git remote set-url origin "https://forgejo-actions:${token}@$host/$repository.git"
}

fetch_main_and_tags() {
  git fetch origin '+refs/heads/main:refs/remotes/origin/main' --tags
}

ensure_label() {
  local name="$1" color="$2" description="$3" output status payload
  output="$(mktemp)"
  status="$(api_capture GET "repos/$repository/labels/$name" "$output")"
  case "$status" in
  200)
    rm -f "$output"
    return
    ;;
  404)
    rm -f "$output"
    payload="$(mktemp)"
    jq -n \
      --arg name "$name" \
      --arg color "$color" \
      --arg description "$description" \
      '{name: $name, color: $color, description: $description}' >"$payload"
    api_required POST "repos/$repository/labels" "200 201" "$payload" >/dev/null
    rm -f "$payload"
    ;;
  *)
    cat "$output" >&2 || true
    rm -f "$output"
    die "GET label $name returned HTTP $status"
    ;;
  esac
}

ensure_release_labels() {
  ensure_label "breaking-change" "b60205" "Change that breaks documented user-facing behavior"
  ensure_label "skip-release-notes" "cfd3d7" "Exclude from generated release notes"
}

add_issue_label() {
  local number="$1" label="$2" payload
  payload="$(mktemp)"
  jq -n --arg label "$label" '{labels: [$label]}' >"$payload"
  api_required POST "repos/$repository/issues/$number/labels" "200 201" "$payload" >/dev/null
  rm -f "$payload"
}

open_pr_number_for_branch() {
  local branch="$1" pulls
  pulls="$(api_required GET "repos/$repository/pulls?state=open&base=main" "200")"
  jq -r --arg branch "$branch" '
    .[]
    | select(
        .head.ref == $branch
        or .head.name == $branch
        or ((.head.label // "") | endswith(":" + $branch))
      )
    | .number
  ' <<<"$pulls" | head -n 1
}

open_or_update_pr() {
  local branch="$1" title="$2" body_file="$3" number payload
  payload="$(mktemp)"
  number="$(open_pr_number_for_branch "$branch")"
  if [ -n "$number" ]; then
    jq -n --arg title "$title" --rawfile body "$body_file" \
      '{title: $title, body: $body}' >"$payload"
    api_required PATCH "repos/$repository/pulls/$number" "200" "$payload" >/dev/null
  else
    jq -n \
      --arg base "main" \
      --arg head "$branch" \
      --arg title "$title" \
      --rawfile body "$body_file" \
      '{base: $base, head: $head, title: $title, body: $body}' >"$payload"
    number="$(api_required POST "repos/$repository/pulls" "200 201" "$payload" | jq -r '.number')"
  fi
  rm -f "$payload"
  add_issue_label "$number" "skip-release-notes"
  printf '%s\n' "$number"
}

remote_tag_target() {
  local tag="$1" target
  target="$(git ls-remote --tags origin "refs/tags/$tag^{}" | awk '{print $1}' | head -n 1)"
  if [ -z "$target" ]; then
    target="$(git ls-remote --tags origin "refs/tags/$tag" | awk '{print $1}' | head -n 1)"
  fi
  printf '%s\n' "$target"
}

create_annotated_tag_if_missing() {
  local tag="$1" target="$2" current
  current="$(remote_tag_target "$tag")"
  if [ -n "$current" ] && [ "$current" != "$target" ]; then
    die "tag $tag already points at $current, not $target"
  fi
  if [ -z "$current" ]; then
    git tag -d "$tag" >/dev/null 2>&1 || true
    git tag -a "$tag" "$target" -m "$tag"
    git push origin "refs/tags/$tag"
  fi
}

release_id_by_tag() {
  local tag="$1" output status
  output="$(mktemp)"
  status="$(api_capture GET "repos/$repository/releases/tags/$tag" "$output")"
  case "$status" in
  200)
    jq -r '.id' "$output"
    rm -f "$output"
    ;;
  404)
    rm -f "$output"
    return 1
    ;;
  *)
    cat "$output" >&2 || true
    rm -f "$output"
    die "GET release $tag returned HTTP $status"
    ;;
  esac
}

create_or_update_release() {
  local tag="$1" title="$2" notes_file="$3" prerelease="$4" target="$5" id payload
  payload="$(mktemp)"
  jq -n \
    --arg tag_name "$tag" \
    --arg target_commitish "$target" \
    --arg name "$title" \
    --rawfile body "$notes_file" \
    --argjson prerelease "$prerelease" \
    '{
      tag_name: $tag_name,
      target_commitish: $target_commitish,
      name: $name,
      body: $body,
      draft: false,
      prerelease: $prerelease
    }' >"$payload"
  if id="$(release_id_by_tag "$tag")"; then
    api_required PATCH "repos/$repository/releases/$id" "200" "$payload" >/dev/null
  else
    api_required POST "repos/$repository/releases" "200 201" "$payload" >/dev/null
  fi
  rm -f "$payload"
}

delete_release_by_tag() {
  local tag="$1" id
  if id="$(release_id_by_tag "$tag")"; then
    api_required DELETE "repos/$repository/releases/$id" "200 204" >/dev/null
  fi
}

quality_context_status() {
  local sha="$1" context="$2" statuses
  statuses="$(api_required GET "repos/$repository/commits/$sha/status" "200")"
  jq -r --arg context "$context" '
    [.statuses[]? | select(.context == $context)][0].status // ""
  ' <<<"$statuses"
}

require_quality_success() {
  local sha="$1" skip="${SKIP_QUALITY_CHECK:-}"
  local context status
  if [ "$skip" = "true" ]; then
    printf 'Skipping quality status check for %s\n' "$sha"
    return
  fi
  for context in \
    "quality / Format (push)" \
    "quality / Lint (push)" \
    "quality / Test (push)"; do
    status="$(quality_context_status "$sha" "$context")"
    [ "$status" = "success" ] || die "$context for $sha is '$status', expected success"
  done
}

previous_stable_tag() {
  local exclude="${1:-}"
  git tag --list 'v[0-9]*.[0-9]*.[0-9]*' --sort=-v:refname |
    { if [ -n "$exclude" ]; then grep -vx "$exclude"; else cat; fi; } |
    head -n 1
}

write_notes() {
  local output="$1" title="$2" target="$3" previous="$4"
  local range
  {
    printf '%s\n\n' "$title"
    printf "Built from \`%s\`.\n\n" "$target"
    if [ -n "$previous" ]; then
      range="$previous..$target"
      printf "Changes since \`%s\`:\n\n" "$previous"
    else
      range="$target"
      printf 'Changes in this release:\n\n'
    fi
    if ! git log --format="- %s (\`%h\`)" --reverse "$range"; then
      printf '%s\n' '- No commit range could be generated.'
    fi
    if [ -n "$previous" ]; then
      printf '\nFull comparison: %s/%s/compare/%s...%s\n' "$server_url" "$repository" "$previous" "$target"
    fi
  } >"$output"
}

cmd_prepare() {
  local version="${VERSION:-}" next_dev_version="${NEXT_DEV_VERSION:-}" current base branch title body pr_number
  [ -n "$version" ] || die "VERSION is required"
  [ -n "$next_dev_version" ] || die "NEXT_DEV_VERSION is required"
  require_api_context
  ensure_release_labels
  set_git_identity
  configure_origin_for_push
  fetch_main_and_tags
  git checkout -B "release/v$version" origin/main
  current="$("$VERSION_SCRIPT" get)"
  "$VERSION_SCRIPT" assert-dev "$current"
  "$VERSION_SCRIPT" assert-stable "$version"
  "$VERSION_SCRIPT" assert-dev "$next_dev_version"
  base="$("$VERSION_SCRIPT" base "$current")"
  [ "$base" = "$version" ] || die "current dev base $base does not match requested release $version"
  [ "$current" != "$next_dev_version" ] || die "next dev version must differ from current version"
  "$VERSION_SCRIPT" set "$version"
  git add flake.nix
  if git diff --cached --quiet; then
    printf 'No release version change to commit for v%s\n' "$version"
  else
    git commit -m "chore(release): prepare v$version"
  fi
  branch="release/v$version"
  git push --force-with-lease origin "$branch"
  title="chore(release): prepare v$version"
  body="$(mktemp)"
  printf 'release-version: %s\nnext-dev-version: %s\n' "$version" "$next_dev_version" >"$body"
  pr_number="$(open_or_update_pr "$branch" "$title" "$body")"
  rm -f "$body"
  printf 'Release PR: %s/%s/pulls/%s\n' "$server_url" "$repository" "$pr_number"
}

cmd_publish() {
  local version tag next_dev_version head_sha previous notes branch title body pr_number current_main_version
  require_api_context
  ensure_release_labels
  set_git_identity
  configure_origin_for_push
  fetch_main_and_tags
  git checkout --detach origin/main
  head_sha="$(git rev-parse HEAD)"
  require_quality_success "$head_sha"
  version="$("$VERSION_SCRIPT" get)"
  "$VERSION_SCRIPT" assert-stable "$version"
  tag="$("$VERSION_SCRIPT" tag "$version")"
  next_dev_version="${NEXT_DEV_VERSION:-}"
  if [ -z "$next_dev_version" ]; then
    next_dev_version="$("$VERSION_SCRIPT" next-patch-dev "$version")"
  fi
  "$VERSION_SCRIPT" assert-dev "$next_dev_version"
  previous="$(previous_stable_tag "$tag" || true)"
  create_annotated_tag_if_missing "$tag" "$head_sha"
  notes="$(mktemp)"
  write_notes "$notes" "$tag" "$head_sha" "$previous"
  create_or_update_release "$tag" "$tag" "$notes" false "$head_sha"
  rm -f "$notes"
  current_main_version="$(git show origin/main:flake.nix | awk -F'"' '/version = "/ { print $2; exit }')"
  if [ "$current_main_version" != "$version" ]; then
    printf 'main already moved to %s; not opening next-dev PR\n' "$current_main_version"
    return
  fi
  branch="release/next-$next_dev_version"
  git checkout -B "$branch" "$head_sha"
  "$VERSION_SCRIPT" set "$next_dev_version"
  git add flake.nix
  if git diff --cached --quiet; then
    printf 'No next-dev version change to commit for %s\n' "$next_dev_version"
  else
    git commit -m "chore(release): start $next_dev_version"
  fi
  git push --force-with-lease origin "$branch"
  title="chore(release): start $next_dev_version"
  body="$(mktemp)"
  printf 'released-version: %s\nnext-dev-version: %s\n' "$version" "$next_dev_version" >"$body"
  pr_number="$(open_or_update_pr "$branch" "$title" "$body")"
  rm -f "$body"
  printf 'Published %s and opened next-dev PR: %s/%s/pulls/%s\n' "$tag" "$server_url" "$repository" "$pr_number"
}

cmd_nightly() {
  local head_sha version nightly_tag short_sha title previous immutable_current alias_current notes alias_notes
  require_api_context
  set_git_identity
  configure_origin_for_push
  fetch_main_and_tags
  git checkout --detach origin/main
  head_sha="$(git rev-parse HEAD)"
  require_quality_success "$head_sha"
  version="$("$VERSION_SCRIPT" get)"
  if ! "$VERSION_SCRIPT" assert-dev "$version" >/dev/null 2>&1; then
    printf 'Current main version %s is not a dev version; skipping nightly.\n' "$version"
    return
  fi
  nightly_tag="$("$VERSION_SCRIPT" nightly-tag "$version" "$head_sha")"
  short_sha="${head_sha:0:7}"
  title="Nightly $version ($short_sha)"
  previous="$(previous_stable_tag || true)"
  immutable_current="$(remote_tag_target "$nightly_tag")"
  alias_current="$(remote_tag_target nightly)"
  if [ "$immutable_current" = "$head_sha" ] &&
    [ "$alias_current" = "$head_sha" ] &&
    release_id_by_tag "$nightly_tag" >/dev/null &&
    release_id_by_tag nightly >/dev/null; then
    printf 'Nightly %s is already published.\n' "$nightly_tag"
    return
  fi
  create_annotated_tag_if_missing "$nightly_tag" "$head_sha"
  notes="$(mktemp)"
  write_notes "$notes" "Immutable nightly tag: \`$nightly_tag\`." "$head_sha" "$previous"
  create_or_update_release "$nightly_tag" "$title" "$notes" true "$head_sha"
  alias_notes="$(mktemp)"
  write_notes "$alias_notes" "Alias for \`$nightly_tag\`." "$head_sha" "$previous"
  delete_release_by_tag nightly
  git push origin :refs/tags/nightly || true
  git tag -d nightly >/dev/null 2>&1 || true
  git tag -a nightly "$head_sha" -m nightly
  git push --force origin refs/tags/nightly
  create_or_update_release nightly "$title" "$alias_notes" true "$head_sha"
  rm -f "$notes" "$alias_notes"
  printf 'Published nightly %s and refreshed nightly alias.\n' "$nightly_tag"
}

cmd="${1:-}"
case "$cmd" in
prepare)
  cmd_prepare
  ;;
publish)
  cmd_publish
  ;;
nightly)
  cmd_nightly
  ;;
*)
  usage
  exit 1
  ;;
esac
