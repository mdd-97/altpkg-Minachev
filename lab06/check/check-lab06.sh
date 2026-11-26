#!/bin/bash
# Все шесть проверок LIVE. Копия исходников и результаты находятся вне Git-клона.
set -uo pipefail
lab=$(cd "$(dirname "$0")/.." && pwd)
pass=0 fail=0
if [[ $(hostname) != rdsu-alt || $(uname -m) != x86_64 ]]; then
 echo 'FAIL требуется rdsu-alt x86_64'; exit 1
fi
for command in gcc ld objcopy make python3; do
 command -v "$command" >/dev/null || { echo "FAIL нет $command"; exit 1; }
done
tools=${LAB06_TOOLS:-/home/user/rdsu-lab06/tools}
for binary in nasm qemu-system-i386; do
 [[ -x "$tools/root/usr/bin/$binary" ]] || { echo "FAIL нет $tools/root/usr/bin/$binary: см. README"; exit 1; }
done
out=${LAB06_OUTPUT:-$(mktemp -d /tmp/lab06-result.XXXXXX)}
mkdir -p "$out" || exit 1
out=$(cd "$out" && pwd)
work=$(mktemp -d /tmp/lab06-live.XXXXXX) || exit 1
trap 'rm -rf -- "$work"' EXIT
cp -R "$lab/sources" "$work/sources" || exit 1
ln -s "$(cd "$tools" && pwd)" "$work/tools" || exit 1
mkdir -p "$work/artifacts"
export LAB06_WORK=$work
export PATH="$work/tools/root/usr/bin:$PATH"
export PYTHONUNBUFFERED=1
printf 'LIVE: все опыты запускаются сейчас в QEMU внутри ALT\nRESULTS=%s\n' "$out"
check() {
 local name=$1;shift
 if "$@" > "$out/$name.log" 2>&1; then
  printf 'PASS %s\n' "$name";((pass+=1))
 else
  printf 'FAIL %s\n' "$name";tail -30 "$out/$name.log";((fail+=1))
 fi
}
build() {
 make -C "$work/sources" all check-image.bin panic-image.bin || return 1
 cp "$work/sources/os-image.bin" "$work/artifacts/demo.bin" || return 1
 cp "$work/sources/check-image.bin" "$work/artifacts/normal.bin" || return 1
 cp "$work/sources/panic-image.bin" "$work/artifacts/panic.bin" || return 1
 python3 - "$work" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]);src=p/'sources'
assert (src/'boot/bootsect.bin').stat().st_size==512
assert (src/'boot/bootsect.bin').read_bytes()[-2:]==b'\x55\xaa'
for name in ('demo','normal','panic'):assert (p/'artifacts'/(name+'.bin')).stat().st_size==16384
print('ELF32 build, boot signature 55aa and 3 images of 16384 bytes: OK')
PY
}
normal() {
 python3 "$lab/env/run_checks.py" normal || return 1
 grep -Fx 'NORMAL_BOOT_COMPLETE' "$work/artifacts/normal/serial.log" || return 1
 grep '^SUMMARY ' "$work/artifacts/normal/serial.log" > "$out/summary.actual" || return 1
 diff -u "$lab/check/summary.expected" "$out/summary.actual"
}
panic() {
 python3 "$lab/env/run_checks.py" panic
}
size_guard() {
 local rc
 cp "$work/sources/kernel.bin" "$work/sources/kernel.saved" || return 1
 truncate -s 15873 "$work/sources/kernel.bin" || return 1
 make -C "$work/sources" os-image.bin;rc=$?
 printf 'oversize_expected_nonzero_actual=%s\n' "$rc"
 mv "$work/sources/kernel.saved" "$work/sources/kernel.bin" || return 1
 touch "$work/sources/kernel.bin"
 make -C "$work/sources" os-image.bin || return 1
 cmp "$work/sources/os-image.bin" "$work/artifacts/demo.bin" || return 1
 printf 'restore_cmp=0\n'
 [[ $rc -ne 0 ]]
}
recovery() {
 python3 "$lab/env/run_checks.py" normal || return 1
 grep -Fx 'SUMMARY PASS=16 FAIL=0' "$work/artifacts/normal/serial.log" || return 1
 grep -Fx 'NORMAL_BOOT_COMPLETE' "$work/artifacts/normal/serial.log"
}
demo() {
 python3 "$lab/env/run_checks.py" demo || return 1
 python3 - "$work/artifacts/demo/00-demo.vga.bin" <<'PY'
from pathlib import Path
import sys
s=Path(sys.argv[1]).read_bytes();assert len(s)==4000
chars=s[::2]
assert chars[:6]==b'Line 8'
assert chars[22*80:22*80+7]==b'Line 30'
assert chars[23*80:23*80+20]==b'Backspace test: ABCD'
assert chars[24*80:25*80]==b' '*80
print('DEMO VGA: Line 8..30, ABCD, cleared bottom row: OK')
PY
}
check 01-build build
if [[ $fail -ne 0 ]]; then
 printf 'PASS=%d FAIL=%d SKIP=0\n' "$pass" "$fail";exit 1
fi
check 02-normal-and-reference normal
check 03-panic-red-and-halted panic
check 04-oversize-and-restore size_guard
check 05-recovery recovery
check 06-demo-vga demo
cp -R "$work/artifacts" "$out/" || { echo 'FAIL copying artifacts';exit 1; }
printf 'PASS=%d FAIL=%d SKIP=0\n' "$pass" "$fail"
((fail==0))
