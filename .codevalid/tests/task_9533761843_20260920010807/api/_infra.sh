#!/usr/bin/env bash
set -euo pipefail

# Shared environment variables
export DATABASE_URL="${DATABASE_URL:-postgresql://app:app@toxiproxy:5432/appdb}"

# Logging helpers
cv_step() {
  local message="${1:-}"
  printf '[cv_step] %s\n' "$message"
}

cv_prereq() {
  local message="${1:-}"
  printf '[cv_prereq] %s\n' "$message"
}

cv_fail() {
  local message="${1:-}"
  printf '[cv_fail] %s\n' "$message" >&2
  exit 1
}

# HTTP helper: performs a request against the app service and captures status/body.
# Usage:
#   cv_http METHOD PATH [DATA]
# Sets:
#   CV_HTTP_STATUS  - HTTP status code
#   CV_HTTP_BODY    - response body
cv_http() {
  local method="${1:-GET}"
  local path="${2:-/}"
  local data="${3:-}"

  local url="http://app:6713${path}"

  local curl_args=(
    -sS
    -X "$method"
    -w '%{http_code}'
    "$url"
  )

  if [[ -n "$data" ]]; then
    curl_args+=(-H 'Content-Type: application/json' --data "$data")
  fi

  local response
  response="$(curl "${curl_args[@]}")" || cv_fail "cv_http: curl failed for $url"

  CV_HTTP_STATUS="${response: -3}"
  CV_HTTP_BODY="${response::-3}"
}

# Wait for app health endpoint to report ok
wait_for_app_health() {
  local url="http://app:6713/health"
  local max_retries="${1:-60}"
  local sleep_seconds="${2:-2}"

  cv_step "Waiting for app health at ${url} (max_retries=${max_retries}, sleep=${sleep_seconds}s)"

  local attempt=0
  while (( attempt < max_retries )); do
    attempt=$((attempt + 1))
    local response
    local status

    response="$(curl -sS -w '%{http_code}' "$url" || true)"
    status="${response: -3}"
    local body="${response::-3}"

    if [[ "$status" == "200" && "$body" == *'"status":"ok"'* ]]; then
      cv_step "App health is OK after ${attempt} attempts"
      return 0
    fi

    sleep "$sleep_seconds"
  done

  cv_fail "wait_for_app_health: app did not become healthy after ${max_retries} attempts"
}

# --- CodeValid diagnosis markers (parsed by the test runner; do not edit) ---
# cv_step  <Given|When|Then|Cleanup> "<what this section does>" $LINENO
# cv_prereq "<setup being done>" $LINENO
# cv_http  <METHOD> <url> <http_status>          (after every curl)
# cv_fail  "<expected X got Y>" $LINENO           (prints marker, exits 1)
cv_step() { printf 'CV_STEP|%s|%s|line=%s\n' "${1:-}" "${2:-}" "${3:-}"; }
cv_prereq() { printf 'CV_PREREQ|%s|line=%s\n' "$1" "${2:-}"; }
cv_http() { printf 'CV_HTTP|%s|%s|%s\n' "$1" "$2" "${3:-}"; }
cv_fail() { printf 'CV_ASSERT_FAIL|%s|line=%s\n' "$1" "${2:-}"; exit 1; }
# --- end CodeValid diagnosis markers ---
