" TODO (2021-02-12) import anyhow::anyhow, but then anyhow::Result?

function! rustbucket#Doc() abort
  let urls = rustbucket#DocUrls()
  if empty(urls)
    return
  endif

  let target_url = ''

  if s:CheckUrl(urls.best_guess)
    let target_url = urls.best_guess
  else
    for url in urls.fallbacks
      if s:CheckUrl(url)
        let target_url = url
      endif
    endfor
  endif

  if target_url != ''
    echomsg "Opening: ".target_url
    call rustbucket#util#Open(target_url)
  else
    echomsg "Couldn't find a valid doc URL from ".string(urls)
  endif
endfunction

function! s:CheckUrl(url)
  " Note: Might add -L to follow redirects, but ideally should be correct URL
  let curl_command = 'curl -Is -o /dev/null -w "%{http_code}" '.shellescape(a:url)
  let status_code = trim(system(curl_command))
  return status_code == '200'
endfunction

function! rustbucket#DocUrls() abort
  " TODO (2021-01-31) WebContext::get_default() -> func call, not namespace.
  " Read bracket?

  let identifier = rustbucket#identifier#AtCursor()
  let real_path = identifier.RealPath()
  if real_path == ''
    echomsg "Can't figure out the real path of: ".real_path
    return ''
  endif

  let term_path = split(real_path, '::')
  let [package, package_version] = identifier.Package()
  let term_name = term_path[-1]

  if package == term_path[0] || package == substitute(term_path[0], '_', '-', 'g')
    " We can safely remove it from the path
    call remove(term_path, 0)
  endif

  let path = join(term_path[0:-2], '/')

  if package == 'std'
    let base_url = 'https://doc.rust-lang.org/'
  elseif len(term_path) > 0 && term_path[0] == 'crate'
    echomsg "Local documentation not supported yet: ".term
    return ''
  else
    if package_version == ''
      let package_version = 'latest'
    endif

    let base_url = 'https://docs.rs/'.package.'/'.package_version
  endif

  if term_name == ''
    if package == 'std'
      return {
            \ 'best_guess': base_url,
            \ 'fallbacks': [],
            \ }
    else
      return {
            \ 'best_guess': base_url . '/' . term_name . '/',
            \ 'fallbacks': [],
            \ }
    endif
  elseif len(term_path) == 0
    " it's just the package/crate name
    return {
          \ 'best_guess': base_url . '/' . term_name . '/',
          \ 'fallbacks': [],
          \ }
  endif

  let type = identifier.Type()
  let search_url = s:NormalizeUrl(base_url . '/' . package . '/?search=' . term_name)

  if type =~ '^\(macro\|struct\|enum\|fn\)$'
    let best_url = s:NormalizeUrl(base_url.'/'.package.'/'.path.'/'.type.'.'. term_name.'.html')
    let fallbacks = [search_url]
  else
    let best_url = search_url
    let fallbacks = []
  endif

  return {
        \ 'best_guess': best_url,
        \ 'fallbacks': fallbacks
        \ }
endfunction

function! s:NormalizeUrl(url)
  return substitute(a:url, '[^:]\zs//', '/', 'g')
endfunction

function! rustbucket#Info() abort
  let identifier = rustbucket#identifier#AtCursor()

  if identifier.IsBlank()
    let lines = ["No info for identifier under cursor"]
  else
    let doc_urls = rustbucket#DocUrls()
    let lines = [
          \ "Real path: " . identifier.RealPath(),
          \ "Type:      " . identifier.Type(),
          \ "Package:   " . join(identifier.Package(), ' '),
          \ "Doc URLs:"
          \ ]

    call add(lines, " - Best Guess: " . doc_urls.best_guess)

    let index = 1
    for url in doc_urls.fallbacks
      call add(lines, " - Fallback " . index . ": " . url)
      let index += 1
    endfor

    call popup_atcursor(lines, {'border': []})
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

function! rustbucket#GenerateTags()
  let rust_sysroot = systemlist('rustc --print sysroot')

  if v:shell_error
    call s:EchoWarning("Couldn't execute `rustc --print sysroot`: ".rust_sysroot)
    return
  elseif empty(rust_sysroot)
    call s:EchoWarning("Couldn't find rust source from `rustc --print sysroot`")
  else
    for package in ['std', 'alloc']
      let src_location = fnamemodify(rust_sysroot[0] . '/lib/rustlib/src/rust/library/'.package.'/src', ':p')
      let output = system('ctags -f '.shellescape(src_location.'/tags').' -R '.shellescape(src_location))

      if v:shell_error
        call s:EchoWarning("Couldn't execute ctags command: ".output)
        return
      endif
    endfor
  endif
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

function! s:EchoWarning(message)
  echohl WarningMsg
  exe 'echomsg "'.escape(a:message, '"\').'"'
  echohl NONE
endfunction
