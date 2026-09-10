#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
NS="${NS:-kubescx-lab}"
NODE="${NODE_NAME:-$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)}"

if [[ ! -x "${ROOT}/bin/kubescx-agent" ]]; then
  make -C "${ROOT}" go
fi

kubectl get pods -A -o json | "${ROOT}/bin/kubescx-agent" \
  --from-json - \
  ${NODE:+--node-name "${NODE}"} \
  "$@"
