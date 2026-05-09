# pg_upgrade — Containerized PostgreSQL Upgrade Utility

A Docker-based toolkit that automates upgrading PostgreSQL databases using `pg_upgrade`, built for teams running **containerized PostgreSQL in production**.

---

## The Problem

Upgrading PostgreSQL across major versions in a containerized environment is painful:

- `pg_upgrade` requires both the old and new PostgreSQL binaries to be present on the **same machine**
- The data directory must be accessible to both server processes during the upgrade
- After upgrade you need to prove the data survived intact before promoting the new cluster to production

This project packages all of that into reproducible Docker images and a CI pipeline that proves the upgrade works end-to-end before you touch production.

---

## How It Works

The upgrade runs as three container steps sharing data through Docker volumes:

```
┌──────────────────────────────────────────────────────────────────┐
│  Step 1 — init-old                                               │
│  Initialises a PostgreSQL <old> cluster with real-world schema:  │
│  tables, indexes, views, sequences, materialized views, FK       │
│  constraints, and sample data.                                   │
└──────────────────────┬───────────────────────────────────────────┘
                       │  pg-old-data volume
┌──────────────────────▼───────────────────────────────────────────┐
│  Step 2 — upgrade                                                │
│  Runs pg_upgrade --check (dry run), then the real upgrade.       │
│  Reads from pg-old-data, writes upgraded files to pg-new-data.  │
└──────────────────────┬───────────────────────────────────────────┘
                       │  pg-new-data volume
┌──────────────────────▼───────────────────────────────────────────┐
│  Step 3 — verify                                                 │
│  Starts the new PostgreSQL <new> cluster and asserts:           │
│  databases exist • row counts match • indexes intact            │
│  views work • sequences preserved • foreign keys survive        │
└──────────────────────────────────────────────────────────────────┘
```

---

## Supported Upgrade Paths

Images are published to **[abhsss/pg-upgrade on DockerHub](https://hub.docker.com/repository/docker/abhsss/pg-upgrade/general)**.

| From | To | Pull command |
|---|---|---|
| PostgreSQL 9.6 | PostgreSQL 16 | `docker pull abhsss/pg-upgrade:9.6-to-16` |

More paths are planned. See [Adding a New Upgrade Path](#adding-a-new-upgrade-path).

---

## Repository Structure

```
pg_upgrade/
├── upgrades/
│   └── 9.6-to-16/
│       └── Dockerfile          # Sets OLD/NEW_PG_VERSION; sources PG 9.6 binaries
├── scripts/
│   ├── entrypoint.sh           # Dispatches init-old / upgrade / verify
│   ├── init-old-cluster.sh     # Seeds old cluster with schema-heavy test data
│   ├── run-upgrade.sh          # Runs pg_upgrade (dry-run check + real upgrade)
│   └── verify-new-cluster.sh   # Asserts data integrity on the upgraded cluster
├── .github/
│   └── workflows/
│       └── pg-upgrade.yml      # Matrix CI: builds image, runs full pipeline
└── README.md
```

The scripts are fully parameterized via `OLD_PG_VERSION` and `NEW_PG_VERSION` environment variables set in each upgrade path's Dockerfile — adding a new path requires no script changes.

---

## Quick Start (Local)

```bash
# 1. Build
docker build -f upgrades/9.6-to-16/Dockerfile -t pg-upgrade:9.6-to-16 .

# 2. Create volumes
docker volume create pg-old-data
docker volume create pg-new-data

# 3. Seed PostgreSQL 9.6
docker run --rm \
  -v pg-old-data:/var/lib/postgresql/9.6/main \
  abhsss/pg-upgrade:9.6-to-16 init-old

# 4. Upgrade to PostgreSQL 16
docker run --rm \
  -v pg-old-data:/var/lib/postgresql/9.6/main \
  -v pg-new-data:/var/lib/postgresql/16/main \
  abhsss/pg-upgrade:9.6-to-16 upgrade

# 5. Verify
docker run --rm \
  -v pg-new-data:/var/lib/postgresql/16/main \
  abhsss/pg-upgrade:9.6-to-16 verify

# 6. Cleanup
docker volume rm pg-old-data pg-new-data
```

---

## CI / DockerHub Setup

The GitHub Actions pipeline builds the image and runs the full upgrade test automatically on every push to `main`.

**Required GitHub secrets** (Settings → Secrets → Actions):

| Secret | Description |
|---|---|
| `DOCKERHUB_USERNAME` | Your DockerHub username |
| `DOCKERHUB_TOKEN` | DockerHub access token (DockerHub → Account Settings → Security) |

---

## Adding a New Upgrade Path

1. **Create the Dockerfile** at `upgrades/<old>-to-<new>/Dockerfile`.
   Copy `upgrades/9.6-to-16/Dockerfile` and update the two `FROM` stages and the `ENV OLD_PG_VERSION` / `ENV NEW_PG_VERSION` values.

2. **Register it in the CI matrix** inside `.github/workflows/pg-upgrade.yml`:

   ```yaml
   matrix:
     upgrade:
       - tag: "9.6-to-16"
         dockerfile: "upgrades/9.6-to-16/Dockerfile"
       - tag: "13-to-16"           # <-- new entry
         dockerfile: "upgrades/13-to-16/Dockerfile"
   ```

   And add the matching entry in the `test-upgrade` matrix with `from_version` / `to_version`.

No changes to the shared scripts are needed.

---

## Contributing

Contributions for additional upgrade paths, improved verification queries, or production hardening are welcome. Please open an issue to discuss scope before sending a pull request.
