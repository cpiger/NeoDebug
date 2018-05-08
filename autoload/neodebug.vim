"""""""""""""""""""""""""""""""""""""""""""""""""""""""
" NeoDebug - NeoDebug 
" Console
" Locals / Registers
" StackFrame / Threads
" Breakpoints / Disassemble
" Expressions / Watchpoints
" Maintainer: scott (cpiger@qq.com)
"
"""""""""""""""""""""""""""""""""""""""""""""""""""""""
let s:help_open = 1
let s:help_text_short = [
			\ '" Press ? for help',
			\ ]

let s:help_text = s:help_text_short

" \ '<C-F9> 	- toggle enable/disable breakpoint on current line',
function s:UpdateHelpText()
    if s:help_open
        let s:help_text = [
            \ '<F5> 	- run or continue (c)',
            \ '<S-F5> 	- stop debugging (kill)',
            \ '<F6> 	- toggle console window',
            \ '<F10> 	- next',
            \ '<F11> 	- step into',
            \ '<S-F11>  - step out (finish)',
            \ '<C-F10>	- run to cursor (tb and c)',
            \ '<F9> 	- toggle breakpoint on current line',
            \ '\ju or <C-S-F10> - set next statement (tb and jump)',
            \ '<C-P>    - view variable under the cursor (.p)',
            \ '<TAB>    - trigger complete ',
            \ '<C-C>    - terminate debugger job',
            \ ]
    else
        let s:help_text = s:help_text_short
    endif
endfunction

function neodebug#ToggleHelp()
    if !g:neodbg_enable_help
        return
    endif

    let s:help_open = !s:help_open
    silent exec '1,' . len(s:help_text) . 'd _'
    call s:UpdateHelpText()
    silent call append( 0, s:help_text )
    silent keepjumps normal! gg
endfunction

" NOTE: this function will be called by neodbg script.
function! neodebug#OpenConsole()

    call neodebug#OpenConsoleWindow()

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

    call neodebug#InstallCommandsShotcut()


    starti!
    " call cursor(0, 7)
    if has('nvim')
        "not implement
    else
        setl completefunc=NeoDebugComplete
    endif

endfunction
" Get ready for communication
function! neodebug#OpenConsoleWindow(...)
    let para = a:0>0 ? a:1 : 'v'
    let bufnum = bufnr(g:neodbg_console_name)

    if bufnum == -1
        " Create a new buffer
        let wcmd = g:neodbg_console_name
    else
        " Edit the existing buffer
        let wcmd = '+buffer' . bufnum
    endif

    " Create the tag explorer window
    if para == 'v'
    exe 'silent!  botright ' . g:neodbg_console_height . 'split ' . wcmd
    elseif para == 'h'
        exe 'silent! bel ' . g:neodbg_console_height. 'split ' . wcmd
    endif
    if line('$') <= 1 && g:neodbg_enable_help
        silent call append ( 0, s:help_text )
    endif
    call neodebug#InstallWinbar()
endfunction

function neodebug#CloseConsole()
    " let g:neodbg_openconsole_default = 0
    call neodebug#CloseConsoleWindow()
endfunction

function neodebug#CloseConsoleWindow()
    let winnr = bufwinnr(g:neodbg_console_name)
    if winnr != -1
        call neodebug#GotoConsoleWindow()
        let s:neodbg_save_console_cursor = getpos(".")
        close
        return 1
    endif
    return 0
endfunction

function neodebug#ToggleConsoleWindow()
    " if  g:neodbg_running == 0
        " return
    " endif
    let result = neodebug#CloseConsoleWindow()
    if result == 0
        " call neodebug#GotoConsoleWindow()
        call neodebug#UpdateConsoleWindow()
        " call setpos('.', s:neodbg_save_console_cursor)
    endif
endfunction

function! neodebug#GotoConsoleWindow()
    if bufname("%") == g:neodbg_console_name
        return
    endif
    let neodbg_winnr = bufwinnr(g:neodbg_console_name)
    if neodbg_winnr == -1
        " if multi-tab or the buffer is hidden
        call neodebug#OpenConsoleWindow('v')
        let neodbg_winnr = bufwinnr(g:neodbg_console_name)
    endif
    exec neodbg_winnr . "wincmd w"
endfunction

function s:GotoInput()
    " exec "InsertLeave"
    exec "normal G"
    starti!
endfunction

function! neodebug#CustomConsoleKey()
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
endfunction

function! s:IsModifiable()
    let pos = getpos(".")  
    let curline = pos[1]
    if  curline == line("$") && strpart(g:neodbg_prompt, 0, 5) == strpart(getline("."), 0, 5) && col(".") >= strlen(g:neodbg_prompt)
        return 1
    else
        return 0
    endif
endfunction

function! s:IsModifiablex()
    let pos = getpos(".")  
    let curline = pos[1]
    if  curline == line("$") && strpart(g:neodbg_prompt, 0, 5) == strpart(getline("."), 0, 5) && col(".") >= strlen(g:neodbg_prompt)+1
                \ || (curline == line("$") && ' >' == strpart(getline("."), 0, 2) && col(".") >= strlen(' >')+1)
        return 1
    else
        return 0
    endif
endfunction
function! s:IsModifiableX()
    let pos = getpos(".")  
    let curline = pos[1]
    if  (curline == line("$") && strpart(g:neodbg_prompt, 0, 5) == strpart(getline("."), 0, 5) && col(".") >= strlen(g:neodbg_prompt)+2)
                \ || (curline == line("$") && ' >' == strpart(getline("."), 0, 2) && col(".") >= strlen(' >')+2)
        return 1
    else
        return 0
    endif
endfunction
function! s:NeoDebugKeyi()
    let pos = getpos(".")  
    let curline = pos[1]
    let curcol = pos[2]
    if curline == line("$")
        if curcol >  strlen(g:neodbg_prompt)
            starti
        else
            starti!
        endif
    else
        silent call s:GotoInput()
    endif
endfunction

function! s:NeoDebugKeyI()
    let pos = getpos(".")  
    let curline = pos[1]
    let curcol = pos[2]
    if curline == line("$")
        let pos[2] = strlen(g:neodbg_prompt)+1
        call setpos(".", pos)
        starti
    else
        silent call s:GotoInput()
    endif
endfunction

function! s:NeoDebugKeya()
    let linecon = getline("$")
    let pos = getpos(".")  
    let curline = pos[1]
    let curcol = pos[2]
    if curline == line("$")
        if curcol >=  strlen(g:neodbg_prompt)
            if linecon == g:neodbg_prompt
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
endfunction

function! s:NeoDebugKeyA()
    let pos = getpos(".")  
    let curline = pos[1]
    let curcol = pos[2]
    if curline == line("$")
        starti!
    else
        silent call s:GotoInput()
    endif
endfunction

function s:NeoDebugKeyo()
    let linecon = getline("$")
    if linecon == g:neodbg_prompt
        exec "normal G"
        starti!
    else
        call append('$', g:neodbg_prompt)
        $
        starti!
    endif
endfunction

function s:NeoDebugKeyS()
    exec "normal G"
    exec "normal dd"
    call append('$', g:neodbg_prompt)
    $
    starti!
endfunction




