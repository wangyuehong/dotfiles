# Path to your oh-my-zsh configuration.
ZSH=$HOME/.oh-my-zsh

# Set name of the theme to load.
# Look in ~/.oh-my-zsh/themes/
# Optionally, if you set this to "random", it'll load a random theme each
# time that oh-my-zsh is loaded.
# ZSH_THEME="candy"
ZSH_THEME="spaceship"

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
plugins=(git z themes history history-substring-search docker docker-compose golang zsh-autosuggestions zsh-syntax-highlighting dotenv)

source $ZSH/oh-my-zsh.sh

# Customize to your needs...
unsetopt share_history
setopt hist_ignore_all_dups

ZSH_DOTENV_PROMPT=false

# set path
# [[ "$PATH" == *"/usr/local/sbin"* ]] || export PATH=$PATH:/usr/local/sbin
[[ "$PATH" == *"$HOME/bin"* ]] || export PATH=$HOME/bin:$PATH

if [ -d ~/.local/bin ]; then # pip install --user will install into ~/.local/
    [[ "$PATH" == *"$HOME/.local/bin"* ]] || export PATH=$HOME/.local/bin:$PATH
fi

export EDITOR=vi

# z
_Z_CMD=j
source ~/.zz/z.sh

# rbenv
if [ -d ~/.rbenv ]; then
    [[ "$PATH" == *"$HOME/.rbenv/bin"* ]] || export PATH=$HOME/.rbenv/bin:$PATH
    eval "$(rbenv init -)";
fi

# pyenv
if [ -d ~/.pyenv ]; then
    [[ "$PATH" == *"$HOME/.pyenv/bin"* ]] || export PATH=$HOME/.pyenv/bin:$PATH
    eval "$(pyenv init -)";
fi

# goenv
if [ -d ~/.goenv ]; then
    export GOENV_ROOT="$HOME/.goenv"
    [[ "$PATH" == *"$GOENV_ROOT/bin"* ]] || export PATH=$GOENV_ROOT/bin:$PATH
    eval "$(goenv init -)"
    export PATH=$GOPATH/bin:$PATH
fi

# fzf
if [ -d ~/.fzf ]; then
    [ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
    export FZF_DEFAULT_OPTS="--reverse --inline-info --exact --history-size=999999"
    if command -v ag >/dev/null 2>&1; then
        export FZF_DEFAULT_COMMAND='ag -g ""'
        export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
    fi
fi

# local config
[[ -f ~/.zshrc.local ]] && source ~/.zshrc.local

# aliases
[[ -f ~/.aliases ]] && source ~/.aliases

export ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=blue'

# https://github.com/denysdovhan/spaceship-prompt/blob/master/docs/Options.md
SPACESHIP_PROMPT_ORDER=(
    time          # Time stampts section
    user          # Username section
    dir           # Current directory section
    host          # Hostname section
    git           # Git section (git_branch + git_status)
    # hg            # Mercurial section (hg_branch  + hg_status)
    # package       # Package version
    # node          # Node.js section
    ruby          # Ruby section
    # elm           # Elm section
    # elixir        # Elixir section
    # xcode         # Xcode section
    # swift         # Swift section
    golang        # Go section
    # php           # PHP section
    # rust          # Rust section
    # haskell       # Haskell Stack section
    # julia         # Julia section
    # docker        # Docker section
    # aws           # Amazon Web Services section
    # gcloud        # Google Cloud Platform section
    # venv          # virtualenv section
    # conda         # conda virtualenv section
    pyenv         # Pyenv section
    dotnet        # .NET section
    # ember         # Ember.js section
    # kubectl       # Kubectl context section
    # terraform     # Terraform workspace section
    exec_time     # Execution time
    line_sep      # Line break
    # battery       # Battery level and status
    vi_mode       # Vi-mode indicator
    jobs          # Background jobs indicator
    exit_code     # Exit code section
    char          # Prompt character
)

SPACESHIP_TIME_SHOW=true
SPACESHIP_PROMPT_ADD_NEWLINE=false
SPACESHIP_DIR_PREFIX="["
SPACESHIP_DIR_SUFFIX="] "
SPACESHIP_DIR_TRUNC_REPO=false
SPACESHIP_GIT_BRANCH_COLOR=028
