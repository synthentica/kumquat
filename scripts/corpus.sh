#!/usr/bin/env bash
# Downloads the test corpus (Tests/Corpus/manifest.json), converts every file with Kumquat,
# and checks the results with outside tools. Works in CI and on your Mac.
#
#   scripts/corpus.sh [path/to/Kumquat binary]
#
# Files are kept in .corpus/files (checked against their SHA-256), outputs go to .corpus/out,
# and the report to .corpus/report.md. Needs ffmpeg (for ffprobe and SSIM), qpdf, veraPDF and LibreOffice:
#   brew install ffmpeg qpdf verapdf && brew install --cask libreoffice
set -euo pipefail
cd "$(dirname "$0")/.."

BIN="${1:-.build/release/Kumquat}"
MANIFEST="Tests/Corpus/manifest.json"
FILES=".corpus/files"
OUT=".corpus/out"
RESULTS=".corpus/results.jsonl"
mkdir -p "$FILES"
rm -rf "$OUT" "$RESULTS"

echo "== Downloading"
python3 - "$MANIFEST" "$FILES" <<'PY'
import hashlib, json, os, subprocess, sys, urllib.parse
manifest, folder = sys.argv[1], sys.argv[2]
for item in json.load(open(manifest)):
    url = item.get("url")
    if not url:
        continue
    ext = os.path.splitext(urllib.parse.urlparse(url).path)[1] or ""
    path = os.path.join(folder, item["id"] + ext.lower())
    def digest(p):
        h = hashlib.sha256()
        with open(p, "rb") as f:
            for block in iter(lambda: f.read(1 << 20), b""):
                h.update(block)
        return h.hexdigest()
    if os.path.exists(path) and (not item.get("sha256") or digest(path) == item["sha256"]):
        continue
    tmp = path + ".part"
    code = subprocess.call(["curl", "-fsSL", "--retry", "3", "--max-time", "600", "-o", tmp, url])
    if code != 0:
        print(f"download failed: {item['id']} ({url})")
        continue
    if item.get("sha256") and digest(tmp) != item["sha256"]:
        print(f"checksum mismatch: {item['id']}; skipping it")
        os.remove(tmp)
        continue
    os.replace(tmp, path)
    print(f"downloaded {item['id']}")
PY

echo "== Converting"
# The runner logs as it goes; after a crash it marks the conversion that was running and carries on.
for attempt in 1 2 3 4 5 6 7 8 9 10; do
  if "$BIN" --corpus "$MANIFEST" "$FILES" "$OUT" "$RESULTS"; then break; fi
  echo "runner stopped (attempt $attempt), resuming"
done

echo "== Checking with outside tools"
python3 scripts/corpus-validate.py "$RESULTS" .corpus/report.md .corpus/report.json
