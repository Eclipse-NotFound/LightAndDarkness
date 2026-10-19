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

MOD=Path(__file__).resolve().parents[1]
GAME=MOD.parents[1]
PYTHON=Path(sys.executable)
sys.path.insert(0,str(GAME/'mods/ModLoader/tools'))
from air_test_process import HiddenProcess

def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()

def main():
    stamp=datetime.now().strftime('%Y%m%d%H%M%S%f')
    appid='remains-lad-survey-'+stamp
    root=MOD/'build/generated'/appid
    evidence=MOD/'build/evidence'/appid
    root.mkdir(parents=True);evidence.mkdir(parents=True)
    tools=GAME/'mods/Sandevistan/build/tools'
    config=root/'probe-config.xml'
    from xml.sax.saxutils import escape
    config.write_text('<flex-config xmlns="http://www.adobe.com/2006/flex-config"><target-player>32.0</target-player><compiler><source-path><path-element>'+escape(str(MOD/'tests'))+'</path-element></source-path><external-library-path><path-element>'+escape(str(tools/'airsdk/frameworks/libs/air/airglobal.swc'))+'</path-element></external-library-path><debug>false</debug><optimize>true</optimize></compiler></flex-config>',encoding='utf8')
    probe=root/'MapLightingSurveyMod.swf'
    subprocess.run(['D:/Program Files/Adobe Animate 2024/jre/bin/java.exe','-Xmx768m','-jar',str(tools/'flexsdk/lib/mxmlc.jar'),'+flexlib='+str(tools/'flexsdk/frameworks'),'-load-config='+str(config),'-swf-version=32','-use-network=false','-static-link-runtime-shared-libraries=true','-output='+str(probe),str(MOD/'tests/MapLightingSurveyMod.as')],check=True)
    assets=['pfe.swf','texture.swf','texture1.swf','sprite.swf','sprite1.swf','sound.swf','sound_unit.swf','sound_weapon.swf','lang.xml','rooms.xml']
    assets += [p.name for p in GAME.glob('text_*.xml')]
    for name in assets:shutil.copy2(GAME/name,root/name)
    shutil.copytree(GAME/'Rooms',root/'Rooms')
    release=root/'mods/LightAndDarkness/release';release.mkdir(parents=True)
    shutil.copy2(MOD/'release/LightAndDarknessMod.swf',release/'LightAndDarknessMod.swf')
    shutil.copy2(probe,release/probe.name)
    shutil.copy2(MOD/'atmosphere.json',release.parent/'atmosphere.json')
    host=root/'mods/ModLoader';host.mkdir()
    for name in ('RemainsModLauncher.exe','RemainsModScanner.exe','supported-mods.txt'):
        shutil.copy2(GAME/'mods/ModLoader'/name,host/name)
    desc=root/'application.xml'
    desc.write_text(f'''<?xml version="1.0"?><application xmlns="http://ns.adobe.com/air/application/30.0"><id>{appid}</id><versionNumber>1.0</versionNumber><filename>MapLightingSurvey</filename><initialWindow><content>pfe.swf</content><visible>false</visible><width>1440</width><height>900</height><renderMode>direct</renderMode></initialWindow><supportedProfiles>extendedDesktop</supportedProfiles></application>''',encoding='utf8')
    launcher=GAME/'mods/ModLoader/RemainsModLauncher.exe'
    selected=subprocess.run([str(launcher),'--root',str(root),'--only','LightAndDarknessMod,MapLightingSurveyMod','--no-ui','--report',str(evidence/'selection.json')],capture_output=True)
    if selected.returncode:raise RuntimeError(selected.stderr.decode('utf8',errors='replace')+selected.stdout.decode('utf8',errors='replace'))
    selection=json.loads((evidence/'selection.json').read_text(encoding='utf-8-sig'))
    assert set(selection['configuration']['selected'])=={'LightAndDarknessMod','MapLightingSurveyMod'},selection
    frozen={str(p.relative_to(root)):sha(p) for p in root.rglob('*') if p.is_file()}
    (evidence/'hashes.json').write_text(json.dumps(frozen,indent=2),encoding='utf8')
    storage=Path(os.environ['APPDATA'])/appid/'Local Store'
    process=None
    try:
        with (evidence/'stdout.txt').open('wb') as stdout,(evidence/'stderr.txt').open('wb') as stderr:
            process=HiddenProcess([str(GAME/'adl64.exe'),'-runtime',str(GAME/'runtimes/air/win64'),str(desc),'-nodebug'],cwd=root,stdout=stdout,stderr=stderr)
            (evidence/'process.json').write_text(json.dumps({'applicationID':appid,'pid':process.pid,'desktop':process.desktop,'runtime':str(root)},indent=2),encoding='utf8')
            print('Evidence:',evidence,flush=True)
            deadline=time.monotonic()+220
            while process.poll() is None and time.monotonic()<deadline:
                time.sleep(.3)
    finally:
        if process:
            if process.poll() is None:process.kill();process.wait(timeout=10)
            process.close()
        if storage.exists():shutil.copytree(storage,evidence/'storage')
    assert (evidence/'storage/survey.done').read_text(encoding='utf8')=='PASS'
    result=json.loads((evidence/'storage/survey.json').read_text(encoding='utf8'))
    assert result['roomsLoad']==1 and len(result['catalog'])==31
    loader=result['loader'];expected={'LightAndDarknessMod','MapLightingSurveyMod'}
    assert {k[10:] for k in loader if k.startswith('requested_')}==expected
    assert {k[3:] for k in loader if k.startswith('ok_')}==expected
    assert not any(k.startswith('err_') for k in loader)
    assert all(sha(root/name)==digest for name,digest in frozen.items()),'Frozen runtime input changed'
    print(json.dumps(result,ensure_ascii=False,indent=2))

if __name__=='__main__':main()
