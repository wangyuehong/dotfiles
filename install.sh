#!/bin/sh

set -e

cd `dirname $0`
cwd=`pwd`

clone_or_pull() {
    if [ ! -d $2 ]; then
        echo "clone $1"
        git clone $1 $2
    else
        echo "update $1"
        cd $2 && git pull
    fi
}

if [ ! -f ~/.z ]; then
    touch ~/.z
fi

clone_or_pull https://github.com/rupa/z.git ~/.zz
clone_or_pull https://github.com/robbyrussell/oh-my-zsh.git ~/.oh-my-zsh
clone_or_pull https://github.com/zsh-users/zsh-syntax-highlighting.git ~/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting
clone_or_pull https://github.com/sstephenson/rbenv.git ~/.rbenv
clone_or_pull https://github.com/sstephenson/ruby-build.git ~/.rbenv/plugins/ruby-build
clone_or_pull https://github.com/sstephenson/rbenv-gem-rehash.git ~/.rbenv/plugins/rbenv-gem-rehash
clone_or_pull https://github.com/sstephenson/rbenv-vars.git ~/.rbenv/plugins/rbenv-vars

# clone_or_pull https://github.com/yyuu/pyenv.git ~/.pyenv
# clone_or_pull https://github.com/tokuhirom/plenv.git ~/.plenv
# clone_or_pull https://github.com/tokuhirom/Perl-Build.git ~/.plenv/plugins/perl-build

clone_or_pull https://github.com/junegunn/fzf.git ~/.fzf && ~/.fzf/install --all

for file in .{agignore,aliases,bashrc,bash_profile,ctags,gemrc,gitconfig,gitignore,psqlrc,tigrc,tmux.conf,vimrc,zshrc}; do
    echo "ln $file"
    ln -sf $cwd/$file ~/$file
done;
unset file;

exit 0
