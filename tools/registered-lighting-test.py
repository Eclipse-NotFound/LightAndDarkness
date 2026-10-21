"""Run an existing LAD driver inside one shared game-test reservation.

Example: python -B tools/registered-lighting-test.py background -- --candidate ... --mixed
The selected driver still owns isolation, assertions and process cleanup.
"""
import argparse
import os
from pathlib import Path
import runpy
import sys

MOD = Path(__file__).resolve().parents[1]
GAME = MOD.parents[1]
THREAD_ID = '01a154dc-b4c2-7f42-837a-ce7541e37297'
ACTIVE = 'LIGHT_AND_DARKNESS_TEST_REGISTRATION'
RUNNERS = {
    'brightness': 'run-brightness-tests.py',
    'brightness-suite': 'run-brightness-suite.py',
    'brightness-release': 'install-brightness-and-smoke.py',
    'background': 'run-background-lighting-tests.py',
    'landmark': 'run-landmark-tests.py',
    'trail': 'run-trail-tests.py',
    'perf': 'run-lighting-perf.py',
    'release': 'install-background-and-smoke.py',
}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--wait', type=float, default=300)
    parser.add_argument('--owner', default='LightAndDarkness / 地区亮度')
    parser.add_argument('--purpose')
    parser.add_argument('runner', choices=sorted(set(RUNNERS) | set(RUNNERS.values())))
    parser.add_argument('arguments', nargs=argparse.REMAINDER)
    args = parser.parse_args()
    if os.environ.get(ACTIVE):
        parser.error('A LAD test reservation is already active; do not nest wrappers')
    target = MOD / 'tools' / RUNNERS.get(args.runner, args.runner)
    forwarded = args.arguments[1:] if args.arguments[:1] == ['--'] else args.arguments
    # Imports are read-only; do not leave bytecode in the shared tool directory.
    sys.dont_write_bytecode = True
    sys.path.insert(0, str(GAME / 'mods/ModLoader/tools'))
    from test_registry import Registration
    import air_test_process

    purpose = args.purpose or ('照明验证 / ' + target.name + ' ' + ' '.join(forwarded))
    with Registration(owner=args.owner, purpose=purpose, resource='game',
                      run_dir=MOD / 'build/evidence',
                      evidence=MOD / 'tests/brightness-2026-10-21.md',
                      wait=args.wait) as record:
        print('Test registration: ' + record.id, flush=True)
        original = air_test_process.HiddenProcess
        children = []

        class RegisteredProcess(original):
            def __init__(self, command, *, cwd, stdout, stderr):
                record.before_launch(target.name + ' / ' + str(Path(cwd).resolve()))
                super().__init__(command, cwd=cwd, stdout=stdout, stderr=stderr)
                children.append(self)
                # If registration fails after creation, the runner has not yet
                # received its handle. Stop only this newly created owned child.
                try:
                    record.child(self.pid)
                except BaseException:
                    if self.poll() is None:
                        self.kill()
                        self.wait(timeout=10)
                    original.close(self)
                    record.child_stopped()
                    raise

            def close(self):
                # Native close refuses a live child. Never release the launch
                # marker before process exit has actually been verified.
                super().close()
                record.child_stopped()

        previous_argv = sys.argv
        air_test_process.HiddenProcess = RegisteredProcess
        os.environ[ACTIVE] = record.id
        try:
            sys.argv = [str(target)] + forwarded
            # Existing drivers raise on failed business assertions. Their normal
            # return, after an actual child, is the only route to "passed".
            runpy.run_path(str(target), run_name='__main__')
            if children:
                record.outcome = 'passed'
                record.note = target.name + '正常完成，业务断言通过；范围见本模组报告'
            else:
                record.note = target.name + '仅完成准备，未启动游戏，未判定业务通过'
        finally:
            sys.argv = previous_argv
            air_test_process.HiddenProcess = original
            os.environ.pop(ACTIVE, None)


if __name__ == '__main__':
    main()
