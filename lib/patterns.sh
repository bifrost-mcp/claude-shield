#!/bin/bash
# Claude Shield — Pattern matching for destructive commands and protected files

# Destructive bash command patterns (regex, grep -E compatible on macOS)
# Each pattern is tested against the full command string
# NOTE: macOS grep doesn't support \b — use (^|[^a-zA-Z0-9]) boundaries instead
BLOCKED_COMMANDS=(
    'rm[[:space:]]+(-[a-zA-Z]*)?r[a-zA-Z]*f'       # rm -rf, rm -Rf, rm -fR, etc.
    'rm[[:space:]]+(-[a-zA-Z]*)?f[a-zA-Z]*r'       # rm -fr
    'DROP[[:space:]]+TABLE'                          # SQL drop table
    'DROP[[:space:]]+DATABASE'                       # SQL drop database
    'TRUNCATE[[:space:]]+TABLE'                      # SQL truncate
    ' --force( |$)'                                  # git push --force, etc.
    ' --no-verify( |$)'                              # skip git hooks
    'chmod[[:space:]]+777'                           # world-writable permissions
    'chmod[[:space:]]+-R[[:space:]]+777'             # recursive world-writable
    'mkfs\.'                                         # format filesystem
    'dd[[:space:]]+if='                              # raw disk write
    '>[[:space:]]*/dev/sd'                           # redirect to raw disk
    'git[[:space:]]+reset[[:space:]]+--hard'         # destructive git reset
    'git[[:space:]]+clean[[:space:]]+-[a-zA-Z]*f'   # git clean -f/-fd
    'git[[:space:]]+checkout[[:space:]]+\.'          # discard all changes
    'git[[:space:]]+restore[[:space:]]+\.'           # discard all changes (new syntax)
)

# Protected file patterns (glob-style, matched against full path)
PROTECTED_FILES=(
    '.env'
    '.env.*'
    '.env.local'
    '.env.production'
    '.env.staging'
    'credentials.*'
    '*.pem'
    '*.key'
    '*.p12'
    '*.pfx'
    'id_rsa'
    'id_rsa.*'
    'id_ed25519'
    'id_ed25519.*'
    '*.keystore'
    'secrets.*'
    'service-account*.json'
    'firebase-adminsdk*.json'
    '.npmrc'
    '.pypirc'
)

# Force push to main/master patterns
FORCE_PUSH_PATTERNS=(
    'git[[:space:]]+push[[:space:]]+.*--force( |$)'
    'git[[:space:]]+push[[:space:]]+-f( |$)'
    'git[[:space:]]+push[[:space:]]+.*--force-with-lease'
)

# Main/master branch references for force push detection
PROTECTED_BRANCHES=(
    'main'
    'master'
)

# Check if a command matches any blocked pattern
# Usage: check_blocked_command "rm -rf /"
# Returns: 0 if blocked (with reason on stdout), 1 if allowed
check_blocked_command() {
    local cmd="$1"
    local custom_patterns_file="${SHIELD_CONFIG:-$HOME/.claude-shield/config.json}"

    # Check force push to protected branches FIRST (more specific)
    for fp_pattern in "${FORCE_PUSH_PATTERNS[@]}"; do
        if echo "$cmd" | grep -qEi -- "$fp_pattern"; then
            for branch in "${PROTECTED_BRANCHES[@]}"; do
                if echo "$cmd" | grep -qEi "(^|[^a-zA-Z0-9])$branch([^a-zA-Z0-9]|$)"; then
                    echo "force_push|force_push_${branch}|Blocked force push to protected branch: $branch"
                    return 0
                fi
            done
        fi
    done

    # Check built-in destructive command patterns
    for pattern in "${BLOCKED_COMMANDS[@]}"; do
        if echo "$cmd" | grep -qEi -- "$pattern"; then
            echo "destructive_command|$pattern|Blocked destructive command matching: $pattern"
            return 0
        fi
    done

    # Check custom blocked patterns from config
    if [ -f "$custom_patterns_file" ]; then
        local custom_cmds
        custom_cmds=$(jq -r '.blocked_commands[]? // empty' "$custom_patterns_file" 2>/dev/null)
        while IFS= read -r custom_pattern; do
            if [ -n "$custom_pattern" ] && echo "$cmd" | grep -qEi -- "$custom_pattern"; then
                echo "custom_command|$custom_pattern|Blocked by custom rule: $custom_pattern"
                return 0
            fi
        done <<< "$custom_cmds"
    fi

    return 1
}

# Check if a file path matches any protected pattern
# Usage: check_protected_file "/path/to/.env"
# Returns: 0 if protected (with reason on stdout), 1 if allowed
check_protected_file() {
    local filepath="$1"
    local filename
    filename=$(basename "$filepath")
    local custom_patterns_file="${SHIELD_CONFIG:-$HOME/.claude-shield/config.json}"

    # Check built-in patterns
    for pattern in "${PROTECTED_FILES[@]}"; do
        # Convert glob to regex for matching
        local regex_pattern
        regex_pattern=$(echo "$pattern" | sed 's/\./\\./g' | sed 's/\*/[^\/]*/g')

        if echo "$filename" | grep -qEi "^${regex_pattern}$"; then
            echo "protected_file|$pattern|Blocked write to protected file matching: $pattern"
            return 0
        fi
    done

    # Check custom protected patterns from config
    if [ -f "$custom_patterns_file" ]; then
        local custom_files
        custom_files=$(jq -r '.protected_files[]? // empty' "$custom_patterns_file" 2>/dev/null)
        while IFS= read -r custom_pattern; do
            if [ -n "$custom_pattern" ]; then
                local regex_pattern
                regex_pattern=$(echo "$custom_pattern" | sed 's/\./\\./g' | sed 's/\*/[^\/]*/g')
                if echo "$filename" | grep -qEi "^${regex_pattern}$"; then
                    echo "custom_file|$custom_pattern|Blocked by custom file rule: $custom_pattern"
                    return 0
                fi
            fi
        done <<< "$custom_files"
    fi

    return 1
}
