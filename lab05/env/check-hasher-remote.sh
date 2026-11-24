#!/bin/bash
set -euo pipefail
test "$(hostname)" = rdsu-alt
b=$HOME/rdsu-lab05
cd "$b/repo/lab05"
export LC_ALL=C
server=$b/hasher
client=$b/hasher-client
for n in {1..70}; do
    [[ -x "$client/chroot/usr/bin/gdb" ]] && break
    sleep 5
done
test -x "$client/chroot/usr/bin/gdb"
{
    id
    ls -ld "$server/chroot" "$client/chroot"
    for endpoint in server client; do
        if [[ $endpoint == server ]]; then number=1; work=$server; else number=2; work=$client; fi
        hsh-run --number="$number" --rooter -- "$work" /bin/bash -ec 'umask 022; cat > /etc/resolv.conf' < /etc/resolv.conf
        printf '%s resolver: ' "$endpoint"
        share_network=1 timeout 8 hsh-run --number="$number" -- "$work" /usr/bin/getent ahostsv4 ftp.altlinux.org || echo 'DNS query not confirmed'
    done
} > logs/task07-hasher-network.log 2>&1
hsh-run --number=2 -- "$client" /bin/bash -ec 'cat > /tmp/lab05-progression.c' < sources/progression.c
hsh-run -- "$server" /bin/bash -ec 'cat /tmp/lab05-progression' |
    hsh-run --number=2 -- "$client" /bin/bash -ec 'cat > /tmp/lab05-progression'
server_pid=
trap 'if [[ -n $server_pid ]]; then kill "$server_pid" 2>/dev/null || :; wait "$server_pid" 2>/dev/null || :; fi' EXIT
share_network=1 timeout 45 hsh-run --mountpoints=/proc -- "$server" /bin/bash -ec '
    exec gdbserver --once 127.0.0.1:0 /tmp/lab05-progression 1 9 2
' > logs/task07-hasher-server.log 2>&1 &
server_pid=$!
port=
for n in {1..100}; do
    port=$(awk '/Listening on port/ {print $NF; exit}' logs/task07-hasher-server.log)
    [[ -z $port ]] || break
    kill -0 "$server_pid"
    sleep 0.2
done
[[ $port =~ ^[0-9]+$ ]]
share_network=1 timeout 35 hsh-run --number=2 --mountpoints=/proc -- "$client" /bin/bash -ec '
    DEBUGINFOD_URLS= gdb -nx -batch -ex "set debuginfod enabled off" -ex "target remote 127.0.0.1:$1" \
        -ex "break emit" -ex continue -ex list -ex "info args" -ex "disable 1" -ex continue /tmp/lab05-progression
' bash "$port" > logs/task07-hasher-client.log 2>&1
wait "$server_pid"
server_pid=
grep -E 'Listening on port|Remote debugging from host' logs/task07-hasher-server.log
grep -E 'Breakpoint 1, emit|index =|value =|exited normally' logs/task07-hasher-client.log
grep -q '^Breakpoint 1, emit' logs/task07-hasher-client.log
