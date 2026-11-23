#!/bin/bash
set -euo pipefail
test "$(hostname)" = rdsu-alt
base=$HOME/rdsu-lab04
work=$base/rpm/hasher
cd "$base/repo"
export LAB04_RPM=$work/repo/x86_64/RPMS.hasher/rdsu-tasks-1.0-alt1.noarch.rpm
export LAB04_HASHER_WORKDIR=$work LAB04_GEAR_REPO=$base/gear
old=$base/rpm/gear-hasher/repo/x86_64/RPMS.hasher/rdsu-tasks-1.0-alt1.noarch.rpm
new=$base/rpm/gear-hasher/repo/x86_64/RPMS.hasher/rdsu-tasks-1.1-alt2.noarch.rpm
{
    set -x
    hsh-run --rooter -- "$work" /bin/bash -ec 'cat >/tmp/rdsu-tasks-new.rpm; rpm -U /tmp/rdsu-tasks-new.rpm; rpm -q rdsu-tasks' < "$new"
    hsh-run -- "$work" /bin/bash -ec '
        t=$(mktemp -d)
        trap "rm -rf -- \"$t\"" EXIT
        export XDG_CONFIG_HOME=$t
        rdsu-tasks add "One open task"
        n=$(rdsu-tasks count)
        echo "count=$n"
        test "$n" = 1
    '
    hsh-run --rooter -- "$work" /bin/bash -ec 'cat >/tmp/rdsu-tasks-previous.rpm; rpm -U --oldpackage /tmp/rdsu-tasks-previous.rpm; rpm -q rdsu-tasks' < "$old"
    hsh-run -- "$work" /bin/bash -ec '
        t=$(mktemp -d)
        trap "rm -rf -- \"$t\"" EXIT
        export XDG_CONFIG_HOME=$t
        rc=0
        rdsu-tasks count || rc=$?
        echo "old count exit=$rc"
        test "$rc" = 2
    '
} > lab04/logs/task07-installed-cycle.log 2>&1
bash -n lab04/check/check-lab04.sh
lab04/check/check-lab04.sh | tee lab04/logs/task08-local.log
