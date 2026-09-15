#!/usr/bin/env bash
# Install scx_kube as a systemd service on THIS machine only.
# Not a cluster product. You must be able to reboot this box.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

if [[ "$(uname -s)" != "Linux" ]]; then
  echo "install-node is Linux-only"
  exit 1
fi
if [[ "${EUID}" -ne 0 ]]; then
  exec sudo --preserve-env=PATH "${ROOT}/hack/install-node.sh"
fi

bash "${ROOT}/hack/node-ready.sh"
make -C "${ROOT}" go scheduler install
install -d /usr/local/lib/systemd/system
install -m 0644 "${ROOT}/deploy/systemd/scx_kube.service" /usr/local/lib/systemd/system/
install -m 0644 "${ROOT}/deploy/systemd/kubescx-agent.service" /usr/local/lib/systemd/system/
systemctl daemon-reload

echo
echo "Installed. This box only. Start the scheduler:"
echo "  systemctl start scx_kube"
echo "  journalctl -u scx_kube -f"
echo "Stop (unload, back to default Linux):"
echo "  systemctl stop scx_kube"
echo "If you also run k3s and want the agent:"
echo "  systemctl start kubescx-agent"
echo "Remove: bash hack/uninstall-node.sh"
