#!/bin/bash
# Claude Shield — Test Suite
# Validates: pattern matching, DB operations, formatting, hook I/O, blocking logic

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR/.."
LIB_DIR="$PROJECT_DIR/lib"

# Use a temp dir for testing
export CLAUDE_SHIELD_DIR=$(mktemp -d)
export SHIELD_CONFIG="$CLAUDE_SHIELD_DIR/config.json"
trap "rm -rf $CLAUDE_SHIELD_DIR" EXIT

PASS=0
FAIL=0

assert_eq() {
    local label="$1" expected="$2" actual="$3"
    if [ "$expected" = "$actual" ]; then
        echo "  PASS: $label"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $label (expected '$expected', got '$actual')"
        FAIL=$((FAIL + 1))
    fi
}

assert_contains() {
    local label="$1" expected="$2" actual="$3"
    if echo "$actual" | grep -q "$expected"; then
        echo "  PASS: $label"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $label (expected to contain '$expected', got '$actual')"
        FAIL=$((FAIL + 1))
    fi
}

assert_empty() {
    local label="$1" actual="$2"
    if [ -z "$actual" ]; then
        echo "  PASS: $label"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $label (expected empty, got '$actual')"
        FAIL=$((FAIL + 1))
    fi
}

assert_exit_code() {
    local label="$1" expected="$2" actual="$3"
    if [ "$expected" = "$actual" ]; then
        echo "  PASS: $label"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $label (expected exit $expected, got $actual)"
        FAIL=$((FAIL + 1))
    fi
}

echo "=== Claude Shield Test Suite ==="
echo ""

# ─────────────────────────────────────────
echo "--- Test: lib/patterns.sh — Destructive Commands ---"
source "$LIB_DIR/patterns.sh"

# Test 1: rm -rf blocked
RESULT=$(check_blocked_command "rm -rf /tmp/test" || true)
assert_contains "rm -rf blocked" "destructive_command" "$RESULT"

# Test 2: rm -Rf blocked
RESULT=$(check_blocked_command "rm -Rf /foo" || true)
assert_contains "rm -Rf blocked" "destructive_command" "$RESULT"

# Test 3: rm -fr blocked
RESULT=$(check_blocked_command "rm -fr /bar" || true)
assert_contains "rm -fr blocked" "destructive_command" "$RESULT"

# Test 4: DROP TABLE blocked
RESULT=$(check_blocked_command "sqlite3 test.db 'DROP TABLE users;'" || true)
assert_contains "DROP TABLE blocked" "destructive_command" "$RESULT"

# Test 5: git push --force to main blocked as force_push
RESULT=$(check_blocked_command "git push --force origin main" || true)
assert_contains "git push --force main blocked" "force_push" "$RESULT"

# Test 6: --no-verify blocked as destructive_command
RESULT=$(check_blocked_command "git commit --no-verify -m 'skip'" || true)
assert_contains "--no-verify blocked" "destructive_command" "$RESULT"

# Test 6b: --force on non-git command blocked as destructive
RESULT=$(check_blocked_command "npm install --force" || true)
assert_contains "--force on non-git blocked" "destructive_command" "$RESULT"

# Test 7: chmod 777 blocked
RESULT=$(check_blocked_command "chmod 777 /etc/passwd" || true)
assert_contains "chmod 777 blocked" "destructive_command" "$RESULT"

# Test 8: git reset --hard blocked
RESULT=$(check_blocked_command "git reset --hard HEAD~3" || true)
assert_contains "git reset --hard blocked" "destructive_command" "$RESULT"

# Test 9: git clean -f blocked
RESULT=$(check_blocked_command "git clean -fd" || true)
assert_contains "git clean -f blocked" "destructive_command" "$RESULT"

# Test 10: Safe command allowed
RESULT=$(check_blocked_command "ls -la /tmp") || true
assert_empty "ls -la allowed" "$RESULT"

# Test 11: Safe rm (no -rf) allowed
RESULT=$(check_blocked_command "rm test.txt") || true
assert_empty "rm without -rf allowed" "$RESULT"

# Test 12: Safe git push allowed
RESULT=$(check_blocked_command "git push origin feature-branch") || true
assert_empty "safe git push allowed" "$RESULT"

echo ""

# ─────────────────────────────────────────
echo "--- Test: lib/patterns.sh — Protected Files ---"

