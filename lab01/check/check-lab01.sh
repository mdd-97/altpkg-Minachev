#!/bin/bash
# check-lab01.sh — функциональная проверка лабораторной работы 1 (задания 2, 4–7)
# Запуск из корня клона репозитория: bash lab01/check/check-lab01.sh
# Рабочий каталог hasher можно переопределить: HSH=/путь bash lab01/check/check-lab01.sh
set -u

LAB=$(cd "$(dirname "$0")/.." && pwd)   # каталог lab01 в клоне
HSH=${HSH:-$HOME/hasher}                # рабочий каталог hasher
PKG=altpkg-minachev
PKGS_COURSE="rpm-build rpmdevtools hasher hasher-priv git-core gcc make openssh-clients tree diffutils coreutils mc"

PASS=0
FAIL=0
check() {   # $1 — наименование проверки, далее — функция-проверка
    local name=$1
    shift
    if "$@" >/dev/null 2>&1; then
        printf 'PASS  %s\n' "$name"
        PASS=$((PASS + 1))
    else
        printf 'FAIL  %s\n' "$name"
        FAIL=$((FAIL + 1))
    fi
}
specval() { sed -n "s/^$1:[[:space:]]*//p" "$2" | head -n1; }   # значение поля преамбулы spec-файла

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# ---------- Подготовка: окружение hasher и сборка пакетов из spec-файлов клона ----------
echo "== Подготовка (окружение hasher, сборка пакетов из клона)"
[ -d "$HSH/chroot" ] || hsh --init "$HSH" >"$TMP/init.log" 2>&1
hsh-run "$HSH" -- which tree >/dev/null 2>&1 || hsh-install "$HSH" tree mc >"$TMP/install.log" 2>&1
hsh-run --rooter "$HSH" -- rpm -e "$PKG" >/dev/null 2>&1   # убрать пакет, если остался от прошлого запуска

