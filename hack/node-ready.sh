#!/usr/bin/env bash
# Is this machine allowed to load scx_kube? (dedicated node only)
set -euo pipefail

echo "KubeSCX node-ready"
echo "  kernel: $(uname -s) $(uname -r)"

fail=0
if [[ "$(uname -s)" != "Linux" ]]; then
  echo "FAIL: not Linux"
  exit 1
fi

if [[ ! -e /sys/kernel/btf/vmlinux ]]; then
  echo "FAIL: no BTF"
  fail=1
else
  echo "OK  BTF"
fi

if [[ -d /sys/kernel/sched_ext ]]; then
  echo "OK  sched_ext"
  if [[ -f /sys/kernel/sched_ext/state ]]; then
    echo "    state=$(cat /sys/kernel/sched_ext/state)"
  fi
else
  echo "FAIL: no /sys/kernel/sched_ext"
  fail=1
fi

if [[ -d /sys/fs/bpf/kubescx ]]; then
  echo "OK  pin dir /sys/fs/bpf/kubescx (scx_kube is probably loaded)"
  ls /sys/fs/bpf/kubescx 2>/dev/null || true
else
  echo "    pin dir not present (scheduler not loaded yet; that is ok before lab-k8s)"
fi

if [[ "${EUID}" -eq 0 ]]; then
  echo "OK  running as root"
else
  echo "NOTE: load/unload needs root (scripts will sudo)"
fi

if [[ $fail -ne 0 ]]; then
  echo "node is not ready"
  exit 1
fi
echo "node can run the dedicated-box test"
