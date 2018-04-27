"""""""""""""""""""""""""""""""""""""""""""""""""""""""
" NeoDebug - Vim plugin for interface to gdb from Vim 
" Maintainer: scott (cpiger@qq.com)
"
"""""""""""""""""""""""""""""""""""""""""""""""""""""""
" In case this gets loaded twice.
if exists(':NeoDebug')
    finish
endif
" Name of the NeoDebug command, defaults to "gdb".
if !exists('g:neodbg_debugger')
    let g:neodbg_debugger = 'gdb'
endif

if !exists('g:neodbg_ballonshow_with_print')
    let g:neodbg_ballonshow_with_print = 0
endif

if !exists('g:neodbg_debuginfo')
    let g:neodbg_debuginfo = 1
endif

let s:ismswin=has('win32')
let s:isunix = has('unix')

let s:neodbg_winheight = 15
let s:neodbg_bufname = "__DebugConsole__"
let s:neodbg_prompt = '(gdb) '
let g:neodbg_exrc = $HOME.'/neodbg_exrc'
let s:gdbd_port = 30777 
let s:neodbg_running = 0

let s:completers = []
let s:neodbg_cmd_historys = ["first"]

let s:pc_id = 12
let s:break_id = 13
let s:stopped = 1
let s:breakpoints = {}

let s:help_open = 1
let s:help_text_short = [
			\ '" Press ? for help',
			\ ]

let s:help_text = s:help_text_short

function s:toggle_help()
    if !g:neodbg_enable_help
        return
    endif

    let s:help_open = !s:help_open
    silent exec '1,' . len(s:help_text) . 'd _'
    call s:update_help_text()
    silent call append ( 0, s:help_text )
    silent keepjumps normal! gg
endfunction

function s:update_help_text()
    if s:help_open
        let s:help_text = [
            \ '<F5> 	- run or continue (c)',
            \ '<S-F5> 	- stop debugging (kill)',
            \ '<F10> 	- next',
            \ '<F11> 	- step into',
            \ '<S-F11> - step out (finish)',
            \ '<C-F10>	- run to cursor (tb and c)',
            \ '<F9> 	- toggle breakpoint on current line',
            \ '<C-F9> 	- toggle enable/disable breakpoint on current line',
            \ '\ju or <C-S-F10> - set next statement (tb and jump)',
            \ '<C-P>   - view variable under the cursor (.p)',
            \ '<TAB>   - trigger complete ',
            \ ]
    else
        let s:help_text = s:help_text_short
    endif
endfunction
if !exists('g:neodbg_enable_help')
    let g:neodbg_enable_help = 1
endif

" mode: i|n|c|<empty>
" i - input command in console window and press enter
" n - press enter (or double click) in console window
" c - run Gdb command
function! NeoDebug(cmd, ...)  " [mode]
    let usercmd = a:cmd
    let mode = a:0>0 ? a:1 : ''

    if s:neodbg_running == 0
        let s:gdbd_port= 30000 + reltime()[1] % 10000
        call s:NeoDebugStart(usercmd)
        call OpenConsole()
        return
    endif

    if s:neodbg_running == 0
        echomsg "neodbg is not running"
        return
    endif

    if -1 == bufwinnr(s:neodbg_bufname)
        call s:ToggleConsoleWindow()
        return
    endif

    " echomsg "usercmd[".usercmd."]"
    if g:neodbg_debugger == 'gdb' && usercmd =~ '^\s*(gdb)' 
        let usercmd = substitute(usercmd, '^\s*(gdb)\s*', '', '')
        if usercmd == ''
            let usercmd = s:neodbg_cmd_historys[-1]
        endif
    elseif g:neodbg_debugger == 'gdb' && usercmd =~ '^\s*>\s*' 
        let usercmd = substitute(usercmd, '^\s*>\s*', '', '')
        echomsg "usercmd2[".usercmd."]"
    endif

    call s:SendCommand(usercmd)
endf

func s:NeoDebugStart(cmd)
    let s:startwin = win_getid(winnr())
    let s:startsigncolumn = &signcolumn

    let s:save_columns = 0
    if exists('g:neodbg_wide')
        if &columns < g:neodbg_wide
            let s:save_columns = &columns
            let &columns = g:neodbg_wide
        endif
        let vertical = 1
    else
        let vertical = 0
    endif

    let cmd = [g:neodbg_debugger, '-quiet','-q', '-f', '--interpreter=mi2', a:cmd]
    " Create a hidden terminal window to communicate with gdb
    if 1
        let s:commjob = job_start(cmd, {
                    \ 'out_cb' : function('s:HandleOutput'),
                    \ 'exit_cb': function('s:NeoDebugEnd'),
                    \ })

        let s:chan = job_getchannel(s:commjob)  
        let commpty = job_info((s:commjob))['tty_out']
    endif
    let s:gdbwin = win_getid(winnr())

    " Interpret commands while the target is running.  This should usualy only be
    " exec-interrupt, since many commands don't work properly while the target is
    " running.
    " call s:SendCommand('-gdb-set mi-async on')
    call s:SendCommand('set mi-async on')
    if s:ismswin
        call s:SendCommand('set new-console on')
    endif
    call s:SendCommand('set print pretty on')
    call s:SendCommand('set breakpoint pending on')
    call s:SendCommand('set pagination off')

    " Install debugger commands in the text window.
    call win_gotoid(s:startwin)

    " Enable showing a balloon with eval info
    if has("balloon_eval") || has("balloon_eval_term")
        set bexpr=NeoDebugBalloonExpr()
        if has("balloon_eval")
            set ballooneval
            set balloondelay=500
        endif
        if has("balloon_eval_term")
            set balloonevalterm
        endif
    endif

    augroup NeoDebugAutoCMD
        au BufRead * call s:BufferRead()
        au BufUnload * call s:BufferUnload()
    augroup END
endfunc

