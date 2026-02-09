#!/bin/bash
# Claude Shield — Pre Tool Use Blocker
# Event: PreToolUse
# Purpose: Block destructive commands, writes to protected files, force push to main/master

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$SCRIPT_DIR/../../lib"

# Source helpers
source "$LIB_DIR/patterns.sh"
source "$LIB_DIR/db.sh"

# Read hook input from stdin
INPUT=$(cat)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty')
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')

if [ -z "$TOOL_NAME" ]; then
    exit 0
fi

# Check if shield is enabled
ensure_config
ENABLED=$(config_get "enabled" "true")
if [ "$ENABLED" != "true" ]; then
    exit 0
fi

# Handle Bash tool — check for destructive commands
if [ "$TOOL_NAME" = "Bash" ]; then
    COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')
    if [ -z "$COMMAND" ]; then
        exit 0
    fi

    BLOCK_CMDS=$(config_get "block_destructive_commands" "true")
    BLOCK_FP=$(config_get "block_force_push" "true")

    if [ "$BLOCK_CMDS" = "true" ] || [ "$BLOCK_FP" = "true" ]; then
        RESULT=$(check_blocked_command "$COMMAND") || true
        if [ -n "$RESULT" ]; then
            IFS='|' read -r rule_type rule_pattern reason <<< "$RESULT"

            # Skip force push blocks if disabled
            if [ "$rule_type" = "force_push" ] && [ "$BLOCK_FP" != "true" ]; then
                exit 0
            fi
            # Skip destructive command blocks if disabled
            if [ "$rule_type" = "destructive_command" ] && [ "$BLOCK_CMDS" != "true" ]; then
                exit 0
            fi

            # Log the blocked attempt
            ensure_db
            db_insert_blocked "$SESSION_ID" "$TOOL_NAME" "$COMMAND" "" "$rule_type" "$rule_pattern" "$reason"

            cat << EOF
{"permissionDecision": "deny", "reason": "🛡️ Claude Shield: $reason"}
EOF
            exit 0
        fi
    fi
fi

# Handle Write/Edit tool — check for protected files
if [ "$TOOL_NAME" = "Write" ] || [ "$TOOL_NAME" = "Edit" ]; then
    FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')
    if [ -z "$FILE_PATH" ]; then
        exit 0
    fi

    BLOCK_FILES=$(config_get "block_protected_files" "true")
    if [ "$BLOCK_FILES" = "true" ]; then
        RESULT=$(check_protected_file "$FILE_PATH") || true
        if [ -n "$RESULT" ]; then
            IFS='|' read -r rule_type rule_pattern reason <<< "$RESULT"

            # Log the blocked attempt
            ensure_db
            db_insert_blocked "$SESSION_ID" "$TOOL_NAME" "" "$FILE_PATH" "$rule_type" "$rule_pattern" "$reason"

            cat << EOF
{"permissionDecision": "deny", "reason": "🛡️ Claude Shield: $reason"}
EOF
            exit 0
        fi
    fi
fi

# Allow — no issues found
exit 0
