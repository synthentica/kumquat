#!/usr/bin/env python3
"""Summarises a scripts/profile.sh run against Kumquat's budgets, as Markdown.

Reads benchmark*.json (written by `Kumquat --benchmark`), the signpost and hang tables exported
from the Instruments traces, and powermetrics' energy samples.
"""
import glob
import json
import os
import re
import statistics
import sys
import xml.etree.ElementTree as ET

folder = sys.argv[1] if len(sys.argv) > 1 else "."


def load(path):
    with open(path) as f:
        return json.load(f)


plain = os.path.join(folder, "benchmark.json")
if not os.path.exists(plain):
    sys.exit(f"No {plain}: the benchmark didn't run.")
report = load(plain)
machine = report.get("machine", {})
print(f"# Kumquat profile, {report.get('date', '')}\n")
print(f"{machine.get('arch')} · {machine.get('cores')} cores · {machine.get('memory_gb', 0):.0f} GB · {machine.get('os')}\n")
print("| Measure | Value | Budget | |")
print("| --- | ---: | ---: | --- |")
for r in report["results"]:
    print(f"| {r['title']} | {r['value']:g} {r['unit']} | {r['limit']:g} {r['unit']} | {'pass' if r['pass'] else '**MISS**'} |")
met = sum(r["pass"] for r in report["results"])
print(f"\n{met} of {len(report['results'])} budgets met.\n")

# Runs under Instruments are slower; show them to spot outliers, not to judge.
others = sorted(glob.glob(os.path.join(folder, "benchmark-*.json")))
if others:
    print("Under Instruments (slower by design):\n")
    for path in others:
        name = os.path.basename(path)[len("benchmark-"):-len(".json")]
        values = {r["id"]: r["value"] for r in load(path)["results"]}
        print(f"- {name}: wheel median {values.get('wheel_open_median_ms', 0):g} ms, "
              f"idle CPU {values.get('idle_cpu_percent', 0):g} %, memory {values.get('idle_memory_mb', 0):g} MB")
    print()


def rows(path):
    """Rows of an xctrace table export, as lists of cell texts (references resolved by id)."""
    try:
        root = ET.parse(path).getroot()
    except (ET.ParseError, FileNotFoundError):
        return []
    by_id = {}
    for element in root.iter():
        if "id" in element.attrib:
            by_id[element.attrib["id"]] = element
    result = []
    for row in root.iter("row"):
        cells = []
        for cell in row:
            target = by_id.get(cell.attrib.get("ref"), cell)
            cells.append((target.tag, target.attrib.get("fmt") or (target.text or "")))
        result.append(cells)
    return result


def nanoseconds(text):
    match = re.match(r"([\d.]+)\s*(ns|µs|us|ms|s)", text)
    if not match:
        return None
    value, unit = float(match.group(1)), match.group(2)
    return value * {"ns": 1, "µs": 1e3, "us": 1e3, "ms": 1e6, "s": 1e9}[unit]


intervals = {}
for path in glob.glob(os.path.join(folder, "*.signposts.xml")):
    for cells in rows(path):
        name = next((text for tag, text in cells if tag == "string" and text in ("Open wheel", "First feedback", "Operation")), None)
        duration = next((nanoseconds(text) for tag, text in cells if tag == "duration"), None)
        if name and duration:
            intervals.setdefault(name, []).append(duration / 1e6)
if intervals:
    print("Signpost intervals seen by Instruments:\n")
    for name, values in sorted(intervals.items()):
        print(f"- {name}: {len(values)} times, median {statistics.median(values):.1f} ms, max {max(values):.1f} ms")
    print()

hangs = sum(len(rows(path)) for path in glob.glob(os.path.join(folder, "*.hangs.xml")))
print(f"Hangs reported by Instruments: {hangs} (budget: 0)\n")

energy = os.path.join(folder, "energy.txt")
if os.path.exists(energy):
    impacts = []
    with open(energy) as f:
        for line in f:
            if line.startswith("Kumquat"):
                numbers = re.findall(r"[\d.]+", line)
                if numbers:
                    impacts.append(float(numbers[-1]))
    if impacts:
        print(f"Energy impact (powermetrics, last column): median {statistics.median(impacts):.2f}, max {max(impacts):.2f} over {len(impacts)} samples\n")
