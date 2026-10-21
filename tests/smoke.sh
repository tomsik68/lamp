#!/usr/bin/env bash
# Smoke test: container starts, Apache serves PHP, MariaDB accepts
# connections (TCP and the localhost socket), phpMyAdmin logs in. Usage: tests/smoke.sh IMAGE
set -euo pipefail

IMAGE=${1:?usage: $0 IMAGE}
DOCKER=${DOCKER:-docker}
# extra run flags, e.g. RUN_FLAGS=--userns=private for rootless podman with keep-id
RUN_FLAGS=${RUN_FLAGS:-}
name=lamp-smoke-$$
web=$(mktemp -d)
jar=$(mktemp)
chmod 755 "$web"
trap '$DOCKER rm -f "$name" >/dev/null 2>&1 || true; rm -rf "$web" "$jar"' EXIT

cat > "$web/index.php" <<'PHP'
<?php
$db = new mysqli('127.0.0.1', 'root', 'root');
echo 'php=' . PHP_VERSION . ' db=' . $db->query('SELECT VERSION()')->fetch_row()[0];
PHP
# `localhost` means the Unix socket to mysqli and PDO, as in most XAMPP-era apps
cat > "$web/socket.php" <<'PHP'
<?php
new mysqli('localhost', 'root', 'root');
new PDO('mysql:host=localhost', 'root', 'root');
echo 'socket ok';
PHP
chmod 644 "$web/index.php" "$web/socket.php"

# shellcheck disable=SC2086 # RUN_FLAGS is meant to split into several flags
$DOCKER run -d $RUN_FLAGS --name "$name" -p 127.0.0.1::80 -v "$web:/var/www/html:ro,z" "$IMAGE" >/dev/null
port=$($DOCKER port "$name" 80 | head -n1 | sed 's/.*://')

fail() { echo "FAIL: $*" >&2; $DOCKER logs "$name" >&2; exit 1; }

for _ in $(seq 60); do
  curl -fsS "http://127.0.0.1:$port/index.php" 2>/dev/null | grep 'db=' >/dev/null && break
  sleep 1
done

body=$(curl -fsS "http://127.0.0.1:$port/index.php") || fail "PHP page did not load"
echo "$body" | grep 'db=.*MariaDB' >/dev/null || fail "PHP could not query MariaDB: $body"
echo "ok   $body"

curl -fsS "http://127.0.0.1:$port/www/index.php" | grep 'db=' >/dev/null || fail "/www/ alias missing"
echo "ok   /www/ alias"

curl -fsS "http://127.0.0.1:$port/socket.php" | grep 'socket ok' >/dev/null || fail "PHP could not connect to localhost over the socket"
echo "ok   localhost socket (mysqli, PDO)"

pma="http://127.0.0.1:$port/phpmyadmin/index.php"
token=$(curl -fsS -c "$jar" -b "$jar" "$pma" | grep -oP 'name="token" value="\K[^"]+' | head -n1) || fail "phpMyAdmin did not load"
curl -fsS -c "$jar" -b "$jar" -o /dev/null --data-urlencode "token=$token" \
  --data 'pma_username=root&pma_password=root&server=1' "$pma?route=/" || fail "phpMyAdmin login request"
curl -fsS -c "$jar" -b "$jar" "$pma?route=/server/databases" | grep information_schema >/dev/null \
  || fail "phpMyAdmin login as root/root did not reach the database list"
echo "ok   phpMyAdmin login"

$DOCKER exec "$name" mariadb -h 127.0.0.1 -uroot -proot -e 'SELECT 1' >/dev/null || fail "root over TCP"
echo "ok   root/root over TCP"

for ext in mysqli pdo_mysql gd intl zip bcmath exif 'Zend OPcache' imagick soap redis memcached xdebug; do
  $DOCKER exec "$name" php -m | grep -x "$ext" >/dev/null || fail "missing PHP extension $ext"
done
echo "ok   PHP extensions"

$DOCKER exec "$name" composer --version >/dev/null || fail "composer"
echo "ok   composer"
echo PASS
