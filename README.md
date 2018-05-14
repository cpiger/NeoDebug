NeoDebug - GDB Vim Frontend
===========================
# Intro

NeoDebug is a gdb frontend plugin for Vim, asynchronously run gdb and pipe communication.

It both works on MS Windows and Linux. 

It opens a DebugConsole window in vim that allows user to type gdb command directly, 
and gdb output is redirected to this windows.

Screenshot:
1. Gdb command directly input and show result.

![Screenshot](https://github.com/cpiger/NeoDebug/blob/master/doc/NeoDebug1.png)


2. Vim Style complete.

![Vim style complete](https://github.com/cpiger/NeoDebug/blob/master/doc/NeoDebugComplete.png)


3. BallonShow.

![ballonshow](https://github.com/cpiger/NeoDebug/blob/master/doc/NeoDebugBallonShow.png)


4. Breakpoints jump, threads, stack

![info breakpoints](https://github.com/cpiger/NeoDebug/blob/master/doc/NeoDebugInfoBreakpointsJump.png)


![stack](https://github.com/cpiger/NeoDebug/blob/master/doc/NeoDebugFrameEnter.png)


![threas](https://github.com/cpiger/NeoDebug/blob/master/doc/NeoDebugInfoThreadsHit.png)


5. info locals, breakpoints, threads, bt, registers

![info](https://github.com/cpiger/NeoDebug/blob/master/doc/NeoDebugInfoSwitch.png)


## Installation

1. You need install sed (and of course gdb).

2. Use your preferred installation method for Vim plugins.

   With vim-plug that would mean to add the following to your vimrc:

   Plug 'cpiger/NeoDebug'

=========================================================

My dev environment:
- Windows: 
 - tdm-gcc-5.1.0-3.exe
 - sed (https://raw.githubusercontent.com/mbuilov/sed-windows/master/sed-4.4-x64.exe)  (This Sed do not creates un-deleteable files in Windows.)
 - Vim 8.0 Included patches: 1-1532 (https://tuxproject.de/projects/vim/)
- Linux:
 - Gdb 7.12.1-48.fc25
 - Vim vim-X11-8.0.1171-1.fc25.x86_64

=========================================================

## Quick usage

In vim or gvim, run :NeoDebug command, e.g. 
See Screenshot.

	:NeoDebug         "start gdb and open a gdb console buffer in vim

    :OpenConsole       "open neodebug console window
    :CloseConsole      "close neodebug console window
    :ToggleConsole     "toggle neodebug console window

    :OpenLocals        "open  [info locals] window
    :OpenRegisters     "open  [info registers] window
    :OpenStacks        "open  [backtrace] window
    :OpenThreads       "open  [info threads] window
    :OpenBreaks        "open  [info breakpoints] window
    :OpenDisas         "open  [disassemble] window
    :OpenExpressions   "open  [Exressions] window
    :OpenWatchs        "open  [info watchpoints] window


    :CloseLocals       "close [info locals] window
    :CloseRegisters    "close [info registers] window
    :CloseStacks       "close [backtrace] window
    :CloseThreads      "close [info threads] window
    :CloseBreaks       "close [info breakpoints] window
    :CloseDisas        "close [disassemble] window
    :CloseExpressions  "close [Exressions] window       
    :CloseWatchs       "close [info watchpoints] window 


The following shortcuts is applied that is similar to MSVC: 

	<F5> 	- run or continue
	<S-F5> 	- stop debugging (kill)
    <F6> 	- toggle console window
	<F10> 	- next
	<F11> 	- step into
	<S-F11> - step out (finish)
	<C-F10>	- run to cursor (tb and c)
	<F9> 	- toggle breakpoint on current line
	\ju or <C-S-F10> - set next statement (tb and jump)
	<C-P> 	- view variable under the cursor (.p)
    <TAB>   - trigger complete 


Options:

    let g:neodbg_console_height        = 15  " gdb console buffer hight, Default: 15
    let g:neodbg_openbreaks_default    = 1   " Open breakpoints window, Default: 1
    let g:neodbg_openstacks_default    = 0   " Open stackframes window, Default: 0
    let g:neodbg_openthreads_default   = 0   " Open threads window, Default: 0
    let g:neodbg_openlocals_default    = 1   " Open locals window, Default: 1
    let g:neodbg_openregisters_default = 0   " Open registers window, Default: 0

## FAQ

Q: Where to get my program's Input and Output ?

A: You can use 'tty' command to redirected program's input and output on linux.
   A similar command under Windows is set new-console, that is default on NeoDebug.
   [GDB OnLine Docs](https://sourceware.org/gdb/onlinedocs/gdb/Input_002fOutput.html)

## TODO

1. Breakpoints disable/enable

2. vim swap file notification

3. source file changed notification and update breakpoints

4. Options add:
   info windows group customized.


## Thanks
skyshore2001

(https://github.com/skyshore2001/vgdb-vim)


Bram Moolenaar 

(vim80\pack\dist\opt\termdebug\plugin\termdebug.vim)
