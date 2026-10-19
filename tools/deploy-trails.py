"""Gate the frozen 0.5.0 bytes, replace only LAD, verify the installed copy or roll back."""
import argparse
from datetime import datetime
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import xml.etree.ElementTree as ET

MOD=Path(__file__).resolve().parents[1]
GAME=MOD.parents[1]
OUT=MOD/'build/out/trails-v050'
TARGET=MOD/'release/LightAndDarknessMod.swf'
RECEIPT=MOD/'state/trail-deployment-2026-10-20.json'
BASE={'LightAndDarknessMod','ModLoaderMod','ContinuousSceneMod','RealisticVisionMod','WallBlendMod'}
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def read(p):return json.loads(p.read_text('utf-8-sig'))
def frozen():
    f=read(OUT/'freeze.json')
    assert f['version']=='0.5.0' and sha(OUT/'LightAndDarknessMod.swf')==f['sha256']
    assert len(f['classes'])==20 and not any('/fe/' in p or 'Probe' in p or 'Test' in p for p in f['classes'])
    assert all(sha(MOD/'src'/p)==h for p,h in f['source'].items()),'Frozen source changed'
    assert all(sha(GAME/p)==h for p,h in f['protected'].items()),'Host or dependency changed; reconcile before release'
    assert ET.parse(GAME/'application.xml').getroot().find('{*}initialWindow/{*}content').text=='pfe.swf'
    return f
def verify(folder,f):
    folder=folder.resolve();assert folder.is_relative_to((MOD/'build/evidence').resolve())
    meta=read(folder/'process.json');store=folder/'storage';label='';count=0
    if (store/'trail.json').exists():
        data=read(store/'trail.json');mode=data['mode'];label='trail:'+mode
        assert (store/'trail.done').read_text('utf8')=='PASS' and not data['error']
        assert data['version']=='0.5.0' and data['roomsLoad']==1
        count=data['checks'];entry='TrailProbeMod';loader=data['loader']
        if mode=='verify':assert count>=35
        elif mode=='legacy':assert count>=131
        elif mode=='cold':assert count>=4
        elif mode=='perf':
            gate=read(folder/'competition.json');assert gate['checked'] and gate['competingPids']==[]
            assert len(data['samples'])==16
            for row in data['samples']:
                assert len(row['combined']['raw'])==80 and row['maxLights']<=24
                if row['candidate']:assert row['maxVisits']<=65536
        else:raise AssertionError('Unexpected trail mode')
    elif (store/'landmark.json').exists():
        data=read(store/'landmark.json');mode=data['mode'];label='landmark:'+mode
        assert (store/'landmark.done').read_text('utf8')=='PASS' and not data['error']
        assert data['version']=='0.5.0' and data['roomsLoad']==1
        entry='LandmarkProbeMod';loader=data['loader'];count=data['checks']
        if mode=='verify':assert count>=217
        else:
            assert mode in ['regression','cold']
            log=(store/'test.log').read_text('utf8');assert ' SUITE_PASS' in log and ' FAIL ' not in log
            count=len(re.findall(r'^\d+ PASS ',log,re.M));assert count>=(101 if mode=='regression' else 11)
    elif (store/'perf-result.json').exists():
        data=read(store/'perf-result.json');label='pixels';entry='LightingPerfProbeMod';loader=data['loader'];count=data['checks']
        assert data['ok'] and data['version']=='0.5.0' and data['config']['mode']=='pixels' and count>=385
        assert meta.get('performanceEligible') and not meta.get('otherAir')
    else:
        label='machines';entry='LightMachineProbeMod';loader=read(store/'loader.json')
        log=(store/'machine-test.log').read_text('utf8');assert 'SUITE_PASS' in log and not re.search(r'^FAIL',log,re.M)
        count=len(re.findall(r'^PASS ',log,re.M));assert count>=173
    session=re.fullmatch(r'run_(\d{13})_\d+',loader.get('session',''))
    assert session and meta['startedMs']<=int(session[1])<=meta['endedMs']
    assert loader.get('boot') is not None and loader.get('boot_start') is not None
    assert not any(k.startswith('err_') for k in loader)
    for prefix in ['requested_','ok_']:assert {k[len(prefix):] for k in loader if k.startswith(prefix)}==BASE|{entry}
    log=(store/'LightAndDarkness.log').read_text('utf8')
    assert 'v0.5.0 loaded' in log and not any(k in log for k in ['FRAME_ERROR','ATTACH_FAILED','PREPARE_FAILED','RESTORE_FAILED'])
    appid=meta.get('applicationID',meta.get('appId'));runtime=MOD/'build/generated'/appid
    raw=read(folder/'hashes.json')
    if isinstance(raw,list):hashes={str(Path(p['Path']).relative_to(runtime)).replace('\\','/'):p['Hash'].lower() for p in raw}
    else:hashes={k.replace('\\','/'):v.lower() for k,v in raw.items()}
    assert hashes['mods/LightAndDarkness/release/LightAndDarknessMod.swf']==f['sha256']
    if label=='trail:perf':assert hashes['baseline.swf']==f['previousSha256'],'Performance baseline must be the actual previous release'
    skip={'application.xml','baseline.swf','reference.swf','trail-mode.txt','projectile-mode.txt','landmark-mode.txt','test-mode.txt','terminal-checks.txt','probe-config.xml','perf.json','mods/loader-manifest.txt'}
    for path,h in hashes.items():
        if path in skip or 'Probe' in Path(path).name or path=='mods/LightAndDarkness/release/LightAndDarknessMod.swf':continue
        assert (GAME/path).is_file() and sha(GAME/path)==h,('Changed test input',path)
    # Older machine runner fingerprints only SWFs. Read back every protected
    # config from its retained private runtime too; no formal input may differ.
    for path,h in f['protected'].items():
        if path in ['application.xml','mods/loader-manifest.txt']:continue
        assert sha(runtime/path)==h,('Private dependency differs',path)
    return {'label':label,'checks':count,'evidence':str(folder.relative_to(MOD)),'session':loader['session']}
