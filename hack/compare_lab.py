#!/usr/bin/env python3
"""Print a compare table from loadgen JSON reports. Keys are labels."""
import json
import sys


def load(path):
    with open(path) as f:
        return json.load(f)


def main():
    if len(sys.argv) < 3 or (len(sys.argv) - 1) % 2 != 0:
        print("usage: compare_lab.py LABEL json [LABEL json ...]", file=sys.stderr)
        sys.exit(2)
    rows = []
    args = sys.argv[1:]
    for i in range(0, len(args), 2):
        label, path = args[i], args[i + 1]
        rows.append((label, load(path)))
    print(f"{'run':<22} {'p50_ms':>8} {'p95_ms':>8} {'p99_ms':>8} {'p99.9_ms':>9} {'rps':>8} {'err':>5}")
    for label, r in rows:
        print(
            f"{label:<22} {r.get('p50_ms', 0):8.2f} {r.get('p95_ms', 0):8.2f} "
            f"{r.get('p99_ms', 0):8.2f} {r.get('p999_ms', 0):9.2f} {r.get('rps', 0):8.1f} "
            f"{r.get('errors', 0):5d}"
        )
        if r.get("errors", 0):
            print(f"warning: {label} had {r['errors']} HTTP errors", file=sys.stderr)
    if len(rows) == 2:
        a, b = rows[0][1], rows[1][1]
        if a.get("p99_ms"):
            delta = (a["p99_ms"] - b["p99_ms"]) / a["p99_ms"] * 100
            print(f"p99 change {rows[0][0]} -> {rows[1][0]}: {delta:+.1f}%  (positive means the second run is better)")
    print()
    print("A negative result is still useful. Record it; do not tune the writeup to invent a win.")


if __name__ == "__main__":
    main()
