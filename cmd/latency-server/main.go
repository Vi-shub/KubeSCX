package main

import (
	"flag"
	"fmt"
	"net/http"
	"os"
	"strconv"
	"time"
)

func main() {
	addr := flag.String("addr", ":8080", "listen address")
	workUs := flag.Int("work-us", 500, "CPU spin per request in microseconds")
	flag.Parse()

	http.HandleFunc("/healthz", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte("ok\n"))
	})
	http.HandleFunc("/work", func(w http.ResponseWriter, r *http.Request) {
		us := *workUs
		if q := r.URL.Query().Get("us"); q != "" {
			if n, err := strconv.Atoi(q); err == nil && n >= 0 && n < 1_000_000 {
				us = n
			}
		}
		spin(time.Duration(us) * time.Microsecond)
		w.Header().Set("Content-Type", "text/plain")
		fmt.Fprintf(w, "ok work_us=%d\n", us)
	})

	fmt.Fprintf(os.Stderr, "latency-server %s work-us=%d\n", *addr, *workUs)
	if err := http.ListenAndServe(*addr, nil); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}

func spin(d time.Duration) {
	end := time.Now().Add(d)
	for time.Now().Before(end) {
	}
}
