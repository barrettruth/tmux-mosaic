#!/usr/bin/env bash

set -euo pipefail

usage() {
  printf '%s\n' "usage: $0 <remove-question-label|request-review|release-metadata>" >&2
}

die() {
  printf 'forgejo automation: %s\n' "$*" >&2
  exit 1
}

truthy() {
  case "${1:-}" in
  true | TRUE | 1 | yes | YES | y | Y) return 0 ;;
  *) return 1 ;;
  esac
}

api_url="${FORGEJO_API_URL:-${GITHUB_API_URL:-}}"
repository="${FORGEJO_REPOSITORY:-${GITHUB_REPOSITORY:-}}"
token="${FORGEJO_TOKEN:-${GITHUB_TOKEN:-}}"
event_path="${FORGEJO_EVENT_PATH:-${GITHUB_EVENT_PATH:-}}"

require_api_context() {
  [ -n "$api_url" ] || die "FORGEJO_API_URL is required"
  [ -n "$repository" ] || die "FORGEJO_REPOSITORY is required"
  [ -n "$token" ] || die "FORGEJO_TOKEN is required"
}

require_event_or_override() {
  [ -n "$event_path" ] || [ -n "${ISSUE_NUMBER:-}" ] || [ -n "${PULL_NUMBER:-}" ] ||
    die "FORGEJO_EVENT_PATH or an explicit ISSUE_NUMBER/PULL_NUMBER override is required"
  if [ -n "$event_path" ] && [ ! -f "$event_path" ]; then
    die "event file does not exist: $event_path"
  fi
}

event_value() {
  local query="$1"
  if [ -n "$event_path" ] && [ -f "$event_path" ]; then
    jq -r "$query // empty" "$event_path"
  fi
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

uri_encode() {
  jq -rn --arg value "$1" '$value | @uri'
}

remove_question_label() {
  local label="${QUESTION_LABEL:-question}"
  local skip_login="${SKIP_LOGIN:-barrettruth}"
  local sender="${SENDER_LOGIN:-}"
  local issue_number="${ISSUE_NUMBER:-}"
  local encoded_label output status

  require_event_or_override
  sender="${sender:-$(event_value '.sender.login')}"
  issue_number="${issue_number:-$(event_value '.issue.number')}"
  [ -n "$issue_number" ] || die "issue number could not be determined"

  if [ "$sender" = "$skip_login" ] && ! truthy "${FORCE:-}"; then
    printf 'Skipping issue #%s because sender is %s.\n' "$issue_number" "$sender"
    return
  fi

  if truthy "${DRY_RUN:-}"; then
    printf 'Would remove label %s from issue #%s in %s.\n' "$label" "$issue_number" "$repository"
    return
  fi

  require_api_context
  encoded_label="$(uri_encode "$label")"
  output="$(mktemp)"
  status="$(api_capture DELETE "repos/$repository/issues/$issue_number/labels/$encoded_label" "$output")"
  case "$status" in
  204)
    printf 'Removed label %s from issue #%s.\n' "$label" "$issue_number"
    ;;
  404)
    printf 'Label %s was not present on issue #%s, or issue was not found.\n' "$label" "$issue_number"
    ;;
  *)
    cat "$output" >&2 || true
    rm -f "$output"
    die "DELETE issue label returned HTTP $status"
    ;;
  esac
  rm -f "$output"
}

request_review() {
  local reviewer="${REVIEWER_LOGIN:-barrettruth}"
  local skip_login="${SKIP_LOGIN:-barrettruth}"
  local sender="${SENDER_LOGIN:-}"
  local pull_number="${PULL_NUMBER:-}"
  local payload output status message

  require_event_or_override
  sender="${sender:-$(event_value '.sender.login')}"
  pull_number="${pull_number:-$(event_value '.pull_request.number')}"
  [ -n "$pull_number" ] || die "pull request number could not be determined"

  if [ "$sender" = "$skip_login" ] && ! truthy "${FORCE:-}"; then
    printf 'Skipping PR #%s because sender is %s.\n' "$pull_number" "$sender"
    return
  fi

  if truthy "${DRY_RUN:-}"; then
    printf 'Would request review from %s on PR #%s in %s.\n' "$reviewer" "$pull_number" "$repository"
    return
  fi

  require_api_context
  payload="$(mktemp)"
  jq -n --arg reviewer "$reviewer" '{reviewers: [$reviewer], team_reviewers: []}' >"$payload"
  output="$(mktemp)"
  status="$(api_capture POST "repos/$repository/pulls/$pull_number/requested_reviewers" "$output" "$payload")"
  case "$status" in
  200 | 201 | 204)
    printf 'Requested review from %s on PR #%s.\n' "$reviewer" "$pull_number"
    ;;
  422)
    message="$(jq -r '.message // ""' "$output" 2>/dev/null || true)"
    if [[ "$message" == *already* ]]; then
      printf 'Review from %s was already requested on PR #%s.\n' "$reviewer" "$pull_number"
    else
      cat "$output" >&2 || true
      rm -f "$payload" "$output"
      die "review request validation failed: $message"
    fi
    ;;
  *)
    cat "$output" >&2 || true
    rm -f "$payload" "$output"
    die "POST requested reviewers returned HTTP $status"
    ;;
  esac
  rm -f "$payload" "$output"
}

