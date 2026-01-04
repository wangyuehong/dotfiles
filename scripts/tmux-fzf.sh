#!/usr/bin/env bash
set -euo pipefail

# === Utility Functions ===

# Shorten path by replacing $HOME with ~
# Usage: shorten_home_path "$HOME/file" -> "~/file"
shorten_home_path() {
	local f="$1"
	if [[ "$f" == "$HOME/"* ]]; then
		echo "~${f#$HOME}"
	elif [[ "$f" == "$HOME" ]]; then
		echo "~"
	else
		echo "$f"
	fi
}

# Format path for shell (printf %q, preserve ~ expansion)
# Usage: format_shell_escape "~/path with space" -> "~/path\ with\ space"
format_shell_escape() {
	local p="$1"
	local escaped
	if [[ "$p" == "~"* ]]; then
		printf -v escaped "%q" "${p#\~}"
		echo "~$escaped"
	else
		printf -v escaped "%q" "$p"
		echo "$escaped"
	fi
}

# Return early if sourced for testing
[[ "${BASH_SOURCE[0]}" != "${0}" ]] && return 0

# === Main Script ===

# --- Environment Check ---
if [[ -z "${TMUX-}" ]]; then
	echo "Error: This script must be run inside a tmux session." >&2
	exit 1
fi

# --- Pane Info ---
pane_id=$(tmux display-message -p '#{pane_id}')
pane_dir=$(tmux display-message -p '#{pane_current_path}')

# --- Git Detection ---
git_root=$(git -C "$pane_dir" rev-parse --show-toplevel 2>/dev/null || true)
in_git_repo=false
[[ -n "$git_root" ]] && in_git_repo=true

# --- Command Detection ---
if command -v fd >/dev/null 2>&1; then
	fd_cmd="fd"
elif command -v fdfind >/dev/null 2>&1; then
	fd_cmd="fdfind"
else
	echo "Error: Required command 'fd' or 'fdfind' not found." >&2
	exit 1
fi

has_grealpath=false
command -v grealpath >/dev/null 2>&1 && has_grealpath=true

# --- Preview Tools ---
# Auto-detect file vs directory preview commands
if command -v bat >/dev/null 2>&1; then
	file_cmd='bat --style=numbers --color=always'
elif command -v batcat >/dev/null 2>&1; then
	file_cmd='batcat --style=numbers --color=always'
else
	file_cmd='cat'
fi

if command -v tree >/dev/null 2>&1; then
	dir_cmd='tree -C'
else
	dir_cmd='ls -ap --color=always'
fi

# --- fd Commands ---
fd_flags="-H --exclude .git"
printf -v escaped_dir "%q" "$pane_dir"

# Abs mode: absolute paths (templates for dynamic reload)
fd_abs_all_tpl="$fd_cmd $fd_flags --absolute-path"
fd_abs_files_tpl="$fd_cmd $fd_flags --type f --absolute-path"
fd_abs_dirs_tpl="$fd_cmd $fd_flags --type d --absolute-path"

# Initial load command
if $in_git_repo; then
	printf -v escaped_git_root "%q" "$git_root"
	fd_initial="$fd_cmd $fd_flags --base-directory $escaped_git_root ."
else
	fd_initial="$fd_cmd $fd_flags --absolute-path . $escaped_dir"
fi

# --- State Files ---
mode_file=$(mktemp)
base_file=$(mktemp)
if $in_git_repo; then
	echo "git" > "$mode_file"
else
	echo "abs" > "$mode_file"
fi
echo "$pane_dir" > "$base_file"
trap "rm -f '$mode_file' '$base_file'" EXIT

# --- Preview Command ---
# Handle relative paths (Git mode) by dynamically getting git root from base_file
preview_path="p={}; if [[ \"\$p\" != /* && ! -e \"\$p\" ]]; then base=\$(cat '$base_file'); gr=\$(git -C \"\$base\" rev-parse --show-toplevel 2>/dev/null); p=\"\$gr\"/\"\$p\"; fi; echo \"\$p\""
preview="p=\$($preview_path); [[ -d \"\$p\" ]] && $dir_cmd \"\$p\" | head -n 30 || $file_cmd \"\$p\""

# --- ANSI Colors ---
C=$'\e[38;5;203m'  # coral/salmon red
R=$'\e[0m'         # reset

