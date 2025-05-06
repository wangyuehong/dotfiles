# utf-8
export LANG='en_US.UTF-8'
export LC_CTYPE='en_US.UTF-8'
export LC_ALL='en_US.UTF-8'

export HISTCONTROL=ignoreboth:erasedups
export RIPGREP_CONFIG_PATH=~/.ripgreprc

# alias
alias tm='tmux new -A -s work'
alias tt='tmux new -A -s quick'

[ -f ~/.zprofile.local ] && source ~/.zprofile.local
