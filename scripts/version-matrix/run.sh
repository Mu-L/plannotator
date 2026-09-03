#!/usr/bin/env bash
# run.sh — run one Plannotator version against a fresh copy of the fixture
# and capture its machine-readable review behavior.
#
# Usage: run.sh <version|dev> [--fixture <dir>] [--out <dir>] [--port <port>]
#   <version>   e.g. v0.26.1 (GitHub release tag) or "dev" (compile worktree)
#
# Env:
#   VM_CACHE_DIR   binary/fixture cache (default: ${TMPDIR:-/tmp}/plannotator-version-matrix)
#
# Every server run is fully sandboxed: throwaway HOME, PLANNOTATOR_DATA_DIR,
# TMPDIR, its own port and its own fixture copy. Only PIDs started here are
# killed. Decision endpoints (/api/approve, /api/feedback) are never called.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CACHE_DIR="${VM_CACHE_DIR:-${TMPDIR:-/tmp}/plannotator-version-matrix}"

VERSION="${1:-}"
[ -n "$VERSION" ] || { echo "usage: run.sh <version|dev> [--fixture <dir>] [--out <dir>] [--port <port>]" >&2; exit 2; }
shift

FIXTURE_DIR="$CACHE_DIR/fixture"
OUT_DIR="$SCRIPT_DIR/out/$VERSION"
PORT=""

while [ $# -gt 0 ]; do
  case "$1" in
    --fixture) FIXTURE_DIR="$2"; shift 2 ;;
    --out) OUT_DIR="$2"; shift 2 ;;
    --port) PORT="$2"; shift 2 ;;
    *) echo "run.sh: unknown arg: $1" >&2; exit 2 ;;
  esac
done

mkdir -p "$CACHE_DIR" "$OUT_DIR"

log() { echo "[$VERSION] $*"; }

# ------------------------------------------------------------ resolve binary
BINARY=""
if [ "$VERSION" = "dev" ]; then
  BINARY="$CACHE_DIR/bin/dev/plannotator"
  mkdir -p "$(dirname "$BINARY")"
  log "compiling dev binary from worktree..."
  ( cd "$REPO_ROOT" && bun build apps/hook/server/index.ts --compile --outfile "$BINARY" ) \
    > "$OUT_DIR/build.log" 2>&1 || { log "dev compile FAILED (see $OUT_DIR/build.log)"; exit 1; }
else
  BINARY="$CACHE_DIR/bin/$VERSION/plannotator-darwin-arm64"
  if [ ! -x "$BINARY" ]; then
    mkdir -p "$(dirname "$BINARY")"
    url="https://github.com/backnotprop/plannotator/releases/download/$VERSION/plannotator-darwin-arm64"
    log "downloading $url"
    curl -fsSL -o "$BINARY.tmp" "$url"
    expected="$(curl -fsSL "$url.sha256" | cut -d' ' -f1)"
    actual="$(shasum -a 256 "$BINARY.tmp" | cut -d' ' -f1)"
    if [ -n "$expected" ] && [ "$expected" != "$actual" ]; then
      log "checksum mismatch: expected $expected got $actual"; rm -f "$BINARY.tmp"; exit 1
    fi
    chmod +x "$BINARY.tmp"
    mv "$BINARY.tmp" "$BINARY"
  fi
fi

# ------------------------------------------------------------ fixture copy
[ -d "$FIXTURE_DIR/.git" ] || bash "$SCRIPT_DIR/fixture.sh" "$FIXTURE_DIR"