function! neodebug#OpenLocals()

    call neodebug#OpenLocalsWindow()

    setlocal buftype=nofile
    setlocal complete=.
    setlocal noswapfile
    setlocal nowrap
    setlocal nobuflisted
    setlocal nonumber
    setlocal winfixwidth
    setlocal cursorline

    setlocal foldcolumn=2
    setlocal foldtext=NeoDebugFoldTextExpr()
    setlocal foldmarker={,}
    setlocal foldmethod=marker


    call neodebug#SetWindowSytaxHilight()

    nnoremap <buffer> <silent> <CR> :call NeoDebug(getline('.'), 'n')<cr>
    nmap <buffer> <silent> <2-LeftMouse> <cr>

endfunction
" Local window
let s:neodbg_locals_opened = 0
function! neodebug#OpenLocalsWindow(...)
    let para = a:0>0 ? a:1 : 'v'
    " call NeoDebugGotoStartWin()
    let s:neodbg_locals_opened = 1
    let bufnum = bufnr(g:neodbg_locals_name)

    if bufnum == -1
        " Create a new buffer
        let wcmd = g:neodbg_locals_name
    else
        " Edit the existing buffer
        let wcmd = '+buffer' . bufnum
    endif

    " Create the tag explorer window
    if para == 'v'
        exe 'silent!  botright ' . g:neodbg_locals_width. 'vsplit ' . wcmd
    elseif para == 'h'
        exe 'silent!  ' . g:neodbg_locals_height. 'split ' . wcmd
    endif
    nnoremenu WinBar.Locals/Registers   :call neodebug#UpdateLocalsOrRegisters()<CR>
endfunction

function neodebug#CloseLocals()
    let g:neodbg_openlocals_default = 0
    call  neodebug#CloseLocalsWindow()
endfunction

function neodebug#CloseLocalsWindow()
    let winnr = bufwinnr(g:neodbg_locals_name)
    if winnr != -1
        call neodebug#GotoLocalsWindow()
        let s:neodbg_save_local_cursor = getpos(".")
        close
        let s:neodbg_locals_opened = 0
        return 1
    endif
    let s:neodbg_locals_opened = 0
    return 0
endfunction

function! neodebug#GotoLocalsWindow()
    if bufname("%") == g:neodbg_locals_name
        return
    endif
    let neodbg_winnr = bufwinnr(g:neodbg_locals_name)
    let neodbg_winnr_register = bufwinnr(g:neodbg_registers_name)

    let neodbg_winnr_stack = bufwinnr(g:neodbg_stackframes_name)
    let neodbg_winnr_thread = bufwinnr(g:neodbg_threads_name)

    let neodbg_winnr_break = bufwinnr(g:neodbg_breakpoints_name)
    let neodbg_winnr_disas = bufwinnr(g:neodbg_disas_name)

    let neodbg_winnr_expr = bufwinnr(g:neodbg_expressions_name)
    let neodbg_winnr_watch = bufwinnr(g:neodbg_watchpoints_name)

    if neodbg_winnr == -1
        if neodbg_winnr_register == -1
            " if multi-tab or the buffer is hidden
            if neodbg_winnr_stack != -1
                call neodebug#GotoStackFramesWindow()
                call neodebug#OpenLocalsWindow('h')
            elseif neodbg_winnr_thread != -1
                call neodebug#GotoThreadsWindow()
                call neodebug#OpenLocalsWindow('h')
            elseif neodbg_winnr_break != -1
                call neodebug#GotoBreakpointsWindow()
                call neodebug#OpenLocalsWindow('h')
            elseif neodbg_winnr_disas != -1
                call neodebug#GotoDisasWindow()
                call neodebug#OpenLocalsWindow('h')
            elseif neodbg_winnr_expr != -1
                call neodebug#GotoExpressionsWindow()
                call neodebug#OpenLocalsWindow('h')
            elseif neodbg_winnr_watch != -1
                call neodebug#GotoWatchpointsWindow()
                call neodebug#OpenLocalsWindow('h')
            else
                call neodebug#OpenLocals()
            endif

            let neodbg_winnr = bufwinnr(g:neodbg_locals_name)

        else
            call neodebug#GotoRegistersWindow()
            let bufnum = bufnr(g:neodbg_locals_name)
            exec "b ". bufnum
            let neodbg_winnr = bufwinnr(g:neodbg_locals_name)
        endif
    endif
    exec neodbg_winnr . "wincmd w"
    " exec "wincmd ="
endfunction

function! neodebug#OpenRegisters()

    call neodebug#OpenRegistersWindow()

    setlocal buftype=nofile
    setlocal complete=.
    setlocal noswapfile
    setlocal nowrap
    setlocal nobuflisted
    setlocal nonumber
    setlocal winfixwidth
    setlocal cursorline

    setlocal foldcolumn=2
    setlocal foldmarker={,}
    setlocal foldmethod=marker

    call neodebug#SetWindowSytaxHilight()

    nnoremap <buffer> <silent> <CR> :call NeoDebug(getline('.'), 'n')<cr>
    nmap <buffer> <silent> <2-LeftMouse> <cr>

endfunction

" Registers window
function! neodebug#OpenRegistersWindow(...)
    let para = a:0>0 ? a:1 : 'v'
    let bufnum = bufnr(g:neodbg_registers_name)

    if bufnum == -1
        " Create a new buffer
        let wcmd = g:neodbg_registers_name
    else
        " Edit the existing buffer
        let wcmd = '+buffer' . bufnum
    endif

    " Create the tag explorer window
    if para == 'v'
        exe 'silent!  botright ' . g:neodbg_registers_width. 'vsplit ' . wcmd
    elseif para == 'h'
        exe 'silent!  ' . g:neodbg_registers_height. 'split ' . wcmd
    endif
    " exe 'silent!  ' . g:neodbg_registers_height. 'split ' . wcmd
    nnoremenu WinBar.Locals/Registers   :call neodebug#UpdateLocalsOrRegisters()<CR>
endfunction

function neodebug#CloseRegisters()
    let g:neodbg_openregisters_default = 0
    call neodebug#CloseRegistersWindow()
endfunction
function neodebug#CloseRegistersWindow()
    let winnr = bufwinnr(g:neodbg_registers_name)
    if winnr != -1
        call neodebug#GotoRegistersWindow()
        let s:neodbg_save_register_cursor = getpos(".")
        close
        return 1
    endif
    return 0
endfunction

