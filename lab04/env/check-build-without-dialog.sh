#!/bin/bash
# Observer-only SPEC: assert dialog is absent before packaging unchanged Source0.
set -euo pipefail
test "$(hostname)" = rdsu-alt
lab=$(cd "$(dirname "$0")/.." && pwd)
work=${1:?Specify a new work directory}
mkdir -p "$work/top/SOURCES" "$work/top/SPECS"
cp "$lab/sources/rdsu-tasks" "$work/top/SOURCES/"
python3 - "$lab/specs/rdsu-tasks.spec" "$work/top/SPECS/observer.spec" <<'PY'
from pathlib import Path
import sys
s=Path(sys.argv[1]).read_text()
s=s.replace('%install', '''%build
if rpm -q dialog; then
    echo 'Unexpected dialog in build environment' >&2
    exit 1
fi
echo 'OBSERVER_DIALOG_ABSENT'

%install''',1)
Path(sys.argv[2]).write_text(s)
PY
rpmbuild -bs --define "_topdir $work/top" "$work/top/SPECS/observer.spec"
hsh --packager='Damir Minachev <mdd97@yandex.ru>' "$work/hasher" "$work/top/SRPMS/rdsu-tasks-1.0-alt1.src.rpm"
