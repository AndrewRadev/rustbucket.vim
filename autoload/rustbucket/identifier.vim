" Data includes:
"
" - symbol:    The specific identifier under the cursor
" - type:      fn|macro|struct|enum|...
" - full_path: The fully namespaced identifier
"
function! rustbucket#identifier#New(data) abort
  return {
        \ 'symbol':    get(a:data, 'symbol', ''),
        \ 'full_path': get(a:data, 'full_path', ''),
        \ 'type':      get(a:data, 'type', ''),
        \
        \ 'real_path': '',
        \
        \ 'IsBlank':            function('rustbucket#identifier#IsBlank'),
        \ 'RealPath':           function('rustbucket#identifier#RealPath'),
        \ 'Type':               function('rustbucket#identifier#Type'),
        \ 'PackageWithVersion': function('rustbucket#identifier#PackageWithVersion'),
        \ }
endfunction

function! rustbucket#identifier#AtCursor() abort
  let namespace_pattern  = '\k\+\%(\.\|::\)'
  let identifier_pattern = '\k\+!\='
  let identifier_type    = ''

  try
    let saved_iskeyword = &l:iskeyword
    setlocal iskeyword+=!
    let symbol = expand('<cword>')
  finally
    let &l:iskeyword = saved_iskeyword
  endtry

  if len(symbol) == 0
    return rustbucket#identifier#New({})
  endif

  if symbol[len(symbol) - 1] == '!'
    let symbol = symbol[0 : len(symbol) - 2]
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

    return rustbucket#identifier#New({
          \ 'symbol':    symbol,
          \ 'full_path': namespace . symbol,
          \ 'type':      identifier_type,
          \ })
  finally
    call winrestview(saved_view)
  endtry
endfunction

function! rustbucket#identifier#IsBlank() dict abort
  return self.symbol == ''
endfunction

function! rustbucket#identifier#RealPath() dict abort
  if self.real_path != ''
    return self.real_path
  endif

  if self.full_path != ''
    let self.real_path = b:imports.Resolve(self.full_path)
  elseif self.symbol != ''
    let self.real_path = b:imports.Resolve(self.symbol)
  endif

  return self.real_path
endfunction

function! rustbucket#identifier#Type() dict abort
  if self.type != ''
    return self.type
  endif

  if self.symbol == ''
    return ''
  endif

  let best_tag = {}
  let taglist = taglist(self.symbol)

  " First, look for a tag that matches by full path:
  for tag in taglist
    " Check if we have some namespacing info in the tag:
    let tag_full_path = ''
    if has_key(tag, 'module')
      let tag_full_path = tag.module . '::' . tag.name
    elseif has_key(tag, 'implementation')
      let tag_full_path = tag.implementation . '::' . tag.name
    endif

    if self.full_path != '' && tag_full_path != '' && self.full_path =~ tag_full_path.'$'
      " The identifier's full path ends with the tag's full path, this should
      " be the best we can hope for:
      let best_tag = tag
      break
    endif
  endfor

  " Try looking for a tag that has a "kind" we know about:
  if empty(best_tag)
    for tag in taglist
      if get(tag, 'kind', '') =~ '^[sgP]$'
        let best_tag = tag
        break
      endif
    endfor
  endif

  if !empty(best_tag) && has_key(best_tag, 'kind')
    if best_tag.kind == 's'
      let self.type = 'struct'
    elseif best_tag.kind == 'g'
      let self.type = 'enum'
    elseif best_tag.kind == 'P'
      let self.type = 'fn'
    endif
  endif

  return self.type
endfunction

function! rustbucket#identifier#PackageWithVersion() dict abort
  let real_path = self.RealPath()
  if real_path == ''
    return ['', '']
  endif

  let package = split(real_path, '::')[0]
  if package == 'std'
    return ['std', '']
  elseif package == 'crate'
    " TODO (2021-02-12) Parse crate name + version
    return ['crate', '']
  endif

  return [package, s:ParsePackageVersion(package)]
endfunction

function! s:ParsePackageVersion(package)
  let lockfile = findfile('Cargo.lock', '.;')
  if lockfile == ''
    return ''
  endif

  let package_data = systemlist("grep -A1 'name = \"".a:package."\"' ".lockfile)
  if len(package_data) == 0
    return ''
  endif

  let version_breakdowns = []
  for i in range(1, len(package_data), 2)
    let package_version = matchstr(package_data[i], 'version = "\zs\d\+\.\d\+\.\d\+\ze"')
    let version_breakdown = map(split(package_version, '\.'), 'str2nr(v:val)')
    call add(version_breakdowns, version_breakdown)
  endfor

  call sort(version_breakdowns)

  return join(version_breakdowns[0], '.')
endfunction
