#!/usr/bin/env bash
# Repeat lab-local several times. This is the week-1 maturity check.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RUNS="${RUNS:-3}"
DUR="${DUR:-30s}"
CONC="${CONC:-8}"
stamp="$(date -u +%Y%m%dT%H%M%SZ 2>/dev/null || date +%Y%m%d-%H%M%S)"
BASE="${KUBESCX_SOAK:-${ROOT}/out/soak-${stamp}}"

if [[ "$(uname -s)" != "Linux" ]]; then
  echo "lab-soak must run on Linux."
  exit 1
fi

mkdir -p "${BASE}"
echo "soak runs=${RUNS} dur=${DUR} conc=${CONC}" | tee "${BASE}/meta.txt"
uname -a | tee "${BASE}/uname.txt"

for i in $(seq 1 "${RUNS}"); do
  echo
  echo "======== soak run ${i}/${RUNS} ========"
  KUBESCX_OUT="${BASE}/run-${i}" DUR="${DUR}" CONC="${CONC}" \
    bash "${ROOT}/hack/lab-local.sh"
done

echo
echo "soak finished. folders:"
ls -1 "${BASE}"
echo "Read each run-*/ baseline.json and scx.json. If p99 jumps around, you do not have a stable win yet."
