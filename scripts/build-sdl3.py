#!/usr/bin/env python3
"""Compile contrib's SDL3-aros-staticlib file list with the ABIv11 toolchain."""
import argparse, re, subprocess, sys, datetime
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor

ap = argparse.ArgumentParser()
ap.add_argument('--deps', required=True)
ap.add_argument('--toolchain', required=True)
ap.add_argument('--sdk', required=True)
ap.add_argument('--build', required=True)
a = ap.parse_args()

deps, prefix = Path(a.deps), Path(a.deps)
src = deps / 'src/SDL3-3.4.12'
cc = Path(a.toolchain) / 'x86_64-aros-gcc'
ar = Path(a.toolchain) / 'x86_64-aros-ar'
sdk = Path(a.sdk)

# FILES := \ ... one $(ARCHSRCDIR)/path per line, no extension.
mm = (deps / 'src/contrib-sdl3/mmakefile.src').read_text()
# FILES is assembled from one ":=" and several "+=" blocks, each a
# backslash-continued list. The test-suite lists further down use their own
# variables, so stop at the end of every continuation rather than grepping
# the whole file.
block = []
lines = mm.splitlines()
for i, ln in enumerate(lines):
    if re.match(r'FILES\s*[:+]?=', ln):
        for cont in lines[i:]:
            block.append(cont)
            if not cont.rstrip().endswith('\\'):
                break
files = re.findall(r'\$\(ARCHSRCDIR\)/(\S+)', '\n'.join(block))
assert len(files) > 150, f'only {len(files)} files parsed from mmakefile.src'

objdir = Path(a.build) / 'sdl3'
objdir.mkdir(parents=True, exist_ok=True)
adate = datetime.date.today().strftime('%d.%m.%Y')

INCLUDES = [f'-I{src}/include', f'-I{src}/include/build_config',
            f'-I{src}', f'-I{src}/src', f'-I{sdk}/include']
CFLAGS = ['-std=gnu99', '-O2', '-DSDL3_AROS_STATIC', f'-DADATE="{adate}"',
          '-Wno-stringop-truncation', '-w']

units = [(src / (f + '.c'), objdir / (f.replace('/', '_') + '.o')) for f in files]
units.append((deps / 'src/contrib-sdl3/SDL3_static.c', objdir / 'SDL3_static.o'))


def build(u):
    s, o = u
    if not s.exists():
        return s, 127, f'missing source {s}'
    r = subprocess.run([str(cc), f'--sysroot={sdk}'] + CFLAGS + INCLUDES +
                       ['-c', str(s), '-o', str(o)], capture_output=True, text=True)
    return s, r.returncode, r.stdout + r.stderr


fail = 0
with ThreadPoolExecutor(max_workers=8) as ex:
    for s, rc, out in ex.map(build, units):
        if rc != 0:
            fail += 1
            print(f'FAIL {s.name}\n{out[:600]}', file=sys.stderr)

print(f'compiled {len(units) - fail}/{len(units)} objects')
if fail:
    sys.exit(1)

(prefix / 'lib').mkdir(parents=True, exist_ok=True)
lib = prefix / 'lib/libSDL3_static.a'
lib.unlink(missing_ok=True)
objs = [str(o) for _, o in units]
for i in range(0, len(objs), 100):
    subprocess.run([str(ar), 'rcs', str(lib)] + objs[i:i + 100], check=True)

incdst = prefix / 'include/SDL3'
incdst.mkdir(parents=True, exist_ok=True)
for h in (src / 'include/SDL3').glob('*.h'):
    (incdst / h.name).write_bytes(h.read_bytes())

print(f'{lib} ({lib.stat().st_size // 1024} KiB)')
print(f'headers in {incdst}')
