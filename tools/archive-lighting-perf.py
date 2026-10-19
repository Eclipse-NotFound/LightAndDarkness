"""Keep compact, exact timing/loading evidence; recover completed probe output after wrapper errors."""
from pathlib import Path
import hashlib, json, os, re, shutil, sys
sys.dont_write_bytecode=True
MOD=Path(__file__).resolve().parents[1]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest().upper()
def main():
    destination=MOD/'tests/evidence/2026-10-20/performance'
    destination.mkdir(parents=True,exist_ok=True)
    for app in sys.argv[1:]:
        if not re.fullmatch(r'remains-lad-perf-\d+',app):raise ValueError(app)
        evidence=MOD/'build/evidence'/app;meta=json.loads((evidence/'process.json').read_text('utf-8'))
        assert meta['applicationID']==app
        out=destination/app
        if out.exists():raise FileExistsError(out)
        out.mkdir()
        for name in ['process.json','selection.json','hashes.json','inventory.json','stderr.txt']:
            if (evidence/name).exists():shutil.copy2(evidence/name,out/name)
        storage=evidence/'storage';recovered=False
        if not (storage/'perf-result.json').exists():
            storage=Path(os.environ['APPDATA'])/app/'Local Store';recovered=True
        for name in ['perf-result.json','progress.json','LightAndDarkness.log','pixel-mismatch.json']:
            if (storage/name).exists():shutil.copy2(storage/name,out/name)
        root=MOD/'build/generated'/app
        hashes=json.loads((evidence/'hashes.json').read_text('utf-8'))
        unchanged=all((root/n).exists() and sha(root/n)==v for n,v in hashes.items())
        checks={'recoveredOriginalStorage':recovered,'frozenInputUnchanged':unchanged,'performanceGuard':meta.get('performanceEligible','not-recorded')}
        result_path=out/'perf-result.json'
        if result_path.exists():
            result=json.loads(result_path.read_text('utf-8'));loader=result['loader']
            selected=json.loads((evidence/'selection.json').read_text('utf-8-sig'))['configuration']['selected']
            session=re.fullmatch(r'run_(\d{13})_\d+',loader.get('session',''))
            checks.update(probeOK=result['ok'],checks=result['checks'],version=result['version'],completedMs=int((storage/'perf-result.json').stat().st_mtime*1000),
                loaderFresh=bool(session and meta['startedMs']<=int(session[1])),
                exactRequested={k[10:] for k in loader if k.startswith('requested_')}==set(selected),
                exactLoaded={k[3:] for k in loader if k.startswith('ok_')}==set(selected),
                loaderErrors=[k for k in loader if k.startswith('err_')])
        (out/'archive-checks.json').write_text(json.dumps(checks,indent=2),'utf-8')
        print(app,json.dumps(checks))
if __name__=='__main__':main()
