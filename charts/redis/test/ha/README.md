# Sentinel HA test harness

Runs the Sentinel failover scenarios against a real cluster and measures them with a
write probe. Use it before publishing any change to `redis.sh`, `sentinel.sh`, the
StatefulSet, the Sentinel Deployment or the headless Service.

It is not part of the chart: `.helmignore` keeps `test/` out of the package.

## What it needs

- `kubectl` and `helm`, with `KUBECONFIG` pointing at a cluster whose nodes can run
  `redis:7-alpine`. Nothing is pulled from your machine, so a laptop that cannot reach
  Docker Hub is fine.
- At least 3 schedulable non-control-plane nodes (redis anti-affinity is `hard`).

Everything goes into a throwaway namespace, `redis-ha-test` (override with `NS=`), as
release `rt` (override with `REL=`). **Never point `NS` at a namespace that runs a real
release.**

## Scripts

| Script | What it does |
|---|---|
| `setup.sh [VERSION\|local] [KEYS]` | Installs a published `VERSION` (or the local chart), moves the master to the **last** pod (the first one a rollout restarts, which is the hard case), seeds `KEYS` keys (default 1000) and starts the probe |
| `upgrade.sh LABEL [helm args]` | `helm upgrade` to the local chart, waits for the rollouts and measures |
| `kill-master.sh [ROUNDS]` | Deletes the master pod `ROUNDS` times (default 3) and measures each round |
| `cold-start.sh` | Deletes every redis pod at once (sentinels stay up) and measures |
| `teardown.sh` | Deletes the namespace |

The probe (`probe.yaml`) asks Sentinel for the master every ~0.5 s, writes a key and
reads `DBSIZE`. Each measurement prints the failed writes, the lowest `DBSIZE` seen
(**a drop means data was lost**), the OK/FAIL windows, the Sentinel events and the final
replication state.

`upgrade.sh` passes its flags to `helm upgrade`, so repeat the flags of earlier runs or
helm will revert them, and that revert is also a config change.

## The full run

```bash
./setup.sh 0.4.1 1000                       # or the version currently in production
./upgrade.sh to-local                       # the transition you are about to ship
./kill-master.sh 3
./upgrade.sh redis-side    --set maxmemory=200mb
./upgrade.sh sentinel-side --set maxmemory=200mb --set sentinel.downAfterMilliseconds=9000
./cold-start.sh
./teardown.sh
```

## Expected results (0.5.0, measured 2026-09-24 on faablecore)

| Scenario | Writes failing | Lowest DBSIZE | Also check |
|---|---|---|---|
| `to-local` from 0.4.1, master on the last pod | ~15-19 s (sentinels start with no memory and promote), then ~11 s (normal failover when the rollout reaches the master) | unchanged | only a transition that changes **both** sides has the first window |
| `kill-master`, each round | ~10-11 s (`down-after` + election) | unchanged | no `-failover-abort-*`, no `+fix-slave-config` storm before the failover |
| `redis-side` | one window of ~11 s | unchanged | sentinel pods **not** restarted |
| `sentinel-side` | ~4-5 s, only the probe's lookups (`m=none`); clients already connected are unaffected | unchanged | redis pods **not** restarted |
| `cold-start` | ~50 s | drops to 1 (expected without persistence) | converges to one master and two `up` replicas, with no deadlock |

For comparison, 0.4.1 left ~90 s without a master on every config change and, without
persistence, came back with an empty dataset.

## What a failure usually means

- **`-failover-abort-no-good-slave`**: Sentinel did not know a usable replica. Check that
  the replicas announce their FQDN (`slave0:ip=<fqdn>` in the master's `INFO`) and that
  `sentinel.conf` got its `known-replica` lines.
- **`+fix-slave-config` every second before the failover**: the old master's FQDN resolves
  to its new pod while Sentinel still holds the old IP. The headless Service must keep
  `publishNotReadyAddresses: false`.
- **DBSIZE drops in any scenario other than `cold-start`**: a pod started as an empty
  master. Read the first lines of each redis pod's log; `redis.sh` states why it chose
  its role.

Background and incident history: `arch/infra/redis-sentinel-chart.md` in the architecture
repo.
