FROM debian:trixie-slim

ENV DEBIAN_FRONTEND=noninteractive

# Cài đặt các package cần thiết
RUN apt-get update && apt-get install -y --no-install-recommends \
    postgresql-client \
    default-mysql-client \
    sqlite3 \
    curl \
    gnupg \
    bash \
    tar \
    gzip \
    zip \
    unzip \
    ca-certificates \
    tzdata \
    cron \
    wget \
    && rm -rf /var/lib/apt/lists/*

# MongoDB tools removed temporarily - focus on PostgreSQL and MySQL first

# Cài đặt rclone
RUN curl https://rclone.org/install.sh | bash

# Tạo thư mục làm việc
WORKDIR /app

# Copy scripts
COPY scripts/backup.sh /app/backup.sh
COPY scripts/start.sh /app/start.sh
COPY scripts/backup-wrapper.sh /app/backup-wrapper.sh

# Tạo thư mục logs
RUN mkdir -p /app/logs

# Set permissions
RUN chmod +x /app/backup.sh /app/start.sh /app/backup-wrapper.sh

# Tạo entrypoint script
ENTRYPOINT ["/app/start.sh"]
