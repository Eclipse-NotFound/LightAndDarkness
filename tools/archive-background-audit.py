"""Preserve investigation evidence without test saves or full game copies."""
from pathlib import Path
from datetime import datetime
import gzip
import hashlib
import json
import shutil

MOD = Path(__file__).resolve().parents[1]
OUT = MOD / 'knowledge/evidence/background-audit-2026-10-20'
RUNS = {'normal': 'remains-lad-background-20261020001621620029', 'large': 'remains-lad-background-20261020002208067968'}


def main():
    manifest = {}
    for label, run in RUNS.items():
        src = MOD / 'build/evidence' / run
        dest = OUT / label
        dest.mkdir(parents=True, exist_ok=True)
        assert (src / 'storage/audit.done').read_text(encoding='utf8') == 'PASS'
        for name in ['hashes.json', 'selection.json', 'sources.json', 'process.json', 'pixel-summary.json', 'stderr.txt']:
            shutil.copy2(src / name, dest / name)
        if (src / 'surface-roi.json').exists():
            shutil.copy2(src / 'surface-roi.json', dest / 'surface-roi.json')
        for name in ['audit.done', 'textures.json', 'LightAndDarkness.log', 'ContinuousScene.log', 'RVision.log']:
            shutil.copy2(src / 'storage' / name, dest / name)
        raw = (src / 'storage/audit.json').read_bytes()
        (dest / 'audit.json.gz').write_bytes(gzip.compress(raw, mtime=0))
        data = json.loads(raw)
        compact = json.loads(raw)
        for sample in compact['samples']:
            del sample['raster']['points']
        (dest / 'scene-summary.json').write_text(json.dumps(compact, ensure_ascii=False, indent=2), encoding='utf8')
        selected = [1, 2, 3, 5, 7, 9] if label == 'normal' else [2, 3]
        for n in selected:
            for mode in ['formal', 'native']:
                name = f'sample-{n}-{mode}.png'
                shutil.copy2(src / 'storage' / name, dest / name)
        if label == 'normal':
            for name in ['sample-1-mask-off.png', 'sample-5-mask-off.png', 'sample-3-aperture-concept.png', 'sample-3-ambient125.png', 'sample-3-lamps150.png', 'texture-tWindows.png', 'texture-tWindows2.png', 'texture-tTower.png']:
                shutil.copy2(src / 'storage' / name, dest / name)
        manifest[label] = {'run': run, 'rawAuditSHA256': hashlib.sha256(raw).hexdigest(), 'rawLocalPath': str(src), 'frames': len(data['samples']), 'files': {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in dest.iterdir() if p.is_file()}}
    (OUT / 'index.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding='utf8')
    print('Archived', {k: len(v['files']) for k, v in manifest.items()})


if __name__ == '__main__':
    main()
