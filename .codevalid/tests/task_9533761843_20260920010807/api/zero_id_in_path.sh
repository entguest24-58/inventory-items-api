#!/usr/bin/env bash
set -euo pipefail

# Source shared infra
source .codevalid/tests/task_9533761843_20260920010807/api/_infra.sh

# Case: zero_id_in_path

# Given / Preconditions
cv_step Given "wait_for_app_health" "$LINENO"
cv_prereq "wait_for_app_health" "$LINENO"
wait_for_app_health

# When
cv_step When "GET /items/0 with Accept: application/json" "$LINENO"

REQUEST_METHOD="GET"
REQUEST_PATH="/items/0"
REQUEST_URL="http://app:6713${REQUEST_PATH}"

REQUEST_HEADERS="Accept: application/json"
REQUEST_BODY=""

echo "REQUEST_METHOD=${REQUEST_METHOD}"
echo "REQUEST_URL=${REQUEST_URL}"
echo "REQUEST_HEADERS=${REQUEST_HEADERS}"
echo "REQUEST_BODY=${REQUEST_BODY}"

response_headers_file="/tmp/zero_id_in_path_headers.$$"

# Perform HTTP request
HTTP_RESPONSE_BODY="$(curl -sS -D "$response_headers_file" -X "$REQUEST_METHOD" -H "$REQUEST_HEADERS" "$REQUEST_URL" -w '%{http_code}')"
HTTP_STATUS="${HTTP_RESPONSE_BODY: -3}"
RESPONSE_JSON="${HTTP_RESPONSE_BODY::-3}"

# Log response headers and body
echo "RESPONSE_HEADERS:"
cat "$response_headers_file" || true
rm -f "$response_headers_file" || true

echo "RESPONSE_BODY:" 
printf '%s
' "$RESPONSE_JSON"

# Diagnosis marker for HTTP call
cv_http "$REQUEST_METHOD" "$REQUEST_URL" "$HTTP_STATUS"

# Then
cv_step Then "Assert 400 status and JSON error for zero id" "$LINENO"

EXPECTED_STATUS=400
if [ "$HTTP_STATUS" -ne "$EXPECTED_STATUS" ]; then
  cv_fail "Expected HTTP status $EXPECTED_STATUS for zero id, got $HTTP_STATUS" "$LINENO"
fi

EXPECTED_ERROR_MESSAGE="id must be a positive integer"
ACTUAL_ERROR_MESSAGE="$(printf '%s' "$RESPONSE_JSON" | jq -r '.error')"

if [ "$ACTUAL_ERROR_MESSAGE" != "$EXPECTED_ERROR_MESSAGE" ]; then
  cv_fail "Expected error message \"$EXPECTED_ERROR_MESSAGE\", got \"${ACTUAL_ERROR_MESSAGE:-<null>}\"" "$LINENO"
fi

# Ensure no extra top-level keys beyond "error"
EXPECTED_KEYS_JSON='["error"]'
ACTUAL_KEYS_JSON="$(printf '%s' "$RESPONSE_JSON" | jq -c 'keys | sort')"

if [ "$ACTUAL_KEYS_JSON" != "$EXPECTED_KEYS_JSON" ]; then
  cv_fail "Expected JSON keys $EXPECTED_KEYS_JSON, got $ACTUAL_KEYS_JSON" "$LINENO"
fi

# Teardown
cv_step Cleanup "No database changes were made by GET /items/0; nothing to clean up." "$LINENO"

# Success marker required by runner
echo "CODEVALID_TEST_ASSERTION_OK:zero_id_in_path"
