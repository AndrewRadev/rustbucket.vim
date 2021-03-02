function! rustbucket#imports#Init()
  return {
        \ 'import_lookup': {},
        \
        \ 'Parse':    function('rustbucket#imports#Parse'),
        \ 'Resolve': function('rustbucket#imports#Resolve'),
        \ }
endfunction

function! rustbucket#imports#Resolve(symbol) dict abort
  " TODO (2021-02-09) Only parse when changedtick changes
  call self.Parse()

  let [head; rest] = split(a:symbol, '::')
  let full_head = get(self.import_lookup, head, head)
  let full_path = extend([full_head], rest)

  return join(full_path, '::')
endfunction

function! rustbucket#imports#Parse() dict abort
  let self.import_lookup = {}
  let alias_lookup = {}

  " TODO (2021-02-09) Islands with [start, end] line coordinates

  for line in filter(getline(1, '$'), {_, l -> l =~ '^\s*use'})
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

    for symbol in symbols
      if symbol == 'self'
        let symbol = split(namespace, '::')[-1]
        let self.import_lookup[symbol] = namespace
      elseif has_key(alias_lookup, symbol)
        let self.import_lookup[symbol] = namespace . '::' . alias_lookup[symbol]
      else
        let self.import_lookup[symbol] = namespace . '::' . symbol
      endif
    endfor
  endfor
endfunction
