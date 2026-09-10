#!/usr/bin/env bash
# Local contention lab: latency-server vs cpu-burn, with and without scx_kube.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BIN="${ROOT}/bin"
DUR="${DUR:-15s}"
CONC="${CONC:-8}"

if [[ "$(uname -s)" != "Linux" ]]; then
  echo "lab-local must run on Linux (this host is $(uname -s))."
  echo "Go tools are still useful: make go && go test ./..."
  exit 1
fi

if [[ ! -x "${BIN}/latency-server" || ! -x "${BIN}/cpu-burn" || ! -x "${BIN}/loadgen" ]]; then
  echo "building Go tools..."
  make -C "${ROOT}" go
fi

if [[ ! -x "${BIN}/scx_kube" ]]; then
  echo "building scx_kube (requires sched_ext)..."
  make -C "${ROOT}" scheduler
fi

if [[ "${EUID}" -ne 0 ]]; then
  echo "re-running lab-local with sudo so scx_kube can load"
  exec sudo --preserve-env=DUR,CONC,PATH "${ROOT}/hack/lab-local.sh"
fi

"${ROOT}/hack/check-env.sh"

workdir="$(mktemp -d /tmp/kubescx-lab.XXXXXX)"
cleanup() {
  kill "${LSPID:-}" "${BPID:-}" "${SCXPID:-}" 2>/dev/null || true
  wait >/dev/null 2>&1 || true
  rm -rf "${workdir}"
}
trap cleanup EXIT

echo
echo "==> start latency-server and cpu-burn"
"${BIN}/latency-server" -addr 127.0.0.1:8080 -work-us 800 >"${workdir}/latency.log" 2>&1 &
LSPID=$!
"${BIN}/cpu-burn" -workers "$(nproc)" >"${workdir}/burn.log" 2>&1 &
BPID=$!
sleep 0.4
if ! kill -0 "${LSPID}" 2>/dev/null; then
  echo "latency-server failed:"; cat "${workdir}/latency.log"; exit 1
fi

echo
echo "==> baseline: default Linux scheduler"
"${BIN}/loadgen" -url http://127.0.0.1:8080/work -c "${CONC}" -d "${DUR}" -json \
  | tee "${workdir}/baseline.json"
echo

echo "==> load scx_kube"
"${BIN}/scx_kube" >"${workdir}/scx.log" 2>&1 &
SCXPID=$!
sleep 1
if ! kill -0 "${SCXPID}" 2>/dev/null; then
  echo "scx_kube failed to stay running:"; cat "${workdir}/scx.log"; exit 1
fi

echo "==> classify PIDs  latency=${LSPID}  background=${BPID}"
"${BIN}/kubescx-agent" --tgid "${LSPID}:latency" --tgid "${BPID}:background"

echo
echo "==> scx_kube: latency-preferred under contention"
"${BIN}/loadgen" -url http://127.0.0.1:8080/work -c "${CONC}" -d "${DUR}" -json \
  | tee "${workdir}/scx.json"

echo
echo "==> compare"
if command -v python3 >/dev/null 2>&1; then
  python3 - "${workdir}/baseline.json" "${workdir}/scx.json" <<'PY'
import json, sys
def load(path):
    with open(path) as f:
        return json.load(f)
a, b = load(sys.argv[1]), load(sys.argv[2])
print(f"{'scheduler':<16} {'p50_ms':>8} {'p95_ms':>8} {'p99_ms':>8} {'p99.9_ms':>9} {'rps':>8}")
print(f"{'default':<16} {a['p50_ms']:8.2f} {a['p95_ms']:8.2f} {a['p99_ms']:8.2f} {a['p999_ms']:9.2f} {a['rps']:8.1f}")
print(f"{'scx_kube':<16} {b['p50_ms']:8.2f} {b['p95_ms']:8.2f} {b['p99_ms']:8.2f} {b['p999_ms']:9.2f} {b['rps']:8.1f}")
if a['p99_ms']:
    delta = (a['p99_ms'] - b['p99_ms']) / a['p99_ms'] * 100
    print(f"p99 change vs default: {delta:+.1f}%  (positive means scx_kube is better)")
print()
print("A negative result is still useful. Record it; do not tune the writeup to invent a win.")
PY
else
  echo "python3 not found; raw reports:"
  echo "--- baseline ---"; cat "${workdir}/baseline.json"
  echo "--- scx_kube ---"; cat "${workdir}/scx.json"
fi

echo
echo "logs: ${workdir} (kept until this script exits)"
echo "Ctrl-C unloads scx_kube and restores the default scheduler."
sleep 2
