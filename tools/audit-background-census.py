"""Read-only background inventory; output only to this mod's audit evidence.

Separates embedded native 1.02 templates from installed external templates.
Counts are template counts, not room-generation probabilities or visible apertures.
No game process is started and no production files are modified.
"""
from collections import Counter
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import re
import xml.etree.ElementTree as ET

MOD = Path(__file__).resolve().parents[1]
GAME = MOD.parents[1]
SRC = GAME / "game-reference/decompiled/1.02/src102/scripts/fe"
OUT = MOD / "knowledge/evidence/background-audit-2026-10-20/census.json"
KNOWN_WINDOWS = {"fwindow", "bwindow", "swindow", "cwindow", "awindow", "enclwindow"}
INTERNAL_WINDOWS = {"stwindow", "stwindow2"}
INPUTS = {}


def read(path):
    raw = path.read_bytes()
    INPUTS[path.relative_to(GAME).as_posix()] = hashlib.sha256(raw).hexdigest()
    return raw.decode("utf-8-sig")


def inline(path, name):
    return ET.fromstring(re.search(fr"<{name}>.*?</{name}>", read(path), re.S)[0])


def opt(node):
    options = node.find("options")
    return {} if options is None else dict(options.attrib)


def counts(values):
    return dict(sorted(Counter(values).items()))


def total_counts(rows, key):
    result = Counter()
    for row in rows:
        result.update(row[key])
    return dict(sorted(result.items()))


def representatives(rows, predicate, limit=6):
    return [{"index": row["index"], "name": row["name"],
             "options": row["options"]} for row in rows if predicate(row)][:limit]


def generation_rules(land):
    conf = land.get("conf", "")
    rules = []
    if conf == "3":
        rules += [
            {"field": "transpFon", "when": "all generated main/back rooms", "value": True,
             "evidence": "Land.buildRandomLand:239-267; Location:319-321"},
            {"field": "backform", "when": "middle column x=2, y>0 (ramka=5)", "value": 1,
             "evidence": "Land:242-254; Location:307-309"},
            {"field": "backform", "when": "roof row y=0, x!=2 (ramka=6)", "value": 2,
             "evidence": "Land:256-259; Location:311-313"},
            {"field": "backwall", "when": "x>2, y>0, resulting backwall=tWindows", "value": "tWindows2",
             "evidence": "Land:263-266"},
        ]
    if conf == "5":
        rules += [
            {"field": "backform", "when": "generated top row y=0", "value": 3,
             "evidence": "Land:231-235,340-347"},
            {"field": "transpFon", "when": "generated top row y=0", "value": True,
             "evidence": "Land:231-235,340-347"},
        ]
    if conf == "6":
        rules.append({"field": "transpFon", "when": "post-construction exit pass", "value": True,
                      "status": "assignment is to parameter object after Location construction; do not count as active room override",
                      "evidence": "Land:387-407 constructs rooms; 628-630 later writes _loc3_.transpFon"})
    return rules


def inventory(label, pools, lands, backdefs):
    templates = []
    region_rows = []
    for file in sorted({land.get("file") for land in lands}):
        contexts = [land for land in lands if land.get("file") == file]
        file_rows = []
        for index, room in enumerate(pools[file].findall("room")):
            options = opt(room)
            backs = list(room.findall("back"))
            by_id = Counter(node.get("id", "") for node in backs)
            windows = {key: value for key, value in by_id.items()
                       if "window" in key or key == "enil"}
            holes = {key: value for key, value in by_id.items()
                     if re.fullmatch(r"c?hole[0-6]?", key)}
            er_defs = {key: value for key, value in by_id.items()
                       if "er" in backdefs.get(key, {})}
            row = dict(file=file, index=index, name=room.get("name", ""),
                       room_attributes=dict(room.attrib), options=options,
                       explicit_transpfon="transpfon" in options,
                       explicit_backform=options.get("backform", ""),
                       windows=dict(sorted(windows.items())), holes=dict(sorted(holes.items())),
                       er_definition_objects=dict(sorted(er_defs.items())),
                       contexts=[])
            for land in contexts:
                defaults = opt(land)
                shared_prob = land.get("id") == "prob"
                row["contexts"].append({
                    "land": land.get("id"),
                    "backwall": options.get("backwall", "<host-backwall>" if shared_prob else defaults.get("backwall", "")),
                    "fon": "<host-fon>" if shared_prob else defaults.get("fon", "fonDefault"),
                    "color": options.get("color", "<host-color>" if shared_prob else defaults.get("color", "")),
                    "colorfon": options.get("colorfon", ""),
                    "darkness": options.get("dark", "<host-darkness>" if shared_prob else defaults.get("darkness", "0")),
                    "note": ("Shared trial pool; runtime defaults come from hosting Land, not prob. Land.buildProb:783-789, newLoc:947."
                             if shared_prob else "Static inheritance only; generated backform/transpFon/backwall rules are separate."),
                })
            if file == "rooms_prob":
                row["referenced_by_land_definitions"] = sorted({
                    land.get("id") for land in lands if
                    any(child.tag.startswith("prob") and child.get("id") == room.get("name") for child in land)
                    or land.get("exit") == room.get("name")
                })
            templates.append(row)
            file_rows.append(row)
        for land in contexts:
            land_id = land.get("id")
            contexts_for_land = [next(c for c in row["contexts"] if c["land"] == land_id)
                                 for row in file_rows]
            region_rows.append({
                "land": land_id, "file": file, "default_options": opt(land),
                "conf": land.get("conf", ""), "templates": len(file_rows),
                "effective_backwalls": counts(c["backwall"] for c in contexts_for_land),
                "fon": "<host-fon>" if land_id == "prob" else opt(land).get("fon", "fonDefault"),
                "context_kind": "shared-trial-pool-in-host-land" if land_id == "prob" else "land-definition",
                "explicit_transpfon_templates": sum(row["explicit_transpfon"] for row in file_rows),
                "explicit_backforms": counts(row["explicit_backform"] or "unset" for row in file_rows),
                "window_instances_by_type": total_counts(file_rows, "windows"),
                "window_templates": sum(bool(row["windows"]) for row in file_rows),
                "hole_instances_by_type": total_counts(file_rows, "holes"),
                "hole_templates": sum(bool(row["holes"]) for row in file_rows),
                "generation_rules": generation_rules(land),
                "representatives": {
                    "texture_windows": representatives(file_rows, lambda row: any(
                        c["land"] == land_id and c["backwall"] in ("tWindows", "tTower", "tSteklo")
                        for c in row["contexts"])),
                    "transpfon": representatives(file_rows, lambda row: row["explicit_transpfon"]),
                    "enil": representatives(file_rows, lambda row: "enil" in row["windows"]),
                    "holes": representatives(file_rows, lambda row: bool(row["holes"])),
                    "plain_sky": representatives(file_rows, lambda row: any(
                        c["land"] == land_id and c["backwall"] == "sky" for c in row["contexts"])),
                },
            })
    return {
        "source": label,
        "summary": {
            "land_definitions": len(lands), "unique_pools": len(pools),
            "unique_templates": len(templates),
            "explicit_transpfon_templates": sum(row["explicit_transpfon"] for row in templates),
            "explicit_backform_templates": sum(bool(row["explicit_backform"]) for row in templates),
            "windows_by_type": total_counts(templates, "windows"),
            "holes_by_type": total_counts(templates, "holes"),
            "enil_instances": sum(row["windows"].get("enil", 0) for row in templates),
            "enil_templates": sum("enil" in row["windows"] for row in templates),
            "hole_instances": sum(sum(row["holes"].values()) for row in templates),
            "hole_templates": sum(bool(row["holes"]) for row in templates),
            "hole_or_enil_templates": sum(bool(row["holes"]) or "enil" in row["windows"] for row in templates),
            "known_six_window_instances": sum(sum(v for k, v in row["windows"].items() if k in KNOWN_WINDOWS) for row in templates),
            "internal_window_instances": sum(sum(v for k, v in row["windows"].items() if k in INTERNAL_WINDOWS) for row in templates),
        },
        "regions": sorted(region_rows, key=lambda r: r["land"]),
        "templates": templates,
    }


