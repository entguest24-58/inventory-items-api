#!/usr/bin/env bash
set -euo pipefail

# Source shared infra for diagnosis markers and helpers
source .codevalid/tests/task_9533761843_20260920010807/api/_infra.sh

# Given: app is healthy before running the test
cv_step Given "wait for inventory API health before testing zero_id_in_path" "$LINENO"
cv_prereq "wait for inventory API health before testing zero_id_in_path" "$LINENO"
wait_for_app_health

# When: send GET /items/0
cv_step When "send GET /items/0 for zero_id_in_path" "$LINENO"
REQUEST_METHOD="GET"
REQUEST_PATH="/items/0"
REQUEST_BODY=""

# Prepare request headers/body logging
REQUEST_HEADERS_FILE="/tmp/zero_id_in_path_request_headers.$$"
RESPONSE_HEADERS_FILE="/tmp/zero_id_in_path_response_headers.$$"

{
  echo "REQUEST_METHOD=${REQUEST_METHOD}"
  echo "REQUEST_PATH=${REQUEST_PATH}"
  echo "REQUEST_BODY=${REQUEST_BODY}"
  echo "REQUEST_HEADERS:"
  # For GET with no body, minimal headers
  echo "Host: app:6713"
} >"${REQUEST_HEADERS_FILE}"

cat "${REQUEST_HEADERS_FILE}"

URL="http://app:6713${REQUEST_PATH}"

# Perform HTTP request and capture status/body
HTTP_RESPONSE="$(curl -sS -D "${RESPONSE_HEADERS_FILE}" -w '%{http_code}' -X "${REQUEST_METHOD}" "${URL}")" || cv_fail "curl failed for ${URL}" "$LINENO"
RESPONSE_STATUS="${HTTP_RESPONSE: -3}"
RESPONSE_BODY="${HTTP_RESPONSE::-3}"

# Log response headers and body
echo "RESPONSE_HEADERS:"
cat "${RESPONSE_HEADERS_FILE}"
echo "RESPONSE_BODY:"
printf '%s
' "${RESPONSE_BODY}"

# Diagnosis marker for HTTP call
cv_http "${REQUEST_METHOD}" "${URL}" "${RESPONSE_STATUS}"

# Then: assert status 400 and JSON error body
cv_step Then "assert status 400 and JSON error body for zero_id_in_path" "$LINENO"
EXPECTED_STATUS=400
if [ "${RESPONSE_STATUS}" -ne "${EXPECTED_STATUS}" ]; then
  cv_fail "expected HTTP status ${EXPECTED_STATUS} for zero_id_in_path, got ${RESPONSE_STATUS}" "$LINENO"
fi

EXPECTED_ERROR_MESSAGE='id must be a positive integer'
ACTUAL_ERROR_MESSAGE="$(printf '%s' "${RESPONSE_BODY}" | jq -r '.error')"

if [ "${ACTUAL_ERROR_MESSAGE}" != "${EXPECTED_ERROR_MESSAGE}" ]; then
  cv_fail "expected error message \"${EXPECTED_ERROR_MESSAGE}\" for zero_id_in_path, got \"${ACTUAL_ERROR_MESSAGE}\" (body: ${RESPONSE_BODY})" "$LINENO"
fi

# Cleanup / Teardown
cv_step Cleanup "no teardown required for zero_id_in_path (read-only request)" "$LINENO"

# Success marker required by runner
echo "CODEVALID_TEST_ASSERTION_OK:zero_id_in_path"
