"""Preflight and atomic single-file deployment of the verified landmark candidate."""
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
CANDIDATE=MOD/'build/out/landmarks-v041/LightAndDarknessMod.swf'
TARGET=MOD/'release/LightAndDarknessMod.swf'
NEW='94a2f0861b9757815f1554d5fbf3c216f403053d1ebcf4b546f9f7a2868a21bd'
OLD='9177513f1a927de82039cfe0b5444eccf6c14b61ba2b765a96a7c2686a9c75e5'
RECEIPT=MOD/'state/landmark-deployment-2026-10-19.json'
ENTRIES={'LightAndDarknessMod','LandmarkProbeMod','ModLoaderMod','ContinuousSceneMod','RealisticVisionMod','WallBlendMod'}

def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()

def verify(folder):
    folder=folder.resolve()
    assert folder.is_relative_to((MOD/'build/evidence').resolve())
    data=json.loads((folder/'storage/landmark.json').read_text('utf8'))
    assert (folder/'storage/landmark.done').read_text('utf8')=='PASS' and not data['error']
    assert data['version']=='0.4.1' and data['roomsLoad']==1
    meta=json.loads((folder/'process.json').read_text('utf8'))
    loader=data['loader'];session=re.fullmatch(r'run_(\d{13})_\d+',loader.get('session',''))
    assert session and meta['startedMs']<=int(session[1])<=meta['endedMs']
    assert loader.get('boot') is not None and loader.get('boot_start') is not None
    assert not any(k.startswith('err_') for k in loader)
    for prefix in ['requested_','ok_']:assert {k[len(prefix):] for k in loader if k.startswith(prefix)}==ENTRIES
    log=(folder/'storage/LightAndDarkness.log').read_text('utf8')
    assert 'v0.4.1 loaded' in log and 'heartbeat' in log
    assert not any(k in log for k in ['FRAME_ERROR','ATTACH_FAILED','PREPARE_FAILED','RESTORE_FAILED'])
    mode=data['mode']
    if mode=='verify':
        assert data['checks']>=124
        checks=(folder/'storage/checks.log').read_text('utf8')
        assert len(re.findall(r'^PASS ',checks,re.M))>=124
    else:
        checks=(folder/'storage/test.log').read_text('utf8')
        assert ' SUITE_PASS' in checks and ' FAIL ' not in checks
        assert len(re.findall(r'^\d+ PASS ',checks,re.M))>=(101 if mode=='regression' else 11)
    hashes={k.replace('\\','/'):v for k,v in json.loads((folder/'hashes.json').read_text('utf8')).items()}
    assert hashes['mods/LightAndDarkness/release/LightAndDarknessMod.swf']==NEW
    # Exact package identity: compare all game assets/dependencies/configuration,
    # excluding only the unique descriptor, selected manifest and test instrumentation.
    for rel,digest in hashes.items():
        normalized=rel.replace('\\','/')
        if normalized in ['application.xml','landmark-mode.txt','test-mode.txt','probe-config.xml','mods/loader-manifest.txt']:continue
        if 'LandmarkProbeMod.swf' in normalized:continue
        if normalized=='mods/LightAndDarkness/release/LightAndDarknessMod.swf':continue
        source=GAME/normalized
        assert source.is_file() and sha(source)==digest,('unverified changed input',normalized)
    return mode,hashes

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--evidence',action='append',type=Path)
    parser.add_argument('--install',action='store_true')
    parser.add_argument('--finish-smoke',type=Path);args=parser.parse_args()
    if args.finish_smoke:
        assert not args.install and not args.evidence
        mode,_=verify(args.finish_smoke)
        assert mode=='verify' and sha(TARGET)==NEW
        receipt=json.loads(RECEIPT.read_text('utf8'))
        assert receipt['sha256']==NEW
        assert all(sha(GAME/p)==h for p,h in receipt['hostAndDependencies'].items())
        assert all(sha(MOD/p)==h for p,h in receipt['sourceHashes'].items())
        receipt['restartSmoke']={'status':'PASS','mode':mode,'evidence':str(args.finish_smoke.resolve().relative_to(MOD)),
                                 'finishedAt':datetime.now().astimezone().isoformat(),'landmarkChecks':124,'sceneSamples':0}
        RECEIPT.write_text(json.dumps(receipt,ensure_ascii=False,indent=2)+'\n','utf8')
        print(json.dumps(dict(status='INSTALLED_SMOKE_PASS',sha256=NEW)));return
    assert args.evidence,'Evidence is required for preflight/install'
    assert sha(CANDIDATE)==NEW and sha(TARGET)==OLD,'Candidate or installed version changed'
    verified=dict(verify(p) for p in args.evidence)
    assert set(verified)=={'verify','regression','cold'},'Missing required verification mode'
    descriptor=ET.parse(GAME/'application.xml').getroot()
    assert descriptor.find('{*}initialWindow/{*}content').text=='pfe.swf'
    protected={str(p.relative_to(GAME)).replace('\\','/'):sha(p) for p in [GAME/'application.xml',GAME/'pfe.swf',GAME/'mods/loader-manifest.txt',MOD/'atmosphere.json']}
    for name in ['ModLoader','ContinuousScene','RealisticVision','WallBlend']:
        for p in (GAME/'mods'/name/'release').iterdir():
            if p.is_file() and p.suffix in ['.swf','.txt','.json','.xml']:protected[str(p.relative_to(GAME)).replace('\\','/')]=sha(p)
    export=MOD/'build/generated/landmarks-v041-decompiled/scripts'
    classes=sorted(str(p.relative_to(export)).replace('\\','/') for p in export.rglob('*.as'))
    assert len(classes)==19 and not any(p.startswith('fe/') or 'Probe' in p or 'Checks' in p or 'Test' in p for p in classes)
    source_hashes={str(p.relative_to(MOD)).replace('\\','/'):sha(p) for p in (MOD/'src').rglob('*.as')}
    receipt=dict(version='0.4.1',sha256=NEW,previousSha256=OLD,hostAndDependencies=protected,
                 evidence=[str(p.resolve().relative_to(MOD)) for p in args.evidence],sourceHashes=source_hashes,classes=classes)
    if not args.install:
        print(json.dumps(dict(status='PRECHECK_PASS',sha256=NEW,modes=list(verified),classes=len(classes))));return
    backup_dir=MOD/'build/backups'/('landmark-'+datetime.now().strftime('%Y%m%d-%H%M%S-%f'))
    backup_dir.mkdir(parents=True,exist_ok=False)
    backup=backup_dir/'LightAndDarknessMod.v0.4.0.swf';staged=backup_dir/'LightAndDarknessMod.staged.swf'
    shutil.copy2(TARGET,backup);shutil.copy2(CANDIDATE,staged)
    assert sha(backup)==OLD and sha(staged)==NEW and sha(TARGET)==OLD
    assert all(sha(GAME/p)==h for p,h in protected.items()),'Concurrent input change'
    os.replace(staged,TARGET)
    assert sha(TARGET)==NEW
    assert all(sha(GAME/p)==h for p,h in protected.items()),'Protected input changed during install'
    receipt.update(installedAt=datetime.now().astimezone().isoformat(),backup=str(backup),restartSmoke='pending',
                   rollback='Restore only this v0.4.0 backup if installed release still matches this candidate. Preserve all other files and real saves.')
    RECEIPT.write_text(json.dumps(receipt,ensure_ascii=False,indent=2)+'\n','utf8')
    print(json.dumps(dict(status='DEPLOYED',sha256=NEW,backup=str(backup)),ensure_ascii=False))

if __name__=='__main__':main()
