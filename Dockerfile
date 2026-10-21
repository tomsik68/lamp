# syntax=docker/dockerfile:1
ARG PHP_VERSION=8.4
FROM php:${PHP_VERSION}-apache-trixie

ARG TARGETARCH
# Pinned downloads, bumped with checksums by scripts/update-pins.sh
ARG S6_OVERLAY_VERSION=3.2.3.2
ARG S6_OVERLAY_NOARCH_SHA256=5379750ed30a84bbd2e2dd74847ba6b5bd29cd0b2e3ea2ec58049b57eb2eda12
ARG S6_OVERLAY_X86_64_SHA256=e6befcc96a437a3831386ecfc51808c5d3e939dc5fe3c02ae9284599e8aa2408
ARG S6_OVERLAY_AARCH64_SHA256=b17f17a82e7a515c682a91edaf2ffdabb73f891981b6c1fd712115693a2f8b4c

ARG PHPMYADMIN_VERSION=5.2.3
ARG PHPMYADMIN_SHA256=57881348297c4412f86c410547cf76b4d8a236574dd2c6b7d6a2beebe7fc44e3

ARG COMPOSER_VERSION=2.10.3
ARG COMPOSER_SHA256=7a2d379d5b8ffdaa028580ef26494c36d2feef4b178d3dd1473a4dbc5e17c8d6

ENV DEBIAN_FRONTEND=noninteractive
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# MariaDB from Debian, plus build deps for the PHP extensions
# hadolint ignore=SC2086
RUN set -eux; \
  buildDeps="libfreetype-dev libjpeg62-turbo-dev libpng-dev libwebp-dev \
      libicu-dev libzip-dev libxml2-dev libmagickwand-dev libmemcached-dev zlib1g-dev"; \
  apt-get update; \
  apt-get install -y --no-install-recommends mariadb-server mariadb-client xz-utils $buildDeps; \
  docker-php-ext-configure gd --with-freetype --with-jpeg --with-webp; \
  docker-php-ext-install -j"$(nproc)" mysqli pdo_mysql gd intl zip bcmath exif soap; \
  # opcache is compiled in from PHP 8.5 on
  if ! php -m | grep -qx 'Zend OPcache'; then docker-php-ext-install opcache; fi; \
  pecl install imagick redis memcached xdebug; \
  # xdebug is enabled but stays off unless XDEBUG_MODE asks for it
  docker-php-ext-enable imagick redis memcached xdebug; \
  # keep the runtime libraries, drop the -dev packages
  savedLibs="$(ldd "$(php-config --extension-dir)"/*.so \
    | awk '/=>/ { so = $(NF-1); if (index(so, "/usr/local/") == 1) next; gsub("^/(usr/)?", "", so); printf "*%s\n", so }' \
    | sort -u | xargs -r dpkg-query --search | cut -d: -f1 | sort -u)"; \
  apt-mark manual $savedLibs >/dev/null; \
  apt-get purge -y --auto-remove $buildDeps; \
  rm -rf /var/lib/apt/lists/* /tmp/pear; \
  # fail the build if any extension lost a library
  ! php -m 2>&1 | grep -i warning

# s6-overlay
RUN set -eu; \
  case "$TARGETARCH" in \
    amd64) s6arch=x86_64;  s6sum="$S6_OVERLAY_X86_64_SHA256" ;; \
    arm64) s6arch=aarch64; s6sum="$S6_OVERLAY_AARCH64_SHA256" ;; \
    *) echo "unsupported arch: $TARGETARCH" >&2; exit 1 ;; \
  esac; \
  base="https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}"; \
  curl -fsSLo /tmp/noarch.tar.xz "$base/s6-overlay-noarch.tar.xz"; \
  curl -fsSLo /tmp/arch.tar.xz "$base/s6-overlay-${s6arch}.tar.xz"; \
  echo "$S6_OVERLAY_NOARCH_SHA256  /tmp/noarch.tar.xz" | sha256sum -c -; \
  echo "$s6sum  /tmp/arch.tar.xz" | sha256sum -c -; \
  tar -C / -Jxpf /tmp/noarch.tar.xz; \
  tar -C / -Jxpf /tmp/arch.tar.xz; \
  rm /tmp/*.tar.xz

# phpMyAdmin
RUN set -eu; \
  curl -fsSLo /tmp/pma.tar.xz "https://files.phpmyadmin.net/phpMyAdmin/${PHPMYADMIN_VERSION}/phpMyAdmin-${PHPMYADMIN_VERSION}-all-languages.tar.xz"; \
  echo "$PHPMYADMIN_SHA256  /tmp/pma.tar.xz" | sha256sum -c -; \
  mkdir -p /usr/share/phpmyadmin; \
  tar -C /usr/share/phpmyadmin --strip-components=1 -Jxf /tmp/pma.tar.xz; \
  rm -rf /tmp/pma.tar.xz /usr/share/phpmyadmin/setup; \
  mkdir -p /var/lib/phpmyadmin/tmp; \
  chown -R www-data:www-data /var/lib/phpmyadmin

# composer
RUN set -eu; \
  curl -fsSLo /usr/local/bin/composer "https://getcomposer.org/download/${COMPOSER_VERSION}/composer.phar"; \
  echo "$COMPOSER_SHA256  /usr/local/bin/composer" | sha256sum -c -; \
  chmod +x /usr/local/bin/composer

COPY rootfs/ /

RUN set -eu; \
  a2enmod rewrite; \
  a2enconf lamp; \
  cp "$PHP_INI_DIR/php.ini-development" "$PHP_INI_DIR/php.ini"; \
  # user drop-ins in /etc/mysql/conf.d must win over Debian's mariadb.conf.d defaults
  echo '!includedir /etc/mysql/conf.d/' >> /etc/mysql/my.cnf; \
  # compatibility paths from tomsik68/xampp
  ln -s /var/www/html /www; \
  mkdir -p /opt/lampp; \
  ln -s /var/www/html /opt/lampp/htdocs; \
  rm -rf /var/lib/mysql/*; \
  mkdir -p /run/mysqld; \
  chown mysql:mysql /var/lib/mysql /run/mysqld

ENV MARIADB_ROOT_PASSWORD=root \
    PHPMYADMIN=1 \
    XDEBUG_MODE=off \
    PUID=33 \
    PGID=33 \
    S6_BEHAVIOUR_IF_STAGE2_FAILS=2 \
    S6_CMD_WAIT_FOR_SERVICES_MAXTIME=0 \
    S6_KEEP_ENV=1

VOLUME ["/var/lib/mysql"]
EXPOSE 80 3306

# the check needs shell operators
# hadolint ignore=DL3025
HEALTHCHECK --interval=30s --timeout=5s --start-period=60s \
  CMD curl -sS -o /dev/null http://127.0.0.1/ && mariadb-admin --protocol=socket ping >/dev/null || exit 1

# s6-overlay shuts down on SIGTERM; the php:apache base sets SIGWINCH
STOPSIGNAL SIGTERM
ENTRYPOINT ["/init"]
