//go:build linux

package cgroup

import (
	"io/fs"
	"os"
	"path/filepath"
	"syscall"
)

func Inode(path string) (uint64, error) {
	var st syscall.Stat_t
	if err := syscall.Stat(path, &st); err != nil {
		return 0, err
	}
	return st.Ino, nil
}

func FindPodDirs(cgroupRoot, podUID string) ([]string, error) {
	var dirs []string
	err := filepath.WalkDir(cgroupRoot, func(path string, d fs.DirEntry, err error) error {
		if err != nil {
			if os.IsPermission(err) {
				return nil
			}
			return err
		}
		if !d.IsDir() {
			return nil
		}
		if pathMatchesPod(path, podUID) {
			dirs = append(dirs, path)
		}
		return nil
	})
	return dirs, err
}

func InodesForPod(cgroupRoot, podUID string) ([]uint64, error) {
	dirs, err := FindPodDirs(cgroupRoot, podUID)
	if err != nil {
		return nil, err
	}
	seen := make(map[uint64]struct{}, len(dirs))
	var ids []uint64
	for _, dir := range dirs {
		id, err := Inode(dir)
		if err != nil {
			continue
		}
		if _, ok := seen[id]; ok {
			continue
		}
		seen[id] = struct{}{}
		ids = append(ids, id)
	}
	return ids, nil
}
