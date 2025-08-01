set tabstop=2 softtabstop=0 expandtab shiftwidth=2 smarttab

syntax on

" filetype plugin indent on 

" Open file in the last line used in this file
if has("autocmd")
  au BufReadPost * if line("'\"") > 0 && line("'\"") <= line("$") | exe "normal! g`\"" | endif
endif

