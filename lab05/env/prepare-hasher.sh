#!/bin/bash
set -euo pipefail
work=
number=1
rooter=()
packages=(gcc gdb gdbserver)
while (($#)); do
    case $1 in
        --workdir) work=${2:?Specify an environment directory}; shift 2 ;;
        --number) number=${2:?Specify a Hasher pair number}; shift 2 ;;
        --package) packages+=("${2:?Specify a package}"); shift 2 ;;
        --rooter) rooter=(--rooter); shift ;;
        --) shift; break ;;
        *) printf 'Unknown option: %s\n' "$1" >&2; exit 2 ;;
    esac
done
[[ -n $work && $number =~ ^[1-9][0-9]*$ ]] || {
    printf 'Usage: %s --workdir DIR [--number N] [--package NAME] [--rooter] [-- COMMAND ...]\n' "$0" >&2
    exit 2
}
test "$(hostname)" = rdsu-alt
mkdir -p -- "$work"
work=$(realpath "$work")
args=("--number=$number" "--workdir=$work")
if [[ ! -d $work/chroot/etc/rpm ]]; then
    hsh "${args[@]}" --initroot-only </dev/null
fi
missing=()
for pkg in "${packages[@]}"; do
    if ! hsh-run "${args[@]}" -- /bin/rpm -q "$pkg" >/dev/null 2>&1; then
        missing+=("$pkg")
    fi
done
if ((${#missing[@]})); then
    hsh-install "${args[@]}" -- "${missing[@]}" </dev/null
fi
hsh-run "${args[@]}" --rooter -- /bin/bash -ec '
    umask 022
    cat > /etc/resolv.conf
' < /etc/resolv.conf
if (($#)); then
    exec hsh-run "${args[@]}" --mountpoints=/proc "${rooter[@]}" -- "$@"
fi
exec hsh-shell "${args[@]}" --mountpoints=/proc "${rooter[@]}"
