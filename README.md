# Claude Shield

[![npm version](https://img.shields.io/npm/v/claude-shield)](https://www.npmjs.com/package/claude-shield)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

**Security & protection hooks for Claude Code.** Blocks destructive commands, protects sensitive files, prevents force-push to main/master, and maintains a full audit trail of all tool use.

## What It Does

Claude Shield adds a security layer to Claude Code through [hooks](https://docs.anthropic.com/en/docs/claude-code/hooks):

- **Blocks destructive bash commands** — `rm -rf`, `DROP TABLE`, `git reset --hard`, `chmod 777`, `--force`, `--no-verify`, and more
- **Protects sensitive files** — Prevents writes to `.env`, `*.pem`, `*.key`, `id_rsa`, `credentials.*`, `.npmrc`, and more
- **Prevents force push** — Blocks `git push --force` to `main`/`master` branches
- **Audit trail** — Logs every file modification, bash command, and search to SQLite
- **Configurable** — Add custom blocked patterns, protected files, and protected branches

## Install

### Option 1: Clone (recommended)

```bash
git clone https://github.com/bifrost-mcp/claude-shield.git ~/.claude/tools/claude-shield
```

### Option 2: npm

```bash
npm install -g claude-shield
```

If using npm, find the install path for the next step:

```bash
echo "$(npm root -g)/claude-shield"
```

### Configure Hooks

Add the following to your `~/.claude/settings.json`. If using npm, replace `~/.claude/tools/claude-shield` with the path from the command above.

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": ".*",
        "hooks": [
          {
            "type": "command",
            "command": "bash ~/.claude/tools/claude-shield/hooks/scripts/pre-tool-blocker.sh"
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": ".*",
        "hooks": [
          {
            "type": "command",
            "command": "bash ~/.claude/tools/claude-shield/hooks/scripts/post-tool-auditor.sh"
          }
        ]
      }
    ]
  }
}
```

> **Note:** If you already have hooks in your settings.json, merge the arrays — don't replace them. Multiple hooks can coexist under the same event.

### Verify It's Working

Start a Claude Code session and try a destructive command:

```
You: run rm -rf /tmp/test
Claude Shield: 🛡️ Blocked: rm -rf is a destructive command
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
| `rm -r -f` (separate flags) | `rm -r -f /important` |
| `git commit --no-verify` | `git commit --no-verify -m 'msg'` |
| `git push --force` to main/master | `git push --force origin main` |

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

No data is sent anywhere. Everything stays on your machine.

## Requirements

- Claude Code (with hooks support)
- `bash` 3.2+ (ships with macOS)
- `jq` (`brew install jq` on macOS, `apt install jq` on Linux)
- `sqlite3` (pre-installed on macOS and most Linux distributions)

If `jq` or `sqlite3` are missing, Claude Shield will silently disable itself rather than break Claude Code.

## Tests

```bash
npm test
# or
bash tests/run.sh
```

79 tests covering pattern matching, DB operations, hook I/O, config toggles, custom patterns, SQL injection prevention, and edge cases.

## License

MIT
