"""Measure matched rendered pixels; never equate light-field values with image brightness."""
from pathlib import Path
import argparse
import html
import json
import statistics
from PIL import Image

MOD = Path(__file__).resolve().parents[1]


def y709(rgb):
    # Encoded RGB luma proxy, deliberately not physical/linear luminance.
    return .2126 * rgb[0] + .7152 * rgb[1] + .0722 * rgb[2]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('evidence', type=Path)
    args = parser.parse_args()
    root = args.evidence.resolve()
    assert root.is_relative_to(MOD.resolve())
    store = root / 'storage'
    data = json.loads((store / 'audit.json').read_text(encoding='utf8'))
    rows = []
    choices = {'formal': '正式效果（关随身灯、隔离视野黑幕）', 'native': '恢复原生灯图（同样隔离黑幕）', 'mask-off': '保留灯具转换，仅隐藏乘法场', 'ambient125': '环境倍率 ×1.25（诊断对照）', 'lamps150': '场景灯倍率 ×1.5（诊断对照）', 'aperture-concept': '仅马哈顿漏接开口临时提亮（无周围散射）', 'actual': '组合默认效果（含随身灯与视野）', 'fixed-rv': '关随身灯，保留视野'}
    for sample in data['samples']:
        prefix = sample['prefix']
        imgs = {key: Image.open(store / f'{prefix}-{key}.png').convert('RGB') for key in choices if (store / f'{prefix}-{key}.png').exists()}
        if sample['land'] == 'surf':
            rois = {}
            for label, box in {'ground': (500, 730, 1300, 790), 'wall': (20, 390, 130, 690), 'sky': (400, 200, 1000, 500)}.items():
                a = list(imgs['formal'].crop(box).getdata())
                b = list(imgs['native'].crop(box).getdata())
                ratios = [x / y for pa, pb in zip(a, b) for x, y in zip(pa, pb) if y > 10]
                rois[label] = {'box': box, 'channelThreshold': 10, 'channelSamples': len(ratios), 'medianRGBRatio': statistics.median(ratios)}
            (root / 'surface-roi.json').write_text(json.dumps(rois, indent=2), encoding='utf8')
        width, height = imgs['native'].size
        valid = [p for p in sample['raster']['points'] if 15 <= p['x'] < width - 15 and 80 <= p['y'] < height - 75 and y709(imgs['native'].getpixel((p['x'], p['y']))) >= 12]
        groups = {'scene': valid, 'solid': [p for p in valid if p['solid']], 'opaque': [p for p in valid if p['opaque']], 'opening': [p for p in valid if p['opening']], 'missed': [p for p in valid if p['missed']]}
        result = {k: sample[k] for k in ('land', 'room', 'backwall', 'backform', 'transpFon', 'lamps', 'onLamps', 'windows', 'regions', 'profile')}
        result.update(prefix=prefix, groups={})
        for group, pts in groups.items():
            values = {}
            native = [y709(imgs['native'].getpixel((p['x'], p['y']))) for p in pts]
            for mode, img in imgs.items():
                yy = [y709(img.getpixel((p['x'], p['y']))) for p in pts]
                values[mode] = {'mean': statistics.mean(yy) if yy else None, 'median': statistics.median(yy) if yy else None, 'sumRelativeNative': sum(yy) / sum(native) if sum(native) else None, 'medianRelativeNative': statistics.median(a / b for a, b in zip(yy, native)) if pts else None, 'below25Fraction': sum(a < 25 for a in yy) / len(yy) if yy else None}
            result['groups'][group] = {'n': len(pts), 'fieldMedian': statistics.median(p['field'] for p in pts) if pts else None, 'images': values}
        rows.append(result)
    output = {'boundary': 'Matched 24-world-pixel grid projected into the screenshot. Excludes HUD bands and native RGB-luma<12. RGB encoded Rec709-weighted luma 0..255, not physical luminance. Same paused room for formal/native/mask-off/ambient/lamp variants. Actual and fixed-rv were captured before visibility isolation, so not used as strict same-state pixel oracles. New-game samples, not all templates or player save.', 'applicationID': data['applicationID'], 'rows': rows}
    (root / 'pixel-summary.json').write_text(json.dumps(output, ensure_ascii=False, indent=2), encoding='utf8')
    opts = ''.join(f'<option value="{r["prefix"]}">{html.escape(r["land"])} / {r["room"]}</option>' for r in rows)
    modes = ''.join(f'<option value="{key}">{label}</option>' for key, label in choices.items())
    page = '''<!doctype html><html lang="zh"><meta charset="utf-8"><title>光照调查 · 同房间对照</title><style>body{margin:24px;background:#171a1e;color:#e4e7eb;font:16px system-ui}select{padding:8px;margin:6px;max-width:100%}.grid{display:grid;grid-template-columns:1fr 1fr;gap:16px}img{width:100%;background:#000}p{max-width:1100px;line-height:1.7}a{color:#a8d5ff}</style><h1>光照调查 · 同房间对照</h1><p>调查用正式 0.4.1 的隔离副本。下面的倍率和开口提亮仅是测试进程中的诊断对照，没有部署。默认对照均关随身灯、临时隔离视野黑幕；“组合默认效果”保留视野。开口概念图只改变漏接孔本身，尚无周围散射，不是完成版。</p><label>场景<select id="scene">''' + opts + '''</select></label><div class="grid"><section><select id="left">''' + modes + '''</select><img id="a"></section><section><select id="right">''' + modes + '''</select><img id="b"></section></div><p>原始 PNG 未做后期亮度调整。统计以画面实际像素为准，照度场数值另列；后台软件绘图不等于前台 GPU 验证。</p><script>right.value='native';function show(){a.src='storage/'+scene.value+'-'+left.value+'.png';b.src='storage/'+scene.value+'-'+right.value+'.png'}[scene,left,right].forEach(x=>x.onchange=show);show()</script></html>'''
    availability = {r['prefix']: [key for key in choices if (store / (r['prefix'] + '-' + key + '.png')).exists()] for r in rows}
    start = page.index('<script>')
    page = page[:start] + '<script>const available=' + json.dumps(availability) + ''';const scene=document.getElementById('scene'),left=document.getElementById('left'),right=document.getElementById('right'),a=document.getElementById('a'),b=document.getElementById('b');right.value='native';function show(){for(const box of [left,right]){for(const o of box.options)o.disabled=!available[scene.value].includes(o.value);if(!available[scene.value].includes(box.value))box.value='formal'}a.src='storage/'+scene.value+'-'+left.value+'.png';b.src='storage/'+scene.value+'-'+right.value+'.png'}[scene,left,right].forEach(x=>x.onchange=show);show()</script></html>'''
    (root / 'gallery.html').write_text(page, encoding='utf8')
    for row in rows:
        g = row['groups']['scene']['images']
        solid = row['groups']['solid']
        print(row['land'], 'native', round(g['native']['mean'], 1), 'formal/native', round(g['formal']['sumRelativeNative'], 3), 'maskoff/native', round(g['mask-off']['sumRelativeNative'], 3), 'ambient125/formal', round(g['ambient125']['mean'] / g['formal']['mean'], 3), 'lamps150/formal', round(g['lamps150']['mean'] / g['formal']['mean'], 3), 'solid-field', solid['fieldMedian'])


if __name__ == '__main__':
    main()
