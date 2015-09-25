#!/bin/sh

cd `dirname $0`

cwd=`pwd`

function clone_or_pull {
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
clone_or_pull rbenv-gemset https://github.com/jamis/rbenv-gemset.git  ~/.rbenv/plugins/rbenv-gemset
clone_or_pull rbenv-gem-rehash https://github.com/sstephenson/rbenv-gem-rehash.git ~/.rbenv/plugins/rbenv-gem-rehash
clone_or_pull rbenv-vars https://github.com/sstephenson/rbenv-vars.git ~/.rbenv/plugins/rbenv-vars

ln -sf $cwd/_tmux.conf ~/.tmux.conf
ln -sf $cwd/_zshrc ~/.zshrc
ln -sf $cwd/_zshrc_alias ~/.zshrc_alias
ln -sf $cwd/_bashrc ~/.bashrc
ln -sf $cwd/_bash_alias ~/.bash_alias
ln -sf $cwd/_bash_profile ~/.bash_profile
ln -sf $cwd/_gitconfig ~/.gitconfig
ln -sf $cwd/_gitignore ~/.gitignore
ln -sf $cwd/_gemrc ~/.gemrc
ln -sf $cwd/_vimrc ~/.vimrc
ln -sf $cwd/_tigrc ~/.tigrc
ln -sf $cwd/_ctags ~/.ctags

# peco
if [ ! -d ~/.peco ]; then
    mkdir ~/.peco
fi

ln -sf $cwd/_peco_config.json ~/.peco/config.json

# ctags
langs=(perl ruby)
for lang in "${langs[@]}"
do
    lang_dir=~/.tags/$lang
    if [ ! -d $lang_dir ]; then
        mkdir -p $lang_dir
    fi
done

exit 0
