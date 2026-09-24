#!/usr/bin/env bash
# kill-master.sh [ROUNDS] — delete the master pod ROUNDS times (default 3).
source "$(dirname "$0")/lib.sh"
for n in $(seq 1 "${1:-3}"); do
  M=$(master_pod); T0=$(now)
  k delete pod "$M" --wait=false >/dev/null
  echo "-- round $n: deleted $M"
  sleep 70
  measure "kill-master-$n" "$T0"
  sleep 15
done
