#!/usr/bin/env bash
# Single-node Kubernetes path. Dedicated box only.
# Measures payment-api with default Linux, then with scx_kube + agent.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
NS="${NS:-kubescx-lab}"
stamp="$(date -u +%Y%m%dT%H%M%SZ 2>/dev/null || date +%Y%m%d-%H%M%S)"
OUTDIR="${KUBESCX_OUT:-${ROOT}/out/k8s-${stamp}}"

if [[ "$(uname -s)" != "Linux" ]]; then
  echo "lab-k8s must run on the Linux node that has kubectl + sched_ext."
  exit 1
fi

if ! command -v kubectl >/dev/null 2>&1; then
  if [[ -x /usr/local/bin/k3s ]]; then
    export PATH="/usr/local/bin:${PATH}"
  fi
fi
if ! command -v kubectl >/dev/null 2>&1; then
  echo "FAIL: kubectl not found."
  echo "On this VM, as root:"
  echo "  curl -sfL https://get.k3s.io | sh -"
  echo "  export KUBECONFIG=/etc/rancher/k3s/k3s.yaml"
  echo "Then re-run: bash hack/lab-k8s.sh"
  exit 1
fi

if [[ -f /etc/rancher/k3s/k3s.yaml ]]; then
  export KUBECONFIG="${KUBECONFIG:-/etc/rancher/k3s/k3s.yaml}"
fi

if [[ "${EUID}" -ne 0 ]]; then
  echo "re-running with sudo"
  exec sudo --preserve-env=NS,KUBESCX_OUT,PATH,KUBECONFIG "${ROOT}/hack/lab-k8s.sh"
fi

bash "${ROOT}/hack/node-ready.sh"
mkdir -p "${OUTDIR}"
uname -a | tee "${OUTDIR}/uname.txt"

if [[ ! -x "${ROOT}/bin/latency-server" || ! -x "${ROOT}/bin/scx_kube" ]]; then
  make -C "${ROOT}" go scheduler
fi

# HostPath binaries cannot be overwritten while pods are running them.
if command -v kubectl >/dev/null 2>&1; then
  kubectl -n "${NS}" scale deploy/payment-api deploy/batch-job --replicas=0 2>/dev/null || true
  kubectl -n "${NS}" delete ds kubescx-agent --ignore-not-found 2>/dev/null || true
  kubectl -n "${NS}" delete job loadgen --ignore-not-found 2>/dev/null || true
  sleep 3
fi
make -C "${ROOT}" install
echo "binaries in /opt/kubescx" | tee -a "${OUTDIR}/meta.txt"

echo "==> apply lab manifests (no loadgen yet)"
kubectl apply -f "${ROOT}/deploy/lab/00-namespace.yaml"
kubectl apply -f "${ROOT}/deploy/lab/01-rbac.yaml"
kubectl apply -f "${ROOT}/deploy/lab/02-payment-api.yaml"
kubectl apply -f "${ROOT}/deploy/lab/03-batch-job.yaml"
kubectl rollout status -n "${NS}" deploy/payment-api --timeout=120s
kubectl rollout status -n "${NS}" deploy/batch-job --timeout=120s
sleep 3

run_loadgen() {
  local name="$1"
  kubectl delete job -n "${NS}" loadgen --ignore-not-found
  kubectl apply -f "${ROOT}/deploy/lab/05-loadgen.yaml"
  if ! kubectl wait -n "${NS}" --for=condition=complete job/loadgen --timeout=180s; then
    echo "loadgen job did not complete"
    kubectl logs -n "${NS}" job/loadgen || true
    return 1
  fi
  kubectl logs -n "${NS}" job/loadgen | tee "${OUTDIR}/${name}.txt"
  kubectl delete job -n "${NS}" loadgen --ignore-not-found
}

echo
echo "==> baseline: default Linux (scx_kube not loaded)"
run_loadgen baseline

echo
echo "==> load scx_kube"
if [[ -f /sys/kernel/sched_ext/state ]] && grep -qi enabled /sys/kernel/sched_ext/state; then
  echo "sched_ext already enabled; not starting a second scx_kube"
else
  /opt/kubescx/scx_kube >"${OUTDIR}/scx.log" 2>&1 &
  echo $! >"${OUTDIR}/scx.pid"
  sleep 1
  if ! kill -0 "$(cat "${OUTDIR}/scx.pid")" 2>/dev/null; then
    echo "scx_kube died:"; cat "${OUTDIR}/scx.log"; exit 1
  fi
fi

echo "==> agent + class sync"
kubectl apply -f "${ROOT}/deploy/lab/04-agent.yaml"
sleep 2
bash "${ROOT}/hack/sync-classes.sh" --dry-run | tee "${OUTDIR}/agent-dry-run.txt" || true
bash "${ROOT}/hack/sync-classes.sh" | tee "${OUTDIR}/agent-apply.txt"

echo
echo "==> scx_kube + labeled pods"
run_loadgen scx

if [[ -f "${OUTDIR}/scx.log" ]]; then
  tail -n 8 "${OUTDIR}/scx.log" | tee "${OUTDIR}/counters.txt" || true
fi

echo
echo "k8s lab done. results: ${OUTDIR}"
echo "Unload: kill the scx_kube pid in ${OUTDIR}/scx.pid (or Ctrl-C if you started it by hand)."
echo "This node is the experiment. Reboot it if it wedges."
