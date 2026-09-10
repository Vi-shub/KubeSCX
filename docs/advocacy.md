# Advocacy kit

Advocacy here means: more people can *run*, *repeat*, and *argue with* the experiment — not more stars, not a product launch.

The eBPF Foundation Community & Advocacy fellowship is built around education, labs, writing, and talks. This page is the checklist.

## Artifacts (what you publish)

| Artifact | Where | Status |
|----------|--------|--------|
| Reproducible lab | `hack/lab-local.sh` | Exists — this is the core |
| Four lessons | this site, Teaching path | Exists |
| Blog post 1 | [First P99 result](blog/first-p99-result.md) | Draft from the real table |
| Blog post 2 | after a second experiment or a meetup | Not yet — do not invent it |
| Talk (10–15 min) | meetup / eBPF Summit CFP | Outline below |
| Contributor path | GitHub issues labeled `good-first-lab` | Add when you push |

You do **not** need a custom marketing website. GitHub Pages + the repo is the website.

## Elevator pitch (20 seconds)

Kubernetes can mark a Pod as latency-sensitive. Linux still schedules threads. KubeSCX is a sched_ext scheduler plus a lab that maps that label onto CPU queues. We have a p99 win on one contended workload, and two published ways to make p99 worse.

## What never to post

- “KubeSCX makes Kubernetes 68% faster.”
- “We replace the Linux scheduler.”
- “Production-ready for clusters.”
- Graphs without the kernel version, the command, and the two failed policies.

## Where to post (in this order)

1. **The repo README** — one table, one safety warning, link to the lab.
2. **This docs site** (GitHub Pages) — teaching path + blog.
3. **eBPF / sched-ext Discord or Slack** — “here is a reproducer, here is a negative result, review welcome.”
4. **A short LinkedIn or X thread** — use the 20-second pitch + the table + the VM warning.
5. **A local CNCF / SREcon / college meetup** — 12 minutes, live `lab-local` if the projector VM works; otherwise screenshots of the table and counters.
6. **eBPF Summit / LPC** — only after a second workload or a k8s-node run. One lab is a blog; two is a talk.

Do the in-community technical channels before the social ones. Advocacy that the scx people cannot reproduce is just marketing.

## 12-minute talk outline

1. **(1 min)** Kubernetes QoS vs Linux tasks — the gap.
2. **(2 min)** What `sched_ext` is. You will not explain the verifier.
3. **(2 min)** Policy: three queues. Unlabeled = default.
4. **(3 min)** The two failures (LOCAL bypass, kick storm) with the bad p99 numbers.
5. **(2 min)** The winning table and the counter line (`kick=528` not millions).
6. **(2 min)** “Run `bash hack/lab-local.sh` on a 6.13+ VM. Tell me when it loses.”

Leave two minutes for “does this starve kubelet?” (no: kubelet is unlabeled, default queue, ahead of background).

## Teaching eBPF without a 12-week course

Do not start with “what is a map.” Start with a system they know (a Pod), one hook they can feel (`sched_ext` load), and one number (p99). Then add maps, then kfuncs.

The four lessons on this site are the course. Extra tutorials (dispatch queues, writing your first scheduler from scratch) come after people have run the lab once.

## Fellowship-shaped metrics (targets, not promises)

- People who complete lab 3 and paste a table (even a loss)
- Issues/PRs that change policy or the harness
- One public writeup you did not have to ghost-write
- One workshop or meetup where someone else drives the VM

Vanity: GitHub stars, “100+ learners.” Skip those in any application.

## Next advocacy actions (this week)

1. Push this docs tree and enable GitHub Pages.
2. Publish blog post 1 as-is (caveats included).
3. Open 3 issues: `docs: add ARM lab notes`, `good-first-lab: print cgroup id in agent`, `experiment: two latency processes`.
4. Post the table + failed policies in the sched-ext community. Ask what baseline they want besides default EEVDF (`scx_simple`, `scx_lavd`).