function! neodebug#GotoRegistersWindow()
    if bufname("%") == g:neodbg_registers_name
        return
    endif
    let neodbg_winnr = bufwinnr(g:neodbg_registers_name)
    let neodbg_winnr_local = bufwinnr(g:neodbg_locals_name)

    let neodbg_winnr_stack = bufwinnr(g:neodbg_stackframes_name)
    let neodbg_winnr_thread = bufwinnr(g:neodbg_threads_name)

    let neodbg_winnr_break = bufwinnr(g:neodbg_breakpoints_name)
    let neodbg_winnr_disas = bufwinnr(g:neodbg_disas_name)

    let neodbg_winnr_expr = bufwinnr(g:neodbg_expressions_name)
    let neodbg_winnr_watch = bufwinnr(g:neodbg_watchpoints_name)

    if neodbg_winnr == -1

        if neodbg_winnr_local == -1
            " if multi-tab or the buffer is hidden
            if neodbg_winnr_stack != -1
                call neodebug#GotoStackFramesWindow()
                call neodebug#OpenRegistersWindow('h')
            elseif neodbg_winnr_thread != -1
                call neodebug#GotoThreadsWindow()
                call neodebug#OpenRegistersWindow('h')
            elseif neodbg_winnr_break != -1
                call neodebug#GotoBreakpointsWindow()
                call neodebug#OpenRegistersWindow('h')
            elseif neodbg_winnr_disas != -1
                call neodebug#GotoDisasWindow()
                call neodebug#OpenRegistersWindow('h')
            elseif neodbg_winnr_expr != -1
                call neodebug#GotoExpressionsWindow()
                call neodebug#OpenRegistersWindow('h')
            elseif neodbg_winnr_watch != -1
                call neodebug#GotoWatchpointsWindow()
                call neodebug#OpenRegistersWindow('h')
            else
                call neodebug#OpenRegisters()
            endif
            let neodbg_winnr = bufwinnr(g:neodbg_registers_name)

        else
            call neodebug#GotoLocalsWindow()
            let bufnum = bufnr(g:neodbg_registers_name)
            exec "b ". bufnum
            let neodbg_winnr = bufwinnr(g:neodbg_registers_name)
        endif
    endif
    exec neodbg_winnr . "wincmd w"
    " exec "wincmd ="
endfunction


function! neodebug#OpenStackFrames()

    call neodebug#OpenStackFramesWindow()

    setlocal buftype=nofile
    setlocal complete=.
    setlocal noswapfile
    setlocal nowrap
    setlocal nobuflisted
    setlocal nonumber
    setlocal winfixwidth
    setlocal cursorline

    setlocal foldcolumn=2
    setlocal foldmarker={,}
    setlocal foldmethod=marker


    call neodebug#SetWindowSytaxHilight()

    nnoremap <buffer> <silent> <CR> :call NeoDebug(getline('.'), 'n')<cr>
    nmap <buffer> <silent> <2-LeftMouse> <cr>

endfunction

" StackFrames window
function! neodebug#OpenStackFramesWindow(...)
    let para = a:0>0 ? a:1 : 'v'
    " call NeoDebugGotoStartWin()

    let bufnum = bufnr(g:neodbg_stackframes_name)

    if bufnum == -1
        " Create a new buffer
        let wcmd = g:neodbg_stackframes_name
    else
        " Edit the existing buffer
        let wcmd = '+buffer' . bufnum
    endif

    " Create the tag explorer window
    if para == 'v'
        exe 'silent!  botright ' . g:neodbg_stackframes_width. 'vsplit ' . wcmd
    elseif para == 'h'
        exe 'silent!  ' . g:neodbg_stackframes_height. 'split ' . wcmd
    endif
    " exe 'silent!  ' . g:neodbg_stackframes_height. 'split ' . wcmd
    nnoremenu WinBar.StackFrames/Threads   :call neodebug#UpdateStackOrThreads()<CR>
endfunction

function neodebug#CloseStackFrames()
    let g:neodbg_openstacks_default = 0
    call neodebug#CloseStackFramesWindow()
endfunction

function neodebug#CloseStackFramesWindow()
    let winnr = bufwinnr(g:neodbg_stackframes_name)
    if winnr != -1
        call neodebug#GotoStackFramesWindow()
        let s:neodbg_save_stack_cursor = getpos(".")
        close
        return 1
    endif
    return 0
endfunction

function! neodebug#GotoStackFramesWindow()
    if bufname("%") == g:neodbg_stackframes_name
        return
    endif
    let neodbg_winnr = bufwinnr(g:neodbg_stackframes_name)
    let neodbg_winnr_thread = bufwinnr(g:neodbg_threads_name)

    let neodbg_winnr_register = bufwinnr(g:neodbg_registers_name)
    let neodbg_winnr_local = bufwinnr(g:neodbg_locals_name)

    let neodbg_winnr_break = bufwinnr(g:neodbg_breakpoints_name)
    let neodbg_winnr_disas = bufwinnr(g:neodbg_disas_name)

    let neodbg_winnr_expr = bufwinnr(g:neodbg_expressions_name)
    let neodbg_winnr_watch = bufwinnr(g:neodbg_watchpoints_name)

    if neodbg_winnr == -1
        if neodbg_winnr_thread == -1
            " if multi-tab or the buffer is hidden
            if neodbg_winnr_local != -1
                call neodebug#GotoLocalsWindow()
                call neodebug#OpenStackFramesWindow('h')
            elseif neodbg_winnr_register != -1
                call neodebug#GotoRegistersWindow()
                call neodebug#OpenStackFramesWindow('h')
            elseif neodbg_winnr_break != -1
                call neodebug#GotoBreakpointsWindow()
                call neodebug#OpenStackFramesWindow('h')
            elseif neodbg_winnr_disas != -1
                call neodebug#GotoDisasWindow()
                call neodebug#OpenStackFramesWindow('h')
            elseif neodbg_winnr_expr != -1
                call neodebug#GotoExpressionsWindow()
                call neodebug#OpenStackFramesWindow('h')
            elseif neodbg_winnr_watch != -1
                call neodebug#GotoWatchpointsWindow()
                call neodebug#OpenStackFramesWindow('h')
            else
                call neodebug#OpenStackFrames()
            endif

            let neodbg_winnr = bufwinnr(g:neodbg_stackframes_name)
        else
            call neodebug#GotoThreadsWindow()
            let bufnum = bufnr(g:neodbg_stackframes_name)
            exec "b ". bufnum
            let neodbg_winnr = bufwinnr(g:neodbg_stackframes_name)
        endif
    endif
    exec neodbg_winnr . "wincmd w"
    " exec "wincmd ="
endfunction


function! neodebug#OpenThreads()

    call neodebug#OpenThreadsWindow()

    setlocal buftype=nofile
    setlocal complete=.
    setlocal noswapfile
    setlocal nowrap
    setlocal nobuflisted
    setlocal nonumber
    setlocal winfixwidth
    setlocal cursorline

    setlocal foldcolumn=2
    setlocal foldmarker={,}
    setlocal foldmethod=marker

    call neodebug#SetWindowSytaxHilight()

    nnoremap <buffer> <silent> <CR> :call NeoDebug(getline('.'), 'n')<cr>
    nmap <buffer> <silent> <2-LeftMouse> <cr>


endfunction
" Threads window
function! neodebug#OpenThreadsWindow(...)
    let para = a:0>0 ? a:1 : 'v'

    let bufnum = bufnr(g:neodbg_threads_name)

    if bufnum == -1
        " Create a new buffer
        let wcmd = g:neodbg_threads_name
    else
        " Edit the existing buffer
        let wcmd = '+buffer' . bufnum
    endif

    " Create the tag explorer window
    if para == 'v'
        exe 'silent!  botright ' . g:neodbg_threads_width. 'vsplit ' . wcmd
    elseif para == 'h'
        exe 'silent!  ' . g:neodbg_threads_height. 'split ' . wcmd
    endif
    " exe 'silent!  ' . g:neodbg_threads_height. 'split ' . wcmd
    nnoremenu WinBar.StackFrames/Threads   :call neodebug#UpdateStackOrThreads()<CR>
endfunction

function neodebug#CloseThreads()
    let g:neodbg_openthreads_default = 0
    call neodebug#CloseThreadsWindow()
