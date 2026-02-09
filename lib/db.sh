#!/bin/bash
# Claude Shield — SQLite helper functions

SHIELD_DIR="${CLAUDE_SHIELD_DIR:-$HOME/.claude-shield}"
SHIELD_DB="$SHIELD_DIR/audit.db"
SHIELD_CONFIG="$SHIELD_DIR/config.json"

# Ensure database exists and is initialized
ensure_db() {
    if [ ! -f "$SHIELD_DB" ]; then
        local schema_dir
        schema_dir="$(dirname "${BASH_SOURCE[0]}")/../data"
        mkdir -p "$SHIELD_DIR"
        sqlite3 "$SHIELD_DB" < "$schema_dir/schema.sql"
    fi
}

# Ensure config exists with defaults
ensure_config() {
    if [ ! -f "$SHIELD_CONFIG" ]; then
        mkdir -p "$SHIELD_DIR"
        cat > "$SHIELD_CONFIG" << 'CONF'
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
CONF
    fi
}

# Read a config value
# Usage: config_get KEY [DEFAULT]
config_get() {
    local key="$1"
    local default="${2:-}"
    ensure_config
    local val
    # Use has() check to handle false/null correctly — jq's // treats false as falsy
    val=$(jq -r "if has(\"$key\") then .$key | tostring else empty end" "$SHIELD_CONFIG" 2>/dev/null)
    echo "${val:-$default}"
}

# Insert a blocked attempt record
# Usage: db_insert_blocked SESSION_ID TOOL_NAME COMMAND FILE_PATH RULE_TYPE RULE_PATTERN REASON
db_insert_blocked() {
    ensure_db
    local session_id tool_name command file_path rule_type rule_pattern reason
    session_id=$(echo "${1:-}" | sed "s/'/''/g")
    tool_name=$(echo "${2:-}" | sed "s/'/''/g")
    command=$(echo "${3:-}" | sed "s/'/''/g")
    file_path=$(echo "${4:-}" | sed "s/'/''/g")
    rule_type=$(echo "${5:-}" | sed "s/'/''/g")
    rule_pattern=$(echo "${6:-}" | sed "s/'/''/g")
    reason=$(echo "${7:-}" | sed "s/'/''/g")
    sqlite3 "$SHIELD_DB" "INSERT INTO blocked_attempts (session_id, tool_name, command, file_path, rule_type, rule_pattern, reason) VALUES ('$session_id', '$tool_name', '$command', '$file_path', '$rule_type', '$rule_pattern', '$reason');"
}

# Insert an audit log record
# Usage: db_insert_audit SESSION_ID TOOL_NAME ACTION FILE_PATH COMMAND DETAILS
db_insert_audit() {
    ensure_db
    local session_id tool_name action file_path command details
    session_id=$(echo "${1:-}" | sed "s/'/''/g")
    tool_name=$(echo "${2:-}" | sed "s/'/''/g")
    action=$(echo "${3:-}" | sed "s/'/''/g")
    file_path=$(echo "${4:-}" | sed "s/'/''/g")
    command=$(echo "${5:-}" | sed "s/'/''/g")
    details=$(echo "${6:-}" | sed "s/'/''/g")
    sqlite3 "$SHIELD_DB" "INSERT INTO audit_log (session_id, tool_name, action, file_path, command, details) VALUES ('$session_id', '$tool_name', '$action', '$file_path', '$command', '$details');"
}

# Get count of blocked attempts today
db_blocked_today() {
    ensure_db
    sqlite3 "$SHIELD_DB" "SELECT COUNT(*) FROM blocked_attempts WHERE date(timestamp) = date('now');"
}

# Get count of blocked attempts for a session
db_blocked_session() {
    local session_id
    session_id=$(echo "${1:-}" | sed "s/'/''/g")
    ensure_db
    sqlite3 "$SHIELD_DB" "SELECT COUNT(*) FROM blocked_attempts WHERE session_id = '$session_id';"
}

# Get recent blocked attempts
# Usage: db_recent_blocked [LIMIT]
db_recent_blocked() {
    local limit="${1:-10}"
    ensure_db
    sqlite3 -separator '|' "$SHIELD_DB" "
        SELECT timestamp, tool_name, rule_type, rule_pattern, reason
        FROM blocked_attempts
        ORDER BY timestamp DESC
        LIMIT $limit;
    "
}

# Get audit log entries
# Usage: db_recent_audit [LIMIT]
db_recent_audit() {
    local limit="${1:-20}"
    ensure_db
    sqlite3 -separator '|' "$SHIELD_DB" "
        SELECT timestamp, tool_name, action, file_path, command
        FROM audit_log
        ORDER BY timestamp DESC
        LIMIT $limit;
    "
}

# Get audit log count today
db_audit_today() {
    ensure_db
    sqlite3 "$SHIELD_DB" "SELECT COUNT(*) FROM audit_log WHERE date(timestamp) = date('now');"
}

# Get blocked attempts by rule type
db_blocked_by_type() {
    ensure_db
    sqlite3 -separator '|' "$SHIELD_DB" "
        SELECT rule_type, COUNT(*) as count
        FROM blocked_attempts
        GROUP BY rule_type
        ORDER BY count DESC;
    "
}

# Purge old audit entries beyond retention period
db_purge_old() {
    local days="${1:-30}"
    ensure_db
    sqlite3 "$SHIELD_DB" "DELETE FROM audit_log WHERE timestamp < datetime('now', '-$days days');"
    sqlite3 "$SHIELD_DB" "DELETE FROM blocked_attempts WHERE timestamp < datetime('now', '-$days days');"
}

# Get session audit summary
db_session_audit_summary() {
    local session_id
    session_id=$(echo "${1:-}" | sed "s/'/''/g")
    ensure_db
    sqlite3 -separator '|' "$SHIELD_DB" "
        SELECT tool_name, action, COUNT(*) as count
        FROM audit_log
        WHERE session_id = '$session_id'
        GROUP BY tool_name, action
        ORDER BY count DESC;
    "
}
