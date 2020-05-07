" Pathogen
execute pathogen#infect()

" General
set nocompatible
filetype on
filetype plugin on
filetype indent on

" Theme/Colours
syntax on
set t_Co=256
set background=dark
colorscheme solarized

" Vim UI
set number
"set mouse=a "Use mouse everywhere

" Visual Cues
set showmatch "Show matching brackets
set mat=5
set incsearch
set statusline=%F%m%r%h%w\ [FORMAT=%{&ff}]\ [TYPE=%Y]\ [ASCII=\%03.3b]\ [HEX=\%02.2B]\ [POS=%04l,%04v][%p%%]\ [LEN=%L]
set laststatus=2 
set hlsearch
set cursorline
set colorcolumn=80
set wildmenu
" Display extra whitespace
set list listchars=tab:»·,trail:·

" Text Formatting/Layout
set ai "autoindent
set si "smartindent
"set cindent "Do C-style indenting
set tabstop=2 "Tab spacing (Settings below are just to unify it)
set softtabstop=2 "Unify
set shiftwidth=2 "Unify
set expandtab

" manpage viewing in Vim
runtime ftplugin/man.vim

" latexSuite plugin
set grepprg=grep\ -nH\ $*

" Spell check plugin for vim 7
"setlocal spell spelllang=en_gb
"setlocal spell encoding=utf-8

" " -------------------
" " NERDTree
" " -------------------
let NERDTreeIgnore=['\.vim$', '\~$[[file]]', '^\.git$[[dir]]', '^vendor$[[dir]]', '\.pyc$[[file]]', '\.swp$']
let NERDTreeShowHidden=1
" Open NERDTree when no files are specified on startup
" (https://github.com/scrooloose/nerdtree/blob/master/README.markdown)
autocmd StdinReadPre * let s:std_in=1
autocmd VimEnter * if argc() == 0 && !exists("s:std_in") | NERDTree | endif
" Autorefresh NERDTree on buffer write
" (https://superuser.com/questions/1141994/autorefresh-nerdtree)
" autocmd BufWritePost * NERDTreeFocus | execute 'normal R' | wincmd p