endfunction
function neodebug#CloseThreadsWindow()
    let winnr = bufwinnr(g:neodbg_threads_name)
    if winnr != -1
        call neodebug#GotoThreadsWindow()
        let s:neodbg_save_thread_cursor = getpos(".")
        close
        return 1
    endif
    return 0
endfunction

function! neodebug#GotoThreadsWindow()
    if bufname("%") == g:neodbg_threads_name
        return
    endif
    let neodbg_winnr = bufwinnr(g:neodbg_threads_name)
    let neodbg_winnr_stack = bufwinnr(g:neodbg_stackframes_name)

    let neodbg_winnr_register = bufwinnr(g:neodbg_registers_name)
    let neodbg_winnr_local = bufwinnr(g:neodbg_locals_name)

    let neodbg_winnr_break = bufwinnr(g:neodbg_breakpoints_name)
    let neodbg_winnr_disas = bufwinnr(g:neodbg_disas_name)

    let neodbg_winnr_expr = bufwinnr(g:neodbg_expressions_name)
    let neodbg_winnr_watch = bufwinnr(g:neodbg_watchpoints_name)

    if neodbg_winnr == -1
        if neodbg_winnr_stack == -1
            " if multi-tab or the buffer is hidden
            if neodbg_winnr_local != -1
                call neodebug#GotoLocalsWindow()
                call neodebug#OpenThreadsWindow('h')
            elseif neodbg_winnr_register != -1
                call neodebug#GotoRegistersWindow()
                call neodebug#OpenThreadsWindow('h')
            elseif neodbg_winnr_break != -1
                call neodebug#GotoBreakpointsWindow()
                call neodebug#OpenThreadsWindow('h')
            elseif neodbg_winnr_disas != -1
                call neodebug#GotoDisasWindow()
                call neodebug#OpenThreadsWindow('h')
            elseif neodbg_winnr_expr != -1
                call neodebug#GotoExpressionsWindow()
                call neodebug#OpenThreadsWindow('h')
            elseif neodbg_winnr_watch != -1
                call neodebug#GotoWatchpointsWindow()
                call neodebug#OpenThreadsWindow('h')
            else
                call neodebug#OpenThreads()
            endif

            let neodbg_winnr = bufwinnr(g:neodbg_threads_name)

        else
            call neodebug#GotoStackFramesWindow()
            let bufnum = bufnr(g:neodbg_threads_name)
            exec "b ". bufnum
            let neodbg_winnr = bufwinnr(g:neodbg_threads_name)
        endif
    endif
    exec neodbg_winnr . "wincmd w"
    " exec "wincmd ="
endfunction

function! neodebug#OpenBreakpoints()

    call neodebug#OpenBreakpointsWindow()

    setlocal buftype=nofile
    setlocal complete=.
    setlocal noswapfile
    setlocal nowrap
    setlocal nobuflisted
    setlocal nonumber
    setlocal winfixwidth
    setlocal cursorline

    setlocal foldcolumn=2
    setlocal foldmarker={,}
    setlocal foldmethod=marker

    call neodebug#SetWindowSytaxHilight()

    nnoremap <buffer> <silent> <CR> :call NeoDebug(getline('.'), 'n')<cr>
    nmap <buffer> <silent> <2-LeftMouse> <cr>

endfunction
" Breakpoints window
function! neodebug#OpenBreakpointsWindow(...)
    let para = a:0>0 ? a:1 : 'v'
    let bufnum = bufnr(g:neodbg_breakpoints_name)

    if bufnum == -1
        " Create a new buffer
        let wcmd = g:neodbg_breakpoints_name
    else
        " Edit the existing buffer
        let wcmd = '+buffer' . bufnum
    endif

    " Create the tag explorer window
    if para == 'v'
        exe 'silent!  botright ' . g:neodbg_breakpoints_width. 'vsplit ' . wcmd
    elseif para == 'h'
        exe 'silent!  ' . g:neodbg_breakpoints_height. 'split ' . wcmd
    endif
    " exe 'silent!  ' . g:neodbg_breakpoints_height. 'split ' . wcmd
    nnoremenu WinBar.Breakpoints/Disassemble   :call neodebug#UpdateBreaksOrDisas()<CR>
endfunction

function neodebug#CloseBreakpoints()
    let g:neodbg_openbreaks_default = 0
    call neodebug#CloseBreakpointsWindow()
endfunction
function neodebug#CloseBreakpointsWindow()
    let winnr = bufwinnr(g:neodbg_breakpoints_name)
    if winnr != -1
        call neodebug#GotoBreakpointsWindow()
        let s:neodbg_save_break_cursor = getpos(".")
        close
        return 1
    endif
    return 0
endfunction

function! neodebug#GotoBreakpointsWindow()
    if bufname("%") == g:neodbg_breakpoints_name
        return
    endif

    let neodbg_winnr = bufwinnr(g:neodbg_breakpoints_name)
    let neodbg_winnr_disas = bufwinnr(g:neodbg_disas_name)

    let neodbg_winnr_stack = bufwinnr(g:neodbg_stackframes_name)
    let neodbg_winnr_thread = bufwinnr(g:neodbg_threads_name)

    let neodbg_winnr_register = bufwinnr(g:neodbg_registers_name)
    let neodbg_winnr_local = bufwinnr(g:neodbg_locals_name)

    let neodbg_winnr_expr = bufwinnr(g:neodbg_expressions_name)
    let neodbg_winnr_watch = bufwinnr(g:neodbg_watchpoints_name)

    if neodbg_winnr == -1
        if neodbg_winnr_disas == -1
            " if multi-tab or the buffer is hidden
            if neodbg_winnr_local != -1
                call neodebug#GotoLocalsWindow()
                call neodebug#OpenBreakpointsWindow('h')
            elseif neodbg_winnr_register != -1
                call neodebug#GotoRegistersWindow()
                call neodebug#OpenBreakpointsWindow('h')
            elseif neodbg_winnr_stack != -1
                call neodebug#GotoStackFramesWindow()
                call neodebug#OpenBreakpointsWindow('h')
            elseif neodbg_winnr_thread != -1
                call neodebug#GotoThreadsWindow()
                call neodebug#OpenBreakpointsWindow('h')
            elseif neodbg_winnr_expr != -1
                call neodebug#GotoExpressionsWindow()
                call neodebug#OpenBreakpointsWindow('h')
            elseif neodbg_winnr_watch != -1
                call neodebug#GotoWatchpointsWindow()
                call neodebug#OpenBreakpointsWindow('h')
            else
                call neodebug#OpenBreakpoints()
            endif

            let neodbg_winnr = bufwinnr(g:neodbg_breakpoints_name)
        else
            call neodebug#GotoDisasWindow()
            let bufnum = bufnr(g:neodbg_breakpoints_name)
            exec "b ". bufnum
            let neodbg_winnr = bufwinnr(g:neodbg_breakpoints_name)
        endif
    endif
    exec neodbg_winnr . "wincmd w"
endfunction

function! neodebug#OpenDisas()
    call neodebug#OpenDisasWindow()

    setlocal buftype=nofile
    setlocal complete=.
    setlocal noswapfile
    setlocal nowrap
    setlocal nobuflisted
    setlocal nonumber
    setlocal winfixwidth
    setlocal cursorline

    setlocal foldcolumn=2
    setlocal foldmarker={,}
    setlocal foldmethod=marker

    call neodebug#SetWindowSytaxHilight()

    nnoremap <buffer> <silent> <CR> :call NeoDebug(getline('.'), 'n')<cr>
    nmap <buffer> <silent> <2-LeftMouse> <cr>

