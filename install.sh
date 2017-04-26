#!/bin/sh

cd `dirname $0`

cwd=`pwd`

clone_or_pull() {
    if [ ! -d $3 ]; then
        echo "clone $1"
        git clone $2 $3
    else
        echo "update $1"
        cd $3 && git pull
    fi
}

if [ ! -f ~/.z ]; then
    touch ~/.z
fi

clone_or_pull z https://github.com/rupa/z.git ~/.zz
clone_or_pull oh-my-zsh https://github.com/robbyrussell/oh-my-zsh.git ~/.oh-my-zsh
clone_or_pull zsh-syntax-highlighting https://github.com/zsh-users/zsh-syntax-highlighting.git ~/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting
clone_or_pull rbenv https://github.com/sstephenson/rbenv.git ~/.rbenv
clone_or_pull ruby-build https://github.com/sstephenson/ruby-build.git ~/.rbenv/plugins/ruby-build
clone_or_pull rbenv-gem-rehash https://github.com/sstephenson/rbenv-gem-rehash.git ~/.rbenv/plugins/rbenv-gem-rehash
clone_or_pull rbenv-vars https://github.com/sstephenson/rbenv-vars.git ~/.rbenv/plugins/rbenv-vars

# clone_or_pull pyenv https://github.com/yyuu/pyenv.git ~/.pyenv

# clone_or_pull plenv https://github.com/tokuhirom/plenv.git ~/.plenv
# clone_or_pull perl-build https://github.com/tokuhirom/Perl-Build.git ~/.plenv/plugins/perl-build

clone_or_pull fzf https://github.com/junegunn/fzf.git ~/.fzf && ~/.fzf/install --all

ln -sf $cwd/.tmux.conf ~/.tmux.conf
ln -sf $cwd/.zshrc ~/.zshrc
ln -sf $cwd/.zshrc_alias ~/.zshrc_alias
ln -sf $cwd/.bashrc ~/.bashrc
ln -sf $cwd/.bash_alias ~/.bash_alias
ln -sf $cwd/.bash_profile ~/.bash_profile
ln -sf $cwd/.gitconfig ~/.gitconfig
ln -sf $cwd/.gitignore ~/.gitignore
ln -sf $cwd/.gemrc ~/.gemrc
ln -sf $cwd/.vimrc ~/.vimrc
ln -sf $cwd/.tigrc ~/.tigrc
ln -sf $cwd/.ctags ~/.ctags
ln -sf $cwd/.agignore ~/.agignore

# ctags
# langs=(perl ruby)
# for lang in "${langs[@]}"
# do
#     lang_dir=~/.tags/$lang
#     if [ ! -d $lang_dir ]; then
#         mkdir -p $lang_dir
#     fi
# done

exit 0
