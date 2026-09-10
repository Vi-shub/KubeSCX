package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"io"
	"net/http"
	"os"
	"sort"
	"sync"
	"sync/atomic"
	"time"
)

type report struct {
	URL         string  `json:"url"`
	DurationSec float64 `json:"duration_sec"`
	Requests    int     `json:"requests"`
	Errors      int     `json:"errors"`
	RPS         float64 `json:"rps"`
	P50Ms       float64 `json:"p50_ms"`
	P95Ms       float64 `json:"p95_ms"`
	P99Ms       float64 `json:"p99_ms"`
	P999Ms      float64 `json:"p999_ms"`
	MaxMs       float64 `json:"max_ms"`
}

func main() {
	target := flag.String("url", "http://127.0.0.1:8080/work", "target URL")
	concurrency := flag.Int("c", 8, "concurrent clients")
	duration := flag.Duration("d", 20*time.Second, "duration")
	jsonOut := flag.Bool("json", false, "print JSON instead of a table")
	flag.Parse()

	client := &http.Client{Timeout: 5 * time.Second}
	var latMu sync.Mutex
	lats := make([]time.Duration, 0, 8192)
	var errs atomic.Int64
	var ok atomic.Int64

	stop := time.Now().Add(*duration)
	var wg sync.WaitGroup
	for i := 0; i < *concurrency; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			for time.Now().Before(stop) {
				start := time.Now()
				resp, err := client.Get(*target)
				elapsed := time.Since(start)
				if err != nil {
					errs.Add(1)
					continue
				}
				io.Copy(io.Discard, resp.Body)
				resp.Body.Close()
				if resp.StatusCode >= 400 {
					errs.Add(1)
					continue
				}
				ok.Add(1)
				latMu.Lock()
				lats = append(lats, elapsed)
				latMu.Unlock()
			}
		}()
	}
	wg.Wait()

	rep := report{
		URL:         *target,
		DurationSec: duration.Seconds(),
		Requests:    int(ok.Load()),
		Errors:      int(errs.Load()),
	}
	if rep.DurationSec > 0 {
		rep.RPS = float64(rep.Requests) / rep.DurationSec
	}
	if n := len(lats); n > 0 {
		sort.Slice(lats, func(i, j int) bool { return lats[i] < lats[j] })
		rep.P50Ms = ms(percentile(lats, 0.50))
		rep.P95Ms = ms(percentile(lats, 0.95))
		rep.P99Ms = ms(percentile(lats, 0.99))
		rep.P999Ms = ms(percentile(lats, 0.999))
		rep.MaxMs = ms(lats[n-1])
	}

	if *jsonOut {
		enc := json.NewEncoder(os.Stdout)
		enc.SetIndent("", "  ")
		_ = enc.Encode(rep)
		return
	}
	fmt.Printf("url=%s  n=%d  err=%d  rps=%.1f\n", rep.URL, rep.Requests, rep.Errors, rep.RPS)
	fmt.Printf("p50=%.2fms  p95=%.2fms  p99=%.2fms  p99.9=%.2fms  max=%.2fms\n",
		rep.P50Ms, rep.P95Ms, rep.P99Ms, rep.P999Ms, rep.MaxMs)
}

func percentile(sorted []time.Duration, p float64) time.Duration {
	if len(sorted) == 0 {
		return 0
	}
	idx := int(p * float64(len(sorted)-1))
	if idx < 0 {
		idx = 0
	}
	if idx >= len(sorted) {
		idx = len(sorted) - 1
	}
	return sorted[idx]
}

func ms(d time.Duration) float64 {
	return float64(d) / float64(time.Millisecond)
}
