# Claude Shield

Security & protection hooks for Claude Code. Blocks destructive commands, protects sensitive files, prevents force-push to main/master, and maintains a full audit trail of all tool use.

## What It Does

Claude Shield adds a security layer to Claude Code through hooks:

- **Blocks destructive bash commands** — `rm -rf`, `DROP TABLE`, `git reset --hard`, `chmod 777`, `--force`, `--no-verify`, and more
- **Protects sensitive files** — Prevents writes to `.env`, `*.pem`, `*.key`, `id_rsa`, `credentials.*`, `.npmrc`, and more
- **Prevents force push** — Blocks `git push --force` to `main`/`master` branches
- **Audit trail** — Logs every file modification, bash command, and search to SQLite
- **Configurable** — Add custom blocked patterns, protected files, and protected branches

## Install

```bash
npm install -g claude-shield
```

Then add to your Claude Code settings (`~/.claude/settings.json`):

```json
{
  "plugins": ["claude-shield"]
}
```

## How It Works

### PreToolUse Hook — Security Blocker

Intercepts every tool call before execution. If a destructive command or protected file write is detected, the hook returns `{"permissionDecision": "deny"}` with a reason, preventing Claude Code from executing the action.

**Blocked commands include:**
| Pattern | Example |
|---------|---------|
| `rm -rf` | `rm -rf /`, `rm -Rf ./src` |
| `DROP TABLE` | `sqlite3 db 'DROP TABLE users'` |
| `git reset --hard` | `git reset --hard HEAD~3` |
| `git clean -f` | `git clean -fd` |
| `chmod 777` | `chmod 777 /etc/passwd` |
| `--force` | `npm install --force` |
| `--no-verify` | `git commit --no-verify` |
| `git push --force` to main | `git push --force origin main` |

**Protected files include:**
`.env`, `.env.*`, `credentials.*`, `*.pem`, `*.key`, `id_rsa`, `id_ed25519`, `.npmrc`, `.pypirc`, `secrets.*`, `*.keystore`

### PostToolUse Hook — Audit Logger

Logs every tool use to SQLite (`~/.claude-shield/audit.db`):
- Bash commands executed
- Files written, edited, or read
- Search patterns used (Glob/Grep)

### Commands

- **`/shield`** — View protection status, recent blocked attempts, and audit log
- **`/shield-config`** — View and update protection settings

## Configuration

Config lives at `~/.claude-shield/config.json` (auto-created on first use):

```json
{
    "enabled": true,
    "block_destructive_commands": true,
    "block_protected_files": true,
    "block_force_push": true,
    "audit_logging": true,
    "audit_retention_days": 30,
    "blocked_commands": [],
    "protected_files": [],
    "protected_branches": ["main", "master"]
}
```

### Custom Rules

Add your own blocked command patterns (regex):

```json
{
    "blocked_commands": ["npm\\s+publish", "docker\\s+rm"]
}
```

Add your own protected file patterns (glob):

```json
{
    "protected_files": ["*.secret", "config.production.*"]
}
```

## Data Storage

All data is stored locally in `~/.claude-shield/`:

| File | Purpose |
|------|---------|
| `audit.db` | SQLite database — blocked attempts + audit log |
| `config.json` | Protection settings and custom rules |

## Requirements

- `bash` 4+
- `jq`
- `sqlite3`

All are pre-installed on macOS and most Linux distributions.

## Tests

```bash
npm test
# or
bash tests/run.sh
```

70 tests covering pattern matching, DB operations, hook I/O, config toggles, custom patterns, and edge cases.

## License

MIT
