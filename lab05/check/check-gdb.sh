#!/bin/bash
set -euo pipefail
export LC_ALL=C
root=$(cd "$(dirname "$0")/.." && pwd)
cd "$root/sources"
tmp=$(mktemp -d)
trap 'rm -rf -- "$tmp"' EXIT
for scenario in conditional range; do
    for run in 1 2 3; do
        gdb -nx --quiet --batch -x "../gdb/$scenario.gdb" ./progression-debug > "$tmp/session"
        grep '^LAB05 ' "$tmp/session" > "$tmp/extract"
        diff -u "../check/$scenario.expected" "$tmp/extract"
        printf '%s run %s: %s matching lines\n' "$scenario" "$run" "$(wc -l < "$tmp/extract")"
    done
done
