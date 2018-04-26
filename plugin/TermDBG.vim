"""""""""""""""""""""""""""""""""""""""""""""""""""""""
" TermDBG - Vim plugin for interface to gdb from 
" Maintainer: scott (pigscott@qq.com)
"
"""""""""""""""""""""""""""""""""""""""""""""""""""""""
" In case this gets loaded twice.
if exists(':TermDBG')
    finish
endif

" Name of the gdb command, defaults to "gdb".
if !exists('g:termdbgger')
    let g:termdbgger = 'gdb'
endif
if !exists('g:termdbg_gdbwin_hidden')
    let g:termdbg_gdbwin_hidden = '1'
endif

if !exists('g:termdbg_program_win_row')
    let g:termdbg_program_win_row = 5
endif

let s:pc_id = 12
let s:break_id = 13
let s:stopped = 1

let s:breakpoints = {}
let s:comm_msg = ''
" =======================================================
let s:ismswin=has('win32')
let s:isunix = has('unix')

let s:termdbg_winheight = 15
let s:termdbg_bufname = "__TermDBG__"
let s:termdbg_prompt = '(gdb) '
let s:dbg = 'gdb'
let g:termdbg_exrc = $HOME.'/termdbg_exrc'

let s:gdbd_port = 30777 
let s:termdbg_running = 0
let s:debugging = 0

let s:completers = []
let s:historys = []

let s:set_disabled_bp = 0

let s:help_open = 0
let s:help_text_short = [
			\ '" Press ? for help',
			\ ]

let s:help_text = s:help_text_short

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
if !exists('g:termdbg_enable_help')
    let g:termdbg_enable_help = 1
endif


