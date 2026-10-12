#!/usr/bin/env bats
# tmux-open.bats: Tests for tmux-open.sh
#
# Run: bats scripts/tmux-open.bats

bats_require_minimum_version 1.5.0

# === Constants ===
SCRIPT="${BATS_TEST_DIRNAME}/tmux-open.sh"
CLIENT='/dev/ttys009'
PANE='%3'
NOTIFY="tmux display-message -c $CLIENT -N -C -l -d 2000 tmux-open:"
# A row of the cc /diff panel: the path starts right after the panel border at column 125
DIFF_PATH='claude/skills/my-md/references/structure.md'
printf -v DIFF_ROW '%s%*s│%s%*s%s' '❯ /diff' 118 '' "$DIFF_PATH" 39 '' '+14 -3'

# === Helpers ===

# Fail when any recorded call matches the pattern (bare `! grep` never fails a bats test).
not_called() {
	if grep -q "$1" "$CALLS"; then
		echo "unexpected call matching: $1" >&2
		return 1
	fi
}

# Run the script for a click at column x of text, with an optional hyperlink, in directory $CWD.
# A separate process, as from the binding, so errexit applies as it does there.
click() {
	run --separate-stderr "$SCRIPT" "$CLIENT" "$PANE" "$CWD" "$2" "$1" "${3:-}"
}

# Assert the popup ran emacsclient with exactly these arguments after "-t -a false".
viewer_args_are() {
	diff <(printf '%s\n' emacsclient -t -a false "$@") <(tail -n +12 "$POPUP")
}

# Print the value the popup got for option $1, among the options before -E.
popup_opt() {
	sed -n "/^-E\$/q;/^$1\$/{n;p;}" "$POPUP"
}

# Assert the popup title argument is $1.
title_is() {
	[ "$(popup_opt -T)" = "$1" ]
}

# Assert split_location splits $1 into path $2, line $3 and col $4.
location_is() {
	split_location "$1"
	[ "$LOC_PATH" = "$2" ] && [ "$LOC_LINE" = "$3" ] && [ "$LOC_COL" = "$4" ]
}

# Create a git repository at $REPO and set ROOT to the root git reports.
make_repo() {
	REPO="$BATS_TEST_TMPDIR/repo"
	mkdir -p "$REPO"
	git init -q "$REPO"
	ROOT=$(cd "$REPO" && pwd -P)
}

# === Setup/Teardown ===
setup() {
	source "$SCRIPT"
	export CALLS="$BATS_TEST_TMPDIR/calls" POPUP="$BATS_TEST_TMPDIR/popup"
	: >"$CALLS"
	export HOME="$BATS_TEST_TMPDIR/home"
	# Keeps git from finding a repository above the test directory.
	export GIT_CEILING_DIRECTORIES="$BATS_TEST_TMPDIR"
	WORK="$BATS_TEST_TMPDIR/work"
	CWD="$WORK"
	mkdir -p "$HOME" "$WORK/src"
	touch "$WORK/src/a.go" "$WORK/b c.go"

	tmux() {
		echo "tmux $*" >>"$CALLS"
		case "$1" in
		display-popup)
			printf '%s\n' "${@:2}" >"$POPUP"
			if [[ "${MOCK_POPUP_RC:-0}" != 0 ]]; then
				echo "popup failed" >&2
			fi
			return "${MOCK_POPUP_RC:-0}"
			;;
		show)
			case "$3" in
			@tmux-open-pane) printf '%s\n' "${MOCK_PANE:-}" ;;
			@tmux-open-x) printf '%s\n' "${MOCK_X:-}" ;;
			@tmux-open-cwd) printf '%s\n' "${MOCK_CWD:-}" ;;
			@tmux-open-line) printf '%s\n' "${MOCK_LINE:-}" ;;
			@tmux-open-link) printf '%s\n' "${MOCK_LINK:-}" ;;
			esac
			;;
		esac
		return 0
	}
	open() { echo "open $*" >>"$CALLS"; }
	export -f tmux open

	# The real tmux-im.sh switches the system input method, so a stub comes first on PATH.
	MOCK_BIN="$BATS_TEST_TMPDIR/bin"
	mkdir -p "$MOCK_BIN"
	printf '%s\n' '#!/usr/bin/env bash' 'echo "tmux-im.sh $*" >>"$CALLS"' \
		'[ "${MOCK_IM_RC:-0}" = 0 ] || echo "im failed" >&2' 'exit "${MOCK_IM_RC:-0}"' >"$MOCK_BIN/tmux-im.sh"
	chmod +x "$MOCK_BIN/tmux-im.sh"
	export PATH="$MOCK_BIN:$PATH"
	[ "$(command -v tmux-im.sh)" = "$MOCK_BIN/tmux-im.sh" ]
}

