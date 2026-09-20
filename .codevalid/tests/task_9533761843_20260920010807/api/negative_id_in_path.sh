#!/usr/bin/env bash
set -euo pipefail

# Source shared infra
source .codevalid/tests/task_9533761843_20260920010807/api/_infra.sh

# Preconditions / Given
cv_step Given "wait-for-app-health" "$LINENO"
cv_prereq "wait-for-app-health" "$LINENO"
wait_for_app_health

# When: perform GET /items/-5
cv_step When "request-negative-id-in-path: GET /items/-5 should be rejected as invalid positive integer id" "$LINENO"
REQUEST_METHOD="GET"
REQUEST_PATH="/items/-5"
FULL_URL="http://app:${PORT}/items/-5"

REQUEST_HEADERS="-X ${REQUEST_METHOD} ${FULL_URL}"
REQUEST_BODY="(no body for GET)"

echo "REQUEST_HEADERS=${REQUEST_HEADERS}"
echo "REQUEST_BODY=${REQUEST_BODY}"

# Perform HTTP request with observable headers/body
curl -sS \
  -X "${REQUEST_METHOD}" \
  -D /tmp/negative_id_in_path_headers.txt \
  -o /tmp/negative_id_in_path_body.json \
  "${FULL_URL}" || cv_fail "HTTP request to ${FULL_URL} failed" "$LINENO"

# Capture status code from response headers
STATUS_CODE="$(awk 'toupper($1) == "HTTP/1.1" { print $2 }' /tmp/negative_id_in_path_headers.txt | tail -n 1)"

# Log response for diagnosis
echo "RESPONSE_HEADERS="
cat /tmp/negative_id_in_path_headers.txt || true

echo "RESPONSE_BODY="
cat /tmp/negative_id_in_path_body.json || true

# CodeValid HTTP marker
cv_http "${REQUEST_METHOD}" "${FULL_URL}" "${STATUS_CODE}"

# Then: assertions
cv_step Then "assert-status-code-400: Negative id must return HTTP 400" "$LINENO"
if [ "${STATUS_CODE}" != "400" ]; then
  cv_fail "Expected HTTP status 400 for negative id, got ${STATUS_CODE}" "$LINENO"
fi

cv_prereq "assert-error-body-id-must-be-positive-integer: Response body must equal {\"error\":\"id must be a positive integer\"}" "$LINENO"
RESPONSE_BODY_COMPACT="$(jq -c '.' /tmp/negative_id_in_path_body.json)"
EXPECTED_BODY='{"error":"id must be a positive integer"}'

if [ "${RESPONSE_BODY_COMPACT}" != "${EXPECTED_BODY}" ]; then
  cv_fail "Expected body ${EXPECTED_BODY}, got ${RESPONSE_BODY_COMPACT}" "$LINENO"
fi

# Teardown / Cleanup
cv_step Cleanup "teardown-negative-id-in-path: No teardown needed for validation-only request" "$LINENO"

# Success marker required by runner
echo "CODEVALID_TEST_ASSERTION_OK:negative_id_in_path"
