# FAQ

## Can I run this on WSL or Docker?

Usually no. You need Linux **6.12+** with `CONFIG_SCHED_CLASS_EXT`. WSL2 5.15 cannot load scx_kube. Docker uses the host kernel and cannot replace the scheduler inside a container. Use a VM.

## Will this replace kube-scheduler?

No. kube-scheduler places Pods on nodes. scx_kube decides which threads run on a CPU after the Pod is already there.

## Will this starve sshd or kubelet?

Unlabeled tasks use the **default** queue, which is ahead of background. Do not classify host agents as background.

## Is the 68% number guaranteed?

No. It is one recorded run on Linux 7.0 with this harness. Two policies on the same harness lost badly. Publish the command and the counters with any table.

## Why eBPF and not a userspace controller?

Scheduling decisions happen next to wakeups and runqueues. A controller that reads Prometheus and patches a CRD is the wrong timescale. `sched_ext` is the kernel API. eBPF is how the policy is loaded with a watchdog fallback.

## What if the scheduler wedges the VM?

Wait for the 10s watchdog or reboot the VM. Do not load scx_kube on a machine you cannot afford to stall.

## How do I contribute?

See [CONTRIBUTING.md](https://github.com/Vi-shub/KubeSCX/blob/main/CONTRIBUTING.md). Useful first work: extra lab notes, a second recorded table, ARM, a clearer error if `sched_ext` is missing.
