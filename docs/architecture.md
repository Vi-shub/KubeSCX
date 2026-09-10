# Architecture

scx_kube is a `sched_ext` policy. kubescx-agent is userspace. The kernel program does not parse Kubernetes YAML.

## Pieces

```
                    +------------------+
                    |  kubescx-agent   |
                    |  labels -> maps  |
                    +--------+---------+
                             | pin
                             v
                    /sys/fs/bpf/kubescx
                      cgroup_class
                      tgid_class
                             ^
                             | lookup
+------------+      +--------+---------+      +-----------+
| latency    |      |    scx_kube      |      | default   |
| server     | ---> |  BPF struct_ops  | <--- | ssh,      |
| (class 1)  |      |  three FIFO DSQs |      | loadgen   |
+------------+      +--------+---------+      +-----------+
                             |
                    +--------v---------+
                    | cpu-burn class 2 |
                    | background DSQ   |
                    +------------------+
```

## Queues

| Class | Who | When it runs |
|-------|-----|----------------|
| latency | Labeled API / TGID | First, if runnable |
| default | Unlabeled (sshd, kubelet, loadgen) | If latency is empty |
| background | Labeled batch / burner | Only if the first two are empty |

## What the BPF program does

1. `select_cpu`: idle CPUs may take latency or default immediately. **Background must not take `SCX_DSQ_LOCAL`.** That leak was loss 1.
2. `enqueue`: FIFO insert into the class DSQ. **No `SCX_KICK_PREEMPT` on every enqueue.** That was loss 2.
3. `dispatch`: pull latency, then default, then background.
4. `tick`: if latency work is waiting and the current task is not latency, end the slice.

## What the agent does

- Local lab: `--tgid PID:latency`
- Kubernetes: Pod label `scheduling.ebpf.io/class` to cgroup inode
- Dry-run prints the mapping without BPF

Classification stays in userspace on purpose. Wrong inode means the task stays default, never silent background.

## Out of scope for this MVP

CRDs, kubectl plugins, adaptive phase detection, energy, AI, and upstreaming into `sched-ext/scx`. One policy, one harness, one teaching path.
