#!/bin/bash
set -euo pipefail

OLD_PG_VERSION="${OLD_PG_VERSION:?OLD_PG_VERSION env var must be set}"
NEW_PG_VERSION="${NEW_PG_VERSION:?NEW_PG_VERSION env var must be set}"
OLD_DATA_DIR="/var/lib/postgresql/${OLD_PG_VERSION}/main"
NEW_DATA_DIR="/var/lib/postgresql/${NEW_PG_VERSION}/main"
OLD_BIN="/usr/lib/postgresql/${OLD_PG_VERSION}/bin"
NEW_BIN="/usr/lib/postgresql/${NEW_PG_VERSION}/bin"
WORK_DIR="/var/lib/postgresql"

# pg_upgrade writes log files and post-upgrade scripts (analyze_new_cluster.sh,
# delete_old_cluster.sh) to the current working directory, which must be
# writable by the postgres user.
cd "${WORK_DIR}"

echo "==> Initializing PostgreSQL ${NEW_PG_VERSION} cluster at ${NEW_DATA_DIR}"
"${NEW_BIN}/initdb" \
  -D "${NEW_DATA_DIR}" \
  --encoding=UTF8 \
  --locale=en_US.UTF-8

echo "==> Running pg_upgrade compatibility check (dry run)"
"${NEW_BIN}/pg_upgrade" \
  -b "${OLD_BIN}" \
  -B "${NEW_BIN}" \
  -d "${OLD_DATA_DIR}" \
  -D "${NEW_DATA_DIR}" \
  --check

echo "==> Compatibility check passed. Running pg_upgrade"
"${NEW_BIN}/pg_upgrade" \
  -b "${OLD_BIN}" \
  -B "${NEW_BIN}" \
  -d "${OLD_DATA_DIR}" \
  -D "${NEW_DATA_DIR}"

echo "==> Running post-upgrade ANALYZE on all databases"
if [ -f "${WORK_DIR}/analyze_new_cluster.sh" ]; then
  bash "${WORK_DIR}/analyze_new_cluster.sh"
else
  echo "    (analyze_new_cluster.sh not found — skipping)"
fi

echo "==> pg_upgrade complete. PostgreSQL ${OLD_PG_VERSION} → ${NEW_PG_VERSION} done."
