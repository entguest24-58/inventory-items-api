#!/usr/bin/env bash
set -euo pipefail

# Source shared infra
source .codevalid/tests/task_9533761843_20260920010807/api/_infra.sh

# Given / Preconditions
cv_step Given "Waiting for app health before testing negative_id_in_path" "$LINENO"
cv_prereq "Waiting for app health before testing negative_id_in_path" "$LINENO"
wait_for_app_health

# When
cv_step When "send GET /items/-5 to inventory API" "$LINENO"
REQUEST_METHOD="GET"
REQUEST_PATH="/items/-5"

# Prepare request observability
REQUEST_HEADERS="Content-Type: application/json"
REQUEST_BODY=""

printf 'REQUEST_HEADERS: %s
' "$REQUEST_HEADERS"
printf 'REQUEST_BODY: %s
' "$REQUEST_BODY"

# Perform HTTP call with header capture
TMP_HDR_FILE="/tmp/negative_id_in_path_headers.$$"
HTTP_URL="http://app:6713${REQUEST_PATH}"

# Build curl arguments (no body for GET)
curl -sS -D "$TMP_HDR_FILE" -X "$REQUEST_METHOD" -w '%{http_code}' "$HTTP_URL" > /tmp/negative_id_in_path_body_and_status.$$ || cv_fail "curl failed for $HTTP_URL" "$LINENO"

# Extract status and body
RAW_RESPONSE="$(cat /tmp/negative_id_in_path_body_and_status.$$)"
ACTUAL_STATUS="${RAW_RESPONSE: -3}"
ACTUAL_BODY="${RAW_RESPONSE::-3}"

# Echo response observability
printf 'RESPONSE_HEADERS:
'
cat "$TMP_HDR_FILE"
printf 'RESPONSE_BODY:
%s
' "$ACTUAL_BODY"

# Diagnosis marker for HTTP
cv_http "$REQUEST_METHOD" "$HTTP_URL" "$ACTUAL_STATUS"

# Then
cv_step Then "assert HTTP 400 and JSON error body for invalid negative id" "$LINENO"
EXPECTED_STATUS=400
EXPECTED_ERROR_MESSAGE="id must be a positive integer"

if [ "$ACTUAL_STATUS" -ne "$EXPECTED_STATUS" ]; then
  cv_fail "Expected status $EXPECTED_STATUS for negative_id_in_path, got $ACTUAL_STATUS" "$LINENO"
fi

ACTUAL_ERROR_MESSAGE="$(printf '%s' "$ACTUAL_BODY" | jq -r '.error // empty')"

if [ "$ACTUAL_ERROR_MESSAGE" != "$EXPECTED_ERROR_MESSAGE" ]; then
  cv_fail "Expected error message '$EXPECTED_ERROR_MESSAGE' for negative_id_in_path, got '$ACTUAL_ERROR_MESSAGE' (body: $ACTUAL_BODY)" "$LINENO"
fi

# Teardown
cv_step Cleanup "no database changes made in negative_id_in_path; nothing to clean up." "$LINENO"

# Success marker for runner
echo "CODEVALID_TEST_ASSERTION_OK:negative_id_in_path"
