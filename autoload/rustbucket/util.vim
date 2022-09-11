" vim: foldmethod=marker

" Cursor stack manipulation {{{1
"
" In order to make the pattern of saving the cursor and restoring it
" afterwards easier, these functions implement a simple cursor stack. The
" basic usage is:
"
"   call rustbucket#util#PushCursor()
"   " Do stuff that move the cursor around
"   call rustbucket#util#PopCursor()
"
" function! rustbucket#util#PushCursor() {{{2
"
" Adds the current cursor position to the cursor stack.
function! rustbucket#util#PushCursor()
  if !exists('b:cursor_position_stack')
    let b:cursor_position_stack = []
  endif

  call add(b:cursor_position_stack, winsaveview())
endfunction

" function! rustbucket#util#PopCursor() {{{2
"
" Restores the cursor to the latest position in the cursor stack, as added
" from the rustbucket#util#PushCursor function. Removes the position from the stack.
function! rustbucket#util#PopCursor()
  call winrestview(remove(b:cursor_position_stack, -1))
endfunction

" function! rustbucket#util#DropCursor() {{{2
"
" Discards the last saved cursor position from the cursor stack.
" Note that if the cursor hasn't been saved at all, this will raise an error.
function! rustbucket#util#DropCursor()
  call remove(b:cursor_position_stack, -1)
endfunction

" Text retrieval {{{1
"
" These functions are similar to the text replacement functions, only retrieve
" the text instead.
"
" function! rustbucket#util#GetMotion(motion) {{{2
"
" Execute the normal mode motion "motion" and return the text it marks.
"
" Note that the motion needs to include a visual mode key, like "V", "v" or
" "gv"
function! rustbucket#util#GetMotion(motion)
  call rustbucket#util#PushCursor()

  let saved_register_text = getreg('z', 1)
  let saved_register_type = getregtype('z')
  let saved_opening_visual = getpos("'<")
  let saved_closing_visual = getpos("'>")

  let @z = ''
  exec 'silent noautocmd normal! '.a:motion.'"zy'
  let text = @z

  if text == ''
    " nothing got selected, so we might still be in visual mode
    exe "normal! \<esc>"
  endif

  call setreg('z', saved_register_text, saved_register_type)
  call setpos("'<", saved_opening_visual)
  call setpos("'>", saved_closing_visual)
  call rustbucket#util#PopCursor()

  return text
endfunction

" function! rustbucket#util#GetCols(start, end) {{{2
"
" Retrieve the text from columns "start" to "end" on the current line.
function! rustbucket#util#GetCols(start, end)
  return strpart(getline('.'), a:start - 1, a:end - a:start + 1)
endfunction

" External programs {{{1
"
" Interacting with external programs -- so far, just the act of opening a URL
" with the default browser.
"
" function! rustbucket#util#Open(url) {{{2
"
function! rustbucket#util#Open(url)
  let url = shellescape(a:url)

  if has('mac')
    silent call system('open '.url)
  elseif has('unix')
    if executable('xdg-open')
      silent call system('xdg-open '.url.' 2>&1 > /dev/null &')
    else
      echoerr 'You need to install xdg-open to be able to open urls'
      return
    end
  elseif has('win32') || has('win64')
    silent exe "! start ".a:url
  else
    echoerr 'Don''t know how to open a URL on this system'
    return
  end
endfunction

" Cargo {{{1
"
" function rustbucket#util#ProjectName() {{{2
"
function rustbucket#util#ProjectName()
  let cargo_toml = findfile('Cargo.toml', '.;')
  if cargo_toml == ''
    return ''
  endif

  let lines = readfile(cargo_toml)
  if len(lines) == 0
    return ''
  endif

  let index = 0
  let project_name = ''

  while index < len(lines) && lines[index] !~ '^\s*\[package\]'
    let index += 1
  endwhile

  while index < len(lines) && lines[index] !~ '^\s*name\s*='
    let index += 1
  endwhile

  if index >= len(lines)
    return ''
  else
    return matchstr(lines[index], '^\s*name\s*=\s*[''"]\zs[[:keyword:]-]\+\ze[''"]')
  endif
endfunction

