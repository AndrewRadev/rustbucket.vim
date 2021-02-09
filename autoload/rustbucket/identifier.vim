function! rustbucket#identifier#AtCursor()
  let namespace_pattern  = '\k\+\%(\.\|::\)'
  let identifier_pattern = '\k\+!\='
  let identifier_type    = ''
  let blank_identifier   = { 'symbol': '', 'type': '', 'full_path': '' }

  try
    let saved_iskeyword = &l:iskeyword
    setlocal iskeyword+=!
    let symbol = expand('<cword>')
  finally
    let &l:iskeyword = saved_iskeyword
  endtry

  if len(symbol) == 0
    return blank_identifier
  endif

  if symbol[len(symbol) - 1] == '!'
    let symbol = symbol[0 : len(identifier) - 1]
    let identifier_type = 'macro'
  endif

  try
    let saved_view = winsaveview()

    let search_result = search('\V'.symbol, 'Wbc', line('.'))
    if search_result <= 0
      return ''
    endif

    let symbol_start_col    = col('.')
    let namespace_start_col = col('.')

    " Check if we should move back some more over any namespaces
    let prefix = strpart(getline('.'), 0, col('.') - 1)
    while prefix =~ namespace_pattern.'$'
      if search(namespace_pattern, 'b', line('.')) <= 0
        break
      endif
      let prefix = strpart(getline('.'), 0, col('.') - 1)
      let namespace_start_col = col('.')
    endwhile

    if namespace_start_col < symbol_start_col - 1
      let namespace = rustbucket#util#GetCols(namespace_start_col, symbol_start_col - 1)
    else
      let namespace = ''
    endif

    return {
          \ 'symbol':    symbol,
          \ 'full_path': b:imports.FullPath(namespace . symbol),
          \ 'type':      identifier_type,
          \ }
  finally
    call winrestview(saved_view)
  endtry
endfunction
