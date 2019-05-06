"""""""""""""""""""""""""""""""""""""""""""""""""""""""
" NeoDebug - Vim plugin for interface to gdb from Vim 
" Maintainer: scott (cpiger@qq.com)
" Version: 0.1 2018-05-03  ready to use.
"""""""""""""""""""""""""""""""""""""""""""""""""""""""
" In case this gets loaded twice.
if exists(':NeoDebug')
    finish
endif
" Name of the NeoDebug command, defaults to "gdb".
if !exists('g:neodbg_debugger')
    let g:neodbg_debugger = 'gdb'
endif

if !exists('g:neodbg_gdb_path')
   let g:neodbg_gdb_path = 'gdb'
endif

if !exists('g:neodbg_cmd_prefix')
    let g:neodbg_cmd_prefix='DBG'
endif

if !exists('g:neodbg_ballonshow_with_print')
    let g:neodbg_ballonshow_with_print = 0
endif

if !exists('g:neodbg_debuginfo')
    let g:neodbg_debuginfo = 0
endif

if !exists('g:neodbg_enable_help')
    let g:neodbg_enable_help = 1
endif

if !exists('g:neodbg_keymap_toggle_breakpoint')
    let g:neodbg_keymap_toggle_breakpoint = '<F9>'
endif

if !exists('g:neodbg_keymap_next')
    let g:neodbg_keymap_next = '<F10>'
endif

if !exists('g:neodbg_keymap_run_to_cursor ')
    let g:neodbg_keymap_run_to_cursor = '<C-F10>'
endif

if !exists('g:neodbg_keymap_jump')
    let g:neodbg_keymap_jump = '<C-S-F10>'
endif

if !exists('g:neodbg_keymap_step_into')
    let g:neodbg_keymap_step_into = '<F11>'
endif
if !exists('g:neodbg_keymap_step_out')
    let g:neodbg_keymap_step_out = '<S-F11>'
endif

if !exists('g:neodbg_keymap_continue')
    let g:neodbg_keymap_continue = '<F5>'
endif

if !exists('g:neodbg_keymap_print_variable')
    let g:neodbg_keymap_print_variable = '<C-P>'
endif

if !exists('g:neodbg_keymap_stop_debugging')
    let g:neodbg_keymap_stop_debugging = '<S-F5>'
endif

if !exists('g:neodbg_keymap_toggle_console_win')
    let g:neodbg_keymap_toggle_console_win = '<F6>'
endif

if !exists('g:neodbg_keymap_terminate_debugger')
    let g:neodbg_keymap_terminate_debugger = '<C-C>'
endif



if !exists('g:neodbg_openlocals_default')
    let g:neodbg_openlocals_default    = 1
endif
if !exists('g:neodbg_openregisters_default')
    let g:neodbg_openregisters_default = 0
endif
if !exists('g:neodbg_openstacks_default')
    let g:neodbg_openstacks_default    = 0
endif
if !exists('g:neodbg_openthreads_default')
    let g:neodbg_openthreads_default   = 0
endif
if !exists('g:neodbg_openbreaks_default')
    let g:neodbg_openbreaks_default    = 0
endif
if !exists('g:neodbg_opendisas_default')
    let g:neodbg_opendisas_default    = 0
endif
if !exists('g:neodbg_openexprs_default')
    let g:neodbg_openexprs_default    = 1
endif
if !exists('g:neodbg_openwatchs_default')
    let g:neodbg_openwatchs_default    = 0
endif

let g:neodbg_console_name = "__DebugConsole__"
let g:neodbg_console_height = 15
let g:neodbg_prompt = '(gdb) '

let g:neodbg_locals_name = "__Locals__"
let g:neodbg_locals_width = 50
let g:neodbg_locals_height = 25

let g:neodbg_registers_name = "__Registers__"
let g:neodbg_registers_width = 50
let g:neodbg_registers_height = 25

let g:neodbg_stackframes_name = "__Stack Frames__"
let g:neodbg_stackframes_width = 50
let g:neodbg_stackframes_height = 25

let g:neodbg_threads_name = "__Threads__"
let g:neodbg_threads_width = 50
let g:neodbg_threads_height = 25

let g:neodbg_breakpoints_name = "__Breakpoints__"
let g:neodbg_breakpoints_width = 50
let g:neodbg_breakpoints_height = 25

let g:neodbg_disas_name = "__Disassemble__"
let g:neodbg_disas_width = 50
let g:neodbg_disas_height = 25

let g:neodbg_expressions_name = "__Expressions__"
let g:neodbg_expressions_width = 50
let g:neodbg_expressions_height = 25

let g:neodbg_watchpoints_name = "__Watchpoints__"
let g:neodbg_watchpoints_width = 50
let g:neodbg_watchpoints_height = 25

let g:neodbg_locals_win = 0
let g:neodbg_registers_win = 0
let g:neodbg_stackframes_win = 0
let g:neodbg_threads_win = 0
let g:neodbg_breakpoints_win = 0
let g:neodbg_disas_win = 0
let g:neodbg_expressions_win = 0
let g:neodbg_watchpoints_win = 0


let s:neodbg_chan = 0

let s:neodbg_is_debugging = 0
let s:neodbg_running = 0
let s:neodbg_exrc_dir = $HOME.'/.neodebug'
let s:neodbg_exrc = s:neodbg_exrc_dir . '/neodbg_exrc'
let s:neodbg_port = 30777 

let s:ismswin = has('win32')
let s:isunix = has('unix')

let s:completers = []
let s:neodbg_cmd_historys = [" "]

let s:pc_id = 12
let s:break_id = 13
let s:stopped = 1
let s:breakpoints = {}

let s:cur_wid = 0
let s:cur_winnr = 0

