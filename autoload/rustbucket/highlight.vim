if !has('textprop')
  finish
endif

hi rustbucketImport cterm=underline gui=underline

function! rustbucket#highlight#Imports()
  if !exists('b:imports')
    return
  endif

  if empty(prop_type_get('rustbucket_import', {'bufnr': bufnr('%')}))
    call prop_type_add('rustbucket_import', {
          \ 'bufnr':     bufnr('%'),
          \ 'highlight': 'rustbucketImport',
          \ 'combine':   v:true
          \ })
  endif

  " Clear out any previous matches
  call prop_remove({'type': 'rustbucket_import', 'all': v:true})

  call b:imports.Parse()
  let project_pattern = '^\(crate\|'.rustbucket#util#UnderscoredProjectName().'\)::'
  let findable_imports = []

  for [import, entries] in items(b:imports.import_lookup)
    for entry in entries
      if entry.full_path =~ project_pattern
        call add(findable_imports, import)
      endif
    endfor
  endfor

  if empty(findable_imports)
    return
  endif

  let import_pattern = '\<\%('.join(findable_imports, '\|').'\)\>'
  let saved_view = winsaveview()

  try
    normal! gg

    let skip_expr = 'synIDattr(synID(line("."), col("."), 0), "name") =~ "String\\|Comment"'

    while search(import_pattern, 'W', 0, 0, skip_expr)
      call prop_add(line('.'), col('.'), {
            \ 'length': len(expand('<cword>')),
            \ 'type': 'rustbucket_import'
            \ })
    endwhile
  finally
    call winrestview(saved_view)
  endtry
endfunction
