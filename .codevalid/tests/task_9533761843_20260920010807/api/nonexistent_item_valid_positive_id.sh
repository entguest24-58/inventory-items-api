#!/usr/bin/env bash
set -euo pipefail

# Source shared infra
source .codevalid/tests/task_9533761843_20260920010807/api/_infra.sh

# -------------------------------
# Given: Preconditions
# -------------------------------
cv_step Given "preconditions for nonexistent_item_valid_positive_id" $LINENO

cv_prereq "Wait for app health" $LINENO
wait_for_app_health

cv_prereq "Ensure no item exists with id = 9999" $LINENO
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 <<'SQL'
DELETE FROM items WHERE id = 9999;
SQL

# -------------------------------
# When: Perform request
# -------------------------------
cv_step When "Request non-existent item with valid positive integer ID" $LINENO

REQUEST_HEADERS="GET /items/9999"
REQUEST_BODY=""
echo "REQUEST_HEADERS: $REQUEST_HEADERS"
echo "REQUEST_BODY: $REQUEST_BODY"

# Perform HTTP request via diagnostic helper (for marker), then real curl to capture status/body
cv_http GET "/items/9999" "/items/9999"

# Real HTTP request to app
URL="http://app:6713/items/9999"
response="$(curl -sS -w '%{http_code}' "$URL" || cv_fail "curl failed for $URL" $LINENO)"
HTTP_STATUS="${response: -3}"
HTTP_BODY="${response::-3}"

# cv_http in diagnostic infra only exposes markers, so we log what we have
RESPONSE_HEADERS="(headers not captured by cv_http helper)"
echo "RESPONSE_HEADERS: $RESPONSE_HEADERS"
echo "RESPONSE_BODY: $HTTP_BODY"

# -------------------------------
# Then: Assertions
# -------------------------------
cv_step Then "Assert HTTP 200 and JSON null body with no extra fields" $LINENO

if [ "$HTTP_STATUS" -ne 200 ]; then
  cv_fail "Expected HTTP 200 for non-existent item, got $HTTP_STATUS. Body: $HTTP_BODY" $LINENO
fi

IS_NULL=$(printf '%s\n' "$HTTP_BODY" | jq -r 'if . == null then "yes" else "no" end' 2>/dev/null || echo "no")
KEY_COUNT=$(printf '%s\n' "$HTTP_BODY" | jq 'if . == null then 0 else (keys | length) end' 2>/dev/null || echo "0")

if [ "$IS_NULL" != "yes" ]; then
  cv_fail "Expected response body to be JSON null for non-existent item, got: $HTTP_BODY" $LINENO
fi

if [ "$KEY_COUNT" -ne 0 ]; then
  cv_fail "Expected no fields in response when body is null, found $KEY_COUNT. Body: $HTTP_BODY" $LINENO
fi

# -------------------------------
# Cleanup / Teardown
# -------------------------------
cv_step Cleanup "No persistent changes created by this case; no teardown SQL required." $LINENO

echo "CODEVALID_TEST_ASSERTION_OK:nonexistent_item_valid_positive_id"
