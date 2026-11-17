#!/bin/bash
set -euxo pipefail
work=$(realpath "${1:?Usage: check-rpm.sh HASHER_WORKDIR}")
main=$(find "$work/repo" -name 'rdsu-args-[0-9]*.x86_64.rpm' -print -quit)
debug=$(find "$work/repo" -name 'rdsu-args-debuginfo-*.x86_64.rpm' -print -quit)
test -f "$main" && test -f "$debug"
find "$work/repo" -name 'rdsu-args-*.rpm' | sort
files=$(rpm -qpl "$main")
printf '%s\n' "$files"
grep -Fxq /usr/lib64/librdsuargs.so <<< "$files"
for exe in rdsu-args-static rdsu-args-shared; do
    rpm -qpl "$main" | grep -Fx "/usr/bin/$exe"
done
rpm -qpl "$debug"
provides=$(rpm -qp --provides "$main")
printf '%s\n' "$provides"
grep -Fq librdsuargs.so <<< "$provides"
rpm -qp --requires "$main"
hsh-run -- "$work" /bin/sh -ec '
    unset LD_LIBRARY_PATH
    rpm -q rdsu-args
    rdsu-args-static alpha beta gamma > /tmp/rdsu-static
    rdsu-args-shared alpha beta gamma > /tmp/rdsu-shared
    cmp /tmp/rdsu-static /tmp/rdsu-shared
    cat /tmp/rdsu-shared
    readelf -d /usr/bin/rdsu-args-shared | grep -F "[librdsuargs.so]"
    ldd /usr/bin/rdsu-args-static > /tmp/rdsu-deps-static
    ldd /usr/bin/rdsu-args-shared > /tmp/rdsu-deps-shared
    cat /tmp/rdsu-deps-static /tmp/rdsu-deps-shared
    ! grep -F "not found" /tmp/rdsu-deps-shared
    ! grep -F librdsuargs.so /tmp/rdsu-deps-static
    grep -E "librdsuargs.so => (/usr)?/lib64/librdsuargs.so" /tmp/rdsu-deps-shared
    rpm -qf /usr/lib64/librdsuargs.so
'
