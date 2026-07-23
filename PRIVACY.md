# Privacy

TaskMatrix is designed as a local-first macOS app.

## Summary

- TaskMatrix stores task data on the user's Mac.
- TaskMatrix does not include analytics, advertising, telemetry, crash reporting
  SDKs, or third-party network services.
- TaskMatrix can optionally sync task data through the user's own iCloud account
  when a build is signed with the iCloud key-value storage entitlement.
- Open-source forks may change behavior; review the source and release notes for
  the build you install.

## Data Stored Locally

Task data is stored as JSON inside the app's sandbox container:

```text
~/Library/Containers/<bundle-id>/Data/Library/Application Support/TaskMatrix/tasks.json
```

For the default open-source bundle identifier, the path is:

```text
~/Library/Containers/io.github.noah-ls.TaskMatrix/Data/Library/Application Support/TaskMatrix/tasks.json
```

The data can include:

- Task titles.
- Subtask titles.
- Quadrant assignment.
- Due dates.
- Completion state and completion dates.
- Archive dates.
- Pinning state.
- Sort order metadata.

## iCloud Sync

If the app is signed with the iCloud key-value storage entitlement, TaskMatrix
can mirror task data into Apple's iCloud key-value store for the user's Apple
account.

The maintainers do not operate a sync server and do not receive synced data.
Apple's iCloud service handles storage and transport according to the user's
Apple account and system settings.

Without the iCloud entitlement, TaskMatrix remains device-local.

## Network Services

TaskMatrix does not send data to project maintainers. It does not include:

- Product analytics.
- Advertising SDKs.
- Telemetry.
- Third-party crash reporting.
- Third-party sync providers.

macOS or iCloud may still perform system-level diagnostics or sync behavior
outside TaskMatrix's control.

## Deleting Data

Users can delete individual tasks inside the app. Removing the app container
removes local task data.

If iCloud sync was enabled in a signed build, synced data may also exist in the
user's iCloud key-value store according to Apple's iCloud behavior. Disable
iCloud sync or remove app data from iCloud according to Apple's platform tools
when needed.

## Security Reports

Report privacy or security vulnerabilities using `SECURITY.md`.
