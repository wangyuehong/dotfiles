#!/usr/bin/env bats
# tmux-open.bats: Tests for tmux-open.sh
#
# Run: bats scripts/tmux-open.bats

# === Constants ===
SCRIPT="${BATS_TEST_DIRNAME}/tmux-open.sh"
SESSION='$1'
EMACS_PANE='%2'
# Any of these calls means Emacs or the focus changed
FOCUS_CALLS='emacsclient\|select-window\|select-pane'

# === Helpers ===

# Fail when any recorded call matches the pattern (bare `! grep` never fails a bats test).
not_called() {
	if grep -q "$1" "$CALLS"; then
		echo "unexpected call matching: $1" >&2
		return 1
	fi
}

# Run main for a click at column x of text, with an optional hyperlink.
click() {
	run main "$SESSION" "$WORK" "$2" "$1" "${3:-}"
}

# Assert split_location splits $1 into path $2, line $3 and col $4.
location_is() {
	split_location "$1"
	[ "$LOC_PATH" = "$2" ] && [ "$LOC_LINE" = "$3" ] && [ "$LOC_COL" = "$4" ]
}

# === Setup/Teardown ===
setup() {
	source "$SCRIPT"
	export CALLS="$BATS_TEST_TMPDIR/calls"
	: >"$CALLS"
	export MOCK_PANES="%1 zsh
${EMACS_PANE} Emacs"
	WORK="$BATS_TEST_TMPDIR/work"
	mkdir -p "$WORK/src"
	touch "$WORK/src/a.go" "$WORK/b c.go"

	tmux() {
		echo "tmux $*" >>"$CALLS"
		case "$1" in
		list-panes)
			[[ -n "${MOCK_LIST_FAIL:-}" ]] && return 1
			echo "$MOCK_PANES"
			;;
		show)
			case "$3" in
			@tmux-open-cwd) printf '%s\n' "${MOCK_CWD:-}" ;;
			@tmux-open-line) printf '%s\n' "${MOCK_LINE:-}" ;;
			@tmux-open-link) printf '%s\n' "${MOCK_LINK:-}" ;;
			esac
			;;
		esac
		return 0
	}
	open() { echo "open $*" >>"$CALLS"; }
	emacsclient() { echo "emacsclient $*" >>"$CALLS"; }
	export -f tmux open emacsclient
}

# === Target recognition ===

@test "AC-0010-0010: hyperlink target wins over visible text" {
	click "see other.go:7 here" 6 "file://$WORK/src/a.go"
	[ "$status" -eq 0 ]
	grep -qx "emacsclient -n +7 $WORK/src/a.go" "$CALLS"
}

@test "AC-0010-0020: path delimited by backticks and full-width punctuation" {
	click '已改 `src/a.go:12`，然后' 6
	grep -qx "emacsclient -n +12 $WORK/src/a.go" "$CALLS"
}

@test "AC-0010-0020: trailing punctuation and leading @ are dropped" {
	run token_at "open @src/a.go." 8
	[ "$output" = "src/a.go" ]
	run token_at "src/a.go:3:, next" 2
	[ "$output" = "src/a.go:3" ]
	run token_at "is it src/a.go?!" 8
	[ "$output" = "src/a.go" ]
}

@test "AC-0010-0030: full-width characters count as two columns" {
	# "中文 " occupies columns 0-4, so column 5 is the first character of the path
	run token_at "中文 src/a.go" 5
	[ "$output" = "src/a.go" ]
	run token_at "中文 src/a.go" 3
	[ "$output" = "中文" ]
	# "📄 " occupies columns 0-2, so column 3 is the first character of the path
	run token_at "📄 src/a.go" 3
	[ "$output" = "src/a.go" ]
}

@test "AC-0010-0040: delimiter under the mouse reports no target" {
	click "a.go  b.go" 5
	grep -q "tmux display-message -N -C -l -d 2000 tmux-open: no path or URL under the mouse" "$CALLS"
	not_called "$FOCUS_CALLS"
}

# === URL ===

@test "AC-0010-0050: URL text opens with the system opener" {
	click "docs at https://example.com/a:12 now" 12
	grep -qx "open https://example.com/a:12" "$CALLS"
	not_called "$FOCUS_CALLS"
}

@test "AC-0010-0050: http hyperlink opens with the system opener" {
	click "the label" 5 "https://example.com"
	grep -qx "open https://example.com" "$CALLS"
	not_called "$FOCUS_CALLS"
}

