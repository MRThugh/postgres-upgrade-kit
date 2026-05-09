#!/bin/bash
set -euo pipefail

OLD_PG_VERSION="${OLD_PG_VERSION:?OLD_PG_VERSION env var must be set}"
NEW_PG_VERSION="${NEW_PG_VERSION:?NEW_PG_VERSION env var must be set}"
OLD_DATA_DIR="/var/lib/postgresql/${OLD_PG_VERSION}/main"
OLD_BIN="/usr/lib/postgresql/${OLD_PG_VERSION}/bin"
# Use the new version's psql — it is backward-compatible with older servers
# and avoids libreadline ABI mismatches between the source and target distros.
PSQL="/usr/lib/postgresql/${NEW_PG_VERSION}/bin/psql"

echo "==> Initializing PostgreSQL ${OLD_PG_VERSION} cluster at ${OLD_DATA_DIR}"
"${OLD_BIN}/initdb" \
  -D "${OLD_DATA_DIR}" \
  --encoding=UTF8 \
  --locale=en_US.UTF-8

# Allow local connections without password
echo "host all all 127.0.0.1/32 trust" >> "${OLD_DATA_DIR}/pg_hba.conf"
echo "host all all ::1/128 trust"       >> "${OLD_DATA_DIR}/pg_hba.conf"

echo "==> Starting PostgreSQL ${OLD_PG_VERSION}"
"${OLD_BIN}/pg_ctl" -D "${OLD_DATA_DIR}" -l "${OLD_DATA_DIR}/pg.log" start -w

echo "==> Creating testdb with schema-heavy fixtures"
"${PSQL}" -U postgres -h 127.0.0.1 -c "CREATE DATABASE testdb;"

"${PSQL}" -U postgres -h 127.0.0.1 -d testdb <<'SQL'
CREATE TABLE users (
    id         SERIAL PRIMARY KEY,
    name       VARCHAR(100) NOT NULL,
    email      VARCHAR(255) NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    CONSTRAINT users_email_unique UNIQUE (email)
);

CREATE TABLE orders (
    id         SERIAL PRIMARY KEY,
    user_id    INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    amount     DECIMAL(10, 2) NOT NULL,
    status     VARCHAR(20) NOT NULL DEFAULT 'pending',
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_orders_user_id ON orders(user_id);
CREATE INDEX idx_orders_status  ON orders(status);

CREATE VIEW active_orders AS
    SELECT o.id, o.amount, o.status, o.created_at, u.name AS user_name, u.email
    FROM orders o
    JOIN users u ON u.id = o.user_id
    WHERE o.status = 'pending';

CREATE SEQUENCE invoice_seq START 1000 INCREMENT 1;

INSERT INTO users (name, email) VALUES
    ('Alice Smith',    'alice@example.com'),
    ('Bob Johnson',    'bob@example.com'),
    ('Carol Williams', 'carol@example.com');

INSERT INTO orders (user_id, amount, status) VALUES
    (1, 99.99,  'pending'),
    (1, 249.00, 'completed'),
    (2, 149.99, 'pending'),
    (3, 49.50,  'cancelled');
SQL

echo "==> Creating analytics database"
"${PSQL}" -U postgres -h 127.0.0.1 -c "CREATE DATABASE analytics;"

"${PSQL}" -U postgres -h 127.0.0.1 -d analytics <<'SQL'
CREATE TABLE events (
    id         BIGSERIAL PRIMARY KEY,
    event_type VARCHAR(50) NOT NULL,
    user_id    INT,
    payload    TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_events_type_time ON events(event_type, created_at);

INSERT INTO events (event_type, user_id, payload) VALUES
    ('login',    1, '{"ip": "1.2.3.4"}'),
    ('purchase', 1, '{"order_id": 1}'),
    ('login',    2, '{"ip": "5.6.7.8"}'),
    ('logout',   1, NULL),
    ('purchase', 3, '{"order_id": 3}');

CREATE MATERIALIZED VIEW daily_event_counts AS
    SELECT
        DATE_TRUNC('day', created_at) AS day,
        event_type,
        COUNT(*) AS event_count
    FROM events
    GROUP BY 1, 2;

CREATE INDEX idx_daily_event_counts_day ON daily_event_counts(day);
SQL

echo "==> Stopping PostgreSQL ${OLD_PG_VERSION}"
"${OLD_BIN}/pg_ctl" -D "${OLD_DATA_DIR}" stop -m fast

echo "==> PostgreSQL ${OLD_PG_VERSION} cluster initialized with test data."
