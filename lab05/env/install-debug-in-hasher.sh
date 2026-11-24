#!/bin/bash
set -euo pipefail
test "$(hostname)" = rdsu-alt
b=$HOME/rdsu-lab05
cd "$b/repo/lab05"
work=$b/hasher
export LC_ALL=C
mkdir -p "$b/debug-rpms"
expat=$(find "$b"/debuginfo.* -maxdepth 1 -name 'libexpat-debuginfo-*.rpm' -print -quit)
glibc=$(rpm -q --qf '%{NAME}-debuginfo-%{VERSION}-%{RELEASE}.%{ARCH}.rpm' -f "$(readlink -f /lib64/libc.so.6)")
mirror=https://ftp.altlinux.org/pub/distributions/ALTLinux/p11/branch/x86_64/RPMS.debuginfo
{
    set -x
    curl -fsSL --max-time 200 --retry 1 "$mirror/$glibc" -o "$b/debug-rpms/$glibc"
    rpm -qp --provides "$b/debug-rpms/$glibc" | grep -F 'debug64(libc.so.6)'
    hsh-run --rooter -- "$work" /bin/bash -ec 'cat > /tmp/lab05-glibc-debuginfo.rpm' < "$b/debug-rpms/$glibc"
    hsh-run --rooter -- "$work" /bin/bash -ec 'cat > /tmp/lab05-libexpat-debuginfo.rpm; rpm -i /tmp/lab05-glibc-debuginfo.rpm /tmp/lab05-libexpat-debuginfo.rpm; rpm -q libexpat-debuginfo; rpm -ql libexpat-debuginfo | head -9' < "$expat"
    hsh-run -- "$work" /bin/bash -ec 'set -o pipefail; DEBUGINFOD_URLS= gdb -nx -batch -iex "set debuginfod enabled off" -ex "info sources" /lib64/libexpat.so.1 | grep -oE "[^, ]*xmlparse[.]c" | head -3'
    echo 'installed debuginfo exit=0'
} > logs/task04-installed-with-dependencies.log 2>&1
tail -16 logs/task04-installed-with-dependencies.log
