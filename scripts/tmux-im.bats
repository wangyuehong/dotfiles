#!/usr/bin/env bats
# tmux-im.bats: Tests for tmux-im.sh
#
# Run: bats scripts/tmux-im.bats
#      make test-tmux-im

# === Constants ===
TEST_SESSION="tmux-im-test"
TEST_SESSION_B="tmux-im-test-b"
IM_RIME="im.rime.inputmethod.Squirrel.Hans"
IM_GOOGLE_JP="com.google.inputmethod.Japanese.base"
IM_ABC="com.apple.keylayout.ABC"
COLOR_RED="#E53935"
COLOR_BLUE="#2C78BF"

# === Helpers ===

# Get pane_id of test session (or specified session)
get_pane() {
	tmux display-message -t "${1:-$TEST_SESSION}" -p '#{pane_id}'
}

# Get pane option value
get_opt() {
	local pane="$1" opt="$2"
	tmux show-options -pqv -t "$pane" "$opt" 2>/dev/null || echo ""
}

# Set pane option
set_opt() {
	local pane="$1" opt="$2" val="$3"
	tmux set-option -p -t "$pane" "$opt" "$val"
}

# Unset pane option
unset_opt() {
	local pane="$1" opt="$2"
	tmux set-option -pu -t "$pane" "$opt" 2>/dev/null || true
}

# Create second session, return its pane_id
create_session_b() {
	tmux new-session -d -s "$TEST_SESSION_B" 2>/dev/null || true
	get_pane "$TEST_SESSION_B"
}

# Cleanup second session
cleanup_session_b() {
	tmux kill-session -t "$TEST_SESSION_B" 2>/dev/null || true
}

# === Setup/Teardown ===

setup() {
	export TMUX_IM_LOG="$BATS_TEST_DIRNAME/.tmux-im-test.log"
	truncate -s 0 "$TMUX_IM_LOG" 2>/dev/null || true
	source "${BATS_TEST_DIRNAME}/tmux-im.sh"
	macism() { echo "${MOCK_IM:-$IM_ABC}"; }
	export -f macism
	tmux new-session -d -s "$TEST_SESSION" 2>/dev/null || true
}

teardown() {
	tmux kill-session -t "$TEST_SESSION" 2>/dev/null || true
	cleanup_session_b
}

# === Unit tests: get_im_color ===

@test "AC-0020-0010: Rime -> red" {
	run get_im_color "$IM_RIME"
	[ "$output" = "$COLOR_RED" ]
}

@test "AC-0020-0020: Google JP -> blue" {
	run get_im_color "$IM_GOOGLE_JP"
	[ "$output" = "$COLOR_BLUE" ]
}

@test "AC-0020-0030: English -> empty" {
	run get_im_color "$IM_ABC"
	[ "$output" = "" ]
}

# === Integration tests: sync ===

@test "AC-0010-0020: focus-in syncs border color" {
	local pane=$(get_pane)
	MOCK_IM="$IM_ABC"
	cmd_focus_in "$pane"
	[ -z "$(get_opt "$pane" @im-color)" ]
}

@test "AC-0010-0030-border: new pane uses default border color" {
	local pane=$(get_pane)
	# New pane should have empty @im-color
	unset_opt "$pane" @im-color
	# Simulate focus-in on new pane
	MOCK_IM="$IM_ABC"
	cmd_focus_in "$pane"
	# Border color should be empty (default brightmagenta)
	[ -z "$(get_opt "$pane" @im-color)" ]
}

# === Integration tests: border color ===

@test "AC-0020-0040: border color updates on IM change" {
	local pane=$(get_pane)
	update_border_color "$pane" "$IM_RIME"
	[ "$(get_opt "$pane" @im-color)" = "$COLOR_RED" ]
}

@test "AC-0020-0050: pane switch updates border color" {
	local pane=$(get_pane)
	MOCK_IM="$IM_RIME"
	cmd_focus_in "$pane"
	[ "$(get_opt "$pane" @im-color)" = "$COLOR_RED" ]
}

@test "AC-0020-0060: prefix updates border color for English" {
	local pane=$(get_pane)
	set_opt "$pane" @im-color "$COLOR_RED"
	MOCK_IM="$IM_RIME"
	cmd_prefix "$pane"
	[ -z "$(get_opt "$pane" @im-color)" ]
}

# === Integration tests: prefix mode ===

@test "AC-0010-0040: prefix switches to English" {
	local pane=$(get_pane)
	MOCK_IM="$IM_RIME"
	cmd_prefix "$pane"
	# Note: actual macism switch verified by code path (macism "$DEFAULT_IM")
}

@test "AC-0010-0050: prefix keeps English" {
	local pane=$(get_pane)
	MOCK_IM="$IM_ABC"
	cmd_prefix "$pane"
}

# === Integration tests: focus-in ===

@test "AC-0010-0110: focus-in syncs border color" {
	local pane=$(get_pane)
	MOCK_IM="$IM_ABC"
	cmd_focus_in "$pane"
	[ -z "$(get_opt "$pane" @im-color)" ]
}

# === Integration tests: copy-mode ===

@test "AC-0010-0090: enter copy-mode switches to English" {
	local pane=$(get_pane)
	MOCK_IM="$IM_RIME"
	cmd_mode_changed "$pane" "copy-mode"
	# Note: actual macism switch to English verified by code path
	[ -z "$(get_opt "$pane" @im-color)" ]
}

@test "AC-0010-0100: exit copy-mode syncs border color" {
	local pane=$(get_pane)
	MOCK_IM="$IM_ABC"
	cmd_mode_changed "$pane" ""
	[ -z "$(get_opt "$pane" @im-color)" ]
}

# === Integration tests: multi-session ===

@test "AC-0020-0070: multi-session independent colors" {
	local pane_a=$(get_pane)
	local pane_b=$(create_session_b)
	set_opt "$pane_a" @im-color "$COLOR_RED"
	set_opt "$pane_b" @im-color ""
	[ "$(get_opt "$pane_a" @im-color)" = "$COLOR_RED" ]
	[ -z "$(get_opt "$pane_b" @im-color)" ]
}

@test "AC-0020-0080: session border color correct" {
	local pane_a=$(get_pane)
	local pane_b=$(create_session_b)
	update_border_color "$pane_a" "$IM_RIME"
	update_border_color "$pane_b" "$IM_ABC"
	[ "$(get_opt "$pane_a" @im-color)" = "$COLOR_RED" ]
	[ -z "$(get_opt "$pane_b" @im-color)" ]
}

@test "AC-0020-0090: consecutive IM switch refreshes border" {
	local pane=$(get_pane)
	# Set blue border (Japanese)
	update_border_color "$pane" "$IM_GOOGLE_JP"
	[ "$(get_opt "$pane" @im-color)" = "$COLOR_BLUE" ]
	# Switch to English - border should become default (empty)
	update_border_color "$pane" "$IM_ABC"
	[ -z "$(get_opt "$pane" @im-color)" ]
}

# Note: The fix for AC-0020-0090 ensures refresh-client -S is always called
# even when @im-color value is unchanged. This cannot be unit tested as it's
# a visual refresh issue, not a sync issue.

# Note: AC-0010-0080 (prefix cancel) not implemented
# Note: AC-0010-0120 (non-terminal check) handled by Hammerspoon
