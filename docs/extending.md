# Extending the image

If you need something the image doesn't ship, build your own image on top of it.

## Extra PHP extensions

The official PHP helper scripts are available:

```dockerfile
FROM tomsik68/lamp:8.4

RUN apt-get update \
 && apt-get install -y --no-install-recommends libpq-dev \
 && docker-php-ext-install pgsql pdo_pgsql \
 && pecl install apcu \
 && docker-php-ext-enable apcu \
 && rm -rf /var/lib/apt/lists/* /tmp/pear
```

`docker-php-ext-install` builds the extensions bundled with PHP. Use `pecl install` and then `docker-php-ext-enable` for extensions from PECL.

## Valkey or memcached servers

The `redis` and `memcached` PHP extensions are already installed, but their servers are not. Add a server as an extra s6 service:

```dockerfile
FROM tomsik68/lamp:8.4

RUN apt-get update \
 && apt-get install -y --no-install-recommends valkey-server memcached \
 && rm -rf /var/lib/apt/lists/*

RUN set -eu; \
  for svc in valkey memcached; do \
    mkdir -p /etc/s6-overlay/s6-rc.d/$svc/dependencies.d; \
    echo longrun > /etc/s6-overlay/s6-rc.d/$svc/type; \
    touch /etc/s6-overlay/s6-rc.d/$svc/dependencies.d/base; \
    touch /etc/s6-overlay/user-bundles.d/user/contents.d/$svc; \
  done; \
  printf '#!/bin/sh\nexec s6-setuidgid valkey valkey-server --bind 127.0.0.1 --save "" --daemonize no\n' \
    > /etc/s6-overlay/s6-rc.d/valkey/run; \
  printf '#!/bin/sh\nexec s6-setuidgid memcache memcached -l 127.0.0.1\n' \
    > /etc/s6-overlay/s6-rc.d/memcached/run; \
  chmod +x /etc/s6-overlay/s6-rc.d/*/run
```

PHP then connects to `127.0.0.1:6379` for Valkey and `127.0.0.1:11211` for memcached.

## Adminer plugins

Adminer loads every `*.php` file in `/usr/share/adminer/adminer-plugins/`. Copy in a plugin from the [Adminer plugins page](https://www.adminer.org/plugins/). Use the plugin from the same release as the bundled Adminer, whose version is shown at the top of `/adminer/`:

```dockerfile
FROM tomsik68/lamp:8.4

ADD https://raw.githubusercontent.com/vrana/adminer/v6.1.2/plugins/dump-json.php \
    /usr/share/adminer/adminer-plugins/
```

A plugin whose constructor takes arguments must be configured in `/usr/share/adminer/adminer-plugins.php` instead. See [how to use plugins](https://www.adminer.org/plugins/#use).

## Your own startup steps

Add an s6 oneshot that depends on `init-lamp`, or a longrun that depends on `mariadb`, the same way. See the [s6-overlay docs](https://github.com/just-containers/s6-overlay#writing-a-service-script).
