#!/bin/bash
set -euxo pipefail
work=$(realpath "${1:?Usage: check-rpm.sh HASHER_WORKDIR}")
main=${LAB03_RPM_MAIN:-$(find "$work/repo" -name 'rdsu-args-[0-9]*.x86_64.rpm' -print | sort -V | tail -1)}
debug=$(find "$work/repo" -name 'rdsu-args-debuginfo-*.x86_64.rpm' -print | sort -V | tail -1)
library=$(find "$work/repo" -name 'librdsuargs-[0-9]*.x86_64.rpm' -print | sort -V | tail -1)
test -f "$main" && test -f "$debug"
requires=$(rpm -qp --requires "$main")
printf '%s\n' "$requires"
test -f "$library"
library_requirement=$(rpm -qp --qf '%{NAME} = %{VERSION}-%{RELEASE}' "$library")
# ALT may optimize a sibling SONAME requirement to an exact package dependency.
grep -Fx "$library_requirement" <<< "$requires" ||
    grep -E '^librdsuargs[.]so[(][)][(]64bit[)]([[:space:]]|$)' <<< "$requires"
find "$work/repo" -name 'rdsu-args-*.rpm' | sort
files=$(rpm -qpl "$main" "$library")
printf '%s\n' "$files"
grep -Fxq /usr/lib64/librdsuargs.so <<< "$files"
for exe in rdsu-args-static rdsu-args-shared; do
    rpm -qpl "$main" | grep -Fx "/usr/bin/$exe"
done
rpm -qpl "$debug"
provides=$(rpm -qp --provides "$library")
printf '%s\n' "$provides"
grep -E '^librdsuargs[.]so[(][)][(]64bit[)]([[:space:]]|$)' <<< "$provides"
rpm -qp --requires "$main"
hsh-run -- "$work" /bin/sh -ec '
    unset LD_LIBRARY_PATH
    rpm -q rdsu-args librdsuargs
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

echo 'split RPM dependency check exit=0'
