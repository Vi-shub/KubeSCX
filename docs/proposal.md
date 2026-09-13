# Application copy (paste into the form)

Deadline: 11 September 2026.
Apply: https://ebpf.foundation/funding-opportunities/community-advocacy-fellowship-program/

Fill your legal name, email, country, and age yourself. Paste the rest. Do not attach the old 23-page concept PDF.

## Links

- Code: https://github.com/Vi-shub/KubeSCX
- Teaching site: https://vi-shub.github.io/KubeSCX/
- First writeup: https://vi-shub.github.io/KubeSCX/blog/first-p99-result/
- Lab: `bash hack/lab-local.sh` in that repo

## Project title

KubeSCX: teaching Kubernetes-aware CPU scheduling with eBPF and sched_ext

## Short summary (if the form asks for 2 to 4 sentences)

Kubernetes can mark a Pod as latency-sensitive. Linux still schedules threads. KubeSCX is an open-source sched_ext scheduler plus a teaching lab that maps that class onto three CPU queues (latency, default, background) and measures p99 under contention. The work already exists: a public repo, a VM lab, documented failures, and a teaching site. I am applying so I can spend six months making that path reproducible and teachable for cloud-native engineers, not so I can invent a product.

## What are you building?

KubeSCX is a public experiment at the gap between Kubernetes workload intent and the Linux CPU scheduler.

I built a `sched_ext` policy (`scx_kube`) with three FIFO dispatch queues: latency, then default, then background. A small userspace agent maps a process TGID or a Pod label (`scheduling.ebpf.io/class`) into pinned BPF maps. Unlabeled tasks stay default, so sshd and kubelet are not treated as batch. The kernel program does not parse YAML.

This is not a replacement for kube-scheduler, EEVDF, or `sched-ext/scx`. kube-scheduler still places Pods on nodes. scx_kube decides which threads run on a CPU after the Pod is already there.

The community half is the point of this fellowship. Most eBPF tutorials attach a probe and print a number. This one is the scheduler: you load it on a VM, classify two processes, measure p99, and read enqueue/dispatch/kick counters. Four lessons, a lab script, and a first blog post are already public.

I already measured the idea on Linux 7.0.0-30-generic, same node, 15s, 8 clients, 800µs CPU per request versus a full-machine burner:

| scheduler | p50 | p95 | p99 | p99.9 | rps |
|-----------|-----|-----|-----|-------|-----|
| default Linux | 4.08 ms | 15.08 ms | 22.44 ms | 34.83 ms | 1409 |
| scx_kube | 3.02 ms | 5.92 ms | 7.27 ms | 10.50 ms | 2388 |

p99 fell about 68% and throughput rose. Two earlier policies made p99 worse (idle LOCAL bypass ~699 ms; `SCX_KICK_PREEMPT` on every enqueue, ~6.4 million kicks in 15s, p99 ~423 ms). Those losses are documented on purpose. This is one workload on one kernel, not "Kubernetes is 68% faster."

## Who will benefit?

- Kubernetes and platform engineers who treat the Linux scheduler as a black box. They already have QoS and labels. Those labels do not become a sched_ext policy unless someone teaches the path.
- People learning eBPF who want a decision in the kernel, not another packet counter.
- The sched_ext community, who get a small, reviewable policy plus a harness that publishes negative results instead of only a win table.

I am in India. A VM-based lab and a GitHub Pages teaching site are the right access model. I am not proposing a custom domain or a product landing page.

## Why is this needed by the eBPF community?

eBPF is visible in networking and observability. Programmable scheduling (`sched_ext`) is newer and still mostly a kernel-specialist topic. Cloud-native developers can label a Pod. They cannot currently take a one-command path from that label to a CPU queue, a counter line, and an honest p99 table.

If the community only teaches "attach a probe, export a metric," we train observers. KubeSCX teaches a verified BPF program that changes what runs, with a watchdog, Ctrl-C unload, and documented ways to get it wrong. That is the kind of education this fellowship funds: tutorials, example code, labs, and talks, built on a real artifact.

## Existing track record (code, content, community)

I am not paid to work on eBPF full time.

The track record for this application is KubeSCX itself, already public:

- BPF scheduler and userspace loader (`scheduler/scx_kube.bpf.c`)
- Agent: TGID and cgroup class maps (`cmd/kubescx-agent`)
- Reproducible mixed-workload lab (`hack/lab-local.sh`)
- Teaching site with four lessons, architecture, results, and a 12-minute talk outline
- First public writeup of the Linux 7.0 table and the two failed policies

I built the scheduler, broke it twice, published the losses, then published the win. That is the contribution I am asking the fellowship to extend.

## What I will do in six months

I will keep one scheduler family and one primary question: does workload class at dispatch time improve tail latency under contention, and can someone else reproduce that, including the losses?

| Month | Technical | Community |
|-------|-----------|-----------|
| 1 | Repeat `lab-local` on 6.13 and 7.x. Document supported kernels and the VM warning. | Publish blog 1 (already drafted from the real table). Open lab-result issues. First written Q&A. |
| 2 | Second workload on the same node (two latency processes). Keep losses public. | Contributor guide used in anger. Lab issue backlog. |
| 3 | Kubernetes node path: Pod label to cgroup inode on k3s. Same p99 harness. | Meetup or workshop notes. 12-minute talk given at least once (live lab or the table). |
| 4 | Fairness / overhead counters so we can see whether background was exiled. Optional `scx_simple` baseline. | Blog 2: k8s mapping or second workload, with counters. |
| 5 | Pin kernel versions, cleaner errors if `sched_ext` is missing, 5 to 8 short labs. | Office hours or async help. Good-first issues on the lab, not "implement CFS." |
| 6 | If maintainers want it, a small example or doc toward `sched-ext/scx`. Otherwise freeze the MVP and write the end-of-fellowship post. | Roadmap beyond the grant. |

Fellowship-required deliverables I will hit:

- Two public blog posts
- All code open source (already GPL-2.0 scheduler, Apache-2.0 tools)
- All teaching material public (GitHub Pages)
- Monthly progress that can be shown as tables and labs, not star counts

## How I will measure impact

- Lab tables pasted by other people (wins and losses), with kernel version and the `enq`/`disp`/`kick` line
- Issues and PRs on the harness
- People who finish lesson 3 (`bash hack/lab-local.sh`) or can explain why their kernel cannot
- One workshop or meetup where someone else drives the VM
- Not GitHub stars

## What I will not promise

- Replacing kube-scheduler or EEVDF
- A universal or AI scheduler
- Production SLOs on other people's clusters
- "Kubernetes becomes 68% faster"

## One-sentence thesis (if the form has a goal field)

I will investigate whether Kubernetes workload class plus a sched_ext dispatch policy can improve Linux CPU tail latency under contention, and I will build a lab and writing path so cloud-native developers can reproduce, fail, and extend it.

## Why Community and Advocacy (not a research grant)

The research grant is for faculty. This work is a public scheduler plus education. The 68% figure is evidence that the lab is real. The two failures are evidence that the teaching is honest. That combination is the fellowship story.
