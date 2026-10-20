"""Archive selected raw evidence, excluding private test saves and game copies."""
import argparse
import hashlib
import html
import json
from pathlib import Path
import shutil

MOD = Path(__file__).resolve().parents[1]


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    p = argparse.ArgumentParser()
    p.add_argument('--out', required=True, type=Path)
    p.add_argument('--evidence', required=True, action='append', type=Path)
    args = p.parse_args()
    dest = MOD / 'tests/evidence/2026-10-20/background-v060'
    dest.mkdir(parents=True, exist_ok=True)
    (dest / '.gitattributes').write_text('** -text -whitespace\n**/stderr.txt -diff\n', 'utf8')
    (dest / '.gitignore').write_text('!*.log\n', 'utf8')
    shutil.copy2(args.out / 'freeze.json', dest / 'freeze.json')
    shutil.copy2(MOD / 'state/background-deployment-2026-10-20.json', dest / 'deployment.json')
    manifest = {}; gallery = []
    for source in args.evidence:
        source = source.resolve()
        assert source.is_relative_to((MOD / 'build/evidence').resolve())
        target = dest / source.name
        target.mkdir(exist_ok=True)
        for name in ['process.json', 'hashes.json', 'selection.json', 'sources.json', 'competition.json', 'guards.json', 'initial-guard.json', 'run-plan.json', 'compiler-stdout.txt', 'compiler-stderr.txt', 'stdout.txt', 'stderr.txt']:
            if (source / name).is_file():
                shutil.copy2(source / name, target / name)
        store = source / 'storage'
        for name in ['background-lighting.json', 'background-lighting.done', 'checks.log', 'heartbeat.log', 'landmark.json', 'landmark.done', 'test.log', 'trail.json', 'trail.done', 'LightAndDarkness.log', 'ContinuousScene.log', 'RVision.log', 'WallBlend.log']:
            if (store / name).is_file():
                shutil.copy2(store / name, target / name)
        if (store / 'background-lighting.json').is_file():
            data = json.loads((store / 'background-lighting.json').read_text('utf8'))
            for row in data['samples']:
                prefix = row['prefix']
                modes = ['isolated'] + (['actual'] if row['land'] in ['rbl', 'random_mane'] else [])
                for mode in modes:
                    names = [prefix + '-baseline051-' + mode + '.png', prefix + '-candidate-' + mode + '.png']
                    if not all((store / n).is_file() for n in names):
                        continue
                    for name in names:
                        shutil.copy2(store / name, target / name)
                    gallery.append('<h2>' + html.escape(data['mode'] + ' / ' + row['land'] + ' / ' + mode) + '</h2><div class="pair">' + ''.join('<figure><figcaption>' + label + '</figcaption><a href="' + html.escape(source.name + '/' + name) + '"><img loading="lazy" src="' + html.escape(source.name + '/' + name) + '"></a></figure>' for name, label in zip(names, ['0.5.1 基线', '0.6.0 候选'])) + '</div>')
        manifest[source.name] = {f.name: sha(f) for f in target.iterdir() if f.is_file()}
    page = '<!doctype html><meta charset="utf-8"><title>背景补光同场景对照</title><style>body{background:#252629;color:#eee;font:16px sans-serif;margin:24px}h1{font-size:24px}h2{font-size:18px;margin-top:32px}.pair{display:flex;gap:16px}figure{margin:0;flex:1;min-width:0}img{width:100%;display:block}figcaption{padding:8px 0}p{max-width:1000px;line-height:1.6}</style><h1>背景补光同场景对照</h1><p>左：正式0.5.1的环境与照度类；右：本次0.6.0。每对使用同一暂停场景、机位、灯状态和原图。actual保留视野组合；isolated临时关闭视野黑幕以判断照明。软件截图不代表前台GPU或FPS认证。点击图片查看原尺寸。</p>' + ''.join(gallery)
    (dest / 'gallery.html').write_text(page, 'utf8')
    (dest / 'index.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n', 'utf8')
    print(json.dumps({'archive': str(dest), 'runs': len(manifest), 'files': sum(len(v) for v in manifest.values())}))


if __name__ == '__main__':
    main()
