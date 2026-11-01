"""Freeze, validate and deploy only the tested 0.7.1 performance bytes.

Adapted from release-brightness.py (the consumed 0.7.0 deployment script):
installs over the current 0.7.0 baseline (8ADBA691...), writes its own receipt,
and requires the same six-suite evidence set with unchanged semantics.
"""
import argparse
from datetime import datetime
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import xml.etree.ElementTree as ET

MOD = Path(__file__).resolve().parents[1]
GAME = MOD.parents[1]
VERSION = '0.7.1'
OLD_SHA = '8adba6914df5aada4df12a646b6c22df4b95b9630a55dd05ca7f713621c7e3ef'
BASELINE_SHA = 'e3233f78d7f9af8f0ac4f99aa78abb1f9fa0d4931b272d7d551b62c7c36e796e'
TARGET = MOD / 'release/LightAndDarknessMod.swf'
RECEIPT = MOD / 'state/perf-deployment-2026-11-02.json'
BASE = {'LightAndDarknessMod', 'ModLoaderMod', 'ContinuousSceneMod', 'RealisticVisionMod', 'WallBlendMod'}


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read(path):
    return json.loads(path.read_text('utf-8-sig'))


def save(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n', 'utf8')


def freeze(out):
    candidate = out / 'LightAndDarknessMod.swf'
    assert not (out / 'freeze.json').exists(), 'Use a fresh output directory for changed bytes'
    assert sha(TARGET) == OLD_SHA, 'Installed baseline changed; reconcile first'
    source = out / 'source'
    shutil.copytree(MOD / 'src', source)
    inputs = {p.relative_to(source).as_posix(): sha(p) for p in source.rglob('*.as')}
    protected = [GAME / 'application.xml', GAME / 'pfe.swf', GAME / 'mods/loader-manifest.txt', MOD / 'atmosphere.json']
    for name in ['ModLoader', 'ContinuousScene', 'RealisticVision', 'WallBlend']:
        protected += [p for p in (GAME / 'mods' / name / 'release').iterdir() if p.is_file() and p.suffix in ['.swf', '.txt', '.json', '.xml']]
    dependencies = {p.relative_to(GAME).as_posix(): sha(p) for p in protected}
    with (out / 'decompile.log').open('w', encoding='utf8') as log:
        subprocess.run(['D:/Program Files/Adobe Animate 2024/jre/bin/java.exe', '-Xmx768m', '-jar', str(GAME / 'mods/Sandevistan/build/tools/ffdec/ffdec-cli.jar'), '-export', 'script', str(out / 'decompiled'), str(candidate)], check=True, stdout=log, stderr=subprocess.STDOUT)
    classes = sorted(p.relative_to(out / 'decompiled').as_posix() for p in (out / 'decompiled').rglob('*.as'))
    assert len(classes) >= 21 and not any('/fe/' in '/' + p or any(s in p for s in ['Test', 'Probe', 'Checks']) for p in classes), classes
    assert any(p.endswith('LadBackdrop.as') for p in classes)
    assert '"' + VERSION + '"' in next((out / 'decompiled').rglob('LightAndDarknessMod.as')).read_text('utf8')
    assert all(sha(GAME / p) == h for p, h in dependencies.items())
    assert all(sha(MOD / 'src' / p) == h for p, h in inputs.items())
    save(out / 'freeze.json', dict(version=VERSION, sha256=sha(candidate), previousSha256=OLD_SHA, source=inputs, protected=dependencies, classes=classes, createdAt=datetime.now().astimezone().isoformat()))
    print(json.dumps({'status': 'FROZEN', 'sha256': sha(candidate), 'classes': len(classes)}))


def frozen(out):
    data = read(out / 'freeze.json')
    assert data['version'] == VERSION and sha(out / 'LightAndDarknessMod.swf') == data['sha256']
    assert all(sha(MOD / 'src' / p) == h for p, h in data['source'].items()), 'Source changed after freeze'
    assert all(sha(GAME / p) == h for p, h in data['protected'].items()), 'Dependency changed after validation'
    assert ET.parse(GAME / 'application.xml').getroot().find('{*}initialWindow/{*}content').text == 'pfe.swf'
    return data


def verify(folder, frozen_data):
    folder = folder.resolve()
    assert folder.is_relative_to((MOD / 'build/evidence').resolve())
    store = folder / 'storage'
    meta = read(folder / 'process.json')
    if (store / 'brightness.json').exists():
        data = read(store / 'brightness.json')
        mode = data['mode']; label = 'brightness:' + mode; entry = 'BrightnessTestMod'
        assert (store / 'brightness.done').read_text('utf8') == 'PASS'
        assert data['baselineVersion'] == '0.6.0' and data['checks'] >= 35
        assert all(a['pass'] for a in data['assertions'])
        guards = read(folder / 'guards.json')
        assert not guards['aborted'] and guards['observations'] and all(g['ok'] for g in guards['observations'])
        assert mode in ['verify', 'large', 'cold', 'smoke']
        assert len(data['samples']) >= (6 if mode == 'verify' else 3 if mode == 'large' else 1)
        if mode == 'large':
            assert all(s['regions'] > 1 for s in data['samples'][1:])
    elif (store / 'landmark.json').exists():
        data = read(store / 'landmark.json'); mode = data['mode']; label = 'landmark:' + mode; entry = 'LandmarkProbeMod'
        assert (store / 'landmark.done').read_text('utf8') == 'PASS'
        assert mode in ['verify', 'regression', 'cold']
        if mode == 'verify':
            assert data['checks'] >= 217
        else:
            log = (store / 'test.log').read_text('utf8')
            assert ' SUITE_PASS' in log and ' FAIL ' not in log
            data['checks'] = len(re.findall(r'^\d+ PASS ', log, re.M))
            assert data['checks'] >= (101 if mode == 'regression' else 11)
    else:
        data = read(store / 'trail.json'); label = 'trail:' + data['mode']; entry = 'TrailProbeMod'
        assert (store / 'trail.done').read_text('utf8') == 'PASS' and label == 'trail:verify' and data['checks'] >= 43
    assert data['version'] == VERSION and data['roomsLoad'] == 1 and not data.get('error')
    loader = data['loader']; session = re.fullmatch(r'run_(\d{13})_\d+', loader.get('session', ''))
    assert session and meta['startedMs'] <= int(session[1]) <= meta['endedMs']
    selected = set(read(folder / 'selection.json')['configuration']['selected'])
    assert selected == BASE | {entry}
    assert loader.get('boot') is not None and loader.get('boot_start') is not None
    assert not any(k.startswith('err_') for k in loader)
    for prefix in ['requested_', 'ok_']:
        assert {k[len(prefix):] for k in loader if k.startswith(prefix)} == selected
    log = (store / 'LightAndDarkness.log').read_text('utf8')
    assert 'v' + VERSION + ' loaded' in log
    assert not any(k in log for k in ['FRAME_ERROR', 'ATTACH_FAILED', 'PREPARE_FAILED', 'RESTORE_FAILED'])
    hashes = {k.replace('\\', '/'): v.lower() for k, v in read(folder / 'hashes.json').items()}
    assert hashes['mods/LightAndDarkness/release/LightAndDarknessMod.swf'] == frozen_data['sha256']
    if label.startswith('brightness:'):
        assert hashes['baseline.swf'] == BASELINE_SHA
    runtime = Path(meta['runtime']).resolve()
    assert runtime.is_relative_to((MOD / 'build/generated').resolve())
    generated = {'application.xml', 'baseline.swf', 'reference.swf', 'trail-mode.txt',
                 'projectile-mode.txt', 'landmark-mode.txt', 'test-mode.txt',
                 'terminal-checks.txt', 'probe-config.xml', 'perf.json',
                 'brightness-config.json', 'mods/loader-manifest.txt',
                 entry + '.swf', 'mods/LightAndDarkness/release/' + entry + '.swf',
                 'mods/LightAndDarkness/release/LightAndDarknessMod.swf'}
    for path, digest in hashes.items():
        copied = (runtime / path).resolve()
        assert copied.is_relative_to(runtime), ('Runtime input escapes its owned directory', path)
        assert copied.is_file() and sha(copied) == digest, ('Changed frozen runtime input', path)
        if path not in generated:
            original = (GAME / path).resolve()
            assert original.is_relative_to(GAME.resolve()), ('Game input escapes its directory', path)
            assert original.is_file() and sha(original) == digest, ('Changed formal test input', path)
    origins = folder / 'sources.json'
    if label.startswith('brightness:'):
        assert origins.is_file(), 'Background evidence is missing its source manifest'
    if origins.is_file():
        for source, digest in read(origins).items():
            original = Path(source)
            assert original.is_file() and sha(original) == digest.lower(), ('Changed source input', source)
    for path, digest in frozen_data['protected'].items():
        if path in ['application.xml', 'mods/loader-manifest.txt']:
            continue
        assert hashes.get(path) == digest and sha(runtime / path) == digest, path
    return dict(label=label, checks=data['checks'], evidence=folder.relative_to(MOD).as_posix(), session=loader['session'])


def rollback(receipt, reason):
    assert sha(TARGET) == receipt['sha256'], 'Installed file changed; refuse unrelated rollback'
    backup = Path(receipt['backup']); assert sha(backup) == OLD_SHA
    staged = backup.parent / ('rollback-' + datetime.now().strftime('%H%M%S%f') + '.swf')
    shutil.copy2(backup, staged); os.replace(staged, TARGET)
    receipt.update(restartSmoke={'status': 'FAILED_ROLLED_BACK', 'reason': reason}, rollbackAt=datetime.now().astimezone().isoformat())
    save(RECEIPT, receipt)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--out', required=True, type=Path)
    parser.add_argument('--freeze', action='store_true')
    parser.add_argument('--refreeze', type=Path, help='Copy unchanged candidate bytes to a fresh freeze after dependencies change')
    parser.add_argument('--evidence', action='append', type=Path)
    parser.add_argument('--install', action='store_true')
    parser.add_argument('--smoke', type=Path)
    parser.add_argument('--rollback-reason')
    args = parser.parse_args(); out = args.out.resolve()
    assert out.is_relative_to((MOD / 'build/out').resolve())
    if args.refreeze:
        previous = read(out / 'freeze.json')
        assert sha(out / 'LightAndDarknessMod.swf') == previous['sha256']
        assert all(sha(MOD / 'src' / p) == h for p, h in previous['source'].items())
        target = args.refreeze.resolve()
        assert target.is_relative_to((MOD / 'build/out').resolve()) and not target.exists()
        target.mkdir()
        shutil.copy2(out / 'LightAndDarknessMod.swf', target / 'LightAndDarknessMod.swf')
        freeze(target)
        assert read(target / 'freeze.json')['sha256'] == previous['sha256']
        return
    if args.freeze:
        freeze(out); return
    if args.rollback_reason:
        rollback(read(RECEIPT), args.rollback_reason); return
    data = frozen(out)
    if args.smoke:
        receipt = read(RECEIPT)
        try:
            assert sha(TARGET) == data['sha256'] == receipt['sha256']
            result = verify(args.smoke, data); assert result['label'] == 'brightness:smoke'
            receipt['restartSmoke'] = dict(status='PASS', **result, finishedAt=datetime.now().astimezone().isoformat())
            save(RECEIPT, receipt)
        except Exception as error:
            rollback(receipt, str(error)); raise
        print(json.dumps({'status': 'INSTALLED_SMOKE_PASS', 'sha256': data['sha256']})); return
    assert args.evidence
    results = [verify(path, data) for path in args.evidence]
    required = {'brightness:verify', 'brightness:large', 'brightness:cold', 'landmark:regression', 'landmark:cold', 'trail:verify'}
    assert {r['label'] for r in results} == required and len(results) == len(required)
    assert sha(TARGET) == OLD_SHA, 'Installed LAD changed concurrently'
    if not args.install:
        print(json.dumps({'status': 'PRECHECK_PASS', 'checks': sum(r['checks'] for r in results)})); return
    folder = MOD / 'build/backups' / ('perf071-' + datetime.now().strftime('%Y%m%d-%H%M%S-%f'))
    folder.mkdir(parents=True, exist_ok=False)
    backup = folder / 'LightAndDarknessMod.v0.7.0.swf'; staged = folder / 'LightAndDarknessMod.staged.swf'
    shutil.copy2(TARGET, backup); shutil.copy2(out / 'LightAndDarknessMod.swf', staged)
    assert sha(backup) == OLD_SHA and sha(staged) == data['sha256']
    frozen(out); assert sha(TARGET) == OLD_SHA
    receipt = dict(**data, evidence=results, backup=str(backup), installedAt=datetime.now().astimezone().isoformat(), restartSmoke={'status': 'pending'}, rollback='Restore only this backup while installed LAD matches this release; preserve other files and real saves.')
    try:
        os.replace(staged, TARGET); assert sha(TARGET) == data['sha256']
        save(RECEIPT, receipt)
        print(json.dumps({'status': 'DEPLOYED', 'sha256': data['sha256'], 'backup': str(backup)}))
    except BaseException as error:
        if sha(TARGET) == data['sha256']:
            rollback(receipt, str(error))
        raise


if __name__ == '__main__':
    main()