# Test 13: .env blocked
RESULT=$(check_protected_file "/path/to/.env" || true)
assert_contains ".env blocked" "protected_file" "$RESULT"

# Test 14: .env.local blocked
RESULT=$(check_protected_file "/app/.env.local" || true)
assert_contains ".env.local blocked" "protected_file" "$RESULT"

# Test 15: .env.production blocked
RESULT=$(check_protected_file "/app/.env.production" || true)
assert_contains ".env.production blocked" "protected_file" "$RESULT"

# Test 16: credentials.json blocked
RESULT=$(check_protected_file "/secrets/credentials.json" || true)
assert_contains "credentials.json blocked" "protected_file" "$RESULT"

# Test 17: *.pem blocked
RESULT=$(check_protected_file "/certs/server.pem" || true)
assert_contains "*.pem blocked" "protected_file" "$RESULT"

# Test 18: *.key blocked
RESULT=$(check_protected_file "/ssl/private.key" || true)
assert_contains "*.key blocked" "protected_file" "$RESULT"

# Test 19: id_rsa blocked
RESULT=$(check_protected_file "/home/user/.ssh/id_rsa" || true)
assert_contains "id_rsa blocked" "protected_file" "$RESULT"

# Test 20: .npmrc blocked
RESULT=$(check_protected_file "/project/.npmrc" || true)
assert_contains ".npmrc blocked" "protected_file" "$RESULT"

# Test 21: Normal file allowed
RESULT=$(check_protected_file "/src/index.ts") || true
assert_empty "index.ts allowed" "$RESULT"

# Test 22: Normal config allowed
RESULT=$(check_protected_file "/app/config.ts") || true
assert_empty "config.ts allowed" "$RESULT"

echo ""

# ─────────────────────────────────────────
echo "--- Test: lib/db.sh ---"
source "$LIB_DIR/db.sh"

# Test 23: DB initialization
ensure_db
assert_eq "DB file created" "true" "$([ -f "$SHIELD_DB" ] && echo true || echo false)"

# Test 24: Config initialization
ensure_config
assert_eq "Config file created" "true" "$([ -f "$SHIELD_CONFIG" ] && echo true || echo false)"

# Test 25: Config read defaults
RESULT=$(config_get "enabled" "true")
assert_eq "Config enabled default" "true" "$RESULT"

# Test 26: Config read block_destructive_commands
RESULT=$(config_get "block_destructive_commands" "true")
assert_eq "Config block_destructive_commands default" "true" "$RESULT"

# Test 27: Insert blocked attempt
db_insert_blocked "test-session-001" "Bash" "rm -rf /" "" "destructive_command" "rm.*-rf" "Blocked destructive command"
RESULT=$(sqlite3 "$SHIELD_DB" "SELECT COUNT(*) FROM blocked_attempts WHERE session_id = 'test-session-001';")
assert_eq "Blocked attempt inserted" "1" "$RESULT"

# Test 28: Insert audit log
db_insert_audit "test-session-001" "Write" "write" "/src/app.ts" "" "File created"
RESULT=$(sqlite3 "$SHIELD_DB" "SELECT COUNT(*) FROM audit_log WHERE session_id = 'test-session-001';")
assert_eq "Audit log inserted" "1" "$RESULT"

# Test 29: Blocked today count
RESULT=$(db_blocked_today)
assert_eq "Blocked today count" "1" "$RESULT"

# Test 30: Blocked session count
RESULT=$(db_blocked_session "test-session-001")
assert_eq "Blocked session count" "1" "$RESULT"

# Test 31: Audit today count
RESULT=$(db_audit_today)
assert_eq "Audit today count" "1" "$RESULT"

# Test 32: Recent blocked
RESULT=$(db_recent_blocked 5)
assert_contains "Recent blocked has data" "destructive_command" "$RESULT"

# Test 33: Recent audit
RESULT=$(db_recent_audit 5)
assert_contains "Recent audit has data" "Write" "$RESULT"

# Test 34: Multiple inserts
db_insert_blocked "test-session-001" "Write" "" "/app/.env" "protected_file" ".env" "Blocked protected file"
db_insert_audit "test-session-001" "Bash" "execute" "" "ls -la" ""
RESULT=$(db_blocked_session "test-session-001")
assert_eq "Multiple blocked inserts" "2" "$RESULT"