" =======================================================
func s:StartDebug(cmd)
    let s:startwin = win_getid(winnr())
    let s:startsigncolumn = &signcolumn

    let s:save_columns = 0
    if exists('g:termdbg_wide')
        if &columns < g:termdbg_wide
            let s:save_columns = &columns
            let &columns = g:termdbg_wide
        endif
        let vertical = 1
    else
        let vertical = 0
    endif

    let cmd = [g:termdbgger, '-quiet','-q', '-f', '--interpreter=mi2', a:cmd]
    " Create a hidden terminal window to communicate with gdb
    if 1
        let s:commjob = job_start(cmd, {
                    \ 'out_cb' : function('s:CommOutput'),
                    \ 'exit_cb': function('s:EndDebug'),
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
        " call s:SendCommand('set new-console on')
    endif
    call s:SendCommand('set print pretty on')
    call s:SendCommand('set breakpoint pending on')
    call s:SendCommand('set pagination off')

    " Install debugger commands in the text window.
    call win_gotoid(s:startwin)

    " Enable showing a balloon with eval info
    if has("balloon_eval") || has("balloon_eval_term")
        set bexpr=TermDBG_BalloonExpr()
        if has("balloon_eval")
            set ballooneval
            set balloondelay=500
        endif
        if has("balloon_eval_term")
            set balloonevalterm
        endif
    endif

    augroup TermDBGAutoCMD
        au BufRead * call s:BufRead()
        au BufUnload * call s:BufUnloaded()
    augroup END
endfunc

func s:EndDebug(job, status)

	if !s:termdbg_running
		return
	endif

	let s:termdbg_running = 0
    sign unplace *

    " If gdb window is open then close it.
    call s:goto_console_win()
    quit

    exe 'bwipe! ' . bufnr(s:termdbg_bufname)

    let curwinid = win_getid(winnr())

    call win_gotoid(s:startwin)
    let &signcolumn = s:startsigncolumn
    call s:DeleteCommands_Hotkeys()

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

    au! TermDBGAutoCMD
endfunc

let s:completer_skip_flag = 0
let s:appendline = ''
" Handle a message received from gdb on the GDB/MI interface.
func s:CommOutput(chan, msg)
    " echomsg "a:msg:".a:msg
    if 1

        let s:curwin = winnr()
        if s:curwin == bufwinnr(s:termdbg_bufname)
            let s:stayInTgtWin = 0
        else
            let s:stayInTgtWin = 1
        endif
        " echomsg "s:stayInTgtWin:".s:stayInTgtWin

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
                let gdb_line = s:termdbg_prompt
            endif

            " echomsg "gdb_line:".gdb_line
            call s:goto_console_win()
            if gdb_line =~ '^\~" >"' 
                call append(line("$"), strpart(gdb_line, 2, strlen(gdb_line)-3))
            " elseif gdb_line =~ '^\~"\S\+' 
            elseif gdb_line =~ '^\~"' 
                let s:appendline .= strpart(gdb_line, 2, strlen(gdb_line)-3)
                if gdb_line =~ '\\n"\_$'
                    " echomsg "s:append_file:".s:appendline
                    call append(line("$"), substitute(s:appendline, '\\n\|\\032\\032', '', 'g'))
                    let s:appendline = ''
                endif
            endif
                
            if gdb_line == s:termdbg_prompt
                call append(line("$"), gdb_line)
            endif

            if s:isunix
                if gdb_line =~ '^\(\*stopped\)'
                    call append(line("$"), s:termdbg_prompt)
                endif
            endif

            $
            starti!
            redraw
            if s:mode != "i"
                stopi
            endif

        endif

        if s:stayInTgtWin
            call win_gotoid(s:startwin)
        endif

    endif

endfunc

" Install commands in the current window to control the debugger.
func s:InstallCommands_Hotkeys()
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

        if !exists('g:termdbg_popup') || g:termdbg_popup != 0
            let s:saved_mousemodel = &mousemodel
            let &mousemodel = 'popup_setpos'
            an 1.200 PopUp.-SEP3-	<Nop>
            an 1.210 PopUp.Set\ breakpoint	:Break<CR>
            an 1.220 PopUp.Clear\ breakpoint	:Clear<CR>
            an 1.230 PopUp.Evaluate		:Evaluate<CR>
        endif
    endif


    hi TermDBGBreakPoint    guibg=darkblue  ctermbg=darkblue term=reverse 
    hi TermDBGDisabledBreak guibg=lightblue guifg=black ctermbg=lightblue ctermfg=black
    hi TermDBGPC            guibg=Orange    guifg=black gui=bold ctermbg=Yellow ctermfg=black

    " hi TermDBGBreakPoint guibg=darkred guifg=white ctermbg=darkred ctermfg=white
    " hi TermDBGDisabledBreak guibg=lightred guifg=black ctermbg=lightred ctermfg=black

    sign define termdbgBP  linehl=TermDBGBreakPoint    text=B> texthl=TermDBGBreakPoint
    sign define termdbgDBP linehl=TermDBGDisabledBreak text=b> texthl=TermDBGDisabledBreak
    sign define termdbgPC  linehl=TermDBGPC            text=>> texthl=TermDBGPC

    " highlight termdbgGoto guifg=Blue
    hi def link termdbgKey Statement
    hi def link termdbgHiLn Statement
    hi def link termdbgGoto Underlined
    hi def link termdbgPtr Underlined
    hi def link termdbgFrame LineNr
    hi def link termdbgCmd Macro
    " syntax
    syn keyword termdbgKey Function Breakpoint Catchpoint 
    syn match termdbgFrame /\v^#\d+ .*/ contains=termdbgGoto
    syn match termdbgGoto /\v<at [^()]+:\d+|file .+, line \d+/
    syn match termdbgCmd /^(gdb).*/
    syn match termdbgPtr /\v(^|\s+)\zs\$?\w+ \=.{-0,} 0x\w+/
    " highlight the whole line for 
    " returns for info threads | info break | finish | watchpoint
    syn match termdbgHiLn /\v^\s*(Id\s+Target Id|Num\s+Type|Value returned is|(Old|New) value =|Hardware watchpoint).*$/

    " syntax for perldb
    syn match termdbgCmd /^\s*DB<.*/
    "	syn match termdbgFrame /\v^#\d+ .*/ contains=termdbgGoto
    syn match termdbgGoto /\v from file ['`].+' line \d+/
    syn match termdbgGoto /\v at ([^ ]+) line (\d+)/
    syn match termdbgGoto /\v at \(eval \d+\)..[^:]+:\d+/


    " shortcut in termdbg window
    inoremap <expr><buffer><BS>  TermDBG_isModifiableX() ? "\<BS>"  : ""
    inoremap <expr><buffer><c-h> TermDBG_isModifiableX() ? "\<c-h>" : ""
    noremap <buffer> <silent> i :call TermDBG_Keyi()<cr>
    noremap <buffer> <silent> I :call TermDBG_KeyI()<cr>
    noremap <buffer> <silent> a :call TermDBG_Keya()<cr>
    noremap <buffer> <silent> A :call TermDBG_KeyA()<cr>
    noremap <buffer> <silent> o :call TermDBG_Keyo()<cr>
    noremap <buffer> <silent> O :call TermDBG_Keyo()<cr>
    noremap <expr><buffer>x  TermDBG_isModifiablex() ? "x" : ""  
    noremap <expr><buffer>X  TermDBG_isModifiableX() ? "X" : ""  
    vnoremap <buffer>x ""

    noremap <expr><buffer>d  TermDBG_isModifiablex() ? "d" : ""  
    noremap <expr><buffer>u  TermDBG_isModifiablex() ? "u" : ""  
    noremap <expr><buffer>U  TermDBG_isModifiablex() ? "U" : ""  

    noremap <expr><buffer>s  TermDBG_isModifiablex() ? "s" : ""  
    noremap <buffer> <silent> S :call TermDBG_KeyS()<cr>

    noremap <expr><buffer>c  TermDBG_isModifiablex() ? "c" : ""  
    noremap <expr><buffer>C  TermDBG_isModifiablex() ? "C" : ""  

    noremap <expr><buffer>p  TermDBG_isModifiable() ? "p" : ""  
    noremap <expr><buffer>P  TermDBG_isModifiablex() ? "P" : ""  


    inoremap <expr><buffer><Del>        TermDBG_isModifiablex() ? "<Del>"    : ""  
    noremap <expr><buffer><Del>         TermDBG_isModifiablex() ? "<Del>"    : ""  
    noremap <expr><buffer><Insert>      TermDBG_isModifiableX() ? "<Insert>" : ""  

    inoremap <expr><buffer><Left>       TermDBG_isModifiableX() ? "<Left>"   : ""  
    noremap <expr><buffer><Left>        TermDBG_isModifiableX() ? "<Left>"   : ""  
    inoremap <expr><buffer><Right>      TermDBG_isModifiablex() ? "<Right>"  : ""  
    noremap <expr><buffer><Right>       TermDBG_isModifiablex() ? "<Right>"  : ""  

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


    noremap <buffer><silent>? :call TermDBG_toggle_help()<cr>
    " inoremap <buffer> <silent> <c-i> <c-o>:call s:TermDBG_gotoInput()<cr>
    " noremap <buffer> <silent> <c-i> :call s:TermDBG_gotoInput()<cr>

    inoremap <expr><buffer> <silent> <c-p>  "\<c-x><c-l>"
    inoremap <expr><buffer> <silent> <c-r>  "\<c-x><c-n>"

    inoremap <expr><buffer><silent> <TAB>    pumvisible() ? "\<C-n>" : "\<c-x><c-u>"
    inoremap <expr><buffer><silent> <S-TAB>  pumvisible() ? "\<C-p>" : "\<c-x><c-u>"
    " inoremap <expr><buffer><silent> <TAB>    pumvisible() ? "\<C-n>" : "\<C-R>=TermDBG_Compl()<CR>"
    " inoremap <expr><buffer><silent> <S-TAB>  pumvisible() ? "\<C-p>" : "\<C-R>=TermDBG_Compl()<CR>"
    noremap <buffer><silent> <Tab> ""
    noremap <buffer><silent> <S-Tab> ""

    noremap <buffer><silent> <ESC> :call TermDBG_close_window()<CR>

    inoremap <expr><buffer> <silent> <CR> pumvisible() ? "\<c-y><c-o>:call TermDBG(getline('.'), 'i')<cr>" : "<c-o>:call TermDBG(getline('.'), 'i')<cr>"
    imap <buffer> <silent> <2-LeftMouse> <cr>
    imap <buffer> <silent> <kEnter> <cr>

    nnoremap <buffer> <silent> <CR> :call TermDBG(getline('.'), 'n')<cr>
    nmap <buffer> <silent> <2-LeftMouse> <cr>
    imap <buffer> <silent> <LeftMouse> <Nop>
    nmap <buffer> <silent> <kEnter> <cr>

    " inoremap <buffer> <silent> <TAB> <C-X><C-L>
    "nnoremap <buffer> <silent> : <C-W>p:

    nmap <silent> <F9>	         :call TermDBG_ToggleBreakpoint()<CR>
    map! <silent> <F9>	         <c-o>:call TermDBG_ToggleBreakpoint()<CR>

    " nmap <silent> <F9>	         :call TermDBG_Btoggle(0)<CR>
    nmap <silent> <C-F9>	     :call TermDBG_Btoggle(1)<CR>
    " map! <silent> <F9>	         <c-o>:call TermDBG_Btoggle(0)<CR>
    map! <silent> <C-F9>         <c-o>:call TermDBG_Btoggle(1)<CR>
    nmap <silent> <Leader>ju	 :call TermDBG_jump()<CR>
    nmap <silent> <C-S-F10>		 :call TermDBG_jump()<CR>
    nmap <silent> <C-F10>        :call TermDBG_runToCursur()<CR>
    map! <silent> <C-S-F10>		 <c-o>:call TermDBG_jump()<CR>
    map! <silent> <C-F10>        <c-o>:call TermDBG_runToCursur()<CR>
    nmap <silent> <F6>           :call TermDBG("run")<CR>
    nmap <silent> <C-P>	         :TermDBG p <C-R><C-W><CR>
    vmap <silent> <C-P>	         y:TermDBG p <C-R>0<CR>
    nmap <silent> <Leader>pr	 :TermDBG p <C-R><C-W><CR>
    vmap <silent> <Leader>pr	 y:TermDBG p <C-R>0<CR>
    nmap <silent> <Leader>bt	 :TermDBG bt<CR>

    nmap <silent> <F5>    :TermDBG c<cr>
    nmap <silent> <S-F5>  :TermDBG k<cr>
    nmap <silent> <F10>   :TermDBG n<cr>
    nmap <silent> <F11>   :TermDBG s<cr>
    nmap <silent> <S-F11> :TermDBG finish<cr>
    nmap <silent> <c-q> :TermDBG q<cr>
    nmap <c-c> :call TermDBG_SendKey("\<c-c>")<cr>

    " map! <silent> <F5>    <c-o>:TermDBG c<cr>i
    " map! <silent> <S-F5>  <c-o>:TermDBG k<cr>i
    map! <silent> <F5>    <c-o>:TermDBG c<cr>
    map! <silent> <S-F5>  <c-o>:TermDBG k<cr>
    map! <silent> <F10>   <c-o>:TermDBG n<cr>
    map! <silent> <F11>   <c-o>:TermDBG s<cr>
    map! <silent> <S-F11> <c-o>:TermDBG finish<cr>
    map! <silent> <c-q>   <c-o>:TermDBG q<cr>

    amenu TermDBG.Toggle\ breakpoint<tab>F9			:call TermDBG_Btoggle(0)<CR>
    amenu TermDBG.Run/Continue<tab>F5 					:TermDBG c<CR>
    amenu TermDBG.Step\ into<tab>F11					:TermDBG s<CR>
    amenu TermDBG.Next<tab>F10							:TermDBG n<CR>
    amenu TermDBG.Step\ out<tab>Shift-F11				:TermDBG finish<CR>
    amenu TermDBG.Run\ to\ cursor<tab>Ctrl-F10			:call TermDBG_runToCursur()<CR>
    amenu TermDBG.Stop\ debugging\ (Kill)<tab>Shift-F5	:TermDBG k<CR>
    amenu TermDBG.-sep1- :

    amenu TermDBG.Show\ callstack<tab>\\bt				:call TermDBG("where")<CR>
    amenu TermDBG.Set\ next\ statement\ (Jump)<tab>Ctrl-Shift-F10\ or\ \\ju 	:call TermDBG_jump()<CR>
    amenu TermDBG.Top\ frame 						:call TermDBG("frame 0")<CR>
    amenu TermDBG.Callstack\ up 					:call TermDBG("up")<CR>
    amenu TermDBG.Callstack\ down 					:call TermDBG("down")<CR>
    amenu TermDBG.-sep2- :

    amenu TermDBG.Preview\ variable<tab>Ctrl-P		:TermDBG p <C-R><C-W><CR> 
    amenu TermDBG.Print\ variable<tab>\\pr			:TermDBG p <C-R><C-W><CR> 
    amenu TermDBG.Show\ breakpoints 				:TermDBG info breakpoints<CR>
    amenu TermDBG.Show\ locals 					:TermDBG info locals<CR>
    amenu TermDBG.Show\ args 						:TermDBG info args<CR>
    amenu TermDBG.Quit			 					:TermDBG q<CR>


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

    nnoremenu WinBar.Step   :TermDBG s<CR>
    nnoremenu WinBar.Next   :TermDBG n<CR>
    nnoremenu WinBar.Finish :TermDBG finish<CR>
    nnoremenu WinBar.Cont   :TermDBG c<CR>
    nnoremenu WinBar.Stop   :TermDBG k<CR>
    nnoremenu WinBar.Eval   :Evaluate<CR>
    call add(s:winbar_winids, win_getid(winnr()))
endfunc

" Delete installed debugger commands in the current window.
func s:DeleteCommands_Hotkeys()
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
    sign undefine termdbgPC
    sign undefine termdbgBP
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
        exec 'so '. g:termdbg_exrc . s:gdbd_port
        call delete(g:termdbg_exrc . s:gdbd_port)
    else
        " so .exrc
        exec 'so '. g:termdbg_exrc . s:gdbd_port
        call delete(g:termdbg_exrc . s:gdbd_port)
    endif
    stopi
endfunc

" :Break - Set a breakpoint at the cursor position.
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

" :Clear - Delete a breakpoint at the cursor position.
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

func TermDBG_ToggleBreakpoint()
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

" :Next, :Continue, etc - send a command to gdb
func s:SendCommand(cmd)
    call ch_sendraw(s:commjob, a:cmd . "\n")
endfunc

func TermDBG_SendKey(key)
    call ch_sendraw(s:commjob, a:key)
endfunc

func s:Run(args)
    if a:args != ''
        call s:SendCommand('-exec-arguments ' . a:args)
    endif
    call s:SendCommand('-exec-run')
endfunc

func s:SendEval(expr)
    call s:SendCommand('-data-evaluate-expression "' . a:expr . '"')
    let s:evalexpr = a:expr
endfunc

" :Evaluate - evaluate what is under the cursor
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

" Show a balloon with information of the variable under the mouse pointer,
" if there is any.
func! TermDBG_BalloonExpr()
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
    " for goto_console_win to display also
    call s:SendEval(v:beval_text)

    return s:evalFromBalloonExprResult

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

        " if -1 == match(fname, '\\\\')
        " let fname = fname
        " else
        " let fname = substitute(fname, '\\\\','\\', 'g')
        " endif

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
                exe 'sign place ' . s:pc_id . ' line=' . lnum . ' name=termdbgPC file=' . fname
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
    exe 'e '.fname
    exe lnum

    if bufloaded(fname)
        call s:PlaceSign(nr, entry)
    endif
    redraw
endfunc

func s:PlaceSign(nr, entry)
    exe 'sign place ' . (s:break_id + a:nr) . ' line=' . a:entry['lnum'] . ' name=termdbgBP file=' . a:entry['fname']
    let a:entry['placed'] = 1
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

" Handle a BufRead autocommand event: place any signs.
func s:BufRead()
    " let fname = expand('<afile>:p')
    let fname = fnamemodify(expand('<afile>:t'), ":p")
    for [nr, entry] in items(s:breakpoints)
        if entry['fname'] == fname
            call s:PlaceSign(nr, entry)
        endif
    endfor
endfunc

" Handle a BufUnloaded autocommand event: unplace any signs.
func s:BufUnloaded()
    " let fname = expand('<afile>:p')
    let fname = fnamemodify(expand('<afile>:t'), ":p")
    for [nr, entry] in items(s:breakpoints)
        if entry['fname'] == fname
            let entry['placed'] = 0
        endif
    endfor
endfunc

" ======================================================================================
" Prevent multiple loading unless: let force_load=1

let s:match = []
function! s:mymatch(expr, pat)
    let s:match = matchlist(a:expr, a:pat)
    return len(s:match) >0
endf

function! s:goto_console_win()
    if bufname("%") == s:termdbg_bufname
        return
    endif
    let termdbg_winnr = bufwinnr(s:termdbg_bufname)
    if termdbg_winnr == -1
        " if multi-tab or the buffer is hidden
        call TermDBG_openWindow()
        let termdbg_winnr = bufwinnr(s:termdbg_bufname)
    endif
    exec termdbg_winnr . "wincmd w"
endf

function! s:TermDBG_bpkey(file, line)
    return a:file . ":" . a:line
endf

function! s:TermDBG_curpos()
    " ???? filename ????
    let file = expand("%:t")
    let line = line(".")
    return s:TermDBG_bpkey(file, line)
endf

" Get ready for communication
function! TermDBG_openWindow()
    let bufnum = bufnr(s:termdbg_bufname)

    if bufnum == -1
        " Create a new buffer
        let wcmd = s:termdbg_bufname
    else
        " Edit the existing buffer
        let wcmd = '+buffer' . bufnum
    endif

    " Create the tag explorer window
    exe 'silent!  botright ' . s:termdbg_winheight . 'split ' . wcmd
    if line('$') <= 1 && g:termdbg_enable_help
        silent call append ( 0, s:help_text )
    endif
    call s:InstallWinbar()
endfunction

" NOTE: this function will be called by termdbg script.
function! TermDBG_open()
    " save current setting and restore when termdbg quits via 'so .exrc'
    " exec 'mk! '
    exec 'mk! ' . g:termdbg_exrc . s:gdbd_port
    "delete line set runtimepath for missing some functions after termdbg quit
    " silent exec '!start /b sed -i "/set runtimepath/d" ' . g:termdbg_exrc . s:gdbd_port
    silent exec '!start /b sed -i "/set /d" ' . g:termdbg_exrc . s:gdbd_port
    let sed_tmp = fnamemodify(g:termdbg_exrc . s:gdbd_port, ":p:h")
    silent exec '!start /b rm -f '. sed_tmp . '/sed*'   

    set nocursorline
    set nocursorcolumn

    call TermDBG_openWindow()

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
    setlocal foldtext=TermDBG_foldTextExpr()
    setlocal foldmarker={,}
    setlocal foldmethod=marker

    call s:InstallCommands_Hotkeys()

    let s:termdbg_running = 1

    " call TermDBG("init") " get init msg
    " call TermDBG("help") " get init msg
    call TermDBG("") " get init msg
    starti!
    " call cursor(0, 7)

    setl completefunc=TermDBG_Complete
    "wincmd p
endfunction

fun! TermDBG_Complete(findstart, base)

    if a:findstart

        let usercmd = getline('.')
        if s:dbg == 'gdb' && usercmd =~ '^\s*(gdb)' 
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


function! TermDBG_SendCmd(cmd)
    let usercmd = a:cmd
    call add(s:historys, usercmd)

    " echomsg "usercmd:".usercmd
    let s:usercmd = usercmd

    call s:SendCommand(a:cmd)
    return ''

endf

" mode: i|n|c|<empty>
" i - input command in VGDB window and press enter
" n - press enter (or double click) in VGDB window
" c - run Gdb command
function! TermDBG(cmd, ...)  " [mode]
    let usercmd = a:cmd
    let s:mode = a:0>0 ? a:1 : ''
    if usercmd == ""
        let s:mode = 'i'
    endif

    if s:termdbg_running == 0
        let s:gdbd_port= 30000 + reltime()[1] % 10000
        call s:StartDebug(usercmd)
        call TermDBG_open()

        return
    endif

    if s:termdbg_running == 0
        echomsg "termdbg is not running"
        return
    endif

    if -1 == bufwinnr(s:termdbg_bufname)
        call TermDBG_toggle_window()
        return
    endif

    " echomsg "usercmd[".usercmd."]"
    if s:dbg == 'gdb' && usercmd =~ '^\s*(gdb)' 
        let usercmd = substitute(usercmd, '^\s*(gdb)\s*', '', '')
    elseif s:dbg == 'gdb' && usercmd =~ '^\s*>\s*' 
        let usercmd = substitute(usercmd, '^\s*>\s*', '', '')
        " echomsg "usercmd2". usercmd
    endif

    call TermDBG_SendCmd(usercmd)

endf

function TermDBG_toggle_window()
    if  s:termdbg_running == 0
        return
    endif
    let result = TermDBG_close_window()
    if result == 0
        call s:goto_console_win()
        call setpos('.', s:termdbg_save_cursor)
    endif
endfunction

function TermDBG_close_window()
    let winnr = bufwinnr(s:termdbg_bufname)
    if winnr != -1
        call s:goto_console_win()
        let s:termdbg_save_cursor = getpos(".")
        close
        if s:isunix
            call win_gotoid(s:ptywin)
            exec "resize ".g:termdbg_program_win_row
            call win_gotoid(s:startwin)
        endif
        return 1
    endif
    return 0
endfunction

" Toggle breakpoints
function! TermDBG_Btoggle(forDisable)
endf

function! TermDBG_jump()
    call win_gotoid(s:startwin)
    let key = s:TermDBG_curpos()
    "	call TermDBG("@tb ".key." ; ju ".key)
    "	call TermDBG("set $rbp1=$rbp; set $rsp1=$rsp; @tb ".key." ; ju ".key . "; set $rsp=$rsp1; set $rbp=$rbp1")
    call TermDBG(".ju ".key)
endf

function! TermDBG_runToCursur()
    call win_gotoid(s:startwin)
    let key = s:TermDBG_curpos()
    call TermDBG("@tb ".key." ; c")
endf

function! TermDBG_isPrompt()
    if  strpart(s:termdbg_prompt, 0, 5) == strpart(getline("."), 0, 5) && col(".") <= strlen(s:termdbg_prompt)+1 
        return 1
    else
        return 0
    endif
endf

function! TermDBG_isModifiable()
    let pos = getpos(".")  
    let curline = pos[1]
    if  curline == line("$") && strpart(s:termdbg_prompt, 0, 5) == strpart(getline("."), 0, 5) && col(".") >= strlen(s:termdbg_prompt)
        return 1
    else
        return 0
    endif
endf

function! TermDBG_isModifiablex()
    let pos = getpos(".")  
    let curline = pos[1]
    if  curline == line("$") && strpart(s:termdbg_prompt, 0, 5) == strpart(getline("."), 0, 5) && col(".") >= strlen(s:termdbg_prompt)+1
                \ || (curline == line("$") && ' >' == strpart(getline("."), 0, 2) && col(".") >= strlen(' >')+1)
        return 1
    else
        return 0
    endif
endf
function! TermDBG_isModifiableX()
    let pos = getpos(".")  
    let curline = pos[1]
    if  (curline == line("$") && strpart(s:termdbg_prompt, 0, 5) == strpart(getline("."), 0, 5) && col(".") >= strlen(s:termdbg_prompt)+2)
                \ || (curline == line("$") && ' >' == strpart(getline("."), 0, 2) && col(".") >= strlen(' >')+2)
        return 1
    else
        return 0
    endif
endf
fun! TermDBG_Keyi()
    let pos = getpos(".")  
    let curline = pos[1]
    let curcol = pos[2]
    if curline == line("$")
        if curcol >  strlen(s:termdbg_prompt)
            starti
        else
            starti!
        endif
    else
        silent call s:TermDBG_gotoInput()
    endif
endf

fun! TermDBG_KeyI()
    let pos = getpos(".")  
    let curline = pos[1]
    let curcol = pos[2]
    if curline == line("$")
        let pos[2] = strlen(s:termdbg_prompt)+1
        call setpos(".", pos)
        starti
    else
        silent call s:TermDBG_gotoInput()
    endif
endf

fun! TermDBG_Keya()
    let linecon = getline("$")
    let pos = getpos(".")  
    let curline = pos[1]
    let curcol = pos[2]
    if curline == line("$")
        if curcol >=  strlen(s:termdbg_prompt)
            if linecon == s:termdbg_prompt
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
        silent call s:TermDBG_gotoInput()
    endif
endf

fun! TermDBG_KeyA()
    let pos = getpos(".")  
    let curline = pos[1]
    let curcol = pos[2]
    if curline == line("$")
        starti!
    else
        silent call s:TermDBG_gotoInput()
    endif
endf

function TermDBG_Keyo()
    let linecon = getline("$")
    if linecon == s:termdbg_prompt
        exec "normal G"
        starti!
    else
        call append('$', s:termdbg_prompt)
        $
        starti!
    endif
endfunction

function TermDBG_KeyS()
    exec "normal G"
    exec "normal dd"
    call append('$', s:termdbg_prompt)
    $
    starti!
endfunction

function! TermDBG_foldTextExpr()
    return getline(v:foldstart) . ' ' . substitute(getline(v:foldstart+1), '\v^\s+', '', '') . ' ... (' . (v:foldend-v:foldstart-1) . ' lines)'
endfunction

" if the value is a pointer ( var = 0x...), expand it by "TermDBG p *var"
" e.g. $11 = (CDBMEnv *) 0x387f6d0
" e.g.  
" (CDBMEnv) $22 = {
"  m_pTempTables = 0x37c6830,
"  ...
" }
function! TermDBG_expandPointerExpr()
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
    exec "TermDBG p *" . cmd
    if foldlevel('.') > 0
        " goto beginning of the fold and close it
        normal [zzc
        " ensure all folds for this var are closed
        foldclose!
    endif
    return 1
endf

function TermDBG_toggle_help()
    if !g:termdbg_enable_help
        return
    endif

    let s:help_open = !s:help_open
    silent exec '1,' . len(s:help_text) . 'd _'
    call s:update_help_text()
    silent call append ( 0, s:help_text )
    silent keepjumps normal! gg
endfunction

function s:TermDBG_gotoInput()
    " exec "InsertLeave"
    exec "normal G"
    starti!
endfunction


fun! TermDBG_Compl()

    let usercmd = getline('.')
    if s:dbg == 'gdb' && usercmd =~ '^\s*(gdb)' 
        let usercmd = substitute(usercmd, '^\s*(gdb)\s*', '', '')
        let usercmd = substitute(usercmd, '*', '', '') "fixed *pointer
        let usercmd = 'complete ' .  usercmd
    endif

    call TermDBG_SendCmd(usercmd)

    return ''
endfunc

command! -nargs=* -complete=file TermDBG :call TermDBG(<q-args>)
" directly show result; must run after TermDBG is running
command! -nargs=* -complete=file TermDBGcall :echo TermDBG_SendCmd(<q-args>)

command -nargs=* -complete=file TD call s:StartDebug(<q-args>)

command TermDBGStop call TermDBG_SendKey("\<c-c>")
map <silent> <F5> :TermDBG<cr>
map <silent> <c-c> :TermDBGStop<cr>

" vim: set foldmethod=marker 
