"""Keep compact logs, metrics and screenshots; never archive disposable save files."""
import argparse
import json
from pathlib import Path
import shutil

MOD=Path(__file__).resolve().parents[1]

def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--run',action='append',required=True,help='label=application ID')
    args=parser.parse_args()
    output=MOD/'tests/evidence/2026-10-19/landmarks-v041'
    records=[]
    for spec in args.run:
        label,appid=spec.split('=',1)
        assert label.isidentifier() and appid.startswith('remains-lad-landmark-') and '/' not in appid and '\\' not in appid
        source=MOD/'build/evidence'/appid
        target=output/label
        target.mkdir(parents=True,exist_ok=True)
        for name in ['hashes.json','process.json','selection.json','stdout.txt','stderr.txt']:
            if (source/name).exists():shutil.copy2(source/name,target/name)
        for path in (source/'storage').iterdir():
            if path.is_file() and path.suffix in ['.log','.json','.done','.png']:
                shutil.copy2(path,target/path.name)
        data=json.loads((target/'landmark.json').read_text('utf8'))
        records.append(dict(label=label,applicationID=appid,mode=data['mode'],samples=len(data['samples']),result=(target/'landmark.done').read_text('utf8')))
    (output/'index.json').write_text(json.dumps(records,ensure_ascii=False,indent=2)+'\n','utf8')
    print(json.dumps(records,ensure_ascii=False))

if __name__=='__main__':main()
