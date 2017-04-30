if [ -f /etc/bashrc ]; then
    . /etc/bashrc
fi

# utf-8
export LANG='en_US.UTF-8'
export LC_CTYPE='en_US.UTF-8'
export LC_ALL='en_US.UTF-8'

export HISTCONTROL=ignoreboth:erasedups

[ -f ~/.fzf.bash ] && source ~/.fzf.bash

# alias
alias tm='tmux attach -t base || tmux new -s base'

[ -f ~/.bashrc.local ] && source ~/.bashrc.local
