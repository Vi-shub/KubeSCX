# Pod label to CPU queue, on k3s

*15 September 2026. Linux 7.0.0-31-generic. Same box as the host lab, now with k3s.*

The host lab classifies PIDs. The Kubernetes question is whether a Pod label becomes a cgroup inode the BPF scheduler can see.

`hack/lab-k8s.sh` starts payment-api (`scheduling.ebpf.io/class=latency`) and a cpu-burn Pod (`background`), measures through the ClusterIP Service, then loads `scx_kube` and runs the agent.

The agent printed three cgroup paths per pod (systemd slice + cri-containerd scopes). Not zero. That is the mapping.

| scheduler | p50 | p95 | p99 | rps |
|-----------|-----|-----|-----|-----|
| default Linux | 6.94 ms | 146.5 ms | 325.1 ms | 266 |
| scx_kube | 3.39 ms | 6.04 ms | 7.54 ms | 2237 |

During the job: `enq lat` matched `disp lat`, kick ~2600, background still ran. After the loadgen Job exited, latency counts froze and `bg` kept climbing (k3s + burner). Expected.

This is not the 22 ms host table. Loadgen goes through a Service. k3s is on the node. Default p99 is ugly because the box is messier. scx still put the API at ~7.5 ms, same region as `lab-local`. Do not say Kubernetes is 97% faster.

Same day, before k3s: three 30s host soaks, p99 ~7.00 / 7.00 / 7.25 ms. Two latency processes shared the queue (7.55 / 7.52 ms) and almost starved background (`bg=4`).

Reproduce: `bash hack/lab-k8s.sh` on a dedicated Linux 6.13+ node. Kill `scx_kube` when you are done.
