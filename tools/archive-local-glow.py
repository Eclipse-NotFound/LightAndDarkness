"""Retain owned test evidence without game assets or private test saves."""
from pathlib import Path
import argparse,hashlib,json,shutil

MOD=Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser();p.add_argument('--machine',required=True);p.add_argument('--landmark',required=True);p.add_argument('--tag',required=True);a=p.parse_args()
assert a.tag.replace('-','').isalnum()
out=MOD/'tests/evidence/2026-10-20/local-glow'/a.tag
out.mkdir(parents=True,exist_ok=False)
index={}
for kind,run in [('machine',a.machine),('landmark',a.landmark)]:
    source=MOD/'build/evidence'/run
    assert source.resolve().is_relative_to((MOD/'build/evidence').resolve())
    dest=out/kind;dest.mkdir()
    files=['process.json','selection.json','hashes.json','stdout.txt','stderr.txt']
    names=['LightAndDarkness.log','checks.log','landmark.json','landmark.done','loader.json','machine-test.log','terminal-native-tree.json','terminal-native-atlas.png','terminals-unhacked.png','terminals-hacked.png','landmarks-after.png','camp-after.png','machines-after.png','game-microglow-on.png']
    files+=['storage/'+name for name in names]
    copied={}
    for rel in files:
        f=source/rel
        if not f.is_file():continue
        target=dest/rel;target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(f,target)
        copied[rel]=hashlib.sha256(target.read_bytes()).hexdigest()
    index[kind]={'source':str(source.relative_to(MOD)),'files':copied}
(out/'index.json').write_text(json.dumps(index,indent=2)+'\n','utf8')
print(out)
