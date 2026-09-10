package main

import (
	"flag"
	"fmt"
	"os"
	"runtime"
	"time"
)

func main() {
	workers := flag.Int("workers", runtime.NumCPU(), "busy-loop goroutines")
	flag.Parse()
	fmt.Fprintf(os.Stderr, "cpu-burn workers=%d pid=%d\n", *workers, os.Getpid())
	for i := 0; i < *workers; i++ {
		go func() {
			for {
				x := 1
				for i := 0; i < 100000; i++ {
					x = x*3 + 1
				}
				_ = x
			}
		}()
	}
	for {
		time.Sleep(time.Hour)
	}
}
