#!/usr/bin/env python3
import os,sys,time,json,socket,subprocess,select,re
from pathlib import Path
assert socket.gethostname()=='rdsu-alt'
w=Path(os.environ['LAB06_WORK']).resolve(); mode=sys.argv[1]
out=w/'artifacts'/mode; out.mkdir(exist_ok=True)
sock=out/'qmp.sock'
if sock.exists(): sock.unlink()
qemu=w/'tools/root/usr/bin/qemu-system-i386'
bios=w/'tools/root/usr/share/seabios/bios-256k.bin'
if not bios.exists():
    matches=list((w/'tools/root/usr/share').rglob('bios-256k.bin'))
    assert matches, 'SeaBIOS missing'
    bios=matches[0]
image=w/'artifacts'/('panic.bin' if mode=='panic' else 'normal.bin' if mode=='normal' else 'demo.bin')
cmd=[str(qemu),'-L',str(w/'tools/root/usr/share/seavgabios'),'-nic','none','-accel','tcg','-m','16M','-bios',str(bios),'-drive',f'format=raw,file={image},if=ide','-display','none','-serial','stdio','-monitor','none','-qmp',f'unix:{sock},server=on,wait=off','-no-reboot','-no-shutdown']
print('COMMAND:', ' '.join(cmd), flush=True)
err=open(out/'qemu.stderr','wb')
p=subprocess.Popen(cmd,stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=err)
def connect():
    end=time.monotonic()+20
    while time.monotonic()<end:
        if p.poll() is not None: raise RuntimeError((out/'qemu.stderr').read_text())
        try:
            s=socket.socket(socket.AF_UNIX); s.connect(str(sock)); return s
        except OSError: time.sleep(.05)
    raise TimeoutError('QMP startup')
s=connect(); f=s.makefile('rwb',buffering=0); print('QMP',f.readline().decode().strip(),flush=True)
def qmp(execute, arguments=None):
    obj={'execute':execute}
    if arguments is not None: obj['arguments']=arguments
    f.write(json.dumps(obj).encode()+b'\n')
    while True:
        v=json.loads(f.readline())
        if 'error' in v: raise RuntimeError(v)
        if 'return' in v: return v['return']
qmp('qmp_capabilities')
def snapshot(name):
    qmp('stop')
    qmp('screendump',{'filename':str(out/(name+'.ppm'))})
    regs=qmp('human-monitor-command',{'command-line':'info registers'})
    (out/(name+'.registers.txt')).write_text(regs)
    qmp('pmemsave', {'val':0xb8000, 'size':4000, 'filename':str(out/(name+".vga.bin"))})
    qmp('cont')
    print('CAPTURE',name,flush=True)
serial=bytearray(); pending=bytearray(); deadline=time.monotonic()+60
try:
    if mode=='demo':
        time.sleep(2); snapshot('00-demo'); print('DEMO_CAPTURED',flush=True)
    else:
        complete=False
        while time.monotonic()<deadline:
            if p.poll() is not None: raise RuntimeError('QEMU exited')
            if not select.select([p.stdout],[],[],.2)[0]: continue
            b=os.read(p.stdout.fileno(),4096); serial.extend(b); pending.extend(b)
            while b'\n' in pending:
                line,_,pending=pending.partition(b'\n'); line=line.decode(errors='replace').strip()
                print(line,flush=True)
                if line.startswith('SNAP '):
                    snapshot(line.split()[1]); p.stdin.write(b'\n'); p.stdin.flush()
                if line=='BEFORE_PANIC':
                    time.sleep(.3); snapshot('06-panic')
                    time.sleep(.5); snapshot('07-panic-still-halted')
                    regs=(out/'07-panic-still-halted.registers.txt').read_text()
                    vga=(out/'06-panic.vga.bin').read_bytes()
                    text=bytes(vga[::2]).decode('ascii',errors='replace')
                    idx=text.index('KERNEL PANIC: Expected laboratory panic')
                    assert all(a==0x4f for a in vga[2*idx+1:2*(idx+len('KERNEL PANIC: Expected laboratory panic')):2])
                    assert 'HLT=1' in regs and 'AFTER_PANIC_UNEXPECTED' not in serial.decode()
                    first_regs=(out/'06-panic.registers.txt').read_text()
                    assert re.search(r'EIP=([0-9a-f]+)',first_regs).group(1)==re.search(r'EIP=([0-9a-f]+)',regs).group(1)
                    print('PANIC_RED_AND_HALTED_PASS',flush=True); complete=True
                if line=='NORMAL_BOOT_COMPLETE':
                    snapshot('06-normal-restored'); complete=True
            if complete: break
        assert complete, 'Kernel completion timeout'
        assert b'SUMMARY PASS=16 FAIL=0' in serial
        assert not re.search(rb'^FAIL ',serial,re.M)
        print('HOST_VALIDATION_PASS exit=0',flush=True)
finally:
    (out/'serial.log').write_bytes(serial)
    try: qmp('quit')
    except Exception: p.terminate()
    p.wait(timeout=10); err.close(); s.close()
