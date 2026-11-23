#!/bin/bash
set -euo pipefail
test "$(hostname)" = rdsu-alt
base=$HOME/rdsu-lab04
work=$base/rpm/hasher
logs=$base/repo/lab04/logs
(
    set -x
    hsh-run -- "$work" /bin/bash -ec '
        set -x
        t=$(mktemp -d)
        trap "rm -rf -- \"$t\"" EXIT
        cd "$t"
        rpm -q moreutils
        printf "alpha\nbeta\n" > text
        tr a-z A-Z < text > text
        wc -c text
        test ! -s text
        printf "alpha\nbeta\n" > text
        tr a-z A-Z < text | sponge text
        printf "ALPHA\nBETA\n" | diff -u - text
        cat text
        printf "event\n" | ts
    '
) > "$logs/task03-moreutils.log" 2>&1
command="hsh-run --pty -- $work /bin/bash -ec 't=\$(mktemp -d); export XDG_CONFIG_HOME=\$t/config TMPDIR=\$t/tmp TERM=xterm; mkdir -p \"\$TMPDIR\"; rdsu-tasks; test -z \"\$(ls -A \"\$TMPDIR\")\"; rm -rf -- \"\$t\"; echo UI-cleanup-ok'"
rc=0
(sleep 1; printf '\033'; sleep 1) | timeout 12 script -qec "$command" "$logs/task04-menu.typescript" > "$logs/task04-menu.raw" 2>&1 || rc=$?
grep -aFq 'RDSU Tasks' "$logs/task04-menu.raw"
grep -aFq 'UI-cleanup-ok' "$logs/task04-menu.raw"
printf 'menu header=RDSU Tasks\nmenu exit=%s\nUI-cleanup-ok\n' "$rc" > "$logs/task04-menu.log"
test "$rc" = 0
