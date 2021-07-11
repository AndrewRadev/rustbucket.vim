command! -buffer Doc  call rustbucket#Doc()
command! -buffer Info call rustbucket#Info()

let b:imports = rustbucket#imports#Init()

" Copied/Adapted from vim-rails
exe 'cmap <buffer><script><expr> <Plug><cfile> rustbucket#gf#Includeexpr()'

nmap <buffer><silent> gf         :find    <Plug><cfile><CR>
nmap <buffer><silent> <C-W>f     :sfind   <Plug><cfile><CR>
nmap <buffer><silent> <C-W><C-F> :sfind   <Plug><cfile><CR>
nmap <buffer><silent> <C-W>gf    :tabfind <Plug><cfile><CR>
cmap <buffer>         <C-R><C-F> <Plug><cfile>

autocmd Syntax       <buffer> call rustbucket#highlight#Imports()
autocmd BufWritePost <buffer> call rustbucket#highlight#Imports()