" mode: i|n|c|<empty>
" i - input command in console window and press enter
" n - press enter (or double click) in console window
" c - run debugger command
function! NeoDebug(cmd, ...)  " [mode]
    let usercmd = a:cmd
    let mode = a:0>0 ? a:1 : ''

    let s:cur_wid = win_getid(winnr())
    " echomsg "s:cur_wid1".s:cur_wid
    let s:cur_winnr = bufwinnr("%")

    if s:neodbg_running == 0
        let s:neodbg_port= 30000 + reltime()[1] % 10000

        call neodebug#OpenLocals()
        let g:neodbg_locals_win = win_getid(winnr())

        call neodebug#OpenRegisters()
        let g:neodbg_registers_win = win_getid(winnr())

        call neodebug#OpenStackFrames()
        let g:neodbg_stackframes_win = win_getid(winnr())

        call neodebug#OpenThreads()
        let g:neodbg_threads_win = win_getid(winnr())

        call neodebug#OpenBreakpoints()
        let g:neodbg_breakpoints_win = win_getid(winnr())

        call neodebug#OpenDisas()
        let g:neodbg_disas_win = win_getid(winnr())

        call neodebug#OpenExpressions()
        let g:neodbg_expressions_win = win_getid(winnr())

        call neodebug#OpenWatchpoints()
        let g:neodbg_watchpoints_win = win_getid(winnr())


        call neodebug#CloseWatchpointsWindow()
        call neodebug#CloseExpressionsWindow()
        call neodebug#CloseDisasWindow()
        call neodebug#CloseBreakpointsWindow()
        call neodebug#CloseThreadsWindow()
        call neodebug#CloseStackFramesWindow()
        call neodebug#CloseRegistersWindow()
        call neodebug#CloseLocalsWindow()
        call s:NeoDebugStart(usercmd)

        " save current setting and restore when neodebug quits via 'so .exrc'
        if finddir(s:neodbg_exrc_dir) == ''
            call mkdir(s:neodbg_exrc_dir, "p")
        endif
        exec 'mk! ' . s:neodbg_exrc . s:neodbg_port
        let sed_cmd = 'sed -i "/^set /d" ' . s:neodbg_exrc . s:neodbg_port

        if has('nvim')
            call jobstart(sed_cmd)
        else
            call job_start(sed_cmd)
        endif

        set nocursorline
        set nocursorcolumn

        call neodebug#OpenConsole()
        let s:neodbg_console_win = win_getid(winnr())
        "fix minibufexpl plugin conflict
        " call neodebug#CloseConsoleWindow()
        " call neodebug#OpenConsoleWindow()

        let s:neodbg_quitted = 0
        let s:neodbg_running = 1

        return
    endif

    if s:neodbg_running == 0
        echomsg "NeoDebug is not running"
        return
    endif

    " if -1 == bufwinnr(g:neodbg_console_name)
        " call neodebug#ToggleConsoleWindow()
        " return
    " endif

    " echomsg "usercmd[".usercmd."]"
    if g:neodbg_debugger == 'gdb' && usercmd =~ '^\s*(gdb)' 
        let usercmd = substitute(usercmd, '^\s*(gdb)\s*', '', '')
    elseif g:neodbg_debugger == 'gdb' && usercmd =~ '^\s*>\s*' 
        let usercmd = substitute(usercmd, '^\s*>\s*', '', '')
        " echomsg "usercmd2[".usercmd."]"
    endif

    " goto frame
    " #0  factor (n=1, r=0x22fe48) at factor/factor.c:4
    " #1  0x00000000004015e2 in main (argc=1, argv=0x5b3480) at sample.c:12
    if s:NeoDebugMatch(usercmd, '\v^#(\d+)')  && s:neodbg_is_debugging
        let usercmd = "frame " . s:neodbg_match[1]
        call NeoDebugSendCommand(usercmd)
        return
    endif

    " goto thread and show frames
    " Id   Target Id         Frame 
    " 2    Thread 83608.0x14dd0 0x00000000773c22da in ntdll!RtlInitString () from C:\\windows\\SYSTEM32\tdll.dll
    " 1    Thread 83608.0x1535c factor (n=1, r=0x22fe48) at factor/factor.c:5
    if s:NeoDebugMatch(usercmd, '\v^\s+(\d+)\s+Thread ') && s:neodbg_is_debugging
        let usercmd = "-thread-select " . s:neodbg_match[1]
        call NeoDebugSendCommand(usercmd)
        call NeoDebugSendCommand("bt")
        return
    endif

    " Num     Type           Disp Enb Address            What
    " 1       breakpoint     keep y   0x00000000004015c4 in main at sample.c:8
    " 2       breakpoint     keep y   0x00000000004015d4 in main at sample.c:12
    " 3       breakpoint     keep y   0x00000000004015e2 in main at sample.c:13
    if s:NeoDebugMatch(usercmd, '\v<at %(0x\S+ )?(..[^:]*):(\d+)') || s:NeoDebugMatch(usercmd, '\vfile ([^,]+), line (\d+)') || s:NeoDebugMatch(usercmd, '\v\((..[^:]*):(\d+)\)')
        call s:NeoDebugGotoFile(s:neodbg_match[1], s:neodbg_match[2])
        return
    endif

    if mode == 'n'  " mode n: jump to source or current callstack, dont exec other gdb commands
        call NeoDebugExpandPointerExpr()
        return
    endif

    if usercmd == 'c'
        let usercmd = s:neodbg_is_debugging ? 'continue' : 'run'
    endif

    call NeoDebugSendCommand(usercmd, mode)
endfunction

function! NeoDebugStop(cmd)
    " echomsg "s:neodbg_running".s:neodbg_running

	if !s:neodbg_running
		return
	endif

    if has('nvim')
        call jobstop(s:nvim_commjob)
    else
        call job_stop(s:commjob)
    endif
endfunction

let s:neodbg_init_flag = 1
function! s:NeoDebugStart(cmd)
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
    if g:neodbg_debugger == 'gdb'
        "-f for do not display code,
        " let cmd = [g:neodbg_gdb_path, '-quiet', '--interpreter=mi2', a:cmd]
        let cmd = [g:neodbg_gdb_path, '-quiet', '-f', '--interpreter=mi2', a:cmd]
    endif
    " Create a hidden terminal window to communicate with gdb
    if has('nvim')
        let opts = {
                    \ 'on_stdout': function('s:NvimHandleOutput'),
                    \ 'on_exit': function('s:NvimNeoDebugEnd'),
                    \ }

        let s:nvim_commjob = jobstart(cmd, opts)

    else
        let s:commjob = job_start(cmd, {
                    \ 'out_cb' : function('s:HandleOutput'),
                    \ 'exit_cb': function('s:NeoDebugEnd'),
                    \ })

        let s:neodbg_chan = job_getchannel(s:commjob)  
        let commpty = job_info((s:commjob))['tty_out']
    endif


    " Interpret commands while the target is running.  This should usualy only be
    " exec-interrupt, since many commands don't work properly while the target is
    " running.
    let s:neodbg_init_flag = 1
    let s:init_count = 0
    let s:start_count = 0
    " echomsg "s:neodbg_init_flag==================".s:neodbg_init_flag
    call NeoDebugSendCommand('set mi-async on')
    if s:ismswin
        call NeoDebugSendCommand('set new-console on')
    elseif s:isunix
        call NeoDebugSendCommand('show inferior-tty')
    endif
    call NeoDebugSendCommand('set print pretty on')
    call NeoDebugSendCommand('set breakpoint pending on')
    call NeoDebugSendCommand('set pagination off')
    " let s:neodbg_init_flag = 0

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
        au VimLeavePre * call delete(s:neodbg_exrc . s:neodbg_port)
    augroup END

endfunction


