#!/bin/bash
set -euo pipefail
test "$(hostname)" = rdsu-alt
base=$HOME/rdsu-lab05
cd "$base/repo/lab05"
export PATH="$base/user-tools/bin:$PATH" LC_ALL=C
lib=/lib64/libexpat.so.1
id=$(readelf -n "$lib" | awk '/Build ID:/ {print $NF}')
debug=
for candidate in "$base"/debuginfo.*/root/usr/lib/debug/.build-id/"${id:0:2}/${id:2}.debug"; do
    if [[ -r $candidate ]]; then debug=$candidate; break; fi
done
test -r "$debug"
tmp=$(mktemp -d "$base/debug-http.XXXXXX")
mkdir -p "$tmp/web/buildid/$id" "$tmp/cache" "$tmp/empty-cache"
cp -L "$debug" "$tmp/web/buildid/$id/debuginfo"
python3 -u -m http.server --bind 127.0.0.1 --directory "$tmp/web" 0 > "$tmp/http.log" 2>&1 &
pid=$!
trap 'kill "$pid" 2>/dev/null || :; wait "$pid" 2>/dev/null || :' EXIT
port=
for i in {1..25}; do
    port=$(sed -nE 's/.* port ([0-9]+) .*/\1/p' "$tmp/http.log" | head -1)
    [[ -z $port ]] || break
    sleep 0.2
done
[[ $port =~ ^[0-9]+$ ]]
{
    printf 'Build ID=%s\nDEBUGINFOD_URLS=http://127.0.0.1:%s\n' "$id" "$port"
    DEBUGINFOD_CACHE_PATH="$tmp/cache" DEBUGINFOD_URLS="http://127.0.0.1:$port" DEBUGINFOD_PROGRESS=1 \
        gdb -nx -batch -iex 'set debuginfod enabled on' -ex 'info sources' "$lib" > "$tmp/positive" 2>&1
    grep -Ei 'Downloading|Reading symbols from' "$tmp/positive"
    grep -oE '[^, ]*xmlparse\.c' "$tmp/positive" | head -3
    test -s "$tmp/cache/$id/debuginfo"
    stat -c 'cache bytes=%s path=%n' "$tmp/cache/$id/debuginfo"
    cmp "$tmp/web/buildid/$id/debuginfo" "$tmp/cache/$id/debuginfo"
    DEBUGINFOD_CACHE_PATH="$tmp/empty-cache" DEBUGINFOD_URLS= gdb -nx -batch -iex 'set debuginfod enabled on' -ex 'info sources' "$lib" > "$tmp/negative" 2>&1 || :
    grep -F 'No symbol table is loaded' "$tmp/negative"
    test ! -e "$tmp/empty-cache/$id/debuginfo"
    cat "$tmp/http.log"
    echo 'local debuginfod protocol check exit=0'
} > logs/task04-local-debuginfod.log 2>&1
cat logs/task04-local-debuginfod.log
