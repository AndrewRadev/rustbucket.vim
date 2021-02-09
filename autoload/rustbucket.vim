" TODO (2021-02-08) Open() function expected -- need a local one

function! rustbucket#Doc() abort
  " TODO (2021-01-31) WebContext::get_default() -> func call, not namespace.
  " Read bracket?

  let term = rustbucket#GetRustIdentifier()

  if term[len(term) - 1] == '!'
    let is_macro = 1
    let term = term[0:(len(term) - 2)]
  else
    let is_macro = 0
  endif

  let [imported_symbols, aliases] = rustbucket#ParseImports()
  let term_head = split(term, '::')[0]

  if has_key(imported_symbols, term_head)
    let term = imported_symbols[term_head] . '::' . term
  elseif has_key(aliases, term_head)
    let term = aliases[term_head] . '::' . term
  elseif has_key(s:std_prelude, term_head)
    let term = s:std_prelude[term_head] . '::' . term
  endif

  let term_path = split(term, '::')

  if term_path[0] == 'std'
    call Open('https://doc.rust-lang.org/std/?search='.term)
  elseif term_path[0] == 'crate'
    echomsg "Local documentation not supported yet: ".term
    return
  else
    let package = term_path[0]
    let term_name = term_path[-1]
    let path = join(term_path[0:-2], '/')

    let package_version = s:ParsePackageVersion(package)
    if package_version == ''
      let package_version = 'latest'
    endif

    let url = 'https://docs.rs/'.package.'/'.package_version.'/'.path

    if is_macro
      let url .= '/macro.'.term_name.'.html'
    else
      let url .= '/?search='.term_name
    endif

    let url = substitute(url, '//', '/', 'g')

    call Open(url)
    return
  endif
endfunction

function! rustbucket#ParseImports()
  let imported_symbols = {}
  let aliases = {}

  for line in filter(getline(1, '$'), {_, l -> l =~ '^\s*use'})
    let namespace = matchstr(line, '^\s*use \zs.\+\ze::')
    let symbols = []

    if line =~ '::\k\+ as \k\+;'
      let real_name      = matchstr(line, 'use\s\+\zs\%(::\|\k\+\)\+\ze as \k\+;')
      let alias          = matchstr(line, '::\k\+ as \zs\k\+\ze;')
      let symbols        = [alias]
      let aliases[alias] = real_name
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
      let imported_symbols[symbol] = namespace
    endfor
  endfor

  return [imported_symbols, aliases]
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

" TODO (2021-02-08) Write down version, link to source
let s:std_prelude = {
      \ 'Copy':                'std::marker::Copy',
      \ 'Send':                'std::marker::Send',
      \ 'Sized':               'std::marker::Sized',
      \ 'Sync':                'std::marker::Sync',
      \ 'Unpin':               'std::marker::Unpin',
      \ 'Drop':                'std::ops::Drop',
      \ 'Fn':                  'std::ops::Fn',
      \ 'FnMut':               'std::ops::FnMut',
      \ 'FnOnce':              'std::ops::FnOnce',
      \ 'drop':                'std::mem::drop',
      \ 'Box':                 'std::boxed::Box',
      \ 'ToOwned':             'std::borrow::ToOwned',
      \ 'Clone':               'std::clone::Cone',
      \ 'PartialEq':           'std::cmp::PartialEq',
      \ 'PartialOrd':          'std::cmp::PartialOrd',
      \ 'Eq':                  'std::cmp::Eq',
      \ 'Ord':                 'std::cmp::Ord',
      \ 'AsRef':               'std::convert::AsRef',
      \ 'AsMut':               'std::convert::AsMut',
      \ 'Into':                'std::convert::Into',
      \ 'From':                'std::convert::From',
      \ 'Default':             'std::default::Default',
      \ 'Iterator':            'std::iter::Iterator',
      \ 'Extend':              'std::iter::Extend',
      \ 'IntoIterator':        'std::iter::IntoIterator',
      \ 'DoubleEndedIterator': 'std::iter::DoubleEndedIterator',
      \ 'ExactSizeIterator':   'std::iter::ExactSizeIterator',
      \ 'Option':              'std::option',
      \ 'Some':                'std::option::Option',
      \ 'None':                'std::option::Option',
      \ 'Result':              'std::result',
      \ 'Ok':                  'std::result::Result',
      \ 'Err':                 'std::result::Result',
      \ 'String':              'std::string::String',
      \ 'ToString':            'std::string::ToString',
      \ 'Vec':                 'std::vec::Vec',
      \ }
