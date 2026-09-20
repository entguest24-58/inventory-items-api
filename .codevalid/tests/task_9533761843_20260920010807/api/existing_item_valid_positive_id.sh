#!/usr/bin/env bash
set -euo pipefail

source .codevalid/tests/task_9533761843_20260920010807/api/_infra.sh

cv_step Given "wait for app health" $LINENO
# Inline health check since wait_for_app_health is not available from infra_sh
APP_HEALTH_URL="http://app:6713/health"
MAX_RETRIES=60
SLEEP_SECONDS=2

attempt=0
while (( attempt < MAX_RETRIES )); do
  attempt=$((attempt + 1))
  response="$(curl -sS -w '%{http_code}' "$APP_HEALTH_URL" || true)"
  status="${response: -3}"
  body="${response::-3}"

  if [[ "$status" == "200" && "$body" == *'"status":"ok"'* ]]; then
    break
  fi

  sleep "$SLEEP_SECONDS"
done

if (( attempt >= MAX_RETRIES )); then
  cv_fail "app did not become healthy after ${MAX_RETRIES} attempts" $LINENO
fi

cv_step Given "case mappings table" $LINENO
cat <<'TABLE'
| case_id                         | method | path       |
|---------------------------------|--------|------------|
| existing_item_valid_positive_id | GET    | /items/:id |
TABLE

cv_step Given "Mocks: none required for GET /items/:id" $LINENO
cv_prereq "no external vendor calls for GET /items/:id; skipping WireMock setup" $LINENO

cv_step Given "clean and seed items table for existing_item_valid_positive_id" $LINENO
cv_prereq "delete any existing test rows with the same SKU" $LINENO
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 <<'SQL'
-- Clean any existing test rows with the same SKU to avoid unique conflicts
DELETE FROM items WHERE sku = 'TEST-SKU-9533761843';

-- Insert a single test item row; id will be assigned by SERIAL/sequence
INSERT INTO items (name, sku, quantity, price_cents)
VALUES ('Test Widget', 'TEST-SKU-9533761843', 5, 1999);
SQL

cv_step Given "fetch seeded item id for verification" $LINENO
SEEDED_ID=$(psql "$DATABASE_URL" -t -A -q <<'SQL'
SELECT id
FROM items
WHERE sku = 'TEST-SKU-9533761843'
ORDER BY id DESC
LIMIT 1;
SQL
)

if [ -z "$SEEDED_ID" ]; then
  cv_fail "Failed to retrieve seeded item id" $LINENO
fi

cv_step When "GET /items/:id for existing seeded item" $LINENO
REQUEST_METHOD="GET"
REQUEST_PATH="/items/${SEEDED_ID}"
REQUEST_BODY=""
printf 'REQUEST_HEADERS: %s %s
' "$REQUEST_METHOD" "$REQUEST_PATH"
printf 'REQUEST_BODY: %s
' "$REQUEST_BODY"

# Perform HTTP request with curl capturing headers and body
HDR_FILE="/tmp/existing_item_valid_positive_id_headers.$$"
BODY_FILE="/tmp/existing_item_valid_positive_id_body.$$"
STATUS_FILE="/tmp/existing_item_valid_positive_id_status.$$"

curl -sS -X "$REQUEST_METHOD" "http://app:6713${REQUEST_PATH}" \
  -D "$HDR_FILE" \
  -o "$BODY_FILE" \
  -w '%{http_code}' >"$STATUS_FILE" || cv_fail "curl failed for GET ${REQUEST_PATH}" $LINENO

HTTP_STATUS="$(cat "$STATUS_FILE")"
HTTP_BODY="$(cat "$BODY_FILE")"

printf 'RESPONSE_HEADERS:
'
cat "$HDR_FILE"
printf '
RESPONSE_BODY:
%s
' "$HTTP_BODY"

cv_http "$REQUEST_METHOD" "$REQUEST_PATH"
cv_step Then "record cv_http metadata" $LINENO
cv_http "$REQUEST_METHOD" "$REQUEST_PATH"
cv_step Then "assert HTTP status via cv_http" $LINENO
cv_http "$REQUEST_METHOD" "$REQUEST_PATH"
# For diagnostics, we use cv_http to log metadata; status validation is based on curl status above.

cv_step Then "assert 200 status and exact response fields + values for existing item" $LINENO
if [ "$HTTP_STATUS" != "200" ]; then
  cv_fail "Expected HTTP 200, got $HTTP_STATUS" $LINENO
fi

IS_OBJECT=$(printf '%s' "$HTTP_BODY" | jq -r 'if type == "object" then "yes" else "no" end')
if [ "$IS_OBJECT" != "yes" ]; then
  cv_fail "Expected JSON object body for existing item, got: $HTTP_BODY" $LINENO
fi

EXPECTED_KEYS='["created_at","id","name","price_cents","quantity","sku","updated_at"]'
BODY_KEYS=$(printf '%s' "$HTTP_BODY" | jq -c 'keys | sort')
if [ "$BODY_KEYS" != "$EXPECTED_KEYS" ]; then
  cv_fail "Expected response keys $EXPECTED_KEYS, got $BODY_KEYS" $LINENO
fi

RESP_ID=$(printf '%s' "$HTTP_BODY" | jq -r '.id')
RESP_NAME=$(printf '%s' "$HTTP_BODY" | jq -r '.name')
RESP_SKU=$(printf '%s' "$HTTP_BODY" | jq -r '.sku')
RESP_QUANTITY=$(printf '%s' "$HTTP_BODY" | jq -r '.quantity')
RESP_PRICE_CENTS=$(printf '%s' "$HTTP_BODY" | jq -r '.price_cents')
RESP_CREATED_AT=$(printf '%s' "$HTTP_BODY" | jq -r '.created_at')
RESP_UPDATED_AT=$(printf '%s' "$HTTP_BODY" | jq -r '.updated_at')

if [ "$RESP_ID" != "$SEEDED_ID" ]; then
  cv_fail "Expected id=$SEEDED_ID, got $RESP_ID" $LINENO
fi

if [ "$RESP_NAME" != "Test Widget" ]; then
  cv_fail "Expected name='Test Widget', got '$RESP_NAME'" $LINENO
fi

if [ "$RESP_SKU" != "TEST-SKU-9533761843" ]; then
  cv_fail "Expected sku='TEST-SKU-9533761843', got '$RESP_SKU'" $LINENO
fi

if [ "$RESP_QUANTITY" != "5" ]; then
  cv_fail "Expected quantity=5, got $RESP_QUANTITY" $LINENO
fi

if [ "$RESP_PRICE_CENTS" != "1999" ]; then
  cv_fail "Expected price_cents=1999, got $RESP_PRICE_CENTS" $LINENO
fi

if [ -z "$RESP_CREATED_AT" ] || [ "$RESP_CREATED_AT" = "null" ]; then
  cv_fail "Expected non-empty created_at timestamp, got '$RESP_CREATED_AT'" $LINENO
fi

if [ -z "$RESP_UPDATED_AT" ] || [ "$RESP_UPDATED_AT" = "null" ]; then
  cv_fail "Expected non-empty updated_at timestamp, got '$RESP_UPDATED_AT'" $LINENO
fi

cv_step Cleanup "remove seeded item row" $LINENO
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 <<'SQL'
DELETE FROM items WHERE sku = 'TEST-SKU-9533761843';
SQL

echo "CODEVALID_TEST_ASSERTION_OK:existing_item_valid_positive_id"
