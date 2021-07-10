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
