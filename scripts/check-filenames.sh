#!/usr/bin/env bash
# Fails on tracked file names that aren't portable: characters outside
# [A-Za-z0-9._-], path parts starting with `-` or ending with `.`, and names
# that collide on case-insensitive filesystems.
set -euo pipefail

status=0
bad=$(git ls-files | grep -vE '^[A-Za-z0-9._/-]+$' || true)
bad+=$'\n'$(git ls-files | grep -E '(^|/)-|\.(/|$)' || true)
bad=$(sed '/^$/d' <<< "$bad")
if [ -n "$bad" ]; then
  echo "Unportable file names (use only A-Z a-z 0-9 . _ -, no leading - or trailing .):"
  echo "$bad"
  status=1
fi

collisions=$(git ls-files | sort -f | uniq -di)
if [ -n "$collisions" ]; then
  echo "File names that collide on case-insensitive filesystems:"
  git ls-files | grep -iFxf <(echo "$collisions")
  status=1
fi

exit $status
