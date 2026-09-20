#!/usr/bin/env bash
set -euo pipefail

# Source shared infra
source .codevalid/tests/task_9533761843_20260920010807/api/_infra.sh

# Given: app is healthy
cv_step Given "wait for app health" "$LINENO"
cv_prereq "wait_for_app_health" "$LINENO"
wait_for_app_health

# When: perform GET /items/abc
cv_step When "Request GET /items/{id} with non-numeric path parameter" "$LINENO"
REQUEST_PATH="http://app:6713/items/abc"
REQUEST_HEADERS_FILE="request_headers.txt"
RESPONSE_HEADERS_FILE="response_headers.txt"

# Prepare and echo request details
REQUEST_HEADERS="Accept: application/json"
REQUEST_BODY=""  # GET request has no body
printf 'REQUEST_HEADERS: %s
' "$REQUEST_HEADERS"
printf 'REQUEST_BODY: %s
' "$REQUEST_BODY"

# Perform request, capturing headers, body, and status
curl -sS -X GET "$REQUEST_PATH" \
  -H "$REQUEST_HEADERS" \
  -D "$RESPONSE_HEADERS_FILE" \
  -o response.json \
  -w '%{http_code}' > status.txt || cv_fail "curl failed for $REQUEST_PATH" "$LINENO"

STATUS_CODE="$(cat status.txt)"
cv_http GET "$REQUEST_PATH" "$STATUS_CODE"

# Echo response headers and body
RESPONSE_HEADERS="$(cat "$RESPONSE_HEADERS_FILE")"
RESPONSE_BODY="$(cat response.json)"
printf 'RESPONSE_HEADERS:
%s
' "$RESPONSE_HEADERS"
printf 'RESPONSE_BODY:
%s
' "$RESPONSE_BODY"

# Then: assert HTTP 400 and body structure
cv_step Then "Assert HTTP 400 status for invalid non-numeric id" "$LINENO"
if [ "$STATUS_CODE" != "400" ]; then
  cv_fail "Expected HTTP 400 for non-numeric id, got $STATUS_CODE" "$LINENO"
fi

cv_prereq "Assert JSON error body for invalid non-numeric id" "$LINENO"
ERROR_VALUE="$(jq -r '.error // empty' response.json)"
if [ "$ERROR_VALUE" != "id must be a positive integer" ]; then
  cv_fail "Expected error message 'id must be a positive integer', got '${ERROR_VALUE}' in body: ${RESPONSE_BODY}" "$LINENO"
fi

KEY_COUNT="$(jq 'keys | length' response.json)"
if [ "$KEY_COUNT" != "1" ]; then
  cv_fail "Expected response JSON to contain exactly one key ('error'), got ${KEY_COUNT} keys in body: ${RESPONSE_BODY}" "$LINENO"
fi

# Cleanup / Teardown
cv_step Cleanup "No database or app state changes performed; nothing to clean up." "$LINENO"

# Success marker required by runner
echo "CODEVALID_TEST_ASSERTION_OK:non_numeric_id_in_path"
