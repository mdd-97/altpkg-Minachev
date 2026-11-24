#!/bin/bash
set -euo pipefail
test "$(hostname)" = rdsu-alt
base=$HOME/rdsu-lab05
cd "$base/repo/lab05"
export PATH="$base/user-tools/bin:$PATH" LC_ALL=C
lib=/lib64/libexpat.so.1
tmp=$(mktemp -d "$base/debuginfo.XXXXXX")
rpm_name=$(rpm -q --qf '%{NAME}-debuginfo-%{VERSION}-%{RELEASE}.%{ARCH}.rpm' libexpat)
url="https://ftp.altlinux.org/pub/distributions/ALTLinux/p11/branch/x86_64/RPMS.debuginfo/$rpm_name"
{
    set -x
    curl -fsSL --retry 2 --max-time 100 "$url" -o "$tmp/$rpm_name"
    rpm -qpl "$tmp/$rpm_name"
    mkdir "$tmp/root"
    rpm2cpio "$tmp/$rpm_name" | (cd "$tmp/root"; cpio -id --quiet)
    DEBUGINFOD_URLS= gdb -nx -batch -iex 'set debuginfod enabled off' -ex 'info sources' "$lib" > "$tmp/baseline" 2>&1 || :
    cat "$tmp/baseline"
    DEBUGINFOD_URLS= gdb -nx -batch -iex "set debug-file-directory $tmp/root/usr/lib/debug" -iex 'set debuginfod enabled off' -ex 'info sources' "$lib" > "$tmp/local" 2>&1
    grep -oE '[^, ]*xmlparse\.c' "$tmp/local" | head -3
} > logs/task04-package.log 2>&1
{
    set -x
    mkdir "$tmp/cache" "$tmp/empty-cache"
    DEBUGINFOD_CACHE_PATH="$tmp/cache" DEBUGINFOD_URLS=https://debuginfod.altlinux.org DEBUGINFOD_MAXTIME=35 DEBUGINFOD_PROGRESS=1 \
      timeout 70 gdb -nx -batch -iex 'set debuginfod enabled on' -ex 'info sources' "$lib" > "$tmp/server" 2>&1 || :
    grep -Ei 'Downloading|xmlparse.c|debuginfod|symbol table' "$tmp/server" | cut -c1-220
    find "$tmp/cache" -type f -printf '%s %P\n'
    DEBUGINFOD_CACHE_PATH="$tmp/empty-cache" DEBUGINFOD_URLS= gdb -nx -batch -iex 'set debuginfod enabled on' -ex 'info sources' "$lib" > "$tmp/empty" 2>&1 || :
    cat "$tmp/empty"
    find "$tmp/empty-cache" -type f -printf '%s %P\n'
} > logs/task04-debuginfod.log 2>&1
tail -6 logs/task04-debuginfod.log
