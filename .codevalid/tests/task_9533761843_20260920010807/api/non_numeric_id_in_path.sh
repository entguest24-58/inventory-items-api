#!/usr/bin/env bash
set -euo pipefail

# Source shared infra (diagnostic markers, helpers)
source .codevalid/tests/task_9533761843_20260920010807/api/_infra.sh

# Case: non_numeric_id_in_path

# Given / Preconditions
cv_step Given "wait for app health on GET /health" "$LINENO"
cv_prereq "wait for app health on GET /health" "$LINENO"
wait_for_app_health

# When: send GET /items/abc with non-numeric id path parameter
cv_step When "send GET /items/abc with non-numeric id path parameter" "$LINENO"

METHOD="GET"
REQUEST_PATH="/items/abc"
URL="http://app:6713${REQUEST_PATH}"

REQUEST_BODY=""  # GET has no body

echo "REQUEST_HEADERS: Accept: application/json"
echo "REQUEST_BODY: ${REQUEST_BODY}"

# Perform HTTP request and capture headers/body/status
HDR_FILE="/tmp/cv_http_headers_$$.txt"
RESP_FILE="/tmp/cv_http_body_$$.txt"

# Build curl command
curl -sS \
  -D "$HDR_FILE" \
  -o "$RESP_FILE" \
  -w '%{http_code}' \
  -H 'Accept: application/json' \
  -X "$METHOD" \
  "$URL" > /tmp/cv_http_status_$$.txt

STATUS_CODE="$(cat /tmp/cv_http_status_$$.txt)"
RESPONSE_BODY="$(cat "$RESP_FILE")"

# Echo response for observability
echo "RESPONSE_HEADERS:"
cat "$HDR_FILE"
echo "RESPONSE_BODY:"
cat "$RESP_FILE"

# Diagnosis marker for HTTP call
cv_http "$METHOD" "$URL" "$STATUS_CODE"

# Then: assertions
cv_step Then "assert status 400 and error body for non-numeric id" "$LINENO"

BODY_JSON="$RESPONSE_BODY"

if [ "$STATUS_CODE" -ne 400 ]; then
  cv_fail "expected HTTP 400 for non-numeric id, got $STATUS_CODE" "$LINENO"
fi

ERROR_VALUE="$(echo "$BODY_JSON" | jq -r '.error // empty')"
if [ "$ERROR_VALUE" != "id must be a positive integer" ]; then
  cv_fail "expected error message 'id must be a positive integer', got '${ERROR_VALUE}' (body: $BODY_JSON)" "$LINENO"
fi

KEYS="$(echo "$BODY_JSON" | jq -r 'keys | sort | join(",")')"
if [ "$KEYS" != "error" ]; then
  cv_fail "expected response JSON to contain exactly key 'error', got keys '${KEYS}' (body: $BODY_JSON)" "$LINENO"
fi

# Teardown
cv_step Cleanup "no teardown required for non-numeric id case; no DB changes were made" "$LINENO"

# Success marker required by runner
echo "CODEVALID_TEST_ASSERTION_OK:non_numeric_id_in_path"
