# journald (local role)

Example of a **project-local role**: something the collection does not do yet.
Sets journald storage, disk cap and retention.

| Variable | Default |
|---|---|
| `journald_max_use` | `1G` |
| `journald_max_retention` | `1month` |
| `journald_storage` | `persistent` |

Marked `UPSTREAM-CANDIDATE` — generic enough to move into the collection's `core` role.
