#!/bin/sh
set -eu

cd /app

mkdir -p /app/kernel/Install

if [ -n "${RAILWAY_VOLUME_MOUNT_PATH:-}" ]; then
    mkdir -p "${RAILWAY_VOLUME_MOUNT_PATH}/assets-cache"
    if [ -d /app/assets/cache ] && [ ! -L /app/assets/cache ]; then
        cp -a /app/assets/cache/. "${RAILWAY_VOLUME_MOUNT_PATH}/assets-cache/" 2>/dev/null || true
        rm -rf /app/assets/cache
    fi
    ln -sfn "${RAILWAY_VOLUME_MOUNT_PATH}/assets-cache" /app/assets/cache
else
    mkdir -p /app/assets/cache
fi

DB_DRIVER="${DB_DRIVER:-mysql}"
DB_HOST="${DB_HOST:-${MYSQLHOST:-${MYSQL_HOST:-}}}"
DB_PORT="${DB_PORT:-${MYSQLPORT:-${MYSQL_PORT:-}}}"
DB_NAME="${DB_NAME:-${MYSQLDATABASE:-${MYSQL_DATABASE:-}}}"
DB_USER="${DB_USER:-${MYSQLUSER:-${MYSQL_USER:-}}}"
DB_PASS="${DB_PASS:-${MYSQLPASSWORD:-${MYSQL_PASSWORD:-}}}"
DB_PREFIX="${DB_PREFIX:-acg_}"
DB_URL="${DB_URL:-${DATABASE_URL:-${MYSQL_URL:-}}}"

if { [ -z "${DB_HOST}" ] || [ -z "${DB_NAME}" ] || [ -z "${DB_USER}" ]; } && [ -n "${DB_URL}" ]; then
    eval "$(
        DB_URL_INPUT="${DB_URL}" php -r '
$dsn = getenv("DB_URL_INPUT");
if (!$dsn) {
    exit(0);
}

$dsn = preg_replace("/^jdbc:/", "", trim($dsn));
$parts = parse_url($dsn);
if ($parts === false) {
    exit(0);
}

$scheme = strtolower($parts["scheme"] ?? "");
if ($scheme !== "" && !in_array($scheme, ["mysql", "mariadb"], true)) {
    exit(0);
}

$dbName = "";
if (isset($parts["path"])) {
    $dbName = ltrim($parts["path"], "/");
    if ($dbName !== "") {
        $dbName = rawurldecode($dbName);
    }
}

if ($dbName === "") {
    $query = [];
    parse_str($parts["query"] ?? "", $query);
    if (isset($query["database"])) {
        $dbName = (string) $query["database"];
    } elseif (isset($query["dbname"])) {
        $dbName = (string) $query["dbname"];
    }
}

$current = [
    "DB_HOST" => getenv("DB_HOST") ?: "",
    "DB_PORT" => getenv("DB_PORT") ?: "",
    "DB_NAME" => getenv("DB_NAME") ?: "",
    "DB_USER" => getenv("DB_USER") ?: "",
    "DB_PASS" => getenv("DB_PASS") ?: "",
];

$parsed = [
    "DB_HOST" => $parts["host"] ?? "",
    "DB_PORT" => isset($parts["port"]) ? (string) $parts["port"] : "",
    "DB_NAME" => $dbName,
    "DB_USER" => isset($parts["user"]) ? rawurldecode($parts["user"]) : "",
    "DB_PASS" => isset($parts["pass"]) ? rawurldecode($parts["pass"]) : "",
];

foreach ($parsed as $key => $value) {
    if ($current[$key] === "" && $value !== "") {
        echo $key, "=", escapeshellarg($value), PHP_EOL;
    }
}
'
    )"
fi

DB_PORT="${DB_PORT:-3306}"

if [ -z "${DB_HOST}" ] || [ -z "${DB_NAME}" ] || [ -z "${DB_USER}" ]; then
    echo "Missing MySQL database settings. Set DB_HOST/DB_NAME/DB_USER/DB_PASS, Railway MySQL vars (MYSQLHOST/MYSQLDATABASE/MYSQLUSER/MYSQLPASSWORD), or provide MYSQL_URL / a mysql:// DATABASE_URL." >&2
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

if [ ! -f /app/kernel/Install/Lock ]; then
    if php -r '
        $host = getenv("DB_HOST");
        $port = getenv("DB_PORT") ?: "3306";
        $db = getenv("DB_NAME");
        $user = getenv("DB_USER");
        $pass = getenv("DB_PASS");
        $prefix = getenv("DB_PREFIX") ?: "acg_";

        try {
            $pdo = new PDO("mysql:host={$host};port={$port};dbname={$db};charset=utf8mb4", $user, $pass, [
                PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
            ]);
            $stmt = $pdo->prepare("SHOW TABLES LIKE ?");
            $stmt->execute([$prefix . "config"]);
            exit($stmt->fetchColumn() ? 0 : 1);
        } catch (Throwable $e) {
            exit(1);
        }
    '; then
        printf "railway" > /app/kernel/Install/Lock
    fi
fi

exec frankenphp run --config /etc/caddy/Caddyfile
