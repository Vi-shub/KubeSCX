/* SPDX-License-Identifier: GPL-2.0 */
/*
 * Userspace loader for scx_kube.
 *
 * Loads the BPF scheduler, pins classification maps under
 * /sys/fs/bpf/kubescx, and prints enqueue/dispatch counters until SIGINT.
 */

#include <errno.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/stat.h>

#include <bpf/bpf.h>
#include <bpf/libbpf.h>

#include "kubescx.h"
#include "scx_kube.skel.h"

static volatile sig_atomic_t exiting;

static void on_signal(int sig)
{
	exiting = 1;
}

static int libbpf_print_fn(enum libbpf_print_level level, const char *fmt, va_list args)
{
	if (level == LIBBPF_DEBUG)
		return 0;
	return vfprintf(stderr, fmt, args);
}

static void read_stats(struct scx_kube_bpf *skel, unsigned long long *out)
{
	int ncpu = libbpf_num_possible_cpus();
	unsigned int idx;

	memset(out, 0, sizeof(*out) * KUBE_STAT_MAX);
	if (ncpu <= 0)
		return;

	for (idx = 0; idx < KUBE_STAT_MAX; idx++) {
		unsigned long long *percpu;
		int cpu, ret;

		percpu = calloc((size_t)ncpu, sizeof(*percpu));
		if (!percpu)
			return;
		ret = bpf_map_lookup_elem(bpf_map__fd(skel->maps.stats), &idx, percpu);
		if (ret == 0) {
			for (cpu = 0; cpu < ncpu; cpu++)
				out[idx] += percpu[cpu];
		}
		free(percpu);
	}
}

static int pin_one(struct bpf_map *map, const char *dir, const char *name)
{
	char path[256];
	int err;

	snprintf(path, sizeof(path), "%s/%s", dir, name);
	unlink(path);
	err = bpf_map__pin(map, path);
	if (err) {
		fprintf(stderr, "pin %s: %s\n", path, strerror(err < 0 ? -err : err));
		return -1;
	}
	return 0;
}

static int pin_maps(struct scx_kube_bpf *skel, const char *dir)
{
	if (mkdir(dir, 0700) && errno != EEXIST) {
		fprintf(stderr, "mkdir %s: %s\n", dir, strerror(errno));
		return -1;
	}

	if (pin_one(skel->maps.cgroup_class, dir, KUBESCX_MAP_CGROUP))
		return -1;
	if (pin_one(skel->maps.tgid_class, dir, KUBESCX_MAP_TGID))
		return -1;
	if (pin_one(skel->maps.stats, dir, KUBESCX_MAP_STATS))
		return -1;

	fprintf(stderr, "pinned maps at %s\n", dir);
	return 0;
}

int main(int argc, char **argv)
{
	const char *pin_dir = KUBESCX_PIN_DIR;
	struct scx_kube_bpf *skel = NULL;
	struct bpf_link *link = NULL;
	int err = 0;
	int i;

	for (i = 1; i < argc; i++) {
		if (!strcmp(argv[i], "--pin") && i + 1 < argc)
			pin_dir = argv[++i];
		else if (!strcmp(argv[i], "-h") || !strcmp(argv[i], "--help")) {
			fprintf(stderr,
				"Usage: %s [--pin DIR]\n"
				"  Load scx_kube and pin maps (default %s).\n"
				"  This replaces the CPU scheduler on the whole machine.\n"
				"  Ctrl-C unloads it and Linux falls back to the default class.\n",
				argv[0], KUBESCX_PIN_DIR);
			return 0;
		}
	}

	if (geteuid() != 0) {
		fprintf(stderr, "scx_kube must run as root\n");
		return 1;
	}

	libbpf_set_print(libbpf_print_fn);
	signal(SIGINT, on_signal);
	signal(SIGTERM, on_signal);

	skel = scx_kube_bpf__open();
	if (!skel) {
		fprintf(stderr, "failed to open BPF skeleton\n");
		return 1;
	}

	err = scx_kube_bpf__load(skel);
	if (err) {
		fprintf(stderr,
			"failed to load scx_kube (%d). Need Linux 6.13+ with CONFIG_SCHED_CLASS_EXT.\n"
			"Check: ls /sys/kernel/sched_ext  and  cat /sys/kernel/sched_ext/state\n",
			err);
		goto out;
	}

	if (pin_maps(skel, pin_dir)) {
		err = 1;
		goto out;
	}

	link = bpf_map__attach_struct_ops(skel->maps.kube_ops);
	if (!link) {
		fprintf(stderr,
			"failed to attach sched_ext ops: %s\n"
			"Is another scx scheduler already loaded?\n",
			strerror(errno));
		err = 1;
		goto out;
	}

	fprintf(stderr, "scx_kube loaded. Classify tasks with kubescx-agent, then Ctrl-C to unload.\n");

	while (!exiting) {
		unsigned long long st[KUBE_STAT_MAX];

		read_stats(skel, st);
		printf("enq lat=%llu def=%llu bg=%llu  disp lat=%llu def=%llu bg=%llu  idle=%llu kick=%llu\n",
		       st[KUBE_STAT_ENQ_LATENCY], st[KUBE_STAT_ENQ_DEFAULT], st[KUBE_STAT_ENQ_BACKGROUND],
		       st[KUBE_STAT_DISP_LATENCY], st[KUBE_STAT_DISP_DEFAULT], st[KUBE_STAT_DISP_BACKGROUND],
		       st[KUBE_STAT_SELECT_IDLE], st[KUBE_STAT_KICK]);
		fflush(stdout);
		sleep(1);
	}

out:
	bpf_link__destroy(link);
	if (skel) {
		char path[256];

		snprintf(path, sizeof(path), "%s/%s", pin_dir, KUBESCX_MAP_CGROUP);
		unlink(path);
		snprintf(path, sizeof(path), "%s/%s", pin_dir, KUBESCX_MAP_TGID);
		unlink(path);
		snprintf(path, sizeof(path), "%s/%s", pin_dir, KUBESCX_MAP_STATS);
		unlink(path);
	}
	scx_kube_bpf__destroy(skel);
	return err ? 1 : 0;
}
