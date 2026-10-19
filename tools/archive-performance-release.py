"""Retain the verified release receipt and private functional evidence in the repo."""
import hashlib, json, shutil
from pathlib import Path
MOD=Path(__file__).resolve().parents[1]
def read(path):return json.loads(path.read_text('utf-8-sig'))
def main():
    receipt=read(MOD/'state/performance-deployment-2026-10-20.json')
    assert receipt['restartSmoke']['status']=='PASS'
    target=MOD/'tests/evidence/2026-10-20/performance-v051'
    target.mkdir(parents=True,exist_ok=False)
    records=receipt['evidence']+[receipt['restartSmoke']]
    # Keep rejected fixture runs too; they were fixed without weakening assertions.
    paths={r['evidence'] for r in records}
    paths.update('build/evidence/'+n for n in ['remains-lad-landmark-20261020025127632409','remains-lad-landmark-20261020025309629345'])
    for name in sorted(paths):
        source=(MOD/name).resolve()
        assert source.is_relative_to((MOD/'build/evidence').resolve())
        out=target/source.name;out.mkdir()
        for filename in ['process.json','selection.json','hashes.json','inventory.json','competition.json','stdout.txt','stderr.txt']:
            if (source/filename).exists():shutil.copy2(source/filename,out/filename)
        shutil.copytree(source/'storage',out/'storage')
    shutil.copy2(MOD/'state/performance-deployment-2026-10-20.json',target/'deployment.json')
    files={p.relative_to(target).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in target.rglob('*') if p.is_file()}
    (target/'index.json').write_text(json.dumps({'sha256':receipt['sha256'],'checks':sum(r['checks'] for r in records),'files':files},ensure_ascii=False,indent=2)+'\n','utf8')
    print(json.dumps({'archive':str(target),'files':len(files),'checks':sum(r['checks'] for r in records)}))
if __name__=='__main__':main()
