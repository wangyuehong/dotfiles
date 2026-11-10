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

# === Integration tests: agent session name ===

# claude_pane makes main resolve the program name to $1.
claude_pane() {
    eval "get_foreground() { [[ \$1 == 1000 ]] && echo 1001; }"
    eval "get_comm() { case \$1 in 1000) echo zsh ;; 1001) echo $1 ;; esac; }"
}

@test "AC-0010-0080: claude with an agent name shows the name" {
    claude_pane claude
    run main 1000 1 fix-login
    [ "$status" -eq 0 ]
    [ "$output" = "fix-login" ]
}

@test "AC-0010-0080: claude with an agent name in a multi-pane window" {
    claude_pane claude
    run main 1000 2 fix-login
    [ "$output" = "${DEFAULT_INDICATOR}fix-login" ]
}

@test "AC-0010-0080: claude without an agent name stays claude" {
    claude_pane claude
    run main 1000 1
    [ "$output" = "claude" ]
    run main 1000 1 ""
    [ "$output" = "claude" ]
}

@test "AC-0010-0080: an agent name that looks like an echo option" {
    claude_pane claude
    run main 1000 1 -n
    [ "$output" = "-n" ]
}

@test "AC-0010-0080: a left-over agent name does not apply to a shell" {
    claude_pane zsh
    run main 1000 1 fix-login
    [ "$output" = "zsh" ]
}

# === Integration tests: foreground process ===

@test "AC-0010-0075: the foreground process wins over another child" {
    # 1001 is a zsh worker in the shell's group fallback; 1002 is in front.
    get_group_child() { [[ $1 == 1000 ]] && echo 1001; }
    get_foreground() { [[ $1 == 1000 ]] && echo 1002; }
    get_comm() { case $1 in 1000|1001) echo zsh ;; 1002) echo claude ;; esac; }
    run main 1000 1 zthcp-468
    [ "$output" = "zthcp-468" ]
}

@test "AC-0010-0075: the shell in front without children shows the shell" {
    get_foreground() { return 0; }
    get_group_child() { return 0; }
    get_comm() { echo zsh; }
    run main 1000 1 fix-login
    [ "$output" = "zsh" ]
}

@test "AC-0010-0075: a shell without job control in front shows its child" {
    command -v tmux >/dev/null || skip "no tmux"
    local socket="bats-wn-jc-$$"
    tmux -L "$socket" -f /dev/null new-session -d -x 80 -y 20 "cd /tmp; sleep 302; true"
    local shell_pid
    shell_pid=$(tmux -L "$socket" display -p '#{pane_pid}')
    local name=""
    for _ in $(seq 1 20); do
        name=$(main "$shell_pid")
        [[ "$name" == "sleep" ]] && break
        sleep 0.25
    done
    tmux -L "$socket" kill-server
    [ "$name" = "sleep" ]
}

@test "get_foreground: empty for a process that does not exist" {
    run get_foreground 999999999
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "get_foreground: empty for a process without a terminal (tpgid 0)" {
    [ "$(ps -o tpgid= -p 1 | tr -d ' ')" = "0" ] || skip "pid 1 has a terminal"
    run get_foreground 1
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "AC-0010-0075: an interactive shell at its prompt with a background job shows the shell" {
    command -v tmux >/dev/null || skip "no tmux"
    local socket="bats-wn-bg-$$"
    tmux -L "$socket" -f /dev/null new-session -d -x 80 -y 20 "zsh -f"
    local shell_pid
    shell_pid=$(tmux -L "$socket" display -p '#{pane_pid}')
    tmux -L "$socket" send-keys "sleep 303 &" Enter
    local job="" name=""
    for _ in $(seq 1 20); do
        job=$(get_child "$shell_pid")
        [[ -n "$job" ]] && break
        sleep 0.25
    done
    for _ in $(seq 1 20); do # back at the prompt: the shell leads the foreground
        [[ -z "$(get_foreground "$shell_pid")" ]] && break
        sleep 0.25
    done
    name=$(main "$shell_pid")
    local job_args
    job_args=$(ps -o args= -p "$job" 2>/dev/null)
    tmux -L "$socket" kill-server
    [ "$job_args" = "sleep 303" ]
    [ "$name" = "zsh" ]
}

@test "get_foreground: a pane's foreground process in a private tmux server" {
    command -v tmux >/dev/null || skip "no tmux"
    local socket="bats-wn-$$"
    tmux -L "$socket" -f /dev/null new-session -d -x 80 -y 20 "zsh -f"
    local shell_pid fg="" first=""
    shell_pid=$(tmux -L "$socket" display -p '#{pane_pid}')
    # A child on another terminal, started first, like a zsh plugin worker.
    tmux -L "$socket" send-keys "script -q /dev/null sleep 300 >/dev/null 2>&1 &! sleep 1; sleep 301" Enter
    for _ in $(seq 1 40); do
        fg=$(get_foreground "$shell_pid")
        [[ -n "$fg" && "$(ps -o args= -p "$fg")" == "sleep 301" ]] && break
        sleep 0.25
    done
    local fg_args first_args
    fg_args=$(ps -o args= -p "$fg" 2>/dev/null)
    first=$(get_child "$shell_pid")
    first_args=$(ps -o args= -p "$first" 2>/dev/null)
    tmux -L "$socket" kill-server
    [ "$fg_args" = "sleep 301" ]
    [ "$first_args" != "sleep 301" ] # the first child is the worker
}
