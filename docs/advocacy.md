# Advocacy kit

Advocacy means more people can run, repeat, and argue with the experiment. Not more stars. Not a product launch.

The eBPF Foundation Community and Advocacy fellowship is built around education, labs, writing, and talks. This page is the checklist.

## Host the site on GitHub Pages

Do not buy a domain for the proposal. The dedicated website **is** this MkDocs site, served at [https://vi-shub.github.io/KubeSCX/](https://vi-shub.github.io/KubeSCX/).

In the GitHub repo: **Settings → Pages → Source: GitHub Actions**. After a push to `main`, the workflow builds `mkdocs.yml`.

A custom domain is optional later. It does not make the fellowship application stronger.

## Artifacts

| Artifact | Where | Status |
|----------|--------|--------|
| Reproducible lab | `hack/lab-local.sh` | Exists. This is the core. |
| Four lessons | Teaching path | Exists |
| Blog post 1 | [First P99 result](blog/first-p99-result.md) | Written from the real table |
| Blog post 2 | After a second experiment or a meetup | Not yet. Do not invent it. |
| Talk (10 to 15 min) | Meetup / eBPF Summit CFP | Outline below |
| Contributor path | GitHub issues | Add when you push |

## Elevator pitch (20 seconds)

Kubernetes can mark a Pod as latency-sensitive. Linux still schedules threads. KubeSCX is a sched_ext scheduler plus a lab that maps that label onto CPU queues. We have a p99 win on one contended workload, and two published ways to make p99 worse.

## What never to post

- "KubeSCX makes Kubernetes 68% faster."
- "We replace the Linux scheduler."
- "Production-ready for clusters."
- Graphs without the kernel version, the command, and the two failed policies.

## Where to post (in this order)

1. The repo README: one table, one safety warning, link to the lab.
2. This docs site (GitHub Pages): teaching path and blog.
3. eBPF / sched-ext Discord or Slack: reproducer, negative result, review welcome.
4. A short LinkedIn or X thread: 20-second pitch, the table, the VM warning.
5. A local CNCF or college meetup: 12 minutes. Live `lab-local` if the VM works. Otherwise the table and counters.
6. eBPF Summit / LPC: only after a second workload or a k8s-node run. One lab is a blog. Two is a talk.

Do in-community technical channels before social posts. Advocacy the scx people cannot reproduce is just marketing.

## 12-minute talk outline

1. (1 min) Kubernetes QoS vs Linux tasks. The gap.
2. (2 min) What `sched_ext` is. Skip the verifier deep dive.
3. (2 min) Policy: three queues. Unlabeled equals default.
4. (3 min) The two failures (LOCAL bypass, kick storm) with the bad p99 numbers.
5. (2 min) The winning table and the counter line (`kick=528`, not millions).
6. (2 min) Run `bash hack/lab-local.sh` on a 6.13+ VM. Tell me when it loses.

Leave time for "does this starve kubelet?" (No. kubelet is unlabeled, default queue, ahead of background.)

## Teaching eBPF without a 12-week course

Do not start with "what is a map." Start with a system they know (a Pod), one hook they can feel (`sched_ext` load), and one number (p99). Then maps. Then kfuncs.

The four lessons on this site are the course.

## Targets (not promises)

- People who complete lab 3 and paste a table (even a loss)
- Issues and PRs on the harness
- One public writeup you did not have to ghost-write
- One workshop or meetup where someone else drives the VM

Skip vanity star counts in any application.

## This week

1. Push docs and the working scheduler. Enable GitHub Pages.
2. Keep blog post 1 as-is (caveats included).
3. Open issues: ARM lab notes, print cgroup id in agent, two latency processes.
4. Post the table and failed policies in the sched-ext community. Ask which extra baseline they want (`scx_simple`, `scx_lavd`).
