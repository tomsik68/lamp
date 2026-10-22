#!/usr/bin/env bash
# Smoke test: container starts, Apache serves PHP, MariaDB accepts
# connections (TCP and the localhost socket), Adminer logs in. Usage: tests/smoke.sh IMAGE
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

adminer="http://127.0.0.1:$port/adminer/"
form=$(curl -fsS -c "$jar" -b "$jar" "$adminer") || fail "Adminer did not load"
echo "$form" | grep 'name="auth\[username\]"[^>]*value="root"' >/dev/null || fail "Adminer login form lacks the root default"
token=$(echo "$form" | grep -oP "name='token' value='\K[^']+" | head -n1)
curl -fsS -c "$jar" -b "$jar" -L -o /dev/null --data-urlencode "token=$token" \
  --data 'auth[driver]=server&auth[server]=&auth[username]=root&auth[password]=root&auth[db]=' "$adminer" \
  || fail "Adminer login request"
curl -fsS -c "$jar" -b "$jar" "$adminer?username=root" | grep information_schema >/dev/null \
  || fail "Adminer login as root/root did not reach the database list"
echo "ok   Adminer login"

redirect=$(curl -sS -o /dev/null -w '%{http_code} %{redirect_url}' "http://127.0.0.1:$port/phpmyadmin/index.php")
[ "$redirect" = "302 http://127.0.0.1:$port/adminer/" ] || fail "/phpmyadmin/ redirect: $redirect"
echo "ok   /phpmyadmin/ redirects to /adminer/"

$DOCKER exec "$name" mariadb -h 127.0.0.1 -uroot -proot -e 'SELECT 1' >/dev/null || fail "root over TCP"
echo "ok   root/root over TCP"

# Waits until the default-password check has run $1 times
wait_password_checks() {
  for _ in $(seq 60); do
    [ "$($DOCKER logs "$name" 2>&1 | grep -c 'default-password check done')" -ge "$1" ] && return
    sleep 1
  done
  fail "default-password check did not run"
}
wait_password_checks 1
$DOCKER logs "$name" 2>&1 | grep 'WARNING: MariaDB root password is the default' >/dev/null || fail "no default-password warning"
$DOCKER exec "$name" mariadb -e "ALTER USER 'root'@'%' IDENTIFIED BY 'changed'" || fail "change root password"
$DOCKER restart "$name" >/dev/null
wait_password_checks 2
[ "$($DOCKER logs "$name" 2>&1 | grep -c 'WARNING: MariaDB root password is the default')" = 1 ] \
  || fail "default-password warning still shows after the password changed"
echo "ok   default-password warning follows the real password"

for ext in mysqli pdo_mysql gd intl zip bcmath exif 'Zend OPcache' imagick soap redis memcached xdebug; do
  $DOCKER exec "$name" php -m | grep -x "$ext" >/dev/null || fail "missing PHP extension $ext"
done
echo "ok   PHP extensions"

$DOCKER exec "$name" composer --version >/dev/null || fail "composer"
echo "ok   composer"
echo PASS
