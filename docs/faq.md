# FAQ

## Do I need a custom domain?

No. Host the teaching site on **GitHub Pages**. That is the dedicated website: `https://vi-shub.github.io/KubeSCX/`.

In the repo: **Settings → Pages → Source: GitHub Actions** (not "Deploy from a branch"). Then run the **GitHub Pages** workflow once.

If the URL shows the README (file table, clone commands), Pages is publishing the repo root. That is the wrong source. After Actions deploy you should see a docs theme with a left nav and a green "Measured on Linux 7.0" box.

A custom domain is optional later. It does not make the fellowship application stronger.

## Can I run this on WSL or Docker?

Usually no. You need Linux **6.12+** with `CONFIG_SCHED_CLASS_EXT`. WSL2 5.15 cannot load scx_kube. Docker uses the host kernel and cannot replace the scheduler inside a container anyway. Use a VM.

## Will this replace kube-scheduler?

No. kube-scheduler places Pods on nodes. scx_kube decides which *threads* run on a CPU after the Pod is already there.

## Will this starve sshd or kubelet?

Unlabeled tasks use the **default** queue, which is ahead of background. Do not classify host agents as background.

## Is the 68% number guaranteed?

No. It is one recorded run on Linux 7.0 with this harness. Two policies on the same harness lost badly. Always publish the command and the counters.

## Why eBPF?

Scheduling decisions happen next to wakeups and runqueues. A userspace controller reading Prometheus is the wrong timescale. `sched_ext` is the kernel API. eBPF is how the policy is loaded safely.

## What if the scheduler wedges the VM?

Wait for the 10s watchdog or reboot the VM. Do not load scx_kube on a laptop you cannot afford to stall.

## How do I contribute?

See [CONTRIBUTING.md](https://github.com/Vi-shub/KubeSCX/blob/main/CONTRIBUTING.md). Useful first work: extra lab notes, a second workload, ARM, a cleaner error if `sched_ext` is missing.
