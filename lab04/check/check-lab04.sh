#!/bin/bash
set -uo pipefail
export LC_ALL=C
lab=$(cd "$(dirname "$0")/.." && pwd)
cd "$lab" || exit 1
work=$(mktemp -d) || exit 1
trap 'rm -rf -- "$work"' EXIT
pass=0 fail=0 skip=0

check() {
    local name=$1
    shift
    if "$@" >"$work/result" 2>&1; then
        printf 'PASS %s\n' "$name"
        ((pass+=1))
    else
        printf 'FAIL %s\n' "$name"
        cat "$work/result"
        ((fail+=1))
    fi
}
skip() {
    printf 'SKIP %s\n' "$1"
    ((skip+=1))
}

shell_checks() {
    local result=$work/shell
    bash env/check-shell.sh > "$result" 2>&1 &&
        grep -F 'read is a shell builtin' "$result" &&
        grep -F 'll is aliased' "$result" &&
        grep -Fx 'before=<>' "$result" &&
        grep -Fx 'exported=<parent>' "$result" &&
        grep -Fx 'parent=<parent>' "$result" &&
        grep -Fx 'short prefix=two/three' "$result" &&
        grep -Fx 'long prefix=three' "$result" &&
        grep -Fx 'short suffix=one/two' "$result" &&
        grep -Fx 'long suffix=one' "$result" &&
        grep -Fx 'diff exit=1' "$result" &&
        grep -Fx 'pipeline exit=0' "$result"
}
text_checks() {
    mkdir -p "$work/text"
    env/check-text.sh "$work/text" > "$work/text.log" &&
        grep -E '^util-linux-' "$work/text.log" &&
        grep -E '^coreutils-' "$work/text.log" &&
        grep -E '^xxd-' "$work/text.log" &&
        grep -cE '(41 4c 54 0a|414c 540a)' "$work/text.log" | grep -Fx 3
}
cli_checks() {
    export XDG_CONFIG_HOME=$work/config
    sources/rdsu-tasks add 'Check package contents' &&
        sources/rdsu-tasks add 'Build the task list' &&
        sources/rdsu-tasks add 'Review notes' &&
        sources/rdsu-tasks done 2 &&
        sources/rdsu-tasks list > "$work/tasks" &&
        diff -u check/tasks.expected "$work/tasks" &&
        test "$(wc -l < "$XDG_CONFIG_HOME/rdsu-tasks/tasks.tsv")" = 3 &&
        test "$(sources/rdsu-tasks-1.1 count)" = 2
}
package_checks() {
    local artifact=$LAB04_RPM workdir=$LAB04_HASHER_WORKDIR
    rpm -qpl "$artifact" | grep -Fx /usr/bin/rdsu-tasks &&
        rpm -qp --requires "$artifact" > "$work/rpm-requires" &&
        grep -Fx /bin/bash "$work/rpm-requires" &&
        grep -Fx dialog "$work/rpm-requires" &&
        grep -Fx coreutils "$work/rpm-requires" &&
        hsh-run -- "$workdir" /bin/bash -ec '
            tmp=$(mktemp -d)
            trap "rm -rf -- \"$tmp\"" EXIT
            export XDG_CONFIG_HOME=$tmp/config
            rdsu-tasks add "Installed task"
            rdsu-tasks list | grep -Fx "1. Installed task"
        '
}
gear_checks() {
    local repo=$1
    test "$(git -C "$repo" show 1.0-alt1:.gear/rules)" = 'copy: rdsu-tasks' &&
        git -C "$repo" rev-parse --verify refs/tags/1.1-alt2 &&
        git -C "$repo" show 1.1-alt2:rdsu-tasks.spec | grep -F 'Add a command to count open tasks.'
}

check '01 Классы команд, переменная, подстановки и конвейер' shell_checks
check '02 Уборка после выхода, ошибки и сигналов' python3 env/check-temp.py "$lab/sources/temp-demo.sh"
check '03 Объединение, обработка текста и байты' text_checks
if locale -a | grep -Fxq ru_RU.utf8; then
    check '03 Диагностика join при разном порядке сортировки' bash env/check-locale.sh "$work"
else
    skip '03 Локаль ru_RU.utf8 отсутствует'
fi
check '04 Добавление, отметка, пробелы в тексте и подсчёт' cli_checks
if [[ -n ${LAB04_RPM:-} && -n ${LAB04_HASHER_WORKDIR:-} ]]; then
    check '03 moreutils сохраняет результат и ставит метку времени' grep -Fx BETA logs/task03-moreutils.log
    check '04 Заголовок меню и очистка после выхода' grep -Fx UI-cleanup-ok logs/task04-menu.log
    check '05 Зависимости RPM и запуск в Hasher' package_checks
else
    skip '05 Для проверки установленного RPM задай LAB04_RPM и LAB04_HASHER_WORKDIR'
fi
if [[ -n ${LAB04_GEAR_REPO:-} ]]; then
    check '06–07 Правила экспорта и оба тега GEAR' gear_checks "$LAB04_GEAR_REPO"
    check '06 Совпадение метаданных, файлов и зависимостей RPM' grep -Fx 'GEAR comparison exit=0' logs/task06-compare.log
    check '07 Старая версия отвергает count' grep -Fx 'old count exit=2' logs/task07-installed-cycle.log
else
    skip '06–07 Для проверки локального GEAR задай LAB04_GEAR_REPO'
fi
if [[ -n ${LAB04_GEAR_URL:-} ]]; then
    if git clone --quiet "$LAB04_GEAR_URL" "$work/gear"; then
        check '07 Теги в свежем клоне публичного GEAR' gear_checks "$work/gear"
    else
        skip '07 Публичный GEAR недоступен'
    fi
else
    skip '07 Для сетевой проверки задай LAB04_GEAR_URL'
fi
printf 'PASS=%d FAIL=%d SKIP=%d\n' "$pass" "$fail" "$skip"
((fail == 0))
