#!/bin/bash
set -euo pipefail
file=$(mktemp "${TMPDIR:-/tmp}/rdsu-lab04.XXXXXX")
trap 'rm -v -- "$file"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
printf 'temporary content\n' > "$file"
printf '%s\n' "$file"
case ${1:-ok} in
    ok) stat -c '%a %n' "$file" ;;
    error) exit 7 ;;
    wait) while :; do sleep 0.1; done ;;
    *) exit 2 ;;
esac
