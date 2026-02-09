# Shield Status

Show the current Claude Shield protection status, audit log, and blocked attempts.

## Instructions

Query the Claude Shield SQLite database at `~/.claude-shield/audit.db` and produce a status report covering:

1. **Protection Status** — Which protections are enabled (destructive commands, protected files, force push blocking)
2. **Session Summary** — Blocked attempts and audit entries for this session
3. **Recent Blocked Attempts** — Last 10 blocked attempts with timestamps, rule type, and reason
4. **Audit Log** — Last 20 tool uses logged (file edits, bash commands, searches)
5. **Statistics** — Total blocked today, blocked by rule type breakdown

Use bash commands with `sqlite3` to query the database. Read the config from `~/.claude-shield/config.json`. Format output as clean markdown with tables.

If the database doesn't exist, inform the user that Claude Shield needs to be installed first.
