"""Freeze the already tested bytes and the currently installed dependencies; do not rebuild."""
import hashlib, json, shutil, subprocess
from pathlib import Path
from datetime import datetime
MOD=Path(__file__).resolve().parents[1]
GAME=MOD.parents[1]
OUT=MOD/'build/out/perf-v051-visible'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
    candidate=OUT/'LightAndDarknessMod.swf'
    assert sha(candidate)=='bafe52b9145194c2e9d3a08a3331236fee5f1b6a3e1f016a46d9bc288c04c47a'
    assert not (OUT/'freeze.json').exists()
    old=sha(MOD/'release/LightAndDarknessMod.swf')
    assert old=='4291b8250d607ea1c6b5be48ded48bb5fa42af37bfe0cb3ed7a2e7c84efbbf90'
    source=OUT/'source';shutil.copytree(MOD/'src',source)
    inputs={p.relative_to(source).as_posix():sha(p) for p in source.rglob('*.as')}
    protected=[GAME/'application.xml',GAME/'pfe.swf',GAME/'mods/loader-manifest.txt',MOD/'atmosphere.json']
    for name in ['ModLoader','ContinuousScene','RealisticVision','WallBlend']:
        protected.extend(p for p in (GAME/'mods'/name/'release').iterdir() if p.is_file() and p.suffix in ['.swf','.txt','.json','.xml'])
    frozen={p.relative_to(GAME).as_posix():sha(p) for p in protected}
    java='D:/Program Files/Adobe Animate 2024/jre/bin/java.exe'
    ffdec=GAME/'mods/Sandevistan/build/tools/ffdec/ffdec-cli.jar'
    with (OUT/'decompile.log').open('w',encoding='utf8') as log:
        subprocess.run([java,'-Xmx768m','-jar',str(ffdec),'-export','script',str(OUT/'decompiled'),str(candidate)],check=True,stdout=log,stderr=subprocess.STDOUT)
    classes=sorted(p.relative_to(OUT/'decompiled').as_posix() for p in (OUT/'decompiled').rglob('*.as'))
    assert len(classes)==21 and not any('/fe/' in p or 'Probe' in p or 'Checks' in p or 'Test' in p for p in classes),classes
    assert all(sha(GAME/n)==h for n,h in frozen.items()),'Dependency changed during freeze'
    assert all(sha(MOD/'src'/n)==h for n,h in inputs.items()),'Source changed during freeze'
    data=dict(version='0.5.1',sha256=sha(candidate),previousSha256=old,source=inputs,protected=frozen,classes=classes,createdAt=datetime.now().astimezone().isoformat())
    (OUT/'freeze.json').write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n','utf8')
    print(json.dumps({'candidate':str(candidate),'sha256':data['sha256'],'classes':len(classes)}))
if __name__=='__main__':main()
