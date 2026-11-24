#!/bin/bash
set -euxo pipefail
export LC_ALL=C
root=$(cd "$(dirname "$0")/.." && pwd)
cd "$root/sources"
make all
printf '0\n1\n2\n' | diff -u - <(./progression 2)
printf '2\n3\n4\n' | diff -u - <(./progression 2 4)
printf '5\n3\n1\n' | diff -u - <(./progression 5 1 -2)
./progression | grep '^Usage:'
for object in progression.o libprogression.so progression-debug; do
    file "$object"
    readelf -h "$object"
done
readelf -h progression.o | grep 'REL (Relocatable file)'
readelf -h libprogression.so | grep -E 'DYN \(Shared object file\)'
readelf -h progression-debug | grep 'EXEC (Executable file)'
header=$(readelf -h progression-debug)
expected_ph=$(awk '/Number of program headers:/ {print $NF}' <<< "$header")
expected_sh=$(awk '/Number of section headers:/ {print $NF}' <<< "$header")
actual_ph=$(readelf -Wl progression-debug | awk '/^  [A-Z][A-Z_0-9]+ +0x/ {n++} END {print n+0}')
actual_sh=$(readelf -WS progression-debug | grep -Ec '^  \[ *[0-9]+\]')
printf 'program headers expected=%s actual=%s\nsection headers expected=%s actual=%s\n' "$expected_ph" "$actual_ph" "$expected_sh" "$actual_sh"
test "$expected_ph" = "$actual_ph"
test "$expected_sh" = "$actual_sh"
file_id=$(file progression-debug | sed -nE 's/.*BuildID\[sha1\]=([0-9a-f]+).*/\1/p')
note_id=$(readelf -n progression-debug | awk '/Build ID:/ {print $NF}')
printf 'file Build ID=%s\nreadelf Build ID=%s\n' "$file_id" "$note_id"
test -n "$file_id"
test "$file_id" = "$note_id"
entry=$(awk '/Entry point address:/ {print $NF}' <<< "$header")
objdump -d progression-debug | awk -v address="${entry#0x}" '$1 ~ ("^0*" address ":$") {print; found=1} END {exit !found}'
readelf -WS progression-debug | grep '\.debug_'
stat -c '%s %n' progression progression-debug progression-opt
