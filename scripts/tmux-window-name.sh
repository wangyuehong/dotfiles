#!/usr/bin/env bash
set -euo pipefail
# Get friendly window name for tmux
# Usage: tmux-window-name.sh <pane_pid> [panes] [agent_name]

# Get command name (basename only) for a PID
get_comm() {
    local comm
    comm=$(ps -o comm= -p "$1" 2>/dev/null)
    echo "${comm##*/}"
}

# Get first child PID of a process
get_child() {
    ps -eo pid=,ppid= 2>/dev/null | awk -v ppid="$1" '$2 == ppid {print $1; exit}'
}

# Get the foreground process of a pane: the leader of the foreground process
# group of the shell's terminal; empty when the shell itself is in front.
# The first child is not it: zsh plugins keep workers on other terminals.
get_foreground() {
    local tpgid
    tpgid=$(ps -o tpgid= -p "$1" 2>/dev/null)
    tpgid="${tpgid// /}"
    [[ "$tpgid" =~ ^[0-9]+$ && "$tpgid" -gt 0 && "$tpgid" != "$1" ]] && echo "$tpgid"
    return 0
}

# Interpreters: show child process name instead
INTERPRETERS="${INTERPRETERS:-^(node|nodejs|python|python3|ruby|perl)$}"

# Map process name to friendly name
friendly_name() {
    local name="$1"
    case "$name" in
        Emacs*|emacs*) echo "emacs" ;;
        *) echo "$name" ;;
    esac
}

# Multi-pane indicator
MULTI_PANE_INDICATOR="${MULTI_PANE_INDICATOR:-▪}"

# Main function
main() {
    local pane_pid="$1"
    local panes="${2:-1}"
    local agent_name="${3:-}"
    [[ -z "$pane_pid" ]] && return 1

    # Get shell name as fallback
    local shell_name
    shell_name=$(get_comm "$pane_pid")
    [[ -z "$shell_name" ]] && shell_name="shell"

    # Find the target process
    local child_pid name
    child_pid=$(get_foreground "$pane_pid")
    if [[ -n "$child_pid" ]]; then
        name=$(get_comm "$child_pid")
        [[ -z "$name" ]] && name="$shell_name"
        # If interpreter, try to get actual program name from grandchild
        if [[ "$name" =~ $INTERPRETERS ]]; then
            local grandchild_pid
            grandchild_pid=$(get_child "$child_pid")
            if [[ -n "$grandchild_pid" ]]; then
                local gname
                gname=$(get_comm "$grandchild_pid")
                [[ -n "$gname" ]] && name="$gname"
            fi
        fi
    else
        name="$shell_name"
    fi

    local result
    result=$(friendly_name "$name")
    # A Claude Code pane shows the session name my-agents-bar gives it; the
    # program name gates a name left over after the agent exited
    [[ "$result" == "claude" && -n "$agent_name" ]] && result="$agent_name"

    # Add multi-pane indicator
    if [[ "$panes" -gt 1 ]]; then
        echo "${MULTI_PANE_INDICATOR}${result}"
    else
        echo "$result"
    fi
}

# Run main only when executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
