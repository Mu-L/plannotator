#!/usr/bin/env bash
# run-all.sh — full version-matrix pass: fixture -> git ground truth ->
# each version (released binaries + dev) -> cross-version report.
#
# Usage: run-all.sh [version ...]
#   default versions: v0.24.2 v0.25.1 v0.26.0 v0.26.1 dev
#
# Env:
#   VM_CACHE_DIR   binary/fixture cache (default: ${TMPDIR:-/tmp}/plannotator-version-matrix)
#
# Robustness over speed: versions run sequentially; a failing version is
# recorded and skipped, the matrix continues. run.sh tears its server down
# via trap even on failure.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CACHE_DIR="${VM_CACHE_DIR:-${TMPDIR:-/tmp}/plannotator-version-matrix}"
export VM_CACHE_DIR="$CACHE_DIR"

VERSIONS=("$@")
if [ ${#VERSIONS[@]} -eq 0 ]; then
  VERSIONS=(v0.24.2 v0.25.1 v0.26.0 v0.26.1 dev)
fi

OUT_ROOT="$SCRIPT_DIR/out"
FIXTURE_DIR="$CACHE_DIR/fixture"
mkdir -p "$OUT_ROOT"

echo "== version matrix: ${VERSIONS[*]}"
echo "== cache: $CACHE_DIR"

# ------------------------------------------------------------ fixture
bash "$SCRIPT_DIR/fixture.sh" "$FIXTURE_DIR" || { echo "fixture build failed" >&2; exit 1; }

# ------------------------------------------------------------ git ground truth
# Captured once, from its own fresh copy of the fixture (read-only git
# commands, but isolation keeps the canonical fixture pristine).
capture_truth() {
  local tdir="$OUT_ROOT/_git-truth"
  local work
  work="$(mktemp -d "${TMPDIR:-/tmp}/pvm-truth.XXXXXX")"
  cp -Rp "$FIXTURE_DIR" "$work/fixture"
  mkdir -p "$tdir"
  (
    cd "$work/fixture"
    export GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null
    local mb
    mb="$(git merge-base main HEAD)"
    echo "$mb" > "$tdir/merge-base.txt"
    git -c core.quotePath=false diff -M "$mb"                 > "$tdir/diff-M.patch"
    git -c core.quotePath=false diff --no-renames "$mb"       > "$tdir/diff-no-renames.patch"
    git -c core.quotePath=false diff -M -w "$mb"              > "$tdir/diff-M-w.patch"
    git -c core.quotePath=false diff -M --numstat "$mb"       > "$tdir/numstat.txt"
    git -c core.quotePath=false diff --no-renames --numstat "$mb" > "$tdir/numstat-no-renames.txt"
    git -c core.quotePath=false diff -M --name-status "$mb"   > "$tdir/name-status.txt"
    git -c core.quotePath=false status --porcelain            > "$tdir/status.txt"
    git log --oneline --first-parent                          > "$tdir/log-first-parent.txt"
    # Untracked files with their line counts (since-base counts them as adds).
    : > "$tdir/untracked-lines.txt"
    git ls-files --others --exclude-standard | while IFS= read -r f; do
      printf '%s %s\n' "$(wc -l < "$f" | tr -d ' ')" "$f" >> "$tdir/untracked-lines.txt"
    done
  )
  local rc=$?
  rm -rf "$work"
  return $rc
}

echo "== capturing git ground truth"
capture_truth || { echo "ground-truth capture failed" >&2; exit 1; }

# ------------------------------------------------------------ versions
port=45731
failures=()
for v in "${VERSIONS[@]}"; do
  echo ""
  echo "== running $v (port $port)"
  if ! bash "$SCRIPT_DIR/run.sh" "$v" --fixture "$FIXTURE_DIR" --out "$OUT_ROOT/$v" --port "$port"; then
    echo "== $v FAILED (continuing)"
    failures+=("$v")
  fi
  port=$((port + 1))
done

# ------------------------------------------------------------ compare
echo ""
echo "== comparing"
if command -v node >/dev/null 2>&1; then
  node "$SCRIPT_DIR/compare.mjs" --out "$OUT_ROOT"
else
  bun "$SCRIPT_DIR/compare.mjs" --out "$OUT_ROOT"
fi
rc=$?

echo ""
if [ ${#failures[@]} -gt 0 ]; then
  echo "== completed with failed versions: ${failures[*]}"
else
  echo "== completed: all versions captured"
fi
echo "== report: $OUT_ROOT/report.md"
exit $rc
