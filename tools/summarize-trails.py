"""Summarize the isolated ABBA benchmark without claiming whole-game FPS."""
import argparse
import json
from pathlib import Path
from statistics import mean,median

def main():
    p=argparse.ArgumentParser();p.add_argument('evidence',type=Path);args=p.parse_args()
    folder=args.evidence
    data=json.loads((folder/'storage/trail.json').read_text('utf8'))
    gate=json.loads((folder/'competition.json').read_text('utf8'))
    assert data['mode']=='perf' and gate=={'checked':True,'competingPids':[]}
    assert (folder/'storage/trail.done').read_text('utf8')=='PASS'
    table=[]
    for kind in dict.fromkeys(row['kind'] for row in data['samples']):
        rows=[r for r in data['samples'] if r['kind']==kind]
        assert [r['candidate'] for r in rows]==[False,True,True,False]
        result={'workload':kind}
        for candidate,name in [(False,'old'),(True,'new')]:
            group=[r for r in rows if r['candidate']==candidate]
            raw=[t for r in group for t in r['combined']['raw']]
            result[name]={'samples':len(raw),'meanMs':mean(raw),'medianMs':median(raw),
                'maxMs':max(raw),'rebuildsPer100Calls':[r['rebuilds'] for r in group],
                'maxLights':max(r['maxLights'] for r in group),'maxVisits':max(r['maxVisits'] for r in group)}
        result['reductionPercent']=100*(1-result['new']['meanMs']/result['old']['meanMs'])
        table.append(result)
    out={'scope':'Production collector + light-field rendering, controlled input, not whole-game FPS','version':data['version'],'results':table}
    (folder/'summary.json').write_text(json.dumps(out,ensure_ascii=False,indent=2)+'\n','utf8')
    print(json.dumps(out,ensure_ascii=False))
if __name__=='__main__':main()
