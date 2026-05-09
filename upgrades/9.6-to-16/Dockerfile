# Stage 1: Pull PostgreSQL 9.6 binaries from the official image (Debian Buster).
# The PGDG focal repo no longer carries 9.6 packages; the official Docker image
# is the reliable source for these binaries.
FROM postgres:9.6 AS old_binaries

# Stage 2: Runtime image.
# Use postgres:16-bullseye (not bookworm) because Debian Bullseye includes
# libssl1.1, which the PG 9.6 server binaries were compiled against.
FROM postgres:16-bullseye

ENV OLD_PG_VERSION=9.6
ENV NEW_PG_VERSION=16
ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8

RUN apt-get update && apt-get install -y \
    locales \
    && locale-gen en_US.UTF-8 \
    && update-locale LANG=en_US.UTF-8 \
    && rm -rf /var/lib/apt/lists/*

# Copy PG 9.6 binaries and catalog files from Stage 1.
# Server binaries (postgres, initdb, pg_ctl) link against libssl.so.1.1
# and libc — both present on Bullseye. psql is not used from this stage;
# all SQL operations use PG 16's psql (backward-compatible with PG 9.6).
COPY --from=old_binaries /usr/lib/postgresql/9.6 /usr/lib/postgresql/9.6
COPY --from=old_binaries /usr/share/postgresql/9.6 /usr/share/postgresql/9.6

# Prepare volume mount-points owned by the postgres user
RUN mkdir -p \
    /var/lib/postgresql/${OLD_PG_VERSION}/main \
    /var/lib/postgresql/${NEW_PG_VERSION}/main \
    && chown -R postgres:postgres /var/lib/postgresql

# Build context is the repo root so shared scripts are always accessible
COPY scripts/ /usr/local/bin/pg-upgrade-scripts/
RUN chmod +x /usr/local/bin/pg-upgrade-scripts/*.sh

ENTRYPOINT ["/usr/local/bin/pg-upgrade-scripts/entrypoint.sh"]
