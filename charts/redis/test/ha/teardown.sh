#!/usr/bin/env bash
# teardown.sh — delete the test namespace (release, PVCs, probe).
source "$(dirname "$0")/lib.sh"
kubectl delete namespace "$NS" --wait=false
