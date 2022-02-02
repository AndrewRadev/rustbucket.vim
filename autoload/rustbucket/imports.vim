function! rustbucket#imports#Init()
  " import_lookup: {
  "   symbol: [{
  "     full_path: string,
  "     range:     [start, end]
  "   }, ...]
  " }

  " TODO (2022-01-16) Fix tests, write more
  " TODO (2022-01-16) Highlight things in scope

  return {
        \ 'import_lookup': {},
        \
        \ 'Parse':   function('rustbucket#imports#Parse'),
        \ 'Resolve': function('rustbucket#imports#Resolve'),
        \ }
endfunction

function! rustbucket#imports#Resolve(symbol) dict abort
  " TODO (2021-02-09) Only parse when changedtick changes
  call self.Parse()

  let [head; rest] = split(a:symbol, '::')
  let full_path = ''
  if has_key(self.import_lookup, head)
    let global_full_path = ''

    for entry in self.import_lookup[head]
      if entry.range[0] <= 0
        let global_full_path = entry.full_path
      elseif entry.range[0] <= line('.') && line('.') <= entry.range[1]
        let full_path = entry.full_path
      endif
    endfor

    if full_path == '' && global_full_path != ''
      let full_path = global_full_path
    endif
  endif

  if full_path == ''
    let full_path = head
  endif
  let full_path = extend([full_path], rest)

  return join(full_path, '::')
endfunction

function! rustbucket#imports#Parse() dict abort
  let self.import_lookup = {}
  let alias_lookup = {}
  let skip = rustbucket#util#SkipSyntax(['rustString', 'rustComment'])

  " TODO (2021-02-09) Islands with [start, end] line coordinates

  call rustbucket#util#PushCursor()
  " Start from end, loop only for the first search
  call s:JumpToEnd()
  let flags = 'w'

  while search('^\s*use', flags, skip) > 0
    let flags = 'W'
    let line = getline('.')
    let namespace = matchstr(line, '^\s*use \zs.\+\ze::')
    let symbols = []

    if line =~ '::\k\+ as \k\+;'
      let real_name      = matchstr(line, 'use\s\+\zs\%(::\|\k\+\)\+\ze as \k\+;')
      let alias          = matchstr(line, '::\k\+ as \zs\k\+\ze;')
      let symbols        = [alias]
      let alias_lookup[alias] = split(real_name, '::')[-1]
    endif

    if symbols == []
      let symbols = [matchstr(line, '::\zs\k\+\ze;')]
    endif
    if symbols == [""]
      let symbols = split(matchstr(line, '::{\zs.*\ze};'), ',\s*')
    endif
    if symbols == []
      continue
    endif

    let range = [-1, -1]
    if searchpair('{', '', '}', 'W', skip) > 0
      let range[0] = line('.')
      let range[1] = searchpair('{', '', '}', 'W', skip)
    endif

    for symbol in symbols
      if symbol == 'self'
        let symbol = split(namespace, '::')[-1]

        if !has_key(self.import_lookup, symbol)
          let self.import_lookup[symbol] = []
        endif

        call add(self.import_lookup[symbol], { 'full_path': namespace, 'range': range })
      elseif has_key(alias_lookup, symbol)
        if !has_key(self.import_lookup, symbol)
          let self.import_lookup[symbol] = []
        endif

        call add(self.import_lookup[symbol], { 'full_path': namespace . '::' . alias_lookup[symbol], 'range': range })
      else
        if !has_key(self.import_lookup, symbol)
          let self.import_lookup[symbol] = []
        endif

        call add(self.import_lookup[symbol], { 'full_path': namespace . '::' . symbol, 'range': range })
      endif
    endfor
  endwhile

  call rustbucket#util#PopCursor()
endfunction

" Note: normal! not allowed during gf
function s:JumpToEnd()
  let pos = getpos('.')
  let pos[1] = line('$')
  call setpos('.', pos)
  let pos[2] = col('$')
  call setpos('.', pos)
endfunction
