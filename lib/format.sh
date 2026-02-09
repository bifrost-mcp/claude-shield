#!/bin/bash
# Claude Shield — Output formatting helpers

# Format a count with label
fmt_count() {
    local count="${1:-0}"
    local label="${2:-items}"
    if [ "$count" -eq 1 ]; then
        # Singularize common labels
        label=$(echo "$label" | sed 's/s$//')
    fi
    echo "${count} ${label}"
}

# Format timestamp for display (strip seconds)
fmt_time() {
    local ts="${1:-}"
    echo "$ts" | sed 's/:[0-9][0-9]$//'
}

# Shield status emoji
fmt_status_emoji() {
    local blocked="${1:-0}"
    if [ "$blocked" -gt 0 ]; then
        echo "🛡️"
    else
        echo "✅"
    fi
}

# Rule type to human-readable label
fmt_rule_type() {
    local rule_type="${1:-unknown}"
    case "$rule_type" in
        destructive_command) echo "Destructive Command" ;;
        protected_file)     echo "Protected File" ;;
        force_push)         echo "Force Push" ;;
        custom_command)     echo "Custom Command Rule" ;;
        custom_file)        echo "Custom File Rule" ;;
        *)                  echo "$rule_type" ;;
    esac
}

# Format protection status line
fmt_protection_status() {
    local feature="$1"
    local enabled="$2"
    if [ "$enabled" = "true" ]; then
        echo "  ✅ $feature: enabled"
    else
        echo "  ❌ $feature: disabled"
    fi
}