func s:NeoDebugEnd(job, status)

	if !s:neodbg_running
		return
	endif

	let s:neodbg_running = 0
    sign unplace *

    " If gdb window is open then close it.
    call s:GotoConsoleWindow()
    quit

    exe 'bwipe! ' . bufnr(s:neodbg_bufname)

    let curwinid = win_getid(winnr())

    call win_gotoid(s:startwin)
    let &signcolumn = s:startsigncolumn
    call s:DeleteCommandsHotkeys()

    call win_gotoid(curwinid)
    if s:save_columns > 0
        let &columns = s:save_columns
    endif

    if has("balloon_eval") || has("balloon_eval_term")
        set bexpr=
        if has("balloon_eval")
            set noballooneval
        endif
        if has("balloon_eval_term")
            set noballoonevalterm
        endif
    endif

    au! NeoDebugAutoCMD
endfunc

let s:completer_skip_flag = 0
let s:appendline = ''
let s:comm_msg = ''
" Handle a message received from gdb on the GDB/MI interface.
func s:HandleOutput(chan, msg)
    if g:neodbg_debuginfo == 1
        echomsg "<GDB>:".a:msg
    endif

    let s:mode = mode()
    let cur_wid = win_getid(winnr())

    " do not output completers
    if  "complete" == strpart(a:msg, 2, strlen("complete"))
        let s:completer_skip_flag = 1
    endif

    if s:completer_skip_flag == 1
        let s:comm_msg .= a:msg
    endif

    " echomsg "s:comm_msg" .s:comm_msg
    if  "complete" == strpart(s:comm_msg, 2, strlen("complete"))  && ( s:comm_msg =~  '(gdb)')
        let s:completer_skip_flag = 0
        let s:comm_msg = ''
        return
    endif

    let gdb_line = a:msg

    if gdb_line != '' && s:completer_skip_flag == 0
        " Handle 
        if gdb_line =~ '^\(\*stopped\|\*running\|=thread-selected\)'
            call s:HandleCursor(gdb_line)
        elseif gdb_line =~ '^\^done,bkpt=' || gdb_line =~ '=breakpoint-created,'
            call s:HandleNewBreakpoint(gdb_line)
        elseif gdb_line =~ '^=breakpoint-deleted,'
            call s:HandleBreakpointDelete(gdb_line)
        elseif gdb_line =~ '^\^done,value='
            call s:HandleEvaluate(gdb_line)
        elseif gdb_line =~ '^\^error,msg='
            call s:HandleError(gdb_line)
        elseif gdb_line == "(gdb) "
            let gdb_line = s:neodbg_prompt
        endif

        " echomsg "gdb_line:".gdb_line
        call s:GotoConsoleWindow()
        if gdb_line =~ '^\~" >"' 
            call append(line("$"), strpart(gdb_line, 2, strlen(gdb_line)-3))
            " elseif gdb_line =~ '^\~"\S\+' 
        elseif gdb_line =~ '^\~"' 
            let s:appendline .= strpart(gdb_line, 2, strlen(gdb_line)-3)
            if gdb_line =~ '\\n"\_$'
                " echomsg "s:appendfile:".s:appendline
                let s:appendline = substitute(s:appendline, '\\n\|\\032\\032', '', 'g')
                let s:appendline = substitute(s:appendline, '\\"', '"', 'g')
                call append(line("$"), s:appendline)
                let s:appendline = ''
            endif
        elseif gdb_line =~ '^\^error,msg='
            if gdb_line =~ '^\^error,msg="The program'
                let s:append_err =  substitute(a:msg, '.*msg="\(.*\)"', '\1', '')
                let s:append_err =  substitute(s:append_err, '\\"', '"', 'g')
                call append(line("$"), s:append_err)
            endif
        elseif gdb_line == s:neodbg_prompt
            if getline("$") != s:neodbg_prompt
                call append(line("$"), gdb_line)
            endif
        endif

        "vim bug  on linux ?
        if s:isunix
            if gdb_line =~ '^\(\*stopped\)'
                call append(line("$"), s:neodbg_prompt)
            endif
        endif

        $
        starti!
        redraw
        if s:mode != "i"
            stopi
        endif

    endif

    call win_gotoid(cur_wid)

endfunc

" NOTE: this function will be called by neodbg script.
function! OpenConsole()
    " save current setting and restore when neodbg quits via 'so .exrc'
    " exec 'mk! '
    exec 'mk! ' . g:neodbg_exrc . s:gdbd_port
    "delete line set runtimepath for missing some functions after neodbg quit
    " silent exec '!start /b sed -i "/set runtimepath/d" ' . g:neodbg_exrc . s:gdbd_port
    silent exec '!start /b sed -i "/set /d" ' . g:neodbg_exrc . s:gdbd_port
    let sed_tmp = fnamemodify(g:neodbg_exrc . s:gdbd_port, ":p:h")
    silent exec '!start /b rm -f '. sed_tmp . '/sed*'   

    set nocursorline
    set nocursorcolumn

    call OpenConsoleWindow()

    " Mark the buffer as a scratch buffer
    setlocal buftype=nofile
    " We need buffer content hold
    " setlocal bufhidden=delete
    "i mode disable mouse
    " setlocal mouse=nvch
    setlocal complete=.
    setlocal noswapfile
    setlocal nowrap
    setlocal nobuflisted
    setlocal nonumber
    setlocal winfixheight
    setlocal cursorline

    setlocal foldcolumn=2
    setlocal foldtext=NeoDebugFoldTextExpr()
    setlocal foldmarker={,}
    setlocal foldmethod=marker

    call s:InstallCommandsHotkeys()

    let s:neodbg_running = 1

    call NeoDebug("") " get init msg
    starti!
    " call cursor(0, 7)

    setl completefunc=NeoDebugComplete
endfunction

" Get ready for communication
function! OpenConsoleWindow()
    let bufnum = bufnr(s:neodbg_bufname)

    if bufnum == -1
        " Create a new buffer
        let wcmd = s:neodbg_bufname
    else
        " Edit the existing buffer
        let wcmd = '+buffer' . bufnum
    endif

    " Create the tag explorer window
    exe 'silent!  botright ' . s:neodbg_winheight . 'split ' . wcmd
    if line('$') <= 1 && g:neodbg_enable_help
        silent call append ( 0, s:help_text )
    endif
    call s:InstallWinbar()
