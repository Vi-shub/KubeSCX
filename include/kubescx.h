/* SPDX-License-Identifier: GPL-2.0 OR Apache-2.0 */
#ifndef KUBESCX_H
#define KUBESCX_H

/*
 * Shared ABI between the BPF scheduler and userspace.
 * Keep cmd/kubescx-agent and include/kubescx.h in sync.
 */

#ifndef __VMLINUX_H__
#include <linux/types.h>
#endif

#define KUBESCX_PIN_DIR "/sys/fs/bpf/kubescx"
#define KUBESCX_MAP_CGROUP "cgroup_class"
#define KUBESCX_MAP_TGID "tgid_class"
#define KUBESCX_MAP_STATS "stats"

#define KUBESCX_LABEL_CLASS "scheduling.ebpf.io/class"

#define KUBE_CLASS_DEFAULT 0
#define KUBE_CLASS_LATENCY 1
#define KUBE_CLASS_BACKGROUND 2

#define KUBE_DSQ_LATENCY 0
#define KUBE_DSQ_DEFAULT 1
#define KUBE_DSQ_BACKGROUND 2

#define KUBE_STAT_ENQ_LATENCY 0
#define KUBE_STAT_ENQ_DEFAULT 1
#define KUBE_STAT_ENQ_BACKGROUND 2
#define KUBE_STAT_DISP_LATENCY 3
#define KUBE_STAT_DISP_DEFAULT 4
#define KUBE_STAT_DISP_BACKGROUND 5
#define KUBE_STAT_SELECT_IDLE 6
#define KUBE_STAT_KICK 7
#define KUBE_STAT_MAX 8

#define KUBE_WEIGHT_LATENCY 500
#define KUBE_WEIGHT_DEFAULT 100
#define KUBE_WEIGHT_BACKGROUND 25

struct kube_class_info {
	__u32 class;
	__u32 weight;
};

#endif /* KUBESCX_H */
