"""Archive selected raw evidence and display original captures without modifying their pixels."""
import hashlib
import html
import json
from pathlib import Path
import shutil

MOD = Path(__file__).resolve().parents[1]
OUT = MOD / 'build/out/brightness-v070-host3'
DEST = MOD / 'tests/evidence/2026-10-21/brightness-v070'


def digest(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()


def main():
    receipt = json.loads((MOD / 'state/brightness-deployment-2026-10-21.json').read_text('utf8'))
    assert receipt['restartSmoke']['status'] == 'PASS'
    entries = json.loads((OUT / 'suite.json').read_text('utf8'))
    final = {Path(x['path']).resolve() for x in entries}
    final.add((MOD / receipt['restartSmoke']['evidence']).resolve())
    runs = final | set((MOD / 'build/evidence').glob('remains-lad-brightness-20261021*'))
    assert not DEST.exists(), 'Archive is immutable; choose a new destination instead of overwriting'
    DEST.mkdir(parents=True)
    (DEST / '.gitattributes').write_text('* -text\n', 'utf8')
    manifest = []

    def copy(source, relative):
        target = DEST / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        before = digest(source)
        shutil.copy2(source, target)
        assert digest(source) == digest(target) == before
        manifest.append({'path': relative.as_posix(), 'sha256': before, 'source': str(source)})

    roi_run = 'remains-lad-brightness-20261021160457383959'
    for run in sorted(runs):
        assert run.resolve().is_relative_to((MOD / 'build/evidence').resolve())
        for source in run.rglob('*'):
            if not source.is_file():
                continue
            image = source.suffix.lower() == '.png'
            roi = run.name == roi_run and source.name in ['sample-3-candidate-isolated.png', 'sample-3-baseline060-isolated.png', 'sample-3-native-isolated.png']
            if image and run.resolve() not in final and not roi:
                continue
            if source.suffix.lower() in ['.json', '.txt', '.log', '.done', '.stdout', '.stderr'] or image:
                copy(source, Path(run.name) / source.relative_to(run))
    for source in [OUT / 'freeze.json', OUT / 'suite.json', OUT / 'suite-bookkeeping.json', MOD / 'state/brightness-deployment-2026-10-21.json']:
        # Bookkeeping belongs to the preceding identical-byte group output.
        if not source.exists() and source.name == 'suite-bookkeeping.json':
            source = MOD / 'build/out/brightness-v070-host3/suite-bookkeeping.json'
        if source.exists():
            copy(source, Path(source.name))

    body = ['<!doctype html><meta charset="utf-8"><title>光与暗0.7画面对照</title><style>body{margin:24px;background:#202326;color:#eee;font:16px sans-serif}h1{font-size:26px}h2{font-size:20px;margin-top:36px}.row{display:flex;gap:12px}figure{margin:0;min-width:0;flex:1}img{display:block;width:100%}p{max-width:1100px;line-height:1.6}figcaption{padding:10px 0}</style>',
            '<h1>光与暗0.7：室外原图亮度与地区调节</h1><p>同暂停场景、相机、灯源。左为0.6环境/光场；中为0.7；右为隐藏LAD光场的原生画面。以下关闭视野黑幕以单独看照明；并非卸载所有模组后的整版游戏对照。图片均为未修改的原始软件截图，可点击查看全尺寸。</p>']
    for row in entries:
        if row['label'] not in ['brightness:verify', 'brightness:large']:
            continue
        run = Path(row['path'])
        data = json.loads((run / 'storage/brightness.json').read_text('utf8'))
        for sample in data['samples']:
            body.append('<h2>' + html.escape(row['label'] + ' / ' + sample['land'] + ' / ' + str(sample['regions']) + '区') + '</h2><div class="row">')
            for suffix, label in [('baseline060-isolated', '0.6环境光'), ('candidate-isolated', '0.7新亮度'), ('native-isolated', '原生画面参照')]:
                path = (Path(run.name) / 'storage' / (sample['prefix'] + '-' + suffix + '.png')).as_posix()
                body.append(f'<figure><figcaption>{label}</figcaption><a href="{path}"><img loading="lazy" src="{path}"></a></figure>')
            body.append('</div>')
    settings = Path(entries[0]['path']).name + '/storage/regional-settings.png'
    body.append(f'<h2>地区亮度设置</h2><p>七项同页显示。截图正在测试把室外滑块拖到75%；正式默认为100%，测试完成后已恢复默认。</p><img style="max-width:1200px" src="{settings}">')
    (DEST / 'gallery.html').write_text('\n'.join(body), 'utf8')
    (DEST / 'manifest.json').write_text(json.dumps({'files': manifest, 'runs': len(runs), 'note': 'Final six groups and installed smoke include all captures. Other attempts retain text evidence; the first successful Manehattan RGB comparison keeps its three source captures. Full working data remains in build/evidence.'}, ensure_ascii=False, indent=2) + '\n', 'utf8')
    print(json.dumps({'archive': str(DEST), 'runs': len(runs), 'files': len(manifest)}, ensure_ascii=False))


if __name__ == '__main__':
    main()
