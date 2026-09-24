#!/usr/bin/env bash
# cold-start.sh — delete every redis pod at once (sentinels stay up). It must
# converge to one master without deadlock. Without persistence the keys are
# lost: that is expected here, nothing held them.
source "$(dirname "$0")/lib.sh"
T0=$(now)
k delete pod $(redis_pods) --wait=false >/dev/null
sleep 100
measure cold-start "$T0"
for p in $(redis_pods); do echo "  $p: $(k logs "$p" | grep -vE '^[0-9]+:[A-Z] |^$|Esperando la promoción' | tail -1)"; done