def main():
    lands = list(inline(SRC / "GameData.as", "game").findall("land"))
    backdefs = {node.get("id"): dict(node.attrib)
                for node in inline(SRC / "AllData.as", "all").findall("back")}
    embedded = {}
    room_source = ""
    for path in sorted((SRC / "rooms").glob("*.as")):
        source = read(path)
        if path.stem == "Rooms":
            room_source = source
        for variable, xml in re.findall(r"(?:public|internal) var (\w+):XML\s*=\s*(<all>.*?</all>)\s*;", source, re.S):
            embedded[(path.stem, variable)] = ET.fromstring(xml)
    instances = dict(re.findall(r"this\.(\w+) = new (\w+)\(", room_source))
    mapping = {}
    for name, expression in re.findall(r'this.rooms\["(\w+)"\] = this\.([\w.]+);', room_source):
        parts = expression.split(".")
        mapping[name] = embedded[(instances[parts[0]], parts[1])] if len(parts) == 2 else embedded[("Rooms", parts[0])]
    files = sorted({land.get("file") for land in lands})
    native = {file: mapping[file] for file in files}
    installed = {file: ET.fromstring(read(GAME / "Rooms" / (file + ".xml"))) for file in files}
    report = {
        "generated_utc": datetime.now(timezone.utc).isoformat(),
        "boundary": "Read-only static census. Unique-pool totals avoid shared pi/mbase double counting. No frequency, actual opacity, brightness, line-of-sight or runtime claims.",
        "production_reference": "LightAndDarkness git c5a04c4 (0.4.1); working source intentionally not used.",
        "production_known_windows": sorted(KNOWN_WINDOWS),
        "renderer_evidence": {
            "world_fon": "World:429 vfon precedes visual; 1063 draws land.act.fon; Grafon:310-324 fallback fonDefault.",
            "backdrop": "Grafon:728-759 tiles backwall bitmap or skips sky; backform 1/2/3 supplies geometry.",
            "opening_alpha": "Grafon:547-608 background object masks; 639-647 preserves final backBmp alpha for transpFon or sky.",
            "coordinate_boundary": "visFon belongs to world.vfon and setFonSize is screen sized; visBack/visBack2/frontBmp use world coordinates. Use display transforms when sampling.",
            "known_gap": "Frozen LadEnvironment:44 sees transpFon only for daylight classification; skyAt:48-55 checks sky/backform, not bitmap openings. WINDOWS:16 omits enil; no hole masks or texture openings.",
            "shared_trials": "GameData prob is a pool registration. Land.buildProb:783-789 takes its XML but constructs with this.newLoc; 947 passes the hosting Land to Location. Default fon/backwall/color/darkness therefore depend on host region, not prob's empty options.",
        },
        "native": inventory("embedded-native-1.02", native, lands, backdefs),
        "installed": inventory("installed-external-xml", installed, lands, backdefs),
        "input_sha256": dict(sorted(INPUTS.items())),
    }
    assert report["native"]["summary"]["unique_templates"] == 639
    assert report["installed"]["summary"]["unique_templates"] == 658
    assert len(lands) == 31 and len(files) == 29
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"output": str(OUT), "native": report["native"]["summary"],
                      "installed": report["installed"]["summary"]}, ensure_ascii=False))


if __name__ == "__main__":
    main()