ensure_label() {
  local name="$1" color="$2" description="$3" encoded output status payload
  encoded="$(uri_encode "$name")"
  output="$(mktemp)"
  status="$(api_capture GET "repos/$repository/labels/$encoded" "$output")"
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

extract_release_refs() {
  python3 -c '
import re
import sys

body = sys.stdin.read()
pattern = re.compile(
    r"(?:close[sd]?|fix(?:e[sd])?|resolve[sd]?)\s+"
    r"(?:(?P<owner>[A-Za-z0-9_.-]+)/(?P<repo>[A-Za-z0-9_.-]+))?#(?P<number>\d+)",
    re.IGNORECASE,
)
seen = set()
for match in pattern.finditer(body):
    owner = match.group("owner")
    repo = match.group("repo")
    if owner and repo and f"{owner}/{repo}" != sys.argv[1]:
        continue
    number = match.group("number")
    if number not in seen:
        print(number)
        seen.add(number)
' "$repository"
}

release_metadata() {
  local pull_number="${PULL_NUMBER:-}"
  local body="${PULL_BODY:-}"
  local pr_json issue_json payload
  local current selected refs labels to_add
  local label

  require_event_or_override
  require_api_context
  pull_number="${pull_number:-$(event_value '.pull_request.number')}"
  [ -n "$pull_number" ] || die "pull request number could not be determined"

  ensure_label "breaking-change" "b60205" "Change that breaks documented user-facing behavior"
  ensure_label "skip-release-notes" "cfd3d7" "Exclude from generated release notes"

  pr_json="$(api_required GET "repos/$repository/pulls/$pull_number" "200")"
  if [ -z "$body" ]; then
    body="$(jq -r '.body // ""' <<<"$pr_json")"
  fi
  current="$(jq -r '.labels[]?.name' <<<"$pr_json" | sort -u)"
  refs="$(extract_release_refs <<<"$body")"
  labels="$(
    while IFS= read -r ref; do
      [ -n "$ref" ] || continue
      issue_json="$(api_required GET "repos/$repository/issues/$ref" "200 404" || true)"
      [ -n "$issue_json" ] || continue
      jq -r '.labels[]?.name' <<<"$issue_json"
    done <<<"$refs" |
      { grep -Ex 'breaking-change|enhancement|bug|documentation' || true; } |
      sort -u
  )"
  to_add="$(comm -13 <(printf '%s\n' "$current" | sort -u) <(printf '%s\n' "$labels" | sort -u) | sed '/^$/d')"

  if [ -n "$to_add" ]; then
    if truthy "${DRY_RUN:-}"; then
      printf 'Would add release metadata labels to PR #%s: %s\n' "$pull_number" "$(paste -sd, - <<<"$to_add")"
    else
      payload="$(mktemp)"
      jq -Rn '{labels: [inputs | select(length > 0)]}' <<<"$to_add" >"$payload"
      api_required POST "repos/$repository/issues/$pull_number/labels" "200 201" "$payload" >/dev/null
      rm -f "$payload"
      printf 'Added release metadata labels to PR #%s: %s\n' "$pull_number" "$(paste -sd, - <<<"$to_add")"
    fi
  else
    printf 'No release metadata labels to add to PR #%s.\n' "$pull_number"
  fi

  selected="$(
    {
      printf '%s\n' "$current"
      printf '%s\n' "$to_add"
    } |
      { grep -Ex 'breaking-change|enhancement|bug|documentation' || true; } |
      sort -u
  )"
  if grep -qx 'skip-release-notes' <<<"$current" && [ -n "$selected" ]; then
    die "skip-release-notes cannot be combined with a release category label"
  fi
  if [ "$(sed '/^$/d' <<<"$selected" | wc -l)" -gt 1 ]; then
    die "pull request has multiple release category labels: $(paste -sd, - <<<"$selected")"
  fi

  for label in $selected; do
    printf 'Selected release metadata label for PR #%s: %s\n' "$pull_number" "$label"
  done
}

cmd="${1:-}"
case "$cmd" in
remove-question-label)
  remove_question_label
  ;;
request-review)
  request_review
  ;;
release-metadata)
  release_metadata
  ;;
*)
  usage
  exit 1
  ;;
esac
