#!/bin/bash
set -euo pipefail

SCRIPTS_DIR="/usr/local/bin/pg-upgrade-scripts"

case "${1:-}" in
  init-old)
    exec gosu postgres "${SCRIPTS_DIR}/init-old-cluster.sh"
    ;;
  upgrade)
    exec gosu postgres "${SCRIPTS_DIR}/run-upgrade.sh"
    ;;
  verify)
    exec gosu postgres "${SCRIPTS_DIR}/verify-new-cluster.sh"
    ;;
  *)
    echo "Usage: docker run <image> <command>"
    echo ""
    echo "Commands:"
    echo "  init-old   Initialize PostgreSQL 9.6 cluster and create test databases"
    echo "  upgrade    Run pg_upgrade from 9.6 to 16"
    echo "  verify     Start PostgreSQL 16 and verify upgraded databases"
    exit 1
    ;;
esac
