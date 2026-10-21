# Migrating from tomsik68/xampp

`tomsik68/xampp` is deprecated. Its images ship PHP versions that no longer get security fixes, and they are no longer rebuilt. `tomsik68/lamp` replaces it. It still runs as one container from one `docker run`, but it is built on the official PHP image and rebuilt automatically when security fixes land.

Most setups move over in about ten minutes: dump your databases, start the new image, and restore them.

## 1. Pick the new tag

PHP versions before 8.4 aren't offered, because they no longer get security fixes. Every old tag maps to `8.4`:

| You run `tomsik68/xampp:…` | Use `tomsik68/lamp:…` |
|---|---|
| `5`, `5.6.40` | `8.4` (read the [PHP 5.6 notes](#from-php-56) first) |
| `7`, `7.3.7`, `7.4.x` | `8.4` (read the [PHP 7.x notes](#from-php-7x)) |
| `8`, `latest`, `8.0.x`, `8.1.x`, `8.2.x` | `8.4`, or `latest` (8.5) if your code is ready for it |

## 2. Dump your databases

Keep the old container running and dump **only your own databases**. Don't use `--all-databases`, because that would overwrite the new image's users and root setup.

```sh
docker exec OLD_CONTAINER /opt/lampp/bin/mysqldump -uroot \
  --databases mydb otherdb > dump.sql
```

To list the databases you have, run `docker exec OLD_CONTAINER /opt/lampp/bin/mysql -uroot -e 'SHOW DATABASES'`. Skip `mysql`, `information_schema`, `performance_schema`, `phpmyadmin` and `test`.

If you created MySQL users for your app, write down their names and grants. You'll recreate them in step 4.

## 3. Start the new container

Change your `docker run` command:

```diff
-docker run -d -p 41061:22 -p 80:80 -p 3306:3306 \
-  -v ~/my_web_pages:/www \
-  tomsik68/xampp:8
+docker run -d -p 80:80 -p 3306:3306 \
+  -v ~/my_web_pages:/var/www/html \
+  -v lamp-db:/var/lib/mysql \
+  tomsik68/lamp:8.4
```

- **Ports:** 80 and 3306 are unchanged. Remove the `-p …:22` mapping, because there's no SSH.
- **Web root:** mount your code at `/var/www/html`. Mounting at `/www` still works because it's a symlink, but `/var/www/html` is the real path.
- **URLs:** pages are served at `http://localhost/` and also at `http://localhost/www/`, as before. phpMyAdmin is still at `/phpmyadmin/`.
- **Data:** add a volume for `/var/lib/mysql`, or your databases disappear with the container.

## 4. Restore

```sh
docker exec -i NEW_CONTAINER mariadb -uroot -proot < dump.sql
```

Then recreate your app's users, for example:

```sh
docker exec NEW_CONTAINER mariadb -uroot -proot -e \
  "CREATE USER 'app'@'%' IDENTIFIED BY 'secret'; GRANT ALL ON mydb.* TO 'app'@'%';"
```

For a single user and database, you can set `MARIADB_DATABASE`, `MARIADB_USER` and `MARIADB_PASSWORD` on the first start instead.

Your old container and its data are untouched, so you can roll back by starting it again.

## Gotchas

- **The root password is now `root`.** XAMPP's root had an empty password, so update any connection strings that use `root` with no password. You can choose another password with `MARIADB_ROOT_PASSWORD` on the first start.
- **No SSH.** Use `docker exec -it NEW_CONTAINER bash` for a shell, and `docker cp` to copy files.
- **No XAMPP dashboard.** The `/dashboard` page is gone. phpMyAdmin is at `/phpmyadmin/`.
- **Config files moved.**

  | XAMPP | lamp |
  |---|---|
  | `/opt/lampp/htdocs` | `/var/www/html` (the old path is a symlink) |
  | `/opt/lampp/etc/php.ini` | drop-in `*.ini` files in `/usr/local/etc/php/conf.d/` |
  | `/opt/lampp/etc/my.cnf` | drop-in `*.cnf` files in `/etc/mysql/conf.d/` |
  | `/opt/lampp/apache2/conf.d/` | `/etc/apache2/conf-enabled/` |
  | `/opt/lampp/bin/mysql` | `mariadb` (on `PATH`) |

  See [configuration](configuration.md).
- **Missing a PHP extension?** See [extending the image](extending.md).
- **Mounting old data files doesn't work.** If you mount XAMPP's `/opt/lampp/var/mysql` directory, the container refuses to start. Use dump and restore instead.

### Advanced: upgrading data files in place

If dumping isn't practical, you can mount a **copy** of the old data directory at `/var/lib/mysql` and set `MARIADB_AUTO_UPGRADE=1`. MariaDB then upgrades the files in place. This is one-way, so the old image can't read them afterwards. Upgrades from XAMPP's MariaDB 10.4 straight to 11.8 are less tested, so if it fails, go through a `mariadb:10.11` container first. Dump and restore remains the recommended path.

## Upgrading your PHP code

### From PHP 5.6

This is the big jump: two major versions. Expect to fix removed `mysql_*` functions (use mysqli or PDO), constructors named after the class, `each()`, and many warnings that are now errors. Work through the php.net migration guides in order: [7.0](https://www.php.net/manual/en/migration70.php), [7.1](https://www.php.net/manual/en/migration71.php), [7.2](https://www.php.net/manual/en/migration72.php), [7.3](https://www.php.net/manual/en/migration73.php), [7.4](https://www.php.net/manual/en/migration74.php), then the 8.x guides below.

### From PHP 7.x

PHP 8.0 is the main step. It brought stricter type errors, changed comparisons between strings and numbers, and removed long-deprecated features. Read [8.0](https://www.php.net/manual/en/migration80.php), then the 8.x guides below.

### From PHP 8.x

Mostly deprecations. Read the guides after your current version: [8.1](https://www.php.net/manual/en/migration81.php), [8.2](https://www.php.net/manual/en/migration82.php), [8.3](https://www.php.net/manual/en/migration83.php), [8.4](https://www.php.net/manual/en/migration84.php), [8.5](https://www.php.net/manual/en/migration85.php).
