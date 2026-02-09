#!/bin/bash
# Claude Shield — Post Tool Use Auditor
# Event: PostToolUse
# Purpose: Log all file modifications and bash commands to SQLite audit trail

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$SCRIPT_DIR/../../lib"

# Source helpers
source "$LIB_DIR/db.sh"

# Read hook input from stdin
INPUT=$(cat)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty')
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')

if [ -z "$TOOL_NAME" ]; then
    exit 0
fi

# Check if audit logging is enabled
ensure_config
AUDIT_ENABLED=$(config_get "audit_logging" "true")
if [ "$AUDIT_ENABLED" != "true" ]; then
    exit 0
fi

ensure_db

# Log based on tool type
case "$TOOL_NAME" in
    Bash)
        COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')
        db_insert_audit "$SESSION_ID" "$TOOL_NAME" "execute" "" "$COMMAND" ""
        ;;
    Write)
        FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')
        db_insert_audit "$SESSION_ID" "$TOOL_NAME" "write" "$FILE_PATH" "" "File created/overwritten"
        ;;
    Edit)
        FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')
        db_insert_audit "$SESSION_ID" "$TOOL_NAME" "edit" "$FILE_PATH" "" "File modified"
        ;;
    Read)
        FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')
        db_insert_audit "$SESSION_ID" "$TOOL_NAME" "read" "$FILE_PATH" "" ""
        ;;
    Glob|Grep)
        PATTERN=$(echo "$INPUT" | jq -r '.tool_input.pattern // empty')
        db_insert_audit "$SESSION_ID" "$TOOL_NAME" "search" "" "" "Pattern: $PATTERN"
        ;;
    *)
        db_insert_audit "$SESSION_ID" "$TOOL_NAME" "other" "" "" ""
        ;;
esac

exit 0
