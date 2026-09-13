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

## Safety

`scx_kube` is system-wide. Use a throwaway VM or a node whose only job is this lab. Ctrl-C / kill the `scx_kube` pid unloads it. Watchdog is 10s. Reboot if it wedges.
