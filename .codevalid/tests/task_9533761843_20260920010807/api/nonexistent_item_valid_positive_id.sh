#!/usr/bin/env bash
set -euo pipefail

source .codevalid/tests/task_9533761843_20260920010807/api/_infra.sh

cv_step Given "Starting test script for GET /items/{id} — nonexistent_item_valid_positive_id" $LINENO

cv_step Given "Ensuring app health before running test cases" $LINENO
wait_for_app_health

cv_prereq "Case nonexistent_item_valid_positive_id: ensure items table is present and clean up any existing test rows" $LINENO

psql "$DATABASE_URL" -v ON_ERROR_STOP=1 <<'SQL'
-- Clean up any prior test data for predictable state
DELETE FROM items WHERE sku LIKE 'TEST-NONEXISTENT-%';

-- Insert a single known item with id=1 so we can choose a different non-existent id
INSERT INTO items (id, name, sku, quantity, price_cents, created_at, updated_at)
VALUES (
  1,
  'Test Item Existing',
  'TEST-NONEXISTENT-EXISTING',
  10,
  1999,
  NOW(),
  NOW()
);
SQL

cv_step When "Case nonexistent_item_valid_positive_id: perform GET /items/9999 with a valid positive integer id that does not exist" $LINENO

NONEXISTENT_ID=9999

REQUEST_METHOD="GET"
REQUEST_PATH="/items/${NONEXISTENT_ID}"
REQUEST_URL="http://app:6713${REQUEST_PATH}"

cv_step When "Preparing HTTP request" $LINENO
REQUEST_HEADERS_FILE="/tmp/request_headers_${NONEXISTENT_ID}.txt"
REQUEST_BODY_FILE="/tmp/request_body_${NONEXISTENT_ID}.txt"
RESPONSE_HEADERS_FILE="/tmp/response_headers_${NONEXISTENT_ID}.txt"

# For GET with no body, just document that the request body is empty
: > "$REQUEST_BODY_FILE"

cv_step When "Request headers (synthetic for logging)" $LINENO
printf 'REQUEST_METHOD=%s
REQUEST_URL=%s
' "$REQUEST_METHOD" "$REQUEST_URL" | tee "$REQUEST_HEADERS_FILE"

cv_step When "Executing curl for GET /items/${NONEXISTENT_ID}" $LINENO

# Perform the HTTP request, capturing headers, body, and status
HTTP_RESPONSE_BODY_AND_STATUS=$(curl -sS -D "$RESPONSE_HEADERS_FILE" -w '%{http_code}' "$REQUEST_URL") || cv_fail "curl failed for $REQUEST_URL" $LINENO
HTTP_STATUS="${HTTP_RESPONSE_BODY_AND_STATUS: -3}"
HTTP_BODY="${HTTP_RESPONSE_BODY_AND_STATUS::-3}"

cv_step When "Captured response headers" $LINENO
cat "$RESPONSE_HEADERS_FILE"

cv_step When "Captured response body" $LINENO
printf '%s
' "$HTTP_BODY"

# Log via CodeValid HTTP marker
cv_http "$REQUEST_METHOD" "$REQUEST_URL" "$HTTP_STATUS"

cv_step Then "Case nonexistent_item_valid_positive_id: assert current behavior for missing item — success path with null JSON body" $LINENO

EXPECTED_STATUS=200

# Assert status code matches the implemented behavior for a valid, non-existent id
if [ "$HTTP_STATUS" -ne "$EXPECTED_STATUS" ]; then
  cv_fail "Expected HTTP status ${EXPECTED_STATUS} for non-existent item id, but got ${HTTP_STATUS}" $LINENO
fi

# Assert JSON body is exactly null (missing items reported as null on the success path)
ACTUAL_RAW_BODY="${HTTP_BODY}"
ACTUAL_JQ_TYPE=$(printf '%s' "${HTTP_BODY}" | jq -r 'type')

if [ "${ACTUAL_RAW_BODY}" != "null" ] || [ "${ACTUAL_JQ_TYPE}" != "null" ]; then
  cv_fail "Expected JSON body to be null for non-existent item id, but got raw=\"${ACTUAL_RAW_BODY}\", jq type=\"${ACTUAL_JQ_TYPE}\"" $LINENO
fi

cv_step Then "Case nonexistent_item_valid_positive_id: assertions passed for 200 status with null JSON body on missing item" $LINENO

cv_step Cleanup "Case nonexistent_item_valid_positive_id: teardown — remove seeded test items" $LINENO

psql "$DATABASE_URL" -v ON_ERROR_STOP=1 <<'SQL'
DELETE FROM items WHERE sku LIKE 'TEST-NONEXISTENT-%';
SQL

cv_step Cleanup "Case nonexistent_item_valid_positive_id: teardown complete" $LINENO

# Success marker required by the runner
echo "CODEVALID_TEST_ASSERTION_OK:nonexistent_item_valid_positive_id"
