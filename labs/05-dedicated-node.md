# Lab 5: Dedicated-node Kubernetes test

This is the 30-day "prod" target. One machine you can reboot. Not a shared cluster.

```bash
sed -i 's/\r$//' hack/*.sh
bash hack/node-ready.sh
sudo make install
bash hack/lab-k8s.sh
```

The script:

1. Installs binaries to `/opt/kubescx`
2. Starts payment-api (latency) and batch-job (background)
3. Runs loadgen on **default Linux**
4. Loads `scx_kube`, applies the agent, syncs labels
5. Runs loadgen again

Keep `out/k8s-*/`. If the agent dry-run shows `cgroups=0`, stop. The scheduler never saw the pod.

## Recorded (Linux 7.0.0-31-generic, k3s)

Agent printed 3 cgroup paths per pod (pod slice + cri-containerd scopes). Not zero.

| scheduler | p50 | p95 | p99 | rps |
|-----------|-----|-----|-----|-----|
| default Linux | 6.94 ms | 146.5 ms | 325.1 ms | 266 |
| scx_kube | 3.39 ms | 6.04 ms | 7.54 ms | 2237 |

Second pass: default p99 274 ms, scx 7.40 ms, rps 248 → 2253.

Default p99 is much worse than host `lab-local` because this path includes k3s, a Service, and a Pod burner. scx p99 landed at ~7.5 ms, same region as the host lab.

## Safety

`scx_kube` is system-wide. Use a throwaway VM or a node whose only job is this lab. Ctrl-C / kill the `scx_kube` pid unloads it. Watchdog is 10s. Reboot if it wedges.
