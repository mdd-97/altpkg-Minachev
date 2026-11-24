#!/bin/bash
set -euo pipefail
test "$(hostname)" = rdsu-alt
base=$HOME/rdsu-lab05
lab=$base/repo/lab05
cd "$lab/sources"
export PATH="$base/user-tools/bin:$base/user-tools/root/usr/bin:$PATH" DEBUGINFOD_URLS= LC_ALL=C
make debug
server=
trap 'if [[ -n $server ]]; then kill "$server" 2>/dev/null || :; wait "$server" 2>/dev/null || :; fi' EXIT
gdbserver --once 127.0.0.1:0 ./progression-debug 1 9 2 > ../logs/task07-server.log 2>&1 &
server=$!
port=
for trial in {1..30}; do
    port=$(awk '/Listening on port/ {print $NF; exit}' ../logs/task07-server.log)
    [[ -z $port ]] || break
    kill -0 "$server"
    sleep 0.2
done
[[ $port =~ ^[0-9]+$ ]]
gdb -nx -batch -ex 'set debuginfod enabled off' -ex "target remote 127.0.0.1:$port" \
    -ex 'break emit' -ex 'continue' -ex 'info args' -ex 'list' -ex 'disable 1' -ex continue \
    ./progression-debug > ../logs/task07-client.log 2>&1
wait "$server"
server=
grep -E 'Listening on port|Remote debugging from host' ../logs/task07-server.log
grep -E 'Breakpoint 1,|index =|value =|exited normally' ../logs/task07-client.log
