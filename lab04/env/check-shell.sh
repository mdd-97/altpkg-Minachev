#!/bin/bash
set -eu -o pipefail
work=$(mktemp -d)
trap 'rm -rf -- "$work"' EXIT
cd "$work"
shopt -s expand_aliases
alias ll='ls -l'
type -a read printf ll rpm sed grep
for cmd in rpm sed grep; do
    rpm -qf "$(command -v "$cmd")"
done
unset LAB04_VALUE
LAB04_VALUE=parent
bash -c 'printf "before=<%s>\n" "${LAB04_VALUE-}"'
test -z "$(bash -c 'printf "%s" "${LAB04_VALUE-}"')"
export LAB04_VALUE
bash -c 'printf "exported=<%s>\n" "$LAB04_VALUE"; LAB04_VALUE=child'
printf 'parent=<%s>\n' "$LAB04_VALUE"
test "$LAB04_VALUE" = parent
V=one/two/three
printf 'short prefix=%s\nlong prefix=%s\nshort suffix=%s\nlong suffix=%s\n' "${V#*/}" "${V##*/}" "${V%/*}" "${V%%/*}"
emit() { printf 'stdout\n'; printf 'stderr\n' >&2; }
emit > combined 2>&1
{ emit 2>&1 > stdout-only; } > original-stdout
emit > no-descriptor
cat combined stdout-only original-stdout no-descriptor
rc=0
diff -u stdout-only combined || rc=$?
printf 'diff exit=%s\n' "$rc"
test "$rc" = 1
while IFS= read -r key; do
    if uname -s | head -1 | cut -d ' ' -f 1 | tr '[:upper:]' '[:lower:]' > "$key"; then
        printf 'pipeline exit=0\n'
    else
        exit "$?"
    fi
done <<'KEYS'
system
KEYS
printf 'linux\n' > system.expected
diff -u system.expected system
cat system
