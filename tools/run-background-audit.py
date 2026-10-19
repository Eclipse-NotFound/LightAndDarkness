"""Copy installed bytes, then investigate on one private desktop and AIR identity.

No production builds or deployments. Comparisons inside each sample share one
paused scene; screenshots are software draws, not a foreground GPU/FPS test.
"""
from datetime import datetime
from pathlib import Path
import argparse
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import time
from xml.sax.saxutils import escape

MOD = Path(__file__).resolve().parents[1]
GAME = MOD.parents[1]
sys.dont_write_bytecode = True
sys.path.insert(0, str(GAME / 'mods/ModLoader/tools'))
from air_test_process import HiddenProcess


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--large', action='store_true')
    args = parser.parse_args()
    appid = 'remains-lad-background-' + datetime.now().strftime('%Y%m%d%H%M%S%f')
    root = MOD / 'build/generated' / appid
    evidence = MOD / 'build/evidence' / appid
    root.mkdir(parents=True)
    evidence.mkdir(parents=True)
    sdk = GAME / 'mods/Sandevistan/build/tools'
    config = root / 'probe-config.xml'
    config.write_text('<flex-config xmlns="http://www.adobe.com/2006/flex-config"><target-player>32.0</target-player><compiler><source-path><path-element>' + escape(str(MOD / 'tests')) + '</path-element></source-path><external-library-path><path-element>' + escape(str(sdk / 'airsdk/frameworks/libs/air/airglobal.swc')) + '</path-element></external-library-path><debug>false</debug><optimize>true</optimize></compiler></flex-config>', encoding='utf8')
    probe = root / 'BackgroundAuditProbeMod.swf'
    subprocess.run(['D:/Program Files/Adobe Animate 2024/jre/bin/java.exe', '-Xmx768m', '-jar', str(sdk / 'flexsdk/lib/mxmlc.jar'), '+flexlib=' + str(sdk / 'flexsdk/frameworks'), '-load-config=' + str(config), '-swf-version=32', '-use-network=false', '-static-link-runtime-shared-libraries=true', '-output=' + str(probe), str(MOD / 'tests/BackgroundAuditProbeMod.as')], check=True)
    assert sha(MOD / 'release/LightAndDarknessMod.swf') == '94a2f0861b9757815f1554d5fbf3c216f403053d1ebcf4b546f9f7a2868a21bd'
    names = ['pfe.swf', 'texture.swf', 'texture1.swf', 'sprite.swf', 'sprite1.swf', 'sound.swf', 'sound_unit.swf', 'sound_weapon.swf', 'lang.xml', 'rooms.xml']
    names += [p.name for p in GAME.glob('text_*.xml')]
    source_hashes = {}
    for name in names:
        shutil.copy2(GAME / name, root / name)
        source_hashes[name] = sha(GAME / name)
    shutil.copytree(GAME / 'Rooms', root / 'Rooms')
    release = root / 'mods/LightAndDarkness/release'
    release.mkdir(parents=True)
    shutil.copy2(MOD / 'release/LightAndDarknessMod.swf', release / 'LightAndDarknessMod.swf')
    shutil.copy2(probe, release / probe.name)
    shutil.copy2(MOD / 'atmosphere.json', release.parent / 'atmosphere.json')
    host = root / 'mods/ModLoader'
    host.mkdir()
    for name in ('RemainsModLauncher.exe', 'RemainsModScanner.exe', 'supported-mods.txt'):
        shutil.copy2(GAME / 'mods/ModLoader' / name, host / name)
    entries = ['LightAndDarknessMod', 'BackgroundAuditProbeMod']
    for name in ['ModLoader', 'ContinuousScene', 'RealisticVision', 'WallBlend']:
        dest = root / 'mods' / name / 'release'
        dest.mkdir(parents=True, exist_ok=True)
        for f in (GAME / 'mods' / name / 'release').iterdir():
            if f.is_file() and f.suffix in ['.swf', '.txt', '.json', '.xml']:
                shutil.copy2(f, dest / f.name)
                source_hashes[str(f.relative_to(GAME))] = sha(f)
        entries.append(name + 'Mod')
    if args.large:
        (root / 'large-mode.txt').write_text('true', encoding='utf8')
    desc = root / 'application.xml'
    desc.write_text(f'<?xml version="1.0"?><application xmlns="http://ns.adobe.com/air/application/30.0"><id>{appid}</id><versionNumber>1.0</versionNumber><filename>BackgroundAudit</filename><initialWindow><content>pfe.swf</content><visible>false</visible><width>1440</width><height>900</height><renderMode>direct</renderMode></initialWindow><supportedProfiles>extendedDesktop</supportedProfiles></application>', encoding='utf8')
    selected = subprocess.run([str(GAME / 'mods/ModLoader/RemainsModLauncher.exe'), '--root', str(root), '--only', ','.join(entries), '--no-ui', '--report', str(evidence / 'selection.json')], capture_output=True)
    if selected.returncode:
        raise RuntimeError(selected.stderr.decode('utf8', errors='replace') + selected.stdout.decode('utf8', errors='replace'))
    selection = json.loads((evidence / 'selection.json').read_text(encoding='utf-8-sig'))
    assert set(selection['configuration']['selected']) == set(entries)
    frozen = {str(p.relative_to(root)): sha(p) for p in root.rglob('*') if p.is_file()}
    (evidence / 'hashes.json').write_text(json.dumps(frozen, indent=2), encoding='utf8')
    (evidence / 'sources.json').write_text(json.dumps(source_hashes, indent=2), encoding='utf8')
    storage = Path(os.environ['APPDATA']) / appid / 'Local Store'
    storage.mkdir(parents=True)
    (storage / 'ContinuousScene.preferences.json').write_text(json.dumps({'nativeEnabled': args.large}), encoding='utf8')
    process = None
    started_ms = int(time.time() * 1000)
    try:
        with (evidence / 'stdout.txt').open('wb') as stdout, (evidence / 'stderr.txt').open('wb') as stderr:
            process = HiddenProcess([str(GAME / 'adl64.exe'), '-runtime', str(GAME / 'runtimes/air/win64'), str(desc), '-nodebug'], cwd=root, stdout=stdout, stderr=stderr)
            meta = {'applicationID': appid, 'pid': process.pid, 'desktop': process.desktop, 'runtime': str(root), 'startedMs': started_ms}
            (evidence / 'process.json').write_text(json.dumps(meta, indent=2), encoding='utf8')
            print('Evidence:', evidence, flush=True)
            deadline = time.monotonic() + 600
            while process.poll() is None and time.monotonic() < deadline:
                if (storage / 'audit.done').exists() or (evidence / 'stop-request').exists():
                    break
                time.sleep(.3)
    finally:
        if process:
            if process.poll() is None:
                process.kill()
                process.wait(timeout=10)
            process.close()
            meta['endedMs'] = int(time.time() * 1000)
            (evidence / 'process.json').write_text(json.dumps(meta, indent=2), encoding='utf8')
        if storage.exists():
            shutil.copytree(storage, evidence / 'storage')
    assert (evidence / 'storage/audit.done').read_text(encoding='utf8') == 'PASS'
    result = json.loads((evidence / 'storage/audit.json').read_text(encoding='utf8'))
    assert result['roomsLoad'] == 1 and result['version'] == '0.4.1'
    assert len(result['samples']) == (3 if args.large else 12)
    if args.large:
        assert all(r['regions'] > 1 for r in result['samples'][1:])
    loader = result['loader']
    session = re.fullmatch(r'run_(\d{13})_\d+', loader.get('session', ''))
    assert session and started_ms <= int(session[1]) <= int(time.time() * 1000)
    assert loader.get('boot') is not None and loader.get('boot_start') is not None
    assert {k[10:] for k in loader if k.startswith('requested_')} == set(entries)
    assert {k[3:] for k in loader if k.startswith('ok_')} == set(entries)
    assert not any(k.startswith('err_') for k in loader)
    assert all(sha(root / name) == digest for name, digest in frozen.items())
    log = (evidence / 'storage/LightAndDarkness.log').read_text(encoding='utf8')
    assert 'v0.4.1 loaded' in log and 'heartbeat' in log
    assert not any(key in log for key in ['FRAME_ERROR', 'ATTACH_FAILED', 'PREPARE_FAILED', 'RESTORE_FAILED'])
    print(json.dumps({'result': 'PASS', 'evidence': str(evidence), 'samples': len(result['samples'])}, ensure_ascii=False))


if __name__ == '__main__':
    main()
