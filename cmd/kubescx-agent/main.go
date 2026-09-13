package main

import (
	"flag"
	"fmt"
	"io"
	"os"
	"strconv"
	"strings"
	"time"

	"kubescx/internal/bpfmap"
	"kubescx/internal/cgroup"
	"kubescx/internal/classid"
	"kubescx/internal/kubeapi"
	"kubescx/internal/kubejson"
)

func main() {
	pinDir := flag.String("pin", classid.PinDir, "pinned BPF map directory")
	cgroupRoot := flag.String("cgroup-root", "/sys/fs/cgroup", "cgroup v2 root")
	nodeName := flag.String("node-name", os.Getenv("NODE_NAME"), "only classify pods on this node")
	fromJSON := flag.String("from-json", "", "kubectl get pods -o json file, or - for stdin")
	poll := flag.Duration("poll", 2*time.Second, "in-cluster poll interval")
	dryRun := flag.Bool("dry-run", false, "print mappings, do not write BPF maps")
	inCluster := flag.Bool("in-cluster", false, "poll the in-cluster Kubernetes API")

	var tgids, cgroups []string
	flag.Func("tgid", "PID:class (repeatable)", func(s string) error {
		tgids = append(tgids, s)
		return nil
	})
	flag.Func("cgroup", "PATH:class (repeatable)", func(s string) error {
		cgroups = append(cgroups, s)
		return nil
	})
	flag.Usage = func() {
		fmt.Fprintf(os.Stderr, `kubescx-agent maps Kubernetes workload intent onto scx_kube.

Classes: latency | background | default
Label:   %s

Examples:
  kubescx-agent --tgid 1201:latency --tgid 1202:background
  kubectl get pods -A -o json | kubescx-agent --from-json -
  kubescx-agent --in-cluster --node-name "$NODE_NAME"

`, classid.LabelClass)
		flag.PrintDefaults()
	}
	flag.Parse()

	if len(tgids) == 0 && len(cgroups) == 0 && *fromJSON == "" && !*inCluster {
		flag.Usage()
		os.Exit(2)
	}

	var maps *bpfmap.Maps
	if !*dryRun {
		m, err := bpfmap.Open(*pinDir)
		if err != nil {
			fatal("%v", err)
		}
		maps = m
		defer maps.Close()
	}

	for _, spec := range tgids {
		applyTGID(maps, spec, *dryRun)
	}
	for _, spec := range cgroups {
		applyCgroup(maps, spec, *dryRun)
	}

	applyPods := func(pods []kubejson.Pod) {
		applyPodList(maps, pods, *cgroupRoot, *nodeName, *dryRun)
	}

	if *fromJSON != "" {
		r, closer, err := openJSON(*fromJSON)
		if err != nil {
			fatal("%v", err)
		}
		if closer != nil {
			defer closer.Close()
		}
		pods, err := kubejson.Parse(r)
		if err != nil {
			fatal("parse json: %v", err)
		}
		applyPods(pods)
	}

	if !*inCluster {
		return
	}
	if !kubeapi.Available() {
		fatal("not running in-cluster (missing service account token)")
	}
	client, err := kubeapi.InCluster(*nodeName)
	if err != nil {
		fatal("%v", err)
	}
	fmt.Fprintf(os.Stderr, "polling Kubernetes API every %s for node %q\n", *poll, *nodeName)
	for {
		resp, err := client.ListPods()
		if err != nil {
			fmt.Fprintf(os.Stderr, "list pods: %v\n", err)
			time.Sleep(*poll)
			continue
		}
		pods, err := kubejson.Parse(resp.Body)
		resp.Body.Close()
		if err != nil {
			fmt.Fprintf(os.Stderr, "decode pods: %v\n", err)
			time.Sleep(*poll)
			continue
		}
		applyPods(pods)
		time.Sleep(*poll)
	}
}

func openJSON(path string) (io.Reader, io.Closer, error) {
	if path == "-" {
		return os.Stdin, nil, nil
	}
	f, err := os.Open(path)
	if err != nil {
		return nil, nil, err
	}
	return f, f, nil
}

func applyTGID(maps *bpfmap.Maps, spec string, dryRun bool) {
	pidStr, classStr, ok := strings.Cut(spec, ":")
	if !ok {
		fatal("expected PID:class, got %q", spec)
	}
	pid, err := strconv.ParseUint(pidStr, 10, 32)
	if err != nil {
		fatal("bad pid in %q: %v", spec, err)
	}
	info, ok := classid.Parse(classStr)
	if !ok {
		fatal("unknown class %q", classStr)
	}
	fmt.Printf("tgid %d -> %s weight=%d\n", pid, classid.Name(info.Class), info.Weight)
	if dryRun || maps == nil {
		return
	}
	if err := maps.PutTGID(uint32(pid), info); err != nil {
		fatal("%v", err)
	}
}

func applyCgroup(maps *bpfmap.Maps, spec string, dryRun bool) {
	path, classStr, ok := strings.Cut(spec, ":")
	if !ok {
		fatal("expected PATH:class, got %q", spec)
	}
	info, ok := classid.Parse(classStr)
	if !ok {
		fatal("unknown class %q", classStr)
	}
	id, err := cgroup.Inode(path)
	if err != nil {
		fatal("stat %s: %v", path, err)
	}
	fmt.Printf("cgroup %s id=%d -> %s\n", path, id, classid.Name(info.Class))
	if dryRun || maps == nil {
		return
	}
	if err := maps.PutCgroup(id, info); err != nil {
		fatal("%v", err)
	}
}

func applyPodList(maps *bpfmap.Maps, pods []kubejson.Pod, cgroupRoot, nodeName string, dryRun bool) {
	for _, p := range pods {
		if nodeName != "" && p.NodeName != "" && p.NodeName != nodeName {
			continue
		}
		if p.Label != "" && !p.Labeled {
			fmt.Fprintf(os.Stderr, "warning: pod %s/%s has %s=%q (unknown class, skipped)\n",
				p.Namespace, p.Name, classid.LabelClass, p.Label)
			continue
		}
		if !p.Labeled {
			continue
		}
		dirs, err := cgroup.FindPodDirs(cgroupRoot, p.UID)
		if err != nil {
			fmt.Fprintf(os.Stderr, "walk cgroups for %s/%s: %v\n", p.Namespace, p.Name, err)
			continue
		}
		fmt.Printf("pod %s/%s uid=%s class=%s cgroups=%d\n",
			p.Namespace, p.Name, p.UID, classid.Name(p.Class.Class), len(dirs))
		if len(dirs) == 0 {
			fmt.Fprintf(os.Stderr, "warning: no cgroup path under %s contained uid %s (task stays default)\n",
				cgroupRoot, p.UID)
			continue
		}
		for _, dir := range dirs {
			id, err := cgroup.Inode(dir)
			if err != nil {
				fmt.Fprintf(os.Stderr, "stat %s: %v\n", dir, err)
				continue
			}
			fmt.Printf("  %s id=%d\n", dir, id)
			if dryRun || maps == nil {
				continue
			}
			if err := maps.PutCgroup(id, p.Class); err != nil {
				fmt.Fprintf(os.Stderr, "map put %d: %v\n", id, err)
			}
		}
	}
}

func fatal(format string, args ...any) {
	fmt.Fprintf(os.Stderr, format+"\n", args...)
	os.Exit(1)
}