@test "AC-0010-0050: any scheme other than file goes to the system opener" {
	click "open vscode://file/a.go now" 7
	grep -qx "open vscode://file/a.go" "$CALLS"
	not_called "$FOCUS_CALLS"
}

# === Paths ===

@test "AC-0010-0060: file URL is percent-decoded" {
	run file_url_path "file:///a/b%20c.go"
	[ "$output" = "/a/b c.go" ]
	click "x" 0 "file://$WORK/b%20c.go"
	grep -qx "emacsclient -n $WORK/b c.go" "$CALLS"
}

@test "AC-0010-0060: absolute, home and relative paths" {
	run resolve_path "/abs/a.go" "$WORK"
	[ "$output" = "/abs/a.go" ]
	run resolve_path "~/a.go" "$WORK"
	[ "$output" = "$HOME/a.go" ]
	run resolve_path "src/a.go" "$WORK"
	[ "$output" = "$WORK/src/a.go" ]
}

@test "AC-0010-0060: relative link target resolves against the pane directory" {
	click "the label" 5 "src/a.go:9"
	grep -qx "emacsclient -n +9 $WORK/src/a.go" "$CALLS"
}

@test "AC-0010-0070: line, column and line range" {
	location_is "a.go:12:3" a.go 12 3
	location_is "a.go:12-20" a.go 12 ""
	location_is "a.go:12-20:3" a.go 12 3
	location_is "a.go" a.go "" ""
	click "src/a.go:12:3" 0
	grep -qx "emacsclient -n +12:3 $WORK/src/a.go" "$CALLS"
}

@test "AC-0010-0070: link fragment #L line and column" {
	location_is "file:///a.go#L12C3" file:///a.go 12 3
	location_is "a.go#L12-L20" a.go 12 ""
	click "a.go:99" 0 "file://$WORK/src/a.go#L42"
	grep -qx "emacsclient -n +42 $WORK/src/a.go" "$CALLS"
}

@test "AC-0010-0080: opens in Emacs then focuses its window and pane" {
	click "src/a.go" 0
	[ "$(grep -n emacsclient "$CALLS" | cut -d: -f1)" -lt "$(grep -n select-window "$CALLS" | cut -d: -f1)" ]
	grep -qx "tmux select-window -t $EMACS_PANE" "$CALLS"
	grep -qx "tmux select-pane -t $EMACS_PANE" "$CALLS"
	grep -qx "tmux list-panes -s -t $SESSION -F #{pane_id} #{pane_current_command}" "$CALLS"
}

@test "AC-0010-0090: missing path reports not found" {
	click "src/none.go:3" 0
	grep -q "tmux display-message -N -C -l -d 2000 tmux-open: not found: $WORK/src/none.go" "$CALLS"
	not_called "$FOCUS_CALLS"
}

@test "AC-0010-0100: no Emacs pane reports and keeps focus" {
	export MOCK_PANES="%1 zsh"
	click "src/a.go" 0
	grep -q "tmux display-message -N -C -l -d 2000 tmux-open: no Emacs pane in this session" "$CALLS"
	not_called "$FOCUS_CALLS"
}

# === Usage ===

@test "main: wrong argument count exits with usage" {
	run main "$SESSION" "$WORK"
	[ "$status" -eq 2 ]
	[[ "$output" == Usage:* ]]
}

@test "main: list-panes failure aborts instead of reporting no Emacs pane" {
	export MOCK_LIST_FAIL=1
	click "src/a.go" 0
	[ "$status" -ne 0 ]
	not_called "no Emacs pane\|emacsclient"
}

# === Binding ===

@test "binding: shell-special text reaches the script as single arguments" {
	local cmd
	cmd=$(sed -n "s/^bind -n M-MouseDown1Pane .*run-shell -E '\(.*\)'\$/\1/p" "$BATS_TEST_DIRNAME/../.tmux.conf")
	[ -n "$cmd" ]
	cmd=${cmd//'#{q:session_id}'/"'$SESSION'"}
	cmd=${cmd//'#{mouse_x}'/0}
	export MOCK_CWD="$WORK" MOCK_LINE='src/a.go:3 and {x,y} ~/z' MOCK_LINK=''
	PATH="$BATS_TEST_DIRNAME:$PATH" run /bin/sh -c "$cmd"
	[ "$status" -eq 0 ]
	grep -qx "emacsclient -n +3 $WORK/src/a.go" "$CALLS"
}