SANDBOX="$(mktemp -d "${TMPDIR:-/tmp}/pvm-${VERSION//\//_}.XXXXXX")"
mkdir -p "$SANDBOX/home" "$SANDBOX/data" "$SANDBOX/tmp"
cp -Rp "$FIXTURE_DIR" "$SANDBOX/fixture"

# ------------------------------------------------------------ port
if [ -z "$PORT" ]; then
  PORT=45720
fi
while lsof -nP -iTCP:"$PORT" -sTCP:LISTEN >/dev/null 2>&1; do
  PORT=$((PORT + 1))
done

BASE_URL="http://127.0.0.1:$PORT"
SERVER_PID=""

cleanup() {
  if [ -n "$SERVER_PID" ] && kill -0 "$SERVER_PID" 2>/dev/null; then
    kill -TERM "$SERVER_PID" 2>/dev/null || true
    for _ in 1 2 3 4 5 6 7 8 9 10; do
      kill -0 "$SERVER_PID" 2>/dev/null || break
      sleep 0.3
    done
    kill -KILL "$SERVER_PID" 2>/dev/null || true
    wait "$SERVER_PID" 2>/dev/null || true
  fi
  rm -rf "$SANDBOX"
}
trap cleanup EXIT INT TERM

# ------------------------------------------------------------ launch server
log "launching review server on port $PORT"
cd "$SANDBOX/fixture"
env -i \
  HOME="$SANDBOX/home" \
  PATH="/usr/bin:/bin:/usr/sbin:/sbin" \
  TMPDIR="$SANDBOX/tmp" \
  LANG="en_US.UTF-8" \
  TERM="dumb" \
  GIT_CONFIG_NOSYSTEM=1 \
  PLANNOTATOR_DATA_DIR="$SANDBOX/data" \
  PLANNOTATOR_REMOTE=1 \
  PLANNOTATOR_PORT="$PORT" \
  PLANNOTATOR_AI=disabled \
  PLANNOTATOR_SHARE=disabled \
  PLANNOTATOR_JINA=0 \
  PLANNOTATOR_GLIMPSE=0 \
  PLANNOTATOR_SKIP_BROWSER_OPEN=1 \
  "$BINARY" review </dev/null > "$OUT_DIR/server.log" 2>&1 &
SERVER_PID=$!
cd "$SCRIPT_DIR"

# ------------------------------------------------------------ readiness
ready=0
for _ in $(seq 1 180); do
  if ! kill -0 "$SERVER_PID" 2>/dev/null; then
    log "server exited early (see $OUT_DIR/server.log)"
    exit 1
  fi
  if curl -sf -o /dev/null --max-time 2 "$BASE_URL/api/diff"; then
    ready=1
    break
  fi
  sleep 0.5
done
if [ "$ready" -ne 1 ]; then
  log "server never became ready on $BASE_URL (see $OUT_DIR/server.log)"
  exit 1
fi

# capture helper: capture <name> <url-path>  -> writes <name>.json + records code
declare -a HTTP_META=()
capture_get() {
  local name="$1" path="$2"
  local code
  code="$(curl -s -o "$OUT_DIR/$name.json" -w '%{http_code}' --max-time 60 "$BASE_URL$path")" || code="000"
  HTTP_META+=("\"$name\": {\"path\": $(printf '%s' "$path" | jq -Rs .), \"status\": \"$code\"}")
  echo "$code"
}

# ------------------------------------------------------------ captures
log "capturing /api/diff (initial)"
capture_get "diff_initial" "/api/diff" >/dev/null

initial_type="$(jq -r '.diffType // "n/a"' "$OUT_DIR/diff_initial.json" 2>/dev/null || echo "unparseable")"
log "initial diffType: $initial_type"

if [ "$initial_type" = "since-base" ]; then
  cp "$OUT_DIR/diff_initial.json" "$OUT_DIR/diff.json"
  HTTP_META+=('"diff": {"path": "/api/diff (copy of initial)", "status": "200"}')
else
  log "switching to since-base"
  sw_code="$(curl -s -o "$OUT_DIR/diff_switch_response.json" -w '%{http_code}' --max-time 60 \
    -X POST -H 'Content-Type: application/json' \
    -d '{"diffType":"since-base"}' "$BASE_URL/api/diff/switch")" || sw_code="000"
  HTTP_META+=("\"diff_switch\": {\"path\": \"/api/diff/switch since-base\", \"status\": \"$sw_code\"}")
  sleep 1
  capture_get "diff" "/api/diff" >/dev/null
fi

log "capturing /api/commits"
capture_get "commits" "/api/commits?limit=50" >/dev/null

log "capturing /api/file-content probes"
capture_get "probe_normal" "/api/file-content?path=apps/web/src/index.ts" >/dev/null
capture_get "probe_renamed" "/api/file-content?path=packages/universal/src/components/spaceship/Panel.tsx&oldPath=packages/universal/src/components/etoro/Card.tsx&base=main" >/dev/null
capture_get "probe_big" "/api/file-content?path=bigassets/metrics-6mb.txt" >/dev/null

log "capturing /api/diff/fresh"
capture_get "fresh" "/api/diff/fresh" >/dev/null

# ------------------------------------------------------------ stats
if command -v node >/dev/null 2>&1; then
  node "$SCRIPT_DIR/lib/parse-patch.mjs" "$OUT_DIR/diff.json" > "$OUT_DIR/stats.json" 2> "$OUT_DIR/stats.err" \
    || log "stats parse failed (see stats.err)"
else
  bun "$SCRIPT_DIR/lib/parse-patch.mjs" "$OUT_DIR/diff.json" > "$OUT_DIR/stats.json" 2> "$OUT_DIR/stats.err" \
    || log "stats parse failed (see stats.err)"
fi

# ------------------------------------------------------------ meta
binary_sha="$(shasum -a 256 "$BINARY" | cut -d' ' -f1)"
{
  echo "{"
  echo "  \"version\": \"$VERSION\","
  echo "  \"binary\": \"$BINARY\","
  echo "  \"binarySha256\": \"$binary_sha\","
  echo "  \"port\": $PORT,"
  echo "  \"initialDiffType\": \"$initial_type\","
  echo "  \"capturedAt\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\","
  echo "  \"http\": {"
  ( IFS=,; echo "    ${HTTP_META[*]}" )
  echo "  }"
  echo "}"
} | jq . > "$OUT_DIR/meta.json" 2>/dev/null || {
  # jq re-format failed; write unformatted
  {
    echo "{ \"version\": \"$VERSION\", \"port\": $PORT, \"initialDiffType\": \"$initial_type\" }"
  } > "$OUT_DIR/meta.json"
}

log "done -> $OUT_DIR"
