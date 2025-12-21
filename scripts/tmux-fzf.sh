#!/usr/bin/env bash
set -euo pipefail

# --- Environment Check ---
if [[ -z "${TMUX-}" ]]; then
	echo "Error: This script must be run inside a tmux session." >&2
	exit 1
fi

# --- Pane Info ---
pane_id=$(tmux display-message -p '#{pane_id}')
pane_dir=$(tmux display-message -p '#{pane_current_path}')
pane_pid=$(tmux display-message -p '#{pane_pid}')

# --- AI Tool Detection ---
at_prefix_mode=false
if pgrep -P "$pane_pid" -f ".*claude.*|node.*gemini|codex" >/dev/null; then
	at_prefix_mode=true
fi

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

# --- Preview Command ---
# Auto-detect file vs directory and use appropriate preview
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

preview="[[ -d {} ]] && $dir_cmd {} | head -n 30 || $file_cmd {}"

# --- fd Commands ---
fd_flags="-H --exclude .git"
printf -v escaped_dir "%q" "$pane_dir"
fd_files="$fd_cmd $fd_flags --type f --absolute-path . $escaped_dir"
fd_dirs="$fd_cmd $fd_flags --type d --absolute-path . $escaped_dir"

# --- State File ---
mode_file=$(mktemp)
if $in_git_repo; then
	echo "git" > "$mode_file"
else
	echo "abs" > "$mode_file"
fi
trap "rm -f '$mode_file'" EXIT

# --- ANSI Colors ---
C=$'\e[38;5;203m'  # coral/salmon red
R=$'\e[0m'         # reset

# --- Prompt Builder ---
# Usage in fzf transform: builds "Type | Mode > " prompt with colors
# Expects: $type (Files/Dirs), $mode (Git/Abs/Rel)
prompt_builder="printf '%s' \"${C}\${type}${R} | ${C}\${mode}${R} > \""

# --- fzf Bindings ---
bind_switch_type="ctrl-d:transform:
	mode=\$(echo \"\$FZF_PROMPT\" | grep -oE '(Git|Abs|Rel)')
	[[ \$FZF_PROMPT =~ Files ]] && type=Dirs || type=Files
	[[ \$type == Dirs ]] && fd=\"$fd_dirs\" || fd=\"$fd_files\"
	prompt=\$($prompt_builder)
	echo \"change-prompt(\$prompt)+reload(\$fd)+first\""

if $in_git_repo; then
	default_mode=Git
	alt_mode=Abs
else
	default_mode=Abs
	alt_mode=Rel
fi

bind_switch_path="ctrl-t:transform:
	[[ \$FZF_PROMPT =~ Files ]] && type=Files || type=Dirs
	[[ \$FZF_PROMPT =~ $alt_mode ]] && mode=$default_mode || mode=$alt_mode
	prompt=\$($prompt_builder)
	echo \"change-prompt(\$prompt)+execute-silent(sh -c 'echo \$mode | tr A-Z a-z > $mode_file')\""

fzf_opts=(
	--multi --reverse
	--preview "$preview"
	--prompt "${C}Files${R} | ${C}${default_mode}${R} > "
	--header "C-d: Files/Dirs | C-t: ${default_mode}/${alt_mode}"
	--bind "start:reload:$fd_files"
	--bind "$bind_switch_type"
	--bind "$bind_switch_path"
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
			if [[ "$f" == "$HOME/"* ]]; then
				f="~${f#$HOME}"
			elif [[ "$f" == "$HOME" ]]; then
				f="~"
			fi
			output+=("$f")
		done
		;;
	git|rel)
		[[ "$mode" == "git" ]] && base="$git_root" || base="$pane_dir"
		if $has_grealpath; then
			while IFS= read -r line; do
				[[ -n "$line" ]] && output+=("$line")
			done < <(grealpath --relative-to="$base" "${files[@]}")
		else
			output=("${files[@]}")
		fi
		;;
esac

# --- Format Output ---
if $at_prefix_mode; then
	result=()
	for p in "${output[@]}"; do
		if [[ "$p" == *[[:space:]\'\"\$\`\\]* ]]; then
			p="'${p//\'/"'\''"}'"
		fi
		result+=("@$p")
	done
	printf -v out "%s " "${result[@]}"
else
	result=()
	for p in "${output[@]}"; do
		if [[ "$p" == "~"* ]]; then
			printf -v escaped "%q" "${p#\~}"
			result+=("~$escaped")
		else
			printf -v escaped "%q" "$p"
			result+=("$escaped")
		fi
	done
	printf -v out "%s " "${result[@]}"
fi

# --- Send to Tmux ---
tmux send-keys -t "$pane_id" "$out"
