FROM ubuntu:20.04

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8

RUN apt-get update && apt-get install -y \
    curl \
    gnupg \
    locales \
    gosu \
    && locale-gen en_US.UTF-8 \
    && update-locale LANG=en_US.UTF-8 \
    && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc \
    | gpg --dearmor -o /usr/share/keyrings/postgresql-keyring.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/postgresql-keyring.gpg] https://apt.postgresql.org/pub/repos/apt focal-pgdg main" \
    > /etc/apt/sources.list.d/pgdg.list

RUN apt-get update && apt-get install -y \
    postgresql-9.6 \
    postgresql-contrib-9.6 \
    postgresql-16 \
    postgresql-contrib-16 \
    && rm -rf /var/lib/apt/lists/*

# Stop system init from managing clusters; we drive everything via scripts
RUN pg_dropcluster --stop 9.6 main || true
RUN pg_dropcluster --stop 16 main || true

# Ensure data dir parents exist and are owned by postgres
RUN mkdir -p /var/lib/postgresql/9.6/main /var/lib/postgresql/16/main \
    && chown -R postgres:postgres /var/lib/postgresql

COPY scripts/ /usr/local/bin/pg-upgrade-scripts/
RUN chmod +x /usr/local/bin/pg-upgrade-scripts/*.sh

ENTRYPOINT ["/usr/local/bin/pg-upgrade-scripts/entrypoint.sh"]
