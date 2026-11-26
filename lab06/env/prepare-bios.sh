#!/bin/bash
set -euo pipefail
test "$(hostname)" = rdsu-alt || exit 90
work=${LAB06_WORK:-/home/user/rdsu-lab06}
exec > >(tee "$work/logs/05-bios.log") 2>&1
pkg=seabios-1.16.3-alt3.noarch.rpm
curl -fsSL --max-time 120 "https://ftp.altlinux.org/pub/distributions/ALTLinux/p11/branch/noarch/RPMS.classic/$pkg" -o "$work/tools/rpms/$pkg"
rpm -qp --qf '%{NAME} %{VERSION}-%{RELEASE}\n' "$work/tools/rpms/$pkg"
rpm2cpio "$work/tools/rpms/$pkg" | (cd "$work/tools/root"; cpio -idm --quiet)
find "$work/tools/root/usr/share" -name '*bin'
