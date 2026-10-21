#!/usr/bin/env bash
# Bump the pinned s6-overlay, Adminer and composer downloads in the
# Dockerfile to their latest releases, with checksums.
set -euo pipefail
cd "$(dirname "$0")/.."

gh_latest() { curl -fsSL "https://api.github.com/repos/$1/releases/latest" | jq -r .tag_name | sed 's/^v//'; }
sum() { curl -fsSL "$1" | awk '{print $1}'; }
set_arg() { sed -i "s|^ARG $1=.*|ARG $1=$2|" Dockerfile; }

s6=$(gh_latest just-containers/s6-overlay)
base="https://github.com/just-containers/s6-overlay/releases/download/v$s6"
set_arg S6_OVERLAY_VERSION "$s6"
set_arg S6_OVERLAY_NOARCH_SHA256 "$(sum "$base/s6-overlay-noarch.tar.xz.sha256")"
set_arg S6_OVERLAY_X86_64_SHA256 "$(sum "$base/s6-overlay-x86_64.tar.xz.sha256")"
set_arg S6_OVERLAY_AARCH64_SHA256 "$(sum "$base/s6-overlay-aarch64.tar.xz.sha256")"

# Adminer publishes no checksums; hash the file at bump time. Its bumps are
# reviewed by hand (see update-pins.yml).
adminer=$(gh_latest vrana/adminer)
set_arg ADMINER_VERSION "$adminer"
set_arg ADMINER_SHA256 "$(curl -fsSL "https://github.com/vrana/adminer/releases/download/v$adminer/adminer-$adminer-mysql.php" | sha256sum | awk '{print $1}')"

composer=$(gh_latest composer/composer)
set_arg COMPOSER_VERSION "$composer"
set_arg COMPOSER_SHA256 "$(sum "https://getcomposer.org/download/$composer/composer.phar.sha256sum")"

echo "s6-overlay $s6, Adminer $adminer, composer $composer"
