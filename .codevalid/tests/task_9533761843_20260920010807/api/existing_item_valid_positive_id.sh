#!/usr/bin/env bash
set -euo pipefail

source .codevalid/tests/task_9533761843_20260920010807/api/_infra.sh

cv_step Given "Mocks: No third-party vendors; no WireMock stubs required for GET /items/{id}." $LINENO

cv_prereq "Preconditions: wait for app health" $LINENO
cv_prereq "wait_for_app_health" $LINENO
wait_for_app_health || cv_fail "App health check did not succeed" $LINENO

cv_prereq "seed_item_row: Insert a known item into the items table for lookup" $LINENO

# Use a deterministic SKU to avoid collisions and make cleanup straightforward.
TEST_SKU="TEST-ITEM-9533761843"
TEST_NAME="Existing item for valid positive ID lookup"
TEST_QUANTITY=42
TEST_PRICE_CENTS=999

# Clean up any existing rows with the same test SKU to ensure a single known record.
cv_prereq "delete any pre-existing test item rows" $LINENO
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 <<'SQL' || cv_fail "Failed to clean up existing test items" $LINENO
DELETE FROM items WHERE sku = 'TEST-ITEM-9533761843';
SQL

# Insert the test item, letting Postgres assign id, created_at, and updated_at.
cv_prereq "insert test item row" $LINENO
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 <<'SQL' || cv_fail "Failed to insert test item" $LINENO
INSERT INTO items (name, sku, quantity, price_cents)
VALUES ('Existing item for valid positive ID lookup', 'TEST-ITEM-9533761843', 42, 999);
SQL

cv_prereq "fetch_seeded_item_id: Retrieve the id of the inserted test item" $LINENO
ITEM_ID_JSON="$(psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -At <<'SQL'
SELECT id
FROM items
WHERE sku = 'TEST-ITEM-9533761843'
ORDER BY id DESC
LIMIT 1;
SQL
)" || cv_fail "Failed to query test item id" $LINENO

# ITEM_ID_JSON is a plain integer line; validate it is a positive integer.
if ! printf '%s
' "$ITEM_ID_JSON" | grep -Eq '^[1-9][0-9]*$'; then
  cv_fail "Seeded item id is not a positive integer: $ITEM_ID_JSON" $LINENO
fi

ITEM_ID="$ITEM_ID_JSON"

cv_prereq "record_expected_values: Capture expected fields for the seeded item" $LINENO
EXPECTED_NAME="$TEST_NAME"
EXPECTED_SKU="$TEST_SKU"
EXPECTED_QUANTITY="$TEST_QUANTITY"
EXPECTED_PRICE_CENTS="$TEST_PRICE_CENTS"

cv_step When "http_get_item: GET /items/{id} for the seeded item" $LINENO
REQUEST_METHOD="GET"
REQUEST_PATH="/items/${ITEM_ID}"

# Prepare request diagnostics
REQUEST_HEADERS=(-H "Accept: application/json")
REQUEST_BODY=""

printf 'REQUEST_METHOD=%s
' "$REQUEST_METHOD"
printf 'REQUEST_PATH=%s
' "$REQUEST_PATH"
printf 'REQUEST_HEADERS=%s
' "${REQUEST_HEADERS[*]}"
printf 'REQUEST_BODY=%s
' "$REQUEST_BODY"

# Perform the HTTP request, capturing headers and body
RESPONSE_HEADERS_FILE="/tmp/response_headers_${ITEM_ID}.txt"
RESPONSE_BODY_FILE="/tmp/response_body_${ITEM_ID}.txt"

HTTP_STATUS="$(curl -sS -o "$RESPONSE_BODY_FILE" -D "$RESPONSE_HEADERS_FILE" -w '%{http_code}' "http://app:6713${REQUEST_PATH}" "${REQUEST_HEADERS[@]}" || true)"

printf 'RESPONSE_STATUS=%s
' "$HTTP_STATUS"
printf 'RESPONSE_HEADERS:
'
cat "$RESPONSE_HEADERS_FILE" || true
printf 'RESPONSE_BODY:
'
cat "$RESPONSE_BODY_FILE" || true

# Emit diagnosis marker for the HTTP call
cv_http "$REQUEST_METHOD" "$REQUEST_PATH" "$HTTP_STATUS" $LINENO

cv_step Then "assert_response_for_existing_item" $LINENO

# Assert HTTP status code is 200
if [ "$HTTP_STATUS" != "200" ]; then
  cv_fail "expected HTTP 200 got $HTTP_STATUS" $LINENO
fi

# Parse JSON body
if ! command -v jq >/dev/null 2>&1; then
  cv_fail "jq is required to parse JSON response" $LINENO
fi

RESPONSE_BODY_JSON="$(cat "$RESPONSE_BODY_FILE")"

ITEM_ID_FIELD="$(printf '%s' "$RESPONSE_BODY_JSON" | jq -r '.id' 2>/dev/null || printf 'null')"
NAME_FIELD="$(printf '%s' "$RESPONSE_BODY_JSON" | jq -r '.name' 2>/dev/null || printf 'null')"
SKU_FIELD="$(printf '%s' "$RESPONSE_BODY_JSON" | jq -r '.sku' 2>/dev/null || printf 'null')"
QUANTITY_FIELD="$(printf '%s' "$RESPONSE_BODY_JSON" | jq -r '.quantity' 2>/dev/null || printf 'null')"
PRICE_CENTS_FIELD="$(printf '%s' "$RESPONSE_BODY_JSON" | jq -r '.price_cents' 2>/dev/null || printf 'null')"

# Assert that id is a positive integer and matches the seeded id
if ! printf '%s
' "$ITEM_ID_FIELD" | grep -Eq '^[1-9][0-9]*$'; then
  cv_fail "response id is not a positive integer: $ITEM_ID_FIELD" $LINENO
fi
if [ "$ITEM_ID_FIELD" != "$ITEM_ID" ]; then
  cv_fail "expected response id $ITEM_ID got $ITEM_ID_FIELD" $LINENO
fi

# Assert name, sku, quantity, and price_cents match expected values
if [ "$NAME_FIELD" != "$EXPECTED_NAME" ]; then
  cv_fail "expected name $EXPECTED_NAME got $NAME_FIELD" $LINENO
fi
if [ "$SKU_FIELD" != "$EXPECTED_SKU" ]; then
  cv_fail "expected sku $EXPECTED_SKU got $SKU_FIELD" $LINENO
fi
if [ "$QUANTITY_FIELD" != "$EXPECTED_QUANTITY" ]; then
  cv_fail "expected quantity $EXPECTED_QUANTITY got $QUANTITY_FIELD" $LINENO
fi
if [ "$PRICE_CENTS_FIELD" != "$EXPECTED_PRICE_CENTS" ]; then
  cv_fail "expected price_cents $EXPECTED_PRICE_CENTS got $PRICE_CENTS_FIELD" $LINENO
fi

cv_step Cleanup "teardown: Remove seeded test item from items table" $LINENO
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 <<'SQL' || cv_fail "Failed to delete seeded test item during teardown" $LINENO
DELETE FROM items WHERE sku = 'TEST-ITEM-9533761843';
SQL

# Success marker required by runner
echo "CODEVALID_TEST_ASSERTION_OK:existing_item_valid_positive_id"