# Test 35: Blocked by type
RESULT=$(db_blocked_by_type)
assert_contains "Blocked by type has destructive_command" "destructive_command" "$RESULT"

# Test 36: Session audit summary
RESULT=$(db_session_audit_summary "test-session-001")
assert_contains "Session summary has Write" "Write" "$RESULT"

echo ""

# ─────────────────────────────────────────
echo "--- Test: lib/format.sh ---"
source "$LIB_DIR/format.sh"

# Test 37: Format count plural
RESULT=$(fmt_count "5" "attempts")
assert_eq "Format count plural" "5 attempts" "$RESULT"

# Test 38: Format count singular
RESULT=$(fmt_count "1" "attempts")
assert_eq "Format count singular" "1 attempt" "$RESULT"

# Test 39: Shield status emoji (blocked)
RESULT=$(fmt_status_emoji "3")
assert_eq "Status emoji blocked" "🛡️" "$RESULT"

# Test 40: Shield status emoji (clean)
RESULT=$(fmt_status_emoji "0")
assert_eq "Status emoji clean" "✅" "$RESULT"

# Test 41: Rule type formatting
RESULT=$(fmt_rule_type "destructive_command")
assert_eq "Rule type destructive" "Destructive Command" "$RESULT"

RESULT=$(fmt_rule_type "protected_file")
assert_eq "Rule type protected file" "Protected File" "$RESULT"

RESULT=$(fmt_rule_type "force_push")
assert_eq "Rule type force push" "Force Push" "$RESULT"

echo ""

# ─────────────────────────────────────────
echo "--- Test: Hook I/O — PreToolUse Blocker ---"

# Clean DB for hook tests
rm -f "$SHIELD_DB"
ensure_db

# Test 42: Bash rm -rf blocked by hook
RESULT=$(echo '{"session_id":"hook-test-001","tool_name":"Bash","tool_input":{"command":"rm -rf /tmp/important"}}' | bash "$PROJECT_DIR/hooks/scripts/pre-tool-blocker.sh" 2>/dev/null)
DECISION=$(echo "$RESULT" | jq -r '.permissionDecision // empty' 2>/dev/null || echo "")
assert_eq "Hook blocks rm -rf" "deny" "$DECISION"

# Test 43: Blocked reason contains Shield
REASON=$(echo "$RESULT" | jq -r '.reason // empty' 2>/dev/null || echo "")
assert_contains "Blocked reason has Shield" "Claude Shield" "$REASON"

# Test 44: Write to .env blocked by hook
RESULT=$(echo '{"session_id":"hook-test-002","tool_name":"Write","tool_input":{"file_path":"/project/.env"}}' | bash "$PROJECT_DIR/hooks/scripts/pre-tool-blocker.sh" 2>/dev/null)
DECISION=$(echo "$RESULT" | jq -r '.permissionDecision // empty' 2>/dev/null || echo "")
assert_eq "Hook blocks .env write" "deny" "$DECISION"

# Test 45: Edit to .pem blocked by hook
RESULT=$(echo '{"session_id":"hook-test-003","tool_name":"Edit","tool_input":{"file_path":"/certs/server.pem"}}' | bash "$PROJECT_DIR/hooks/scripts/pre-tool-blocker.sh" 2>/dev/null)
DECISION=$(echo "$RESULT" | jq -r '.permissionDecision // empty' 2>/dev/null || echo "")
assert_eq "Hook blocks .pem edit" "deny" "$DECISION"

# Test 46: Safe command allowed by hook
RESULT=$(echo '{"session_id":"hook-test-004","tool_name":"Bash","tool_input":{"command":"echo hello"}}' | bash "$PROJECT_DIR/hooks/scripts/pre-tool-blocker.sh" 2>/dev/null)
assert_empty "Hook allows safe command" "$RESULT"

# Test 47: Safe file write allowed by hook
RESULT=$(echo '{"session_id":"hook-test-005","tool_name":"Write","tool_input":{"file_path":"/src/index.ts"}}' | bash "$PROJECT_DIR/hooks/scripts/pre-tool-blocker.sh" 2>/dev/null)
assert_empty "Hook allows safe file write" "$RESULT"

# Test 48: Blocked attempts logged to DB
RESULT=$(sqlite3 "$SHIELD_DB" "SELECT COUNT(*) FROM blocked_attempts WHERE session_id LIKE 'hook-test-%';")
assert_eq "Hook logged blocked attempts" "3" "$RESULT"

