" snipplr.vim 
" ============
" Snipplr.vim is frontend for http://www.snipplr.com/
" You can open your favoritted snippet or get snippet you specified by ID or URL.
" 
" INSTALL
" ---------------
" 
"    cp plugin/snipplr.vim $HOME/.vim/plugin/
"    cp syntax/snipplrlist.vim $HOME/.vim/syntax/
"    copy bin/snipplr.rb to one of the directory in $PATH
" 
" SETUP
" ---------------
" 
" Create account on http://www.snipplr.com/
" You can find API KEY at buttom of "Setting" page.
" 
" then save API KEY as `~/.snipplr/api_key`
" 
" GLOVAL VARIABLE
" ---------------
" You can exclusively set path for snipplr.rb in `.vimrc`
" 
"     let g:snipplr_rb = '$HOME/.vim/bundle/snipplr/bin/snipplr.rb'
" 
" Command
" ----------
" 
" snipplr.rb save snippets once get as `~/.snipplr/db.yml.`
" You can avoid cache with exlamation(!) version command.
" 
" ### SnipplrGet
" In opend snippet buffer you can use 'i' to view informatin about that snippet.
" 
"     :SnipplrGet 1234
"     :SnipplrGet http://snipplr.com/view/1234/sample
" 
" ### SnipplrList
" 
"     :SnipplrList
"     :SnipplrList!
" 
" ### SnipplrFind
" To this comman work, you have to install [ fuzzyfinder ]( http://www.vim.org/scripts/script.php?script_id=1984 )
" 
"     :SnipplrFind
"     :SnipplrFind!
" 
" KeyMapping Example
" ------------------
" 
"     nnoremap <silent> <Space>sl :<C-u>SnipplrFind<CR>
"     nnoremap <silent> <Space>sr :<C-u>SnipplrFind!<CR>
" 
" TODO
" ------------------
" parametarize cache dir and api_key location etc..  
" query with metadata(tag, user.. etc)  
" post snippet from vim buffer  
" more informative syntax highlight with predefined keyword for lang name  
" dynamically change window height for snipplr list  
" merge more than one cache data to one cache(which is comvenient for  
"    collabolate with coworker

if exists('g:loaded_snipplr') || &cp || version < 700
    finish
endif
let g:loaded_snipplr = 1

"for line continuation - i.e dont want C in &cpo
let s:old_cpo = &cpo
set cpo&vim

" main
command! -nargs=1 -bang SnipplrGet  :call <SID>SnipplrGet(<q-args>, <bang>0)
command! -nargs=0 -bang SnipplrFind :call <SID>SnipplrFind(<bang>0)
command! -nargs=? -bang SnipplrList :call <SID>SnipplrOpenList(<bang>0, <q-args>)

if !exists("g:snipplr_rb")
  let g:snipplr_rb = "snipplr.rb"
endif

let s:listener = {}
function! s:listener.onComplete(item, method)
  call s:SnipplrGetFromList(a:item, 'local')
endfunction

function! s:listener.onAbort()
    echo "Abort"
endfunction

function! s:SnipplrFind(bang, ...)
  if a:0 == 1
    if !empty(a:1)
      let items  = s:SnipplrList(a:bang, a:1)
    endif
  else
    let items = s:SnipplrList(a:bang)
  endif

  call fuf#callbackitem#launch('', 0, 'Snipplr>', s:listener, items, 0)
endfunction

function! s:SnipplrOpenList(where, ...)
  if a:0 == 1
    if !empty(a:1)
      let snippet_list = s:SnipplrCreateList(a:where, a:1)
    else
      let snippet_list = s:SnipplrCreateList(a:where)
    endif
  else
    let snippet_list = s:SnipplrCreateList(a:where)
  endif

  let tempfile = tempname()
  call writefile(snippet_list, tempfile)
  belowright split 
  exec "edit " . tempfile
  call cursor(1, 1)
  call s:PrepareListBuffer(a:where)
endfunction

function! s:SnipplrRefreshList(where)
  let snippet_list = s:SnipplrCreateList(a:where)
  setlocal modifiable
  silent! normal ggdG
  call setline(1, snippet_list)
endfunction

