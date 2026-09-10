/* SPDX-License-Identifier: GPL-2.0 */
/*
 * scx_kube — Kubernetes-aware sched_ext scheduler (MVP)
 *
 * Policy: three FIFO dispatch queues.
 *   latency  -> always first
 *   default  -> unlabeled tasks (sshd, loadgen, kubelet)
 *   background -> only if the first two are empty
 *
 * Classification comes from userspace BPF maps (TGID / cgroup id).
 *
 * Important: do not insert background tasks into SCX_DSQ_LOCAL from
 * select_cpu. That idle fast-path lets burners grab every CPU and
 * bypass the latency queue — the first lab-local run showed that as
 * p99 exploding from ~23ms to ~700ms.
 */

#include "scx_kube.bpf.h"
#include "kubescx.h"

char _license[] SEC("license") = "GPL";

struct {
	__uint(type, BPF_MAP_TYPE_HASH);
	__uint(max_entries, 16384);
	__type(key, u64);
	__type(value, struct kube_class_info);
} cgroup_class SEC(".maps");

struct {
	__uint(type, BPF_MAP_TYPE_HASH);
	__uint(max_entries, 8192);
	__type(key, u32);
	__type(value, struct kube_class_info);
} tgid_class SEC(".maps");

struct {
	__uint(type, BPF_MAP_TYPE_PERCPU_ARRAY);
	__uint(max_entries, KUBE_STAT_MAX);
	__type(key, u32);
	__type(value, u64);
} stats SEC(".maps");

static __always_inline void stat_inc(u32 idx)
{
	u64 *cnt = bpf_map_lookup_elem(&stats, &idx);

	if (cnt)
		(*cnt)++;
}

static __always_inline u64 task_cgroup_id(struct task_struct *p)
{
	return BPF_CORE_READ(p, cgroups, dfl_cgrp, kn, id);
}

static __always_inline struct kube_class_info *lookup_class(struct task_struct *p)
{
	u32 tgid = BPF_CORE_READ(p, tgid);
	struct kube_class_info *ci;
	u64 cgid;

	ci = bpf_map_lookup_elem(&tgid_class, &tgid);
	if (ci)
		return ci;

	cgid = task_cgroup_id(p);
	if (!cgid)
		return NULL;
	return bpf_map_lookup_elem(&cgroup_class, &cgid);
}

static __always_inline void class_params(struct kube_class_info *ci, u32 *class,
					 u64 *dsq, u64 *slice)
{
	u32 c = KUBE_CLASS_DEFAULT;

	if (ci)
		c = ci->class;
	*class = c;

	switch (c) {
	case KUBE_CLASS_LATENCY:
		*dsq = KUBE_DSQ_LATENCY;
		*slice = 5ULL * 1000ULL * 1000ULL;
		break;
	case KUBE_CLASS_BACKGROUND:
		*dsq = KUBE_DSQ_BACKGROUND;
		*slice = 2ULL * 1000ULL * 1000ULL;
		break;
	default:
		*dsq = KUBE_DSQ_DEFAULT;
		*slice = SCX_SLICE_DFL;
		break;
	}
}

s32 BPF_STRUCT_OPS(kube_select_cpu, struct task_struct *p, s32 prev_cpu, u64 wake_flags)
{
	struct kube_class_info *ci = lookup_class(p);
	u32 class;
	u64 dsq, slice;
	bool is_idle = false;
	s32 cpu;

	class_params(ci, &class, &dsq, &slice);
	cpu = scx_bpf_select_cpu_dfl(p, prev_cpu, wake_flags, &is_idle);

	/*
	 * Only latency/default may take an idle CPU immediately.
	 * Background must go through enqueue so dispatch can prefer
	 * the latency queue.
	 */
	if (is_idle && class != KUBE_CLASS_BACKGROUND) {
		stat_inc(KUBE_STAT_SELECT_IDLE);
		kube_dsq_insert(p, SCX_DSQ_LOCAL, slice, 0);
	}
	return cpu;
}

void BPF_STRUCT_OPS(kube_enqueue, struct task_struct *p, u64 enq_flags)
{
	struct kube_class_info *ci = lookup_class(p);
	u32 class;
	u64 dsq, slice;

	class_params(ci, &class, &dsq, &slice);

	switch (class) {
	case KUBE_CLASS_LATENCY:
		stat_inc(KUBE_STAT_ENQ_LATENCY);
		break;
	case KUBE_CLASS_BACKGROUND:
		stat_inc(KUBE_STAT_ENQ_BACKGROUND);
		break;
	default:
		stat_inc(KUBE_STAT_ENQ_DEFAULT);
		break;
	}

	/* FIFO per class. Vtime is a later experiment, not the MVP. */
	kube_dsq_insert(p, dsq, slice, enq_flags);
}

void BPF_STRUCT_OPS(kube_tick, struct task_struct *p)
{
	struct kube_class_info *ci = lookup_class(p);
	u32 class;
	u64 dsq, slice;

	class_params(ci, &class, &dsq, &slice);
	if (class == KUBE_CLASS_LATENCY)
		return;
	/*
	 * If latency work is waiting, end this slice so dispatch can
	 * pick it. Do not SCX_KICK_PREEMPT on every enqueue — that
	 * created a 6.4M kick/15s storm and a 400ms p99.
	 */
	if (bpf_ksym_exists(scx_bpf_dsq_nr_queued) &&
	    scx_bpf_dsq_nr_queued(KUBE_DSQ_LATENCY) > 0) {
		p->scx.slice = 0;
		stat_inc(KUBE_STAT_KICK);
	}
}

void BPF_STRUCT_OPS(kube_dispatch, s32 cpu, struct task_struct *prev)
{
	(void)cpu;
	(void)prev;
	if (kube_dsq_move_to_local(KUBE_DSQ_LATENCY)) {
		stat_inc(KUBE_STAT_DISP_LATENCY);
		return;
	}
	if (kube_dsq_move_to_local(KUBE_DSQ_DEFAULT)) {
		stat_inc(KUBE_STAT_DISP_DEFAULT);
		return;
	}
	if (kube_dsq_move_to_local(KUBE_DSQ_BACKGROUND))
		stat_inc(KUBE_STAT_DISP_BACKGROUND);
}

s32 BPF_STRUCT_OPS_SLEEPABLE(kube_init)
{
	s32 ret;

	ret = scx_bpf_create_dsq(KUBE_DSQ_LATENCY, -1);
	if (ret) {
		bpf_printk("scx_kube: create latency DSQ failed %d", ret);
		return ret;
	}
	ret = scx_bpf_create_dsq(KUBE_DSQ_DEFAULT, -1);
	if (ret) {
		bpf_printk("scx_kube: create default DSQ failed %d", ret);
		return ret;
	}
	ret = scx_bpf_create_dsq(KUBE_DSQ_BACKGROUND, -1);
	if (ret) {
		bpf_printk("scx_kube: create background DSQ failed %d", ret);
		return ret;
	}
	return 0;
}

SEC(".struct_ops.link")
struct sched_ext_ops kube_ops = {
	.select_cpu		= (void *)kube_select_cpu,
	.enqueue		= (void *)kube_enqueue,
	.dispatch		= (void *)kube_dispatch,
	.tick			= (void *)kube_tick,
	.init			= (void *)kube_init,
	.flags			= SCX_OPS_KEEP_BUILTIN_IDLE | SCX_OPS_ENQ_LAST,
	.timeout_ms		= 10000,
	.name			= "scx_kube",
};
