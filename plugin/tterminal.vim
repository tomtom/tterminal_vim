" @Author:      Tom Link (micathom AT gmail com?subject=[vim])
" @Website:     https://github.com/tomtom
" @License:     GPL (see http://www.gnu.org/licenses/gpl.txt)
" @Last Change: 2019-04-20
" @Revision:    13
" GetLatestVimScripts: 0 0 :AutoInstall: tterminal.vim

if &cp || exists('g:loaded_tterminal')
    finish
endif
if !has('terminal')
    echoerr 'Tterminal requires terminal support'
    finish
endif
let g:loaded_tterminal = 1

let s:save_cpo = &cpo
set cpo&vim


if !exists('g:tterminal_autoenable_filetypes')
    " Automatically enable tterminal (i.e. install some basic maps) for 
    " these filetypes.
    let g:tterminal_autoenable_filetypes = []   "{{{2
endif


" :display: :Tterminal [RUNCONFIG_NAME] [TERMINAL_ID]
command! -nargs=* Tterminal call tterminal#Terminal(matchstr(histget(':'), '^.\{-}\ze\<Tterminal'), <f-args>)


augroup Tterminal
    autocmd!
    if !empty(g:tterminal_autoenable_filetypes)
        exec 'autocmd Filetype' join(g:tterminal_autoenable_filetypes, ',') 'call tterminal#EnableBuffer()'
    endif
augroup END


let &cpo = s:save_cpo
unlet s:save_cpo
