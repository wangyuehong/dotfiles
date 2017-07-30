# utf-8
export LANG='en_US.UTF-8'
export LC_CTYPE='en_US.UTF-8'
export LC_ALL='en_US.UTF-8'

export HISTCONTROL=ignoreboth:erasedups

export PATH="/home/linuxbrew/.linuxbrew/bin:$PATH"

# alias
alias tm='tmux attach -t base || tmux new -s base'

[ -f ~/.fzf.bash ] && source ~/.fzf.bash

[ -f ~/.bash_profile.local ] && source ~/.bash_profile.local