echo ""

# ─────────────────────────────────────────
echo "--- Test: Hook I/O — PostToolUse Auditor ---"

# Test 49: Bash command logged
RESULT=$(echo '{"session_id":"audit-test-001","tool_name":"Bash","tool_input":{"command":"npm install"}}' | bash "$PROJECT_DIR/hooks/scripts/post-tool-auditor.sh" 2>/dev/null)
EXIT_CODE=$?
assert_eq "Auditor exits 0 for Bash" "0" "$EXIT_CODE"

# Test 50: Write logged
RESULT=$(echo '{"session_id":"audit-test-001","tool_name":"Write","tool_input":{"file_path":"/src/app.ts"}}' | bash "$PROJECT_DIR/hooks/scripts/post-tool-auditor.sh" 2>/dev/null)
EXIT_CODE=$?
assert_eq "Auditor exits 0 for Write" "0" "$EXIT_CODE"

# Test 51: Edit logged
RESULT=$(echo '{"session_id":"audit-test-001","tool_name":"Edit","tool_input":{"file_path":"/src/utils.ts"}}' | bash "$PROJECT_DIR/hooks/scripts/post-tool-auditor.sh" 2>/dev/null)
EXIT_CODE=$?
assert_eq "Auditor exits 0 for Edit" "0" "$EXIT_CODE"

# Test 52: Read logged
RESULT=$(echo '{"session_id":"audit-test-001","tool_name":"Read","tool_input":{"file_path":"/src/config.ts"}}' | bash "$PROJECT_DIR/hooks/scripts/post-tool-auditor.sh" 2>/dev/null)
EXIT_CODE=$?
assert_eq "Auditor exits 0 for Read" "0" "$EXIT_CODE"

# Test 53: Verify audit entries were created
RESULT=$(sqlite3 "$SHIELD_DB" "SELECT COUNT(*) FROM audit_log WHERE session_id = 'audit-test-001';")
assert_eq "Auditor logged 4 entries" "4" "$RESULT"

# Test 54: Verify correct actions logged
RESULT=$(sqlite3 "$SHIELD_DB" "SELECT action FROM audit_log WHERE session_id = 'audit-test-001' AND tool_name = 'Bash';")
assert_eq "Bash action is execute" "execute" "$RESULT"

RESULT=$(sqlite3 "$SHIELD_DB" "SELECT action FROM audit_log WHERE session_id = 'audit-test-001' AND tool_name = 'Write';")
assert_eq "Write action is write" "write" "$RESULT"

RESULT=$(sqlite3 "$SHIELD_DB" "SELECT action FROM audit_log WHERE session_id = 'audit-test-001' AND tool_name = 'Edit';")
assert_eq "Edit action is edit" "edit" "$RESULT"

echo ""

# ─────────────────────────────────────────
echo "--- Test: Config Toggles ---"