# === Target recognition ===

@test "AC-0010-0010: hyperlink target wins over visible text" {
	click "see other.go:7 here" 6 "file://$WORK/src/a.go"
	[ "$status" -eq 0 ]
	viewer_args_are +7 "$WORK/src/a.go"
}

@test "AC-0010-0020: path delimited by backticks and full-width punctuation" {
	click '已改 `src/a.go:12`，然后' 6
	viewer_args_are +12 "$WORK/src/a.go"
}

@test "AC-0010-0020: trailing punctuation and leading @ are dropped" {
	run token_at "open @src/a.go." 8
	[ "$output" = "src/a.go" ]
	run token_at "src/a.go:3:, next" 2
	[ "$output" = "src/a.go:3" ]
	run token_at "is it src/a.go?!" 8
	[ "$output" = "src/a.go" ]
}

@test "AC-0010-0020: box drawing and block characters end a path" {
	run token_at "$DIFF_ROW" 126
	[ "$output" = "$DIFF_PATH" ]
	run token_at "$DIFF_ROW" 125
	[ "$output" = "" ]
	run token_at "─┤src/a.go▌" 3
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
	grep -qx "$NOTIFY no path or URL under the mouse" "$CALLS"
	not_called "display-popup\|^open \|tmux-im.sh"
}

# === URL ===

@test "AC-0010-0050: URL text opens with the system opener" {
	click "docs at https://example.com/a:12 now" 12
	grep -qx "open https://example.com/a:12" "$CALLS"
	not_called "display-popup\|tmux-im.sh"
}

@test "AC-0010-0050: http hyperlink opens with the system opener" {
	click "the label" 5 "https://example.com"
	grep -qx "open https://example.com" "$CALLS"
	not_called "display-popup"
}

@test "AC-0010-0050: any scheme other than file goes to the system opener" {
	click "open vscode://file/a.go now" 7
	grep -qx "open vscode://file/a.go" "$CALLS"
	not_called "display-popup"
}

# === Paths ===

@test "AC-0010-0060: file URL is percent-decoded" {
	run file_url_path "file:///a/b%20c.go"
	[ "$output" = "/a/b c.go" ]
	click "x" 0 "file://$WORK/b%20c.go"
	viewer_args_are "$WORK/b c.go"
}

@test "AC-0010-0060: absolute, home and relative paths" {
	resolve_path "/abs/a.go" "$WORK"
	[ "$REPLY" = "/abs/a.go" ]
	resolve_path "~/a.go" "$WORK"
	[ "$REPLY" = "$HOME/a.go" ]
	resolve_path "src/a.go" "$WORK"
	[ "$REPLY" = "$WORK/src/a.go" ]
}

@test "AC-0010-0060: relative link target resolves against the pane directory" {
	click "the label" 5 "src/a.go:9"
	viewer_args_are +9 "$WORK/src/a.go"
}

@test "AC-0010-0060: :/ path resolves against the repository root" {
	make_repo
	mkdir -p "$REPO/sub"
	touch "$REPO/x.go"
	CWD="$REPO/sub"
	click "git add :/x.go:5" 9
	viewer_args_are +5 "$ROOT/x.go"
	[ -z "$stderr" ]
}

