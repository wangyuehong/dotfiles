#!/usr/bin/env bats
# tmux-window-name.bats: Tests for tmux-window-name.sh
#
# Run: bats scripts/tmux-window-name.bats
# Spec: scripts/tmux-window-name.md

# === Constants ===
SCRIPT_DIR="${BATS_TEST_DIRNAME}"
SCRIPT="${SCRIPT_DIR}/tmux-window-name.sh"
DEFAULT_INDICATOR="▪"

# === Setup ===
setup() {
    source "${BATS_TEST_DIRNAME}/tmux-window-name.sh"
}

# === Unit tests: get_comm ===

@test "get_comm: returns basename for current shell" {
    local pid=$$
    run get_comm "$pid"
    [[ "$output" =~ ^(bash|bats|bats-core)$ ]]
}

@test "get_comm: returns empty for invalid PID" {
    run get_comm "999999999"
    [ -z "$output" ]
}

# === Unit tests: get_child ===
# Note: get_child tests provide coverage for AC-0010-0020 (command shows command name)
#       and AC-0010-0030 (interpreter shows child name) core logic

@test "get_child: returns child PID for process with children" {
    # Current shell ($$) should have bats as child
    run get_child "$$"
    [ -n "$output" ]
    # Verify it's a valid PID (numeric)
    [[ "$output" =~ ^[0-9]+$ ]]
}

@test "get_child: returns empty for PID with no children" {
    # Use a PID that likely has no children (like sleep in subshell)
    sleep 0.1 &
    local pid=$!
    run get_child "$pid"
    [ -z "$output" ]
    kill $pid 2>/dev/null || true
}

# === Unit tests: friendly_name ===

@test "AC-0010-0040: Emacs-arm64-11 maps to emacs" {
    run friendly_name "Emacs-arm64-11"
    [ "$output" = "emacs" ]
}

@test "friendly_name: emacs-28.1 maps to emacs" {
    run friendly_name "emacs-28.1"
    [ "$output" = "emacs" ]
}

@test "friendly_name: vim unchanged" {
    run friendly_name "vim"
    [ "$output" = "vim" ]
}

@test "friendly_name: zsh unchanged" {
    run friendly_name "zsh"
    [ "$output" = "zsh" ]
}

# === Unit tests: INTERPRETERS regex ===

@test "INTERPRETERS: matches all interpreters" {
    for interp in node nodejs python python3 ruby perl; do
        [[ "$interp" =~ $INTERPRETERS ]]
    done
}

@test "INTERPRETERS: does not match non-interpreters" {
    for cmd in zsh bash vim emacs cat grep; do
        ! [[ "$cmd" =~ $INTERPRETERS ]]
    done
}

# === Integration tests: main function ===

@test "AC-0010-0010: current PID returns shell or process name" {
    run main "$$"
    [ "$status" -eq 0 ]
    [ -n "$output" ]
    # Should return a reasonable process name (letters, numbers, dashes)
    [[ "$output" =~ ^[a-zA-Z0-9_-]+$ ]]
}

@test "AC-0010-0050: empty input exits with error" {
    run "$SCRIPT" ""
    [ "$status" -eq 1 ]
}

@test "AC-0010-0060: invalid PID returns fallback" {
    run main "999999999"
    [ "$status" -eq 0 ]
    [ "$output" = "shell" ]
}

# === Integration tests: multi-pane indicator ===

@test "AC-0010-0070: multi-pane shows indicator" {
    run main "$PPID" 2
    [ "$status" -eq 0 ]
    [[ "$output" == ${DEFAULT_INDICATOR}* ]]
}

@test "single pane no indicator" {
    run main "$PPID" 1
    [ "$status" -eq 0 ]
    [[ "$output" != ${DEFAULT_INDICATOR}* ]]
}

@test "default panes (omitted) no indicator" {
    run main "$PPID"
    [ "$status" -eq 0 ]
    [[ "$output" != ${DEFAULT_INDICATOR}* ]]
}

@test "custom MULTI_PANE_INDICATOR" {
    MULTI_PANE_INDICATOR="+" run main "$PPID" 2
    [ "$status" -eq 0 ]
    [[ "$output" == +* ]]
}