def rollback(receipt,error):
    assert sha(TARGET)==receipt['sha256']
    backup=Path(receipt['backup']);assert sha(backup)==receipt['previousSha256']
    staged=backup.parent/('rollback-'+datetime.now().strftime('%H%M%S%f')+'.swf')
    shutil.copy2(backup,staged);os.replace(staged,TARGET)
    receipt.update(restartSmoke={'status':'FAILED_ROLLED_BACK','error':str(error)},rollbackAt=datetime.now().astimezone().isoformat())
    RECEIPT.write_text(json.dumps(receipt,ensure_ascii=False,indent=2)+'\n','utf8')
def main():
    p=argparse.ArgumentParser();p.add_argument('--evidence',type=Path,action='append');p.add_argument('--install',action='store_true');p.add_argument('--smoke',type=Path);args=p.parse_args()
    f=frozen()
    if args.smoke:
        receipt=read(RECEIPT)
        try:
            assert sha(TARGET)==f['sha256']==receipt['sha256']
            record=verify(args.smoke,f);assert record['label']=='trail:verify'
            receipt['restartSmoke']={'status':'PASS',**record,'finishedAt':datetime.now().astimezone().isoformat()}
            RECEIPT.write_text(json.dumps(receipt,ensure_ascii=False,indent=2)+'\n','utf8')
        except Exception as error:
            if sha(TARGET)==receipt['sha256']:rollback(receipt,error)
            raise
        print(json.dumps({'status':'INSTALLED_SMOKE_PASS','sha256':f['sha256']}));return
    assert args.evidence
    records=[verify(path,f) for path in args.evidence]
    needed={'trail:verify','trail:legacy','trail:perf','trail:cold','landmark:verify','landmark:regression','landmark:cold','pixels','machines'}
    assert {r['label'] for r in records}==needed,('Missing evidence',needed-{r['label'] for r in records})
    assert all(sum(r['label']==label for r in records)==(2 if label=='trail:perf' else 1) for label in needed),'Keep both isolated timing runs; no duplicate functional evidence'
    [r for r in records if r['label']=='trail:perf'][1]['label']='trail:perf-repeat'
    assert sha(TARGET)==f['previousSha256'],'Installed LAD changed concurrently'
    receipt={**f,'evidence':records}
    if not args.install:print(json.dumps({'status':'PRECHECK_PASS','sha256':f['sha256'],'modes':sorted(needed)}));return
    backup_dir=MOD/'build/backups'/('trails-'+datetime.now().strftime('%Y%m%d-%H%M%S-%f'));backup_dir.mkdir(parents=True,exist_ok=False)
    backup=backup_dir/'LightAndDarknessMod.v0.4.1.swf';staged=backup_dir/'LightAndDarknessMod.staged.swf'
    shutil.copy2(TARGET,backup);shutil.copy2(OUT/'LightAndDarknessMod.swf',staged)
    assert sha(backup)==f['previousSha256'] and sha(staged)==f['sha256'];frozen()
    assert sha(TARGET)==f['previousSha256'];os.replace(staged,TARGET);assert sha(TARGET)==f['sha256']
    receipt.update(installedAt=datetime.now().astimezone().isoformat(),backup=str(backup),restartSmoke='pending',rollback='Restore only this backup while installed LAD still matches this release; leave other modules, host, manifest and real saves unchanged.')
    RECEIPT.write_text(json.dumps(receipt,ensure_ascii=False,indent=2)+'\n','utf8')
    print(json.dumps({'status':'DEPLOYED','sha256':f['sha256'],'backup':str(backup)}))
if __name__=='__main__':main()
