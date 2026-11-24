#!/bin/bash
set -euxo pipefail
export LC_ALL=C
root=$(cd "$(dirname "$0")/.." && pwd)
cd "$root/sources"
tmp=$(mktemp -d)
trap 'rm -rf -- "$tmp"' EXIT
cc -O0 -g -Wall -Wextra -fsyntax-only warning-demo.c
cc -O0 -g -Wall -Wextra -c warning-demo.c -o "$tmp/warning.o" 2>"$tmp/warning"
cat "$tmp/warning"
grep -i uninitialized "$tmp/warning"
cc -O0 -g -Wall -Wextra stack-demo.c -o "$tmp/before"
cc -O0 -g -Wall -Wextra -DFIXED stack-demo.c -o "$tmp/after"
printf '15\n' > "$tmp/expected"
"$tmp/before" > "$tmp/before.out"
"$tmp/after" > "$tmp/after.out"
rc=0
diff -u "$tmp/expected" "$tmp/before.out" || rc=$?
test "$rc" = 1
echo "before diff exit=$rc"
diff -u "$tmp/expected" "$tmp/after.out"
echo 'after diff exit=0'
if command -v gdb >/dev/null; then
    gdb -nx --quiet --batch -x ../gdb/stack.gdb "$tmp/before"
fi
