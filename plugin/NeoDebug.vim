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

if !exists('g:neodbg_enable_help')
    let g:neodbg_enable_help = 1
endif

let g:neodbg_console_name = "__DebugConsole__"
let g:neodbg_console_height = 15
let g:neodbg_prompt = '(gdb) '

let s:neodbg_running = 0
let s:neodbg_exrc = $HOME.'/neodbg_exrc'
let s:neodbg_port = 30777 

let s:ismswin = has('win32')
let s:isunix = has('unix')

let s:completers = []
let s:neodbg_cmd_historys = ["first"]

let s:pc_id = 12
let s:break_id = 13
let s:stopped = 1
let s:breakpoints = {}

" mode: i|n|c|<empty>
" i - input command in console window and press enter
" n - press enter (or double click) in console window
" c - run debugger command
function! NeoDebug(cmd, ...)  " [mode]
    let usercmd = a:cmd
    let mode = a:0>0 ? a:1 : ''

    if s:neodbg_running == 0
        let s:neodbg_port= 30000 + reltime()[1] % 10000
        call s:NeoDebugStart(usercmd)

        " save current setting and restore when neodebug quits via 'so .exrc'
        exec 'mk! ' . s:neodbg_exrc . s:neodbg_port
        "delete line set runtimepath for missing some functions after neodebug quit
        " silent exec '!start /b sed -i "/set runtimepath/d" ' . s:neodbg_exrc . s:neodbg_port
        silent exec '!start /b sed -i "/set /d" ' . s:neodbg_exrc . s:neodbg_port
        let sed_tmp = fnamemodify(s:neodbg_exrc . s:neodbg_port, ":p:h")
        silent exec '!start /b rm -f '. sed_tmp . '/sed*'   

        set nocursorline
        set nocursorcolumn

        call neodebug#OpenConsole()

        let s:neodbg_running = 1

        return
    endif

    if s:neodbg_running == 0
        echomsg "NeoDebug is not running"
        return
    endif

    if -1 == bufwinnr(g:neodbg_console_name)
        call neodebug#ToggleConsoleWindow()
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

function! NeoDebugStop(cmd)
    call job_stop(s:commjob)
endfunction

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
    let s:neodebug_console_win = win_getid(winnr())

    " Interpret commands while the target is running.  This should usualy only be
    " exec-interrupt, since many commands don't work properly while the target is
    " running.
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

    " If neodebug console window is open then close it.
    call neodebug#GotoConsoleWindow()
    quit

    exe 'bwipe! ' . bufnr(g:neodbg_console_name)

    let curwinid = win_getid(winnr())

    call win_gotoid(s:startwin)
    let &signcolumn = s:startsigncolumn
    call NeoDebugDeleteCommandsHotkeys()

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
" Handle a message received from debugger
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
    if  "complete" == strpart(s:comm_msg, 2, strlen("complete"))  && ( s:comm_msg =~  g:neodbg_prompt)
        let s:completer_skip_flag = 0
        let s:comm_msg = ''
        return
    endif

    let debugger_line = a:msg

    if debugger_line != '' && s:completer_skip_flag == 0
        " Handle 
        if debugger_line =~ '^\(\*stopped\|\*running\|=thread-selected\)'
            call s:HandleCursor(debugger_line)
        elseif debugger_line =~ '^\^done,bkpt=' || debugger_line =~ '=breakpoint-created,'
            call s:HandleNewBreakpoint(debugger_line)
        elseif debugger_line =~ '^=breakpoint-deleted,'
            call s:HandleBreakpointDelete(debugger_line)
        elseif debugger_line =~ '^\^done,value='
            call s:HandleEvaluate(debugger_line)
        elseif debugger_line =~ '^\^error,msg='
            call s:HandleError(debugger_line)
        elseif debugger_line == g:neodbg_prompt
            let debugger_line = g:neodbg_prompt
        endif

        " echomsg "debugger_line:".debugger_line
        call neodebug#GotoConsoleWindow()
        if debugger_line =~ '^\~" >"' 
            call append(line("$"), strpart(debugger_line, 2, strlen(debugger_line)-3))
            " elseif debugger_line =~ '^\~"\S\+' 
        elseif debugger_line =~ '^\~"' 
            let s:appendline .= strpart(debugger_line, 2, strlen(debugger_line)-3)
            if debugger_line =~ '\\n"\_$'
                " echomsg "s:appendfile:".s:appendline
                let s:appendline = substitute(s:appendline, '\\n\|\\032\\032', '', 'g')
                let s:appendline = substitute(s:appendline, '\\"', '"', 'g')
                call append(line("$"), s:appendline)
                let s:appendline = ''
            endif
        elseif debugger_line =~ '^\^error,msg='
            if debugger_line =~ '^\^error,msg="The program'
                let s:append_err =  substitute(a:msg, '.*msg="\(.*\)"', '\1', '')
                let s:append_err =  substitute(s:append_err, '\\"', '"', 'g')
                call append(line("$"), s:append_err)
            endif
        elseif debugger_line == g:neodbg_prompt
            if getline("$") != g:neodbg_prompt
                call append(line("$"), debugger_line)
            endif
        endif

        "vim bug  on linux ?
        if s:isunix
            if debugger_line =~ '^\(\*stopped\)'
                call append(line("$"), g:neodbg_prompt)
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

