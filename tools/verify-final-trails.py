"""Run the frozen candidate sequentially; cold tests use only this run's private saves."""
from datetime import datetime
import json
from pathlib import Path
import runpy
import subprocess
import sys

MOD=Path(__file__).resolve().parents[1]
OUT=MOD/'build/out/trails-v050/LightAndDarknessMod.swf'
def main():
    runpy.run_path(str(MOD/'tools/deploy-trails.py'))['frozen']()
    records=[];output=MOD/'build/evidence'/('trails-final-'+datetime.now().strftime('%Y%m%d%H%M%S')+'.json')
    def run(script,mode,prefix,seed=None):
        before=set((MOD/'build/evidence').glob(prefix+'*'))
        command=[sys.executable,str(MOD/'tools'/script),'--candidate',str(OUT),'--mode',mode,'--mixed','--expected-version','0.5.0']
        if seed:command+=['--seed-storage',str(seed/'storage')]
        subprocess.run(command,cwd=MOD,check=True)
        added=set((MOD/'build/evidence').glob(prefix+'*'))-before
        assert len(added)==1
        folder=added.pop();records.append({'script':script,'mode':mode,'evidence':str(folder.relative_to(MOD))})
        output.write_text(json.dumps(records,ensure_ascii=False,indent=2)+'\n','utf8')
        return folder
    run('run-trail-tests.py','perf','remains-lad-projectile-trails-')
    run('run-trail-tests.py','verify','remains-lad-projectile-trails-')
    legacy=run('run-trail-tests.py','legacy','remains-lad-projectile-trails-')
    run('run-trail-tests.py','cold','remains-lad-projectile-trails-',legacy)
    regression=run('run-landmark-tests.py','regression','remains-lad-landmark-')
    run('run-landmark-tests.py','cold','remains-lad-landmark-',regression)
    print('FINAL_RUN_INDEX '+str(output),flush=True)
if __name__=='__main__':main()
