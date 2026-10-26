#!/usr/bin/env python3
"""Run every test in isolated user-data directories, preserving full logs.

python3 tools/run_tests.py --godot /path/to/godot --output /path/to/qa
Use --match stage28 for a subset. --strict-cleanup fails on known exit leaks.
No third-party Python packages are required. A fresh import runs by default.
"""
import argparse
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile


ROOT = Path(__file__).resolve().parent.parent
CLEANUP = (
    "Pages in use exist at exit",
    "resources still in use at exit",
    "RID allocations of type",
)


def classify(output, code, strict=False):
    lines = output.splitlines()
    errors = [
        line for line in lines
        if "SCRIPT ERROR:" in line or "Parse Error:" in line
        or re.match(r"^\s*FAIL(?:ED|URES)?\s*:", line)
        or re.match(r"^SOME .+ FAILED$", line)
        or (line.startswith("ERROR:") and not any(s in line for s in CLEANUP))
    ]
    cleanup = [line for line in lines if any(s in line for s in CLEANUP)
               or "were leaked at exit" in line
               or "Leaked instance dependency" in line]
    passes = sum(bool(re.match(r"^\s*PASS\s*:", line)) for line in lines)
    # Exit 0 alone is not enough: old tests can quit after a script error.
    completed = passes > 0 or any(re.match(r"^ALL(?: .+)? PASSED$", line) for line in lines)
    passed = code == 0 and not errors and completed
    if strict and cleanup:
        passed = False
    return {"passed": passed, "returncode": code, "pass_lines": passes,
            "errors": errors, "cleanup_messages": cleanup}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default="godot")
    parser.add_argument("--output", default=str(ROOT / "qa_results"))
    parser.add_argument("--match", default="")
    parser.add_argument("--timeout", type=int, default=90)
    parser.add_argument("--skip-import", action="store_true")
    parser.add_argument("--strict-cleanup", action="store_true")
    args = parser.parse_args()
    godot = shutil.which(args.godot)
    if not godot:
        parser.error("Godot was not found. Supply --godot /absolute/path/to/godot")
    tests = sorted(path for path in ROOT.glob("test*.gd")
                   if args.match in path.stem)
    if not tests:
        parser.error("No matching tests")
    output_dir = Path(args.output).resolve()
    output_dir.mkdir(parents=True, exist_ok=True)
    version = subprocess.check_output([godot, "--version"], text=True).strip()
    results = []
    with tempfile.TemporaryDirectory(prefix="frost-city-qa-") as sandbox:
        for index, script in enumerate(tests):
            env = os.environ.copy()
            for variable in ("XDG_DATA_HOME", "XDG_CONFIG_HOME", "XDG_CACHE_HOME"):
                env[variable] = str(Path(sandbox) / str(index) / variable)
            if index == 0 and not args.skip_import:
                command = [godot, "--headless", "--editor", "--path",
                           str(ROOT), "--import"]
                run = subprocess.run(command, capture_output=True, text=True,
                                     env=env, timeout=180)
                text = run.stdout + run.stderr
                (output_dir / "import.log").write_text(text, encoding="utf-8")
                if run.returncode or "SCRIPT ERROR:" in text or "ERROR:" in text:
                    print("Import failed; inspect import.log")
                    return 1
            command = [godot, "--headless", "--path", str(ROOT)]
            if script.with_suffix(".tscn").exists():
                command.append("res://" + script.with_suffix(".tscn").name)
            elif re.search(r"^extends SceneTree\s*$",
                           script.read_text(encoding="utf-8"), re.MULTILINE):
                command.extend(["--script", "res://" + script.name])
            else:
                print("Unsupported test entry point:", script.name)
                return 1
            try:
                run = subprocess.run(command, capture_output=True, text=True,
                                     env=env, timeout=args.timeout)
                text = run.stdout + run.stderr
                result = classify(text, run.returncode, args.strict_cleanup)
            except subprocess.TimeoutExpired as error:
                def decoded(value):
                    return value.decode(errors="replace") if isinstance(value, bytes) else value or ""
                text = decoded(error.stdout) + decoded(error.stderr)
                result = classify(text, 124, args.strict_cleanup)
                result["errors"].append("Timed out")
            (output_dir / (script.stem + ".log")).write_text(text, encoding="utf-8")
            result["test"] = script.stem
            results.append(result)
            print("%s %s (%d checks; %d cleanup messages)" % (
                "PASS" if result["passed"] else "FAIL", script.stem,
                result["pass_lines"], len(result["cleanup_messages"])), flush=True)
    summary = {"engine": version, "tests": len(results),
               "passed": sum(r["passed"] for r in results),
               "pass_lines": sum(r["pass_lines"] for r in results),
               "results": results}
    (output_dir / "summary.json").write_text(
        json.dumps(summary, ensure_ascii=False, indent=2), encoding="utf-8")
    print("RESULT: %d/%d tests; %d PASS lines" % (
        summary["passed"], summary["tests"], summary["pass_lines"]))
    return 0 if summary["passed"] == summary["tests"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
