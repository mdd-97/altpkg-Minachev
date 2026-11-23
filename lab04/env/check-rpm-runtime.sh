#!/bin/bash
set -euo pipefail
test "$(hostname)" = rdsu-alt
base=$HOME/rdsu-lab04
work=$base/rpm/hasher
logs=$base/repo/lab04/logs
artifact=$(find "$work/repo" -name rdsu-tasks-1.0-alt1.noarch.rpm -print -quit)
test -f "$artifact"
exec >> "$logs/task05-runtime.log" 2>&1
set -x
if [[ ! -d $work/chroot ]]; then hsh --initroot-only "$work"; fi
export LC_ALL=C
rpm -qpl "$artifact"
rpm -qp --requires "$artifact"
rc=0
hsh-run --rooter -- "$work" /bin/bash -c '
    if rpm -q dialog; then exit 90; fi
    cat >/tmp/rdsu-tasks-1.0.rpm
    rpm -i /tmp/rdsu-tasks-1.0.rpm
' < "$artifact" || rc=$?
echo "installation without dialog exit=$rc"
test "$rc" = 1
hsh-install "$work" dialog moreutils
hsh-run --rooter -- "$work" /bin/bash -c 'rpm -i /tmp/rdsu-tasks-1.0.rpm; rpm -q rdsu-tasks'
hsh-run -- "$work" /bin/bash -ec '
    t=$(mktemp -d)
    trap "rm -rf -- \"$t\"" EXIT
    export XDG_CONFIG_HOME=$t/config
    rdsu-tasks add "Installed task"
    rdsu-tasks list
'
echo 'install and launch exit=0'
