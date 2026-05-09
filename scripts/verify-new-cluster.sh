#!/bin/bash
set -euo pipefail

NEW_DATA_DIR="/var/lib/postgresql/16/main"
NEW_BIN="/usr/lib/postgresql/16/bin"
PSQL="${NEW_BIN}/psql"

echo "==> Starting PostgreSQL 16"
"${NEW_BIN}/pg_ctl" -D "${NEW_DATA_DIR}" -l "${NEW_DATA_DIR}/pg.log" start -w

# Allow local connections without password (pg_upgrade carries over pg_hba.conf
# from the old cluster, which already has trust entries, but add them defensively)
if ! grep -q "127.0.0.1/32 trust" "${NEW_DATA_DIR}/pg_hba.conf"; then
  echo "host all all 127.0.0.1/32 trust" >> "${NEW_DATA_DIR}/pg_hba.conf"
  echo "host all all ::1/128 trust"       >> "${NEW_DATA_DIR}/pg_hba.conf"
  "${NEW_BIN}/pg_ctl" -D "${NEW_DATA_DIR}" reload
fi

pass() { echo "  [PASS] $1"; }
fail() { echo "  [FAIL] $1"; "${NEW_BIN}/pg_ctl" -D "${NEW_DATA_DIR}" stop -m fast; exit 1; }

run_sql() {
  local db="$1"
  local sql="$2"
  "${PSQL}" -U postgres -d "${db}" -tAc "${sql}"
}

echo ""
echo "==> Verifying databases exist"
for db in testdb analytics; do
  result=$(run_sql postgres "SELECT 1 FROM pg_database WHERE datname = '${db}';")
  [ "${result}" = "1" ] && pass "Database '${db}' exists" || fail "Database '${db}' missing"
done

echo ""
echo "==> Verifying testdb tables and row counts"

user_count=$(run_sql testdb "SELECT COUNT(*) FROM users;")
[ "${user_count}" -ge 3 ] && pass "users table has ${user_count} rows" || fail "users table has unexpected count: ${user_count}"

order_count=$(run_sql testdb "SELECT COUNT(*) FROM orders;")
[ "${order_count}" -ge 4 ] && pass "orders table has ${order_count} rows" || fail "orders table has unexpected count: ${order_count}"

echo ""
echo "==> Verifying testdb view"
view_count=$(run_sql testdb "SELECT COUNT(*) FROM active_orders;")
[ "${view_count}" -ge 1 ] && pass "active_orders view returns ${view_count} rows" || fail "active_orders view returned 0 rows"

echo ""
echo "==> Verifying testdb sequence"
seq_val=$(run_sql testdb "SELECT nextval('invoice_seq');")
[ "${seq_val}" -ge 1000 ] && pass "invoice_seq value is ${seq_val}" || fail "invoice_seq value unexpected: ${seq_val}"

echo ""
echo "==> Verifying testdb indexes"
idx_count=$(run_sql testdb "SELECT COUNT(*) FROM pg_indexes WHERE tablename = 'orders' AND indexname LIKE 'idx_%';")
[ "${idx_count}" -ge 2 ] && pass "orders table has ${idx_count} custom indexes" || fail "orders indexes missing (found ${idx_count})"

echo ""
echo "==> Verifying analytics events table"
evt_count=$(run_sql analytics "SELECT COUNT(*) FROM events;")
[ "${evt_count}" -ge 5 ] && pass "events table has ${evt_count} rows" || fail "events table has unexpected count: ${evt_count}"

echo ""
echo "==> Verifying analytics materialized view"
mv_count=$(run_sql analytics "SELECT COUNT(*) FROM daily_event_counts;")
[ "${mv_count}" -ge 1 ] && pass "daily_event_counts materialized view has ${mv_count} rows" || fail "daily_event_counts materialized view is empty"

echo ""
echo "==> Verifying foreign key constraint is intact"
fk_count=$(run_sql testdb "SELECT COUNT(*) FROM information_schema.table_constraints WHERE constraint_type = 'FOREIGN KEY' AND table_name = 'orders';")
[ "${fk_count}" -ge 1 ] && pass "orders foreign key constraint present" || fail "orders foreign key constraint missing"

echo ""
"${NEW_BIN}/pg_ctl" -D "${NEW_DATA_DIR}" stop -m fast
echo "==> All verification checks passed. PostgreSQL 16 upgrade is healthy."
