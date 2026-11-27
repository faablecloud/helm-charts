#!/usr/bin/env bash
# kill-master-and-sentinel.sh [ROUNDS] — delete the master pod and one sentinel
# pod at the same time, ROUNDS times (default 2). It is what a node drain does
# when both live on the node, the case that split the sentinels' view on
# 2026-11-27: the new sentinel promoted a replica by itself, the survivors kept
# the old master with a higher epoch, and every sentinel started later adopted
# it. Pass = writes recover, every sentinel names the real master, and the
# ghost of the deleted sentinel is forgotten (reaper) within a few minutes.
#
# SENTINELS=2 deletes two sentinels with the master: the survivor alone has no
# quorum, so the new sentinels must ask it for SENTINEL FAILOVER instead of
# promoting a replica themselves (the path sentinel.sh takes when the live
# sentinels cannot fail over in time, e.g. with ghost voters).
source "$(dirname "$0")/lib.sh"
for n in $(seq 1 "${1:-2}"); do
  M=$(master_pod); T0=$(now); E0=$(date +%s)
  S=$(k get pods -l "app.kubernetes.io/name=redis-sentinel,app.kubernetes.io/instance=$REL" -o name | sed 's#pod/##' | head -"${SENTINELS:-1}" | tr '\n' ' ')
  k delete pod "$M" $S --wait=false >/dev/null
  echo "-- round $n: deleted $M and $S"
  sleep 90
  measure "kill-master-and-sentinel-$n" "$T0"
  echo "  sentinels:"; sentinels
  for i in $(seq 1 40); do converged && break; sleep 10; done
  if converged; then echo "  converged after $(( $(date +%s) - E0 )) s"
  else echo "  NOT CONVERGED:"; sentinels; fi
  sleep 15
done
