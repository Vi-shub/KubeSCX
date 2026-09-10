/* SPDX-License-Identifier: GPL-2.0 */
#ifndef SCX_KUBE_BPF_H
#define SCX_KUBE_BPF_H

/*
 * Minimal sched_ext kfunc wrappers used by scx_kube.
 * Generated vmlinux.h comes from the running kernel at build time.
 *
 * Kernel names have changed across 6.12 → 6.19. Weak ksyms plus
 * bpf_ksym_exists() pick the variant the loaded kernel actually has.
 */

#define BPF_NO_KFUNC_PROTOTYPES

#include "vmlinux.h"
#include <bpf/bpf_helpers.h>
#include <bpf/bpf_tracing.h>
#include <bpf/bpf_core_read.h>

#ifndef SCX_SLICE_DFL
#define SCX_SLICE_DFL (20ULL * 1000ULL * 1000ULL)
#endif

#ifndef SCX_DSQ_LOCAL
#define SCX_DSQ_FLAG_BUILTIN (1ULL << 63)
#define SCX_DSQ_GLOBAL (SCX_DSQ_FLAG_BUILTIN | 1)
#define SCX_DSQ_LOCAL (SCX_DSQ_FLAG_BUILTIN | 2)
#endif

#ifndef SCX_KICK_PREEMPT
#define SCX_KICK_IDLE (1ULL << 0)
#define SCX_KICK_PREEMPT (1ULL << 1)
#endif

#ifndef SCX_OPS_KEEP_BUILTIN_IDLE
#define SCX_OPS_KEEP_BUILTIN_IDLE (1ULL << 0)
#endif

#define BPF_STRUCT_OPS(name, args...) \
	SEC("struct_ops/" #name)      \
	BPF_PROG(name, ##args)

#define BPF_STRUCT_OPS_SLEEPABLE(name, args...) \
	SEC("struct_ops.s/" #name)              \
	BPF_PROG(name, ##args)

s32 scx_bpf_create_dsq(u64 dsq_id, s32 node) __ksym;

s32 scx_bpf_select_cpu_dfl(struct task_struct *p, s32 prev_cpu, u64 wake_flags,
			   bool *is_idle) __ksym;

void scx_bpf_kick_cpu(s32 cpu, u64 flags) __ksym;
s32 scx_bpf_task_cpu(const struct task_struct *p) __ksym;

bool scx_bpf_dsq_move_to_local___v2___compat(u64 dsq_id, u64 enq_flags) __ksym __weak;
bool scx_bpf_dsq_move_to_local___v1(u64 dsq_id) __ksym __weak;
bool scx_bpf_consume___old(u64 dsq_id) __ksym __weak;

bool scx_bpf_dsq_insert___v2___compat(struct task_struct *p, u64 dsq_id, u64 slice,
				      u64 enq_flags) __ksym __weak;
void scx_bpf_dsq_insert___v1(struct task_struct *p, u64 dsq_id, u64 slice,
			     u64 enq_flags) __ksym __weak;
void scx_bpf_dispatch___compat(struct task_struct *p, u64 dsq_id, u64 slice,
			       u64 enq_flags) __ksym __weak;

void scx_bpf_dsq_insert_vtime___compat(struct task_struct *p, u64 dsq_id, u64 slice,
				       u64 vtime, u64 enq_flags) __ksym __weak;
void scx_bpf_dispatch_vtime___compat(struct task_struct *p, u64 dsq_id, u64 slice,
				     u64 vtime, u64 enq_flags) __ksym __weak;

bool scx_bpf_task_set_dsq_vtime___new(struct task_struct *p, u64 vtime) __ksym __weak;

static __always_inline bool time_before64(u64 a, u64 b)
{
	return (s64)(a - b) < 0;
}

static __always_inline bool kube_dsq_move_to_local(u64 dsq_id)
{
	if (bpf_ksym_exists(scx_bpf_dsq_move_to_local___v2___compat))
		return scx_bpf_dsq_move_to_local___v2___compat(dsq_id, 0);
	if (bpf_ksym_exists(scx_bpf_dsq_move_to_local___v1))
		return scx_bpf_dsq_move_to_local___v1(dsq_id);
	if (bpf_ksym_exists(scx_bpf_consume___old))
		return scx_bpf_consume___old(dsq_id);
	return false;
}

static __always_inline bool kube_dsq_insert(struct task_struct *p, u64 dsq_id,
					    u64 slice, u64 enq_flags)
{
	if (bpf_ksym_exists(scx_bpf_dsq_insert___v2___compat))
		return scx_bpf_dsq_insert___v2___compat(p, dsq_id, slice, enq_flags);
	if (bpf_ksym_exists(scx_bpf_dsq_insert___v1)) {
		scx_bpf_dsq_insert___v1(p, dsq_id, slice, enq_flags);
		return true;
	}
	if (bpf_ksym_exists(scx_bpf_dispatch___compat)) {
		scx_bpf_dispatch___compat(p, dsq_id, slice, enq_flags);
		return true;
	}
	return false;
}

static __always_inline bool kube_dsq_insert_vtime(struct task_struct *p, u64 dsq_id,
						  u64 slice, u64 vtime, u64 enq_flags)
{
	if (bpf_ksym_exists(scx_bpf_dsq_insert_vtime___compat)) {
		scx_bpf_dsq_insert_vtime___compat(p, dsq_id, slice, vtime, enq_flags);
		return true;
	}
	if (bpf_ksym_exists(scx_bpf_dispatch_vtime___compat)) {
		scx_bpf_dispatch_vtime___compat(p, dsq_id, slice, vtime, enq_flags);
		return true;
	}
	return kube_dsq_insert(p, dsq_id, slice, enq_flags);
}

static __always_inline void kube_task_set_dsq_vtime(struct task_struct *p, u64 vtime)
{
	if (bpf_ksym_exists(scx_bpf_task_set_dsq_vtime___new))
		scx_bpf_task_set_dsq_vtime___new(p, vtime);
	else
		p->scx.dsq_vtime = vtime;
}

#endif /* SCX_KUBE_BPF_H */
