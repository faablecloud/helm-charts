# Faable Helm Charts

Internal charts that support Faable's own services. This repository is public only because Helm
installs the charts from its GitHub Pages site.

This is not a supported product: the charts can change without notice, and we do not take feature
requests for them. For Faable's products, see the [documentation](https://faable.com/docs).

## Usage

Use a chart as a dependency of your own chart:

```yaml
dependencies:
  - name: redis
    version: 0.5.0
    repository: https://faablecloud.github.io/helm-charts
```

The parent chart sets the subchart's values under the `redis:` key. They are described in
[`values.yaml`](charts/redis/values.yaml).

## Charts

| Chart   | Description                                          |
| ------- | ---------------------------------------------------- |
| `redis` | Redis/Valkey deployment — standalone or Sentinel HA. |

## Releasing

Charts are published automatically by the `release` GitHub Action
([helm/chart-releaser-action](https://github.com/helm/chart-releaser-action)):
on every push to `main`, each chart under `charts/` whose `version` in
`Chart.yaml` was bumped is packaged, attached to a GitHub Release, and indexed
in `index.yaml` on the `gh-pages` branch (served via GitHub Pages).

To cut a new version: bump `version:` in the chart's `Chart.yaml`, commit, and
merge to `main`. Consumers then run `helm dependency update`.

## License

[MIT](LICENSE) © Faable Cloud SLU
