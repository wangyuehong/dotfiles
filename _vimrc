"部分设置来源于roclinux.cn

"vim支持go语言 - 开始
"关闭文件类型检测功能
filetype off
"关闭文件类型插件加载功能、文件类型缩进功能
filetype plugin indent off
"增加go语言的vim相关配置路径
set runtimepath+=$GOROOT/misc/vim
"重新打开文件类型检测功能、文件类型插件加载功能和文件类型缩进功能
filetype plugin indent on
"vim支持go语言 - 结束

"按编程语言的语法,对代码进行彩色标示,术语叫做语法高亮
syntax on

" 不要备份
set nobackup

" 也不要swap file
set noswapfile

"用于设置自动格式化规则
"t: 根据textwidth来自动换行
"c: 如果是注释行,则根据textwidth自动换行,且在行首自动加注释标记
"r: 在插入模式下键入Enter会在新的一行行首自动添加注释标记
"o: 在普通模式下键入o或O,则会在新的一行行首自动添加注释标记
"q: 支持使用gq来格式化注释
"a: 在添加和删除文本时,对段落自动进行格式化
"n: 格式化文本时,智能处理编号列表
"2: 第二行缩进(默认为是第一行缩进)
"1: 单字符单词的后面不要折行
"m: 对中文等多字符语言更智能的换行
"M: 在拼接两行时,如果行尾或行首为多字节字符,则拼接时不要在中间加空格
"l: 在插入模式下不换行
"默认值为tcq
set formatoptions=tcqmM

"设置行宽限制,超过则会自动折行
"set textwidth=80

"显示行宽限制提示红线（仅vim7.4支持）
set colorcolumn=121

"显示行数标示
set number

"不显示不可见字符
set nolist

"禁止通过左方向键和右方向键进行换行
"b代表backspace
"s代表space
"h代表向左
"l代表向右
"<代表普通模式下的左方向键
">代表普通模式下的右方向键
"[代表插入模式下的左方向键
"]代表插入模式下的右方向键
"空则代表禁止通过上述按键触发换行
"set whichwrap=b,s,h,l,<,>,[,]
set whichwrap+=<,>,h,l

"设置成backspace的正常操作习惯
set backspace=eol,start,indent

"打开状态栏的坐标信息
set ruler

"取消底部状态栏显示。1为关闭,2为开启。
set laststatus=1

"将输入的命令显示出来,便于查看当前输入的信息
set showcmd

" 显示模式insert之类的状态
set showmode

"设置魔术匹配控制,可以通过:h magic查看更详细的帮助信息
set magic

"设置vim存储的历史命令记录的条数
set history=9999

"下划线高亮显示光标所在行
"set cursorline

"插入右括号时会短暂地跳转到匹配的左括号
set showmatch

"不对匹配的括号进行高亮显示
let loaded_matchparen=1

"在执行宏命令时,不进行显示重绘；
"在宏命令执行完成后,一次性重绘,以便提高性能。
set lazyredraw

"设置一个tab对应的空格个数
set tabstop=2

"在按退格键时,如果前面有多少个空格,则会统一清除
"set softtabstop=4

"cindent对c语法的缩进更加智能灵活,
"而shiftwidth则是在使用<和>进行缩进调整时用来控制缩进量。
"换行自动缩进,是按照shiftwidth值来缩进的
set cindent shiftwidth=2

"最基本的自动缩进
set autoindent shiftwidth=2

"比autoindent稍智能的自动缩进
set smartindent shiftwidth=2

"将新增的tab转换为空格。不会对已有的tab进行转换
set expandtab

"搜索时, 输入有大写的话,区别大小写,没有大写的时候,忽略大小写
set ignorecase
set smartcase

"高亮显示搜索匹配到的字符串
set hlsearch

"在搜索模式下,随着搜索字符的逐个输入,实时进行字符串匹配,
"并对首个匹配到的字符串高亮显示
set incsearch

"设置终端标题
set title

"关闭扰民
set novisualbell
set noerrorbells

"语言编码设置
set encoding=utf-8
set termencoding=utf-8
set fileencodings=ucs-bom,utf-8,cp936,gb18030,big5,euc-jp,euc-kr,latin1
set helplang=cn

"设置自定义快捷键的前导键
let mapleader=","

"利用前导键加b,则可以在一个单子两边加上大括号
map <leader>b wbi{<Esc>ea}<Esc>

"使用前导键加w来实现加速文件保存,来代替:w!加回车
nmap <leader>w :w!<CR>

"匹配那些末尾有空格或TAB的行。（es：Endspace Show）
map <leader>es :/.*\s\+$<CR>

"删除行末尾的空格或TAB（ed：Endspace Delete）
map <leader>ed :s#\s\+$##<CR>

"如果所选行的行首没有#,则给所选行行首加上注释符#（#a：# add）
map <leader>#a :s/^\([^#]\s*\)/#\1/<CR>

"如果所选行行首有#,则将所选行行首所有的#都去掉（#d：# delete）
map <leader>#d :s/^#\+\(\s*\)/\1/<CR>

"如果所选行的行首没有//,则给所选行行首加上注释符//（/a：/ add）
map <leader>/a :s/^\([^\/\/]\s*\)/\/\/\1/<CR>

"如果所选行行首有//,则将所选行行首的//都去掉（/d：/ delete）
map <leader>/d :s/^\/\/\(\s*\)/\1/<CR>