@test "AC-0010-0060: /diff panel path from a subdirectory falls back to the repository root" {
	make_repo
	mkdir -p "$REPO/claude/skills/my-md/references"
	touch "$REPO/$DIFF_PATH"
	CWD="$REPO/claude/skills"
	click "$DIFF_ROW" 140
	viewer_args_are "$ROOT/$DIFF_PATH"
	[ -z "$stderr" ]
}

@test "AC-0010-0060: relative path under the pane directory wins over the repository root" {
	make_repo
	mkdir -p "$REPO/sub"
	touch "$REPO/x.go" "$REPO/sub/x.go"
	CWD="$REPO/sub"
	click "x.go" 0
	viewer_args_are "$REPO/sub/x.go"
}

@test "AC-0010-0070: line, column and line range" {
	location_is "a.go:12:3" a.go 12 3
	location_is "a.go:12-20" a.go 12 ""
	location_is "a.go:12-20:3" a.go 12 3
	location_is "a.go" a.go "" ""
	click "src/a.go:12:3" 0
	viewer_args_are +12:3 "$WORK/src/a.go"
}

@test "AC-0010-0070: link fragment #L line and column" {
	location_is "file:///a.go#L12C3" file:///a.go 12 3
	location_is "a.go#L12-L20" a.go 12 ""
	click "a.go:99" 0 "file://$WORK/src/a.go#L42"
	viewer_args_are +42 "$WORK/src/a.go"
}

# === Popup ===

@test "AC-0010-0080: popup on the clicking client runs emacsclient on its tty" {
	click "src/a.go:12:3" 0
	[ "$status" -eq 0 ]
	diff <(printf '%s\n' -c "$CLIENT" -t "$PANE" -w 90% -h 90% -T "$WORK/src/a.go" \
		-E emacsclient -t -a false +12:3 "$WORK/src/a.go") "$POPUP"
	not_called "select-window\|select-pane\|^open "
}

@test "AC-0010-0080: input method switches for the clicked pane before the popup" {
	click "src/a.go" 0
	[ "$status" -eq 0 ]
	diff <(printf '%s\n' "tmux-im.sh popup $PANE") <(grep -o '^tmux-im.sh .*' "$CALLS")
	[ "$(grep -n '^tmux-im.sh' "$CALLS" | cut -d: -f1)" -lt "$(grep -n 'display-popup' "$CALLS" | cut -d: -f1)" ]
}

@test "AC-0010-0080: title abbreviates HOME only as a whole path component" {
	mkdir -p "$HOME/d" "$HOME-x"
	touch "$HOME/d/n.go" "$HOME-x/n.go"
	click "$HOME/d/n.go" 0
	title_is "~/d/n.go"
	click "$HOME-x/n.go" 0
	title_is "$HOME-x/n.go"
}

@test "AC-0010-0080: # in the title is escaped to show literally" {
	touch "$WORK/a#b" "$WORK/a#[x]" "$WORK/a##b"
	click "a#b" 0
	title_is "$WORK/a####b"
	viewer_args_are "$WORK/a#b"
	# "[" ends a token, so this path comes from a link
	click "a#" 0 "$WORK/a#[x]"
	title_is "$WORK/a##[x]"
	click "a##b" 0
	title_is "$WORK/a########b"
	popup_title 'x#y#[z]##w#'
	[ "$REPLY" = 'x####y##[z]########w####' ]
}

@test "AC-0010-0080: directory opens like a file" {
	click "src" 0
	viewer_args_are "$WORK/src"
}

@test "AC-0010-0085: popup closed normally or from the popup menu is not reported" {
	click "src/a.go" 0
	[ "$status" -eq 0 ]
	export MOCK_POPUP_RC=129
	click "src/a.go" 0
	[ "$status" -eq 0 ]
	[ -z "$stderr" ]
	not_called "display-message"
}

