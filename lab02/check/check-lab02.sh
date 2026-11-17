#!/usr/bin/env bash
set -u
export LC_ALL=C

cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." || exit 2
logs=lab02/logs
tmp=$(mktemp -d) || exit 2
trap 'rm -rf -- "$tmp"' EXIT

passed=0
failed=0
skipped=0

check() {
    local name=$1
    shift
    if "$@" > "$tmp/check.out" 2>&1; then
        printf 'PASS %s\n' "$name"
        passed=$((passed + 1))
    else
        printf 'FAIL %s\n' "$name"
        cat "$tmp/check.out"
        failed=$((failed + 1))
    fi
}

skip() {
    printf 'SKIP %s (окружение недоступно)\n' "$1"
    skipped=$((skipped + 1))
}

terminal_controls() {
    local key
    for key in 'intr = ^C' 'erase = ^?' 'kill = ^U' 'eof = ^D'; do
        grep -Fq "$key" "$logs/stty-before.txt" || return 1
    done
    grep -Eq '^[[:space:]]*03 7f 15 04[[:space:]]*$' "$logs/control-codes.txt"
}

terminfo_diff() {
    local vt="$logs/infocmp-vt100.txt" xt="$logs/infocmp-xterm-256color.txt"
    test -s "$vt" && test -s "$xt" && test -s "$logs/infocmp-diff.txt" &&
        test "$(wc -l < "$vt")" -ne "$(wc -l < "$xt")"
}

manual_build() {
    if gcc -Wall -O2 lab02/sources/Show.c -o "$tmp/Show" > "$tmp/link-error" 2>&1; then
        return 1
    fi
    grep -q 'undefined reference' "$tmp/link-error" &&
        test -s "$logs/build-no-lib.log" &&
        gcc -Wall -O2 lab02/sources/Show.c -o "$tmp/Show" -lncurses
}

show_error() {
    if "$tmp/Show" "$@" > "$tmp/stdout" 2> "$tmp/stderr"; then
        return 1
    fi
    test ! -s "$tmp/stdout" && test -s "$tmp/stderr"
}

show_pty() {
    local first_line
    IFS= read -r first_line < lab02/check/sample.txt && test -n "$first_line" || return 1
    export CHECK_TMP="$tmp"
    { sleep 2; printf ' '; sleep 1; printf ' '; sleep 1; printf 'q'; } |
        TERM=xterm timeout 15s script -qec '
            stty rows 24 cols 80 &&
            stty -g > "$CHECK_TMP/tty-before" || exit 2
            "$CHECK_TMP/Show" lab02/check/sample.txt
            show_rc=$?
            stty -g > "$CHECK_TMP/tty-after" || exit 2
            exit "$show_rc"
        ' "$tmp/show-session.log" > /dev/null || return 1
    grep -aFq 'lab02/check/sample.txt' "$tmp/show-session.log" &&
        grep -aFq -- "$first_line" "$tmp/show-session.log" &&
        cmp -s "$tmp/tty-before" "$tmp/tty-after"
}

make_cycle() (
    mkdir "$tmp/make" &&
    cp lab02/sources/{Makefile,Show.c} "$tmp/make/" &&
    cd "$tmp/make" &&
    make && test -x Show && test -f Show.o &&
    make -q Show && make &&
    sleep 1 && touch Show.c &&
    { make -q Show; test "$?" -eq 1; } &&
    make && make -q Show &&
    make clean && test ! -e Show && test ! -e Show.o
)

make_error() (
    cd "$tmp/make" || exit 1
    local makefile=$1 expected=$2
    if make -f "$makefile" > "$tmp/make-error" 2>&1; then
        exit 1
    fi
    grep -Fq -- "$expected" "$tmp/make-error" || {
        cat "$tmp/make-error"
        exit 1
    }
)

make_spaces() {
    sed $'s/^\t/        /' "$tmp/make/Makefile" > "$tmp/make/spaces.mk" &&
        make_error spaces.mk 'missing separator'
}

make_missing() {
    sed 's/^Show\.o: Show\.c$/Show.o: Show.c missing.h/' \
        "$tmp/make/Makefile" > "$tmp/make/missing.mk" &&
        make_error missing.mk 'missing.h'
}

show_archive() {
    printf '%s\n' show-1.0/ show-1.0/Makefile show-1.0/Show.c > "$tmp/expected" &&
        tar -tzf lab02/sources/show-1.0.tar.gz > "$tmp/archive" &&
        sort "$tmp/archive" > "$tmp/archive.sorted" &&
        diff -u "$tmp/expected" "$tmp/archive.sorted"
}

show_dependencies() {
    grep -Fq 'libncurses.so.6()(64bit)' "$logs/show-rpm-requires.log" &&
        ! grep -q 'libncurses-devel' "$logs/show-rpm-requires.log" &&
        grep -Eq '^BuildRequires:[[:space:]]+libncurses-devel' lab02/specs/show.spec &&
        ! grep -Eq '^Requires:.*(libncurses|libtinfo)' lab02/specs/show.spec
}

