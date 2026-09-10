package cgroup

import "strings"

func systemdUID(podUID string) string {
	return strings.ReplaceAll(podUID, "-", "_")
}

func pathMatchesPod(path, podUID string) bool {
	if podUID == "" {
		return false
	}
	if strings.Contains(path, podUID) {
		return true
	}
	return strings.Contains(path, systemdUID(podUID))
}
