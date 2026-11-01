"""Sequential brightness release checks under one existing game reservation."""
import argparse
import json
import os
from pathlib import Path
import runpy
import sys

MOD = Path(__file__).resolve().parents[1]


def run(name, pattern, options):
    before = set((MOD / 'build/evidence').glob(pattern))
    previous = sys.argv
    try:
        sys.argv = [str(MOD / 'tools' / name)] + list(map(str, options))
        runpy.run_path(sys.argv[0], run_name='__main__')
    finally:
        sys.argv = previous
    created = set((MOD / 'build/evidence').glob(pattern)) - before
    assert len(created) == 1, 'Expected exactly one completed evidence directory'
    return created.pop()


def main():
    p = argparse.ArgumentParser()
    p.add_argument('--out', type=Path, required=True)
    p.add_argument('--normal', type=Path, help='Reuse a successful normal run of exactly these bytes')
    p.add_argument('--expected-version', default='0.7.1',
                   help='Candidate VERSION the probes must report (suite records it verbatim)')
    args = p.parse_args()
    assert os.environ.get('LIGHT_AND_DARKNESS_TEST_REGISTRATION'), 'Use registered-lighting-test.py brightness-suite'
    candidate = args.out.resolve() / 'LightAndDarknessMod.swf'
    common = ['--candidate', candidate, '--mixed', '--expected-version', args.expected_version]
    results = []

    def record(label, directory):
        results.append({'label': label, 'path': str(directory.resolve())})
        (args.out / 'suite.json').write_text(json.dumps(results, ensure_ascii=False, indent=2) + '\n', 'utf8')

    normal = args.normal or run('run-brightness-tests.py', 'remains-lad-brightness-*', common + ['--mode', 'verify'])
    record('brightness:verify', normal)
    record('brightness:large', run('run-brightness-tests.py', 'remains-lad-brightness-*', common + ['--mode', 'large']))
    record('brightness:cold', run('run-brightness-tests.py', 'remains-lad-brightness-*', common + ['--mode', 'cold', '--seed-preferences', normal / 'storage/cold-preferences.json']))
    fixtures = run('run-landmark-tests.py', 'remains-lad-landmark-*', common + ['--mode', 'regression'])
    record('landmark:regression', fixtures)
    record('landmark:cold', run('run-landmark-tests.py', 'remains-lad-landmark-*', common + ['--mode', 'cold', '--seed-storage', fixtures / 'storage']))
    record('trail:verify', run('run-trail-tests.py', 'remains-lad-projectile-trails-*', common + ['--mode', 'verify']))
    print(json.dumps({'status': 'SUITE_PASS', 'evidence': results}), flush=True)


if __name__ == '__main__':
    main()