runtime_packages() {
    local dir="$HOME/hasher-lab02-runtime"
    hsh-run "$dir" -- rpm -q show libncurses6 &&
        hsh-run "$dir" -- rpm -q libncurses-devel > "$tmp/devel" 2>&1
    local rc=$?
    test "$rc" -eq 1 && grep -Fq 'package libncurses-devel is not installed' "$tmp/devel"
}

repo_packages() {
    local arch repo
    arch=$(uname -m) || return 1
    repo="$HOME/hasher-lab02-show/repo"
    test -s "$repo/SRPMS.hasher/show-1.0-alt1.src.rpm" &&
        test -s "$repo/$arch/RPMS.hasher/show-1.0-alt1.$arch.rpm" &&
        test -s "$repo/$arch/RPMS.hasher/show-debuginfo-1.0-alt1.$arch.rpm"
}

package_file_lists() {
    grep -Fxq '/usr/bin/Show' "$logs/show-package-files.log" &&
        test "$(wc -l < "$logs/show-package-files.log")" -eq 1 &&
        grep -Fxq '/usr/lib/debug/usr/bin/Show.debug' "$logs/show-debuginfo-files.log" &&
        sort -u "$logs/show-package-files.log" > "$tmp/main.sorted" &&
        sort -u "$logs/show-debuginfo-files.log" > "$tmp/debug.sorted" &&
        comm -12 "$tmp/main.sorted" "$tmp/debug.sorted" > "$tmp/common" &&
        test ! -s "$tmp/common"
}

check '1. Байты очистки экрана' cmp "$logs/clear-printf.bin" "$logs/clear-tput-x.bin"
check '1. Коды intr, erase, kill, eof' terminal_controls
check '1. Различия описаний terminfo' terminfo_diff
check '1. Двойная печать' grep -aPq '([[:alnum:]])\x08\1' "$logs/ls-nroff.txt"
check '1. Подчёркивание' grep -aPq '_\x08[[:alnum:]]' "$logs/ls-nroff.txt"
check '1. Ограничения TERM=dumb' grep -Fq 'у dumb нет cup' "$logs/term-dumb.txt"

check '2. Ручная сборка с ncurses и без неё' manual_build
check '2. Ошибка при запуске без аргумента' show_error
check '2. Ошибка при открытии отсутствующего файла' show_error "$tmp/no-such-file"
check '2. Сеанс Show и восстановление параметров терминала' show_pty

check '3. Сборка, пересборка и очистка' make_cycle
check '3. TAB в рецептах' grep -q $'^\t' lab02/sources/Makefile
check '3. Пробелы вместо TAB' make_spaces
check '3. Отсутствующий реквизит' make_missing

check '4. Конфигурация сопровождающего' grep -Eq '^packager=.+' lab02/env/hasher-config
check '4. Отказ sisyphus_check' grep -Fq 'sisyphus_check failed' "$logs/hsh-before-packager.log"
check '5. Структура архива Show' show_archive
check '5. Сборка RPM дошла до make' grep -Eq '^\+ make([[:space:]]|$)' "$logs/hsh-show-build.log"
check '5. Совпадение экранов Show' diff -aq \
    "$logs/show-local-24x80.screen" "$logs/show-rpm-24x80.screen"
check '6. Эксплуатационные зависимости RPM' show_dependencies
check '6. Установка без libncurses6 отклонена' grep -Fq \
    'libncurses.so.6()(64bit)' "$logs/show-install-without-ncurses.log"
check '6. Установка после добавления libncurses6' grep -Fq \
    'Код установки после добавления libncurses6: 0' "$logs/show-install-with-ncurses-retry.log"
check '7. Состав пакетов и отсутствие общих путей' package_file_lists

printf '\nПроверки окружений hasher\n'
if command -v hsh-run >/dev/null && test -d "$HOME/hasher-lab02/chroot"; then
    check '4. Макрос %packager внутри окружения' \
        hsh-run "$HOME/hasher-lab02" -- grep -Eq '^%packager[[:space:]]' /usr/src/.rpmmacros
else
    skip '4. Макрос %packager внутри окружения'
fi

if command -v hsh-run >/dev/null && test -d "$HOME/hasher-lab02-runtime/chroot"; then
    check '6. Show и libncurses6 установлены, devel отсутствует' runtime_packages
else
    skip '6. Проверка установленных пакетов'
fi

if test -d "$HOME/hasher-lab02-show/repo"; then
    check '7. Двоичный, исходный и отладочный RPM в репозитории' repo_packages
else
    skip '7. Проверка локального репозитория RPM'
fi

printf '\nИтого: PASS=%s FAIL=%s SKIP=%s\n' "$passed" "$failed" "$skipped"
test "$failed" -eq 0
