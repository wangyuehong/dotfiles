eval $(/opt/homebrew/bin/brew shellenv)

# utf-8
export LANG='en_US.UTF-8'
export LC_CTYPE='en_US.UTF-8'
export LC_ALL='en_US.UTF-8'

export HISTCONTROL=ignoreboth:erasedups

# alias
alias tm='tmux attach -t base || tmux new -s base'

[ -f ~/.zprofile.local ] && source ~/.zprofile.local
