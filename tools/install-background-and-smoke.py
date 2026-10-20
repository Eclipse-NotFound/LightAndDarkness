"""Install checked bytes and smoke-test under one shared game reservation."""
import argparse
import importlib.util
import json
import os
from pathlib import Path
import runpy
import sys

MOD = Path(__file__).resolve().parents[1]


def run_script(path, args):
    previous = sys.argv
    try:
        sys.argv = [str(path)] + list(map(str, args))
        runpy.run_path(str(path), run_name='__main__')
    finally:
        sys.argv = previous


def main():
    p = argparse.ArgumentParser()
    p.add_argument('--out', required=True, type=Path)
    p.add_argument('--evidence', action='append', required=True, type=Path)
    args = p.parse_args()
    assert os.environ.get('LIGHT_AND_DARKNESS_TEST_REGISTRATION'), 'Run through registered-lighting-test.py release'
    gate = MOD / 'tools/release-background.py'
    options = ['--out', args.out]
    for folder in args.evidence:
        options += ['--evidence', folder]
    run_script(gate, options)  # Full evidence and dependency precheck before writing.
    before = set((MOD / 'build/evidence').glob('remains-lad-background-lighting-*'))
    installed = False
    try:
        run_script(gate, options + ['--install'])
        installed = True
        run_script(MOD / 'tools/run-background-lighting-tests.py', [
            '--candidate', MOD / 'release/LightAndDarknessMod.swf',
            '--expected-version', '0.6.0', '--mixed', '--mode', 'smoke'])
        created = set((MOD / 'build/evidence').glob('remains-lad-background-lighting-*')) - before
        assert len(created) == 1, 'Ambiguous installed smoke evidence'
        smoke = created.pop()
        run_script(gate, ['--out', args.out, '--smoke', smoke])
        print(json.dumps({'status': 'INSTALL_AND_SMOKE_PASS', 'smoke': str(smoke)}), flush=True)
    except BaseException as error:
        if installed:
            receipt = json.loads((MOD / 'state/background-deployment-2026-10-20.json').read_text('utf8'))
            if not receipt.get('rollbackAt'):
                run_script(gate, ['--out', args.out, '--rollback-reason', str(error)])
        raise


if __name__ == '__main__':
    main()
