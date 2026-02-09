-- Claude Shield SQLite Schema
-- Tracks blocked attempts and audit log of all tool use

CREATE TABLE IF NOT EXISTS blocked_attempts (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp TEXT NOT NULL DEFAULT (datetime('now')),
    session_id TEXT,
    tool_name TEXT NOT NULL,
    command TEXT,
    file_path TEXT,
    rule_type TEXT NOT NULL,
    rule_pattern TEXT NOT NULL,
    reason TEXT
);

CREATE TABLE IF NOT EXISTS audit_log (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp TEXT NOT NULL DEFAULT (datetime('now')),
    session_id TEXT,
    tool_name TEXT NOT NULL,
    action TEXT NOT NULL,
    file_path TEXT,
    command TEXT,
    details TEXT
);

CREATE TABLE IF NOT EXISTS config (
    key TEXT PRIMARY KEY,
    value TEXT
);

-- Indexes for fast lookups
CREATE INDEX IF NOT EXISTS idx_blocked_timestamp ON blocked_attempts(timestamp);
CREATE INDEX IF NOT EXISTS idx_blocked_session ON blocked_attempts(session_id);
CREATE INDEX IF NOT EXISTS idx_blocked_rule_type ON blocked_attempts(rule_type);
CREATE INDEX IF NOT EXISTS idx_audit_timestamp ON audit_log(timestamp);
CREATE INDEX IF NOT EXISTS idx_audit_session ON audit_log(session_id);
CREATE INDEX IF NOT EXISTS idx_audit_tool ON audit_log(tool_name);
