command! -buffer Doc  call rustbucket#Doc()
command! -buffer Info call rustbucket#Info()

let b:imports = rustbucket#imports#Init()
