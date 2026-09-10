//go:build !linux

package cgroup

import "fmt"

func Inode(path string) (uint64, error) {
	return 0, fmt.Errorf("cgroup inodes are Linux-only (%s)", path)
}

func FindPodDirs(cgroupRoot, podUID string) ([]string, error) {
	return nil, fmt.Errorf("cgroup walk is Linux-only")
}

func InodesForPod(cgroupRoot, podUID string) ([]uint64, error) {
	return nil, fmt.Errorf("cgroup walk is Linux-only")
}