endfunction

" Disas window
function! neodebug#OpenDisasWindow(...)
    let para = a:0>0 ? a:1 : 'v'
    let bufnum = bufnr(g:neodbg_disas_name)

    if bufnum == -1
        " Create a new buffer
        let wcmd = g:neodbg_disas_name
    else
        " Edit the existing buffer
        let wcmd = '+buffer' . bufnum
    endif

    " Create the tag explorer window
    if para == 'v'
        exe 'silent!  botright ' . g:neodbg_disas_width. 'vsplit ' . wcmd
    elseif para == 'h'
        exe 'silent!  ' . g:neodbg_disas_height. 'split ' . wcmd
    endif
    " exe 'silent!  ' . g:neodbg_disas_height. 'split ' . wcmd
    nnoremenu WinBar.Breakpoints/Disassemble   :call neodebug#UpdateBreaksOrDisas()<CR>
endfunction

function neodebug#CloseDisas()
    let g:neodbg_opendisas_default = 0
    call neodebug#CloseDisasWindow()
endfunction

function neodebug#CloseDisasWindow()
    let winnr = bufwinnr(g:neodbg_disas_name)
    if winnr != -1
        call neodebug#GotoDisasWindow()
        let s:neodbg_save_disas_cursor = getpos(".")
        close
        return 1
    endif
    return 0
endfunction

function! neodebug#GotoDisasWindow()
    if bufname("%") == g:neodbg_disas_name
        return
    endif
    let neodbg_winnr = bufwinnr(g:neodbg_disas_name)
    let neodbg_winnr_break = bufwinnr(g:neodbg_breakpoints_name)

    let neodbg_winnr_stack = bufwinnr(g:neodbg_stackframes_name)
    let neodbg_winnr_thread = bufwinnr(g:neodbg_threads_name)

    let neodbg_winnr_local = bufwinnr(g:neodbg_locals_name)
    let neodbg_winnr_register = bufwinnr(g:neodbg_registers_name)

    let neodbg_winnr_expr = bufwinnr(g:neodbg_expressions_name)
    let neodbg_winnr_watch = bufwinnr(g:neodbg_watchpoints_name)

    if neodbg_winnr == -1

        if neodbg_winnr_break == -1
            " if multi-tab or the buffer is hidden
            if neodbg_winnr_stack != -1
                call neodebug#GotoStackFramesWindow()
                call neodebug#OpenDisasWindow('h')
            elseif neodbg_winnr_thread != -1
                call neodebug#GotoThreadsWindow()
                call neodebug#OpenDisasWindow('h')
            elseif neodbg_winnr_local != -1
                call neodebug#GotoLocalsWindow()
                call neodebug#OpenDisasWindow('h')
            elseif neodbg_winnr_register != -1
                call neodebug#GotoRegistersWindow()
                call neodebug#OpenDisasWindow('h')
            elseif neodbg_winnr_expr != -1
                call neodebug#GotoExpressionsWindow()
                call neodebug#OpenDisasWindow('h')
            elseif neodbg_winnr_watch != -1
                call neodebug#GotoWatchpointsWindow()
                call neodebug#OpenDisasWindow('h')
            else
                call neodebug#OpenDisas()
            endif
            let neodbg_winnr = bufwinnr(g:neodbg_disas_name)

        else
            call neodebug#GotoBreakpointsWindow()
            let bufnum = bufnr(g:neodbg_disas_name)
            exec "b ". bufnum
            let neodbg_winnr = bufwinnr(g:neodbg_disas_name)
        endif
    endif
    exec neodbg_winnr . "wincmd w"
    " exec "wincmd ="
endfunction

function! neodebug#OpenExpressions()

    call neodebug#OpenExpressionsWindow()

    setlocal buftype=nofile
    setlocal complete=.
    setlocal noswapfile
    setlocal nowrap
    setlocal nobuflisted
    setlocal nonumber
    setlocal winfixwidth
    setlocal cursorline

    setlocal foldcolumn=2
    setlocal foldmarker={,}
    setlocal foldtext=NeoDebugFoldTextExpr()
    setlocal foldmethod=marker

    " au InsertLeave {__Expressions__}  call neodebug#UpdateExpressionsWindow()
    au InsertLeave <buffer> call neodebug#UpdateExpressionsWindow()

    call neodebug#SetWindowSytaxHilight()

    nnoremap <buffer> <silent> <CR> :call NeoDebug(getline('.'), 'n')<cr>
    nmap <buffer> <silent> <2-LeftMouse> <cr>

endfunction
" Expressions window
function! neodebug#OpenExpressionsWindow(...)
    let para = a:0>0 ? a:1 : 'v'
    let bufnum = bufnr(g:neodbg_expressions_name)

    if bufnum == -1
        " Create a new buffer
        let wcmd = g:neodbg_expressions_name
    else
        " Edit the existing buffer
        let wcmd = '+buffer' . bufnum
    endif

    " Create the tag explorer window
    if para == 'v'
        exe 'silent!  botright ' . g:neodbg_expressions_width. 'vsplit ' . wcmd
    elseif para == 'h'
        exe 'silent!  ' . g:neodbg_expressions_height. 'split ' . wcmd
    endif
    " exe 'silent!  ' . g:neodbg_expressions_height. 'split ' . wcmd
    nnoremenu WinBar.Expressions/Watchpoints   :call neodebug#UpdateExprsOrWatchs()<CR>
endfunction

function neodebug#CloseExpressions()
    let g:neodbg_openexprs_default = 0
    call neodebug#CloseExpressionsWindow()
endfunction
function neodebug#CloseExpressionsWindow()
    let winnr = bufwinnr(g:neodbg_expressions_name)
    if winnr != -1
        call neodebug#GotoExpressionsWindow()
        let s:neodbg_save_expr_cursor = getpos(".")
        close
        return 1
    endif
    return 0
endfunction

function! neodebug#GotoExpressionsWindow()
    if bufname("%") == g:neodbg_expressions_name
        return
    endif

    let neodbg_winnr = bufwinnr(g:neodbg_expressions_name)
    let neodbg_winnr_watch = bufwinnr(g:neodbg_watchpoints_name)

    let neodbg_winnr_local = bufwinnr(g:neodbg_locals_name)
    let neodbg_winnr_register = bufwinnr(g:neodbg_registers_name)

    let neodbg_winnr_stack = bufwinnr(g:neodbg_stackframes_name)
    let neodbg_winnr_thread = bufwinnr(g:neodbg_threads_name)

    let neodbg_winnr_break = bufwinnr(g:neodbg_breakpoints_name)
    let neodbg_winnr_disas = bufwinnr(g:neodbg_disas_name)

    if neodbg_winnr == -1
        if neodbg_winnr_watch == -1
            " if multi-tab or the buffer is hidden
            if neodbg_winnr_local != -1
                call neodebug#GotoLocalsWindow()
                call neodebug#OpenExpressionsWindow('h')
            elseif neodbg_winnr_register != -1
                call neodebug#GotoRegistersWindow()
                call neodebug#OpenExpressionsWindow('h')
            elseif neodbg_winnr_stack != -1
                call neodebug#GotoStackFramesWindow()
                call neodebug#OpenExpressionsWindow('h')
            elseif neodbg_winnr_thread != -1
                call neodebug#GotoThreadsWindow()
                call neodebug#OpenExpressionsWindow('h')
            elseif neodbg_winnr_break != -1
                call neodebug#GotoBreakpointsWindow()
                call neodebug#OpenExpressionsWindow('h')
            elseif neodbg_winnr_disas != -1
                call neodebug#GotoDisasWindow()
                call neodebug#OpenExpressionsWindow('h')
            else
                call neodebug#OpenExpressions()
            endif

            let neodbg_winnr = bufwinnr(g:neodbg_expressions_name)
        else
            call neodebug#GotoWatchpointsWindow()
            let bufnum = bufnr(g:neodbg_expressions_name)
            exec "b ". bufnum
            let neodbg_winnr = bufwinnr(g:neodbg_expressions_name)
        endif
    endif
    exec neodbg_winnr . "wincmd w"
