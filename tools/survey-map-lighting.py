"""Read-only native map census. Writes evidence only inside this mod.

Counts templates, not playtime or procedurally generated room frequency.
Circle coverage is deliberately optimistic: every fixture lit, no walls, no falloff.
It is an estimate using definition bounds, not the runtime lighting measurement.
"""
import collections
import csv
import hashlib
import json
from pathlib import Path
import re
import sys
import xml.etree.ElementTree as ET

MOD = Path(__file__).resolve().parents[1]
GAME = MOD.parents[1]
SRC = GAME / "game-reference/decompiled/1.02/src102/scripts/fe"
OUT = MOD / "knowledge/evidence/map-lighting-2026-10-19"
RADIUS = dict(light1=300, stlight1=310, light2=370, light3=340,
              stlight3=350, light4=390, stlight4=390, light5=190,
              light6=320, light7=360)
FRAMES = dict(light1=2, stlight1=3, light2=3, light3=2, stlight3=3,
              light4=2, stlight4=3, light5=2, light6=2, light7=2)
GLOWS = set("lwhite lred lorange lyellow lacid lgreen lcyan lblue lpurple lpink bar exit_light".split())
inputs = {}


def read(path):
    data = path.read_bytes()
    inputs[str(path.relative_to(GAME)).replace('\\', '/')] = hashlib.sha256(data).hexdigest()
    return data.decode('utf-8-sig')


def inline(path, root):
    text = read(path)
    return ET.fromstring(re.search(fr'<{root}>.*?</{root}>', text, re.S)[0])


def canonical(node):
    return (node.tag, tuple(sorted(node.attrib.items())), (node.text or '').strip(),
            tuple(canonical(c) for c in node))


def options(node):
    child = node.find('options')
    return {} if child is None else dict(child.attrib)


