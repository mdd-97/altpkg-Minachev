#!/bin/bash
set -uo pipefail
lab=$(cd "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d) || exit 1
trap 'rm -rf -- "$tmp"' EXIT
pass=0 fail=0 skip=0
check() {
    local name=$1
    shift
    if "$@" > "$tmp/log" 2>&1; then
        printf 'PASS %s\n' "$name"
        ((pass+=1))
    else
        printf 'FAIL %s\n' "$name"
        cat "$tmp/log"
        ((fail+=1))
    fi
}
skip() {
    printf 'SKIP %s\n' "$1"
    ((skip+=1))
}
check '01 ELF, Build ID, точка входа, вывод программы' bash "$lab/env/check-elf.sh"
check '03 Предупреждение и исправление ошибки параметра' bash "$lab/env/check-stack.sh"
check '04 Уменьшение ELF и сохранение вывода после strip' bash "$lab/env/check-strip.sh"
if command -v gdb >/dev/null; then
    check '02 Три режима и поиск исходников' bash "$lab/env/check-build-modes.sh"
    check '05 Пакетные сценарии GDB и три повторения' make -C "$lab/sources" check
else
    skip '02 Отладчик GDB недоступен'
    skip '05 Отладчик GDB недоступен'
fi
if [[ -r "$lab/logs/task04-local-debuginfod.log" ]]; then
    check '04 Загрузка символов по Build ID с локального сервера' grep -Fx 'local debuginfod protocol check exit=0' "$lab/logs/task04-local-debuginfod.log"
else
    skip '04 Нет протокола загрузки символов'
fi
if [[ -r "$lab/logs/task06-proc-confirmed.log" ]]; then
    check '06 Точка останова в Hasher со смонтированным /proc' grep -E '^Breakpoint 1, emit' "$lab/logs/task06-proc-confirmed.log"
else
    skip '06 Нет протокола Hasher'
fi
if [[ -r "$lab/logs/task07-hasher-client.log" ]]; then
    check '07 Клиент и сервер в разных окружениях Hasher' grep -E '^Breakpoint 1, emit' "$lab/logs/task07-hasher-client.log"
else
    skip '07 Сеанс между Hasher не подтверждён'
fi
if [[ -r "$lab/logs/task04-installed-with-dependencies.log" ]]; then
    check '04 Системные символы из установленного RPM' grep -Fx 'installed debuginfo exit=0' "$lab/logs/task04-installed-with-dependencies.log"
else
    skip '04 Нет протокола установки debuginfo'
fi
if [[ -r "$lab/logs/task07-attach-child.log" ]]; then
    check '07 Разрешённое подключение к дочернему процессу' grep -Fx 'child attach exit=0' "$lab/logs/task07-attach-child.log"
else
    skip '07 Нет протокола подключения к дочернему процессу'
fi
printf 'PASS=%d FAIL=%d SKIP=%d\n' "$pass" "$fail" "$skip"
((fail == 0))
