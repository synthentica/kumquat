#!/usr/bin/env bash
# Profiles Kumquat on this Mac and compares it with its budgets (Sources/KumquatCore/Benchmark/Budget.swift).
#
#   scripts/profile.sh            build the app, then profile it
#   scripts/profile.sh --no-build profile build/Kumquat.app as it is
#
# Runs `Kumquat --benchmark` once on its own and once under each Instruments template
# (Time Profiler, Hangs, Allocations), samples energy with powermetrics (asks for your password),
# and writes everything to build/profile-<time>/. Needs Xcode (for xctrace) and python3.
set -euo pipefail
cd "$(dirname "$0")/.."

if [ "${1:-}" != "--no-build" ]; then ./scripts/bundle.sh; fi
APP="build/Kumquat.app"
BIN="$APP/Contents/MacOS/Kumquat"
[ -x "$BIN" ] || { echo "No $BIN. Run scripts/bundle.sh first." >&2; exit 1; }
command -v xcrun >/dev/null || { echo "xcrun not found: install Xcode." >&2; exit 1; }

OUT="build/profile-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$OUT"
# A running copy would also answer drags while we measure.
pkill -x Kumquat 2>/dev/null || true

echo "== Plain run (the numbers the budgets are judged on)"
"$BIN" --benchmark "$OUT/benchmark.json" | tee "$OUT/benchmark.txt"

for template in "Time Profiler" "Hangs" "Allocations"; do
  name="${template// /-}"
  echo "== $template"
  xcrun xctrace record --template "$template" --output "$OUT/$name.trace" --no-prompt \
    --launch -- "$BIN" --benchmark "$OUT/benchmark-$name.json" >"$OUT/$name.log" 2>&1 \
    || echo "   $template didn't finish; see $OUT/$name.log"
done

echo "== Energy (powermetrics needs administrator rights)"
"$BIN" --benchmark "$OUT/benchmark-energy.json" >/dev/null &
PID=$!
sleep 1
if sudo -n true 2>/dev/null || sudo -v; then
  # Twenty one-second samples covering the wheel, the toast and the idle stretch.
  sudo powermetrics --samplers tasks --show-process-energy -i 1000 -n 20 >"$OUT/energy.txt" 2>&1 || true
fi
wait "$PID" || true

echo "== Signpost intervals and hangs from the traces"
for trace in "$OUT"/*.trace; do
  [ -d "$trace" ] || continue
  base="${trace%.trace}"
  xcrun xctrace export --input "$trace" --toc >"$base.toc.xml" 2>/dev/null || continue
  xcrun xctrace export --input "$trace" \
    --xpath '/trace-toc/run[@number="1"]/data/table[@schema="os-signpost-interval"]' >"$base.signposts.xml" 2>/dev/null || true
  xcrun xctrace export --input "$trace" \
    --xpath '/trace-toc/run[@number="1"]/data/table[@schema="potential-hangs"]' >"$base.hangs.xml" 2>/dev/null || true
done

python3 scripts/profile-report.py "$OUT" | tee "$OUT/report.md"
echo
echo "Everything is in $OUT. Open the .trace files in Instruments for the details."