endfunction

function! neodebug#OpenWatchpoints()
    call neodebug#OpenWatchpointsWindow()

    setlocal buftype=nofile
    setlocal complete=.
    setlocal noswapfile
    setlocal nowrap
    setlocal nobuflisted
    setlocal nonumber
    setlocal winfixwidth
    setlocal cursorline

    setlocal foldcolumn=2
    setlocal foldmarker={,}
    setlocal foldmethod=marker

    call neodebug#SetWindowSytaxHilight()

    nnoremap <buffer> <silent> <CR> :call NeoDebug(getline('.'), 'n')<cr>
    nmap <buffer> <silent> <2-LeftMouse> <cr>

endfunction

" Watchpoints window
function! neodebug#OpenWatchpointsWindow(...)
    let para = a:0>0 ? a:1 : 'v'
    let bufnum = bufnr(g:neodbg_watchpoints_name)

    if bufnum == -1
        " Create a new buffer
        let wcmd = g:neodbg_watchpoints_name
    else
        " Edit the existing buffer
        let wcmd = '+buffer' . bufnum
    endif

    " Create the tag explorer window
    if para == 'v'
        exe 'silent!  botright ' . g:neodbg_watchpoints_width. 'vsplit ' . wcmd
    elseif para == 'h'
        exe 'silent!  ' . g:neodbg_watchpoints_height. 'split ' . wcmd
    endif
    " exe 'silent!  ' . g:neodbg_watchpoints_height. 'split ' . wcmd
    nnoremenu WinBar.Expressions/Watchpoints   :call neodebug#UpdateExprsOrWatchs()<CR>
endfunction

function neodebug#CloseWatchpoints()
    let g:neodbg_openwatchs_default = 0
    call neodebug#CloseWatchpointsWindow()
endfunction

function neodebug#CloseWatchpointsWindow()
    let winnr = bufwinnr(g:neodbg_watchpoints_name)
    if winnr != -1
        call neodebug#GotoWatchpointsWindow()
        let s:neodbg_save_watch_cursor = getpos(".")
        close
        return 1
    endif
    return 0
endfunction

function! neodebug#GotoWatchpointsWindow()
    if bufname("%") == g:neodbg_watchpoints_name
        return
    endif
    let neodbg_winnr = bufwinnr(g:neodbg_watchpoints_name)
    let neodbg_winnr_expr = bufwinnr(g:neodbg_expressions_name)

    let neodbg_winnr_local = bufwinnr(g:neodbg_locals_name)
    let neodbg_winnr_register = bufwinnr(g:neodbg_registers_name)

    let neodbg_winnr_stack = bufwinnr(g:neodbg_stackframes_name)
    let neodbg_winnr_thread = bufwinnr(g:neodbg_threads_name)

    let neodbg_winnr_break = bufwinnr(g:neodbg_breakpoints_name)
    let neodbg_winnr_disas = bufwinnr(g:neodbg_disas_name)

    if neodbg_winnr == -1

        if neodbg_winnr_expr == -1
            " if multi-tab or the buffer is hidden
            if neodbg_winnr_local != -1
                call neodebug#GotoLocalsWindow()
                call neodebug#OpenWatchpointsWindow('h')
            elseif neodbg_winnr_register != -1
                call neodebug#GotoRegistersWindow()
                call neodebug#OpenWatchpointsWindow('h')
            elseif neodbg_winnr_stack != -1
                call neodebug#GotoStackFramesWindow()
                call neodebug#OpenWatchpointsWindow('h')
            elseif neodbg_winnr_thread != -1
                call neodebug#GotoThreadsWindow()
                call neodebug#OpenWatchpointsWindow('h')
            elseif neodbg_winnr_break != -1
                call neodebug#GotoBreakpointsWindow()
                call neodebug#OpenWatchpointsWindow('h')
            elseif neodbg_winnr_disas != -1
                call neodebug#GotoDisasWindow()
                call neodebug#OpenWatchpointsWindow('h')
            else
                call neodebug#OpenWatchpoints()
            endif
            let neodbg_winnr = bufwinnr(g:neodbg_watchpoints_name)

        else
            call neodebug#GotoExpressionsWindow()
            let bufnum = bufnr(g:neodbg_watchpoints_name)
            exec "b ". bufnum
            let neodbg_winnr = bufwinnr(g:neodbg_watchpoints_name)
        endif
    endif
    exec neodbg_winnr . "wincmd w"
    " exec "wincmd ="
endfunction

function! neodebug#UpdateConsole()
    " if g:neodbg_openconsole_default == 0
        " return
    " endif
    call neodebug#UpdateConsoleWindow()
endfunction

function! neodebug#UpdateLocals()
    if g:neodbg_openlocals_default == 0
        return
    endif
    call neodebug#UpdateLocalsWindow()
endfunction

function! neodebug#UpdateRegisters()
    if g:neodbg_openregisters_default == 0
        return
    endif
    call neodebug#UpdateRegistersWindow()
endfunction

function! neodebug#UpdateStackFrames()
    if g:neodbg_openstacks_default == 0
        return
    endif
    call neodebug#UpdateStackFramesWindow()
endfunction

function! neodebug#UpdateThreads()
    if g:neodbg_openthreads_default == 0
        return
    endif
    call neodebug#UpdateThreadsWindow()
endfunction

function! neodebug#UpdateBreakpoints()
    if g:neodbg_openbreaks_default == 0
        return
    endif
    call neodebug#UpdateBreakpointsWindow()
endfunction

function! neodebug#UpdateDisas()
    if g:neodbg_opendisas_default == 0
        return
    endif
    call neodebug#UpdateDisasWindow()
endfunction

function! neodebug#UpdateExpressions()
    if g:neodbg_openexprs_default == 0
        return
    endif
    call neodebug#UpdateExpressionsWindow()
endfunction

function! neodebug#UpdateWatchpoints()
    if g:neodbg_openwatchs_default == 0
        return
    endif
    call neodebug#UpdateWatchpointsWindow()
endfunction

function! neodebug#UpdateConsoleWindow()
    " let g:neodbg_openconsole_default = 1
    call neodebug#GotoConsoleWindow()

    if len(g:append_messages) == 1 && g:append_messages[-1] == g:neodbg_prompt
        "do not need output
    else
        if !empty(g:append_messages)
            for append_message in (g:append_messages)
                call append(line("$"), append_message)
            endfor
            " let  g:append_messages = []
            let g:append_messages = ["(gdb) "]
        endif
    endif

    $
    starti!
    redraw

