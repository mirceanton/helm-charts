# volsync

![Version: 0.1.0](https://img.shields.io/badge/Version-0.1.0-informational?style=flat-square)

A PVC plus its VolSync backup and restore resources, with a deterministic staggered backup schedule and a final backup on uninstall.

## Overview

For one app, this chart renders:

- a `PersistentVolumeClaim` that, on first creation, is restored from the latest backup (`dataSourceRef` → `ReplicationDestination`)
- a `ReplicationSource` that backs the PVC up to a restic repository
- a `ReplicationDestination` used for that restore
- optionally, an `ExternalSecret` that builds the restic repository credentials

It assumes [VolSync](https://volsync.readthedocs.io/) is installed, and [External Secrets](https://external-secrets.io/) too when `externalSecret.enabled` is set.

### Staggered schedules

If every app shares the same cron expression, all backups start at the same moment and spike CPU and I/O. Instead of a fixed cron, set `backup.every` (for example `6h`). The chart then hashes `namespace/release`, or `backup.seed` if set, into a minute and hour offset:

| release           | `every: 12h`    | `every: 4h`                |
|-------------------|-----------------|----------------------------|
| `ai/hermes`       | `30 8,20 * * *` | `30 0,4,8,12,16,20 * * *`  |
| `media/immich`    | `23 7,19 * * *` | `23 3,7,11,15,19,23 * * *` |
| `media/paperless` | `54 2,14 * * *` | `54 2,6,10,14,18,22 * * *` |

The result is deterministic: the same release always renders the same schedule, so there is no drift between reconciles. To pin an exact time, set `backup.schedule`, which takes precedence.

### Final backup on uninstall

With `backup.finalBackup.enabled` (the default), a `pre-delete` hook Job runs on uninstall. It switches the `ReplicationSource` to a one-off manual trigger and waits until VolSync reports it in `status.lastManualSync`. Only then does Helm delete the PVC and the rest. If the backup fails or exceeds `backup.finalBackup.timeoutSeconds`, the uninstall fails and nothing is deleted.

When using Flux, keep `spec.uninstall.timeout` above the backup timeout, and don't set `spec.uninstall.disableHooks`. Deleting the whole namespace at once can race the hook, so remove the `HelmRelease` first.

## Using with FluxCD

```yaml
---
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: paperless-volsync
spec:
  interval: 1h
  releaseName: paperless
  chart:
    kind: OCIRepository
    spec:
      url: oci://ghcr.io/mirceanton/helm-charts/volsync
      ref:
        tag: 0.1.0
  uninstall:
    timeout: 70m
  values:
    pvc:
      capacity: 20Gi
    backup:
      every: 6h
```

The inline `chart.kind: OCIRepository` form needs Flux v2.10 or newer. On older versions, use `chartRef` pointing to a separate `OCIRepository`.

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| backup | object | `{"accessModes":["ReadWriteOnce"],"cache":{"accessModes":["ReadWriteOnce"],"capacity":"5Gi","storageClass":"openebs-zfs"},"copyMethod":"Snapshot","every":"12h","finalBackup":{"enabled":true,"image":{"repository":"registry.k8s.io/kubectl","tag":"v1.37.2"},"timeoutSeconds":3600},"mover":{"gid":1000,"uid":1000},"pruneIntervalDays":14,"retain":{"daily":7,"hourly":6},"schedule":"","seed":"","snapshotClass":"openebs-snapshots","storageClass":"openebs-zfs"}` | Backup (ReplicationSource) and restore (ReplicationDestination) settings. |
| backup.accessModes | list | `["ReadWriteOnce"]` | Access modes for the temporary snapshot/clone volume. |
| backup.cache | object | `{"accessModes":["ReadWriteOnce"],"capacity":"5Gi","storageClass":"openebs-zfs"}` | Restic cache volume settings. |
| backup.cache.accessModes | list | `["ReadWriteOnce"]` | Access modes of the restic cache volume. |
| backup.cache.capacity | string | `"5Gi"` | Size of the restic cache volume. |
| backup.cache.storageClass | string | `"openebs-zfs"` | StorageClass of the restic cache volume. |
| backup.copyMethod | string | `"Snapshot"` | VolSync copy method for backups. |
| backup.every | string | `"12h"` | Backup interval in hours (e.g. `4h`, `6h`, `12h`, `24h`); must divide 24 evenly. The minute and hour offset are derived from a hash of `namespace/release` (or `seed`), so every app gets a stable but different slot instead of all firing at once. |
| backup.finalBackup | object | `{"enabled":true,"image":{"repository":"registry.k8s.io/kubectl","tag":"v1.37.2"},"timeoutSeconds":3600}` | On `helm uninstall`, take one last backup before anything is deleted. A failed or timed-out backup fails the uninstall, so nothing is lost silently. |
| backup.finalBackup.enabled | bool | `true` | Run the pre-delete final backup hook. |
| backup.finalBackup.image | object | `{"repository":"registry.k8s.io/kubectl","tag":"v1.37.2"}` | kubectl image used by the hook Job (needs no shell). |
| backup.finalBackup.image.repository | string | `"registry.k8s.io/kubectl"` | Image repository. |
| backup.finalBackup.image.tag | string | `"v1.37.2"` | Image tag. |
| backup.finalBackup.timeoutSeconds | int | `3600` | Max seconds to wait for the final backup. Keep Flux's `uninstall.timeout` above this. |
| backup.mover | object | `{"gid":1000,"uid":1000}` | UID/GID the restic mover runs as (also used as fsGroup). |
| backup.mover.gid | int | `1000` | Mover GID and fsGroup. |
| backup.mover.uid | int | `1000` | Mover UID. |
| backup.pruneIntervalDays | int | `14` | How often (in days) restic prunes the repository. |
| backup.retain | object | `{"daily":7,"hourly":6}` | Restic retention policy. |
| backup.retain.daily | int | `7` | Daily snapshots to keep. |
| backup.retain.hourly | int | `6` | Hourly snapshots to keep. |
| backup.schedule | string | `""` | Manual cron expression. If set, it takes precedence over `every`. |
| backup.seed | string | `""` | Override the hash input used to derive the schedule offset. Change it if two apps collide. |
| backup.snapshotClass | string | `"openebs-snapshots"` | VolumeSnapshotClass used for Snapshot copies. |
| backup.storageClass | string | `"openebs-zfs"` | StorageClass for the temporary snapshot/clone volume. |
| externalSecret | object | `{"bucket":"home-ops-volsync","enabled":true,"itemKey":"Garage HomeOps Backups Key","storeKind":"ClusterSecretStore","storeName":"onepassword"}` | ExternalSecret that builds the restic repository credentials secret. |
| externalSecret.bucket | string | `"home-ops-volsync"` | S3 bucket; each app gets its own `<bucket>/<name>` restic repository. |
| externalSecret.enabled | bool | `true` | Create the ExternalSecret. Disable it to bring your own `<name>-volsync-secret`. |
| externalSecret.itemKey | string | `"Garage HomeOps Backups Key"` | Secret store item holding the `username`, `password`, `url` and `RESTIC_PASSWORD` properties. |
| externalSecret.storeKind | string | `"ClusterSecretStore"` | Kind of the secret store. |
| externalSecret.storeName | string | `"onepassword"` | Name of the secret store. |
| nameOverride | string | `""` | Name used for all rendered resources. Defaults to the release name. |
| pvc | object | `{"accessModes":["ReadWriteOnce"],"capacity":"5Gi","enabled":true,"name":"","storageClass":"openebs-zfs"}` | The application PVC. On first creation it is restored from the latest backup via the ReplicationDestination. |
| pvc.accessModes | list | `["ReadWriteOnce"]` | Access modes of the PVC. |
| pvc.capacity | string | `"5Gi"` | Size of the PVC (also used as the restore capacity). |
| pvc.enabled | bool | `true` | Create the PVC. Disable it if the app chart creates its own PVC. |
| pvc.name | string | `""` | PVC name. Defaults to the app name. |
| pvc.storageClass | string | `"openebs-zfs"` | StorageClass of the PVC. |

----------------------------------------------
Autogenerated from chart metadata using [helm-docs v1.14.2](https://github.com/norwoodj/helm-docs/releases/v1.14.2)