# Test 55: Disable shield entirely
cat > "$SHIELD_CONFIG" << 'CONF'
{
    "enabled": false,
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

RESULT=$(echo '{"session_id":"config-test-001","tool_name":"Bash","tool_input":{"command":"rm -rf /"}}' | bash "$PROJECT_DIR/hooks/scripts/pre-tool-blocker.sh" 2>/dev/null)
assert_empty "Disabled shield allows rm -rf" "$RESULT"

# Test 56: Re-enable shield, disable just destructive commands
cat > "$SHIELD_CONFIG" << 'CONF'
{
    "enabled": true,
    "block_destructive_commands": false,
    "block_protected_files": true,
    "block_force_push": true,
    "audit_logging": true,
    "audit_retention_days": 30,
    "blocked_commands": [],
    "protected_files": [],
    "protected_branches": ["main", "master"]
}
CONF

RESULT=$(echo '{"session_id":"config-test-002","tool_name":"Bash","tool_input":{"command":"rm -rf /tmp"}}' | bash "$PROJECT_DIR/hooks/scripts/pre-tool-blocker.sh" 2>/dev/null)
assert_empty "Disabled destructive cmds allows rm -rf" "$RESULT"

# Test 57: File protection still works when cmd blocking disabled
RESULT=$(echo '{"session_id":"config-test-003","tool_name":"Write","tool_input":{"file_path":"/app/.env"}}' | bash "$PROJECT_DIR/hooks/scripts/pre-tool-blocker.sh" 2>/dev/null)
DECISION=$(echo "$RESULT" | jq -r '.permissionDecision // empty' 2>/dev/null || echo "")
assert_eq "File protection still active" "deny" "$DECISION"

# Test 58: Disable audit logging
cat > "$SHIELD_CONFIG" << 'CONF'
{
    "enabled": true,
    "block_destructive_commands": true,
    "block_protected_files": true,
    "block_force_push": true,
    "audit_logging": false,
    "audit_retention_days": 30,
    "blocked_commands": [],
    "protected_files": [],
    "protected_branches": ["main", "master"]
}
CONF

# Count before
BEFORE=$(sqlite3 "$SHIELD_DB" "SELECT COUNT(*) FROM audit_log;")
echo '{"session_id":"config-test-004","tool_name":"Bash","tool_input":{"command":"echo test"}}' | bash "$PROJECT_DIR/hooks/scripts/post-tool-auditor.sh" 2>/dev/null
AFTER=$(sqlite3 "$SHIELD_DB" "SELECT COUNT(*) FROM audit_log;")
assert_eq "Disabled audit skips logging" "$BEFORE" "$AFTER"

echo ""

# ─────────────────────────────────────────
echo "--- Test: Custom Patterns ---"

# Test 59: Custom blocked command
cat > "$SHIELD_CONFIG" << 'CONF'
{
    "enabled": true,
    "block_destructive_commands": true,
    "block_protected_files": true,
    "block_force_push": true,
    "audit_logging": true,
    "audit_retention_days": 30,
    "blocked_commands": ["npm\\s+publish"],
    "protected_files": ["*.secret"],
    "protected_branches": ["main", "master"]
}
CONF

RESULT=$(check_blocked_command "npm publish --access public" || true)
assert_contains "Custom npm publish blocked" "custom_command" "$RESULT"

# Test 60: Custom protected file
RESULT=$(check_protected_file "/app/database.secret" || true)
assert_contains "Custom .secret blocked" "custom_file" "$RESULT"

echo ""

# ─────────────────────────────────────────
echo "--- Test: Edge Cases ---"

# Test 61: Empty tool input
RESULT=$(echo '{"session_id":"edge-001","tool_name":"Bash","tool_input":{}}' | bash "$PROJECT_DIR/hooks/scripts/pre-tool-blocker.sh" 2>/dev/null)
EXIT_CODE=$?
assert_eq "Empty tool input exits 0" "0" "$EXIT_CODE"

# Test 62: Missing tool_name
RESULT=$(echo '{"session_id":"edge-002"}' | bash "$PROJECT_DIR/hooks/scripts/pre-tool-blocker.sh" 2>/dev/null)
EXIT_CODE=$?
assert_eq "Missing tool_name exits 0" "0" "$EXIT_CODE"

# Test 63: Empty input to auditor
RESULT=$(echo '{"session_id":"edge-003"}' | bash "$PROJECT_DIR/hooks/scripts/post-tool-auditor.sh" 2>/dev/null)
EXIT_CODE=$?
assert_eq "Empty auditor input exits 0" "0" "$EXIT_CODE"

# Test 64: Glob/Grep logged correctly
echo '{"session_id":"edge-004","tool_name":"Grep","tool_input":{"pattern":"TODO"}}' | bash "$PROJECT_DIR/hooks/scripts/post-tool-auditor.sh" 2>/dev/null
RESULT=$(sqlite3 "$SHIELD_DB" "SELECT details FROM audit_log WHERE session_id = 'edge-004' AND tool_name = 'Grep';")
assert_contains "Grep pattern logged" "TODO" "$RESULT"

# Test 65: DB purge old entries
db_insert_audit "old-session" "Bash" "execute" "" "ls" ""
sqlite3 "$SHIELD_DB" "UPDATE audit_log SET timestamp = datetime('now', '-60 days') WHERE session_id = 'old-session';"
db_purge_old 30
RESULT=$(sqlite3 "$SHIELD_DB" "SELECT COUNT(*) FROM audit_log WHERE session_id = 'old-session';")
assert_eq "Purge removes old entries" "0" "$RESULT"

echo ""

# ─────────────────────────────────────────
echo "==================================="
echo "Results: $PASS passed, $FAIL failed"
echo "==================================="

if [ "$FAIL" -gt 0 ]; then
    exit 1
fi
exit 0
