"""Install checked 0.7.1 bytes and smoke-test under one shared game reservation."""
import argparse
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
    assert os.environ.get('LIGHT_AND_DARKNESS_TEST_REGISTRATION'), 'Run through registered-lighting-test.py perf-release'
    gate = MOD / 'tools/release-perf-071.py'
    options = ['--out', args.out]
    for folder in args.evidence:
        options += ['--evidence', folder]
    run_script(gate, options)  # Full evidence and dependency precheck before writing.
    before = set((MOD / 'build/evidence').glob('remains-lad-brightness-*'))
    installed = False
    try:
        run_script(gate, options + ['--install'])
        installed = True
        run_script(MOD / 'tools/run-brightness-tests.py', [
            '--candidate', MOD / 'release/LightAndDarknessMod.swf',
            '--expected-version', '0.7.1', '--mixed', '--mode', 'smoke'])
        created = set((MOD / 'build/evidence').glob('remains-lad-brightness-*')) - before
        assert len(created) == 1, 'Ambiguous installed smoke evidence'
        smoke = created.pop()
        run_script(gate, ['--out', args.out, '--smoke', smoke])
        print(json.dumps({'status': 'INSTALL_AND_SMOKE_PASS', 'smoke': str(smoke)}), flush=True)
    except BaseException as error:
        if installed:
            receipt = json.loads((MOD / 'state/perf-deployment-2026-11-02.json').read_text('utf8'))
            if not receipt.get('rollbackAt'):
                run_script(gate, ['--out', args.out, '--rollback-reason', str(error)])
        raise


if __name__ == '__main__':
    main()
