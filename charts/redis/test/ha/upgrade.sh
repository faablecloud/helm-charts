#!/usr/bin/env bash
# upgrade.sh LABEL [helm args...]
# helm upgrade to the LOCAL chart and measure the rollout with the probe.
#   ./upgrade.sh to-local                                   # e.g. after setup.sh 0.4.1
#   ./upgrade.sh redis-side    --set maxmemory=200mb        # only redis.conf changes
#   ./upgrade.sh sentinel-side --set sentinel.downAfterMilliseconds=9000   # only sentinel.conf
# Pass the flags of previous runs again, or helm reverts them (and that is a change too).
source "$(dirname "$0")/lib.sh"
LABEL=$1; shift
T0=$(now)
helm upgrade "$REL" "$CHART" -n "$NS" -f "$HERE/values.yaml" "$@" >/dev/null || exit 1
sleep 5
k rollout status "deploy/$REL-redis-sentinel" --timeout=4m >/dev/null 2>&1
k rollout status "sts/$REL-redis" --timeout=8m >/dev/null 2>&1
sleep 40
measure "$LABEL" "$T0"
