# tomsik68/lamp

Apache, PHP and MariaDB, with phpMyAdmin, in **one container**. Start it with one `docker run`, with no compose file needed.

This is a **development** image. It is the successor to [`tomsik68/xampp`](https://hub.docker.com/r/tomsik68/xampp). Coming from there? Read the [migration guide](https://github.com/tomsik68/lamp/blob/main/docs/migrating-from-xampp.md).

## Quick start

```sh
docker run -d --name lamp \
  -p 80:80 -p 3306:3306 \
  -v "$PWD":/var/www/html \
  -v lamp-db:/var/lib/mysql \
  tomsik68/lamp
```

- Your site: <http://localhost/>
- phpMyAdmin: <http://localhost/phpmyadmin/> (user `root`, password `root`)
- MariaDB: `localhost:3306` from the host, or `localhost` from PHP inside the container.

> [!WARNING]
> The default MariaDB login is **root / root**, and root can connect from outside the container. That's convenient on your laptop, but don't publish port 3306 on a network you don't trust. To choose a different password, set `-e MARIADB_ROOT_PASSWORD=…` on the **first** start. See [configuration](https://github.com/tomsik68/lamp/blob/main/docs/configuration.md).

## What's inside

- The official [`php:X.Y-apache`](https://hub.docker.com/_/php) image on Debian trixie, with `mod_rewrite` and `AllowOverride All`.
- MariaDB 11.8 from Debian, and phpMyAdmin at `/phpmyadmin`.
- PHP extensions: mysqli, pdo_mysql, gd, intl, zip, bcmath, exif, opcache, imagick, soap, redis, memcached, plus xdebug (installed but off by default).
- `composer`.
- No SSH. Use `docker exec -it lamp bash` and `docker cp`.

## Tags

| Tag | PHP | Status |
|---|---|---|
| `8.5`, `8`, `latest`, `8.5-trixie`, `8.5.X` | 8.5 | supported |
| `8.4`, `8.4-trixie`, `8.4.X` | 8.4 | supported |

- **Only PHP branches that upstream still supports are built.** When a branch reaches end of life, its tags stay on Docker Hub, frozen. They are marked unsupported here and never rebuilt.
- Images are rebuilt automatically when the base image or a Debian package gets an update, so pulling `8.4` again picks up security fixes.
- Images are published for `linux/amd64` and `linux/arm64`, and are mirrored at `ghcr.io/tomsik68/lamp`.

## Documentation

- [Configuration](https://github.com/tomsik68/lamp/blob/main/docs/configuration.md): environment variables and config drop-ins.
- [Extending the image](https://github.com/tomsik68/lamp/blob/main/docs/extending.md): extra PHP extensions, Valkey and memcached servers.
- [Migrating from tomsik68/xampp](https://github.com/tomsik68/lamp/blob/main/docs/migrating-from-xampp.md)

## License

MIT
