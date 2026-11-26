#!/usr/bin/env python3
"""Drive the real dialog menu in a Hasher PTY and verify persisted data."""
import os
from pathlib import Path
import pty
import select
import signal
import sys
import time

workdir = sys.argv[1]
out = Path(sys.argv[2])
out.mkdir(parents=True, exist_ok=True)
script = r'''
set -euo pipefail
t=$(mktemp -d)
trap 'rm -rf -- "$t"' EXIT
export XDG_CONFIG_HOME=$t/config TMPDIR=$t/tmp TERM=xterm
mkdir -p "$TMPDIR"
rdsu-tasks
printf '\nUI_DATABASE\n'
cat "$XDG_CONFIG_HOME/rdsu-tasks/tasks.tsv"
grep -Fx $'1\tdone\tMenu task with spaces' "$XDG_CONFIG_HOME/rdsu-tasks/tasks.tsv"
test -z "$(ls -A "$TMPDIR")"
echo UI-cleanup-ok
echo UI-functional-exit=0
'''
pid, fd = pty.fork()
if pid == 0:
    import fcntl, struct, termios
    fcntl.ioctl(0, termios.TIOCSWINSZ, struct.pack('HHHH', 30, 100, 0, 0))
    os.execvp('hsh-run', ['hsh-run', '--pty', '--', workdir, '/bin/bash', '-ec', script])
raw = bytearray()
position = 0
finished = False

def read_more(timeout):
    if select.select([fd], [], [], timeout)[0]:
        try:
            data = os.read(fd, 65536)
        except OSError:
            return False
        if not data:
            return False
        raw.extend(data)
    return True

def expect(token):
    global position
    deadline = time.monotonic() + 20
    while time.monotonic() < deadline:
        index = raw.find(token, position)
        if index >= 0:
            position = index + len(token)
            return
        if not read_more(0.1):
            break
    raise AssertionError(f'missing UI output: {token!r}')

def send(data):
    os.write(fd, data)

try:
    expect(b'RDSU Tasks')
    expect(b'Exit')
    for _ in range(6):
        read_more(0.05)
    (out/'menu-initial.raw').write_bytes(raw)
    print('menu: Add task / Show tasks / Mark done / Exit')
    send(b'\r')
    expect(b'Enter task text')
    send(b'Menu task with spaces\r')
    expect(b'Added 1')
    print('menu add: Added 1')
    send(b'\r')
    expect(b'RDSU Tasks')
    send(b'l\r')
    expect(b'1. Menu task with spaces')
    print('menu list: 1. Menu task with spaces')
    send(b'\r')
    expect(b'RDSU Tasks')
    send(b'd\r')
    expect(b'Mark done')
    expect(b'Menu task with spaces')
    send(b'\r')
    expect(b'RDSU Tasks')
    send(b'l\r')
    expect(b'Done:')
    expect(b'1. Menu task with spaces')
    print('menu done: task is in Done')
    send(b'\r')
    expect(b'RDSU Tasks')
    send(b'q\r')
    expect(b'UI-cleanup-ok')
    expect(b'UI-functional-exit=0')
    deadline = time.monotonic() + 10
    while time.monotonic() < deadline:
        child, status = os.waitpid(pid, os.WNOHANG)
        if child:
            finished = True
            code = os.waitstatus_to_exitcode(status)
            assert code == 0, code
            break
        read_more(0.1)
    assert finished, 'UI process did not exit'
    print('menu database: 1 / done / Menu task with spaces')
    print('UI-cleanup-ok')
    print('UI-functional-exit=0')
finally:
    (out/'menu-flow.raw').write_bytes(raw)
    if not finished:
        try:
            os.killpg(pid, signal.SIGTERM)
        except ProcessLookupError:
            pass
    os.close(fd)
