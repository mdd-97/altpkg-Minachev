from pathlib import Path
import signal
import subprocess
import sys
import tempfile

demo = sys.argv[1]
previous = None
seen = set()
with tempfile.TemporaryDirectory() as directory:
    for mode, sig, expected in [('ok', None, 0), ('ok', None, 0), ('error', None, 7),
                                ('wait', signal.SIGINT, 130), ('wait', signal.SIGTERM, 143)]:
        child = subprocess.Popen([demo, mode], stdout=subprocess.PIPE, text=True)
        path = Path(child.stdout.readline().strip())
        if sig is not None:
            print(f'observer: {path} exists={path.is_file()} mode={path.stat().st_mode & 0o777:o}')
            assert path.is_file()
            assert path.stat().st_mode & 0o777 == 0o600
            child.send_signal(sig)
        output, _ = child.communicate(timeout=5)
        print(output, end='')
        print(f'{mode} {sig}: {path} exit={child.returncode} exists={path.exists()}')
        if mode == 'ok':
            assert output.split()[0] == '600', output
        assert path.is_absolute() and path not in seen
        seen.add(path)
        assert not path.exists() and child.returncode == expected
        previous = path
    for command in (['mktemp', '-d', directory + '/dir.XXXXXX'],
                    ['mktemp', '-u', directory + '/dry.XXXXXX'],
                    ['mktemp', '-u', directory + '/dry.XXX'],
                    ['mktemp', '-u', directory + '/short.XX']):
        run = subprocess.run(command, capture_output=True, text=True)
        print(command, run.stdout.strip(), run.stderr.strip(), f'exit={run.returncode}')
        if '-d' in command:
            directory_mode = Path(run.stdout.strip()).stat().st_mode & 0o777
            print(f'directory mode={directory_mode:o}')
            assert directory_mode == 0o700
        elif run.returncode == 0:
            assert not Path(run.stdout.strip()).exists()
        else:
            assert 'too few X' in run.stderr
