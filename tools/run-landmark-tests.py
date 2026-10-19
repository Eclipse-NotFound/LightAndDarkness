"""Private desktop, private AIR ID, frozen copies, launcher-selected LAD + probe."""
from datetime import datetime
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import time
import argparse
import re

MOD=Path(__file__).resolve().parents[1]
GAME=MOD.parents[1]
PYTHON=Path(sys.executable)
sys.path.insert(0,str(GAME/'mods/ModLoader/tools'))
sys.dont_write_bytecode=True
from air_test_process import HiddenProcess

def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()

def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--candidate',default=str(MOD/'build/out/landmarks-v041/LightAndDarknessMod.swf'))
    parser.add_argument('--mode',choices=['atlas','verify','regression','cold'],default='atlas')
    parser.add_argument('--mixed',action='store_true')
    parser.add_argument('--expected-version',default='0.4.1')
    parser.add_argument('--seed-storage')
    parser.add_argument('--terminals',action='store_true')
    args=parser.parse_args()
    stamp=datetime.now().strftime('%Y%m%d%H%M%S%f')
    appid='remains-lad-landmark-'+stamp
    root=MOD/'build/generated'/appid
    evidence=MOD/'build/evidence'/appid
    root.mkdir(parents=True);evidence.mkdir(parents=True)
    tools=GAME/'mods/Sandevistan/build/tools'
    config=root/'probe-config.xml'
    from xml.sax.saxutils import escape
    config.write_text('<flex-config xmlns="http://www.adobe.com/2006/flex-config"><target-player>32.0</target-player><compiler><source-path><path-element>'+escape(str(MOD/'tests'))+'</path-element></source-path><external-library-path><path-element>'+escape(str(tools/'airsdk/frameworks/libs/air/airglobal.swc'))+'</path-element></external-library-path><debug>false</debug><optimize>true</optimize></compiler></flex-config>',encoding='utf8')
    probe=root/'LandmarkProbeMod.swf'
    subprocess.run(['D:/Program Files/Adobe Animate 2024/jre/bin/java.exe','-Xmx768m','-jar',str(tools/'flexsdk/lib/mxmlc.jar'),'+flexlib='+str(tools/'flexsdk/frameworks'),'-load-config='+str(config),'-swf-version=32','-use-network=false','-static-link-runtime-shared-libraries=true','-output='+str(probe),str(MOD/'tests/LandmarkProbeMod.as')],check=True)
    assets=['pfe.swf','texture.swf','texture1.swf','sprite.swf','sprite1.swf','sound.swf','sound_unit.swf','sound_weapon.swf','lang.xml','rooms.xml']
    assets += [p.name for p in GAME.glob('text_*.xml')]
    for name in assets:shutil.copy2(GAME/name,root/name)
    shutil.copytree(GAME/'Rooms',root/'Rooms')
    release=root/'mods/LightAndDarkness/release';release.mkdir(parents=True)
    shutil.copy2(args.candidate,release/'LightAndDarknessMod.swf')
    shutil.copy2(probe,release/probe.name)
    shutil.copy2(MOD/'atmosphere.json',release.parent/'atmosphere.json')
    host=root/'mods/ModLoader';host.mkdir()
    for name in ('RemainsModLauncher.exe','RemainsModScanner.exe','supported-mods.txt'):
        shutil.copy2(GAME/'mods/ModLoader'/name,host/name)
    entries=['LightAndDarknessMod','LandmarkProbeMod']
    if args.mixed:
        for name in ['ModLoader','ContinuousScene','RealisticVision','WallBlend']:
            dep=root/'mods'/name/'release';dep.mkdir(parents=True,exist_ok=True)
            for f in (GAME/'mods'/name/'release').iterdir():
                if f.is_file() and f.suffix in ['.swf','.txt','.json','.xml']:shutil.copy2(f,dep/f.name)
            entries.append(name+'Mod')
    (root/'landmark-mode.txt').write_text(args.mode,'utf-8')
    if args.terminals:(root/'terminal-checks.txt').write_text('1','utf8')
    (root/'test-mode.txt').write_text('cold' if args.mode=='cold' else 'mixed' if args.mixed else 'single','utf-8')
    desc=root/'application.xml'
    desc.write_text(f'''<?xml version="1.0"?><application xmlns="http://ns.adobe.com/air/application/30.0"><id>{appid}</id><versionNumber>1.0</versionNumber><filename>MapLightingSurvey</filename><initialWindow><content>pfe.swf</content><visible>false</visible><width>1440</width><height>900</height><renderMode>direct</renderMode></initialWindow><supportedProfiles>extendedDesktop</supportedProfiles></application>''',encoding='utf8')
    launcher=GAME/'mods/ModLoader/RemainsModLauncher.exe'
    selected=subprocess.run([str(launcher),'--root',str(root),'--only',','.join(entries),'--no-ui','--report',str(evidence/'selection.json')],capture_output=True)
    if selected.returncode:raise RuntimeError(selected.stderr.decode('utf8',errors='replace')+selected.stdout.decode('utf8',errors='replace'))
    selection=json.loads((evidence/'selection.json').read_text(encoding='utf-8-sig'))
    assert set(selection['configuration']['selected'])==set(entries),selection
    frozen={str(p.relative_to(root)):sha(p) for p in root.rglob('*') if p.is_file()}
    (evidence/'hashes.json').write_text(json.dumps(frozen,indent=2),encoding='utf8')
    storage=Path(os.environ['APPDATA'])/appid/'Local Store'
    if args.seed_storage:
        source=Path(args.seed_storage).resolve()
        if not source.is_relative_to((MOD/'build').resolve()):raise ValueError('Only owned test evidence may seed a run')
        for item in source.rglob('*.sol'):
            destination=storage/item.relative_to(source);destination.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(item,destination)
    process=None
    started_ms=int(time.time()*1000)
    try:
        with (evidence/'stdout.txt').open('wb') as stdout,(evidence/'stderr.txt').open('wb') as stderr:
            process=HiddenProcess([str(GAME/'adl64.exe'),'-runtime',str(GAME/'runtimes/air/win64'),str(desc),'-nodebug'],cwd=root,stdout=stdout,stderr=stderr)
            (evidence/'process.json').write_text(json.dumps({'applicationID':appid,'pid':process.pid,'desktop':process.desktop,'runtime':str(root)},indent=2),encoding='utf8')
            print('Evidence:',evidence,flush=True)
            deadline=time.monotonic()+440
            while process.poll() is None and time.monotonic()<deadline:
                if (storage/'landmark.done').exists() or (evidence/'stop-request').exists():break
                time.sleep(.3)
    finally:
        if process:
            if process.poll() is None:process.kill();process.wait(timeout=10)
            process.close()
            meta=json.loads((evidence/'process.json').read_text('utf8'));meta.update(startedMs=started_ms,endedMs=int(time.time()*1000))
            (evidence/'process.json').write_text(json.dumps(meta,indent=2),'utf8')
        if storage.exists():shutil.copytree(storage,evidence/'storage')
    done=(evidence/'storage/landmark.done').read_text(encoding='utf8')
    assert done=='PASS',done
    result=json.loads((evidence/'storage/landmark.json').read_text(encoding='utf8'))
    assert result['roomsLoad']==1 and result['version']==args.expected_version
    if args.mode=='verify':assert result['checks']>=(217 if args.terminals else 124)
    if args.mode in ['regression','cold']:
        checks=(evidence/'storage/test.log').read_text('utf8')
        assert ' SUITE_PASS' in checks and ' FAIL ' not in checks
        assert len(re.findall(r'^\d+ PASS ',checks,re.M))>=(101 if args.mode=='regression' else 11)
    loader=result['loader'];expected=set(entries)
    session=re.fullmatch(r'run_(\d{13})_\d+',loader.get('session',''))
    assert session and started_ms<=int(session[1])<=int(time.time()*1000),'Stale or missing loader session'
    assert loader.get('boot') is not None and loader.get('boot_start') is not None
    assert {k[10:] for k in loader if k.startswith('requested_')}==expected
    assert {k[3:] for k in loader if k.startswith('ok_')}==expected
    assert not any(k.startswith('err_') for k in loader)
    assert all(sha(root/name)==digest for name,digest in frozen.items()),'Frozen runtime input changed'
    log=(evidence/'storage/LightAndDarkness.log').read_text('utf-8')
    assert ('v'+args.expected_version+' loaded') in log and 'heartbeat' in log
    assert not any(key in log for key in ['FRAME_ERROR','ATTACH_FAILED','PREPARE_FAILED','RESTORE_FAILED'])
    print(json.dumps({'result':'PASS','evidence':str(evidence),'mode':args.mode,'samples':len(result['samples'])},ensure_ascii=False))

if __name__=='__main__':main()
