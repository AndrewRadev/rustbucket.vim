function! rustbucket#toml#Doc()
  let saved_view = winsaveview()

  try
    if !rustbucket#util#SearchUnderCursor('\%([[:keyword:]-]\+\)\ze\s*=')
      return
    endif

    let package_name = trim(rustbucket#util#GetMotion('vt='))
    if package_name == ''
      return
    endif

    let url = 'https://crates.io/crates/'.package_name

    " Is there an explicit definition we can get a url out of?
    if search('=\s*\zs{', 'W', line('.'))
      let string_definition = rustbucket#util#GetMotion('va{')
      let json_definition = substitute(string_definition, '\([[:keyword:]-]\+\)\s*=', '"\1": ', 'g')
      let definition = json_decode(json_definition)

      if has_key(definition, 'git') && definition.git =~ '^https\=://'
        let url = definition.git

        if has_key(definition, 'branch')
          let url .= '/tree/' . definition.branch
        elseif has_key(definition, 'rev')
          let url .= '/tree/' . definition.rev
        elseif has_key(definition, 'tag')
          let url .= '/tree/' . definition.tag
        endif
      elseif has_key(definition, 'version')
        let url .= '/' . definition.version
      endif
    endif

    echomsg "Opening: ".url
    call rustbucket#util#Open(url)
  finally
    call winrestview(saved_view)
  endtry
endfunction
