"""Run only the owned AIR test process on ModLoader's private Windows desktop."""
import json
import sys
import time
from pathlib import Path

game, runtime, evidence, storage, timeout = sys.argv[1:]
sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(game) / 'mods/ModLoader/tools'))
from air_test_process import HiddenProcess

evidence, storage = Path(evidence), Path(storage)
command = [str(Path(game) / 'adl64.exe'), '-runtime', str(Path(game) / 'runtimes/air/win64'), str(Path(runtime) / 'application.xml'), '-nodebug']
started = int(time.time() * 1000)
with (evidence / 'adl-stdout.txt').open('wb') as out, (evidence / 'adl-stderr.txt').open('wb') as err:
    process = HiddenProcess(command, cwd=runtime, stdout=out, stderr=err)
    try:
        while process.poll() is None and time.time() * 1000 - started < float(timeout) * 1000:
            log = storage / 'machine-test.log'
            if log.exists() and any(line.startswith(('SUITE_PASS', 'FAIL ')) for line in log.read_text('utf-8').splitlines()):
                break
            time.sleep(.25)
    finally:
        if process.poll() is None:
            process.kill()
            process.wait(15)
        meta = dict(startedMs=started, endedMs=int(time.time()*1000), pid=process.pid, desktop=process.desktop, appId=storage.parent.name)
        (evidence / 'process.json').write_text(json.dumps(meta, indent=2), 'utf-8')
        process.close()