endfunction

function CloseConsoleWindow()
    let winnr = bufwinnr(s:neodbg_bufname)
    if winnr != -1
        call s:GotoConsoleWindow()
        let s:neodbg_save_cursor = getpos(".")
        close
        return 1
    endif
    return 0
endfunction

function s:ToggleConsoleWindow()
    if  s:neodbg_running == 0
        return
    endif
    let result = CloseConsoleWindow()
    if result == 0
        call s:GotoConsoleWindow()
        call setpos('.', s:neodbg_save_cursor)
    endif
endfunction

function! s:GotoConsoleWindow()
    if bufname("%") == s:neodbg_bufname
        return
    endif
    let neodbg_winnr = bufwinnr(s:neodbg_bufname)
    if neodbg_winnr == -1
        " if multi-tab or the buffer is hidden
        call OpenConsoleWindow()
        let neodbg_winnr = bufwinnr(s:neodbg_bufname)
    endif
    exec neodbg_winnr . "wincmd w"
endf

function! NeoDebugFoldTextExpr()
    return getline(v:foldstart) . ' ' . substitute(getline(v:foldstart+1), '\v^\s+', '', '') . ' ... (' . (v:foldend-v:foldstart-1) . ' lines)'
endfunction

" Show a balloon with information of the variable under the mouse pointer,
" if there is any.
func! NeoDebugBalloonExpr()
    if v:beval_winid != s:startwin
        return
    endif
    let s:evalFromBalloonExpr = 1
    let s:evalFromBalloonExprResult = ''
    let s:ignoreEvalError = 1
    call s:SendEval(v:beval_text)

    let output = ch_readraw(s:chan)
    let alloutput = ''
    while output != "(gdb) "
        let alloutput .= output
        let output = ch_readraw(s:chan)
    endw

    let value = substitute(alloutput, '.*value="\(.*\)"', '\1', '')
    let value = substitute(value, '\\"', '"', 'g')
    let value = substitute(value, '\\n\s*', '', 'g')

    if s:evalFromBalloonExprResult == ''
        let s:evalFromBalloonExprResult = s:evalexpr . ': ' . value
    else
        let s:evalFromBalloonExprResult .= ' = ' . value
    endif

    if s:evalexpr[0] != '*' && value =~ '^0x' && value != '0x0' && value !~ '"$'
        " Looks like a pointer, also display what it points to.
        let s:ignoreEvalError = 1
        call s:SendEval('*' . s:evalexpr)

        let output = ch_readraw(s:chan)
        let alloutput = ''
        while output != "(gdb) "
            let alloutput .= output
            let output = ch_readraw(s:chan)
        endw

        let value = substitute(alloutput, '.*value="\(.*\)"', '\1', '')
        let value = substitute(value, '\\"', '"', 'g')
        let value = substitute(value, '\\n\s*', '', 'g')

        let s:evalFromBalloonExprResult .= ' ' . value

    endif

    " for GotoConsoleWindow to display also
    if g:neodbg_ballonshow_with_print == 1
        call s:SendCommand('p '. v:beval_text)
        call s:SendCommand('p '. s:evalexpr)
    endif

    return s:evalFromBalloonExprResult

endfunc

fun! NeoDebugComplete(findstart, base)

    if a:findstart

        let usercmd = getline('.')
        if g:neodbg_debugger == 'gdb' && usercmd =~ '^\s*(gdb)' 
            let usercmd = substitute(usercmd, '^\s*(gdb)\s*', '', '')
            let usercmd = substitute(usercmd, '*', '', '') "fixed *pointer
            let usercmd = 'complete ' .  usercmd
        endif

        call s:SendCommand(usercmd)

        let output = ch_readraw(s:chan)
        let s:completers = []
        while output != "(gdb) "
            if output =~ '\~"' 
                let completer = strpart(output, 2, strlen(output)-5) 
                " echomsg completer
                call add(s:completers, completer)
            endif
            let output = ch_readraw(s:chan)
        endw

        " locate the start of the word
        let line = getline('.')
        let start = col('.') - 1
        while start > 0 && line[start - 1] =~ '\S' && line[start-1] != '*' "fixed *pointer
            let start -= 1
        endwhile
        return start
    else
        " find s:completers matching the "a:base"
        let res = []
        for m in (s:completers)
            if a:base == '' 
                return res
            endif

            if m =~ '^' . a:base
                call add(res, m)
            endif

            if m =~ '^\a\+\s\+' . a:base
                call add(res, substitute(m, '^\a*\s*', '', ''))
            endif
        endfor
        return res
    endif
endfun

let s:match = []
function! s:mymatch(expr, pat)
    let s:match = matchlist(a:expr, a:pat)
    return len(s:match) >0
