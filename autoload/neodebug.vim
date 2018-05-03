"""""""""""""""""""""""""""""""""""""""""""""""""""""""
" NeoDebug - NeoDebug 
" Console
" Breakpoints
" Locals
" StackFrame
" Threads
" Registers
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
    silent call append ( 0, s:help_text )
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

    call NeoDebugInstallCommandsHotkeys()


    starti!
    " call cursor(0, 7)
    setl completefunc=NeoDebugComplete

endfunction
" Get ready for communication
function! neodebug#OpenConsoleWindow()
    let bufnum = bufnr(g:neodbg_console_name)

    if bufnum == -1
        " Create a new buffer
        let wcmd = g:neodbg_console_name
    else
        " Edit the existing buffer
        let wcmd = '+buffer' . bufnum
    endif

    " Create the tag explorer window
    exe 'silent!  botright ' . g:neodbg_console_height . 'split ' . wcmd
    if line('$') <= 1 && g:neodbg_enable_help
        silent call append ( 0, s:help_text )
    endif
    call NeoDebugInstallWinbar()
endfunction

function neodebug#CloseConsoleWindow()
    let winnr = bufwinnr(g:neodbg_console_name)
    if winnr != -1
        call neodebug#GotoConsoleWindow()
        let s:neodbg_save_cursor = getpos(".")
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
        call neodebug#GotoConsoleWindow()
        call setpos('.', s:neodbg_save_cursor)
    endif
endfunction

function! neodebug#GotoConsoleWindow()
    if bufname("%") == g:neodbg_console_name
        return
    endif
    let neodbg_winnr = bufwinnr(g:neodbg_console_name)
    if neodbg_winnr == -1
        " if multi-tab or the buffer is hidden
        call neodebug#OpenConsoleWindow()
        let neodbg_winnr = bufwinnr(g:neodbg_console_name)
    endif
    exec neodbg_winnr . "wincmd w"
endf

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
endf

function! s:IsModifiablex()
    let pos = getpos(".")  
    let curline = pos[1]
    if  curline == line("$") && strpart(g:neodbg_prompt, 0, 5) == strpart(getline("."), 0, 5) && col(".") >= strlen(g:neodbg_prompt)+1
                \ || (curline == line("$") && ' >' == strpart(getline("."), 0, 2) && col(".") >= strlen(' >')+1)
        return 1
    else
        return 0
    endif
endf
function! s:IsModifiableX()
    let pos = getpos(".")  
    let curline = pos[1]
    if  (curline == line("$") && strpart(g:neodbg_prompt, 0, 5) == strpart(getline("."), 0, 5) && col(".") >= strlen(g:neodbg_prompt)+2)
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
        if curcol >  strlen(g:neodbg_prompt)
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
        let pos[2] = strlen(g:neodbg_prompt)+1
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
    setlocal foldmarker={,}
    setlocal foldmethod=marker


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
        let s:neodbg_save_cursor = getpos(".")
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
            else
                call neodebug#OpenLocals()
            endif

            exec "wincmd ="
            let neodbg_winnr = bufwinnr(g:neodbg_locals_name)

        else
            call neodebug#GotoRegistersWindow()
            let bufnum = bufnr(g:neodbg_locals_name)
            exec "b ". bufnum
            let neodbg_winnr = bufwinnr(g:neodbg_locals_name)
        endif
    endif
    exec neodbg_winnr . "wincmd w"
endf

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
    " exec "wincmd ="
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
        let s:neodbg_save_cursor = getpos(".")
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
            else
                call neodebug#OpenRegisters()
            endif
            exec "wincmd ="
            let neodbg_winnr = bufwinnr(g:neodbg_registers_name)

        else
            call neodebug#GotoLocalsWindow()
            let bufnum = bufnr(g:neodbg_registers_name)
            exec "b ". bufnum
            let neodbg_winnr = bufwinnr(g:neodbg_registers_name)
        endif
    endif
    exec neodbg_winnr . "wincmd w"
endf


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
    " exec "wincmd ="
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
        let s:neodbg_save_cursor = getpos(".")
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
            else
                call neodebug#OpenStackFrames()
            endif

            exec "wincmd ="
            let neodbg_winnr = bufwinnr(g:neodbg_stackframes_name)
        else
            call neodebug#GotoThreadsWindow()
            let bufnum = bufnr(g:neodbg_stackframes_name)
            exec "b ". bufnum
            let neodbg_winnr = bufwinnr(g:neodbg_stackframes_name)
        endif
    endif
    exec neodbg_winnr . "wincmd w"
