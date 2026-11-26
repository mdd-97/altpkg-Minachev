#!/bin/bash
set -euo pipefail
test "$(hostname)" = rdsu-alt || exit 90
work=${LAB06_WORK:-/home/user/rdsu-lab06}
mkdir -p "$work/tools/rpms" "$work/tools/root" "$work/logs" "$work/artifacts"
exec > >(tee "$work/logs/05-tools.log") 2>&1
hostname; cat /etc/os-release; uname -m
gcc --version | head -1
ld --version | head -1
base=https://ftp.altlinux.org/pub/distributions/ALTLinux/p11/branch/x86_64/RPMS.classic
for pkg in nasm-2.16.03-alt1.x86_64.rpm qemu-system-x86-core-9.1.2-alt1.x86_64.rpm; do
 curl -fSL -C - --max-time 900 "$base/$pkg" -o "$work/tools/rpms/$pkg"
 rpm -qp --qf '%{NAME} %{VERSION}-%{RELEASE} %{ARCH}\n' "$work/tools/rpms/$pkg"
 rpm2cpio "$work/tools/rpms/$pkg" | (cd "$work/tools/root"; cpio -idm --quiet)
done
sha256sum "$work"/tools/rpms/*.rpm
"$work/tools/root/usr/bin/nasm" -v
"$work/tools/root/usr/bin/qemu-system-i386" --version
ldd "$work/tools/root/usr/bin/qemu-system-i386" | grep 'not found' && exit 91 || :
ls /usr/share/qemu /usr/share/seabios 2>/dev/null || :
printf 'TOOLS_READY exit=0\n'
