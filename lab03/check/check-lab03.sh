#!/bin/bash
set -uo pipefail
export LC_ALL=C
lab=$(cd "$(dirname "$0")/.." && pwd)
temp=$(mktemp -d) || exit 1
trap 'rm -rf -- "$temp"' EXIT
cd "$temp" || exit 1
cp "$lab"/sources/{Makefile,*.c,*.h} . || exit 1
pass=0
fail=0
skip=0
check() {
    local name=$1
    shift
    if "$@"; then printf 'PASS %s\n' "$name"; ((pass+=1))
    else printf 'FAIL %s\n' "$name"; ((fail+=1)); fi
}
skip_check() { printf 'SKIP %s\n' "$1"; ((skip+=1)); }
matches_log() { grep -Eq -- "$2" "$lab/logs/$1"; }
help_output() {
    ./rdsu-args-objects > stdout 2> stderr &&
    test ! -s stdout && cmp stderr "$lab/check/help.expected"
}
argument_output() {
    ./rdsu-args-objects alpha beta gamma > three &&
    test "$(wc -l < three)" -eq 5 && cmp three "$lab/check/three.expected"
}
cpp_output() { cc -E main.c | grep -F 'void print_arg(const char *arg);' > /dev/null; }
object_files() { test "$(file main.o output.o counter.o | grep -c 'relocatable')" -eq 3; }
counter_symbols() {
    nm main.o output.o counter.o > symbols &&
    test "$(grep -Ec ' [BD] counter$' symbols)" -eq 1 &&
    test "$(grep -Ec ' U counter$' symbols)" -eq 2
}
external_symbols() {
    nm -g --defined-only main.o output.o counter.o | awk 'NF == 3 {print $3}' | sort -u > defined &&
    nm -u main.o output.o counter.o | awk '$1 == "U" {print $2}' | sort -u > undefined &&
    comm -23 undefined defined > external &&
    libc=$(ldd ./rdsu-args-objects | awk '$1 == "libc.so.6" {print $3}') &&
    test -f "$libc" &&
    nm -D --defined-only "$libc" | awk 'NF == 3 {sub(/@.*/, "", $3); print $3}' | sort -u > libc-symbols &&
    comm -23 external libc-symbols > unresolved && test ! -s unresolved
}
resolved() { ldd "$1" > dependencies && grep -Fq libc.so.6 dependencies && ! grep -Fq 'not found' dependencies; }
selective_make() {
    touch main.c && make -n rdsu-args-objects > dry &&
    test "$(wc -l < dry)" -eq 2 &&
    grep -Eq -- '-c .*main.c' dry && make rdsu-args-objects > /dev/null
}
header_make() {
    touch args.h && make -n rdsu-args-objects CFLAGS=-O0 > dry &&
    test "$(grep -c -- '-O0.*-c' dry)" -eq 3
}
archive_members() { ar t librdsuargs.a > members && printf 'output.o\ncounter.o\n' | cmp - members; }
static_output() { ./rdsu-args-static alpha beta gamma > static && cmp three static; }
shared_symbols() {
    nm -D --defined-only librdsuargs.so > dynamic &&
    test "$(grep -Ec ' [TDB] (print_arg|print_help|counter)$' dynamic)" -eq 3
}
missing_library() {
    local status=0
    env -u LD_LIBRARY_PATH ./rdsu-args-shared alpha > missing 2>&1 || status=$?
    test "$status" -ne 0 && grep -Eq 'librdsuargs.so.*cannot open shared object file' missing &&
    env -u LD_LIBRARY_PATH ldd ./rdsu-args-shared > dependencies &&
    grep -Eq 'librdsuargs.so.*not found' dependencies
}
shared_output() {
    export LD_LIBRARY_PATH=$PWD
    ./rdsu-args-shared alpha beta gamma > shared && cmp static shared && resolved ./rdsu-args-shared
}
test_matrix() { make test > make-test.log 2>&1 && test "$(find . -name '*.out' | wc -l)" -eq 9; }
distclean() {
    make distclean > /dev/null &&
    test -z "$(find . -maxdepth 1 \( -name '*.o' -o -name '*.out' -o -name '*.a' -o -name '*.so' -o -name 'rdsu-args-*' \) -print)"
}
check 'Сборка трёх вариантов' make -j1
check '01 Справка в stderr' help_output
check '01 Формат и пять строк' argument_output
check '01 Препроцессирование' cpp_output
check '01 Объектные файлы' object_files
check '01 Трассировка компоновщика' matches_log task01.log 'execve\(".*(/ld|collect2)"'
check '01 Повторное определение' matches_log task01.log 'multiple definition.*duplicate'
check '02 Единственное определение счётчика' counter_symbols
check '02 Все внешние символы найдены в libc' external_symbols
check '02 Динамические зависимости разрешены' resolved ./rdsu-args-objects
check '03 Пересборка одного модуля' selective_make
check '03 Заголовок и CFLAGS' header_make
check '03 Встроенное правило' matches_log task03.log '^%.o: %.c'
check '03 Фиктивная цель' matches_log task03.log "clean.*up to date"
check '04 Два модуля в архиве' archive_members
check '04 Совпадение статического варианта' static_output
check '04 Диагностика отсутствия статической libc' matches_log task04.log 'cannot find -lc|cannot find libc'
check "04 Полная статическая компоновка" matches_log task04-static-hasher.log "^static comparison exit=0$"
check '05 Диагностика без PIC' matches_log task05.log 'relocation.*(cannot|can not)'
check '05 Экспорт библиотеки' shared_symbols
check '05 Библиотека не найдена' missing_library
check "05 Загрузка библиотеки и совпадение вывода" shared_output
unset LD_LIBRARY_PATH
check '06 Девять совпадающих выводов' test_matrix
check '06 Отказ при расхождении' matches_log task06.log '\.out differ(:| in)'
check '06 Полная очистка' distclean
if [[ -n ${LAB03_HASHER_WORKDIR:-} && -d $LAB03_HASHER_WORKDIR/chroot ]]; then
    check '07 Установленный RPM в Hasher' "$lab/env/check-rpm.sh" "$LAB03_HASHER_WORKDIR"
else
    skip_check '07 Установка и запуск в Hasher (задайте LAB03_HASHER_WORKDIR)'
fi
printf 'PASS=%s FAIL=%s SKIP=%s\n' "$pass" "$fail" "$skip"
((fail == 0))