function! NeoDebugFoldTextExpr()
    return getline(v:foldstart) . ' ' . substitute(getline(v:foldstart+1), '\v^\s+', '', '') . ' ... (' . (v:foldend-v:foldstart-1) . ' lines)'
endfunction

" Show a balloon with information of the variable under the mouse pointer,
" if there is any.
let s:neodbg_balloonexpr_flag = 0
func! NeoDebugBalloonExpr()
    if v:beval_winid != s:startwin
        return
    endif
    let s:evalFromBalloonExpr = 1
    let s:evalFromBalloonExprResult = ''
    let s:ignoreEvalError = 1
    let s:neodbg_balloonexpr_flag = 1
    call s:SendEval(v:beval_text)
    let s:neodbg_balloonexpr_flag = 0

    let output = ch_readraw(s:chan)
    let alloutput = ''
    while output != g:neodbg_prompt
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
        let s:neodbg_balloonexpr_flag = 1
        call s:SendEval('*' . s:evalexpr)
        let s:neodbg_balloonexpr_flag = 0

        let output = ch_readraw(s:chan)
        let alloutput = ''
        while output != g:neodbg_prompt
            let alloutput .= output
            let output = ch_readraw(s:chan)
        endw

        let value = substitute(alloutput, '.*value="\(.*\)"', '\1', '')
        let value = substitute(value, '\\"', '"', 'g')
        let value = substitute(value, '\\n\s*', '', 'g')

        let s:evalFromBalloonExprResult .= ' ' . value

    endif

    " for neodebug#GotoConsoleWindow to display also
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
        while output != g:neodbg_prompt
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
function! s:MyMatch(expr, pat)
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
    if ! s:MyMatch(getline('.'), '\v((\$|\w)+) \=.{-0,} 0x')
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
func NeoDebugInstallCommandsHotkeys()

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
    command Program call win_gotoid(s:ptywin)
    command Winbar call NeoDebugInstallWinbar()

    " TODO: can the K mapping be restored?
    nnoremap K :Evaluate<CR>

    if has('menu') && &mouse != ''
        call NeoDebugInstallWinbar()

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

    call neodebug#CustomConsoleKey()

    noremap <buffer><silent>? :call neodebug#ToggleHelp()<cr>

    inoremap <expr><buffer> <silent> <c-p>  "\<c-x><c-l>"
    inoremap <expr><buffer> <silent> <c-r>  "\<c-x><c-n>"

    inoremap <expr><buffer><silent> <TAB>    pumvisible() ? "\<C-n>" : "\<c-x><c-u>"
    inoremap <expr><buffer><silent> <S-TAB>  pumvisible() ? "\<C-p>" : "\<c-x><c-u>"
    noremap <buffer><silent> <Tab> ""
    noremap <buffer><silent> <S-Tab> ""

    noremap <buffer><silent> <ESC> :call neodebug#CloseConsoleWindow()<CR>

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
    nmap <silent> <c-c> :NeoDebugStop<cr>

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
func NeoDebugInstallWinbar()
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
func NeoDebugDeleteCommandsHotkeys()
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
        exec 'so '. s:neodbg_exrc . s:neodbg_port
        call delete(s:neodbg_exrc . s:neodbg_port)
    else
        " so .exrc
        exec 'so '. s:neodbg_exrc . s:neodbg_port
        call delete(s:neodbg_exrc . s:neodbg_port)
    endif
    stopi
endfunc

" :Next, :Continue, etc - send a command to debugger
func s:SendCommand(cmd)
    " echomsg "<GDB>cmd:[".a:cmd."]"
    let usercmd = a:cmd
    if usercmd != s:neodbg_cmd_historys[-1]
        call add(s:neodbg_cmd_historys, usercmd)
    else
        if s:neodbg_balloonexpr_flag == 0
            call neodebug#GotoConsoleWindow()
            call setline(line('.'), getline('.').s:neodbg_cmd_historys[-1])
        endif
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

" Handle stopping and running message from debugger.
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

command! -nargs=* -complete=file NeoDebug :call NeoDebug(<q-args>)
command! -nargs=* -complete=file NeoDebugStop :call NeoDebugStop(<q-args>)

" vim: set foldmethod=marker 