endf


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
    " exec "wincmd ="
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
        let s:neodbg_save_cursor = getpos(".")
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
            else
                call neodebug#OpenThreads()
            endif

            exec "wincmd ="
            let neodbg_winnr = bufwinnr(g:neodbg_threads_name)

        else
            call neodebug#GotoStackFramesWindow()
            let bufnum = bufnr(g:neodbg_threads_name)
            exec "b ". bufnum
            let neodbg_winnr = bufwinnr(g:neodbg_threads_name)
        endif
    endif
    exec neodbg_winnr . "wincmd w"
endf

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
    " exec "wincmd ="
    nnoremenu WinBar.Breakpoints   :call neodebug#UpdateBreakpointsWindow()<CR>
endfunction

function neodebug#CloseBreakpoints()
    let g:neodbg_openbreaks_default = 0
    call neodebug#CloseBreakpointsWindow()
endfunction
function neodebug#CloseBreakpointsWindow()
    let winnr = bufwinnr(g:neodbg_breakpoints_name)
    if winnr != -1
        call neodebug#GotoBreakpointsWindow()
        let s:neodbg_save_cursor = getpos(".")
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

    let neodbg_winnr_stack = bufwinnr(g:neodbg_stackframes_name)
    let neodbg_winnr_thread = bufwinnr(g:neodbg_threads_name)

    let neodbg_winnr_register = bufwinnr(g:neodbg_registers_name)
    let neodbg_winnr_local = bufwinnr(g:neodbg_locals_name)

    if neodbg_winnr == -1
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
            else
                call neodebug#OpenBreakpoints()
            endif

            exec "wincmd ="
            let neodbg_winnr = bufwinnr(g:neodbg_breakpoints_name)
    endif
    exec neodbg_winnr . "wincmd w"
endf

function! neodebug#UpdateLocals()
    if g:neodbg_openlocals_default == 0
        return
    endif
    call neodebug#UpdateLocalsWindow()
endf
function! neodebug#UpdateRegisters()
    if g:neodbg_openregisters_default == 0
        return
    endif
    call neodebug#UpdateRegistersWindow()
endf
function! neodebug#UpdateStackFrames()
    if g:neodbg_openstacks_default == 0
        return
    endif
    call neodebug#UpdateStackFramesWindow()
endf
function! neodebug#UpdateThreads()
    if g:neodbg_openthreads_default == 0
        return
    endif
    call neodebug#UpdateThreadsWindow()
endf
function! neodebug#UpdateBreakpoints()
    if g:neodbg_openbreaks_default == 0
        return
    endif
    call neodebug#UpdateBreakpointsWindow()
endf

function! neodebug#UpdateLocalsWindow()
    let g:neodbg_openlocals_default = 1
    call neodebug#GotoLocalsWindow()
    silent exec '0,' . line("$") . 'd _'
    call NeoDebugSendCommand("info locals", 'u')
endf

function! neodebug#UpdateRegistersWindow()
    let g:neodbg_openregisters_default = 1
    call neodebug#GotoRegistersWindow()
    silent exec '0,' . line("$") . 'd _'
    call NeoDebugSendCommand("info registers", 'u')
endf

function! neodebug#UpdateStackFramesWindow()
    let g:neodbg_openstacks_default = 1
    call neodebug#GotoStackFramesWindow()
    silent exec '0,' . line("$") . 'd _'
    call NeoDebugSendCommand("backtrace", 'u')
endf

function! neodebug#UpdateThreadsWindow()
    let g:neodbg_openthreads_default = 1
    call neodebug#GotoThreadsWindow()
    silent exec '0,' . line("$") . 'd _'
    call NeoDebugSendCommand("info threads", 'u')
endf

function! neodebug#UpdateBreakpointsWindow()
    let g:neodbg_openbreaks_default = 1
    call neodebug#GotoBreakpointsWindow()
    silent exec '0,' . line("$") . 'd _'
    call NeoDebugSendCommand("info breakpoints", 'u')
endf

function! neodebug#UpdateStackOrThreads()

    let neodbg_winnr_thread = bufwinnr(g:neodbg_threads_name)
    let neodbg_winnr_stack = bufwinnr(g:neodbg_stackframes_name)

    if neodbg_winnr_thread == -1
        call neodebug#UpdateThreadsWindow()
    endif

    if neodbg_winnr_stack == -1
        call neodebug#UpdateStackFramesWindow()
    endif
endfunction

function! neodebug#UpdateLocalsOrRegisters()

    let neodbg_winnr_register = bufwinnr(g:neodbg_registers_name)
    let neodbg_winnr_local = bufwinnr(g:neodbg_locals_name)

    if neodbg_winnr_register == -1
        call neodebug#UpdateRegistersWindow()
    endif

    if neodbg_winnr_local == -1
        call neodebug#UpdateLocalsWindow()
    endif
endfunction
" vim: set foldmethod=marker 
