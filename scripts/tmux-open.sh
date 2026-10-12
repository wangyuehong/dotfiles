#!/usr/bin/env bash
set -euo pipefail

# Open the path or URL under the mouse: URLs go to the system opener,
# paths open in a viewer inside a popup on the clicking client.
#
# Called from a tmux mouse binding, which collects the click context:
#   tmux-open.sh <client_name> <pane_id> <pane_current_path> <mouse_x> <mouse_line> <mouse_hyperlink>
#
# Stages, each using only the output of the one before:
#   target    the hyperlink, or token_at on the line under the mouse
#   classify  a scheme other than file:// makes a URL, anything else is a path
#   resolve   split_location, file_url_path and resolve_path give an absolute path, line and column
#   act       a URL goes to open, a path to the presenter named by choose_presenter
#   present   present_<name> <client> <pane> <path> <line> <col> runs the viewer named by choose_viewer
#             in a tty until the user is done; returns 0 when finished or dismissed, non-zero on failure
#   view      viewer_<name> <path> <line> <col> sets VIEWER_ARGV to a foreground command that holds
#             the tty until the user is done and exits 0 on success; the path may be a directory

# Characters that end a token, besides whitespace and the box drawing range in is_delim.
# Includes full-width punctuation that surrounds paths in CJK prose.
TOKEN_DELIMS=$'\'"`()[]{}<>|（）【】「」『』《》，。、：；！？“”‘’　'

# Punctuation stripped from the end of a token (sentence ends, list commas).
TRAILING_PUNCT='.,;:!?'

# Display width of one character into REPLY: 2 for East Asian wide and emoji ranges, 1 otherwise.
# Sets REPLY instead of printing so the per-character loop in token_at does not fork.
char_width() {
	local cp
	printf -v cp '%d' "'$1"
	if ((cp >= 0x1100 && cp <= 0x115F)) ||
		((cp >= 0x2E80 && cp <= 0xA4CF)) ||
		((cp >= 0xAC00 && cp <= 0xD7A3)) ||
		((cp >= 0xF900 && cp <= 0xFAFF)) ||
		((cp >= 0xFE30 && cp <= 0xFE4F)) ||
		((cp >= 0xFF00 && cp <= 0xFF60)) ||
		((cp >= 0xFFE0 && cp <= 0xFFE6)) ||
		((cp >= 0x1F300 && cp <= 0x1FAFF)) ||
		((cp >= 0x20000 && cp <= 0x3FFFD)); then
		REPLY=2
	else
		REPLY=1
	fi
}

# Box drawing and block elements (U+2500-U+259F) frame panels such as the cc /diff view.
is_delim() {
	local cp
	printf -v cp '%d' "'$1"
	((cp >= 0x2500 && cp <= 0x259F)) || [[ "$1" =~ [[:space:]] || "$TOKEN_DELIMS" == *"$1"* ]]
}

