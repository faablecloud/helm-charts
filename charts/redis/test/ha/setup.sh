#!/usr/bin/env bash
# setup.sh [VERSION|local] [KEYS]
# Installs the chart in a throwaway namespace (a published VERSION from the
# faablecloud repo, or the local working copy), puts the master on the LAST
# pod (the first one a StatefulSet rollout restarts — the hard case), seeds
# KEYS keys and starts the probe.
source "$(dirname "$0")/lib.sh"
VERSION=${1:-local}; KEYS=${2:-1000}

helm uninstall "$REL" -n "$NS" --wait >/dev/null 2>&1
if [ "$VERSION" = local ]; then SRC=("$CHART"); else
  helm repo add faablecloud https://faablecloud.github.io/helm-charts >/dev/null 2>&1
  helm repo update faablecloud >/dev/null; SRC=(faablecloud/redis --version "$VERSION"); fi
helm install "$REL" "${SRC[@]}" -n "$NS" --create-namespace -f "$HERE/values.yaml" --wait --timeout 5m >/dev/null || exit 1
sleep 15

LAST=$(redis_pods | tail -1)
for attempt in 1 2 3; do
  [ "$(master_pod)" = "$LAST" ] && break
  for p in $(redis_pods); do [ "$p" = "$LAST" ] && prio=10 || prio=200; rc "$p" config set replica-priority $prio >/dev/null; done
  k exec "$(sentinel_pod)" -- redis-cli -p 26379 sentinel failover mymaster >/dev/null
  sleep 15
done
for p in $(redis_pods); do rc "$p" config set replica-priority 100 >/dev/null; done
[ "$(master_pod)" = "$LAST" ] || { echo "could not move the master to $LAST"; exit 1; }

k exec "$LAST" -- sh -c "for i in \$(seq 1 $KEYS); do echo \"SET seed:\$i v\$i\"; done | redis-cli -a $PASS --no-auth-warning --pipe" | tail -1
start_probe
echo "== setup ($VERSION): master on $LAST, $KEYS keys"
status
