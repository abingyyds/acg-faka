#!/bin/sh
set -eu

cd /app

mkdir -p /app/kernel/Install

DB_DRIVER="${DB_DRIVER:-mysql}"
DB_HOST="${DB_HOST:-${MYSQLHOST:-}}"
DB_PORT="${DB_PORT:-${MYSQLPORT:-3306}}"
DB_NAME="${DB_NAME:-${MYSQLDATABASE:-}}"
DB_USER="${DB_USER:-${MYSQLUSER:-}}"
DB_PASS="${DB_PASS:-${MYSQLPASSWORD:-}}"
DB_PREFIX="${DB_PREFIX:-acg_}"

if [ -z "${DB_HOST}" ] || [ -z "${DB_NAME}" ] || [ -z "${DB_USER}" ]; then
    echo "Missing database settings. Set DB_HOST/DB_NAME/DB_USER/DB_PASS or Railway MySQL variables (MYSQLHOST/MYSQLDATABASE/MYSQLUSER/MYSQLPASSWORD)." >&2
    exit 1
fi

cat > /app/config/database.php <<EOF
<?php
declare(strict_types=1);

return [
    'driver' => '${DB_DRIVER}',
    'host' => '${DB_HOST}',
    'port' => '${DB_PORT}',
    'database' => '${DB_NAME}',
    'username' => '${DB_USER}',
    'password' => '${DB_PASS}',
    'charset' => 'utf8mb4',
    'collation' => 'utf8mb4_unicode_ci',
    'prefix' => '${DB_PREFIX}',
    'options' => [],
];
EOF

if [ -n "${APP_INSTALLED_LOCK:-}" ]; then
    printf "%s" "${APP_INSTALLED_LOCK}" > /app/kernel/Install/Lock
elif [ "${APP_MARK_INSTALLED:-0}" = "1" ] && [ ! -f /app/kernel/Install/Lock ]; then
    printf "railway" > /app/kernel/Install/Lock
fi

exec frankenphp run --config /etc/caddy/Caddyfile
