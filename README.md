# Faable Helm Charts

```bash
helm repo add faablecloud https://faablecloud.github.io/helm-charts
helm repo update
```

You can then run `helm search repo faablecloud` to see the charts.

## Charts

| Chart   | Description                                                       |
| ------- | ----------------------------------------------------------------- |
| `redis` | Redis/Valkey deployment — standalone or Sentinel HA. Shared by `auth` and `api`. |

## Releasing

Charts are published automatically by the `release` GitHub Action
([helm/chart-releaser-action](https://github.com/helm/chart-releaser-action)):
on every push to `main`, each chart under `charts/` whose `version` in
`Chart.yaml` was bumped is packaged, attached to a GitHub Release, and indexed
in `index.yaml` on the `gh-pages` branch (served via GitHub Pages).

To cut a new version: bump `version:` in the chart's `Chart.yaml`, commit, and
merge to `main`. Consumers then run `helm dependency update`.
