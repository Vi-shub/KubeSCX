/* SPDX-License-Identifier: GPL-2.0 */
/*
 * scx_kube — Kubernetes-aware sched_ext scheduler (MVP)
 *
 * Policy: three dispatch queues. Latency-sensitive tasks always run before
 * default tasks, which run before background tasks. Within a queue, tasks
 * are ordered by weighted vtime.
 *
 * Classification is not guessed in the kernel. Userspace (kubescx-agent)
 * writes cgroup ids and/or TGIDs into pinned BPF maps. Unclassified tasks
 * stay in the default queue so sshd, kubelet, and other host services are
 * not treated as batch work.
 */

#include "scx_kube.bpf.h"
#include "kubescx.h"

char _license[] SEC("license") = "GPL";

static u64 vtime_now;

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
					 u32 *weight, u64 *dsq, u64 *slice)
{
	u32 c = KUBE_CLASS_DEFAULT;
	u32 w = KUBE_WEIGHT_DEFAULT;

	if (ci) {
		c = ci->class;
		if (ci->weight)
			w = ci->weight;
	}

	*class = c;
	*weight = w;

	switch (c) {
	case KUBE_CLASS_LATENCY:
		*dsq = KUBE_DSQ_LATENCY;
		*slice = 8ULL * 1000ULL * 1000ULL; /* 8ms: return to latency queue often */
		if (w == KUBE_WEIGHT_DEFAULT)
			*weight = KUBE_WEIGHT_LATENCY;
		break;
	case KUBE_CLASS_BACKGROUND:
		*dsq = KUBE_DSQ_BACKGROUND;
		*slice = 4ULL * 1000ULL * 1000ULL; /* 4ms: yield so latency can preempt */
		if (w == KUBE_WEIGHT_DEFAULT)
			*weight = KUBE_WEIGHT_BACKGROUND;
		break;
	default:
		*dsq = KUBE_DSQ_DEFAULT;
		*slice = SCX_SLICE_DFL;
		break;
	}
}

s32 BPF_STRUCT_OPS(kube_select_cpu, struct task_struct *p, s32 prev_cpu, u64 wake_flags)
{
	bool is_idle = false;
	s32 cpu;

	cpu = scx_bpf_select_cpu_dfl(p, prev_cpu, wake_flags, &is_idle);
	if (is_idle) {
		stat_inc(KUBE_STAT_SELECT_IDLE);
		kube_dsq_insert(p, SCX_DSQ_LOCAL, SCX_SLICE_DFL, 0);
	}
	return cpu;
}

void BPF_STRUCT_OPS(kube_enqueue, struct task_struct *p, u64 enq_flags)
{
	struct kube_class_info *ci = lookup_class(p);
	u32 class, weight;
	u64 dsq, slice, vtime;

	class_params(ci, &class, &weight, &dsq, &slice);

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

	vtime = p->scx.dsq_vtime;
	if (time_before64(vtime, vtime_now - slice))
		vtime = vtime_now - slice;

	kube_dsq_insert_vtime(p, dsq, slice, vtime, enq_flags);

	if (class == KUBE_CLASS_LATENCY) {
		s32 cpu = scx_bpf_task_cpu(p);

		scx_bpf_kick_cpu(cpu, SCX_KICK_PREEMPT);
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

void BPF_STRUCT_OPS(kube_running, struct task_struct *p)
{
	if (time_before64(vtime_now, p->scx.dsq_vtime))
		vtime_now = p->scx.dsq_vtime;
}

void BPF_STRUCT_OPS(kube_stopping, struct task_struct *p, bool runnable)
{
	struct kube_class_info *ci = lookup_class(p);
	u32 class, weight;
	u64 dsq, slice, used, delta;

	(void)runnable;

	class_params(ci, &class, &weight, &dsq, &slice);
	if (weight == 0)
		weight = 100;

	used = slice - p->scx.slice;
	delta = used * 100 / weight;
	kube_task_set_dsq_vtime(p, p->scx.dsq_vtime + delta);
}

void BPF_STRUCT_OPS(kube_enable, struct task_struct *p)
{
	kube_task_set_dsq_vtime(p, vtime_now);
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
	.running		= (void *)kube_running,
	.stopping		= (void *)kube_stopping,
	.enable			= (void *)kube_enable,
	.init			= (void *)kube_init,
	.flags			= SCX_OPS_KEEP_BUILTIN_IDLE,
	.timeout_ms		= 10000,
	.name			= "scx_kube",
};