# --- Prompt Builder ---
# Usage in fzf transform: builds "Type | Mode > " prompt with colors
# Expects: $type (All/Files/Dirs), $mode (Git/Abs/Rel)
prompt_builder="printf '%s' \"${C}\${type}${R} | ${C}\${mode}${R} > \""

# --- fzf Bindings ---
# Ctrl-D: cycle All -> Files -> Dirs -> All
bind_switch_type="ctrl-d:transform:
	mode=\$(echo \"\$FZF_PROMPT\" | grep -oE '(Git|Abs|Rel)')
	base=\$(cat '$base_file')
	printf -v esc '%q' \"\$base\"
	if [[ \$FZF_PROMPT =~ All ]]; then
		type=Files
	elif [[ \$FZF_PROMPT =~ Files ]]; then
		type=Dirs
	else
		type=All
	fi
	# Select fd command based on mode
	if [[ \$mode == Git ]]; then
		# Git mode: dynamically get git root for current base directory
		git_root=\$(git -C \"\$base\" rev-parse --show-toplevel 2>/dev/null)
		printf -v git_esc '%q' \"\$git_root\"
		case \$type in
			All) fd='$fd_cmd $fd_flags --base-directory '\"\$git_esc\"' .' ;;
			Files) fd='$fd_cmd $fd_flags --type f --base-directory '\"\$git_esc\"' .' ;;
			Dirs) fd='$fd_cmd $fd_flags --type d --base-directory '\"\$git_esc\"' .' ;;
		esac
	else
		case \$type in
			All) fd='$fd_abs_all_tpl . '\"\$esc\" ;;
			Files) fd='$fd_abs_files_tpl . '\"\$esc\" ;;
			Dirs) fd='$fd_abs_dirs_tpl . '\"\$esc\" ;;
		esac
	fi
	prompt=\$($prompt_builder)
	echo \"change-prompt(\$prompt)+reload(\$fd)+first\""

if $in_git_repo; then
	default_mode=Git
	alt_mode=Abs
else
	default_mode=Abs
	alt_mode=Rel
fi

# --- Header ---
keybinds_header="C-d: All/Files/Dirs | C-t: ${default_mode}/${alt_mode} | C-h: Up | C-l: In"
initial_header="$(shorten_home_path "$pane_dir")
$keybinds_header"

bind_switch_path="ctrl-t:transform:
	base=\$(cat '$base_file')
	printf -v esc '%q' \"\$base\"
	if [[ \$FZF_PROMPT =~ All ]]; then type=All
	elif [[ \$FZF_PROMPT =~ Files ]]; then type=Files
	else type=Dirs
	fi
	[[ \$FZF_PROMPT =~ $alt_mode ]] && mode=$default_mode || mode=$alt_mode
	# Select fd command based on new mode
	if [[ \$mode == Git ]]; then
		# Git mode: dynamically get git root for current base directory
		# AC-0020-0040: If navigated outside git repo, cannot switch to Git mode
		git_root=\$(git -C \"\$base\" rev-parse --show-toplevel 2>/dev/null)
		[[ -z \"\$git_root\" ]] && exit 0
		printf -v git_esc '%q' \"\$git_root\"
		case \$type in
			All) fd='$fd_cmd $fd_flags --base-directory '\"\$git_esc\"' .' ;;
			Files) fd='$fd_cmd $fd_flags --type f --base-directory '\"\$git_esc\"' .' ;;
			Dirs) fd='$fd_cmd $fd_flags --type d --base-directory '\"\$git_esc\"' .' ;;
		esac
	else
		case \$type in
			All) fd='$fd_abs_all_tpl . '\"\$esc\" ;;
			Files) fd='$fd_abs_files_tpl . '\"\$esc\" ;;
			Dirs) fd='$fd_abs_dirs_tpl . '\"\$esc\" ;;
		esac
	fi
	prompt=\$($prompt_builder)
	echo \"change-prompt(\$prompt)+reload(\$fd)+execute-silent(sh -c 'echo \$mode | tr A-Z a-z > $mode_file')+first\""

