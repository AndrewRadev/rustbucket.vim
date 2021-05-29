if exists('g:loaded_rustbucket') || &cp
  finish
endif

let g:loaded_rustbucket = '0.0.1' " version number
let s:keepcpo = &cpo
set cpo&vim

command! -nargs=0 RustbucketGenerateTags call rustbucket#GenerateTags()

let &cpo = s:keepcpo
unlet s:keepcpo