function! NeoDebugReadRaw()
    return ch_readraw(s:neodbg_chan)
endfunction


function! s:NvimNeoDebugEnd(job_id, data, event_type) abort
    call s:NeoDebugEnd(a:job_id, a:event_type)
endfunction



function! s:NeoDebugEnd(job, status)

	if !s:neodbg_running
		return
	endif

	let s:neodbg_running = 0
    sign unplace *

    " If neodebug console window is open then close it.
    call neodebug#GotoWatchpointsWindow()
    quit
    call neodebug#GotoExpressionsWindow()
    quit
    call neodebug#GotoBreakpointsWindow()
    quit
    call neodebug#GotoDisasWindow()
    quit
    call neodebug#GotoRegistersWindow()
    quit
    call neodebug#GotoStackFramesWindow()
    quit
    call neodebug#GotoThreadsWindow()
    quit
    call neodebug#GotoLocalsWindow()
    quit
    call neodebug#GotoConsoleWindow()
    quit

    exe 'bwipe! ' . bufnr(g:neodbg_locals_name)
    exe 'bwipe! ' . bufnr(g:neodbg_registers_name)
    exe 'bwipe! ' . bufnr(g:neodbg_stackframes_name)
    exe 'bwipe! ' . bufnr(g:neodbg_threads_name)
    exe 'bwipe! ' . bufnr(g:neodbg_breakpoints_name)
    exe 'bwipe! ' . bufnr(g:neodbg_disas_name)
    exe 'bwipe! ' . bufnr(g:neodbg_expressions_name)
    exe 'bwipe! ' . bufnr(g:neodbg_watchpoints_name)
    exe 'bwipe! ' . bufnr(g:neodbg_console_name)

    let curwinid = win_getid(winnr())

    call win_gotoid(s:startwin)
    let &signcolumn = s:startsigncolumn
    call NeoDebugRestoreCommandsShotcut()

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
    "back to normal
    call feedkeys("\<ESC>")
endfunction

function! s:NvimHandleOutput(id, data, event)
    for msg in a:data
        call s:HandleOutput(a:id, substitute(msg, '\r','', 'g'))
    endfor
endfunction


let s:updateinfo_skip_flag = 0
let s:completer_skip_flag = 0

let g:append_messages = ["(gdb) "]
let s:append_msg = ''
let s:appendline = ''
let s:append_err = ''
let s:comm_msg   = ''

