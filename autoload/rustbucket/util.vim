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
  exec 'silent normal! '.a:motion.'"zy'
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
