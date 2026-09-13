#!/usr/bin/env python3
"""Compile every OpenLoco translation unit with each AROS x86_64 toolchain.

Objects only, no link. The point is to find out how much of the tree each AROS
GCC accepts, and which files need work. A count from this probe is a statement
about translation units, not about a working program.

Sources come from work/OpenLoco (upstream + patches/openloco), third-party
headers from deps/<abi>/src - run scripts/bootstrap.sh and
scripts/fetch-deps.sh first.

Flags mirror upstream's cmake/OpenLocoCommon.cmake. Any divergence has to be
explicit and commented: a probe with different flags invents failures the real
build never sees, and we were bitten by exactly that once (-fno-char8_t).

Results land in docs/evidence/compile-probe/<abi>/ so they are versioned with
the claims that cite them.
"""
from pathlib import Path
import json
import os
import subprocess
import sys

PORT_ROOT = Path(__file__).resolve().parent.parent
WORK = Path(os.environ.get('WORK_DIR', PORT_ROOT / 'work/OpenLoco'))
EVIDENCE = PORT_ROOT / 'docs/evidence/compile-probe'

ABIS = [
    # ABIv11 first: it is the primary target.
    ('abiv11',
     Path(os.environ.get('AROS_ABIV11_TOOLCHAIN', Path.home() / 'Work/AROS/toolchain')),
     Path(os.environ.get('AROS_ABIV11_SDK', Path.home() / 'Work/AROS/sdk'))),
    ('mainline-v1',
     Path(os.environ.get('AROS_MAINLINE_TOOLCHAIN', '/Volumes/arosmain/toolchain-mainline')),
     Path(os.environ.get('AROS_MAINLINE_SDK',
                         '/Volumes/arosmain/build/bin/pc-x86_64/AROS/Developer'))),
]

# Platform backends that are not ours: Windows needs the Win32 SDK, macOS is
# Objective-C++, Crash.cpp is breakpad (MSVC only).
SKIP = {'Platform.Windows.cpp', 'Platform.Macos.mm', 'Crash.cpp'}


def deps_dir(abi):
    return PORT_ROOT / 'deps' / abi / 'src'


def include_dirs():
    """Mirror cmake/OpenLocoUtility.cmake and src/OpenLoco/CMakeLists.txt:791.

    Returns (public, private_by_module). Only a module's OWN files get its
    include/OpenLoco and include/OpenLoco/<Module> directories, because upstream
    adds those PRIVATE. Handing them to every translation unit is not just
    inaccurate, it actively breaks the probe: include/OpenLoco/Graphics matches
    a system <graphics/...> include on a case-insensitive filesystem, so
    <graphics/gfx.h> resolved to OpenLoco's own Gfx.h and produced errors deep
    inside AROS SDK headers that the real build never sees.
    """
    public, private = [], {}
    for mod in sorted((WORK / 'src').iterdir()):
        if not mod.is_dir():
            continue
        for cand in (mod / 'include', mod / 'src'):
            if cand.is_dir():
                public.append(cand)
        priv = [d for d in (mod / 'include' / 'OpenLoco',
                            mod / 'include' / 'OpenLoco' / mod.name) if d.is_dir()]
        if priv:
            private[mod.name] = priv
    return public, private


def flags(abi, sysroot, src, include_all):
    # The file's own module comes first: several modules ship a Types.hpp and a
    # plain #include "Types.hpp" must resolve inside its own module.
    public, private = include_all
    own = src.relative_to(WORK / 'src').parts[0]
    mine = private.get(own, []) + [d for d in public
                                   if d.relative_to(WORK / 'src').parts[0] == own]
    rest = [d for d in public if d not in mine]
    deps = deps_dir(abi)
    inc = [f'-I{d}' for d in mine + rest]
    inc += [f'-I{src.parent}',
            f'-I{deps}/SDL3-3.4.12/include',
            f'-I{deps}/fmt/include',
            f'-I{deps}/sfl/include',
            f'-I{deps}/yaml/include',
            f'-I{sysroot}/include']
    # -w only silences warnings; every functional flag here comes from
    # COMMON_COMPILE_OPTIONS_GNU in cmake/OpenLocoCommon.cmake.
    return ['-std=c++20', '-O1', '-fno-char8_t', '-fstrict-aliasing', '-w',
            '-DFMT_HEADER_ONLY=1',
            '-DOPENLOCO_VERSION_TAG="probe"', '-DOPENLOCO_BRANCH="probe"',
            '-DOPENLOCO_COMMIT_SHA1="0"', '-DOPENLOCO_COMMIT_SHA1_SHORT="0"',
            '-DOPENLOCO_BUILD_SERVER=""'] + inc


def main():
    if not (WORK / 'src').is_dir():
        print(f'no work tree at {WORK} - run scripts/bootstrap.sh', file=sys.stderr)
        return 2

    sources = sorted(p for p in (WORK / 'src').rglob('*.cpp')
                     if p.name not in SKIP and '/test' not in str(p).lower())
    include_all = include_dirs()
    summary = {}

    for abi, tc, sysroot in ABIS:
        cc = tc / 'x86_64-aros-g++'
        if not cc.exists():
            print(f'{abi}: toolchain missing at {cc} - skipped', file=sys.stderr)
            summary[abi] = {'__error__': f'toolchain missing: {cc}'}
            continue
        if not deps_dir(abi).is_dir():
            print(f'{abi}: no deps - run scripts/fetch-deps.sh {abi}', file=sys.stderr)
            summary[abi] = {'__error__': 'deps missing'}
            continue

        objdir = PORT_ROOT / 'build' / abi / 'compile-probe'
        logdir = EVIDENCE / abi
        objdir.mkdir(parents=True, exist_ok=True)
        logdir.mkdir(parents=True, exist_ok=True)
        for stale in logdir.glob('*.log'):
            stale.unlink()

        results = {}
        for s in sources:
            rel = str(s.relative_to(WORK / 'src'))
            flat = rel.replace('/', '_')
            cmd = [str(cc), f'--sysroot={sysroot}'] + \
                flags(abi, sysroot, s, include_all) + \
                ['-c', str(s), '-o', str(objdir / (flat[:-4] + '.o'))]
            r = subprocess.run(cmd, capture_output=True, text=True)
            (logdir / (flat + '.log')).write_text(
                ' '.join(cmd) + f'\nexit={r.returncode}\n' + r.stdout + r.stderr)
            results[rel] = r.returncode

        ok = sum(v == 0 for v in results.values())
        summary[abi] = results
        print(f'{abi}: {ok}/{len(results)} OK', flush=True)
        for name, v in results.items():
            if v != 0:
                errs = [l for l in (logdir / (name.replace('/', '_') + '.log'))
                        .read_text().splitlines() if ' error:' in l]
                head = errs[0][:150] if errs else f'exit {v}'
                print(f'  FAIL {name}: {head}', flush=True)

    EVIDENCE.mkdir(parents=True, exist_ok=True)
    (EVIDENCE / 'summary.json').write_text(json.dumps(
        {'upstream_commit': os.environ.get('UPSTREAM_COMMIT', 'unset'),
         'results': summary}, indent=2))
    print(f'\nlogs and summary.json in {EVIDENCE}')
    return 0


if __name__ == '__main__':
    sys.exit(main())
