package cgroup

import "testing"

func TestPathMatchesPod(t *testing.T) {
	uid := "123e4567-e89b-12d3-a456-426614174000"
	sysd := "123e4567_e89b_12d3_a456_426614174000"

	cases := []struct {
		path string
		want bool
	}{
		{"/sys/fs/cgroup/kubepods.slice/kubepods-burstable.slice/kubepods-burstable-pod" + sysd + ".slice", true},
		{"/sys/fs/cgroup/kubepods/burstable/pod" + uid + "/containerid", true},
		{"/sys/fs/cgroup/user.slice", false},
		{"/sys/fs/cgroup/kubepods.slice/other-pod", false},
	}
	for _, tc := range cases {
		if got := pathMatchesPod(tc.path, uid); got != tc.want {
			t.Fatalf("pathMatchesPod(%q) = %v, want %v", tc.path, got, tc.want)
		}
	}
}

func TestSystemdUID(t *testing.T) {
	if got := systemdUID("a-b-c"); got != "a_b_c" {
		t.Fatalf("got %q", got)
	}
}
