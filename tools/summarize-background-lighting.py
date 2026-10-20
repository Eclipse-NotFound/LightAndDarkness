"""Measure unmodified paired screenshots; encoded RGB proxies, not physical luminance."""
import argparse
import json
from pathlib import Path
import statistics
from PIL import Image


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('evidence', type=Path)
    args = parser.parse_args()
    store = args.evidence / 'storage'
    data = json.loads((store / 'background-lighting.json').read_text('utf8'))
    rows = []
    for sample in data['samples']:
        prefix = sample['prefix']
        with Image.open(store / (prefix + '-baseline051-isolated.png')) as before, Image.open(store / (prefix + '-candidate-isolated.png')) as after:
            a, b = before.convert('RGB'), after.convert('RGB')
            assert a.size == b.size
            sum_a = sum_b = 0.0
            ratios, chromaticity, lowered = [], [], 0
            for y in range(96, a.height - 80, 4):
                for x in range(24, a.width - 24, 4):
                    av, bv = a.getpixel((x, y)), b.getpixel((x, y))
                    ay = sum(c * w for c, w in zip(av, (.2126, .7152, .0722)))
                    if ay < 12:
                        continue
                    by = sum(c * w for c, w in zip(bv, (.2126, .7152, .0722)))
                    sum_a += ay; sum_b += by; ratios.append(by / ay)
                    if by < ay - 2:
                        lowered += 1
                    if sum(av) > 90 and sum(bv) > 90:
                        chromaticity.append(max(abs(av[i] / sum(av) - bv[i] / sum(bv)) for i in range(3)))
            rows.append(dict(land=sample['land'], prefix=prefix, regions=sample['regions'], samples=len(ratios),
                             totalEncodedLumaRatio=sum_b / sum_a if sum_a else None,
                             medianPixelRatio=statistics.median(ratios) if ratios else None,
                             lowerByMoreThanTwo=lowered,
                             medianChannelShareDelta=statistics.median(chromaticity) if chromaticity else None,
                             field=sample.get('isolated'), stability=sample.get('stability')))
    result = dict(version=data['version'], baseline='0.5.1', mode=data['mode'],
                  boundary='Same paused scene/camera; sample every 4 pixels, exclude HUD margins and baseline encoded luma below 12. Encoded Rec.709 RGB proxy only. No gamma correction, physical lux, perceptual percentage or FPS claim.', rows=rows)
    (args.evidence / 'pixel-summary.json').write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n', 'utf8')
    print(json.dumps([dict(land=r['land'], ratio=round(r['totalEncodedLumaRatio'], 4), channelShareDelta=round(r['medianChannelShareDelta'], 5)) for r in rows]))


if __name__ == '__main__':
    main()
