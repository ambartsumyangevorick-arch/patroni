FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC
ENV PATRONI_VERSION=4.1.1

RUN apt-get update && apt-get install -y --no-install-recommends \
        curl \
        wget \
        ca-certificates \
        git \
        make \
        build-essential \
        libssl-dev \
        libkrb5-dev \
        python3 \
        python3-dev \
        python3-pip \
        locales \
        meson \
        ninja-build \
        libxml2-dev \
        pkg-config \
        liblz4-dev \
        libzstd-dev \
        libbz2-dev \
        libz-dev \
        libyaml-dev \
        libssh2-1-dev \
        libcurl4-openssl-dev \
        && apt-get clean \
        && rm -rf /var/lib/apt/lists/*

COPY pgpro-repo-add.sh /tmp/pgpro-repo-add.sh
RUN chmod +x /tmp/pgpro-repo-add.sh && \
    /tmp/pgpro-repo-add.sh && \
    rm /tmp/pgpro-repo-add.sh

RUN apt-get update && \
    apt-get install -y \
        postgrespro-1c-18 \
        postgrespro-1c-18-dev \
        && apt-get clean \
        && rm -rf /var/lib/apt/lists/*

RUN usermod -u 2001 postgres && groupmod -g 2001 postgres
ENV PATH=/opt/pgpro/1c-18/bin:$PATH

RUN locale-gen ru_RU.UTF-8 && \
    locale-gen en_US.UTF-8 && \
    update-locale LANG=ru_RU.UTF-8 LC_ALL=ru_RU.UTF-8
ENV LANG=ru_RU.UTF-8
ENV LC_ALL=ru_RU.UTF-8

RUN pip3 install --no-cache-dir --break-system-packages \
    pgxnclient \
    "patroni[consul]==${PATRONI_VERSION}" \
    psycopg2-binary \
    python-consul2 \
    ydiff==1.4.2 && \
    ln -sf /opt/pgpro/1c-18/bin/pg_config /usr/local/bin/pg_config

RUN mkdir -p /tmp/build && \
    wget -P /tmp/build https://github.com/pgbackrest/pgbackrest/archive/refs/tags/release/2.58.0.tar.gz && \
    cd /tmp/build && \
    tar -xvf 2.58.0.tar.gz && \
    PKG_CONFIG_PATH=/opt/pgpro/1c-18/lib/pkgconfig meson setup /tmp/build/pgbackrest /tmp/build/pgbackrest-release-2.58.0/ && \
    ninja -C /tmp/build/pgbackrest && \
    mv /tmp/build/pgbackrest/src/pgbackrest /opt/pgpro/1c-18/bin/ && \
    cd /tmp && \
    rm -rf /tmp/build && \
    pgbackrest --version

RUN mkdir -p /var/lib/postgresql/data && \
    chown -R postgres:postgres /var/lib/postgresql && \
    mkdir -p /var/log/pgbackrest && \
    chown -R postgres:postgres /var/log/pgbackrest && \
    chmod 750 /var/log/pgbackrest

RUN ls -l /opt/pgpro/1c-18/bin/pg_config && /opt/pgpro/1c-18/bin/pg_config --version

RUN git clone --branch 2.3.1 https://github.com/percona/pg_stat_monitor.git /tmp/pg_stat_monitor && \
    cd /tmp/pg_stat_monitor && \
    PG_CONFIG=/opt/pgpro/1c-18/bin/pg_config make USE_PGXS=1 && \
    PG_CONFIG=/opt/pgpro/1c-18/bin/pg_config make USE_PGXS=1 install && \
    rm -rf /tmp/pg_stat_monitor

RUN git clone https://github.com/pgaudit/pgaudit.git /tmp/pgaudit && \
    cd /tmp/pgaudit && \
    git checkout REL_18_STABLE && \
    PG_CONFIG=/opt/pgpro/1c-18/bin/pg_config make USE_PGXS=1 install && \
    rm -rf /tmp/pgaudit

RUN git clone https://github.com/eulerto/wal2json.git /tmp/wal2json && \
    cd /tmp/wal2json && \
    PG_CONFIG=/opt/pgpro/1c-18/bin/pg_config make USE_PGXS=1 && \
    PG_CONFIG=/opt/pgpro/1c-18/bin/pg_config make USE_PGXS=1 install && \
    rm -rf /tmp/wal2json

USER postgres
