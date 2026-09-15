# Dedicated node (not a production cluster)

KubeSCX can run as a systemd service on **one machine you can reboot**. That is the next step after the labs. It is not "production Kubernetes."

`scx_kube` is the CPU scheduler for the whole OS while it is started. Stop the service and Linux goes back to the default class. The 10s watchdog is a backup, not an SLO.

## Install on the VM

```bash
cd /root/KubeSCX
sed -i 's/\r$//' hack/*.sh
bash hack/install-node.sh
systemctl start scx_kube
journalctl -u scx_kube -f
```

You should see `enq` / `disp` / `kick` lines. Classify work the same as the lab (`kubescx-agent --tgid ...` or, with k3s, `systemctl start kubescx-agent`).

Stop:

```bash
systemctl stop scx_kube
cat /sys/kernel/sched_ext/state
```

That must say `disabled`. Remove units: `bash hack/uninstall-node.sh`.

## What would have to be true before a real prod node

- Hours of soak, not 15s, on more than one kernel
- A second baseline (`scx_simple` or `scx_lavd`), not only default Linux
- Images for the agent, not `hostPath` + alpine
- A rollback you have actually used (stop service / reboot)
- A written go/no-go: if `kick` is millions or p99 explodes, you do not leave it enabled
- Never enable this on a box you cannot reboot, and never on a multi-tenant cluster

The 1-in-16 background floor is **not** coming back. It made two-latency p99 worse than default. Batch starving when two latency apps fill the node is a known tradeoff of the winning policy.

## Do not

- `Restart=always` on `scx_kube` (a crash loop as the CPU scheduler is a bad day)
- Advertise this as a Cilium/Tetragon replacement
- Enable the unit on boot until you have lived with `systemctl start/stop` by hand
