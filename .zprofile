# utf-8
export LANG='en_US.UTF-8'
export LC_CTYPE='en_US.UTF-8'
export LC_ALL='en_US.UTF-8'

export HISTCONTROL=ignoreboth:erasedups
export RIPGREP_CONFIG_PATH=~/.ripgreprc

# alias
alias tm='tmux attach -t base || tmux new -s base'
alias tt='tmux attach -t quick || tmux new -s quick'

[ -f ~/.zprofile.local ] && source ~/.zprofile.local
