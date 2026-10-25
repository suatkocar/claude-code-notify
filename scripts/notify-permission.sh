#!/bin/bash
# Only notify if tool requires permission - reads allowed list from settings.json

SETTINGS_FILE="$HOME/.claude/settings.json"
[[ -f "$SETTINGS_FILE" ]] || SETTINGS_FILE=/dev/null

# Same rule as in notify.sh (see there): when it would stay quiet, skip the work below.
stay_quiet() {
    case "${CLAUDE_NOTIFY:-}" in
        off) return 0 ;;
        on) return 1 ;;
    esac
    [[ -n "${GHOSTEX_GLOBAL_SESSION_REF:-}" && -n "${GHOSTEX_GXSERVER_BASE_URL:-}" ]]
}
if stay_quiet; then
    [[ -t 0 ]] || cat >/dev/null
    exit 0
fi

# One jq run reads the hook's JSON from stdin and the allow/deny rules from
# settings.json, and prints "!" plus the notification text only when the call
# would actually prompt. (Spawning sed for every rule took about a second.)
OUTPUT=$(jq -r --slurpfile settings "$SETTINGS_FILE" '
    # Commands that are inherently safe (read-only / navigation). They never
    # need permission, unless they write to a file (checked first).
    def safe_commands: ["cd", "pwd", "ls", "echo", "cat", "head", "tail", "find",
        "grep", "rg", "fd", "ag", "fzf", "wc", "file", "stat", "du", "df", "which",
        "whereis", "whoami", "type", "test", "uname", "date", "hostname", "printenv",
        "env", "basename", "dirname", "realpath", "readlink", "sort", "uniq", "cut",
        "tr", "jq", "yq", "diff", "tree", "md5", "shasum", "sha256sum"];

    # A rule such as "git status*" as an anchored regex: text matches literally,
    # * matches any text (newlines included).
    def rule_regex:
        "\\A" + (gsub("(?<c>[.^$+?{}|()\\[\\]\\\\])"; "\\\(.c)") | gsub("\\*"; "[\\s\\S]*")) + "\\z";

    # "Bash(git status*)" -> "git status*" for $tool, otherwise null.
    def rule_argument($tool):
        if startswith($tool + "(") and endswith(")") and length > ($tool | length) + 2
        then .[($tool | length) + 1:-1] else null end;

    def rule_matches($tool; $input):
        rule_argument($tool) as $pattern
        | $pattern != null and ($input | test($pattern | rule_regex));

    # A > or >> redirect to a file. 2>&1, >&2 and >/dev/null do not count.
    def writes_file:
        gsub("[0-9]*>&[0-9]+"; "") | gsub("[0-9]*>/dev/null"; "") | test(">[\\s\\S]");

    # The first word of each line, as `awk "{print $1}"` prints them.
    def first_words:
        [split("\n")[] | [splits("[ \t]+") | select(length > 0)] | .[0] // ""]
        | join("\n") | sub("\n+\\z"; "");

    def allowed($tool; $input; $allow; $deny):
        if any($deny[]; rule_matches($tool; $input)) then false
        elif $tool == "Bash" and ($input | writes_file) then false
        # Compound commands (&&, ||, ;) skip the safe-command shortcut: each part needs checking.
        elif $tool == "Bash" and ($input | test("&&|\\|\\||[^>];") | not)
            and (($input | first_words) as $word | any(safe_commands[]; . == $word)) then true
        else any($allow[]; . == $tool or rule_matches($tool; $input))
        end;

    ($settings[0].permissions // {}) as $permissions
    | (.tool_name // "") as $tool
    | (.tool_input.command // .tool_input // ""
        | if type == "string" then . else tojson end | sub("\n+\\z"; "")) as $input
    # permission_mode is optional since Claude Code ~2.1.50+, default to "default".
    # Notifications only matter where the user is actually prompted: "default"
    # asks for everything not allowed, "acceptEdits" still asks for Bash. Other
    # modes (bypassPermissions, plan, ...) never prompt.
    | (.permission_mode // "default") as $mode
    | if $mode != "default" and $mode != "acceptEdits" then empty
      elif $mode == "acceptEdits" and $tool != "Bash" then empty
      elif allowed($tool; $input; $permissions.allow // []; $permissions.deny // []) then empty
      elif $tool == "Bash" then "!" + $input[:50]
      elif $tool == "Edit" or $tool == "Write" then "!\($tool): \(.tool_input.file_path // "")"
      else "!" + $tool
      end
' 2>/dev/null)

[[ -n "$OUTPUT" ]] || exit 0

# Pass terminal info for Warp tab name support
~/.claude/notify.sh 'Claude Code - Permission Required' "${OUTPUT#!}" 'Glass' "${TERM_PROGRAM:-}" &
