#!/usr/bin/env bash
# Local contention lab: latency-server vs cpu-burn, with and without scx_kube.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BIN="${ROOT}/bin"
DUR="${DUR:-15s}"
CONC="${CONC:-8}"
stamp="$(date -u +%Y%m%dT%H%M%SZ 2>/dev/null || date +%Y%m%d-%H%M%S)"
OUTDIR="${KUBESCX_OUT:-${ROOT}/out/lab-${stamp}}"

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
  exec sudo --preserve-env=DUR,CONC,KUBESCX_OUT,PATH "${ROOT}/hack/lab-local.sh"
fi

"${ROOT}/hack/check-env.sh"

mkdir -p "${OUTDIR}"
uname -a | tee "${OUTDIR}/uname.txt"
echo "kernel: $(uname -r)"
echo "results: ${OUTDIR}"

cleanup() {
  kill "${LSPID:-}" "${BPID:-}" "${SCXPID:-}" 2>/dev/null || true
  wait >/dev/null 2>&1 || true
  echo
  echo "results kept in ${OUTDIR}"
}
trap cleanup EXIT

echo
echo "==> start latency-server and cpu-burn"
"${BIN}/latency-server" -addr 127.0.0.1:8080 -work-us 800 >"${OUTDIR}/latency.log" 2>&1 &
LSPID=$!
"${BIN}/cpu-burn" -workers "$(nproc)" >"${OUTDIR}/burn.log" 2>&1 &
BPID=$!
sleep 0.4
if ! kill -0 "${LSPID}" 2>/dev/null; then
  echo "latency-server failed:"; cat "${OUTDIR}/latency.log"; exit 1
fi

echo
echo "==> baseline: default Linux scheduler"
"${BIN}/loadgen" -url http://127.0.0.1:8080/work -c "${CONC}" -d "${DUR}" -json \
  | tee "${OUTDIR}/baseline.json"
echo

echo "==> load scx_kube"
"${BIN}/scx_kube" >"${OUTDIR}/scx.log" 2>&1 &
SCXPID=$!
sleep 1
if ! kill -0 "${SCXPID}" 2>/dev/null; then
  echo "scx_kube failed to stay running:"; cat "${OUTDIR}/scx.log"; exit 1
fi

echo "==> classify PIDs  latency=${LSPID}  background=${BPID}"
"${BIN}/kubescx-agent" --tgid "${LSPID}:latency" --tgid "${BPID}:background"

echo
echo "==> scx_kube: latency-preferred under contention"
"${BIN}/loadgen" -url http://127.0.0.1:8080/work -c "${CONC}" -d "${DUR}" -json \
  | tee "${OUTDIR}/scx.json"

echo
echo "==> scx_kube counters (last lines)"
tail -n 5 "${OUTDIR}/scx.log" | tee "${OUTDIR}/counters.txt" || true

echo
echo "==> compare"
if command -v python3 >/dev/null 2>&1; then
  python3 "${ROOT}/hack/compare_lab.py" default "${OUTDIR}/baseline.json" scx_kube "${OUTDIR}/scx.json"
else
  echo "python3 not found; raw reports:"
  echo "--- baseline ---"; cat "${OUTDIR}/baseline.json"
  echo "--- scx_kube ---"; cat "${OUTDIR}/scx.json"
fi

echo "Ctrl-C unloads scx_kube and restores the default scheduler."
sleep 2
