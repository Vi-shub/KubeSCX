# Lesson 4 — Read the counters

`scx_kube` prints a line every second:

```
enq lat=… def=… bg=…  disp lat=… def=… bg=…  idle=… kick=…
```

`enq` is “task was queued in that class.” `disp` is “a CPU took a task from that queue.” They should stay close. `kick` is “we forced a reschedule” (in the current policy, mostly from `tick` when latency work is waiting).

## Healthy winning run (Linux 7.0)

```
enq lat=11376 def=15456 bg=142  disp lat=11376 def=15455 bg=139  idle=38 kick=528
```

- enqueue ≈ dispatch → tasks are not disappearing
- `kick` in the hundreds, not millions
- some `bg` still runs → we did not fully kill the burner (good: the policy is preference, not exile)

## Two bugs this line diagnosed

**Background on the idle LOCAL path.** Burners grabbed every CPU in `select_cpu` and skipped the background queue. p99 went from ~23 ms to ~700 ms.

**Kick on every latency enqueue.** Go HTTP threads park and wake constantly. `SCX_KICK_PREEMPT` on each enqueue was ~6.4 million kicks in 15 seconds. p95 improved; p99 exploded to ~423 ms. Rule: if `kick ≈ enq lat` and both are huge, you are preempting yourself.

## How to read a new result

| What you see | Likely cause |
|--------------|----------------|
| p99 down, rps up or flat | Policy did the job on this workload |
| p99 up, `kick ≈ enq lat` and huge | Preempt storm |
| `disp lat` << `enq lat` | Dispatch is not consuming the latency DSQ |
| `enq lat = 0` | Agent did not classify the server TGID |
| p99 unchanged, `bg` huge on LOCAL | Idle fast-path leak |

The teaching point: **a BPF scheduler you cannot explain from counters is not a teaching project.** It is a lottery.
