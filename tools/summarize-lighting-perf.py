import json, sys, statistics
from pathlib import Path
path=Path(sys.argv[1]);data=json.loads(path.read_text('utf-8-sig'))
rows=data if isinstance(data,list) else data['rows']
def stats(a):
    b=sorted(a)
    return {'n':len(b),'mean':round(statistics.mean(b),2),'p50':statistics.median(b),'p95':b[min(len(b)-1,int(len(b)*.95))],'max':max(b),'>50':sum(x>50 for x in b)} if b else {}
for row in rows:
    if 'frames' in row:print(json.dumps({'scene':row['scene'],'on':row['on'],'frames':stats(row['frames']),'logic':stats(row.get('logic',[])),'field':stats(row['field']),'empty':row['empty'],'steps':row.get('steps'),'renders':row.get('renders')},ensure_ascii=False))
    else:print(json.dumps(row,ensure_ascii=False))
