"""Snapshot source, build once, retain exact production/dependency fingerprints."""
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
from datetime import datetime

MOD=Path(__file__).resolve().parents[1]
GAME=MOD.parents[1]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
    out=MOD/'build/out/trails-v050'
    out.mkdir(parents=True,exist_ok=False)
    source=out/'source';shutil.copytree(MOD/'src',source)
    inputs={str(p.relative_to(source)).replace('\\','/'):sha(p) for p in source.rglob('*.as')}
    assert all(sha(MOD/'src'/name)==digest for name,digest in inputs.items())
    protected=[GAME/'application.xml',GAME/'pfe.swf',GAME/'mods/loader-manifest.txt',MOD/'atmosphere.json']
    for name in ['ModLoader','ContinuousScene','RealisticVision','WallBlend']:
        protected.extend(p for p in (GAME/'mods'/name/'release').iterdir() if p.is_file() and p.suffix in ['.swf','.txt','.json','.xml'])
    frozen={str(p.relative_to(GAME)).replace('\\','/'):sha(p) for p in protected}
    old=sha(MOD/'release/LightAndDarknessMod.swf')
    assert old=='94a2f0861b9757815f1554d5fbf3c216f403053d1ebcf4b546f9f7a2868a21bd'
    subprocess.run(['pwsh','-NoProfile','-File',str(MOD/'build/build.ps1'),'-OutputDirectory',str(out),'-SourceDirectory',str(source)],check=True)
    candidate=out/'LightAndDarknessMod.swf'
    java='D:/Program Files/Adobe Animate 2024/jre/bin/java.exe'
    ffdec=GAME/'mods/Sandevistan/build/tools/ffdec/ffdec-cli.jar'
    subprocess.run([java,'-Xmx768m','-jar',str(ffdec),'-export','script',str(out/'decompiled'),str(candidate)],check=True,stdout=(out/'decompile.log').open('w',encoding='utf8'),stderr=subprocess.STDOUT)
    classes=sorted(str(p.relative_to(out/'decompiled')).replace('\\','/') for p in (out/'decompiled').rglob('*.as'))
    assert len(classes)==20,classes
    assert not any('/fe/' in p or 'Probe' in p or 'Checks' in p or 'Test' in p for p in classes),classes
    assert all(sha(GAME/name)==digest for name,digest in frozen.items())
    assert all(sha(MOD/'src'/name)==digest for name,digest in inputs.items()),'Production source changed during freeze'
    data=dict(version='0.5.0',sha256=sha(candidate),previousSha256=old,source=inputs,protected=frozen,classes=classes,createdAt=datetime.now().astimezone().isoformat())
    (out/'freeze.json').write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n','utf8')
    print(json.dumps({'candidate':str(candidate),'sha256':data['sha256'],'classes':len(classes)}))
if __name__=='__main__':main()
