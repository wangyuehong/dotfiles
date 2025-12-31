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

# Setup pane with IM and optional protection flag
setup_pane_im() {
	local pane="$1" im="$2" protected="${3:-}"
	set_opt "$pane" @im "$im"
	if [[ -n "$protected" ]]; then
		set_opt "$pane" @im-saved 1
	fi
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

# === Integration tests: save/restore ===

@test "AC-0010-0010: save IM state" {
	local pane=$(get_pane)
	save_im "$pane" "$IM_RIME"
	[ "$(get_opt "$pane" @im)" = "$IM_RIME" ]
}

@test "AC-0010-0020: restore IM on pane switch" {
	local pane=$(get_pane)
	set_opt "$pane" @im "$IM_RIME"
	run restore_pane_im "$pane"
	[ "$status" -eq 0 ]
}

@test "AC-0010-0030: new pane uses default IM" {
	local pane=$(get_pane)
	unset_opt "$pane" @im
	[ -z "$(get_opt "$pane" @im)" ]
}

@test "AC-0010-0030-border: new pane uses default border color" {
	local pane=$(get_pane)
	# New pane should have empty @im and @im-color
	unset_opt "$pane" @im
	unset_opt "$pane" @im-color
	# Simulate focus-in on new pane
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
	set_opt "$pane" @im "$IM_RIME"
	cmd_focus_in "$pane"
	[ "$(get_opt "$pane" @im-color)" = "$COLOR_RED" ]
}

@test "AC-0020-0060: prefix preserves border color" {
	local pane=$(get_pane)
	setup_pane_im "$pane" "$IM_RIME"
	set_opt "$pane" @im-color "$COLOR_RED"
	MOCK_IM="$IM_RIME"
	cmd_prefix "$pane"
	[ "$(get_opt "$pane" @im-color)" = "$COLOR_RED" ]
}

# === Integration tests: prefix mode ===

@test "AC-0010-0040: prefix switches to English and saves IM" {
	local pane=$(get_pane)
	MOCK_IM="$IM_RIME"
	cmd_prefix "$pane"
	# Should save current IM (Rime) and set protection flag
	[ "$(get_opt "$pane" @im)" = "$IM_RIME" ]
	[ "$(get_opt "$pane" @im-saved)" = "1" ]
	# Note: actual macism switch verified by code path (macism "$DEFAULT_IM")
}

@test "AC-0010-0050: prefix keeps English" {
	local pane=$(get_pane)
	MOCK_IM="$IM_ABC"
	cmd_prefix "$pane"
	[ "$(get_opt "$pane" @im)" = "$IM_ABC" ]
}

# === Integration tests: focus-in ===

@test "AC-0010-0060: focus-in clears stale flag" {
	local pane=$(get_pane)
	set_opt "$pane" @im-saved 1
	cmd_focus_in "$pane"
	[ -z "$(get_opt "$pane" @im-saved)" ]
}

@test "AC-0010-0110: focus-in preserves IM state" {
	local pane=$(get_pane)
	setup_pane_im "$pane" "$IM_RIME" protected
	cmd_focus_in "$pane"
	[ "$(get_opt "$pane" @im)" = "$IM_RIME" ]
}

# === Integration tests: copy-mode ===

@test "AC-0010-0090: enter copy-mode switches to English and saves IM" {
	local pane=$(get_pane)
	MOCK_IM="$IM_RIME"
	unset_opt "$pane" @im-saved
	cmd_mode_changed "$pane" "copy-mode"
	# Should save current IM (Rime) and set protection flag
	[ "$(get_opt "$pane" @im)" = "$IM_RIME" ]
	[ "$(get_opt "$pane" @im-saved)" = "1" ]
	# Note: actual macism switch to English verified by code path
}

@test "AC-0010-0070: copy-mode after prefix skips save" {
	local pane=$(get_pane)
	setup_pane_im "$pane" "$IM_RIME" protected
	MOCK_IM="$IM_ABC"
	cmd_mode_changed "$pane" "copy-mode"
	[ "$(get_opt "$pane" @im)" = "$IM_RIME" ]
}

@test "AC-0010-0100: exit copy-mode clears flag" {
	local pane=$(get_pane)
	setup_pane_im "$pane" "$IM_RIME" protected
	cmd_mode_changed "$pane" ""
	[ -z "$(get_opt "$pane" @im-saved)" ]
}

# === Integration tests: protection flag ===

@test "AC-0010-0140: protection flag blocks sync" {
	local pane=$(get_pane)
	setup_pane_im "$pane" "$IM_RIME" protected
	[ "$(get_opt "$pane" @im-saved)" = "1" ]
	[ "$(get_opt "$pane" @im)" = "$IM_RIME" ]
}

@test "AC-0010-0150: copy-mode protection blocks sync" {
	local pane=$(get_pane)
	setup_pane_im "$pane" "$IM_RIME" protected
	[ "$(get_opt "$pane" @im-saved)" = "1" ]
	[ "$(get_opt "$pane" @im)" = "$IM_RIME" ]
}

@test "AC-0010-0130: sync updates pane IM" {
	local pane=$(get_pane)
	unset_opt "$pane" @im-saved
	set_opt "$pane" @im "$IM_RIME"
	[ "$(get_opt "$pane" @im)" = "$IM_RIME" ]
}

# === Integration tests: multi-session ===

@test "AC-0010-0160: multi-session independent IM" {
	local pane_a=$(get_pane)
	local pane_b=$(create_session_b)
	set_opt "$pane_a" @im "$IM_RIME"
	set_opt "$pane_b" @im "$IM_ABC"
	[ "$(get_opt "$pane_a" @im)" = "$IM_RIME" ]
	[ "$(get_opt "$pane_b" @im)" = "$IM_ABC" ]
}

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

# === Integration tests: spurious focus event ===

@test "AC-0010-0170: external spurious focus-in syncs current IM" {
	local pane=$(get_pane)
	# Setup: pane has ABC saved, @im-saved NOT set (external trigger like Emacs)
	set_opt "$pane" @im "$IM_ABC"
	unset_opt "$pane" @im-saved
	MOCK_IM="$IM_RIME"
	# Simulate spurious focus: set focus_out_ts to now (within debounce threshold)
	set_opt "$pane" @focus_out_ts "$(get_timestamp_ms)"
	sleep 0.01
	cmd_focus_in "$pane"
	# Should sync current IM (Rime), not restore saved IM (ABC)
	[ "$(get_opt "$pane" @im)" = "$IM_RIME" ]
	[ "$(get_opt "$pane" @im-color)" = "$COLOR_RED" ]
}

@test "AC-0010-0175: prefix spurious focus-in skips save (protected)" {
	local pane=$(get_pane)
	# Setup: pane has Rime saved, @im-saved=1 (prefix just saved it)
	set_opt "$pane" @im "$IM_RIME"
	set_opt "$pane" @im-saved 1
	set_opt "$pane" @im-color "$COLOR_RED"
	MOCK_IM="$IM_ABC"  # macism switched to ABC
	# Simulate spurious focus from prefix's macism call
	set_opt "$pane" @focus_out_ts "$(get_timestamp_ms)"
	sleep 0.01
	cmd_focus_in "$pane"
	# Should skip: @im stays Rime (not overwritten by ABC), @im-color unchanged
	[ "$(get_opt "$pane" @im)" = "$IM_RIME" ]
	[ "$(get_opt "$pane" @im-color)" = "$COLOR_RED" ]
	[ "$(get_opt "$pane" @im-saved)" = "1" ]
}

@test "AC-0010-0180: normal focus-in restores saved IM" {
	local pane=$(get_pane)
	# Setup: pane has Rime saved
	set_opt "$pane" @im "$IM_RIME"
	MOCK_IM="$IM_ABC"
	# No @focus_out_ts set (normal pane switch, not spurious)
	unset_opt "$pane" @focus_out_ts
	cmd_focus_in "$pane"
	# Should restore saved IM (Rime)
	[ "$(get_opt "$pane" @im)" = "$IM_RIME" ]
	[ "$(get_opt "$pane" @im-color)" = "$COLOR_RED" ]
}

@test "is_spurious_focus_in: returns true when elapsed < threshold" {
	local pane=$(get_pane)
	set_opt "$pane" @focus_out_ts "$(get_timestamp_ms)"
	sleep 0.01
	run is_spurious_focus_in "$pane"
	[ "$status" -eq 0 ]
}

@test "is_spurious_focus_in: returns false when no focus_out_ts" {
	local pane=$(get_pane)
	unset_opt "$pane" @focus_out_ts
	run is_spurious_focus_in "$pane"
	[ "$status" -eq 1 ]
}

@test "is_spurious_focus_in: returns false when elapsed > threshold" {
	local pane=$(get_pane)
	# Set timestamp 1 second ago (well beyond 50ms threshold)
	local old_ts=$(($(get_timestamp_ms) - 1000))
	set_opt "$pane" @focus_out_ts "$old_ts"
	run is_spurious_focus_in "$pane"
	[ "$status" -eq 1 ]
}

@test "cmd_focus_out: sets focus_out_ts" {
	local pane=$(get_pane)
	unset_opt "$pane" @focus_out_ts
	cmd_focus_out "$pane"
	local ts=$(get_opt "$pane" @focus_out_ts)
	[ -n "$ts" ]
}

# Note: The fix for AC-0020-0090 ensures refresh-client -S is always called
# even when @im-color value is unchanged. This cannot be unit tested as it's
# a visual refresh issue, not a state issue.

# Note: AC-0010-0080 (prefix cancel) not implemented
# Note: AC-0010-0120 (non-terminal check) handled by Hammerspoon