endf
" if the value is a pointer ( var = 0x...), expand it by "NeoDebug p *var"
" e.g. $11 = (CDBMEnv *) 0x387f6d0
" e.g.  
" (CDBMEnv) $22 = {
"  m_pTempTables = 0x37c6830,
"  ...
" }
function! NeoDebugExpandPointerExpr()
    if ! s:mymatch(getline('.'), '\v((\$|\w)+) \=.{-0,} 0x')
        return 0
    endif
    let cmd = s:match[1]
    let lastln = line('.')
    while 1
        normal [z
        if line('.') == lastln
            break
        endif
        let lastln = line('.')

        if ! s:mymatch(getline('.'), '\v(([<>$]|\w)+) \=')
            return 0
        endif
        " '<...>' means the base class. Just ignore it. Example:
        " (OBserverDBMCInterface) $4 = {
        "   <__DBMC_ObserverA> = {
        "     members of __DBMC_ObserverA:
        "     m_pEnv = 0x378de60
        "   }, <No data fields>}

        if s:match[1][0:0] != '<' 
            let cmd = s:match[1] . '.' . cmd
        endif
    endwhile 
    "	call append('$', cmd)
    exec "NeoDebug p *" . cmd
    if foldlevel('.') > 0
        " goto beginning of the fold and close it
        normal [zzc
        " ensure all folds for this var are closed
        foldclose!
    endif
    return 1
endf

" Install commands in the current window to control the debugger.
func s:InstallCommandsHotkeys()
    command Break call s:SetBreakpoint()
    command Clear call s:ClearBreakpoint()
    command Step call s:SendCommand('-exec-step')
    command Over call s:SendCommand('-exec-next')
    command Finish call s:SendCommand('-exec-finish')
    command -nargs=* Run call s:Run(<q-args>)
    command -nargs=* Arguments call s:SendCommand('-exec-arguments ' . <q-args>)
    command Stop call s:SendCommand('-exec-interrupt')
    command Continue call s:SendCommand('-exec-continue')
    command -range -nargs=* Evaluate call s:Evaluate(<range>, <q-args>)
    command Gdb call win_gotoid(s:gdbwin)
    command Program call win_gotoid(s:ptywin)
    command Winbar call s:InstallWinbar()

    " TODO: can the K mapping be restored?
    nnoremap K :Evaluate<CR>

    if has('menu') && &mouse != ''
        call s:InstallWinbar()

        if !exists('g:neodbg_popup') || g:neodbg_popup != 0
            let s:saved_mousemodel = &mousemodel
            let &mousemodel = 'popup_setpos'
            an 1.200 PopUp.-SEP3-	<Nop>
            an 1.210 PopUp.Set\ breakpoint	:Break<CR>
            an 1.220 PopUp.Clear\ breakpoint	:Clear<CR>
            an 1.230 PopUp.Evaluate		:Evaluate<CR>
        endif
    endif


    hi NeoDbgBreakPoint    guibg=darkblue  ctermbg=darkblue term=reverse 
    hi NeoDbgDisabledBreak guibg=lightblue guifg=black ctermbg=lightblue ctermfg=black
    hi NeoDbgPC            guibg=Orange    guifg=black gui=bold ctermbg=Yellow ctermfg=black

    " hi NeoDbgBreakPoint guibg=darkred guifg=white ctermbg=darkred ctermfg=white
    " hi NeoDbgDisabledBreak guibg=lightred guifg=black ctermbg=lightred ctermfg=black

    sign define NeoDebugBP  linehl=NeoDbgBreakPoint    text=B> texthl=NeoDbgBreakPoint
    sign define NeoDebugDBP linehl=NeoDbgDisabledBreak text=b> texthl=NeoDbgDisabledBreak
    sign define NeoDebugPC  linehl=NeoDbgPC            text=>> texthl=NeoDbgPC

    " highlight NeoDebugGoto guifg=Blue
    hi def link NeoDebugKey Statement
    hi def link NeoDebugHiLn Statement
    hi def link NeoDebugGoto Underlined
    hi def link NeoDebugPtr Underlined
    hi def link NeoDebugFrame LineNr
    hi def link NeoDebugCmd Macro
    " syntax
    syn keyword NeoDebugKey Function Breakpoint Catchpoint 
    syn match NeoDebugFrame /\v^#\d+ .*/ contains=NeoDebugGoto
    syn match NeoDebugGoto /\v<at [^()]+:\d+|file .+, line \d+/
    syn match NeoDebugCmd /^(gdb).*/
    syn match NeoDebugPtr /\v(^|\s+)\zs\$?\w+ \=.{-0,} 0x\w+/
    " highlight the whole line for 
    " returns for info threads | info break | finish | watchpoint
    syn match NeoDebugHiLn /\v^\s*(Id\s+Target Id|Num\s+Type|Value returned is|(Old|New) value =|Hardware watchpoint).*$/

    " syntax for perldb
    syn match NeoDebugCmd /^\s*DB<.*/
    "	syn match NeoDebugFrame /\v^#\d+ .*/ contains=NeoDebugGoto
    syn match NeoDebugGoto /\v from file ['`].+' line \d+/
    syn match NeoDebugGoto /\v at ([^ ]+) line (\d+)/
    syn match NeoDebugGoto /\v at \(eval \d+\)..[^:]+:\d+/


    " shortcut in NeoDebug window
    inoremap <expr><buffer><BS>  <SID>IsModifiableX() ? "\<BS>"  : ""
    inoremap <expr><buffer><c-h> <SID>IsModifiableX() ? "\<c-h>" : ""
    noremap <buffer> <silent> i :call <SID>NeoDebugKeyi()<cr>
    noremap <buffer> <silent> I :call <SID>NeoDebugKeyI()<cr>
    noremap <buffer> <silent> a :call <SID>NeoDebugKeya()<cr>
    noremap <buffer> <silent> A :call <SID>NeoDebugKeyA()<cr>
    noremap <buffer> <silent> o :call <SID>NeoDebugKeyo()<cr>
    noremap <buffer> <silent> O :call <SID>NeoDebugKeyo()<cr>
    noremap <expr><buffer>x  <SID>IsModifiablex() ? "x" : ""  
    noremap <expr><buffer>X  <SID>IsModifiableX() ? "X" : ""  
    vnoremap <buffer>x ""

    noremap <expr><buffer>d  <SID>IsModifiablex() ? "d" : ""  
    noremap <expr><buffer>u  <SID>IsModifiablex() ? "u" : ""  
    noremap <expr><buffer>U  <SID>IsModifiablex() ? "U" : ""  

    noremap <expr><buffer>s  <SID>IsModifiablex() ? "s" : ""  
    noremap <buffer> <silent> S :call <SID>NeoDebugKeyS()<cr>

    noremap <expr><buffer>c  <SID>IsModifiablex() ? "c" : ""  
    noremap <expr><buffer>C  <SID>IsModifiablex() ? "C" : ""  

    noremap <expr><buffer>p  <SID>IsModifiable() ? "p" : ""  
    noremap <expr><buffer>P  <SID>IsModifiablex() ? "P" : ""  


    inoremap <expr><buffer><Del>        <SID>IsModifiablex() ? "<Del>"    : ""  
    noremap <expr><buffer><Del>         <SID>IsModifiablex() ? "<Del>"    : ""  
    noremap <expr><buffer><Insert>      <SID>IsModifiableX() ? "<Insert>" : ""  

    inoremap <expr><buffer><Left>       <SID>IsModifiableX() ? "<Left>"   : ""  
    noremap <expr><buffer><Left>        <SID>IsModifiableX() ? "<Left>"   : ""  
    inoremap <expr><buffer><Right>      <SID>IsModifiablex() ? "<Right>"  : ""  
    noremap <expr><buffer><Right>       <SID>IsModifiablex() ? "<Right>"  : ""  

    inoremap <expr><buffer><Home>       "" 
    inoremap <expr><buffer><End>        ""
    inoremap <expr><buffer><Up>         ""
    inoremap <expr><buffer><Down>       ""
    inoremap <expr><buffer><S-Up>       ""
    inoremap <expr><buffer><S-Down>     ""
    inoremap <expr><buffer><S-Left>     ""
    inoremap <expr><buffer><S-Right>    ""
    inoremap <expr><buffer><C-Left>     ""
    inoremap <expr><buffer><C-Right>    ""
    inoremap <expr><buffer><PageUp>     ""
    inoremap <expr><buffer><PageDown>   ""


    noremap <buffer><silent>? :call <SID>toggle_help()<cr>
    " inoremap <buffer> <silent> <c-i> <c-o>:call <SID>GotoInput()<cr>
    " noremap <buffer> <silent> <c-i> :call <SID>GotoInput()<cr>

    inoremap <expr><buffer> <silent> <c-p>  "\<c-x><c-l>"
    inoremap <expr><buffer> <silent> <c-r>  "\<c-x><c-n>"

    inoremap <expr><buffer><silent> <TAB>    pumvisible() ? "\<C-n>" : "\<c-x><c-u>"
    inoremap <expr><buffer><silent> <S-TAB>  pumvisible() ? "\<C-p>" : "\<c-x><c-u>"
    noremap <buffer><silent> <Tab> ""
    noremap <buffer><silent> <S-Tab> ""

    noremap <buffer><silent> <ESC> :call CloseConsoleWindow()<CR>

    inoremap <expr><buffer> <silent> <CR> pumvisible() ? "\<c-y><c-o>:call NeoDebug(getline('.'), 'i')<cr>" : "<c-o>:call NeoDebug(getline('.'), 'i')<cr>"
    imap <buffer> <silent> <2-LeftMouse> <cr>
    imap <buffer> <silent> <kEnter> <cr>

    nnoremap <buffer> <silent> <CR> :call NeoDebug(getline('.'), 'n')<cr>
    nmap <buffer> <silent> <2-LeftMouse> <cr>
    imap <buffer> <silent> <LeftMouse> <Nop>
    nmap <buffer> <silent> <kEnter> <cr>

    " inoremap <buffer> <silent> <TAB> <C-X><C-L>
    "nnoremap <buffer> <silent> : <C-W>p:

    nmap <silent> <F9>	         :call <SID>ToggleBreakpoint()<CR>
    map! <silent> <F9>	         <c-o>:call <SID>ToggleBreakpoint()<CR>

    nmap <silent> <Leader>ju	 :call <SID>Jump()<CR>
    nmap <silent> <C-S-F10>		 :call <SID>Jump()<CR>
    nmap <silent> <C-F10>        :call <SID>RunToCursur()<CR>
    map! <silent> <C-S-F10>		 <c-o>:call <SID>Jump()<CR>
    map! <silent> <C-F10>        <c-o>:call <SID>RunToCursur()<CR>
    nmap <silent> <F6>           :call NeoDebug("run")<CR>
    nmap <silent> <C-P>	         :NeoDebug p <C-R><C-W><CR>
    vmap <silent> <C-P>	         y:NeoDebug p <C-R>0<CR>
    nmap <silent> <Leader>pr	 :NeoDebug p <C-R><C-W><CR>
    vmap <silent> <Leader>pr	 y:NeoDebug p <C-R>0<CR>
    nmap <silent> <Leader>bt	 :NeoDebug bt<CR>

    nmap <silent> <F5>    :NeoDebug c<cr>
    nmap <silent> <S-F5>  :NeoDebug k<cr>
    nmap <silent> <F10>   :NeoDebug n<cr>
    nmap <silent> <F11>   :NeoDebug s<cr>
    nmap <silent> <S-F11> :NeoDebug finish<cr>
    nmap <silent> <c-q> :NeoDebug q<cr>
    nmap <c-c> :call <SID>SendKey("\<c-c>")<cr>

    " map! <silent> <F5>    <c-o>:NeoDebug c<cr>i
    " map! <silent> <S-F5>  <c-o>:NeoDebug k<cr>i
    map! <silent> <F5>    <c-o>:NeoDebug c<cr>
    map! <silent> <S-F5>  <c-o>:NeoDebug k<cr>
    map! <silent> <F10>   <c-o>:NeoDebug n<cr>
    map! <silent> <F11>   <c-o>:NeoDebug s<cr>
    map! <silent> <S-F11> <c-o>:NeoDebug finish<cr>
    map! <silent> <c-q>   <c-o>:NeoDebug q<cr>

    amenu NeoDebug.Run/Continue<tab>F5 					:NeoDebug c<CR>
    amenu NeoDebug.Step\ into<tab>F11					:NeoDebug s<CR>
    amenu NeoDebug.Next<tab>F10							:NeoDebug n<CR>
    amenu NeoDebug.Step\ out<tab>Shift-F11				:NeoDebug finish<CR>
    amenu NeoDebug.Run\ to\ cursor<tab>Ctrl-F10			:call <SID>RunToCursur()<CR>
    amenu NeoDebug.Stop\ debugging\ (Kill)<tab>Shift-F5	:NeoDebug k<CR>
    amenu NeoDebug.-sep1- :

    amenu NeoDebug.Show\ callstack<tab>\\bt				:call NeoDebug("where")<CR>
    amenu NeoDebug.Set\ next\ statement\ (Jump)<tab>Ctrl-Shift-F10\ or\ \\ju 	:call <SID>Jump()<CR>
    amenu NeoDebug.Top\ frame 						:call NeoDebug("frame 0")<CR>
    amenu NeoDebug.Callstack\ up 					:call NeoDebug("up")<CR>
    amenu NeoDebug.Callstack\ down 					:call NeoDebug("down")<CR>
    amenu NeoDebug.-sep2- :

    amenu NeoDebug.Preview\ variable<tab>Ctrl-P		:NeoDebug p <C-R><C-W><CR> 
    amenu NeoDebug.Print\ variable<tab>\\pr			:NeoDebug p <C-R><C-W><CR> 
    amenu NeoDebug.Show\ breakpoints 				:NeoDebug info breakpoints<CR>
    amenu NeoDebug.Show\ locals 					:NeoDebug info locals<CR>
    amenu NeoDebug.Show\ args 						:NeoDebug info args<CR>
    amenu NeoDebug.Quit			 					:NeoDebug q<CR>


endfunc

let s:winbar_winids = []

" Install the window toolbar in the current window.
func s:InstallWinbar()
    "nnoremenu WinBar.Step   :Step<CR>
    "nnoremenu WinBar.Next   :Over<CR>
    "nnoremenu WinBar.Finish :Finish<CR>
    "nnoremenu WinBar.Cont   :Continue<CR>
    "nnoremenu WinBar.Stop   :Stop<CR>
    "nnoremenu WinBar.Eval   :Evaluate<CR>

    nnoremenu WinBar.Step   :NeoDebug s<CR>
    nnoremenu WinBar.Next   :NeoDebug n<CR>
    nnoremenu WinBar.Finish :NeoDebug finish<CR>
    nnoremenu WinBar.Cont   :NeoDebug c<CR>
    nnoremenu WinBar.Stop   :NeoDebug k<CR>
    nnoremenu WinBar.Eval   :Evaluate<CR>
    call add(s:winbar_winids, win_getid(winnr()))
endfunc

" Delete installed debugger commands in the current window.
func s:DeleteCommandsHotkeys()
    delcommand Break
    delcommand Clear
    delcommand Step
    delcommand Over
    delcommand Finish
    delcommand Run
    delcommand Arguments
    delcommand Stop
    delcommand Continue
    delcommand Evaluate
    delcommand Gdb
    delcommand Program
    delcommand Winbar

    nunmap K

    if has('menu')
        " Remove the WinBar entries from all windows where it was added.
        let curwinid = win_getid(winnr())
        for winid in s:winbar_winids
            if win_gotoid(winid)
                aunmenu WinBar.Step
                aunmenu WinBar.Next
                aunmenu WinBar.Finish
                aunmenu WinBar.Cont
                aunmenu WinBar.Stop
                aunmenu WinBar.Eval
            endif
        endfor
        call win_gotoid(curwinid)
        let s:winbar_winids = []

        if exists('s:saved_mousemodel')
            let &mousemodel = s:saved_mousemodel
            unlet s:saved_mousemodel
            aunmenu PopUp.-SEP3-
            aunmenu PopUp.Set\ breakpoint
            aunmenu PopUp.Clear\ breakpoint
            aunmenu PopUp.Evaluate
        endif
    endif

    exe 'sign unplace ' . s:pc_id
    for key in keys(s:breakpoints)
        exe 'sign unplace ' . (s:break_id + key)
    endfor
    sign undefine NeoDebugPC
    sign undefine NeoDebugBP
    "unlet s:breakpoints

    unmap <F9>
    unmap <C-F9>
    unmap <Leader>ju
    unmap <C-S-F10>
    unmap <C-F10>
    unmap <C-P>
    unmap <Leader>pr
    unmap <Leader>bt

    unmap <F5>
    unmap <S-F5>
    unmap <F10>
    unmap <F11>
    unmap <S-F11>

    if s:ismswin
        " so _exrc
        exec 'so '. g:neodbg_exrc . s:gdbd_port
        call delete(g:neodbg_exrc . s:gdbd_port)
    else
        " so .exrc
        exec 'so '. g:neodbg_exrc . s:gdbd_port
        call delete(g:neodbg_exrc . s:gdbd_port)
    endif
    stopi
endfunc

" :Next, :Continue, etc - send a command to gdb
func s:SendCommand(cmd)
    " echomsg "<GDB>cmd:[".a:cmd."]"
    let usercmd = a:cmd
    if usercmd != s:neodbg_cmd_historys[-1]
        call add(s:neodbg_cmd_historys, usercmd)
    else
        call s:GotoConsoleWindow()
        call setline(line('.'), getline('.').s:neodbg_cmd_historys[-1])
    endif

    if g:neodbg_debuginfo == 1
        silent echohl ModeMsg
        echomsg "<GDB>:[".usercmd."]"
        silent echohl None
    endif
    call ch_sendraw(s:commjob, usercmd . "\n")
endfunc

func s:SendKey(key)
    call ch_sendraw(s:commjob, a:key)
endfunc

func s:SendEval(expr)
    call s:SendCommand('-data-evaluate-expression "' . a:expr . '"')
    let s:evalexpr = a:expr
endfunc

func s:PlaceSign(nr, entry)
    exe 'sign place ' . (s:break_id + a:nr) . ' line=' . a:entry['lnum'] . ' name=NeoDebugBP file=' . a:entry['fname']
    let a:entry['placed'] = 1
endfunc

" Handle a BufRead autocommand event: place any signs.
func s:BufferRead()
    " let fname = expand('<afile>:p')
    let fname = fnamemodify(expand('<afile>:t'), ":p")
    for [nr, entry] in items(s:breakpoints)
        if entry['fname'] == fname
            call s:PlaceSign(nr, entry)
        endif
    endfor
endfunc

" Handle a BufUnload autocommand event: unplace any signs.
func s:BufferUnload()
    " let fname = expand('<afile>:p')
    let fname = fnamemodify(expand('<afile>:t'), ":p")
    for [nr, entry] in items(s:breakpoints)
        if entry['fname'] == fname
            let entry['placed'] = 0
        endif
    endfor
endfunc

func s:SetBreakpoint()
    " Setting a breakpoint may not work while the program is running.
    " Interrupt to make it work.
    let do_continue = 0
    if !s:stopped
        let do_continue = 1
        call s:SendCommand('-exec-interrupt')
        sleep 10m
    endif
    " call s:SendCommand('-break-insert '
    " \ . fnameescape(expand('%:p')) . ':' . line('.'))
    call s:SendCommand('break '
                \ . fnameescape(expand('%:p')) . ':' . line('.'))
    if do_continue
        call s:SendCommand('-exec-continue')
    endif
endfunc

func s:ClearBreakpoint()
    " let fname = fnameescape(expand('%:p'))
    let fname = fnameescape(expand('%:t'))
    " let fname = bufnr(fname)
    let fname = fnamemodify(fnamemodify(fname, ":t"), ":p")
    let lnum = line('.')
    " echomsg "s:ClearBreakpoint:fnamelnum".fname.lnum
    for [key, val] in items(s:breakpoints)
        if val['fname'] == fname && val['lnum'] == lnum
            call ch_sendraw(s:commjob, 'delete ' . key . "\n")
            " call ch_sendraw(s:commjob, '-break-delete ' . key . "\n")
            " call ch_sendraw(s:commjob, '-break-disable ' . key . "\n")
            " Assume this always wors, the reply is simply "^done".
            exe 'sign unplace ' . (s:break_id + key)
            unlet s:breakpoints[key]
            break
        endif
    endfor
endfunc

func s:ToggleBreakpoint()
    call win_gotoid(s:startwin)
    let fname = fnameescape(expand('%:t'))
    let fname = fnamemodify(fnamemodify(fname, ":t"), ":p")
    let lnum = line('.')
    for [key, val] in items(s:breakpoints)
        if val['fname'] == fname && val['lnum'] == lnum
            call ch_sendraw(s:commjob, 'delete ' . key . "\n")
            " Assume this always wors, the reply is simply "^done".
            exe 'sign unplace ' . (s:break_id + key)
            unlet s:breakpoints[key]
            " break
            return
        endif
    endfor
    call s:SetBreakpoint()
endfunc

func s:Run(args)
    if a:args != ''
        call s:SendCommand('-exec-arguments ' . a:args)
    endif
    call s:SendCommand('-exec-run')
endfunc

func s:Evaluate(range, arg)
    if a:arg != ''
        let expr = a:arg
    elseif a:range == 2
        let pos = getcurpos()
        let reg = getreg('v', 1, 1)
        let regt = getregtype('v')
        normal! gv"vy
        let expr = @v
        call setpos('.', pos)
        call setreg('v', reg, regt)
    else
        let expr = expand('<cexpr>')
    endif
    let s:ignoreEvalError = 0
    call s:SendEval(expr)
endfunc

let s:ignoreEvalError = 0
let s:evalFromBalloonExpr = 0

" Handle the result of data-evaluate-expression
func s:HandleEvaluate(msg)
    " echomsg "HandleEvaluate:".a:msg
    let value = substitute(a:msg, '.*value="\(.*\)"', '\1', '')
    let value = substitute(value, '\\"', '"', 'g')

    if s:evalexpr[0] != '*' && value =~ '^0x' && value != '0x0' && value !~ '"$'
        " Looks like a pointer, also display what it points to.
        let s:ignoreEvalError = 1
        call s:SendEval('*' . s:evalexpr)
    else
        let s:evalFromBalloonExpr = 0
    endif
endfunc


" Handle an error.
func s:HandleError(msg)
    " call s:SendEval(v:beval_text)
    if s:ignoreEvalError
        " Result of s:SendEval() failed, ignore.
        let s:ignoreEvalError = 0
        let s:evalFromBalloonExpr = 0
        return
    endif
    " echoerr substitute(a:msg, '.*msg="\(.*\)"', '\1', '')
endfunc

" Handle stopping and running message from gdb.
" Will update the sign that shows the current position.
func s:HandleCursor(msg)
    let wid = win_getid(winnr())

    if a:msg =~ '\*stopped'
        let s:stopped = 1
    elseif a:msg =~ '\*running'
        let s:stopped = 0
    endif

    if win_gotoid(s:startwin)
        let fname = substitute(a:msg, '.*fullname="\([^"]*\)".*', '\1', '')
        let fname = fnamemodify(fnamemodify(fname, ":t"), ":p")

        if a:msg =~ '\(\*stopped\|=thread-selected\)' && filereadable(fname)
            let lnum = substitute(a:msg, '.*line="\([^"]*\)".*', '\1', '')
            if lnum =~ '^[0-9]*$'
                if expand('%:p') != fnamemodify(fname, ':p')
                    if &modified
                        " TODO: find existing window
                        exe 'split ' . fnameescape(fname)
                        let s:startwin = win_getid(winnr())
                    else
                        exe 'edit ' . fnameescape(fname)
                    endif
                endif
                " echomsg "HandleCursor:fnamelnum=".fname.lnum
                exe lnum
                exe 'sign unplace ' . s:pc_id
                exe 'sign place ' . s:pc_id . ' line=' . lnum . ' name=NeoDebugPC file=' . fname
                setlocal signcolumn=yes
            endif
        else
            exe 'sign unplace ' . s:pc_id
        endif

        call win_gotoid(wid)
    endif
endfunc

" Handle setting a breakpoint
" Will update the sign that shows the breakpoint
func s:HandleNewBreakpoint(msg)
    if -1 == stridx(a:msg, 'fullname')
        return
    endif
    let nr = substitute(a:msg, '.*number="\([0-9]\)*\".*', '\1', '') + 0
    if nr == 0
        return
    endif

    if has_key(s:breakpoints, nr)
        let entry = s:breakpoints[nr]
    else
        let entry = {}
        let s:breakpoints[nr] = entry
    endif

    let fname = substitute(a:msg, '.*fullname="\([^"]*\)".*', '\1', '')
    let lnum = substitute(a:msg, '.*line="\([^"]*\)".*', '\1', '')

    " echomsg "fname:".fname
    " echomsg "lnum:".lnum

    let fname = fnamemodify(fnamemodify(fname, ":t"), ":p")
    " echomsg "fname:lnum=".fname.':'.lnum

    let entry['fname'] = fname
    let entry['lnum'] = lnum

    call win_gotoid(s:startwin)
    " exe 'e +'.lnum ' '.fname
    try
        exe 'e '.fname
        exe lnum
    catch /^Vim\%((\a\+)\)\=:E37/
        " TODO ask 
        silent echohl ModeMsg
        echomsg "No write since last change (add ! to override)"
        silent echohl None
    catch /^Vim\%((\a\+)\)\=:E325/
        " TODO ask 
        silent echohl ModeMsg
        echomsg "Found a swap file"
        silent echohl None
    endtry

    if bufloaded(fname)
        call s:PlaceSign(nr, entry)
    endif
    redraw
endfunc

" Handle deleting a breakpoint
" Will remove the sign that shows the breakpoint
func s:HandleBreakpointDelete(msg)
    let nr = substitute(a:msg, '.*id="\([0-9]*\)\".*', '\1', '') + 0
    if nr == 0
        return
    endif
    if has_key(s:breakpoints, nr)
        let entry = s:breakpoints[nr]
        if has_key(entry, 'placed')
            exe 'sign unplace ' . (s:break_id + nr)
            unlet entry['placed']
        endif
        unlet s:breakpoints[nr]
    endif
endfunc

" TODO 
function! s:NeoDebug_bpkey(file, line)
    return a:file . ":" . a:line
endf

function! s:CursorPos()
    " ???? filename ????
    let file = expand("%:t")
    let line = line(".")
    return s:NeoDebug_bpkey(file, line)
endf

function! s:Jump()
    call win_gotoid(s:startwin)
    let key = s:CursorPos()
    "	call NeoDebug("@tb ".key." ; ju ".key)
    "	call NeoDebug("set $rbp1=$rbp; set $rsp1=$rsp; @tb ".key." ; ju ".key . "; set $rsp=$rsp1; set $rbp=$rbp1")
    call NeoDebug("ju ".key)
endf

function! s:RunToCursur()
    call win_gotoid(s:startwin)
    let key = s:CursorPos()
    call NeoDebug("tb ".key)
    call NeoDebug("c")
endf

function s:GotoInput()
    " exec "InsertLeave"
    exec "normal G"
    starti!
endfunction

function! s:IsModifiable()
    let pos = getpos(".")  
    let curline = pos[1]
    if  curline == line("$") && strpart(s:neodbg_prompt, 0, 5) == strpart(getline("."), 0, 5) && col(".") >= strlen(s:neodbg_prompt)
        return 1
    else
        return 0
    endif
endf

function! s:IsModifiablex()
    let pos = getpos(".")  
    let curline = pos[1]
    if  curline == line("$") && strpart(s:neodbg_prompt, 0, 5) == strpart(getline("."), 0, 5) && col(".") >= strlen(s:neodbg_prompt)+1
                \ || (curline == line("$") && ' >' == strpart(getline("."), 0, 2) && col(".") >= strlen(' >')+1)
        return 1
    else
        return 0
    endif
endf
function! s:IsModifiableX()
    let pos = getpos(".")  
    let curline = pos[1]
    if  (curline == line("$") && strpart(s:neodbg_prompt, 0, 5) == strpart(getline("."), 0, 5) && col(".") >= strlen(s:neodbg_prompt)+2)
                \ || (curline == line("$") && ' >' == strpart(getline("."), 0, 2) && col(".") >= strlen(' >')+2)
        return 1
    else
        return 0
    endif
endf
fun! s:NeoDebugKeyi()
    let pos = getpos(".")  
    let curline = pos[1]
    let curcol = pos[2]
    if curline == line("$")
        if curcol >  strlen(s:neodbg_prompt)
            starti
        else
            starti!
        endif
    else
        silent call s:GotoInput()
    endif
endf

fun! s:NeoDebugKeyI()
    let pos = getpos(".")  
    let curline = pos[1]
    let curcol = pos[2]
    if curline == line("$")
        let pos[2] = strlen(s:neodbg_prompt)+1
        call setpos(".", pos)
        starti
    else
        silent call s:GotoInput()
    endif
endf

fun! s:NeoDebugKeya()
    let linecon = getline("$")
    let pos = getpos(".")  
    let curline = pos[1]
    let curcol = pos[2]
    if curline == line("$")
        if curcol >=  strlen(s:neodbg_prompt)
            if linecon == s:neodbg_prompt
                starti!
            else
                let pos[2] = pos[2]+1
                call setpos(".", pos)
                if pos[2] == col("$") 
                    starti!
                else
                    starti
                endif
            endif
        else
            starti!
        endif
    else
        silent call s:GotoInput()
    endif
endf

fun! s:NeoDebugKeyA()
    let pos = getpos(".")  
    let curline = pos[1]
    let curcol = pos[2]
    if curline == line("$")
        starti!
    else
        silent call s:GotoInput()
    endif
endf

function s:NeoDebugKeyo()
    let linecon = getline("$")
    if linecon == s:neodbg_prompt
        exec "normal G"
        starti!
    else
        call append('$', s:neodbg_prompt)
        $
        starti!
    endif
endfunction

function NeoDebugKeyS()
    exec "normal G"
    exec "normal dd"
    call append('$', s:neodbg_prompt)
    $
    starti!
endfunction

command! -nargs=* -complete=file NeoDebug :call NeoDebug(<q-args>)

" vim: set foldmethod=marker 
