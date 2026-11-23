#!/bin/bash
set -eu -o pipefail
out=${1:?output directory}
ps -eo pid=,comm=,user= > "$out/ps-snapshot.txt"
awk '{print $1, $2}' "$out/ps-snapshot.txt" > "$out/ps-command.txt"
awk '{print $1, $3}' "$out/ps-snapshot.txt" > "$out/ps-user.txt"
LC_ALL=C sort -k1,1 "$out/ps-command.txt" > "$out/ps-command.sorted"
LC_ALL=C sort -k1,1 "$out/ps-user.txt" > "$out/ps-user.sorted"
LC_ALL=C join --check-order "$out/ps-command.sorted" "$out/ps-user.sorted" > "$out/ps-joined.txt"
test "$(wc -l < "$out/ps-joined.txt")" -eq "$(wc -l < "$out/ps-snapshot.txt")"
cut -d ' ' -f 2 "$out/ps-joined.txt" | tr '[:lower:]' '[:upper:]' > "$out/ps-names.txt"
wc -l "$out/ps-joined.txt"
head -3 "$out/ps-names.txt"
tail -3 "$out/ps-names.txt"
for cmd in hexdump od xxd; do rpm -qf "$(command -v "$cmd")"; done
printf 'ALT\n' > "$out/bytes.txt"
hexdump -C "$out/bytes.txt"
od -An -tx1 "$out/bytes.txt"
xxd "$out/bytes.txt"
