#!/usr/bin/env bash
# A failed refresh must record qmd's own exit status in refresh.failed.
set -euo pipefail

hook="$(cd "$(dirname "$0")/.." && pwd)/hooks/qmd-refresh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

mkdir -p "$tmp/bin" "$tmp/cache/qmd"
printf '#!/bin/sh\nexit 3\n' >"$tmp/bin/qmd"
chmod +x "$tmp/bin/qmd"
touch "$tmp/cache/qmd/refresh.dirty"

PATH="$tmp/bin:$PATH" XDG_CACHE_HOME="$tmp/cache" "$hook" --run >/dev/null 2>&1

failed=$(cat "$tmp/cache/qmd/refresh.failed")
if [[ "$failed" != *"exited 3" ]]; then
  echo "FAIL: refresh.failed says '$failed', want it to end in 'exited 3'"
  exit 1
fi
echo "PASS"
