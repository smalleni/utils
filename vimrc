set smartindent
set tabstop=4
set shiftwidth=4
set expandtab
set encoding=utf-8
let python_highlight_all=1
syntax on
autocmd BufRead,BufWrite * if ! &bin | silent! %s/\s\+$//ge | endif
set nocompatible              " required
filetype off                  " required

" set the runtime path to include Vundle and initialize
" set rtp+=~/.vim/bundle/Vundle.vim
" call vundle#begin()
"
" " alternatively, pass a path where Vundle should install plugins
"
" " let Vundle manage Vundle, required
" Plugin 'gmarik/Vundle.vim'
"
" " Add all your plugins here (note older versions of Vundle used Bundle
" instead of Plugin)
" Bundle 'Valloric/YouCompleteMe'
" Bundle 'chase/vim-ansible-yaml'
" Plugin 'scrooloose/syntastic'
" Plugin 'nvie/vim-flake8'
" Plugin 'powerline/powerline', {'rtp': 'powerline/bindings/vim/'}
"
" call vundle#end()            " required
" filetype plugin indent on    " required
" let g:loaded_youcompleteme = 1
