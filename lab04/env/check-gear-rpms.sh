#!/bin/bash
set -euxo pipefail
test "$(hostname)" = rdsu-alt
base=$HOME/rdsu-lab04
lab=$base/repo/lab04
cd "$lab"
baseline=$base/rpm/hasher/repo/x86_64/RPMS.hasher/rdsu-tasks-1.0-alt1.noarch.rpm
gear=$base/rpm/gear-hasher/repo/x86_64/RPMS.hasher/rdsu-tasks-1.0-alt1.noarch.rpm
recent=$base/rpm/gear-new/RPMS/noarch/rdsu-tasks-1.1-alt2.noarch.rpm
old=$base/rpm/gear-old-tag/RPMS/noarch/rdsu-tasks-1.0-alt1.noarch.rpm
{
    export LC_ALL=C
    for format in name files requires; do
        case $format in
            name) args=(--queryformat '%{NAME} %{VERSION} %{RELEASE}\n');;
            files) args=(-l);;
            requires) args=(--requires);;
        esac
        rpm -qp "${args[@]}" "$baseline" | sort > "logs/standalone-$format.txt"
        rpm -qp "${args[@]}" "$gear" | sort > "logs/gear-$format.txt"
        diff -u "logs/standalone-$format.txt" "logs/gear-$format.txt"
        cat "logs/gear-$format.txt"
    done
    echo 'GEAR comparison exit=0'
} > logs/task06-compare.log 2>&1
(
    temp=$(mktemp -d)
    trap 'rm -rf -- "$temp"' EXIT
    export XDG_CONFIG_HOME=$temp/config
    rpm -qp --queryformat '%{NAME} %{VERSION} %{RELEASE}\n' "$recent" "$old"
    rpm -qp --changelog "$recent"
    mkdir "$temp/old" "$temp/new"
    (cd "$temp/old"; rpm2cpio "$old" | cpio -id)
    (cd "$temp/new"; rpm2cpio "$recent" | cpio -id)
    "$temp/new/usr/bin/rdsu-tasks" add 'Open task'
    test "$("$temp/new/usr/bin/rdsu-tasks" count)" = 1
    printf 'new count=%s\n' "$("$temp/new/usr/bin/rdsu-tasks" count)"
    rc=0
    "$temp/old/usr/bin/rdsu-tasks" count || rc=$?
    echo "old count exit=$rc"
    test "$rc" = 2
) > logs/task07-function.log 2>&1