let s:init_messages = ["(gdb) "]
let s:init_count = 0
let s:start_count = 0
" Handle a message received from debugger
function! s:HandleOutput(chan, msg)
    if g:neodbg_debuginfo == 1
        echomsg "<GDB><HandleOutput>:".a:msg."[s:mode:".s:mode."]"
    endif
    " echomsg "s:cur_wid2".s:cur_wid

    " echomsg "s:neodbg_init_flag".s:neodbg_init_flag
    " to control vim cursor position stay in neodebug console after init
    " &"set pagination off 
    if a:msg =~ 'set pagination off' &&  s:neodbg_init_flag == 1
        let s:start_count = 1
    endif
    if s:start_count == 1
        let s:init_count = s:init_count + 1
    endif
    if s:init_count == 5
        let s:init_count = 0
        let s:start_count = 0
        let s:neodbg_init_flag = 0
    endif
    if s:neodbg_init_flag == 1
        call add(s:init_messages, a:msg)
    endif


    let neodbg_winnr = bufwinnr(g:neodbg_console_name)
    " echomsg "neodbg_winnr".neodbg_winnr

    let cur_mode = mode()
    " let cur_wid = win_getid(winnr())

    " skip complete command,do not output completers
    if  "complete" == strpart(a:msg, 2, strlen("complete"))
        let s:completer_skip_flag = 1
    endif

    if s:completer_skip_flag == 1
        let s:comm_msg .= a:msg
    endif

    if  "complete" == strpart(s:comm_msg, 2, strlen("complete"))  && ( s:comm_msg =~  g:neodbg_prompt)
        let s:completer_skip_flag = 0
        let s:comm_msg = ''
        return
    endif

    " message should skipped to display to console
    " Handle update window
    if  (s:mode == 'u') && ( "info breakpoints" == strpart(a:msg, 2, strlen("info breakpoints")) || "disassemble" == strpart(a:msg, 2, strlen("disassemble")) || "info locals" == strpart(a:msg, 2, strlen("info locals")) || "backtrace" == strpart(a:msg, 2, strlen("backtrace")) || "info threads" == strpart(a:msg, 2, strlen("info threads"))|| "info registers" == strpart(a:msg, 2, strlen("info registers")) || "info watchpoints" == strpart(a:msg, 2, strlen("info watchpoints")) || "-data-evaluate-expression" == strpart(s:comm_msg, 2, strlen("-data-evaluate-expression")) || "print" == strpart(s:comm_msg, 2, strlen("print")) )
        let s:updateinfo_skip_flag = 1
    endif

    if s:updateinfo_skip_flag == 1
        let s:comm_msg .= a:msg
        let updateinfo_line = a:msg
        if  s:neodbg_quitted != 1
            if  "info locals" == strpart(s:comm_msg, 2, strlen("info locals"))
                call neodebug#GotoLocalsWindow()
            endif

            if  "info registers" == strpart(s:comm_msg, 2, strlen("info registers"))
                call neodebug#GotoRegistersWindow()
            endif

            if  "backtrace" == strpart(s:comm_msg, 2, strlen("backtrace"))
                call neodebug#GotoStackFramesWindow()
            endif

            if  "info threads" == strpart(s:comm_msg, 2, strlen("info threads"))
                call neodebug#GotoThreadsWindow()
            endif

            if "info breakpoints" == strpart(s:comm_msg, 2, strlen("info breakpoints"))
                call neodebug#GotoBreakpointsWindow()
            endif

            if "disassemble" == strpart(s:comm_msg, 2, strlen("disassemble"))
                call neodebug#GotoDisasWindow()
            endif

            if "-data-evaluate-expression" == strpart(s:comm_msg, 2, strlen("-data-evaluate-expression"))
                call neodebug#GotoExpressionsWindow()
            endif

            if "print" == strpart(s:comm_msg, 2, strlen("print"))
                call neodebug#GotoExpressionsWindow()
            endif

            if "info watchpoints" == strpart(s:comm_msg, 2, strlen("info watchpoints"))
                call neodebug#GotoWatchpointsWindow()
            endif

            let updateinfo_line = substitute(updateinfo_line, '\\t', "\t", 'g')
            if updateinfo_line =~ '^\~"'  
                let updateinfo_line = substitute(updateinfo_line, '\~"\\t', "\~\"\t\t", 'g')
                let updateinfo_line = substitute(updateinfo_line, ':\\t', ":\t\t", 'g')
                let updateinfo_line = substitute(updateinfo_line, '\\"', '"', 'g')
                let updateinfo_line = substitute(updateinfo_line, '\\\\', '\\', 'g')
                let s:appendline .= strpart(updateinfo_line, 2, strlen(updateinfo_line)-3)
                if updateinfo_line =~ '\\n"\_$'
                    " echomsg "s:appendfile:".s:appendline
                    let s:appendline = substitute(s:appendline, '\\n\|\\032\\032', '', 'g')
                    call neodebug#SetBufEnable()
                    call append(line("$")-1, s:appendline)
                    call neodebug#SetBufDisable()
                    let s:appendline = ''
                    " redraw!
                endif
            endif
            " exec "wincmd ="
        endif
        " echomsg "updateinfo_line::".updateinfo_line
        if updateinfo_line == g:neodbg_prompt
            if neodbg_winnr != -1
                if -1 == match(histget("cmd", -1), 'OpenConsole\|OpenLocals\|OpenRegisters\|OpenStacks\|OpenThreads\|OpenBreaks\|OpenDisas\|OpenExpressions\|OpenWatchs')
                    call neodebug#GotoConsoleWindow()
                endif
            endif
            "back to current window
            if -1 == match(histget("cmd", -1), 'OpenConsole\|OpenLocals\|OpenRegisters\|OpenStacks\|OpenThreads\|OpenBreaks\|OpenDisas\|OpenExpressions\|OpenWatchs')
                call win_gotoid(s:cur_wid)
            endif
        endif
    endif


    if  "info locals" == strpart(s:comm_msg, 2, strlen("info locals"))  && ( s:comm_msg =~  g:neodbg_prompt)
        let s:updateinfo_skip_flag = 0
        let s:comm_msg = ''
        return
    endif

    if  "info registers" == strpart(s:comm_msg, 2, strlen("info registers"))  && ( s:comm_msg =~  g:neodbg_prompt)
        let s:updateinfo_skip_flag = 0
        let s:comm_msg = ''
        return
    endif

    if  "backtrace" == strpart(s:comm_msg, 2, strlen("backtrace"))  && ( s:comm_msg =~  g:neodbg_prompt)
        let s:updateinfo_skip_flag = 0
        let s:comm_msg = ''
        return
    endif

    if  "info threads" == strpart(s:comm_msg, 2, strlen("info threads"))  && ( s:comm_msg =~  g:neodbg_prompt)
        let s:updateinfo_skip_flag = 0
        let s:comm_msg = ''
        return
    endif

    if  "info breakpoints" == strpart(s:comm_msg, 2, strlen("info breakpoints"))  && ( s:comm_msg =~  g:neodbg_prompt)
        let s:updateinfo_skip_flag = 0
        let s:comm_msg = ''
        return
    endif

    if  "disassemble" == strpart(s:comm_msg, 2, strlen("disassemble"))  && ( s:comm_msg =~  g:neodbg_prompt)
        let s:updateinfo_skip_flag = 0
        let s:comm_msg = ''
        return
    endif

    if  "-data-evaluate-expression" == strpart(s:comm_msg, 2, strlen("info watchpoints"))  && ( s:comm_msg =~  g:neodbg_prompt)
        let s:updateinfo_skip_flag = 0
        let s:comm_msg = ''
        return
    endif

    if  "print" == strpart(s:comm_msg, 2, strlen("print"))  && ( s:comm_msg =~  g:neodbg_prompt)
        let s:updateinfo_skip_flag = 0
        let s:comm_msg = ''
        return
    endif

    if  "info watchpoints" == strpart(s:comm_msg, 2, strlen("info watchpoints"))  && ( s:comm_msg =~  g:neodbg_prompt)
        let s:updateinfo_skip_flag = 0
        let s:comm_msg = ''
        return
    endif


    let debugger_line = a:msg
    " message for console to display
    if debugger_line != '' && s:completer_skip_flag == 0 && s:updateinfo_skip_flag == 0
        " Handle 
        if debugger_line =~ '^\(\*stopped\|\^done,new-thread-id=\|\*running\|=thread-selected\)'
            call s:HandleCursor(debugger_line)
        elseif debugger_line =~ '^\^done,bkpt=' || debugger_line =~ '=breakpoint-created,'
            call s:HandleNewBreakpoint(debugger_line)
        elseif debugger_line =~ '^=breakpoint-deleted,'
            call s:HandleBreakpointDelete(debugger_line)
        elseif debugger_line =~ '^\(=thread-created,id=\|=thread-selected,id=\|=thread-exited,id=\)'
            if !s:neodbg_quitted
                " call neodebug#UpdateThreadsWindow()
            endif
        elseif debugger_line =~ '^\^done,value='
            call s:HandleEvaluate(debugger_line)
        elseif debugger_line =~ '^\^error,msg='
            call s:HandleError(debugger_line)
        elseif debugger_line =~ '^\~"'  
            let debugger_line = substitute(debugger_line, '\\t', "\t", 'g')
        elseif debugger_line == g:neodbg_prompt
            let debugger_line = g:neodbg_prompt
        endif

        if neodbg_winnr != -1
            call neodebug#GotoConsoleWindow()
        endif

        if s:neodbg_sendcmd_flag == 1
            " call setline(line('$'), getline('$').s:neodbg_cmd_historys[-1])
            if neodbg_winnr != -1
                call setline(line('$'), getline('$').s:neodbg_cmd_historys[-1])
            else
                let g:append_messages[-1] =  g:append_messages[-1].s:neodbg_cmd_historys[-1]
            endif
            let s:neodbg_sendcmd_flag = 0
        endif

        if debugger_line =~ '^\~" >"' 
            call append(line("$"), strpart(debugger_line, 2, strlen(debugger_line)-3))
            " elseif debugger_line =~ '^\~"\S\+' 

        " elseif debugger_line =~ '^\*' 
            " call append(line("$"), debugger_line)

            "fix win32 gdb D:\\path\\path\\file
        elseif debugger_line =~ '^&"' && s:usercmd != substitute(strpart(debugger_line, 2 , strlen(debugger_line)-5), '\\\\', '\\', 'g')
            let debugger_line = substitute(debugger_line, '\~"\\t', "\~\"\t\t", 'g')
            let debugger_line = substitute(debugger_line, ':\\t', ":\t\t", 'g')
            let debugger_line = substitute(debugger_line, '\\"', '"', 'g')
            let debugger_line = substitute(debugger_line, '\\\\', '\\', 'g')
            let s:append_msg .= strpart(debugger_line, 2, strlen(debugger_line)-3)
            if debugger_line =~ '\\n"\_$'
                " echomsg "s:append_msg:".s:append_msg
                let s:append_msg = substitute(s:append_msg, '\\n\|\\032\\032', '', 'g')
                " call append(line("$"), s:append_msg)
                if neodbg_winnr != -1
                    call append(line("$"), s:append_msg)
                else
                    call add(g:append_messages, s:append_msg)
                endif
                let s:append_msg = ''
            endif

        elseif debugger_line =~ '^\~"' 
            if debugger_line =~ '^\~"\(Kill the program\|Program exited\|The program is not being run\|The program no longer exists\|Detaching from\|Inferior\)'
                let s:neodbg_is_debugging = 0
            elseif  debugger_line =~ '^\~"\(Starting program\|Attaching to\)'
                " ~"Starting program:  \n" 
                let index_colon = stridx(debugger_line, ":")
                let program_name = strpart(debugger_line, index_colon+2, stridx(debugger_line, ' \n', index_colon)-(index_colon+2) )
                if program_name != ''
                    let s:neodbg_is_debugging = 1
                endif
            endif
            " echomsg 's:neodbg_is_debugging'. s:neodbg_is_debugging
            let debugger_line = substitute(debugger_line, '\~"\\t', "\~\"\t\t", 'g')
            let debugger_line = substitute(debugger_line, ':\\t', ":\t\t", 'g')
            let debugger_line = substitute(debugger_line, '\\"', '"', 'g')
            let debugger_line = substitute(debugger_line, '\\\\', '\\', 'g')
            let s:appendline .= strpart(debugger_line, 2, strlen(debugger_line)-3)
            if debugger_line =~ '\\n"\_$'
                " echomsg "s:appendfile:".s:appendline
                let s:appendline = substitute(s:appendline, '\\n\|\\032\\032', '', 'g')
                " call append(line("$"), s:appendline)
                if neodbg_winnr != -1
                    call append(line("$"), s:appendline)
                    if s:isunix && -1 != stridx(s:appendline, "Terminal for future runs of program being debugged is")
                        call append(line('$'), "Please use gdb's tty command to redirect Your Program's Input and Output.")
                    endif
                else
                    call add(g:append_messages, s:appendline)
                endif
                let s:appendline = ''
            endif

        elseif debugger_line =~ '^\^error,msg='
            " if debugger_line =~ '^\^error,msg="The program'
                let s:append_err =  substitute(a:msg, '.*msg="\(.*\)"', '\1', '')
                let s:append_err =  substitute(s:append_err, '\\"', '"', 'g')
                if getline("$") != s:append_err
                    " call append(line("$"), s:append_err)
                    if neodbg_winnr != -1
                        call append(line("$"), s:append_err)
                    else
                        call add(g:append_messages, s:append_err)
                    endif
                endif
            " endif
        elseif debugger_line == g:neodbg_prompt
            if getline("$") != g:neodbg_prompt
                " call append(line("$"), debugger_line)
                    if neodbg_winnr != -1
                        call neodebug#GotoConsoleWindow()
                        call append(line("$"), debugger_line)
                    else
                        call add(g:append_messages, debugger_line)
                    endif
            endif
        endif

        "vim bug  on linux ?
        if s:isunix
            if debugger_line =~ '^\(\*stopped\)'
                " call append(line("$"), g:neodbg_prompt)
                if neodbg_winnr != -1
                    call append(line("$"), g:neodbg_prompt)
                else
                    call add(g:append_messages, g:neodbg_prompt)
                endif
            endif
        endif

        if neodbg_winnr != -1
            $
            starti!
            redraw
            if cur_mode != "i"
                stopi
            endif
        endif

        if debugger_line == g:neodbg_prompt && s:neodbg_init_flag == 0
            call win_gotoid(s:cur_wid)
        endif

    endif

