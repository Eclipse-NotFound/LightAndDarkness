"""Matched lighting measurements in a private AIR desktop and private storage."""
from pathlib import Path
from datetime import datetime
import argparse, ctypes, hashlib, json, os, re, shutil, subprocess, sys, time
from ctypes import wintypes as W
MOD=Path(__file__).resolve().parents[1]; GAME=MOD.parents[1]
sys.dont_write_bytecode=True
sys.path.insert(0,str(GAME/'mods/ModLoader/tools'))
from air_test_process import HiddenProcess
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest().upper()
def air_pids():
    # Read-only inventory, never terminate a process found here. Only HiddenProcess
    # owns a killable handle. Reject contaminated timing instead of ranking it.
    k=ctypes.WinDLL('kernel32',use_last_error=True);p=ctypes.WinDLL('psapi',use_last_error=True)
    k.OpenProcess.argtypes=[W.DWORD,W.BOOL,W.DWORD];k.OpenProcess.restype=W.HANDLE
    k.QueryFullProcessImageNameW.argtypes=[W.HANDLE,W.DWORD,W.LPWSTR,ctypes.POINTER(W.DWORD)]
    k.CloseHandle.argtypes=[W.HANDLE]
    ids=(W.DWORD*16384)();size=W.DWORD()
    if not p.EnumProcesses(ids,ctypes.sizeof(ids),ctypes.byref(size)):raise ctypes.WinError()
    result=[]
    for pid in ids[:size.value//4]:
        h=k.OpenProcess(0x1000,False,pid)
        if not h:continue
        try:
            buf=ctypes.create_unicode_buffer(32768);n=W.DWORD(len(buf))
            if k.QueryFullProcessImageNameW(h,0,buf,ctypes.byref(n)) and Path(buf.value).name.lower()=='adl64.exe':result.append(pid)
        finally:k.CloseHandle(h)
    return result
def responsive_owned(process):
    class State(ctypes.Structure):_fields_=[('version',W.DWORD),('control',W.DWORD),('state',W.DWORD)]
    k=process.k
    k.GetProcessInformation.argtypes=[W.HANDLE,ctypes.c_int,ctypes.c_void_p,W.DWORD]
    k.SetProcessInformation.argtypes=[W.HANDLE,ctypes.c_int,ctypes.c_void_p,W.DWORD]
    before=State(1,0,0)
    if not k.GetProcessInformation(process._process,4,ctypes.byref(before),ctypes.sizeof(before)):raise ctypes.WinError()
    after=State(1,before.control|1,before.state&~1)
    if not k.SetProcessInformation(process._process,4,ctypes.byref(after),ctypes.sizeof(after)):raise ctypes.WinError()
    actual=State(1,0,0)
    if not k.GetProcessInformation(process._process,4,ctypes.byref(actual),ctypes.sizeof(actual)):raise ctypes.WinError()
    assert actual.control&1 and not actual.state&1
    return {'before':[before.control,before.state],'applied':[actual.control,actual.state]}

def owned_cpu_ms(process):
    times=[W.FILETIME() for _ in range(4)]
    process.k.GetProcessTimes.argtypes=[W.HANDLE]+[ctypes.POINTER(W.FILETIME)]*4
    if not process.k.GetProcessTimes(process._process,*[ctypes.byref(t) for t in times]):raise ctypes.WinError()
    return sum((t.dwHighDateTime<<32)|t.dwLowDateTime for t in times[2:])/10000

def available_memory():
    class Memory(ctypes.Structure):
        _fields_=[('length',W.DWORD),('load',W.DWORD)]+[(name,ctypes.c_ulonglong) for name in ['totalPhysical','availablePhysical','totalCommit','availableCommit','totalVirtual','availableVirtual','extendedVirtual']]
    state=Memory();state.length=ctypes.sizeof(state)
    if not ctypes.WinDLL('kernel32',use_last_error=True).GlobalMemoryStatusEx(ctypes.byref(state)):raise ctypes.WinError()
    return {'physicalBytes':state.availablePhysical,'commitBytes':state.availableCommit}
def main():
    p=argparse.ArgumentParser();p.add_argument('--candidate',required=True);p.add_argument('--mode',choices=['bench','pixels','frames'],default='bench');p.add_argument('--full',action='store_true');p.add_argument('--samples',type=int,default=90);p.add_argument('--variant',choices=['module','bitmap','fixtures','proxy','suite','staticlights'],default='module');p.add_argument('--room-only',dest='roomOnly',action='store_true');p.add_argument('--width',type=int,default=1440);p.add_argument('--height',type=int,default=900);args=p.parse_args()
    if not (640<=args.width<=3840 and 480<=args.height<=2160):p.error('Invalid test window dimensions')
    others=air_pids()
    if others:raise RuntimeError('Other AIR exists; wait for the agreed window: '+str(others))
    if available_memory()['commitBytes']<2*1024**3:raise RuntimeError('Insufficient commit headroom for one isolated test')
    appid='remains-lad-perf-'+datetime.now().strftime('%Y%m%d%H%M%S%f')
    root=MOD/'build/generated'/appid;out=MOD/'build/evidence'/appid
    root.mkdir(parents=True);out.mkdir(parents=True)
    inventory=json.loads(subprocess.check_output([str(GAME/'mods/ModLoader/RemainsModLauncher.exe'),'--list','--json','--no-ui']).decode('utf-8-sig'))
    (out/'inventory.json').write_text(json.dumps(inventory,indent=2),'utf-8')
    baseline=MOD/'build/out/perf-reference-v041.swf'
    if not baseline.exists():
        assert sha(MOD/'release/LightAndDarknessMod.swf')=='94A2F0861B9757815F1554D5FBF3C216F403053D1EBCF4B546F9F7A2868A21BD'
        shutil.copy2(MOD/'release/LightAndDarknessMod.swf',baseline)
    shutil.copy2(baseline,root/'reference.swf')
    tool=GAME/'mods/Sandevistan/build/tools';from xml.sax.saxutils import escape
    config=root/'probe-config.xml'
    config.write_text('<flex-config xmlns="http://www.adobe.com/2006/flex-config"><target-player>32.0</target-player><compiler><source-path><path-element>'+escape(str(MOD/'tests'))+'</path-element></source-path><external-library-path><path-element>'+escape(str(tool/'airsdk/frameworks/libs/air/airglobal.swc'))+'</path-element></external-library-path><debug>false</debug><optimize>true</optimize></compiler></flex-config>','utf-8')
    probe=root/'LightingPerfProbeMod.swf'
    subprocess.run(['D:/Program Files/Adobe Animate 2024/jre/bin/java.exe','-Xmx768m','-jar',str(tool/'flexsdk/lib/mxmlc.jar'),'+flexlib='+str(tool/'flexsdk/frameworks'),'-load-config='+str(config),'-swf-version=32','-use-network=false','-static-link-runtime-shared-libraries=true','-output='+str(probe),str(MOD/'tests/LightingPerfProbeMod.as')],check=True)
    for name in ['pfe.swf','texture.swf','texture1.swf','sprite.swf','sprite1.swf','sound.swf','sound_unit.swf','sound_weapon.swf','lang.xml','rooms.xml']+[f.name for f in GAME.glob('text_*.xml')]:shutil.copy2(GAME/name,root/name)
    shutil.copytree(GAME/'Rooms',root/'Rooms')
    wanted=inventory['selected'] if args.full else ['LightAndDarknessMod','ModLoaderMod','ContinuousSceneMod','RealisticVisionMod','WallBlendMod']
    for m in inventory['mods']:
        if m['entry'] not in wanted:continue
        src=GAME/'mods'/m['directory'];dst=root/'mods'/m['directory']
        for folder in ['release','config']:
            if (src/folder).is_dir():shutil.copytree(src/folder,dst/folder)
    shutil.copy2(args.candidate,root/'mods/LightAndDarkness/release/LightAndDarknessMod.swf')
    shutil.copy2(MOD/'atmosphere.json',root/'mods/LightAndDarkness/atmosphere.json')
    host=root/'mods/ModLoader';host.mkdir(exist_ok=True,parents=True)
    for name in ['supported-mods.txt','RemainsModLauncher.exe','RemainsModScanner.exe']:shutil.copy2(GAME/'mods/ModLoader'/name,host/name)
    shutil.copy2(probe,root/'mods/LightAndDarkness/release'/probe.name)
    entries=wanted+['LightingPerfProbeMod']
    (root/'perf.json').write_text(json.dumps(vars(args)),'utf-8')
    desc=root/'application.xml'
    desc.write_text(f'<?xml version="1.0"?><application xmlns="http://ns.adobe.com/air/application/30.0"><id>{appid}</id><versionNumber>1.0</versionNumber><filename>LightingPerformance</filename><initialWindow><content>pfe.swf</content><visible>false</visible><width>{args.width}</width><height>{args.height}</height><renderMode>direct</renderMode></initialWindow><supportedProfiles>extendedDesktop</supportedProfiles></application>','utf-8')
    selected=subprocess.run([str(GAME/'mods/ModLoader/RemainsModLauncher.exe'),'--root',str(root),'--only',','.join(entries),'--no-ui','--report',str(out/'selection.json')],capture_output=True)
    if selected.returncode:raise RuntimeError(selected.stdout.decode('utf-8',errors='replace')+selected.stderr.decode('utf-8',errors='replace'))
    frozen={str(f.relative_to(root)):sha(f) for f in root.rglob('*') if f.is_file()}
    (out/'hashes.json').write_text(json.dumps(frozen,indent=2),'utf-8')
    storage=Path(os.environ['APPDATA'])/appid/'Local Store';storage.mkdir(parents=True)
    (storage/'ContinuousScene.preferences.json').write_text(json.dumps({'nativeEnabled':True}),'utf-8')
    process=None;started=int(time.time()*1000);meta={};contaminated=False;low_memory=False
    try:
        with (out/'stdout.txt').open('wb') as stdout,(out/'stderr.txt').open('wb') as stderr:
            process=HiddenProcess([str(GAME/'adl64.exe'),'-runtime',str(GAME/'runtimes/air/win64'),str(desc),'-nodebug'],cwd=root,stdout=stdout,stderr=stderr)
            meta={'applicationID':appid,'pid':process.pid,'desktop':process.desktop,'startedMs':started,'qos':responsive_owned(process),'otherAir':[],'cpuSamples':[],'memoryAtStart':available_memory()}
            (out/'process.json').write_text(json.dumps(meta,indent=2),'utf-8');print('EVIDENCE '+str(out),flush=True)
            deadline=time.monotonic()+440;next_inventory=time.monotonic()+1
            while process.poll() is None and time.monotonic()<deadline:
                # Let native exit complete; do not race its file close/destructors.
                if time.monotonic()>=next_inventory:
                    memory=available_memory()
                    meta['cpuSamples'].append({'atMs':int(time.time()*1000),'cpuMs':owned_cpu_ms(process),'memory':memory})
                    if memory['commitBytes']<512*1024**2:low_memory=True;break
                    others=[pid for pid in air_pids() if pid!=process.pid];next_inventory=time.monotonic()+1
                    if others:
                        meta['otherAir'].append({'atMs':int(time.time()*1000),'pids':others});contaminated=True;break
                time.sleep(.3)
    finally:
        if process:
            if process.poll() is None:
                process.kill()
                for attempt in range(6):
                    try:process.wait(10);break
                    except subprocess.TimeoutExpired:pass
            if process.poll() is None:raise RuntimeError('Owned process did not exit; PID '+str(process.pid))
            process.close()
        if storage.exists():shutil.copytree(storage,out/'storage')
        meta['endedMs']=int(time.time()*1000);meta['performanceEligible']=not contaminated and not low_memory;meta['lowMemory']=low_memory
        meta['memoryAtEnd']=available_memory()
        (out/'process.json').write_text(json.dumps(meta,indent=2),'utf-8')
    assert not contaminated,'Another AIR started during sampling; timing rejected, other process untouched'
    assert not low_memory,'Commit headroom below 512 MiB; only owned test stopped, timing rejected'
    result=json.loads((out/'storage/perf-result.json').read_text('utf-8'))
    assert result['ok'],result.get('error')
    loader=result['loader'];session=re.fullmatch(r'run_(\d{13})_\d+',loader.get('session',''))
    assert session and started<=int(session[1])<=int(time.time()*1000)
    assert {k[10:] for k in loader if k.startswith('requested_')}==set(entries)
    assert {k[3:] for k in loader if k.startswith('ok_')}==set(entries)
    assert not any(k.startswith('err_') for k in loader)
    assert all(sha(root/n)==h for n,h in frozen.items())
    print(json.dumps({'PASS':True,'checks':result['checks'],'rows':len(result['rows']),'evidence':str(out)},ensure_ascii=False))
if __name__=='__main__':main()