# Token covering display column x (0-based) of line; empty when x hits a delimiter.
# Usage: token_at "see foo.go:12, ok" 6 -> "foo.go:12"
token_at() {
	local line="$1" x="$2"
	local -a chars=()
	local i col=0 hit=-1 w
	for ((i = 0; i < ${#line}; i++)); do
		chars+=("${line:i:1}")
		char_width "${line:i:1}"
		w=$REPLY
		if ((hit < 0 && x >= col && x < col + w)); then
			hit=$i
		fi
		((col += w))
	done
	((hit < 0)) && return 0
	is_delim "${chars[hit]}" && return 0

	local start=$hit end=$hit
	while ((start > 0)) && ! is_delim "${chars[start - 1]}"; do ((--start)); done
	while ((end < ${#chars[@]} - 1)) && ! is_delim "${chars[end + 1]}"; do ((++end)); done

	local token="${line:start:end-start+1}"
	token="${token#@}"
	while [[ -n "$token" && "$TRAILING_PUNCT" == *"${token: -1}"* ]]; do
		token="${token%?}"
	done
	echo "$token"
}

# Split a location into LOC_PATH, LOC_LINE and LOC_COL; missing parts are empty.
# Accepts "path:line[-end][:col]" and the link fragment form "path#Lline[Ccol][-Lend]".
# Sets variables like char_width, so callers need no subshell or parsing.
# Usage: split_location "a.go:12:3" -> LOC_PATH=a.go LOC_LINE=12 LOC_COL=3
split_location() {
	local s="$1"
	LOC_PATH="$s" LOC_LINE="" LOC_COL=""
	if [[ "$s" =~ ^(.+)#L([0-9]+)(C([0-9]+))?(-L?[0-9]+)?$ ]]; then
		LOC_PATH="${BASH_REMATCH[1]}" LOC_LINE="${BASH_REMATCH[2]}" LOC_COL="${BASH_REMATCH[4]}"
	# Two patterns because ERE has no lazy match: "(.+)" would swallow ":line" of "path:line:col".
	elif [[ "$s" =~ ^(.+):([0-9]+)(-[0-9]+)?:([0-9]+)$ ]]; then
		LOC_PATH="${BASH_REMATCH[1]}" LOC_LINE="${BASH_REMATCH[2]}" LOC_COL="${BASH_REMATCH[4]}"
	elif [[ "$s" =~ ^(.+):([0-9]+)(-[0-9]+)?$ ]]; then
		LOC_PATH="${BASH_REMATCH[1]}" LOC_LINE="${BASH_REMATCH[2]}"
	fi
}

# Path of a file:// URL with percent-escapes decoded.
# Usage: file_url_path "file:///tmp/a%20b.go" -> "/tmp/a b.go"
file_url_path() {
	local p="${1#file://}"
	p="/${p#*/}"
	printf '%b\n' "${p//%/\\x}"
}

# Root of the git work tree containing dir; empty when git reports none or fails,
# so a click outside any repository, inside .git or in a deleted directory still gets "not found".
repo_root() {
	git -C "$1" rev-parse --show-toplevel 2>/dev/null || true
}

# Absolute path for p into REPLY: ~ expands to HOME, :/x resolves against the repository root of cwd,
# other relative paths against cwd, then against the repository root when missing under cwd.
# REPLY is empty for :/x without a repository root.
resolve_path() {
	local p="$1" cwd="$2" root
	case "$p" in
	"~") REPLY="$HOME" ;;
	"~/"*) REPLY="$HOME/${p#\~/}" ;;
	/*) REPLY="$p" ;;
	:/*)
		root=$(repo_root "$cwd")
		REPLY="${root:+$root/${p#:/}}"
		;;
	*)
		REPLY="$cwd/$p"
		if [[ ! -e "$REPLY" ]]; then
			root=$(repo_root "$cwd")
			if [[ -n "$root" && -e "$root/$p" ]]; then
				REPLY="$root/$p"
			fi
		fi
		;;
	esac
}

# -N keeps the notice for NOTIFY_MS: tmux drops keys and mouse input meanwhile instead of closing it.
# -l keeps "#" in paths literal.
NOTIFY_MS=2000
notify() {
	tmux display-message -c "$1" -N -C -l -d "$NOTIFY_MS" "tmux-open: $2"
}

# Name of the presenter into REPLY.
choose_presenter() {
	REPLY=popup
}

# Name of the viewer into REPLY.
choose_viewer() {
	REPLY=emacs
}

# Text for display-popup -T into REPLY, shown literally. -T is expanded as a format and then drawn
# with styles: a run of "#" before "[" survives the expansion and is halved when drawn,
# any other run is halved by both.
popup_title() {
	local s="$1" out="" run
	while [[ "$s" =~ ^([^#]*)(#+)(.*)$ ]]; do
		run="${BASH_REMATCH[2]}"
		out+="${BASH_REMATCH[1]}$run$run"
		s="${BASH_REMATCH[3]}"
		[[ "$s" == "["* ]] || out+="$run$run"
	done
	REPLY="$out$s"
}

# Popup over the clicking client: it covers the panes without resizing them and takes all input until closed.
# -t expands the -T format against the clicked pane; size and position still follow the client.
present_popup() {
	local client="$1" pane="$2" path="$3" line="$4" col="$5"
	choose_viewer
	# Explicit return: callers run this in a || list, where errexit does not apply.
	"viewer_$REPLY" "$path" "$line" "$col" || return
	local title="$path" rc=0 im_rc=0
	# Keys typed in the popup go to the viewer, so the input method switches to English first.
	tmux-im.sh popup "$pane" 2>/dev/null || im_rc=$?
	if [[ "$title" == "$HOME" || "$title" == "$HOME"/* ]]; then
		title="~${title#"$HOME"}"
	fi
	popup_title "$title"
	# TMUX_POPUP=1 tells the viewer it runs in a popup that closes when it exits.
	tmux display-popup -c "$client" -t "$pane" -w 90% -h 90% -T "$REPLY" -e TMUX_POPUP=1 \
		-E "${VIEWER_ARGV[@]}" 2>/dev/null || rc=$?
	# The switch only helps typing, so its failure does not stop the popup. The notice waits for the popup
	# to close: while a notice shows, tmux drops all input, including keys meant for the popup.
	((im_rc == 0)) || notify "$client" "input method switch failed (exit $im_rc)"
	# 129: the user closed the popup or turned it into a pane from the popup menu.
	((rc == 0 || rc == 129)) || return "$rc"
}

# Emacs frame on the popup's tty, sharing buffers with the running server.
# -a false: with ALTERNATE_EDITOR empty emacsclient would start a daemon; this makes a missing server fail.
viewer_emacs() {
	local path="$1" line="$2" col="$3"
	VIEWER_ARGV=(emacsclient -t -a false)
	if [[ -n "$line" ]]; then
		VIEWER_ARGV+=("+$line${col:+:$col}")
	fi
	VIEWER_ARGV+=("$path")
}

main() {
	if (($# != 6)); then
		echo "Usage: tmux-open.sh <client_name> <pane_id> <pane_current_path> <mouse_x> <mouse_line> <mouse_hyperlink>" >&2
		exit 2
	fi
	local client="$1" pane="$2" cwd="$3" x="$4" text="$5" link="$6"

	local token=""
	[[ -n "$text" && -n "$x" ]] && token=$(token_at "$text" "$x")
	local target="${link:-$token}"
	if [[ -z "$target" ]]; then
		notify "$client" "no path or URL under the mouse"
		return 0
	fi
	if [[ "$target" != file://* && "$target" =~ ^[a-zA-Z][a-zA-Z0-9+.-]*:// ]]; then
		open "$target"
		return 0
	fi

	split_location "$target"
	local path="$LOC_PATH" line="$LOC_LINE" col="$LOC_COL"
	# A link without a line number may still show one in its visible text.
	if [[ -n "$link" && -z "$line" ]]; then
		split_location "$token"
		line="$LOC_LINE" col="$LOC_COL"
	fi
	local abs
	if [[ "$path" == file://* ]]; then
		abs=$(file_url_path "$path")
	else
		resolve_path "$path" "$cwd"
		abs="$REPLY"
	fi

	if [[ -z "$abs" || ! -e "$abs" ]]; then
		notify "$client" "not found: ${abs:-$path}"
		return 0
	fi
	choose_presenter
	local presenter="$REPLY" rc=0
	"present_$presenter" "$client" "$pane" "$abs" "$line" "$col" || rc=$?
	((rc == 0)) || notify "$client" "open failed (exit $rc)"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
	main "$@"
fi
