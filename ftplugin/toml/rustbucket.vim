if expand('%:t') !~# '^Cargo.\%(toml\|lock\)$'
  " then we're not interested in this particular toml file
  finish
endif

command! -buffer Doc call rustbucket#toml#Doc()