@test "AC-0010-0090: missing path reports not found" {
	click "src/none.go:3" 0
	grep -qx "$NOTIFY not found: $WORK/src/none.go" "$CALLS"
	not_called "display-popup\|tmux-im.sh"
}

@test "AC-0010-0090: missing relative path in a repository reports the pane directory form" {
	make_repo
	mkdir -p "$REPO/sub"
	CWD="$REPO/sub"
	click "none.go" 0
	grep -qx "$NOTIFY not found: $REPO/sub/none.go" "$CALLS"
	[ -z "$stderr" ]
	click ":/none.go" 0
	grep -qx "$NOTIFY not found: $ROOT/none.go" "$CALLS"
	[ -z "$stderr" ]
	not_called "display-popup"
}

@test "AC-0010-0090: :/ path without a repository shows the clicked text" {
	click ":/src/a.go:3" 0
	grep -qx "$NOTIFY not found: :/src/a.go" "$CALLS"
	[ -z "$stderr" ]
	not_called "display-popup"
}

@test "AC-0010-0090: no repository root inside .git or in a deleted directory" {
	make_repo
	CWD="$REPO/.git"
	click "none.go" 0
	grep -qx "$NOTIFY not found: $REPO/.git/none.go" "$CALLS"
	[ -z "$stderr" ]
	CWD="$BATS_TEST_TMPDIR/gone"
	click "none.go" 0
	grep -qx "$NOTIFY not found: $BATS_TEST_TMPDIR/gone/none.go" "$CALLS"
	[ -z "$stderr" ]
}

@test "AC-0010-0100: popup failure is reported once on the clicking client" {
	export MOCK_POPUP_RC=1
	click "src/a.go" 0
	[ "$status" -eq 0 ]
	[ -z "$stderr" ]
	[ "$(grep -c "display-message" "$CALLS")" -eq 1 ]
	grep -qx "$NOTIFY open failed (exit 1)" "$CALLS"
}

@test "AC-0010-0110: popup still opens without a notice when the input method switch fails" {
	export MOCK_IM_RC=3
	click "src/a.go" 0
	[ "$status" -eq 0 ]
	[ -z "$stderr" ]
	viewer_args_are "$WORK/src/a.go"
	# A notice drops all input while it shows, so none may come before the popup
	[ -z "$(sed -n '/display-popup/q;/display-message/p' "$CALLS")" ]
}

@test "AC-0010-0120: closing the popup reports the failed input method switch once" {
	export MOCK_IM_RC=3
	click "src/a.go" 0
	[ "$status" -eq 0 ]
	[ "$(grep -c "display-message" "$CALLS")" -eq 1 ]
	[ "$(sed -n '/display-popup/,$p' "$CALLS" | grep -cx "$NOTIFY input method switch failed (exit 3)")" -eq 1 ]
}

# === Extension points ===
# main is called directly so the stubs defined here replace the script's own choices.

@test "main: presenter from choose_presenter receives the resolved target" {
	present_stub() { printf '%s\n' "$@" >"$BATS_TEST_TMPDIR/present"; }
	choose_presenter() { REPLY=stub; }
	main "$CLIENT" "$PANE" "$WORK" 0 "src/a.go:12:3" ""
	diff <(printf '%s\n' "$CLIENT" "$PANE" "$WORK/src/a.go" 12 3) "$BATS_TEST_TMPDIR/present"
	not_called "display-popup"
}

@test "main: failing presenter is reported once and main still succeeds" {
	present_stub() { return 3; }
	choose_presenter() { REPLY=stub; }
	main "$CLIENT" "$PANE" "$WORK" 0 "src/a.go" ""
	[ "$(grep -c "display-message" "$CALLS")" -eq 1 ]
	grep -qx "$NOTIFY open failed (exit 3)" "$CALLS"
}

