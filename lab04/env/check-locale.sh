#!/bin/bash
set -eu -o pipefail
out=${1:?output directory}
printf 'Z upper\na lower\n' > "$out"/locale-left.txt
printf 'Z 1\na 2\n' > "$out"/locale-right.txt
LC_ALL=C sort -k1,1 -o "$out"/locale-left.txt "$out"/locale-left.txt
LC_ALL=C sort -k1,1 -o "$out"/locale-right.txt "$out"/locale-right.txt
LC_ALL=ru_RU.utf8 sort -k1,1 "$out"/locale-left.txt
rc=0
LC_ALL=ru_RU.utf8 join --check-order "$out"/locale-left.txt "$out"/locale-right.txt > "$out"/locale-national.txt || rc=$?
printf 'national join exit=%s\n' "$rc"
test "$rc" = 1
LC_ALL=C join --check-order "$out"/locale-left.txt "$out"/locale-right.txt | tee "$out"/locale-C.txt
printf 'C join exit=0\n'
