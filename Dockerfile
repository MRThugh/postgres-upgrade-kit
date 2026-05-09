# Stage 1: Pull PostgreSQL 9.6 binaries from the official image (Debian Buster)
# The PGDG focal repo no longer carries 9.6 packages; the official Docker image
# is the reliable source for these binaries.
FROM postgres:9.6 AS pg96_binaries

# Stage 2: Runtime image
# Use postgres:16-bullseye (not bookworm) because Debian Bullseye includes
# libssl1.1, which the PG 9.6 server binaries were compiled against.
FROM postgres:16-bullseye

ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8

RUN apt-get update && apt-get install -y \
    locales \
    && locale-gen en_US.UTF-8 \
    && update-locale LANG=en_US.UTF-8 \
    && rm -rf /var/lib/apt/lists/*

# Copy PG 9.6 binaries and catalog files from Stage 1.
# The server binaries (postgres, initdb, pg_ctl) link against libssl.so.1.1
# and libc — both present on Bullseye. No extra library copies are needed.
# psql is NOT copied; all SQL operations use PG 16's psql instead.
COPY --from=pg96_binaries /usr/lib/postgresql/9.6 /usr/lib/postgresql/9.6
COPY --from=pg96_binaries /usr/share/postgresql/9.6 /usr/share/postgresql/9.6

# Prepare volume mount-points owned by the postgres user
RUN mkdir -p /var/lib/postgresql/9.6/main /var/lib/postgresql/16/main \
    && chown -R postgres:postgres /var/lib/postgresql

COPY scripts/ /usr/local/bin/pg-upgrade-scripts/
RUN chmod +x /usr/local/bin/pg-upgrade-scripts/*.sh

ENTRYPOINT ["/usr/local/bin/pg-upgrade-scripts/entrypoint.sh"]
