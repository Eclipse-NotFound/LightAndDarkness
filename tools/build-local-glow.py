"""Isolate this tuning from the separately paused motion-cache candidate.

Build only: export released 0.4.1 source, overlay the two light collectors.
Final deployment belongs to the coordinated integration release.
"""
from pathlib import Path
import hashlib,json,subprocess

MOD=Path(__file__).resolve().parents[1]
BASE='c5a04c4'
VERSION='0.4.1-glow'
OUT=MOD/'build/out/local-glow'
SOURCE=MOD/'build/generated/local-glow-src'

def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()

files=subprocess.check_output(['git','ls-tree','-r','--name-only',BASE,'src'],cwd=MOD,text=True).splitlines()
for name in files:
    target=SOURCE/Path(name).relative_to('src');target.parent.mkdir(parents=True,exist_ok=True)
    target.write_bytes(subprocess.check_output(['git','show',BASE+':'+name],cwd=MOD))
for name in ['lad/LadMachineLights.as','lad/LadLandmarkLights.as']:
    (SOURCE/name).write_bytes((MOD/'src'/name).read_bytes())
for name in ['LightAndDarknessMod.as','lad/LadRuntime.as']:
    entry=SOURCE/name
    entry.write_text(entry.read_text('utf8').replace('0.4.1',VERSION),'utf8')
subprocess.run(['powershell','-NoProfile','-File',str(MOD/'build/build.ps1'),'-SourceDirectory',str(SOURCE),'-OutputDirectory',str(OUT)],check=True,cwd=MOD)
(OUT/'source.json').write_text(json.dumps(dict(base=BASE,version=VERSION,sources={str(p.relative_to(SOURCE)):sha(p) for p in SOURCE.rglob('*.as')},sha256=sha(OUT/'LightAndDarknessMod.swf')),indent=2),'utf8')
