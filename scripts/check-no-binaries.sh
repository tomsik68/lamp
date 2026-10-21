#!/usr/bin/env bash
# Fails if a tracked file is binary (as git sees it) and isn't listed in
# .binary-allowlist.
set -euo pipefail

empty_tree=$(git hash-object -t tree /dev/null)
binaries=$(git diff --numstat "$empty_tree" HEAD | awk -F'\t' '$1 == "-" { print $3 }')
[ -n "$binaries" ] || exit 0

allowed=$(grep -vE '^(#|$)' .binary-allowlist || true)
status=0
while IFS= read -r f; do
  ok=0
  for pattern in $allowed; do
    # shellcheck disable=SC2053 # the pattern is a glob on purpose
    [[ $f == $pattern ]] && ok=1
  done
  if [ $ok = 0 ]; then
    echo "Binary file not in .binary-allowlist: $f"
    status=1
  fi
done <<< "$binaries"
exit $status
