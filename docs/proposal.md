# Fellowship proposal notes

Copy from this file into the Community and Advocacy application. This page is not in the public site nav. Keep the tone modest. You already have a working lab and a recorded result.

## Problem

Kubernetes exposes workload intent (priority, QoS, "this is latency-sensitive"). Linux schedules tasks using runqueues, wakeups, and cgroups. Cloud-native developers can label a Pod, but that label is not a `sched_ext` policy. Programmable scheduling stays a kernel-specialist topic.

## Proposal

KubeSCX is an open-source Kubernetes-aware CPU scheduling experiment using eBPF and Linux `sched_ext`, plus a teaching path for platform engineers.

Technical thesis: map workload class onto three FIFO dispatch queues (latency, default, background) and measure tail latency under contention.

Community thesis: make programmable scheduling runnable (`bash hack/lab-local.sh`) and explainable (counters, documented failures), not just a paper.

## What already exists (do not pitch as vapor)

- `scx_kube` BPF scheduler and userspace loader
- `kubescx-agent` (TGID and cgroup class maps)
- Mixed-workload harness and `hack/lab-local.sh`
- Four lessons, advocacy kit, and a first blog post
- A recorded Linux 7.0 result: p99 22.4 ms to 7.3 ms (about 68%), rps 1409 to 2388, after two published losing policies

## What I will do in six months

Keep the MVP small. One scheduler family, one primary objective (tail latency under contention), a stronger lab, and teaching.

| Month | Technical | Community |
|-------|-----------|-----------|
| 1 | Stabilize scx_kube on 6.13 and 7.x, document supported kernels | Publish blog 1, first office-hour or written Q&A |
| 2 | Repeat the lab 3+ times, second workload (I/O or two latency procs) | Lab issue backlog, contributor guide |
| 3 | Kubernetes node path: label to cgroup on k3s | Workshop notes / meetup talk |
| 4 | Fairness metrics for background, overhead counters | Blog 2: k8s mapping or second workload |
| 5 | Clean APIs, pin kernel versions, debug docs | 5 to 8 short labs (current 3 plus mapping and counters) |
| 6 | Upstream a small fix or example to scx/docs if it is wanted | Roadmap beyond the fellowship |

## Community deliverables

- Keep the public teaching site as the home for labs and writeups
- Two public blog posts (fellowship requirement)
- Hands-on labs a newcomer can finish on a VM
- Office hours or equivalent async help
- Good-first issues that change the lab or docs, not "implement CFS"

## How I will measure impact

- Lab tables pasted by other people (wins and losses)
- Issues and PRs on the harness
- Workshop or meetup attendees who ran `lab-local`
- Not GitHub stars

## What I will not promise

- Replacing kube-scheduler or EEVDF
- A universal or AI scheduler
- Production SLOs on other people's clusters
- "Kubernetes becomes 68% faster"

Prefer this sentence in the form:

> I will investigate whether Kubernetes workload class plus runtime dispatch policy can improve Linux CPU tail latency through sched_ext, and I will build a lab and writing path so cloud-native developers can reproduce, fail, and extend it.

## Why Community and Advocacy (not research grant)

The research grant is for faculty. This work is a public scheduler plus education. The 68% figure is evidence that the lab is real. The two failures are evidence that the teaching is honest. That combination is the fellowship story.