build() {   # $1 — каталог дерева сборки, $2 — spec-файл
    mkdir -p "$1"/BUILD "$1"/SOURCES "$1"/SPECS "$1"/RPMS "$1"/SRPMS "$1"/tmp
    cp "$LAB"/sources/*.sh "$1/SOURCES/" 2>/dev/null
    rpmbuild -ba --define "_topdir $1" --define "_tmppath $1/tmp" "$2" >"$1/build.log" 2>&1
}
T5=$TMP/t5
T6=$TMP/t6
build "$T5" "$LAB/specs/$PKG-task5.spec"; RC5=$?
build "$T6" "$LAB/specs/$PKG.spec";       RC6=$?
P5=$(find "$T5/RPMS" -name '*.rpm' 2>/dev/null | head -n1)
P6=$(find "$T6/RPMS" -name '*.rpm' 2>/dev/null | head -n1)
AUTO=$(find "$HSH/repo" -path '*RPMS.hasher*' -name "$PKG-*.noarch.rpm" 2>/dev/null | head -n1)

# ---------- Задание 2 ----------
t2_repo()    { apt-repo list | grep -q 'p11'; }
t2_pkgs()    { local p rc=0; for p in $PKGS_COURSE; do rpm -q "$p" || rc=1; done; return $rc; }
t2_service() { systemctl is-enabled -q hasher-privd && systemctl is-active -q hasher-privd; }
t2_files()   { [ -s "$LAB/env/repos.txt" ] && [ -s "$LAB/env/host-packages.txt" ]; }
t2_count()   { [ "$(wc -l < "$LAB/env/host-packages.txt")" -eq "$(rpm -qa | wc -l)" ]; }

# ---------- Задание 3: проверки будут добавлены после согласования пакета ----------

# ---------- Задание 4 ----------
t4_groups() { local g u; g=" $(id -nG) "; u=$(id -un)
              [[ $g == *" hashman "* && $g == *" ${u}_a "* && $g == *" ${u}_b "* ]]; }
t4_log()    { grep -q 'Created RPM build directory tree' "$LAB/logs/hsh-init.log"; }
t4_config() { grep -q '^packager=' "$LAB/env/hasher-config" && grep -q '^no_sisyphus_check=' "$LAB/env/hasher-config"; }
t4_roles()  { [ "$(hsh-run "$HSH" -- id -un)" = builder ] && [ "$(hsh-run --rooter "$HSH" -- id -un)" = root ]; }
t4_tree()   { local t d; t=$(hsh-run "$HSH" -- tree -d /usr/src/RPM) || return 1
              for d in BUILD SOURCES SPECS RPMS SRPMS; do grep -qw "$d" <<< "$t" || return 1; done; }
t4_which()  { hsh-run "$HSH" -- which tree; }

# ---------- Задание 5 ----------
t5_build()   { [ "$RC5" -eq 0 ] && [ "$(find "$T5/RPMS" -name '*.rpm' | wc -l)" -eq 1 ] \
               && [ "$(find "$T5/SRPMS" -name '*.src.rpm' | wc -l)" -eq 1 ]; }
t5_nofiles() { [ -n "$P5" ] && [ -z "$(rpm -qpl "$P5" | grep -v '^(contains no files)$')" ]; }
t5_meta()    { local s=$LAB/specs/$PKG-task5.spec
               [ -n "$P5" ] && [ "$(rpm -qp --queryformat '%{NAME}|%{VERSION}|%{RELEASE}|%{LICENSE}' "$P5")" = \
                 "$(specval Name "$s")|$(specval Version "$s")|$(specval Release "$s")|$(specval License "$s")" ]; }
t5_install() { local rc
               [ -n "$P5" ] && cp "$P5" "$HSH/chroot/.in/" \
               && hsh-run --rooter "$HSH" -- rpm -i "/.in/$(basename "$P5")" \
               && hsh-run "$HSH" -- rpm -q "$PKG" \
               && ! hsh-run "$HSH" -- which "$PKG"
               rc=$?
               hsh-run --rooter "$HSH" -- rpm -e "$PKG" >/dev/null 2>&1
               return $rc; }

# ---------- Задание 6 ----------
t6_onefile()    { [ -n "$P6" ] && [ "$(rpm -qpl "$P6" | wc -l)" -eq 1 ] && rpm -qpl "$P6" | grep -q '^/usr/bin/'; }
t6_noexplicit() { ! grep -qiE '^(Requires|PreReq)(\([^)]*\))?:' "$LAB/specs/$PKG.spec"; }
t6_requires()   { [ -n "$P6" ] && diff <(rpm -qp --requires "$P6" | sort) <(sort "$LAB/logs/task6-requires.txt"); }
t6_run()        { [ -n "$P6" ] && cp "$P6" "$HSH/chroot/.in/" \
                  && hsh-run --rooter "$HSH" -- rpm -i "/.in/$(basename "$P6")" \
                  && hsh-run "$HSH" -- "$PKG" | diff - "$LAB/check/expected.txt"; }
t6_removed()    { hsh-run --rooter "$HSH" -- rpm -e "$PKG" \
                  && ! hsh-run "$HSH" -- which "$PKG" \
                  && ! hsh-run "$HSH" -- sh -c "$PKG"; }

# ---------- Задание 7 ----------
# Сравнивается пакет из репозитория hasher (автоматическая сборка) и пакет, собранный из spec-файла клона
nvr()        { rpm -qp --queryformat '%{NAME}-%{VERSION}-%{RELEASE}' "$1"; }
t7_exists()  { [ -n "$AUTO" ] && [ -n "$P6" ] && [ "$(nvr "$AUTO")" = "$(nvr "$P6")" ]; }
t7_files()   { [ -n "$AUTO" ] && diff <(rpm -qpl "$AUTO" | sort) <(rpm -qpl "$P6" | sort); }
t7_sha()     { local s
               [ -n "$AUTO" ] && [ -n "$P6" ] || return 1
               s=$(sha256sum < "$LAB/sources/$PKG.sh") || return 1
               mkdir -p "$TMP/xa" "$TMP/xm" || return 1
               (cd "$TMP/xa" && rpm2cpio "$AUTO" | cpio -idm) || return 1
               (cd "$TMP/xm" && rpm2cpio "$P6" | cpio -idm) || return 1
               [ "$(sha256sum < "$TMP/xa/usr/bin/$PKG")" = "$s" ] && [ "$(sha256sum < "$TMP/xm/usr/bin/$PKG")" = "$s" ]; }
t7_less()    { [ "$(wc -l < "$LAB/logs/task7-hasher-packages.txt")" -lt "$(wc -l < "$LAB/logs/task7-host-packages.txt")" ]; }
t7_onlyhost(){ comm -23 "$LAB/logs/task7-host-packages.txt" "$LAB/logs/task7-hasher-packages.txt" > "$TMP/only-host" \
               && [ -s "$TMP/only-host" ] && grep -qE '^(hasher|rpmdevtools|git-core)-[0-9]' "$TMP/only-host"; }

# ---------- Запуск проверок ----------
echo "== Задание 2. Окружение хост-системы"
check "2.1 apt-repo содержит источники ветки p11"                t2_repo
check "2.2 rpm -q: все пакеты курса установлены"                 t2_pkgs
check "2.3 hasher-privd: enabled и active"                       t2_service
check "2.4 env/repos.txt и env/host-packages.txt непусты"       t2_files
check "2.5 строк в host-packages.txt = rpm -qa | wc -l"          t2_count

echo "== Задание 4. Изолированное сборочное окружение"
check "4.1 id: группы hashman, <user>_a, <user>_b"               t4_groups
check "4.2 журнал развёртывания: создано дерево сборки RPM"      t4_log
check "4.3 конфигурация hasher сохранена в env/"                 t4_config
check "4.4 id -un: builder у сборщика, root у rooter"            t4_roles
check "4.5 tree: BUILD, SOURCES, SPECS, RPMS, SRPMS"             t4_tree
check "4.6 which tree в окружении"                               t4_which

echo "== Задание 5. Пакет минимальной структуры"
check "5.1 rpmbuild -ba: один RPM и один SRPM"                   t5_build
check "5.2 rpm -qpl: перечень файлов пуст"                       t5_nofiles
check "5.3 rpm -qpi: имя, версия, релиз, лицензия из преамбулы"  t5_meta
check "5.4 установка: rpm -q находит, which не находит"          t5_install

echo "== Задание 6. Пакет со сценарием"
check "6.1 rpm -qpl: ровно один файл в /usr/bin"                 t6_onefile
check "6.2 в spec-файле нет явных Requires"                      t6_noexplicit
check "6.3 rpm -qp --requires совпадает с журналом"              t6_requires
check "6.4 запуск по имени: diff с expected.txt пуст"            t6_run
check "6.5 после удаления: which и запуск — ненулевой код"       t6_removed

echo "== Задание 7. Воспроизводимость сборки"
check "7.1 автосборка hasher: то же имя-версия-релиз"            t7_exists
check "7.2 diff перечней файлов пуст"                            t7_files
check "7.3 sha256 исходного файла из обоих пакетов совпадает"    t7_sha
check "7.4 пакетов в окружении меньше, чем на хосте"             t7_less
check "7.5 comm -23 непуст и содержит инструментальные пакеты"   t7_onlyhost

echo "== Итог: пройдено $PASS, не пройдено $FAIL"
[ "$FAIL" -eq 0 ]
