#!/bin/bash
# Install PostgreSQL extension packages for a given PG major version.
# Usage: install-extensions.sh <pg-version> <ext1,ext2,...>
# Called at Docker build time from both Stage 1 (old PG) and Stage 2 (new PG).
set -euo pipefail

PG_VER="${1:?First argument must be the PostgreSQL major version}"
EXTENSIONS_CSV="${2:-}"

[ -z "${EXTENSIONS_CSV}" ] && exit 0

pkg_for() {
  local ext="${1}" ver="${2}"
  case "${ext}" in
    postgis)      echo "postgresql-${ver}-postgis-3" ;;
    pgvector)     echo "postgresql-${ver}-pgvector" ;;
    pg_partman)   echo "postgresql-${ver}-partman" ;;
    pgrouting)    echo "postgresql-${ver}-pgrouting" ;;
    pg_repack)    echo "postgresql-${ver}-repack" ;;
    hypopg)       echo "postgresql-${ver}-hypopg" ;;
    orafce)       echo "postgresql-${ver}-orafce" ;;
    rum)          echo "postgresql-${ver}-rum" ;;
    ip4r)         echo "postgresql-${ver}-ip4r" ;;
    pg_cron)      echo "postgresql-${ver}-cron" ;;
    pgaudit)      echo "postgresql-${ver}-pgaudit" ;;
    pg_hint_plan) echo "postgresql-${ver}-pg-hint-plan" ;;
    *) echo "Unknown extension: ${ext}" >&2; exit 1 ;;
  esac
}

PKGS=""
IFS=',' read -ra EXTS <<< "${EXTENSIONS_CSV}"
for ext in "${EXTS[@]}"; do
  ext="${ext// /}"
  [ -z "${ext}" ] && continue
  PKGS="${PKGS} $(pkg_for "${ext}" "${PG_VER}")"
done

[ -z "${PKGS// /}" ] && exit 0

# Debian Stretch (postgres:9.6, postgres:11) and Buster (postgres:10) are EOL
# and their packages moved to archive.debian.org. The PGDG repos for these
# codenames are gone entirely. Redirect before apt-get update to avoid 404s.
fix_eol_sources() {
  for codename in stretch buster; do
    if grep -qr "${codename}" /etc/apt/sources.list /etc/apt/sources.list.d/ 2>/dev/null; then
      sed -i \
        -e 's|http://deb.debian.org/debian|http://archive.debian.org/debian|g' \
        -e 's|http://security.debian.org/debian-security|http://archive.debian.org/debian-security|g' \
        -e "/${codename}-updates/d" \
        /etc/apt/sources.list 2>/dev/null || true
      find /etc/apt/sources.list.d/ -name '*.list' \
        -exec sed -i "/${codename}/d" {} \; 2>/dev/null || true
    fi
  done
}
fix_eol_sources

apt-get update -qq
# shellcheck disable=SC2086
apt-get install -y --no-install-recommends ${PKGS}
rm -rf /var/lib/apt/lists/*