endfunction

function! neodebug#UpdateLocalsWindow()
    let g:neodbg_openlocals_default = 1
    let g:neodbg_openregisters_default = 0
    call neodebug#GotoLocalsWindow()
    call neodebug#SetBufEnable()
    silent exec '0,' . line("$") . 'd _'
    call neodebug#SetBufDisable()
    call NeoDebugSendCommand("info locals", 'u')
endfunction

function! neodebug#UpdateRegistersWindow()
    let g:neodbg_openregisters_default = 1
    let g:neodbg_openlocals_default = 0
    call neodebug#GotoRegistersWindow()
    call neodebug#SetBufEnable()
    silent exec '0,' . line("$") . 'd _'
    call neodebug#SetBufDisable()
    call NeoDebugSendCommand("info registers", 'u')
endfunction

function! neodebug#UpdateStackFramesWindow()
    let g:neodbg_openstacks_default = 1
    let g:neodbg_openthreads_default = 0
    call neodebug#GotoStackFramesWindow()
    call neodebug#SetBufEnable()
    silent exec '0,' . line("$") . 'd _'
    call neodebug#SetBufDisable()
    call NeoDebugSendCommand("backtrace", 'u')
endfunction

function! neodebug#UpdateThreadsWindow()
    let g:neodbg_openthreads_default = 1
    let g:neodbg_openstacks_default = 0
    call neodebug#GotoThreadsWindow()
    call neodebug#SetBufEnable()
    silent exec '0,' . line("$") . 'd _'
    call neodebug#SetBufDisable()
    call NeoDebugSendCommand("info threads", 'u')
endfunction

function! neodebug#UpdateBreakpointsWindow()
    let g:neodbg_openbreaks_default = 1
    let g:neodbg_opendisas_default = 0
    call neodebug#GotoBreakpointsWindow()
    call neodebug#SetBufEnable()
    silent exec '0,' . line("$") . 'd _'
    call neodebug#SetBufDisable()
    call NeoDebugSendCommand("info breakpoints", 'u')
endfunction

function! neodebug#UpdateDisasWindow()
    let g:neodbg_opendisas_default = 1
    let g:neodbg_openbreaks_default = 0
    call neodebug#GotoDisasWindow()
    call neodebug#SetBufEnable()
    silent exec '0,' . line("$") . 'd _'
    call neodebug#SetBufDisable()
    call NeoDebugSendCommand("disassemble", 'u')
endfunction

function! neodebug#UpdateExpressionsWindow()
    let g:neodbg_openexprs_default = 1
    let g:neodbg_openwatchs_default = 0
    call neodebug#GotoExpressionsWindow()

    if line("$") != 1 || getline(1) != ""
        " Expression buffer not empty
        let iline = 1
        while iline <= line("$")
            " echomsg "ilinestart".iline
            let linetext = getline(iline)
            " echomsg "linetext".linetext
            let expr  = substitute(linetext,'^\(\S*\)\s*=.*\n\=$','\1','')
            if expr == linetext
                echomsg "Expressions no space start please!"
            else
                " echomsg "expr:".expr
                let value = NeoDebugExprPrint(expr)
                if value == 0
                    let value = '--N/A--'
                    keepj call setline(iline,expr.' = '.value)
                else
                    for v in g:exprs_value_lines
                        echomsg "v".v
                    endfor
                    let value = strpart(g:exprs_value_lines[0], stridx(g:exprs_value_lines[0], ' ')+2 )
                    keepj call setline(iline,expr.' = '.value)
                    for othervalue in g:exprs_value_lines[1:-1]
                        " echomsg "ilinemid".iline
                        let iline = iline + 1
                        keepj call setline(iline, othervalue)
                    endfor
                endif
                let g:exprs_value_lines = []
            endif
            let iline = iline + 1
            " echomsg "ilineend".iline
        endwhile
    endif
endfunction

function! neodebug#UpdateWatchpointsWindow()
    let g:neodbg_openwatchs_default = 1
    let g:neodbg_openexprs_default = 0
    call neodebug#GotoWatchpointsWindow()
    call neodebug#SetBufEnable()
    silent exec '0,' . line("$") . 'd _'
    call neodebug#SetBufDisable()
    call NeoDebugSendCommand("info watchpoints", 'u')
endfunction


function! neodebug#UpdateLocalsOrRegisters()

    let neodbg_winnr_register = bufwinnr(g:neodbg_registers_name)
    let neodbg_winnr_local = bufwinnr(g:neodbg_locals_name)

    if neodbg_winnr_register == -1
        let g:neodbg_openlocals_default = 0
        call neodebug#UpdateRegistersWindow()
    endif

    if neodbg_winnr_local == -1
        let g:neodbg_openregisters_default = 0
        call neodebug#UpdateLocalsWindow()
    endif
endfunction

function! neodebug#UpdateStackOrThreads()

    let neodbg_winnr_thread = bufwinnr(g:neodbg_threads_name)
    let neodbg_winnr_stack = bufwinnr(g:neodbg_stackframes_name)

    if neodbg_winnr_thread == -1
        let g:neodbg_openstacks_default = 0
        call neodebug#UpdateThreadsWindow()
    endif

    if neodbg_winnr_stack == -1
        let g:neodbg_openthreads_default = 0
        call neodebug#UpdateStackFramesWindow()
    endif
endfunction

function! neodebug#UpdateBreaksOrDisas()

    let neodbg_winnr_break = bufwinnr(g:neodbg_breakpoints_name)
    let neodbg_winnr_disas = bufwinnr(g:neodbg_disas_name)

    if neodbg_winnr_break == -1
        let g:neodbg_opendisas_default = 0
        call neodebug#UpdateBreakpointsWindow()
    endif

    if neodbg_winnr_disas == -1
        let g:neodbg_openbreaks_default = 0
        call neodebug#UpdateDisasWindow()
    endif

endfunction

function! neodebug#UpdateExprsOrWatchs()

    let neodbg_winnr_expr = bufwinnr(g:neodbg_expressions_name)
    let neodbg_winnr_watch = bufwinnr(g:neodbg_watchpoints_name)

    if neodbg_winnr_expr == -1
        let g:neodbg_openwatchs_default = 0
        call neodebug#UpdateExpressionsWindow()
    endif

    if neodbg_winnr_watch == -1
        let g:neodbg_openexprs_default = 0
        call neodebug#UpdateWatchpointsWindow()
    endif
endfunction


" Install commands in the current window to control the debugger.
func neodebug#InstallCommandsShotcut()

    call neodebug#InstallCommand()

    if has('menu') && &mouse != ''
        call neodebug#InstallWinbar()
        call  neodebug#InstallPopupMenu()
    endif

    call neodebug#SetWindowSytaxHilight()
    "disable some key
    call neodebug#CustomConsoleKey()
    " shortcut in NeoDebug window
    call neodebug#InstallShotcut()
    " menu
    call neodebug#InstallMenu()
endfunc