endfunction

function! NeoDebugFoldTextExpr()
    return getline(v:foldstart) . ' ' . substitute(getline(v:foldstart+1), '\v^\s+', '', '') . ' ... (' . (v:foldend-v:foldstart-1) . ' lines)'
endfunction

" Show a balloon with information of the variable under the mouse pointer,
" if there is any.
function! NeoDebugBalloonExpr()
    if v:beval_winid != s:startwin
        return
    endif
    let s:evalFromBalloonExpr = 1
    let s:evalFromBalloonExprResult = ''
    let s:ignoreEvalError = 1
    call s:SendEval(v:beval_text)

    let output = ch_readraw(s:neodbg_chan)
    let alloutput = ''
    while output != g:neodbg_prompt
        let alloutput .= output
        let output = ch_readraw(s:neodbg_chan)
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

        let output = ch_readraw(s:neodbg_chan)
        let alloutput = ''
        while output != g:neodbg_prompt
            let alloutput .= output
            let output = ch_readraw(s:neodbg_chan)
        endw

        let value = substitute(alloutput, '.*value="\(.*\)"', '\1', '')
        let value = substitute(value, '\\"', '"', 'g')
        let value = substitute(value, '\\n\s*', '', 'g')

        let s:evalFromBalloonExprResult .= ' ' . value

    endif

    " for neodebug#GotoConsoleWindow to display also
    if g:neodbg_ballonshow_with_print == 1
        call NeoDebugSendCommand('p '. v:beval_text)
        call NeoDebugSendCommand('p '. s:evalexpr)
    endif

    return s:evalFromBalloonExprResult

endfunction

function! NeoDebugExprEval(expr)
    let s:evalForExprResult = ''
    " call s:SendEval(a:expr)
    call NeoDebugSendCommand('-data-evaluate-expression "' . a:expr . '"', 'u')
    let s:evalexpr = a:expr

    let alloutput = ''
    let output = ch_readraw(s:neodbg_chan)
    while 1
        if output  =~ '^\^done,value=' || output =~ '^\^error,msg='
            break
        endif
        let output = ch_readraw(s:neodbg_chan)
    endw

    let alloutput = output
    while output != g:neodbg_prompt
        let alloutput .= output
        let output = ch_readraw(s:neodbg_chan)
    endw
    " echomsg "output".output
    " echomsg "alloutput".alloutput
    let value = ''
    if alloutput =~ '^\^error,msg='
        let value = '--N/A--'
    else
        let value = substitute(alloutput, '.*value="\(.*\)"', '\1', '')
        let value = substitute(value, '\\"', '"', 'g')
        let value = substitute(value, '\\n\s*', '', 'g')
    endif

    if s:evalForExprResult == ''
       let s:evalForExprResult =  value
    else
       let s:evalForExprResult .= ' = ' . value
    endif

    "if s:evalForExprResult == ''
    "    let s:evalForExprResult = s:evalexpr . ': ' . value
    "else
    "    let s:evalForExprResult .= ' = ' . value
    "endif

    "if s:evalexpr[0] != '*' && value =~ '^0x' && value != '0x0' && value !~ '"$'
    "    " Looks like a pointer, also display what it points to.
    "    let s:ignoreEvalError = 1
    "    call s:SendEval('*' . s:evalexpr)

    "    let output = ch_readraw(s:neodbg_chan)
    "    let alloutput = ''
    "    while output != g:neodbg_prompt
    "        let alloutput .= output
    "        let output = ch_readraw(s:neodbg_chan)
    "    endw

    "    let value = substitute(alloutput, '.*value="\(.*\)"', '\1', '')
    "    let value = substitute(value, '\\"', '"', 'g')
    "    let value = substitute(value, '\\n\s*', '', 'g')

    "    let s:evalForExprResult .= ' ' . value

    "endif

    return s:evalForExprResult

