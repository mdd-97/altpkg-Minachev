#!/bin/bash
set -euo pipefail
export LC_ALL=C
lab=$(cd "$(dirname "$0")/.." && pwd)
test "$(hostname)" = rdsu-alt
work=$(mktemp -d)
trap 'rm -rf -- "$work"' EXIT
cc -O0 -g -Wall -Wextra -fno-stack-protector "$lab/sources/memory-demo.c" -o "$work/before" 2> "$work/warnings"
cat "$work/warnings"
grep -i uninitialized "$work/warnings"
cc -O0 -g -Wall -Wextra -DFIXED -fno-stack-protector "$lab/sources/memory-demo.c" -o "$work/after"
printf '15\n' > "$work/expected"
"$work/before" > "$work/before.out"
"$work/after" > "$work/after.out"
echo 'BEFORE:'; cat "$work/before.out"
echo 'AFTER:'; cat "$work/after.out"
rc=0
diff -u "$work/expected" "$work/before.out" || rc=$?
echo "before diff exit=$rc"
test "$rc" = 1
diff -u "$work/expected" "$work/after.out"
echo 'after diff exit=0'
gdb -nx --quiet --batch -x "$lab/gdb/memory.gdb" "$work/before" > "$work/gdb" 2>&1 || { cat "$work/gdb"; exit 1; }
cat "$work/gdb"
grep -F '$1 = 1' "$work/gdb"
grep -F '$2 = 1' "$work/gdb"
grep -E '^#2 .*main' "$work/gdb"
echo 'memory check exit=0'
