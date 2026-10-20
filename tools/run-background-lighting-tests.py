"""Frozen candidate and 0.5.1 comparison, private AIR storage and owned desktop.

--prepare-only writes a build plan/configuration and does not start Java or AIR.
Functional/pixel runs reject concurrent AIR and low commit headroom.
Offline JVM work is recorded but allowed by the shared test-registry rules.
"""
import argparse
import ctypes
from ctypes import wintypes as W
from datetime import datetime
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import time
from xml.sax.saxutils import escape

MOD = Path(__file__).resolve().parents[1]
GAME = MOD.parents[1]
BASELINE_SHA = "BAFE52B9145194C2E9D3A08A3331236FEE5F1B6A3E1F016A46D9BC288C04C47A"
sys.dont_write_bytecode = True
sys.path.insert(0, str(GAME / "mods/ModLoader/tools"))
from air_test_process import HiddenProcess


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest().upper()


def write(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf8")


def processes(names=("adl64.exe", "java.exe", "javaw.exe")):
    class Entry(ctypes.Structure):
        _fields_ = [("dwSize", W.DWORD), ("cntUsage", W.DWORD), ("pid", W.DWORD),
                    ("heap", ctypes.c_size_t), ("module", W.DWORD), ("threads", W.DWORD),
                    ("parent", W.DWORD), ("priority", W.LONG), ("flags", W.DWORD),
                    ("exe", W.WCHAR * 260)]
    kernel = ctypes.WinDLL("kernel32", use_last_error=True)
    kernel.CreateToolhelp32Snapshot.restype = W.HANDLE
    kernel.Process32FirstW.argtypes = [W.HANDLE, ctypes.POINTER(Entry)]
    kernel.Process32NextW.argtypes = [W.HANDLE, ctypes.POINTER(Entry)]
    kernel.CloseHandle.argtypes = [W.HANDLE]
    handle = kernel.CreateToolhelp32Snapshot(2, 0)
    if handle == ctypes.c_void_p(-1).value:
        raise ctypes.WinError(ctypes.get_last_error())
    entry = Entry()
    entry.dwSize = ctypes.sizeof(entry)
    result = []
    try:
        more = kernel.Process32FirstW(handle, ctypes.byref(entry))
        while more:
            if entry.exe.lower() in names:
                result.append({"pid": entry.pid, "name": entry.exe})
            more = kernel.Process32NextW(handle, ctypes.byref(entry))
    finally:
        kernel.CloseHandle(handle)
    return result


def memory():
    class Memory(ctypes.Structure):
        _fields_ = [("length", W.DWORD), ("load", W.DWORD)] + [
            (name, ctypes.c_ulonglong) for name in ("totalPhysical", "availablePhysical", "totalCommit",
                                                   "availableCommit", "totalVirtual", "availableVirtual", "extendedVirtual")]
    state = Memory()
    state.length = ctypes.sizeof(state)
    if not ctypes.WinDLL("kernel32", use_last_error=True).GlobalMemoryStatusEx(ctypes.byref(state)):
        raise ctypes.WinError()
    return {"physicalBytes": state.availablePhysical, "commitBytes": state.availableCommit}


def guard(minimum, owned_pid=None):
    observed = [p for p in processes() if p["pid"] != owned_pid]
    competitors = [p for p in observed if p["name"].lower() == "adl64.exe"]
    mem = memory()
    return {"ok": not competitors and mem["commitBytes"] >= minimum,
            "competitors": competitors, "offlineProcesses": [p for p in observed if p not in competitors],
            "memory": mem, "minimumCommitBytes": minimum}


def copy_with_hash(source, target, sources):
    source = Path(source).resolve()
    before = sha(source)
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source, target)
    assert sha(source) == before == sha(target), "Input changed while copying: " + str(source)
    sources[str(source)] = before


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--candidate", required=True)
    parser.add_argument("--baseline", default=str(MOD / "build/out/perf-v051-visible/LightAndDarknessMod.swf"))
    parser.add_argument("--expected-version", default="0.6.0")
    parser.add_argument("--mode", choices=["verify", "large", "smoke"], default="verify")
    parser.add_argument("--mixed", action="store_true")
    parser.add_argument("--prepare-only", action="store_true")
    parser.add_argument("--width", type=int, default=1440)
    parser.add_argument("--height", type=int, default=900)
    parser.add_argument("--timeout", type=int, default=600)
    args = parser.parse_args()
    if not (640 <= args.width <= 3840 and 480 <= args.height <= 2160):
        parser.error("Invalid test window dimensions")
    if args.mode == "large" and not args.mixed:
        parser.error("--mode large requires --mixed for actual ContinuousScene metadata")
    candidate, baseline = Path(args.candidate).resolve(), Path(args.baseline).resolve()
    assert candidate.is_file(), "Missing candidate"
    assert baseline.is_file() and sha(baseline) == BASELINE_SHA, "Comparison must use frozen formal 0.5.1 bytes"
    appid = "remains-lad-background-lighting-" + datetime.now().strftime("%Y%m%d%H%M%S%f")
    root, evidence = MOD / "build/generated" / appid, MOD / "build/evidence" / appid
    root.mkdir(parents=True)
    evidence.mkdir(parents=True)
    sdk = GAME / "mods/Sandevistan/build/tools"
    config, probe = root / "probe-config.xml", root / "BackgroundLightingTestMod.swf"
    config.write_text('<flex-config xmlns="http://www.adobe.com/2006/flex-config"><target-player>32.0</target-player>'
                      '<compiler><source-path><path-element>' + escape(str(MOD / "tests")) + '</path-element></source-path>'
                      '<external-library-path><path-element>' + escape(str(sdk / "airsdk/frameworks/libs/air/airglobal.swc")) +
                      '</path-element></external-library-path><debug>false</debug><optimize>true</optimize></compiler></flex-config>', encoding="utf8")
    compile_command = ["D:/Program Files/Adobe Animate 2024/jre/bin/java.exe", "-Xmx768m", "-jar", str(sdk / "flexsdk/lib/mxmlc.jar"),
                       "+flexlib=" + str(sdk / "flexsdk/frameworks"), "-load-config=" + str(config), "-swf-version=32",
                       "-use-network=false", "-static-link-runtime-shared-libraries=true", "-output=" + str(probe),
                       str(MOD / "tests/BackgroundLightingTestMod.as")]
    plan = {"applicationID": appid, "runtime": str(root), "evidence": str(evidence), "candidate": str(candidate),
            "candidateSHA256": sha(candidate), "baseline": str(baseline), "baselineSHA256": BASELINE_SHA,
            "expectedVersion": args.expected_version, "mode": args.mode, "mixed": args.mixed,
            "compileCommand": compile_command, "probeSourceSHA256": sha(MOD / "tests/BackgroundLightingTestMod.as")}
    write(evidence / "run-plan.json", plan)
    if args.prepare_only:
        print(json.dumps({"prepared": str(root), "evidence": str(evidence), "executed": False}), flush=True)
        return
    first_guard = guard(2 * 1024 ** 3)
    write(evidence / "initial-guard.json", first_guard)
    assert first_guard["ok"], "Concurrent AIR or insufficient commit memory: " + str(first_guard)
    compiled = subprocess.run(compile_command, capture_output=True)
    (evidence / "compiler-stdout.txt").write_bytes(compiled.stdout)
    (evidence / "compiler-stderr.txt").write_bytes(compiled.stderr)
    if compiled.returncode:
        raise RuntimeError("Probe compile failed: " + compiled.stdout.decode("utf8", errors="replace") + compiled.stderr.decode("utf8", errors="replace"))
    probe_source = MOD / "tests/BackgroundLightingTestMod.as"
    assert sha(probe_source) == plan["probeSourceSHA256"], "Probe source changed during compilation"
    sources = {str(probe_source.resolve()): plan["probeSourceSHA256"]}
    asset_names = ["pfe.swf", "texture.swf", "texture1.swf", "sprite.swf", "sprite1.swf", "sound.swf", "sound_unit.swf",
                   "sound_weapon.swf", "lang.xml", "rooms.xml"] + [p.name for p in GAME.glob("text_*.xml")]
    for name in asset_names:
        copy_with_hash(GAME / name, root / name, sources)
    for path in (GAME / "Rooms").rglob("*"):
        if path.is_file():
            copy_with_hash(path, root / "Rooms" / path.relative_to(GAME / "Rooms"), sources)
    release = root / "mods/LightAndDarkness/release"
    copy_with_hash(candidate, release / "LightAndDarknessMod.swf", sources)
    assert sha(release / "LightAndDarknessMod.swf") == plan["candidateSHA256"], "Candidate changed after preparation"
    copy_with_hash(baseline, root / "baseline.swf", sources)
    copy_with_hash(probe, release / probe.name, sources)
    copy_with_hash(MOD / "atmosphere.json", release.parent / "atmosphere.json", sources)
    host = root / "mods/ModLoader"
    for name in ("RemainsModLauncher.exe", "RemainsModScanner.exe", "supported-mods.txt"):
        copy_with_hash(GAME / "mods/ModLoader" / name, host / name, sources)
    entries = ["LightAndDarknessMod", "BackgroundLightingTestMod"]
    if args.mixed:
        for name in ["ModLoader", "ContinuousScene", "RealisticVision", "WallBlend"]:
            for path in (GAME / "mods" / name / "release").iterdir():
                if path.is_file() and path.suffix in [".swf", ".txt", ".json", ".xml"]:
                    copy_with_hash(path, root / "mods" / name / "release" / path.name, sources)
            entries.append(name + "Mod")
    write(root / "background-lighting-config.json", {"mode": args.mode, "mixed": args.mixed,
          "expectedVersion": args.expected_version, "baselineVersion": "0.5.1"})
    descriptor = root / "application.xml"
    descriptor.write_text(f'<?xml version="1.0"?><application xmlns="http://ns.adobe.com/air/application/30.0"><id>{appid}</id>'
                          f'<versionNumber>1.0</versionNumber><filename>BackgroundLightingTest</filename><initialWindow><content>pfe.swf</content>'
                          f'<visible>false</visible><width>{args.width}</width><height>{args.height}</height><renderMode>direct</renderMode></initialWindow>'
                          '<supportedProfiles>extendedDesktop</supportedProfiles></application>', encoding="utf8")
    selected = subprocess.run([str(GAME / "mods/ModLoader/RemainsModLauncher.exe"), "--root", str(root), "--only", ",".join(entries),
                               "--no-ui", "--report", str(evidence / "selection.json")], capture_output=True)
    assert selected.returncode == 0, selected.stdout.decode("utf8", errors="replace") + selected.stderr.decode("utf8", errors="replace")
    selection = json.loads((evidence / "selection.json").read_text(encoding="utf-8-sig"))
    assert set(selection["configuration"]["selected"]) == set(entries)
    frozen = {str(path.relative_to(root)): sha(path) for path in root.rglob("*") if path.is_file()}
    write(evidence / "hashes.json", frozen)
    write(evidence / "sources.json", sources)
    storage = Path(os.environ["APPDATA"]) / appid / "Local Store"
    assert not storage.exists(), "Unique AIR identity unexpectedly has existing storage"
    storage.mkdir(parents=True)
    write(storage / "ContinuousScene.preferences.json", {"nativeEnabled": args.mode == "large"})
    process, metadata = None, None
    guards, aborted = [], ""
    before_launch = guard(2 * 1024 ** 3)
    guards.append(before_launch)
    assert before_launch["ok"], "Work window changed before AIR launch: " + str(before_launch)
    started_ms = int(time.time() * 1000)
    try:
        with (evidence / "stdout.txt").open("wb") as stdout, (evidence / "stderr.txt").open("wb") as stderr:
            process = HiddenProcess([str(GAME / "adl64.exe"), "-runtime", str(GAME / "runtimes/air/win64"), str(descriptor), "-nodebug"],
                                    cwd=root, stdout=stdout, stderr=stderr)
            metadata = {"applicationID": appid, "pid": process.pid, "desktop": process.desktop, "runtime": str(root), "startedMs": started_ms}
            write(evidence / "process.json", metadata)
            print("Evidence: " + str(evidence), flush=True)
            deadline, next_guard = time.monotonic() + args.timeout, 0
            while process.poll() is None and time.monotonic() < deadline:
                if time.monotonic() >= next_guard:
                    state = guard(512 * 1024 ** 2, process.pid)
                    state["atMs"] = int(time.time() * 1000)
                    guards.append(state)
                    next_guard = time.monotonic() + 1
                    if not state["ok"]:
                        aborted = "Concurrent AIR or low commit headroom"
                        break
                if (storage / "background-lighting.done").exists():
                    break
                if (evidence / "stop-request").exists():
                    aborted = "Owner stop request"
                    break
                time.sleep(.25)
            if not (storage / "background-lighting.done").exists() and not aborted:
                aborted = "Process exited before result or watchdog timeout"
    finally:
        if process:
            if process.poll() is None:
                process.kill()
                process.wait(timeout=10)
            process.close()
            metadata["endedMs"] = int(time.time() * 1000)
            write(evidence / "process.json", metadata)
        write(evidence / "guards.json", {"aborted": aborted, "observations": guards})
        if storage.exists():
            shutil.copytree(storage, evidence / "storage")
    assert not aborted, aborted + "; only the owned test process was stopped"
    assert (evidence / "storage/background-lighting.done").read_text("utf8") == "PASS"
    result = json.loads((evidence / "storage/background-lighting.json").read_text("utf8"))
    assert not result["error"] and result["version"] == args.expected_version and result["baselineVersion"] == "0.5.1"
    assert result["applicationID"] == appid and result["roomsLoad"] == 1
    assert result["checks"] >= 35 and all(row["pass"] for row in result["assertions"])
    assert len(result["samples"]) == {"verify": 6, "large": 3, "smoke": 1}[args.mode]
    if args.mode == "large":
        assert all(row["regions"] > 1 for row in result["samples"][1:])
        for row in result["samples"][1:]:
            scene = row["scene"]
            assert scene["nativeEnabled"] and scene["sceneLarge"] and scene["stateUsesCurrentLocation"] and scene["viewReady"]
            assert scene["nativeRegions"] > 1 and (scene["spaceX"] > 48 or scene["spaceY"] > 25)
        assert not result["samples"][0]["scene"]["sceneLarge"], "Base unexpectedly converted to a large map"
    else:
        assert all(not row["scene"]["sceneLarge"] for row in result["samples"])
    for row in result["samples"]:
        stability = row["stability"]
        assert stability["settleFrames"] >= 8 and stability["observedFrames"] >= 8
        assert stability["signatureStable"] and stability["pixelsStable"] and stability["cameraStable"]
        for suffix in ("candidate-actual", "baseline051-actual", "candidate-isolated", "baseline051-isolated"):
            assert (evidence / "storage" / (row["prefix"] + "-" + suffix + ".png")).is_file()
    loader = result["loader"]
    session = re.fullmatch(r"run_(\d{13})_\d+", loader.get("session", ""))
    assert session and started_ms <= int(session[1]) <= metadata["endedMs"], "Missing or stale loader session"
    assert loader.get("boot") is not None and loader.get("boot_start") is not None
    assert {key[10:] for key in loader if key.startswith("requested_")} == set(entries)
    assert {key[3:] for key in loader if key.startswith("ok_")} == set(entries)
    assert not any(key.startswith("err_") for key in loader)
    assert all(sha(root / name) == digest for name, digest in frozen.items()), "Frozen runtime input changed"
    assert all(sha(path) == digest for path, digest in sources.items()), "Source input changed during test"
    log = (evidence / "storage/LightAndDarkness.log").read_text("utf8")
    assert "v" + args.expected_version + " loaded" in log
    assert not any(token in log for token in ["FRAME_ERROR", "ATTACH_FAILED", "PREPARE_FAILED", "RESTORE_FAILED"])
    print(json.dumps({"result": "PASS", "evidence": str(evidence), "checks": result["checks"], "samples": len(result["samples"])}), flush=True)


if __name__ == "__main__":
    main()