function! s:PrepareListBuffer(where)
  setlocal nomodifiable
  set buftype=nofile
  set bufhidden=hide
  setlocal noswapfile
  set ft&
  set syntax=snipplrlist
  let b:snipplr_where = a:where
  nnoremap <buffer> <silent> <CR> :call <SID>SnipplrGetFromList(getline('.'),0)<CR>
  nnoremap <buffer> <silent> u :call <SID>SnipplrGetFromList(getline('.'), 1)<CR>
  nnoremap <buffer> <silent> D :call <SID>SnipplrDeleteFromList(getline('.'))<CR>
  nnoremap <buffer> <silent> i :call <SID>SnipplrInfoFromList(getline('.'))<CR>
  nnoremap <buffer> <silent> r :call <SID>SnipplrRefreshList(b:snipplr_where)<CR>
  nnoremap <buffer> <silent> c :<C-u>bdelete<CR>
endfunction


function! s:SnipplrCreateList(where,...)
  if a:0 == 1
    if !empty(a:1)
      let snippet_list = s:SnipplrList(a:where, a:1)
    endif
  else
    let snippet_list = s:SnipplrList(a:where)
  endif

  let helpstr = "# [D]elete, [u]pdate, [i]nfo, [c]lose, [r]efresh"
  call insert(snippet_list, helpstr)
  return snippet_list
endfunction

function! s:SnipplrGetFromList(line, where)
  let snippet_id = split(a:line, " ")[0]

  call s:SnipplrGet(snippet_id, a:where)
endfunction


function! s:SnipplrInfoFromList(line)
  let snippet_id = split(a:line, " ")[0]
  call SnipplrInfo(snippet_id)
endfunction

function! s:SnipplrDeleteFromList(line)
  let snippet_id = split(a:line, " ")[0]
  let answer = input("Delete [" . snippet_id . "] ?[Y/n]")
  if answer =~? 'y\|^$'
    call s:SnipplrDelete(snippet_id)
    wincmd c
    call s:SnipplrOpenList('local')
  endif
endfunction

function! s:SnipplrList(bang,...)
  let cmd = "ruby " . g:snipplr_rb . " -l "
  if a:bang == 1
    let cmd = cmd . " --nocache"
  endif

  if a:0 == 1
    if !empty(a:1)
      let cmd = cmd . " --lang " . a:1
    endif
  endif

  return split(system(cmd), "\n")
endfunction

function! s:SnipplrGet(query, bang)
  let tempfile = tempname()
  "let cmd = 'snipplr -g ' . a:snippet_id
  let cmd = "ruby " . g:snipplr_rb . ' -g ' . a:query
  if a:bang == 1
    let cmd = cmd . " --nocache"
  endif
  call writefile(split(system(cmd), "\n"), tempfile)
  belowright split 
  exec "edit " . tempfile
  call cursor(1, 1)
  setlocal nomodifiable
  set buftype=nofile
  set bufhidden=hide
  setlocal noswapfile
  let b:snipplr_id = a:query  =~# 'http://'
              \ ?  matchlist(a:query,'http://snipplr.com/view/\(\d\+\)/')[1]
              \ : a:query
  nnoremap <buffer> <silent> i :call <SID>SnipplrInfo(b:snipplr_id)<CR>
  nnoremap <buffer> <silent> q :<C-u>bdelete<CR>
endfunction

function! s:SnipplrInfo(snippet_id)
  let tempfile = tempname()
  let cmd = "ruby " . g:snipplr_rb . ' -i ' . a:snippet_id
  call writefile(split(system(cmd), "\n"), tempfile)
  belowright split 
  exec "edit " . tempfile
  nnoremap <buffer> <silent> c :<C-u>bdelete<CR>
  call cursor(1, 1)
  setlocal nomodifiable
  set buftype=nofile
  set bufhidden=hide
  setlocal noswapfile
endfunction

function! s:SnipplrDelete(snippet_id)
  let cmd = "ruby " . g:snipplr_rb . ' -d ' . a:snippet_id
  call system(cmd)
  if v:shell_error != 0
    echo "error"
  else
    echo "deleted [" . a:snippet_id . "]"
  endif   
endfunction

"reset &cpo back to users setting
let &cpo = s:old_cpo

" vim: set sw=4 sts=4 et fdm=marker:
