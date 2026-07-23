# Privacy

TaskMatrix is designed as a local-first macOS app.

## Data Stored

Task data is stored as JSON inside the app's sandbox container:

```text
~/Library/Containers/<bundle-id>/Data/Library/Application Support/TaskMatrix/tasks.json
```

The data can include task titles, subtasks, due dates, completion dates, archive
dates, and ordering metadata.

## Network and Sync

TaskMatrix does not include analytics, advertising, telemetry, or third-party
network services.

If the app is signed with the iCloud key-value storage entitlement, task data can
sync through the user's own iCloud account. Without that entitlement, the app
remains device-local.

## User Control

Deleting the app container removes local task data. If iCloud sync was enabled
in a signed build, synced data may also exist in the user's iCloud key-value
store according to Apple's iCloud behavior.