def main():
    use_reference = '--reference' in sys.argv
    game = inline(SRC / 'GameData.as', 'game')
    all_data = inline(SRC / 'AllData.as', 'all')
    lands = list(game.findall('land'))
    backdefs = {n.get('id'): n.attrib for n in all_data.findall('back')}
    forms = {n.get('id'): n.attrib for n in all_data.findall('mat')}
    embedded = {}
    for path in sorted((SRC / 'rooms').glob('*.as')):
        text = read(path)
        for var, xml in re.findall(r'(?:public|internal) var (\w+):XML\s*=\s*(<all>.*?</all>)\s*;', text, re.S):
            embedded[(path.stem, var)] = ET.fromstring(xml)
    room_source = (SRC / 'rooms/Rooms.as').read_text(encoding='utf8')
    instances = dict(re.findall(r'this\.(\w+) = new (\w+)\(', room_source))
    mapping = {}
    for name, expr in re.findall(r'this.rooms\["(\w+)"\] = this\.([\w.]+);', room_source):
        parts = expr.split('.')
        mapping[name] = embedded[(instances[parts[0]], parts[1])] if len(parts) == 2 else embedded[('Rooms', parts[0])]

    rows, file_rows, fixture_rows = [], [], []
    for file in sorted({land.get('file') for land in lands}):
        path = GAME / 'Rooms' / (file + '.xml')
        disk = ET.fromstring(read(path))
        contexts = [n for n in lands if n.get('file') == file]
        baseline = mapping[file]
        same = canonical(disk) == canonical(baseline)
        changed = [i for i, (a, b) in enumerate(zip(disk.findall('room'), baseline.findall('room')))
                   if canonical(a) != canonical(b)]
        light_signature = lambda r: (tuple(sorted(tuple(sorted(b.attrib.items())) for b in r.findall('back') if b.get('id') in RADIUS)), tuple(sorted(options(r).items())))
        installed_signatures = collections.Counter(light_signature(r) for r in disk.findall('room'))
        reference_signatures = collections.Counter(light_signature(r) for r in baseline.findall('room'))
        file_rows.append(dict(file=file, templates=len(disk.findall('room')),
                              embedded_templates=len(baseline.findall('room')),
                              same_as_reference=same, changed_room_indices=changed,
                              identical_lighting_option_signatures=sum((installed_signatures & reference_signatures).values()),
                              land_ids=[n.get('id') for n in contexts]))
        for index, room in enumerate((baseline if use_reference else disk).findall('room')):
            opt = options(room)
            backs = list(room.findall('back'))
            fixtures = [b for b in backs if b.get('id') in RADIUS]
            counts = collections.Counter(b.get('id') for b in backs)
            tile_rows = [(a.text or '').split('.') for a in room.findall('a')]
            width = max(map(len, tile_rows), default=0)
            height = len(tile_rows)
            open_cells = []
            for y, cells in enumerate(tile_rows):
                for x, cell in enumerate(cells):
                    # Tile.inForm retains the last nonzero phis; ramps remain physical.
                    physical = any(float(forms.get(c, {}).get('phis', 0)) != 0 for c in cell)
                    if not physical:
                        open_cells.append((x*40+20, y*40+20))
            circles = []
            expected = []
            for context in contexts:
                effective = options(context) | opt
                on, off, random_count, expected_on = 0, 0, 0, 0.0
                power = int(opt.get('lon', 0))
                # Home stable and attack generation set lightOn=1 explicitly.
                if context.get('id') in ('stable_pi', 'stable_pi_atk'):
                    power = 1
                for n, b in enumerate(fixtures):
                    kind = b.get('id')
                    d = backdefs[kind]
                    frame = d.get('fr')
                    if frame is None:
                        frame = d.get('lon') if power > 0 else d.get('loff') if power < 0 else None
                    if 'fr' in b.attrib:
                        frame = b.get('fr')
                    if float(b.get('lon', 1)) > 1 and 'lon' in d:
                        frame = d['lon']
                    if float(b.get('lon', 1)) < 1 and 'loff' in d:
                        frame = d['loff']
                    p = 0 if power == -1 else (1/FRAMES[kind] if frame is None else int(frame) == int(d.get('lon', 1)))
                    expected_on += p
                    if p == 0: off += 1
                    elif p == 1: on += 1
                    else: random_count += 1
                    if context is contexts[0]:
                        fixture_rows.append(dict(file=file, room_index=index, name=room.get('name',''),
                                                 type=kind, x=b.get('x'), y=b.get('y'),
                                                 attributes=dict(b.attrib), initial_frame=frame,
                                                 expected_on_probability=p))
                expected.append(dict(land=context.get('id'), backwall=effective.get('backwall',''),
                                     color=effective.get('color',''), darkness=opt.get('dark', options(context).get('darkness','0')),
                                     visibility=effective.get('vis','1'), land_type=context.get('tip',''),
                                     lightOn=power, on=on, off=off, random=random_count, expected_on=round(expected_on,3)))
            for b in fixtures:
                d = backdefs[b.get('id')]
                circles.append((float(b.get('x','0'))*40 + float(d.get('x2',1))*20,
                                float(b.get('y','0'))*40 + float(d.get('y2',1))*20, RADIUS[b.get('id')]))
            covered = sum(any((x-lx)**2+(y-ly)**2 < radius**2 for lx,ly,radius in circles) for x,y in open_cells)
            rows.append(dict(file=file,index=index,name=room.get('name',''),x=room.get('x'),y=room.get('y'),
                             width=width,height=height,lamps=len(fixtures),lamp_types=dict(collections.Counter(b.get('id') for b in fixtures)),
                             sky_flag='sky' in opt,base_flag='base' in opt,noblack='noblack' in opt,
                             options=opt,contexts=expected,other_glows={k:v for k,v in counts.items() if k in GLOWS},
                             windows={k:v for k,v in counts.items() if 'window' in k},
                             shadow_count=counts['shadow'],object_reveal_flags=sum('light' in b.attrib for b in room.findall('obj')),
                             raw_open_cells=len(open_cells),ideal_circle_covered_cells=covered,
                             ideal_circle_coverage=round(covered/len(open_cells),4) if open_cells else None))

    summary = dict(land_definitions=len(lands),files=len(file_rows),templates=len(rows),
                   lamp_instances=sum(r['lamps'] for r in rows),
                   zero_lamp_templates=sum(r['lamps']==0 for r in rows),
                   one_or_two_lamp_templates=sum(1 <= r['lamps'] <= 2 for r in rows),
                   sky_flag_templates=sum(r['sky_flag'] for r in rows),
                   sky_backwall_templates=sum(any(c['backwall']=='sky' for c in r['contexts']) for r in rows),
                   sky_backwall_without_sky_flag=sum(not r['sky_flag'] and any(c['backwall']=='sky' for c in r['contexts']) for r in rows),
                   glow_instances=sum(sum(r['other_glows'].values()) for r in rows),
                   glow_templates=sum(bool(r['other_glows']) for r in rows),
                   window_instances=sum(sum(r['windows'].values()) for r in rows),
                   window_templates=sum(bool(r['windows']) for r in rows),
                   ideal_circle_coverage=sum(r['ideal_circle_covered_cells'] for r in rows)/sum(r['raw_open_cells'] for r in rows))
    groups = []
    for f in file_rows:
        group = [r for r in rows if r['file']==f['file']]
        groups.append(dict(file=f['file'], rooms=len(group), zero=sum(r['lamps']==0 for r in group),
                           lamps=sum(r['lamps'] for r in group),
                           expected_on=round(sum(r['contexts'][0]['expected_on'] for r in group),2),
                           sky_background=sum(any(c['backwall']=='sky' for c in r['contexts']) for r in group),
                           glows=sum(sum(r['other_glows'].values()) for r in group),
                           windows=sum(sum(r['windows'].values()) for r in group),
                           circle_coverage=round(sum(r['ideal_circle_covered_cells'] for r in group)/sum(r['raw_open_cells'] for r in group),4)))
    OUT.mkdir(parents=True,exist_ok=True)
    data = dict(source='reference-1.02-embedded' if use_reference else 'installed-external-xml',
                boundary='Native 1.02 GameData registered files only. No spawn weighting, runtime geometry or pixel claim.',
                summary=summary, groups=groups, files=file_rows, rooms=rows, fixtures=fixture_rows, inputs=inputs)
    prefix = 'reference-' if use_reference else ''
    (OUT/(prefix+'census.json')).write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
    with (OUT/(prefix+'by-region.csv')).open('w',encoding='utf-8-sig',newline='') as stream:
        writer=csv.DictWriter(stream,fieldnames=list(groups[0]));writer.writeheader();writer.writerows(groups)
    print(json.dumps(summary,ensure_ascii=False,indent=2))
    for group in groups: print(json.dumps(group,ensure_ascii=False))
    print('External/reference differences:',[(f['file'],len(f['changed_room_indices'])) for f in file_rows if not f['same_as_reference']])


if __name__ == '__main__':
    main()
