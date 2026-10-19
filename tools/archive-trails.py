"""Archive the verified release receipt and compact evidence, excluding saved games."""
import hashlib
import json
from pathlib import Path
import shutil

MOD=Path(__file__).resolve().parents[1]
def read(path):return json.loads(path.read_text('utf-8-sig'))
def main():
    receipt=read(MOD/'state/trail-deployment-2026-10-20.json')
    assert receipt['restartSmoke']['status']=='PASS'
    out=MOD/'tests/evidence/2026-10-20/trails-v050'
    out.mkdir(parents=True,exist_ok=True)
    records=receipt['evidence']+[dict(receipt['restartSmoke'],label='installed')]
    files={}
    for record in records:
        source=(MOD/record['evidence']).resolve()
        assert source.is_relative_to((MOD/'build/evidence').resolve())
        target=out/record['label'].replace(':','-');target.mkdir(exist_ok=True)
        for path in source.iterdir():
            if path.is_file() and path.suffix in ['.json','.txt','.log']:
                shutil.copy2(path,target/path.name)
        for path in (source/'storage').iterdir():
            if path.is_file() and path.suffix in ['.json','.done','.log','.png']:
                shutil.copy2(path,target/path.name)
        for path in target.iterdir():
            files[str(path.relative_to(out)).replace('\\','/')]=hashlib.sha256(path.read_bytes()).hexdigest()
    shutil.copy2(MOD/'build/out/trails-v050/freeze.json',out/'freeze.json')
    (out/'index.json').write_text(json.dumps({'sha256':receipt['sha256'],'records':records,'files':files},ensure_ascii=False,indent=2)+'\n','utf8')
    print(json.dumps({'archived':len(records),'files':len(files),'directory':str(out)}))
if __name__=='__main__':main()