"
" function rustbucket#util#UnderscoredProjectName() {{{2
"
function rustbucket#util#UnderscoredProjectName()
  return substitute(rustbucket#util#ProjectName(), '-', '_', 'g')
endfunction

" Searching callbacks after file navigation {{{1
"
" function rustbucket#util#SetFileOpenCallback(filename, ...) {{{2
"
function! rustbucket#util#SetFileOpenCallback(filename, ...)
  let searches = a:000
  let filename = fnamemodify(a:filename, ':p')

  augroup rustbucket_file_open_callback
    autocmd!

    exe 'autocmd BufEnter '.filename.' normal! gg'
    for pattern in searches
      exe 'autocmd BufEnter '.filename.' call search("'.escape(pattern, '"\').'")'
    endfor
    exe 'autocmd BufEnter '.filename.' call rustbucket#util#ClearFileOpenCallback()'
  augroup END
endfunction

" function rustbucket#util#ClearFileOpenCallback() {{{2
"
function! rustbucket#util#ClearFileOpenCallback()
  augroup rustbucket_file_open_callback
    autocmd!
  augroup END
endfunction

" Searching for patterns {{{1
"
" function! rustbucket#util#SearchUnderCursor(pattern, flags, skip) {{{2
"
" Searches for a match for the given pattern under the cursor. Returns the
" result of the |search()| call if a match was found, 0 otherwise.
"
" Moves the cursor unless the 'n' flag is given.
"
" The a:flags parameter can include one of "e", "p", "s", "n", which work the
" same way as the built-in |search()| call. Any other flags will be ignored.
"
function! rustbucket#util#SearchUnderCursor(pattern, ...)
  let [match_start, match_end] = call('rustbucket#util#SearchColsUnderCursor', [a:pattern] + a:000)
  if match_start > 0
    return match_start
  else
    return 0
  endif
endfunction

" function! rustbucket#util#SearchColsUnderCursor(pattern, flags, skip) {{{2
"
" Searches for a match for the given pattern under the cursor. Returns the
" start and (end + 1) column positions of the match. If nothing was found,
" returns [0, 0].
"
" Moves the cursor unless the 'n' flag is given.
"
" Respects the skip expression if it's given.
"
" See rustbucket#util#SearchUnderCursor for the behaviour of a:flags
"
function! rustbucket#util#SearchColsUnderCursor(pattern, ...)
  if a:0 >= 1
    let given_flags = a:1
  else
    let given_flags = ''
  endif

  if a:0 >= 2
    let skip = a:2
  else
    let skip = ''
  endif

  let lnum        = line('.')
  let col         = col('.')
  let pattern     = a:pattern
  let extra_flags = ''

  " handle any extra flags provided by the user
  for char in ['e', 'p', 's']
    if stridx(given_flags, char) >= 0
      let extra_flags .= char
    endif
  endfor

  call rustbucket#util#PushCursor()

  " find the start of the pattern
  call search(pattern, 'bcW', lnum)
  let search_result = rustbucket#util#SearchSkip(pattern, skip, 'cW'.extra_flags, lnum)
  if search_result <= 0
    call rustbucket#util#PopCursor()
    return [0, 0]
  endif

  call rustbucket#util#PushCursor()

  " find the end of the pattern
  if stridx(extra_flags, 'e') >= 0
    let match_end = col('.')

    call rustbucket#util#PushCursor()
    call rustbucket#util#SearchSkip(pattern, skip, 'cWb', lnum)
    let match_start = col('.')
    call rustbucket#util#PopCursor()
  else
    let match_start = col('.')
    call rustbucket#util#SearchSkip(pattern, skip, 'cWe', lnum)
    let match_end = col('.')
  end

  " set the end of the pattern to the next character, or EOL. Extra logic
  " is for multibyte characters.
  normal! l
  if col('.') == match_end
    " no movement, we must be at the end
    let match_end = col('$')
  else
    let match_end = col('.')
  endif
  call rustbucket#util#PopCursor()

  if !rustbucket#util#ColBetween(col, match_start, match_end)
    " then the cursor is not in the pattern
    call rustbucket#util#PopCursor()
    return [0, 0]
  else
    " a match has been found
    if stridx(given_flags, 'n') >= 0
      call rustbucket#util#PopCursor()
    else
      call rustbucket#util#DropCursor()
    endif

    return [match_start, match_end]
  endif
endfunction

" function! rustbucket#util#SearchSkip(pattern, skip, ...) {{{2
" A partial replacement to search() that consults a skip pattern when
" performing a search, just like searchpair().
"
" Note that it doesn't accept the "n" and "c" flags due to implementation
" difficulties.
function! rustbucket#util#SearchSkip(pattern, skip, ...)
  " collect all of our arguments
  let pattern = a:pattern
  let skip    = a:skip

  if a:0 >= 1
    let flags = a:1
  else
    let flags = ''
  endif

  if stridx(flags, 'n') > -1
    echoerr "Doesn't work with 'n' flag, was given: ".flags
    return
  endif

  let stopline = (a:0 >= 2) ? a:2 : 0
  let timeout  = (a:0 >= 3) ? a:3 : 0

  if skip == ''
    " no skip, can delegate to native search()
    return search(pattern, flags, stopline, timeout)
  elseif has('patch-8.2.915')
    " the native search() function can do this now:
    return search(pattern, flags, stopline, timeout, skip)
  endif

  " search for the pattern, skipping a match if necessary
  let skip_match = 1
  while skip_match
    let match = search(pattern, flags, stopline, timeout)

    " remove 'c' flag for any run after the first
    let flags = substitute(flags, 'c', '', 'g')

    if match && eval(skip)
      let skip_match = 1
    else
      let skip_match = 0
    endif
  endwhile

  return match
endfunction

function! rustbucket#util#SkipSyntax(syntax_groups)
  let syntax_groups = a:syntax_groups
  let skip_pattern  = '\%('.join(syntax_groups, '\|').'\)'

  return "synIDattr(synID(line('.'),col('.'),1),'name') =~ '".skip_pattern."'"
endfunction


" Checks if the given column is within the given limits.
"
function! rustbucket#util#ColBetween(col, start, end)
  return a:start <= a:col && a:end > a:col
endfunction
