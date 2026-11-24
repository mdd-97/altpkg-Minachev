#!/bin/bash
set -euxo pipefail
export LC_ALL=C DEBUGINFOD_URLS=
root=$(cd "$(dirname "$0")/.." && pwd)
cd "$root/sources"
make all
tmp=$(mktemp -d)
trap 'rm -rf -- "$tmp"' EXIT
for program in progression progression-debug progression-opt; do
    gdb -nx -batch -ex 'set debuginfod enabled off' -ex 'break main' -ex 'run 1 9 2' \
        -ex 'list' -ex 'info locals' -ex 'next' -ex 'step' "./$program" || :
done
mkdir "$tmp/build" "$tmp/moved"
cp progression.c "$tmp/build/"
(
    cd "$tmp/build"
    cc -O0 -g -Wall -Wextra -o progression progression.c
    gdb -nx -batch -ex 'list main' ./progression
)
mv "$tmp/build/progression" "$tmp/moved/progression"
mv "$tmp/build" "$tmp/hidden"
(
    cd "$tmp/moved"
    gdb -nx -batch -ex 'list main' ./progression
) || :
mv "$tmp/hidden" "$tmp/build"
(
    cd "$tmp/build"
    gdb -nx -batch -ex 'list main' "$tmp/moved/progression"
)
