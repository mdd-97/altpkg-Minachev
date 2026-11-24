#!/bin/bash
set -euo pipefail
test "$(hostname)" = rdsu-alt
b=$HOME/rdsu-lab05
cd "$b/repo/lab05"
work=$b/hasher
export LC_ALL=C
hsh-run -- "$work" /bin/bash -ec 'cat > /tmp/lab05-progression.c; cc -O0 -g -o /tmp/lab05-progression /tmp/lab05-progression.c; rpm -q gcc gdb gdbserver' < sources/progression.c > logs/task06-packages.log 2>&1
rc=0
hsh-run -- "$work" /bin/bash -c '
  test -r /proc/self/status && echo proc-present || echo proc-absent
  DEBUGINFOD_URLS= gdb -nx --batch -ex "break emit" -ex "run 1 9 2" -ex "info args" /tmp/lab05-progression
' > logs/task06-no-proc.log 2>&1 || rc=$?
echo "without configured mount exit=$rc" >> logs/task06-no-proc.log
rc=0
hsh-run --mountpoints=/proc -- "$work" /bin/bash -ec '
  grep " /proc " /proc/self/mounts
  DEBUGINFOD_URLS= gdb -nx --batch -ex "break emit" -ex "run 1 9 2" -ex "info args" /tmp/lab05-progression
' > logs/task06-with-proc.log 2>&1 || rc=$?
echo "with proc requested exit=$rc" >> logs/task06-with-proc.log
cat logs/task06-{packages,no-proc,with-proc}.log
