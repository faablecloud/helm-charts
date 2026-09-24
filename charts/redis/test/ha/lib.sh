# Shared helpers, sourced by the scenario scripts. Needs kubectl + helm with
# KUBECONFIG pointing at the test cluster.
set -u
NS=${NS:-redis-ha-test}
REL=${REL:-rt}
PASS=testpass
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CHART=$(cd "$HERE/../.." && pwd)

k() { kubectl -n "$NS" "$@"; }
rc() { k exec "$1" -- redis-cli -a "$PASS" --no-auth-warning "${@:2}" 2>/dev/null | tr -d '\r'; }
redis_pods() { k get pods -l "app.kubernetes.io/name=redis,app.kubernetes.io/instance=$REL" -o name | sed 's#pod/##' | sort; }
sentinel_pod() { k get pods -l "app.kubernetes.io/name=redis-sentinel,app.kubernetes.io/instance=$REL" -o name | sed 's#pod/##' | head -1; }
now() { date -u +%Y-%m-%dT%H:%M:%SZ; }

# The pod that says role:master (Sentinel answers an IP up to 0.4.1 and a
# hostname from 0.5.0, so ask the pods).
master_pod() {
  for p in $(redis_pods); do
    rc "$p" info replication | grep -q '^role:master' && { echo "$p"; return; }
  done
}

start_probe() {
  k delete pod probe --ignore-not-found --wait >/dev/null
  sed "s/__REL__/$REL/g; s/__PASS__/$PASS/g" "$HERE/probe.yaml" | k apply -f - >/dev/null
  k wait --for=condition=Ready pod/probe --timeout=120s >/dev/null
}

status() {
  for p in $(redis_pods); do
    printf '  %-12s %-12s ' "$p" "$(k get pod "$p" -o jsonpath='{.spec.nodeName}' | cut -d. -f1)"
    rc "$p" info replication | grep -E '^(role|master_link_status|connected_slaves)' | tr '\n' ' '
    echo "dbsize=$(rc "$p" dbsize)"
  done
  local s; s=$(sentinel_pod)
  echo "  sentinel: $(k exec "$s" -- redis-cli -p 26379 sentinel master mymaster | paste -d= - - | grep -E '^(num-slaves|num-other-sentinels)=' | tr '\n' ' ')$(k exec "$s" -- redis-cli -p 26379 sentinel ckquorum mymaster)"
}

# measure <label> <since RFC3339>: summarise the probe since a point in time.
measure() {
  local log="${TMPDIR:-/tmp}/redis-ha-$1.log"
  k logs probe --since-time="$2" | grep -v Terminated > "$log"
  echo "== $1"
  echo "  failed writes: $(grep -c FAIL "$log") of $(wc -l < "$log" | tr -d ' ') (one attempt every ~0.5 s)"
  echo "  lowest dbsize: $(grep -oE 'dbsize=[0-9]+' "$log" | cut -d= -f2 | sort -n | head -1)   last: $(tail -1 "$log" | grep -oE 'dbsize=[0-9]+')"
  echo "  windows:"
  awk '{print $1, $2, $3}' "$log" | sed 's/\.'"$REL"'-redis\..*//' | awk '
    {key=$2" "$3; if (key!=prev) { if (prev!="") print "    "first" -> "last"  "prev"  ("n")"; first=$1; n=0 } last=$1; n++; prev=key}
    END {if (prev!="") print "    "first" -> "last"  "prev"  ("n")"}'
  echo "  sentinel events:"
  for s in $(k get pods -l "app.kubernetes.io/name=redis-sentinel,app.kubernetes.io/instance=$REL" -o name); do
    k logs "$s" --since-time="$2" | grep -E '^1:X' | grep -E 'sdown master|switch-master|abort|fix-slave' | cut -c17-110 | sed 's/^/    /'
  done | sort -u
  status
}