function! neodebug#InstallCommand()
    command Break call NeoDebugSetBreakpoint()
    command Clear call NeoDebugClearBreakpoint()
    command Step call NeoDebugSendCommand('-exec-step')
    command Over call NeoDebugSendCommand('-exec-next')
    command Finish call NeoDebugSendCommand('-exec-finish')
    command -nargs=* Run call NeoDebugRun(<q-args>)
    command -nargs=* Arguments call NeoDebugSendCommand('-exec-arguments ' . <q-args>)
    command Stop call NeoDebugSendCommand('-exec-interrupt')
    command Continue call NeoDebugSendCommand('-exec-continue')
    command -range -nargs=* Evaluate call NeoDebugEvaluate(<range>, <q-args>)
    command Winbar call neodebug#InstallWinbar()
endfunction

function! neodebug#DeleteCommand()
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
    delcommand Winbar
endfunction

function! neodebug#SetWindowSytaxHilight()

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
    syn match NeoDebugHiLn /Dump of assembler code for function main:$/
    syn match NeoDebugHiLn /End of assembler dump.$/

    " syntax for perldb
    syn match NeoDebugCmd /^\s*DB<.*/
    "	syn match NeoDebugFrame /\v^#\d+ .*/ contains=NeoDebugGoto
    syn match NeoDebugGoto /\v from file ['`].+' line \d+/
    syn match NeoDebugGoto /\v at ([^ ]+) line (\d+)/
    syn match NeoDebugGoto /\v at \(eval \d+\)..[^:]+:\d+/

endfunction

function! neodebug#UnsetWindowSytaxHilight()
    sign undefine NeoDebugPC
    sign undefine NeoDebugBP
endfunction

function! neodebug#InstallShotcut()

    " TODO: can the K mapping be restored?
    nnoremap K :Evaluate<CR>

    noremap <buffer><silent>? :call neodebug#ToggleHelp()<cr>

    inoremap <expr><buffer> <silent> <c-p>  "\<c-x><c-l>"
    inoremap <expr><buffer> <silent> <c-r>  "\<c-x><c-n>"

    inoremap <expr><buffer><silent> <TAB>    pumvisible() ? "\<C-n>" : "\<c-x><c-u>"
    inoremap <expr><buffer><silent> <S-TAB>  pumvisible() ? "\<C-p>" : "\<c-x><c-u>"
    noremap <buffer><silent> <Tab> ""
    noremap <buffer><silent> <S-Tab> ""

    noremap <buffer><silent> <ESC> :call neodebug#CloseConsoleWindow()<CR>

    inoremap <expr><buffer> <silent> <CR> pumvisible() ? "\<c-y><c-o>:call NeoDebug(getline('.'), 'i')<cr>" : "<c-o>:call NeoDebug(getline('.'), 'i')<cr>"
    " inoremap <buffer> <silent> <C-CR> :<c-o>:call NeoDebug("", 'i')<cr>

    nnoremap <buffer> <silent> <CR> :call NeoDebug(getline('.'), 'n')<cr>
    nmap <buffer> <silent> <2-LeftMouse> <cr>

    nmap <silent> <F9>	         :call NeoDebugToggleBreakpoint()<CR>
    map! <silent> <F9>	         <c-o>:call NeoDebugToggleBreakpoint()<CR>

    nmap <silent> <Leader>ju	 :call NeoDebugJump()<CR>
    nmap <silent> <C-S-F10>		 :call NeoDebugJump()<CR>
    nmap <silent> <C-F10>        :call NeoDebugRunToCursur()<CR>
    map! <silent> <C-S-F10>		 <c-o>:call NeoDebugJump()<CR>
    map! <silent> <C-F10>        <c-o>:call NeoDebugRunToCursur()<CR>
    nmap <silent> <F6>           :call neodebug#ToggleConsoleWindow()<CR>
    imap <silent> <F6>           <c-o>:call neodebug#ToggleConsoleWindow()<CR>
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
    noremap <silent> <c-c> :NeoDebugStop<cr>

    map! <silent> <F5>    <c-o>:NeoDebug c<cr>
    map! <silent> <S-F5>  <c-o>:NeoDebug k<cr>
    map! <silent> <F10>   <c-o>:NeoDebug n<cr>
    map! <silent> <F11>   <c-o>:NeoDebug s<cr>
    map! <silent> <S-F11> <c-o>:NeoDebug finish<cr>

endfunction

function! neodebug#DeleteShotcut()
    nunmap K
    unmap <F9>
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
endfunction

function! neodebug#InstallMenu()
    amenu NeoDebug.Run/Continue<tab>F5 					:NeoDebug c<CR>
    amenu NeoDebug.Step\ into<tab>F11					:NeoDebug s<CR>
    amenu NeoDebug.Next<tab>F10							:NeoDebug n<CR>
    amenu NeoDebug.Step\ out<tab>Shift-F11				:NeoDebug finish<CR>
    amenu NeoDebug.Run\ to\ cursor<tab>Ctrl-F10			:call NeoDebugRunToCursur()<CR>
    amenu NeoDebug.Stop\ debugging\ (Kill)<tab>Shift-F5	:NeoDebug k<CR>
    amenu NeoDebug.-sep1- :

    amenu NeoDebug.Show\ callstack<tab>\\bt				:call NeoDebug("where")<CR>
    amenu NeoDebug.Set\ next\ statement\ (Jump)<tab>Ctrl-Shift-F10\ or\ \\ju 	:call NeoDebugJump()<CR>
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
endfunction

function! neodebug#DeleteMenu()
    aunmenu NeoDebug
endfunction

let s:winbar_winids = []

" Install the window toolbar in the current window.
function! neodebug#InstallWinbar()
    nnoremenu WinBar.Step   :NeoDebug s<CR>
    nnoremenu WinBar.Next   :NeoDebug n<CR>
    nnoremenu WinBar.Finish :NeoDebug finish<CR>
    nnoremenu WinBar.Cont   :NeoDebug c<CR>
    nnoremenu WinBar.Stop   :NeoDebug k<CR>
    nnoremenu WinBar.Eval   :Evaluate<CR>
    call add(s:winbar_winids, win_getid(winnr()))
endfunction

function! neodebug#DeleteWinbar()
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
    endif

endfunction

function! neodebug#InstallPopupMenu()
        if !exists('g:neodbg_popup') || g:neodbg_popup != 0
            let s:saved_mousemodel = &mousemodel
            let &mousemodel = 'popup_setpos'
            an 1.200 PopUp.-SEP3-	<Nop>
            an 1.210 PopUp.Set\ breakpoint	:Break<CR>
            an 1.220 PopUp.Clear\ breakpoint	:Clear<CR>
            an 1.230 PopUp.Evaluate		:Evaluate<CR>
        endif
endfunction

function! neodebug#DeletePopupMenu()
    if has('menu')
        if exists('s:saved_mousemodel')
            let &mousemodel = s:saved_mousemodel
            unlet s:saved_mousemodel
            aunmenu PopUp.-SEP3-
            aunmenu PopUp.Set\ breakpoint
            aunmenu PopUp.Clear\ breakpoint
            aunmenu PopUp.Evaluate
        endif
    endif
endfunction

function! neodebug#SetBufEnable()
    " clear the buffer and make it editable
    setlocal ma noro
endfunction

function! neodebug#SetBufDisable()
    " make it not-editable and close the buffer
    setlocal noma ro cul nomod
endfunction

" vim: set foldmethod=marker 