bind_parent_dir="ctrl-h:transform:
	base=\$(cat '$base_file')
	parent=\$(dirname \"\$base\")
	[[ \"\$parent\" == \"\$base\" ]] && exit 0
	echo \"\$parent\" > '$base_file'
	printf -v esc '%q' \"\$parent\"
	short=\$(echo \"\$parent\" | sed 's|^$HOME|~|')
	header=\"\${short}
$keybinds_header\"
	# Auto-switch mode based on git status
	target_git=\$(git -C \"\$parent\" rev-parse --show-toplevel 2>/dev/null || true)
	if [[ -n \"\$target_git\" ]]; then
		mode=Git
		printf -v git_esc '%q' \"\$target_git\"
		fd='$fd_cmd $fd_flags --base-directory '\"\$git_esc\"' .'
	else
		mode=Abs
		fd='$fd_abs_all_tpl . '\"\$esc\"
	fi
	echo \"\$mode\" | tr A-Z a-z > '$mode_file'
	type=All
	prompt=\$($prompt_builder)
	echo \"clear-query+change-header(\$header)+change-prompt(\$prompt)+reload(\$fd)+first\""

bind_enter_dir="ctrl-l:transform:
	[[ ! -d {} ]] && exit 0
	dir={}
	# Handle relative path from Git mode
	if [[ \"\$dir\" != /* ]]; then
		base=\$(cat '$base_file')
		current_git=\$(git -C \"\$base\" rev-parse --show-toplevel 2>/dev/null)
		dir=\"\$current_git\"/\"\$dir\"
	fi
	echo \"\$dir\" > '$base_file'
	printf -v esc '%q' \"\$dir\"
	short=\$(echo \"\$dir\" | sed 's|^$HOME|~|')
	header=\"\${short}
$keybinds_header\"
	# Auto-switch mode based on git status
	target_git=\$(git -C \"\$dir\" rev-parse --show-toplevel 2>/dev/null || true)
	if [[ -n \"\$target_git\" ]]; then
		mode=Git
		printf -v git_esc '%q' \"\$target_git\"
		fd='$fd_cmd $fd_flags --base-directory '\"\$git_esc\"' .'
	else
		mode=Abs
		fd='$fd_abs_all_tpl . '\"\$esc\"
	fi
	echo \"\$mode\" | tr A-Z a-z > '$mode_file'
	type=All
	prompt=\$($prompt_builder)
	echo \"clear-query+change-header(\$header)+change-prompt(\$prompt)+reload(\$fd)+first\""

fzf_opts=(
	--multi --reverse
	--preview "$preview"
	--prompt "${C}All${R} | ${C}${default_mode}${R} > "
	--header "$initial_header"
	--bind "start:reload:$fd_initial"
	--bind "$bind_switch_type"
	--bind "$bind_switch_path"
	--bind "$bind_parent_dir"
	--bind "$bind_enter_dir"
)

# --- Run fzf ---
selected=$(fzf "${fzf_opts[@]}" || true)
[[ -z "$selected" ]] && exit 0

# --- Parse Selection ---
files=()
while IFS= read -r line; do
	[[ -n "$line" ]] && files+=("$line")
done <<<"$selected"

# --- Convert Paths ---
read -r mode < "$mode_file"
output=()

case "$mode" in
	abs)
		for f in "${files[@]}"; do
			output+=("$(shorten_home_path "$f")")
		done
		;;
	git)
		# Git mode: paths are already relative from fd, use directly
		for f in "${files[@]}"; do
			if [[ "$f" == /* ]]; then
				# Absolute path (from Abs mode before switch)
				output+=("$(shorten_home_path "$f")")
			else
				# Relative path from git root
				output+=("$f")
			fi
		done
		;;
	rel)
		for f in "${files[@]}"; do
			# Use absolute path if file is outside pane directory
			if [[ "$f" != "$pane_dir"/* ]]; then
				output+=("$(shorten_home_path "$f")")
			elif $has_grealpath; then
				output+=("$(grealpath --relative-to="$pane_dir" "$f")")
			else
				output+=("$(shorten_home_path "$f")")
			fi
		done
		;;
esac

# --- Format Output ---
result=()
for p in "${output[@]}"; do
	result+=("$(format_shell_escape "$p")")
done
printf -v out "%s " "${result[@]}"

# --- Send to Tmux ---
tmux send-keys -t "$pane_id" "$out"
