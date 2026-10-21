# Configuration

## Environment variables

| Variable | Default | When it applies | What it does |
|---|---|---|---|
| `MARIADB_ROOT_PASSWORD` | `root` | first start | The root password. Root can log in both inside the container and from outside it. |
| `MARIADB_DATABASE` | — | first start | Creates this database. |
| `MARIADB_USER`, `MARIADB_PASSWORD` | — | first start | Creates this user, who can connect from anywhere. If `MARIADB_DATABASE` is set, the user gets all privileges on it. |
| `MARIADB_AUTO_UPGRADE` | `0` | every start | Set it to `1` to upgrade data written by an older MariaDB in place. Back up first. |
| `ADMINER` | `1` | every start | Set it to `0` to disable `/adminer` and the `/phpmyadmin` redirect. |
| `XDEBUG_MODE` | `off` | every start | The [xdebug mode](https://xdebug.org/docs/all_settings#mode), for example `debug` or `debug,develop`. |
| `PUID`, `PGID` | `33` | every start | The uid and gid Apache runs as. Set them to your own (`-e PUID=$(id -u) -e PGID=$(id -g)`) so files PHP writes into a bind mount belong to you. |

A "first start" variable takes effect only when `/var/lib/mysql` is empty. After that, change passwords and users with SQL, for example in Adminer.

The startup log warns while `MARIADB_ROOT_PASSWORD` is still `root`. The check reads only the variable. If you changed the password with SQL, the warning still shows until you also set the variable.

### Xdebug

With `XDEBUG_MODE=debug`, xdebug connects to `host.docker.internal:9003` when a request carries the trigger, such as the `XDEBUG_TRIGGER` cookie or query parameter. On Linux, add `--add-host=host.docker.internal:host-gateway` to `docker run`.

## Paths and volumes

| Path | What it is |
|---|---|
| `/var/www/html` | The web root. It is also served at `/www/`. `/www` and `/opt/lampp/htdocs` are symlinks to it. |
| `/var/lib/mysql` | The MariaDB data directory, declared as a volume. Mount a named volume here to keep your databases. |

## Config drop-ins

Mount or copy your own files into these directories. They are read after the image's defaults, so their settings win.

| Directory | Files | Example |
|---|---|---|
| `/usr/local/etc/php/conf.d/` | `*.ini` | `memory_limit = 1G` |
| `/etc/mysql/conf.d/` | `*.cnf` | `[mysqld]` and then `max_allowed_packet = 256M` |
| `/etc/apache2/conf-enabled/` | `*.conf` | extra `Alias` or `<Directory>` blocks |

```sh
docker run -d -p 80:80 \
  -v "$PWD/php.ini":/usr/local/etc/php/conf.d/zz-my.ini:ro \
  tomsik68/lamp
```

PHP starts from `php.ini-development`, so errors are shown. The image also sets `upload_max_filesize` and `post_max_size` to 64M and `memory_limit` to 256M.
