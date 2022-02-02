function! rustbucket#gf#Includeexpr(...)
  if a:0 > 0
    let filename = a:1
  else
    let filename = expand('<cword>')
  endif

  " call b:imports.Parse()
  let path = split(b:imports.Resolve(filename), '::')
  if len(path) == 0
    return filename
  endif

  let package = remove(path, 0)
  if package != 'crate' && package != rustbucket#util#ProjectName()
    return filename
  endif

  " If we're here, we've got a path prefix of a local file, let's see if it's
  " a file
  let root = finddir('src', '.;') . '/'
  let imported_filename =  root . join(path, '/') . '.rs'
  if filereadable(imported_filename)
    return imported_filename
  endif

  let exported_symbol = remove(path, -1)
  let imported_filename =  root . join(path, '/') . '.rs'
  if filereadable(imported_filename)
    call s:AttachSearch(
          \ imported_filename,
          \ ['pub\s\+\%(struct\|enum\|trait\|const\)\s\+\zs'.exported_symbol]
          \ )
    return imported_filename
  endif

  " We couldn't find anything, let's just return the filename under the cursor
  return expand('<cfile>')
endfunction

function! s:AttachSearch(filename, searches)
  if len(a:searches) > 0 && filereadable(a:filename)
    call call('rustbucket#util#SetFileOpenCallback', extend([a:filename], a:searches))
  endif
endfunction