endfunction

let g:exprs_value_lines = []
function! NeoDebugExprPrint(expr)
    let s:evalForExprResult = ''
    " call s:SendEval(a:expr)
    call NeoDebugSendCommand('print ' . a:expr, 'u')
    let s:evalexpr = a:expr

    let output = ch_readraw(s:neodbg_chan)
    while 1
        " if output  =~ '^\^done,value=' || output =~ '^\^error,msg='
        if output  =~ '^&"print '
            break
        endif
        let output = ch_readraw(s:neodbg_chan)
    endw

    let value = 1
    let s:value_line = ''
    let output = ch_readraw(s:neodbg_chan)
    while output != g:neodbg_prompt
        " echomsg "output".output
        if output =~ '\^error,msg='
            let value = 0
        endif
        let output = substitute(output, '\~"\\t', "\~\"\t\t", 'g')
        let output = substitute(output, ':\\t', ":\t\t", 'g')
        let output = substitute(output, '\\"', '"', 'g')
        let output = substitute(output, '\\\\', '\\', 'g')
        let s:value_line .= strpart(output, 2, strlen(output)-3)
        if output =~ '\\n"\_$'
            let s:value_line = substitute(s:value_line, '\\n\|\\032\\032', '', 'g')
            call add(g:exprs_value_lines, s:value_line)
            let s:value_line = ''
        endif
        let output = ch_readraw(s:neodbg_chan)
    endw

    " echomsg "output".output
    " if !empty(g:exprs_value_lines)
        " for m in g:exprs_value_lines
            " echomsg "m".m
        " endfor
    " endif

    return value

    " if s:evalForExprResult == ''
       " let s:evalForExprResult =  value
    " else
       " let s:evalForExprResult .= ' = ' . value
    " endif

    "if s:evalForExprResult == ''
    "    let s:evalForExprResult = s:evalexpr . ': ' . value
    "else
    "    let s:evalForExprResult .= ' = ' . value
    "endif

    "if s:evalexpr[0] != '*' && value =~ '^0x' && value != '0x0' && value !~ '"$'
    "    " Looks like a pointer, also display what it points to.
    "    let s:ignoreEvalError = 1
    "    call s:SendEval('*' . s:evalexpr)

    "    let output = ch_readraw(s:neodbg_chan)
    "    let alloutput = ''
    "    while output != g:neodbg_prompt
    "        let alloutput .= output
    "        let output = ch_readraw(s:neodbg_chan)
    "    endw

    "    let value = substitute(alloutput, '.*value="\(.*\)"', '\1', '')
    "    let value = substitute(value, '\\"', '"', 'g')
    "    let value = substitute(value, '\\n\s*', '', 'g')

    "    let s:evalForExprResult .= ' ' . value

    "endif

    " return s:evalForExprResult

endfunction


let s:neodbg_complete_flag = 0
function! NeoDebugComplete(findstart, base)

    if a:findstart

        let usercmd = getline('.')
        if g:neodbg_debugger == 'gdb' && usercmd =~ '^\s*(gdb)' 
            let usercmd = substitute(usercmd, '^\s*(gdb)\s*', '', '')
            let usercmd = substitute(usercmd, '*', '', '') "fixed *pointer
            let usercmd = 'complete ' .  usercmd
        endif

        call NeoDebugSendCommand(usercmd)

        let output = ch_readraw(s:neodbg_chan)
        let s:completers = []
        while output != g:neodbg_prompt
            if output =~ '\~"' 
                let completer = strpart(output, 2, strlen(output)-5) 
                call add(s:completers, completer)
            endif
            let output = ch_readraw(s:neodbg_chan)
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

let s:neodbg_match = []
function! s:NeoDebugMatch(expr, pat)
    let s:neodbg_match = matchlist(a:expr, a:pat)
    return len(s:neodbg_match) >0
