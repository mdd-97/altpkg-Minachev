#!/bin/bash
set -euxo pipefail
export LC_ALL=C
root=$(cd "$(dirname "$0")/.." && pwd)
cd "$root/sources"
make debug
tmp=$(mktemp -d)
trap 'rm -rf -- "$tmp"' EXIT
cp progression-debug "$tmp/stripped"
strip --strip-all "$tmp/stripped"
stat -c '%s %n' progression-debug "$tmp/stripped"
file progression-debug "$tmp/stripped"
test "$(stat -c %s "$tmp/stripped")" -lt "$(stat -c %s progression-debug)"
./progression-debug 1 9 2 > "$tmp/expected"
"$tmp/stripped" 1 9 2 > "$tmp/observed"
diff -u "$tmp/expected" "$tmp/observed"
if command -v gdb >/dev/null; then
    DEBUGINFOD_URLS= gdb -nx -batch -ex 'info sources' progression-debug
    rc=0
    DEBUGINFOD_URLS= gdb -nx -batch -ex 'info sources' "$tmp/stripped" > "$tmp/gdb-stripped" 2>&1 || rc=$?
    cat "$tmp/gdb-stripped"
    printf 'stripped GDB exit=%s\n' "$rc"
    grep -F 'No symbol table is loaded' "$tmp/gdb-stripped"
fi