@test "present_popup: viewer from choose_viewer runs in the popup" {
	viewer_stub() { VIEWER_ARGV=(stubview "$@"); }
	choose_viewer() { REPLY=stub; }
	main "$CLIENT" "$PANE" "$WORK" 0 "src/a.go:12" ""
	diff <(printf '%s\n' stubview "$WORK/src/a.go" 12 "") <(tail -n +12 "$POPUP")
}

# === Usage ===

@test "main: wrong argument count exits with usage" {
	run --separate-stderr "$SCRIPT" "$CLIENT" "$PANE" "$WORK"
	[ "$status" -eq 2 ]
	[[ "$stderr" == Usage:* ]]
}

@test "main: any git failure counts as no repository root" {
	git() {
		echo "git: failed" >&2
		return 127
	}
	export -f git
	click ":/src/a.go" 0
	[ "$status" -eq 0 ]
	[ -z "$stderr" ]
	grep -qx "$NOTIFY not found: :/src/a.go" "$CALLS"
	click "none.go" 0
	[ "$status" -eq 0 ]
	grep -qx "$NOTIFY not found: $WORK/none.go" "$CALLS"
}

# === Binding ===

@test "binding: every press form records the click and enters the tmux-open table" {
	local conf="$BATS_TEST_DIRNAME/../.tmux.conf" press opt key
	press=$(sed -n "s/^%hidden TMUX_OPEN_PRESS='\(.*\)'\$/\1/p" "$conf")
	[[ "$press" != *run-shell* ]]
	for opt in pane cwd x line link; do
		[[ "$press" == *"set -gF @tmux-open-$opt "* ]]
	done
	[[ "$press" == *' ; switch-client -T tmux-open' ]]
	for key in M-MouseDown1Pane M-SecondClick1Pane M-TripleClick1Pane; do
		grep -qx "bind -n $key \"\$TMUX_OPEN_PRESS\"" "$conf"
	done
}

@test "binding: only a release in the tmux-open table opens the recorded click" {
	local conf="$BATS_TEST_DIRNAME/../.tmux.conf" up drag_end
	up=$(sed -n 's/^bind -T tmux-open M-MouseUp1Pane //p' "$conf")
	drag_end=$(sed -n 's/^bind -T tmux-open M-MouseDragEnd1Pane //p' "$conf")
	[[ "$up" == "run-shell -E 'tmux-open.sh "* ]]
	[ "$up" = "$drag_end" ]
	# A drag ends elsewhere, so the release must not read the mouse position or pane
	[[ "$up" != *'#{mouse_'* && "$up" != *'#{q:pane_id}'* ]]
	# Events between press and release keep the gesture in the table instead of reaching the pane
	for key in M-MouseDrag1Pane M-MouseDrag1Border M-MouseDrag1Status M-MouseDrag1StatusLeft \
		M-MouseDrag1StatusRight M-MouseDrag1StatusDefault M-DoubleClick1Pane; do
		grep -qx "bind -T tmux-open $key switch-client -T tmux-open" "$conf"
	done
	[ -z "$(grep -E '^bind (-n|-T root) M-Mouse(Up|DragEnd)1Pane' "$conf")" ]
}

@test "binding: shell-special text reaches the script as single arguments" {
	local cmd
	cmd=$(sed -n "s/^bind -T tmux-open M-MouseUp1Pane run-shell -E '\(.*\)'\$/\1/p" "$BATS_TEST_DIRNAME/../.tmux.conf")
	[ -n "$cmd" ]
	cmd=${cmd//'#{q:client_name}'/"'$CLIENT'"}
	export MOCK_PANE="$PANE" MOCK_X=0 MOCK_CWD="$WORK" MOCK_LINE='src/a.go:3 and {x,y} ~/z' MOCK_LINK=''
	PATH="$MOCK_BIN:$BATS_TEST_DIRNAME:$PATH" run /bin/sh -c "$cmd"
	[ "$status" -eq 0 ]
	viewer_args_are +3 "$WORK/src/a.go"
	[ "$(popup_opt -c)" = "$CLIENT" ]
	[ "$(popup_opt -t)" = "$PANE" ]
}