endfunction
" if the value is a pointer ( var = 0x...), expand it by "NeoDebug p *var"
" e.g. $11 = (CDBMEnv *) 0x387f6d0
" e.g.  
" (CDBMEnv) $22 = {
"  m_pTempTables = 0x37c6830,
"  ...
" }
function! NeoDebugExpandPointerExpr()
    if ! s:NeoDebugMatch(getline('.'), '\v((\$|\w)+) \=.{-0,} 0x')
        return 0
    endif
    let cmd = s:neodbg_match[1]
    let lastln = line('.')
    while 1
        normal [z
        if line('.') == lastln
            break
        endif
        let lastln = line('.')

        if ! s:NeoDebugMatch(getline('.'), '\v(([<>$]|\w)+) \=')
            return 0
        endif
        " '<...>' means the base class. Just ignore it. Example:
        " (OBserverDBMCInterface) $4 = {
        "   <__DBMC_ObserverA> = {
        "     members of __DBMC_ObserverA:
        "     m_pEnv = 0x378de60
        "   }, <No data fields>}

        if s:neodbg_match[1][0:0] != '<' 
            let cmd = s:neodbg_match[1] . '.' . cmd
        endif
    endwhile 
    call NeoDebugSendCommand("p *" . cmd)
    if foldlevel('.') > 0
        " goto beginning of the fold and close it
        normal [zzc
        " ensure all folds for this var are closed
        foldclose!
    endif
    return 1
endfunction

" Delete installed debugger commands in the current window.
function! NeoDebugRestoreCommandsShotcut()
    call neodebug#DeleteCommand()
    call neodebug#DeleteMenu()
    call neodebug#DeleteWinbar()
    call neodebug#DeletePopupMenu()

    exe 'sign unplace ' . s:pc_id
    for key in keys(s:breakpoints)
        exe 'sign unplace ' . (s:break_id + key)
    endfor

    call  neodebug#UnsetWindowSytaxHilight()

    "unlet s:breakpoints

    call neodebug#DeleteShotcut()

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
endfunction

" :Next, :Continue, etc - send a command to debugger
let s:neodbg_quitted = 0
let s:neodbg_sendcmd_flag = 0
let s:usercmd = ''

function! NeoDebugSendCommand(cmd, ...)  " [mode]
    if g:neodbg_debuginfo == 1
        echomsg "<GDB>cmd:[".a:cmd."]"
    endif
    let usercmd = a:cmd
    let mode = a:0>0 ? a:1 : ''
    let s:mode = mode

    if  mode == 'u'  ||  -1 != match(usercmd, '^complete')
        if g:neodbg_debuginfo == 1
            echomsg "<GDB1>:[".usercmd."][mode:".mode."]"
        endif
        let s:neodbg_sendcmd_flag = 0
    else
        "save commands 
        if usercmd != s:neodbg_cmd_historys[-1] && usercmd != ''
            if g:neodbg_debuginfo == 1
                echomsg "<GDB2>:[".usercmd."][mode:".mode."]"
            endif
            call add(s:neodbg_cmd_historys, usercmd)
        endif

        "whether print command in console command line
        if mode == '' && s:neodbg_init_flag == 0
            let s:neodbg_sendcmd_flag = 1
        endif

        if usercmd == '' && mode == 'i'
            let usercmd = s:neodbg_cmd_historys[-1]
            let s:neodbg_sendcmd_flag = 1
        elseif usercmd == s:neodbg_cmd_historys[-1] && mode == 'i'
            let s:neodbg_sendcmd_flag = 0
        endif

    endif

    if g:neodbg_debuginfo == 1
        silent echohl ModeMsg
        echomsg "<GDB>:[".usercmd."][mode:".mode."]"
        silent echohl None
    endif
    let s:usercmd = usercmd
    if has('nvim')
        call jobsend(s:nvim_commjob, usercmd . "\n")
    else
        call ch_sendraw(s:commjob, usercmd . "\n")
    endif
    if usercmd == 'q'
        let  s:neodbg_quitted = 1
    endif
endfunction

function! s:SendKey(key)
    if has('nvim')
        call jobsend(s:nvim_commjob, a:key)
    else
        call ch_sendraw(s:commjob, a:key)
    endif
endfunction

function! s:SendEval(expr)
    call NeoDebugSendCommand('-data-evaluate-expression "' . a:expr . '"')
    let s:evalexpr = a:expr
endfunction

function! s:PlaceSign(nr, entry)
    exe 'sign place ' . (s:break_id + a:nr) . ' line=' . a:entry['lnum'] . ' name=NeoDebugBP file=' . a:entry['fname']
    let a:entry['placed'] = 1
endfunction

" Handle a BufRead autocommand event: place any signs.
function! s:BufferRead()
    let fname = expand('<afile>:p')
    " let fname = fnamemodify(expand('<afile>:t'), ":p")
    " echomsg "BufferRead:".fname
    for [nr, entry] in items(s:breakpoints)
        if entry['fname'] == fname
            call s:PlaceSign(nr, entry)
        endif
    endfor
endfunction

" Handle a BufUnload autocommand event: unplace any signs.
function! s:BufferUnload()
    let fname = expand('<afile>:p')
    " let fname = fnamemodify(expand('<afile>:t'), ":p")
    " echomsg "BufferUnload:".fname
    for [nr, entry] in items(s:breakpoints)
        if entry['fname'] == fname
            let entry['placed'] = 0
        endif
    endfor
endfunction


function! NeoDebugSetBreakpoint()
    " Setting a breakpoint may not work while the program is running.
    " Interrupt to make it work.
    let do_continue = 0
    if !s:stopped
        let do_continue = 1
        call NeoDebugSendCommand('-exec-interrupt')
        sleep 10m
    endif
    " call NeoDebugSendCommand('-break-insert '
    " \ . fnameescape(expand('%:p')) . ':' . line('.'))
    call NeoDebugSendCommand('break '
                \ . fnameescape(expand('%:p')) . ':' . line('.'))
    if do_continue
        call NeoDebugSendCommand('-exec-continue')
    endif
endfunction

function! NeoDebugClearBreakpoint()
    call win_gotoid(s:startwin)
    let fname = fnameescape(expand('%:p'))
    let lnum = line('.')
    " echomsg "ClearBreakpoint:fname:lnum".fname.":".lnum
    for [key, val] in items(s:breakpoints)
        if val['fname'] == fname && val['lnum'] == lnum
            " echomsg "val[fname]:lnum".val['fname'].":".val['lnum'].":".key
            call NeoDebugSendCommand('delete ' . key)
            " call ch_sendraw(s:commjob, '-break-delete ' . key . "\n")
            " call ch_sendraw(s:commjob, '-break-disable ' . key . "\n")
            " Assume this always wors, the reply is simply "^done".
            exe 'sign unplace ' . (s:break_id + key)
            unlet s:breakpoints[key]
            break
        endif
    endfor
endfunction

function! NeoDebugToggleBreakpoint()
    call win_gotoid(s:startwin)
    let fname = fnameescape(expand('%:p'))
    let lnum = line('.')
    " echomsg "ToggleBreakpoint:fname:lnum".fname.":".lnum

    for [key, val] in items(s:breakpoints)
        if val['fname'] == fname && val['lnum'] == lnum
            " echomsg "val[fname]:lnum".val['fname'].":".val['lnum'].":".key
            " call ch_sendraw(s:commjob, 'delete ' . key . "\n")
            call NeoDebugSendCommand('delete ' . key)
            " Assume this always wors, the reply is simply "^done".
            exe 'sign unplace ' . (s:break_id + key)
            unlet s:breakpoints[key]
            return
        endif
    endfor
    call NeoDebugSetBreakpoint()
endfunction

function! NeoDebugRun(args)
    if a:args != ''
        call NeoDebugSendCommand('-exec-arguments ' . a:args)
    endif
    call NeoDebugSendCommand('-exec-run')
endfunction

function! NeoDebugEvaluate(range, arg)
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
endfunction

let s:ignoreEvalError = 0
let s:evalFromBalloonExpr = 0

" Handle the result of data-evaluate-expression
function! s:HandleEvaluate(msg)
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
endfunction


" Handle an error.
function! s:HandleError(msg)
    " call s:SendEval(v:beval_text)
    if s:ignoreEvalError
        " Result of s:SendEval() failed, ignore.
        let s:ignoreEvalError = 0
        let s:evalFromBalloonExpr = 0
        return
    endif
    " echoerr substitute(a:msg, '.*msg="\(.*\)"', '\1', '')
endfunction

" Handle stopping and running message from debugger.
" Will update the sign that shows the current position.
function! s:HandleCursor(msg)
    let wid = win_getid(winnr())

    if a:msg =~ '\*stopped'
        let s:stopped = 1
    elseif a:msg =~ '\*running'
        let s:stopped = 0
    endif
    if a:msg =~ '\(\*stopped,reason="breakpoint-hit"\)'
        " call  neodebug#UpdateBreakpoints()
    endif

    if a:msg =~ '\(\*stopped\)'
        "first for locals windows cant refresh
        call neodebug#UpdateExpressions()

        call neodebug#UpdateLocals()
        call neodebug#UpdateRegisters()
        call neodebug#UpdateStackFrames()
        call neodebug#UpdateThreads()
        call neodebug#UpdateDisas()
    endif

    if win_gotoid(s:startwin)
        let fname = substitute(a:msg, '.*fullname="\([^"]*\)".*', '\1', '')
        " let fname = fnamemodify(fnamemodify(fname, ":t"), ":p")
        "fix mswin
        " echomsg "HandleCursor:fname:".fname
        if -1 == match(fname, '\\\\')
            let fname = fname
        else
            let fname = substitute(fname, '\\\\','\\', 'g')
        endif
        " echomsg "HandleCursor:fname:".fname

        if a:msg =~ '\(\*stopped\|=thread-selected\|new-thread-id=\)' && filereadable(fname)
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
                " echomsg "HandleCursor:fname:lnum=".fname.':'.lnum
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
endfunction

" Handle setting a breakpoint
" Will update the sign that shows the breakpoint
function! s:HandleNewBreakpoint(msg)
    call neodebug#UpdateWatchpoints()
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


    " let fname = fnamemodify(fnamemodify(fname, ":t"), ":p")
    " echomsg "fname:".fname
    " echomsg "lnum:".lnum

    " fix mswin
    " echomsg "HandleCursor:fname:".fname
    if -1 == match(fname, '\\\\')
        let fname = fname
    else
        let fname = substitute(fname, '\\\\','\\', 'g')
    endif
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
        echomsg "NeoDebug: No write since last change (add ! to override)"
        silent echohl None
    catch /^Vim\%((\a\+)\)\=:E325/
        " TODO ask 
        silent echohl ModeMsg
        echomsg "NeoDebug: Found a swap file."
        silent echohl None
    endtry

    if bufloaded(fname)
        call s:PlaceSign(nr, entry)
    endif
    redraw

    call neodebug#UpdateBreakpoints()
endfunction

" Handle deleting a breakpoint
" Will remove the sign that shows the breakpoint
function! s:HandleBreakpointDelete(msg)
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

    if s:neodbg_quitted != 1
        call neodebug#UpdateWatchpoints()
    endif
    call neodebug#UpdateBreakpoints()
endfunction

" TODO 
function! s:NeoDebug_bpkey(file, line)
    return a:file . ":" . a:line
endfunction

function! s:NeoDebugGotoFile(fname, lnum)
    let fname = a:fname
    let lnum  = a:lnum
    let wid = win_getid(winnr())

    if win_gotoid(s:startwin)
        let fname = fnamemodify(fnamemodify(fname, ":t"), ":p")

        if filereadable(fname)
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
                exe lnum
                exe 'sign unplace ' . s:pc_id
                exe 'sign place ' . s:pc_id . ' line=' . lnum . ' name=NeoDebugPC file=' . fname
                setlocal signcolumn=yes
            else
                exe 'sign unplace ' . s:pc_id
            endif
        endif

        call win_gotoid(wid)
    endif
endfunction

function! s:CursorPos()
    let file = expand("%:t")
    let line = line(".")
    return s:NeoDebug_bpkey(file, line)
endfunction

function! NeoDebugJump()
    call win_gotoid(s:startwin)
    let key = s:CursorPos()
    "	call NeoDebug("@tb ".key." ; ju ".key)
    "	call NeoDebug("set $rbp1=$rbp; set $rsp1=$rsp; @tb ".key." ; ju ".key . "; set $rsp=$rsp1; set $rbp=$rbp1")
    call NeoDebug("ju ".key)
endfunction

function! NeoDebugRunToCursor()
    call win_gotoid(s:startwin)
    let key = s:CursorPos()
    call NeoDebug("tb ".key)
    call NeoDebug("c")
endfunction

function! NeoDebugGotoStartWin()
    call win_gotoid(s:startwin)
endfunction

command! -nargs=* -complete=file NeoDebug :call NeoDebug(<q-args>)
command! -nargs=* -complete=file NeoDebugStop :call NeoDebugStop(<q-args>)

execute printf('command! %s%s call neodebug#ToggleConsoleWindow()    ', g:neodbg_cmd_prefix, 'ToggleConsole')
execute printf('command! %s%s call neodebug#UpdateConsoleWindow()    ', g:neodbg_cmd_prefix, 'OpenConsole')
execute printf('command! %s%s call neodebug#UpdateLocalsWindow()     ', g:neodbg_cmd_prefix, 'OpenLocals')
execute printf('command! %s%s call neodebug#UpdateRegistersWindow()  ', g:neodbg_cmd_prefix, 'OpenRegisters')
execute printf('command! %s%s call neodebug#UpdateStackFramesWindow()', g:neodbg_cmd_prefix, 'OpenStacks')
execute printf('command! %s%s call neodebug#UpdateThreadsWindow()    ', g:neodbg_cmd_prefix, 'OpenThreads')
execute printf('command! %s%s call neodebug#UpdateBreakpointsWindow()', g:neodbg_cmd_prefix, 'OpenBreaks')
execute printf('command! %s%s call neodebug#UpdateDisasWindow()      ', g:neodbg_cmd_prefix, 'OpenDisas')
execute printf('command! %s%s call neodebug#UpdateExpressionsWindow()', g:neodbg_cmd_prefix, 'OpenExpressions')
execute printf('command! %s%s call neodebug#UpdateWatchpointsWindow()', g:neodbg_cmd_prefix, 'OpenWatchs')
execute printf('command! %s%s call neodebug#CloseConsole()           ', g:neodbg_cmd_prefix, 'CloseConsole')
execute printf('command! %s%s call neodebug#CloseLocals()            ', g:neodbg_cmd_prefix, 'CloseLocals')
execute printf('command! %s%s call neodebug#CloseRegisters()         ', g:neodbg_cmd_prefix, 'CloseRegisters')
execute printf('command! %s%s call neodebug#CloseStackFrames()       ', g:neodbg_cmd_prefix, 'CloseStacks')
execute printf('command! %s%s call neodebug#CloseThreads()           ', g:neodbg_cmd_prefix, 'CloseThreads')
execute printf('command! %s%s call neodebug#CloseBreakpoints()       ', g:neodbg_cmd_prefix, 'CloseBreaks')
execute printf('command! %s%s call neodebug#CloseDisas()             ', g:neodbg_cmd_prefix, 'CloseDisas')
execute printf('command! %s%s call neodebug#CloseExpressions()       ', g:neodbg_cmd_prefix, 'CloseExpressions')
execute printf('command! %s%s call neodebug#CloseWatchpoints()       ', g:neodbg_cmd_prefix, 'CloseWatchs')

" vim: set foldmethod=marker 
