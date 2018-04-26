NeoDebug - GDB Vim Frontend
===========================
# Intro

NeoDebug is a gdb frontend plugin for Vim, asynchronously run gdb and pipe communication.

It both works on MS Windows and Linux. 

It opens a DebugConsole window in vim that allows user to type gdb command directly, 
and gdb output is redirected to this windows.

Screenshot:
1. Gdb command directly input and show result.
![Screenshot](https://github.com/cpiger/NeoDebug/blob/master/NeoDebug1.png)

2. Vim Style complete.
![Vim style complete](https://github.com/cpiger/NeoDebug/blob/master/NeoDebugComplete.png)

3. BallonShow.
![ballonshow](https://github.com/cpiger/NeoDebug/blob/master/NeoDebugBallonShow.png)


## Installation

1. You need install sed (and of course gdb).

2. Use your preferred installation method for Vim plugins.

   With vim-plug that would mean to add the following to your vimrc:

   Plug 'cpiger/NeoDebug'

=========================================================

My dev environment:
- Windows: 
 - tdm-gcc-5.1.0-3.exe
 - sed-4.2.1-bin.zip(http://sourceforge.net/projects/gnuwin32/files//sed/4.2.1/sed-4.2.1-bin.zip/download)
 - Vim 8.0 Included patches: 1-1532 (https://tuxproject.de/projects/vim/)
- Linux:
 - Gdb 7.12.1-48.fc25
 - Vim vim-X11-8.0.1171-1.fc25.x86_64

=========================================================

## Quick usage

In vim or gvim, run :NeoDebug command, e.g. 
See Screenshot.

	:NeoDebug


The following shortcuts is applied that is similar to MSVC: 

	<F5> 	- run or continue
	<S-F5> 	- stop debugging (kill)
	<F10> 	- next
	<F11> 	- step into
	<S-F11> - step out (finish)
	<C-F10>	- run to cursor (tb and c)
	<F9> 	- toggle breakpoint on current line
	<C-F9> 	- toggle enable/disable breakpoint on current line
	\ju or <C-S-F10> - set next statement (tb and jump)
	<C-P> 	- view variable under the cursor (.p)
    <TAB>   - trigger complete 

## Thanks
skyshore2001
(https://github.com/skyshore2001/vgdb-vim)
Bram Moolenaar 
(vim80\pack\dist\opt\termdebug\plugin\termdebug.vim)
