#!/usr/bin/env bash
# Second workload: two latency-class servers share the latency DSQ while a burner runs.
# Question: do both stay ahead of background, and do they starve each other?
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BIN="${ROOT}/bin"
DUR="${DUR:-15s}"
CONC="${CONC:-4}"
stamp="$(date -u +%Y%m%dT%H%M%SZ 2>/dev/null || date +%Y%m%d-%H%M%S)"
OUTDIR="${KUBESCX_OUT:-${ROOT}/out/lab-two-latency-${stamp}}"

if [[ "$(uname -s)" != "Linux" ]]; then
  echo "lab-two-latency must run on Linux (this host is $(uname -s))."
  exit 1
fi

if [[ ! -x "${BIN}/latency-server" || ! -x "${BIN}/cpu-burn" || ! -x "${BIN}/loadgen" ]]; then
  make -C "${ROOT}" go
fi
if [[ ! -x "${BIN}/scx_kube" ]]; then
  make -C "${ROOT}" scheduler
fi

if [[ "${EUID}" -ne 0 ]]; then
  echo "re-running with sudo so scx_kube can load"
  exec sudo --preserve-env=DUR,CONC,KUBESCX_OUT,PATH "${ROOT}/hack/lab-two-latency.sh"
fi

"${ROOT}/hack/check-env.sh"

mkdir -p "${OUTDIR}"
uname -a | tee "${OUTDIR}/uname.txt"
echo "results: ${OUTDIR}"

cleanup() {
  kill "${A:-}" "${B:-}" "${BPID:-}" "${SCXPID:-}" 2>/dev/null || true
  wait >/dev/null 2>&1 || true
  echo "results kept in ${OUTDIR}"
}
trap cleanup EXIT

echo
echo "==> two latency-servers + cpu-burn"
"${BIN}/latency-server" -addr 127.0.0.1:8080 -work-us 800 >"${OUTDIR}/a.log" 2>&1 &
A=$!
"${BIN}/latency-server" -addr 127.0.0.1:8081 -work-us 800 >"${OUTDIR}/b.log" 2>&1 &
B=$!
"${BIN}/cpu-burn" -workers "$(nproc)" >"${OUTDIR}/burn.log" 2>&1 &
BPID=$!
sleep 0.4
if ! kill -0 "${A}" 2>/dev/null || ! kill -0 "${B}" 2>/dev/null; then
  echo "server failed"; cat "${OUTDIR}/a.log" "${OUTDIR}/b.log"; exit 1
fi

run_pair() {
  local prefix="$1"
  "${BIN}/loadgen" -url http://127.0.0.1:8080/work -c "${CONC}" -d "${DUR}" -json \
    >"${OUTDIR}/${prefix}-a.json" &
  local pa=$!
  "${BIN}/loadgen" -url http://127.0.0.1:8081/work -c "${CONC}" -d "${DUR}" -json \
    >"${OUTDIR}/${prefix}-b.json" &
  local pb=$!
  wait "${pa}" "${pb}"
}

echo
echo "==> baseline: default Linux, both servers in parallel"
run_pair baseline

echo "==> load scx_kube"
"${BIN}/scx_kube" >"${OUTDIR}/scx.log" 2>&1 &
SCXPID=$!
sleep 1
if ! kill -0 "${SCXPID}" 2>/dev/null; then
  echo "scx_kube failed:"; cat "${OUTDIR}/scx.log"; exit 1
fi

echo "==> classify both servers latency, burner background"
"${BIN}/kubescx-agent" --tgid "${A}:latency" --tgid "${B}:latency" --tgid "${BPID}:background"

echo "==> scx_kube: both latency procs under contention"
run_pair scx

echo
echo "==> scx_kube counters (last lines)"
tail -n 5 "${OUTDIR}/scx.log" | tee "${OUTDIR}/counters.txt" || true

echo
echo "==> compare"
if command -v python3 >/dev/null 2>&1; then
  python3 "${ROOT}/hack/compare_lab.py" \
    default-a "${OUTDIR}/baseline-a.json" \
    default-b "${OUTDIR}/baseline-b.json" \
    scx-a "${OUTDIR}/scx-a.json" \
    scx-b "${OUTDIR}/scx-b.json"
  echo
  echo "Read it this way:"
  echo "- scx-a and scx-b p99 should both beat default if the first lab holds."
  echo "- If scx-a and scx-b p99 differ by a lot, the latency DSQ is bursty FIFO, not two reserved CPUs."
else
  echo "python3 not found; JSON is in ${OUTDIR}"
fi

echo "Ctrl-C unloads scx_kube."
sleep 2
