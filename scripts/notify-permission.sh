#!/bin/bash
# Only notify if tool requires permission - reads allowed list from settings.json

SETTINGS_FILE="$HOME/.claude/settings.json"

# Read JSON input from stdin
INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // ""')
TOOL_INPUT=$(echo "$INPUT" | jq -r '.tool_input.command // .tool_input // ""')

# Get allowed and denied lists from settings.json
ALLOWED_LIST=$(jq -r '.permissions.allow[]' "$SETTINGS_FILE" 2>/dev/null)
DENIED_LIST=$(jq -r '.permissions.deny[]' "$SETTINGS_FILE" 2>/dev/null)

# Convert Claude Code pattern to regex
# Rule: If pattern contains space, * matches anything
#       If pattern has no space, * matches non-space only
pattern_to_regex() {
    local pattern="$1"
    # Escape special regex chars except *
    local escaped=$(echo "$pattern" | sed 's/[.^$+?{}|()\\[\\]]/\\&/g')

    if [[ "$pattern" == *" "* ]]; then
        # Pattern has space - * matches anything
        local regex=$(echo "$escaped" | sed 's/\*/.*/g')
    else
        # Pattern has no space - * matches non-space only
        local regex=$(echo "$escaped" | sed 's/\*/[^ ]*/g')
    fi
    echo "^${regex}$"
}

# Check if tool is denied
is_denied() {
    local tool="$1"
    local input="$2"

    while IFS= read -r pattern; do
        [[ -z "$pattern" ]] && continue

        if [[ "$pattern" =~ ^${tool}\((.+)\)$ ]]; then
            local cmd_pattern="${BASH_REMATCH[1]}"
            local regex=$(pattern_to_regex "$cmd_pattern")
            if [[ "$input" =~ $regex ]]; then
                return 0
            fi
        fi
    done <<< "$DENIED_LIST"

    return 1
}

# Check if tool is allowed
is_allowed() {
    local tool="$1"
    local input="$2"

    # First check if denied
    if is_denied "$tool" "$input"; then
        return 1
    fi

    while IFS= read -r pattern; do
        [[ -z "$pattern" ]] && continue

        # Direct tool match (e.g., "Read", "WebFetch")
        if [[ "$pattern" == "$tool" ]]; then
            return 0
        fi

        # Tool with pattern (e.g., "Bash(git status*)")
        if [[ "$pattern" =~ ^${tool}\((.+)\)$ ]]; then
            local cmd_pattern="${BASH_REMATCH[1]}"
            local regex=$(pattern_to_regex "$cmd_pattern")
            if [[ "$input" =~ $regex ]]; then
                return 0
            fi
        fi
    done <<< "$ALLOWED_LIST"

    return 1
}

# Check if this tool+input is allowed
if is_allowed "$TOOL_NAME" "$TOOL_INPUT"; then
    exit 0
fi

# Not allowed - send notification
if [[ "$TOOL_NAME" == "Bash" ]]; then
    SHORT_INPUT=$(echo "$TOOL_INPUT" | head -c 50)
    ~/.claude/notify.sh 'Permission Required' "$SHORT_INPUT" 'Glass' &
elif [[ "$TOOL_NAME" == "Edit" ]] || [[ "$TOOL_NAME" == "Write" ]]; then
    FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // ""')
    ~/.claude/notify.sh 'Permission Required' "$TOOL_NAME: $FILE_PATH" 'Glass' &
else
    ~/.claude/notify.sh 'Permission Required' "$TOOL_NAME" 'Glass' &
fi
