#!/usr/bin/env python3
"""Patch scx_kube.bpf.c on the VM: drop enqueue preempt-kick, add tick yield."""
import re
from pathlib import Path

bpf = Path("scheduler/scx_kube.bpf.c")
hdr = Path("scheduler/include/scx_kube.bpf.h")
t = bpf.read_text()

# Remove the enqueue kick block, whatever the whitespace.
kick_re = re.compile(
    r"\n[ \t]*if \(class == KUBE_CLASS_LATENCY\) \{.*?"
    r"scx_bpf_kick_cpu\(.*?\).*?stat_inc\(KUBE_STAT_KICK\);.*?\n[ \t]*\}",
    re.S,
)
t2, n = kick_re.subn("\n", t, count=1)
if n:
    print("removed enqueue SCX_KICK_PREEMPT")
    t = t2
elif "scx_bpf_kick_cpu" in t:
    raise SystemExit("kick still present but regex did not match; print enqueue and stop")
else:
    print("enqueue kick already gone")

TICK = r'''
void BPF_STRUCT_OPS(kube_tick, struct task_struct *p)
{
	struct kube_class_info *ci = lookup_class(p);
	u32 class;
	u64 dsq, slice;

	class_params(ci, &class, &dsq, &slice);
	if (class == KUBE_CLASS_LATENCY)
		return;
	if (bpf_ksym_exists(scx_bpf_dsq_nr_queued) &&
	    scx_bpf_dsq_nr_queued(KUBE_DSQ_LATENCY) > 0) {
		p->scx.slice = 0;
		stat_inc(KUBE_STAT_KICK);
	}
}
'''

if "kube_tick" not in t:
    t = t.replace(
        "void BPF_STRUCT_OPS(kube_dispatch",
        TICK + "\nvoid BPF_STRUCT_OPS(kube_dispatch",
        1,
    )
    print("inserted kube_tick")
else:
    print("kube_tick already present")

if ".tick" not in t:
    t = re.sub(
        r"(\.dispatch\s*=\s*\(void \*\)kube_dispatch,)",
        r"\1\n\t.tick\t\t\t= (void *)kube_tick,",
        t,
        count=1,
    )
    print("wired .tick in kube_ops")
else:
    print(".tick already wired")

bpf.write_text(t)

h = hdr.read_text()
if "scx_bpf_dsq_nr_queued" not in h:
    h = h.replace(
        "s32 scx_bpf_task_cpu(const struct task_struct *p) __ksym;",
        "s32 scx_bpf_task_cpu(const struct task_struct *p) __ksym;\n"
        "s32 scx_bpf_dsq_nr_queued(u64 dsq_id) __ksym __weak;",
        1,
    )
    hdr.write_text(h)
    print("declared scx_bpf_dsq_nr_queued")
else:
    print("nr_queued already declared")

print("done")
