# Shield Configuration

View and update Claude Shield protection settings.

## Instructions

Read the current config from `~/.claude-shield/config.json` and display all settings.

If the user wants to change a setting, update the config file. Available settings:

| Setting | Type | Default | Description |
|---------|------|---------|-------------|
| `enabled` | boolean | true | Master switch for all protections |
| `block_destructive_commands` | boolean | true | Block rm -rf, DROP TABLE, etc. |
| `block_protected_files` | boolean | true | Block writes to .env, *.pem, etc. |
| `block_force_push` | boolean | true | Block force push to main/master |
| `audit_logging` | boolean | true | Log all tool use to audit trail |
| `audit_retention_days` | number | 30 | Days to keep audit log entries |
| `blocked_commands` | array | [] | Custom command patterns to block (regex) |
| `protected_files` | array | [] | Custom file patterns to protect (glob) |
| `protected_branches` | array | ["main", "master"] | Branches protected from force push |

To add a custom blocked command pattern:
```bash
jq '.blocked_commands += ["pattern"]' ~/.claude-shield/config.json > /tmp/shield-config.json && mv /tmp/shield-config.json ~/.claude-shield/config.json
```

To add a custom protected file pattern:
```bash
jq '.protected_files += ["pattern"]' ~/.claude-shield/config.json > /tmp/shield-config.json && mv /tmp/shield-config.json ~/.claude-shield/config.json
```

If the config file doesn't exist, create it with defaults.
