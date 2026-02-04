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

# Check if command has file write operators
# These ALWAYS require permission because they write to files
has_write_operators() {
    local cmd="$1"
    # Remove safe redirects: 2>/dev/null, >/dev/null, 2>&1, >&2, etc.
    local cleaned=$(echo "$cmd" | sed -E 's/[0-9]*>[>&][0-9]*//g; s/[0-9]*>\/dev\/null//g')
    # Check for remaining: > >> (actual file redirects)
    if [[ "$cleaned" =~ \>[^\>] ]] || [[ "$cleaned" =~ \>\> ]]; then
        return 0
    fi
    return 1
}

# Convert Claude Code pattern to regex
# Rule: * matches anything (including spaces)
pattern_to_regex() {
    local pattern="$1"
    # Escape special regex chars except *
    local escaped=$(echo "$pattern" | sed 's/[.^$+?{}|()\\[\\]]/\\&/g')
    # * matches anything
    local regex=$(echo "$escaped" | sed 's/\*/.*/g')
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

    # For Bash commands, check file write operators FIRST
    # These always require permission because they write to files
    if [[ "$tool" == "Bash" ]] && has_write_operators "$input"; then
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
# Pass terminal info for Warp tab name support
TERMINAL="${TERM_PROGRAM:-}"

if [[ "$TOOL_NAME" == "Bash" ]]; then
    SHORT_INPUT=$(echo "$TOOL_INPUT" | head -c 50)
    ~/.claude/notify.sh 'Claude Code - Permission Required' "$SHORT_INPUT" 'Glass' "$TERMINAL" &
elif [[ "$TOOL_NAME" == "Edit" ]] || [[ "$TOOL_NAME" == "Write" ]]; then
    FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // ""')
    ~/.claude/notify.sh 'Claude Code - Permission Required' "$TOOL_NAME: $FILE_PATH" 'Glass' "$TERMINAL" &
else
    ~/.claude/notify.sh 'Claude Code - Permission Required' "$TOOL_NAME" 'Glass' "$TERMINAL" &
fi
