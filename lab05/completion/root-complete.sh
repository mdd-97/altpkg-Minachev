#!/bin/bash
# Выполнять в UTM под root после просмотра сценария.
set -euo pipefail
[[ $(id -u) = 0 && $(hostname) = rdsu-alt && $(uname -m) = x86_64 ]] || exit 1
base=/home/user/rdsu-lab05
lab=$base/repo/lab05
stamp=$(date +%Y%m%d-%H%M%S)
backup=/root/lab05-completion-$stamp
mkdir -m 700 "$backup"
cp -a /etc/apt/sources.list /etc/apt/sources.list.d "$backup/"
export LC_ALL=C
# Подключение компонента debuginfo без обновления установленных пакетов.
(
set -x
printf '%s\n' 'rpm [p11] http://ftp.altlinux.org/pub/distributions/ALTLinux p11/branch/x86_64 debuginfo' > /etc/apt/sources.list.d/lab05-debuginfo.list
apt-get update
apt-cache search '^libexpat-debuginfo$'
apt-get install -y libexpat-debuginfo gdb gdbserver
rpm -q libexpat-debuginfo glibc-core-debuginfo gdb
rpm -ql libexpat-debuginfo
runuser -u user -- env DEBUGINFOD_URLS= gdb -nx -batch -iex 'set debuginfod enabled off' -ex 'info sources' /lib64/libexpat.so.1
printf '%s\n' 'host debuginfo exit=0'
) > "$lab/logs/task04-host-debuginfo.log" 2>&1
# Yama: изменение только на время опыта, восстановление при любом выходе.
original=$(sysctl -n kernel.yama.ptrace_scope)
[[ $original = 1 ]] || { echo "Ожидалось Yama=1, получено $original; остановлено"; exit 1; }
launcher=
target=
cleanup() {
    sysctl -w "kernel.yama.ptrace_scope=$original"
    if [[ -n $target ]]; then kill "$target" 2>/dev/null || :; fi
    if [[ -n $launcher ]]; then wait "$launcher" 2>/dev/null || :; fi
}
trap cleanup EXIT
{
set -x
rm -f "$base/yama-sleep.pid"
runuser -u user -- bash -c 'sleep 300 & child=$!; echo "$child" > "$HOME/rdsu-lab05/yama-sleep.pid"; wait "$child"' &
launcher=$!
for i in {1..30}; do [[ -s $base/yama-sleep.pid ]] && break; sleep 0.1; done
target=$(cat "$base/yama-sleep.pid")
ps -o pid,user,comm -p "$target"
attach() {
    local phase=$1 rc=0
    runuser -u user -- env DEBUGINFOD_URLS= gdb -nx -batch -iex 'set debuginfod enabled off' -ex "attach $target" -ex 'info threads' -ex detach > "$base/yama-$phase.log" 2>&1 || rc=$?
    cat "$base/yama-$phase.log"
    echo "$phase exit=$rc"
    if [[ $phase = allowed ]]; then
        [[ $rc = 0 ]]
        grep -E '0x[0-9a-f]+ in|\[New LWP|\[Thread debugging' "$base/yama-$phase.log"
    else
        [[ $rc != 0 ]]
        grep -i 'Operation not permitted' "$base/yama-$phase.log"
    fi
}
sysctl kernel.yama.ptrace_scope
attach denied
sysctl -w kernel.yama.ptrace_scope=0
attach allowed
sysctl -w "kernel.yama.ptrace_scope=$original"
attach restored
sysctl kernel.yama.ptrace_scope
echo 'yama cycle exit=0'
} > "$lab/logs/task07-yama-cycle.log" 2>&1
chown user:user "$lab/logs/task04-host-debuginfo.log" "$lab/logs/task07-yama-cycle.log"
echo "Готово. Резервная копия APT: $backup"
echo "Журналы: $lab/logs/task04-host-debuginfo.log и task07-yama-cycle.log"
