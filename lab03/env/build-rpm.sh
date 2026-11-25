#!/bin/bash
set -euxo pipefail
lab=$(cd "$(dirname "$0")/.." && pwd)
work=$(realpath -m "${1:?Usage: build-rpm.sh WORKDIR}")
mkdir -p "$work"/{rpmbuild/SOURCES,hasher,archive/rdsu-args-1.0}
cp "$lab"/sources/{Makefile,*.c,*.h} "$work/archive/rdsu-args-1.0/"
tar -C "$work/archive" -czf "$work/rpmbuild/SOURCES/rdsu-args-1.0.tar.gz" rdsu-args-1.0
rpmbuild -bs --define "_topdir $work/rpmbuild" "$lab/specs/rdsu-args.spec"
release=$(awk '$1 == "Release:" {print $2; exit}' "$lab/specs/rdsu-args.spec")
hsh "$work/hasher" "$work/rpmbuild/SRPMS/rdsu-args-1.0-$release.src.rpm"
