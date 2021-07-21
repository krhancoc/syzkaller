// Copyright 2021 syzkaller project authors. All rights reserved.
// Use of this source code is governed by Apache 2 LICENSE that can be found in the LICENSE file.
package main

import (
	"bytes"
	"testing"

	"github.com/google/go-cmp/cmp"
)

func dummyStats() *Stats {
	return &Stats{
		Progs:           24,
		TotalMismatches: 10,
		Calls: map[string]*CallStats{
			"foo": {"foo", 2, 8, map[ReturnState]bool{{Errno: 1}: true, {Errno: 3}: true}},
			"bar": {"bar", 5, 6, map[ReturnState]bool{{Errno: 10}: true, {Errno: 22}: true}},
			"tar": {"tar", 3, 4, map[ReturnState]bool{{Errno: 5}: true, {Errno: 17}: true, {Errno: 31}: true}},
			"biz": {"biz", 0, 2, map[ReturnState]bool{}},
		},
	}
}

func TestReportCallStats(t *testing.T) {
	tests := []struct {
		name, call, report string
	}{
		{
			name:   "report for unsupported call",
			call:   "read",
			report: "",
		},
		{
			name: "report for supported call",
			call: "foo",
			report: "statistics for foo:\n" +
				"\t↳ mismatches of foo / occurrences of foo: 2 / 8 (25.00 %)\n" +
				"\t↳ mismatches of foo / total number of mismatches: 2 / 10 (20.00 %)\n" +
				"\t↳ 2 distinct states identified: " +
				"[Errno: 1 (operation not permitted)\n Errno: 3 (no such process)\n]\n",
		},
	}

	for _, test := range tests {
		s := dummyStats()
		t.Run(test.name, func(t *testing.T) {
			got, want := s.ReportCallStats(test.call), test.report
			if diff := cmp.Diff(want, got); diff != "" {
				t.Errorf("s.ReportCallStats mismatch (-want +got):\n%s", diff)
			}
		})
	}
}

func TestReportGlobalStats(t *testing.T) {
	s := dummyStats()
	out := bytes.Buffer{}
	s.ReportGlobalStats(&out, float64(10))
	got, want := out.String(),
		"total number of mismatches / total number of calls "+
			"executed: 10 / 20 (50.00 %)\n\n"+
			"programs / minute: 2.40\n\n"+
			"statistics for bar:\n"+
			"\t↳ mismatches of bar / occurrences of bar: 5 / 6 (83.33 %)\n"+
			"\t↳ mismatches of bar / total number of mismatches: 5 / 10 (50.00 %)\n"+
			"\t↳ 2 distinct states identified: "+
			"[Errno: 10 (no child processes)\n Errno: 22 (invalid argument)\n]\n\n"+
			"statistics for tar:\n"+
			"\t↳ mismatches of tar / occurrences of tar: 3 / 4 (75.00 %)\n"+
			"\t↳ mismatches of tar / total number of mismatches: 3 / 10 (30.00 %)\n"+
			"\t↳ 3 distinct states identified: "+
			"[Errno: 5 (input/output error)\n Errno: 17 (file exists)\n Errno: 31 (too many links)\n]\n\n"+
			"statistics for foo:\n"+
			"\t↳ mismatches of foo / occurrences of foo: 2 / 8 (25.00 %)\n"+
			"\t↳ mismatches of foo / total number of mismatches: 2 / 10 (20.00 %)\n"+
			"\t↳ 2 distinct states identified: "+
			"[Errno: 1 (operation not permitted)\n Errno: 3 (no such process)\n]\n\n"

	if diff := cmp.Diff(want, got); diff != "" {
		t.Errorf("s.ReportGlobalStats mismatch (-want +got):\n%s", diff)
	}
}