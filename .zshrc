# Path to your oh-my-zsh configuration.
ZSH=$HOME/.oh-my-zsh

# Set name of the theme to load.
# Look in ~/.oh-my-zsh/themes/
# Optionally, if you set this to "random", it'll load a random theme each
# time that oh-my-zsh is loaded.
ZSH_THEME="candy"

# Example aliases
# alias zshconfig="mate ~/.zshrc"
# alias ohmyzsh="mate ~/.oh-my-zsh"

# Set to this to use case-sensitive completion
# CASE_SENSITIVE="true"

# Comment this out to disable weekly auto-update checks
# DISABLE_AUTO_UPDATE="true"
DISABLE_UPDATE_PROMPT=true

# Uncomment following line if you want to disable colors in ls
# DISABLE_LS_COLORS="true"

# Uncomment following line if you want to disable autosetting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment following line if you want red dots to be displayed while waiting for completion
# COMPLETION_WAITING_DOTS="true"

# Which plugins would you like to load? (plugins can be found in ~/.oh-my-zsh/plugins/*)
# Custom plugins may be added to ~/.oh-my-zsh/custom/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
plugins=(git git-extras rake gem osx z colored-man tmux history history-substring-search docker perl zsh-syntax-highlighting)

source $ZSH/oh-my-zsh.sh

# Customize to your needs...
unsetopt share_history
setopt hist_ignore_all_dups

# set path
export PATH=$PATH:/usr/local/sbin
export PATH=$PATH:$HOME/bin

export EDITOR=ec

# z
_Z_CMD=j
source ~/.zz/z.sh

# rbenv
export PATH=$HOME/.rbenv/bin:$PATH
[ -d ~/.rbenv ] && eval "$(rbenv init -)"

# pyenv
# export PATH=$HOME/.pyenv/bin:$PATH
# [ -d ~/.pyenv ] && eval "$(pyenv init -)"

# plenv
# export PATH=$HOME/.plenv/bin:$PATH
# [ -d ~/.rbenv ] && eval "$(plenv init - zsh)"

# fzf
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
if ag --version>/dev/null; then
  export FZF_DEFAULT_COMMAND='ag -g ""'
  export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
fi

export FZF_DEFAULT_OPTS="--reverse --inline-info --exact --history-size=999999"

# alias
alias e='emacs'
alias ec='emacsclient -t'
alias v='vim'
alias ..='cd ..'
alias ...='cd ../..'
alias g='git'
alias h='history'
alias df='df -h'
alias du='du -h'
alias su="su -"
alias sudo='sudo -E'
alias less='less -r'
alias tree='tree -C'
alias fz='fzf'

[ -f ~/.zshrc_custom ] && source ~/.zshrc_custom