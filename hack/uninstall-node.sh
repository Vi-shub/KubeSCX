#!/usr/bin/env bash
set -euo pipefail
if [[ "${EUID}" -ne 0 ]]; then
  exec sudo "$0" "$@"
fi
systemctl stop kubescx-agent 2>/dev/null || true
systemctl stop scx_kube 2>/dev/null || true
systemctl disable kubescx-agent 2>/dev/null || true
systemctl disable scx_kube 2>/dev/null || true
rm -f /usr/local/lib/systemd/system/scx_kube.service
rm -f /usr/local/lib/systemd/system/kubescx-agent.service
systemctl daemon-reload
echo "services stopped. default scheduler should be back:"
cat /sys/kernel/sched_ext/state 2>/dev/null || true
