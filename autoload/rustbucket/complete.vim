" TODO: Only works for `crate::`, needs a lot more work

function! rustbucket#complete#Mapping()
  let b:saved_completefunc = &completefunc
  setlocal completefunc=rustbucket#complete#CompleteFunc

  autocmd CompleteDone * ++once let &completefunc = b:saved_completefunc
  autocmd CompleteDone * ++once unlet b:saved_completefunc

  return "\<c-x>\<c-u>"
endfunction

function! rustbucket#complete#CompleteFunc(findstart, base)
  if a:findstart
    let [_, start_col] = searchpos('^\s*use \zscrate::[[:keyword:]:]*::', 'bWne', line('.'))

    if start_col <= 1
      return -3 " cancel completion
    else
      return start_col
    endif
  else
    let import = substitute(getline('.'), '^\s*use crate::', '', '')
    let module_path = split(import, '::', 1)

    " remove last part, we're completing it
    let item = remove(module_path, -1)

    let file = 'src/'..join(module_path, '/')..'.rs'
    if !filereadable(file)
      let file = 'src/'..join(module_path, '/')..'/mod.rs'
    endif

    let exports = []
    let export_pattern = '^\s*pub \%(fn\|struct\|trait\|enum\) \zs\k\+'

    for line in readfile(file)
      if line !~ export_pattern
        continue
      endif

      let match = matchstr(line, export_pattern)

      if stridx(match, a:base) != 0
        continue
      endif

      let taglist = taglist('^'..match..'$', file)
      let tag     = taglist->get(0, {})
      let kind    = tag->get('kind', '')

      if kind == 'P'
        continue
      endif

      call add(exports, { 'word': match, 'menu': trim(line) })
    endfor

    return sort(exports, { a, b -> a.word == b.word ? 0 : a.word > b.word })
  endif
endfunction
