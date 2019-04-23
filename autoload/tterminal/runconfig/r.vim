" @Author:      Tom Link (mailto:micathom AT gmail com?subject=[vim])
" @Website:     https://github.com/tomtom
" @License:     GPL (see http://www.gnu.org/licenses/gpl.txt)
" @Last Change: 2019-04-21
" @Revision:    666


if !exists('g:tterminal#runconfig#r#cmd')
    let g:tterminal#runconfig#r#cmd = executable('Rterm') ? 'Rterm' : 'R'   "{{{2
endif
if !executable(g:tterminal#runconfig#r#cmd)
    throw 'Tterminal: g:tterminal#runconfig#r#cmd is not executable: '. g:tterminal#runconfig#r#cmd
endif


if !exists('g:tterminal#runconfig#r#save')
    " If true, save R sessions by default.
    let g:tterminal#runconfig#r#save = 1   "{{{2
endif


if !exists('g:tterminal#runconfig#r#restore')
    " If true, restore R sessions by default.
    let g:tterminal#runconfig#r#restore = 1   "{{{2
endif


if !exists('g:tterminal#runconfig#r#args')
    let g:tterminal#runconfig#r#args = ''   "{{{2
    " let g:tterminal#runconfig#r#args = '--silent '. (g:tterminal#runconfig#r#cmd =~? '\<rterm\%(\.exe\)\>' ? '--ess' : '--no-readline --interactive')   "{{{2
endif


if !exists('g:tterminal#runconfig#r#init_script')
    let g:tterminal#runconfig#r#init_script = simplify(expand('<sfile>:p:h') .'/tterminal_vim.R')  "{{{2
endif


if !exists('g:tterminal#runconfig#r#quicklist')
    let g:tterminal#runconfig#r#quicklist = ['??"%{cword}"', 'str(%{cword})', 'summary(%{cword})', 'head(%{cword})', 'edit(%{cword})', 'fix(%{cword})', 'debugger()', 'traceback()', 'install.packages("%{cword}")', 'update.packages()', 'example("%{cword}")', 'graphics.off()']   "{{{2
    if exists('g:tterminal#runconfig#r_quicklist_user')
        let g:tterminal#runconfig#r#quicklist += g:tterminal#runconfig#r_quicklist_user
    endif
endif


if !exists('g:tterminal#runconfig#r#highlight_debug')
    " Highlight group for debugged functions.
    let g:tterminal#runconfig#r#highlight_debug = 'SpellRare'   "{{{2
endif


if !exists('g:tterminal#runconfig#r#init_code')
    " Evaluate this code on startup.
    let g:tterminal#runconfig#r#init_code = ''   "{{{2
    " let g:tterminal#runconfig#r#init_code = 'tterminalCtags()'   "{{{2
endif


if !exists('g:tterminal#runconfig#r#init_files')
    " Source these files on startup.
    let g:tterminal#runconfig#r#init_files = []   "{{{2
endif



if !exists('g:tterminal#runconfig#r#handle_qfl_expression_f')
    " An ex command as format string. Defined how the results from 
    " codetools:checkUsage are displayed.
    let g:tterminal#runconfig#r#handle_qfl_expression_f = 'cgetexpr %s | cwindow'   "{{{2
endif


if !exists('g:tterminal#runconfig#r#use_formatR')
    " If true, format code with formatR.
    let g:tterminal#runconfig#r#use_formatR = 1   "{{{2
endif


if !exists('g:tterminal#runconfig#r#formatR_options')
    " Additional arguments to formatR::tidy_source().
    let g:tterminal#runconfig#r#formatR_options = ''   "{{{2
endif


let s:prototype = {'debugged': {}
            \ }

function! tterminal#runconfig#r#New(ext) abort "{{{3
    let o = extend(a:ext, s:prototype)
    let o.cmd = join([g:tterminal#runconfig#r#cmd
                \, g:tterminal#runconfig#r#args
                \, get(o, 'save', g:tterminal#runconfig#r#save) ? '--save' : '--no-save'
                \, get(o, 'restore', g:tterminal#runconfig#r#restore) ? '--restore' : '--no-restore'
                \ ])
    return o
endf


function! s:prototype.Init() abort dict "{{{3
    Tlibtrace 'tterminal', 'Init'
    if filereadable(g:tterminal#runconfig#r#init_script)
        call tterminal#SendLine(printf('source("%s")', substitute(g:tterminal#runconfig#r#init_script, '\\', '/', 'g')), self.tterminal_bufnr)
    endif
    if !empty(g:tterminal#runconfig#r#init_code)
        call tterminal#SendLine(g:tterminal#runconfig#r#init_code, self.tterminal_bufnr)
    endif
    for filename in g:tterminal#runconfig#r#init_files
        if filereadable(filename)
            call tterminal#SendLine(printf('source("%s")', substitute(filename, '\\', '/', 'g')), self.tterminal_bufnr)
        endif
    endfor
    " if get(self, 'save', g:tterminal#runconfig#r#save)
    "     call tterminal#SendLine('option(tterminal.save = "yes")', self.tterminal_bufnr)
    " endif
    " call tterminal#SendLine('flush.console()', self.tterminal_bufnr)
endf


function! s:prototype.Exit() abort dict "{{{3
    " let l:cmd = 'q(save = getOption("tterminal.save", "no"))'
    let l:cmd = 'q()'
    Tlibtrace 'tterminal', l:cmd
    call tterminal#SendLine(l:cmd, self.tterminal_bufnr)
endf


function! s:prototype.Complete(text) abort dict "{{{3
    let l:cmd = printf('tterminalComplete(%s)', string(a:text))
    let l:cmpl = tterminal#Eval(l:cmd, [])
    Tlibtrace 'tterminal', l:cmpl
    return l:cmpl
endf


function! s:prototype.Reset() abort dict "{{{3
    call tterminal#SendKeys("\<c-c>")
endf


function! s:prototype.Debug(fn) abort dict "{{{3
    " TLogVAR fn
    if !empty(a:fn) && !get(self.debugged, a:fn, 0)
        let r = printf('{debug(%s); "ok"}', a:fn)
        let rv = tterminal#Eval(r)
        " TLogVAR rv
        if rv ==# 'ok'
            let self.debugged[a:fn] = 1
            call self.HighlightDebug()
        else
            call tterminal#Echohl('Tterminal/r: Cannot debug '. a:fn, 'ErrorMsg')
        endif
    else
        call tterminal#runconfig#r#Undebug(a:fn)
    endif
endf


function! s:prototype.Undebug(fn) abort dict "{{{3
    let fn = a:fn
    if empty(fn)
        let fn = tlib#input#List('s', 'Select function:', sort(keys(self.debugged)))
    endif
    if !empty(fn)
        if has_key(self.debugged, fn)
            let self.debugged[fn] = 0
            echom 'Tterminal/r: Undebug:' a:fn
        else
            echom 'Tterminal/r: Not a debugged function?' fn
        endif
        let r = printf('undebug(%s)', fn)
        call tterminal#SendLine(r, self.tterminal_bufnr)
        call self.HighlightDebug()
    endif
endf


function! s:prototype.HighlightDebug() abort dict "{{{3
    let bufnr = bufnr('%')
    try
        for bnr in tterminal#GetTerminalBuffers()
            exec 'hide buffer' bnr
            if b:tterminal_r_hl_init
                syntax clear TterminalRDebug
            else
                exec 'hi def link TterminalRDebug' g:tterminal#runconfig#r#highlight_debug
                let b:tterminal_r_hl_init = 1
            endif
            if !empty(self.debugged)
                let debugged = map(copy(self.debugged), 'escape(v:val, ''\'')')
                exec 'syntax match TterminalRDebug /\V\<\('. join(debugged, '\|') .'\)\>/'
            endif
        endfor
    finally
        exec 'hide buffer' bufnr
    endtry
endf


function! s:prototype.GetFilename(filename) abort dict "{{{3
    return s:GetFilename(a:filename)
endf


function! s:GetFilename(filename) abort "{{{3
    return substitute(a:filename, '\\', '/', 'g')
endf


function! tterminal#runconfig#r#Cd() abort "{{{3
    let wd = s:GetFilename(getcwd())
    call tterminal#SendLine('setwd('. string(wd) .')')
endf


" Toggle the debug status of a function.
function! tterminal#runconfig#r#Debug(fn) abort "{{{3
    let l:runconfig = tterminal#GetTerminalRunConfig()
    call l:runconfig.Debug(a:fn)
endf


" Undebug a debugged function.
function! tterminal#runconfig#r#Undebug(fn) abort "{{{3
    let l:runconfig = tterminal#GetTerminalRunConfig()
    call l:runconfig.Undebug(a:fn)
endf


function! tterminal#runconfig#r#CheckUsage() abort "{{{3
    let checks = tterminal#Eval('codetools::checkUsageEnv(.GlobalEnv)')
    Tlibtrace 'tterminal', checks
    let efm = &errorformat
    let &errorformat = '%m (%f:%l-%*[0-9]),%m (%f:%l)'
    try
        exec printf(g:tterminal#runconfig#r#handle_qfl_expression_f, 'checks')
    finally
        let &errorformat = efm
    endtry
endf


function! tterminal#runconfig#r#Format(type, ...) abort "{{{3
    let sel_save = &selection
    let &selection = 'inclusive'
    let reg_save = @@
    try
        if a:0  " Invoked from Visual mode, use gv command.
            let lbeg = line("'<")
            let lend = line("'>")
        else
            let lbeg = line("'[")
            let lend = line("']")
        endif
        let cnt = lend - lbeg
        call s:FormatR(lbeg, cnt + 1)
    finally
        let &selection = sel_save
        let @@ = reg_save
    endtry
endf


function! s:FormatR(lnum, count) abort "{{{3
    let lend = a:lnum + a:count - 1
    let lines = getline(a:lnum, lend)
    let lines = map(lines, '''"''. escape(v:val, ''"\'') .''"''')
    let code = join(lines, ', ')
    let options = empty(g:tterminal#runconfig#r#formatR_options) ? '' : (', '. g:tterminal#runconfig#r#formatR_options)
    let cmd = printf('suppressWarnings(formatR::tidy_source(text = c(%s)%s))', code, options)
    let formatted = tterminal#Eval(cmd)
    if a:count > 1
        exec a:lnum .','. lend 'delete'
    else
        exec a:lnum 'delete'
    endif
    call append(a:lnum - 1, split(formatted, '\n'))
    return 0
endf


" In R terminals, the following additional maps are set (<TML> is 
" |g:tterminal#map_leader|):
"
" <TML>cd ... Set the working directory in R to VIM's working directory
" <TML>d  ... Debug the word under the cursor
" <TML>i  ... Inspect the word under the cursor
" <TML>k  ... Get help on the word under the cursor
" <TML>s  ... Source the current file
" <TML>s  ... Quicklist
"
" The following maps require codetools to be installed in R:
" <TML>cu ... Run checkUsage on the global environment
"
" The following maps require formatR to be installed in R:
" <TML>f{motion} ... Format some code
" <TML>f  ... In visual mode: format some code
" <TML>ff ... Format the current paragraph
"
" Omni completion (see 'omnifunc') is enabled.
function! tterminal#runconfig#r#SetupBuffer(runconfig) abort "{{{3
    Tlibtrace 'tterminal', a:runconfig
    exec 'nnoremap <buffer>' g:tterminal#map_leader .'cd :call tterminal#runconfig#r#Cd()<cr>'
    exec 'nnoremap <buffer>' g:tterminal#map_leader .'cu :call tterminal#runconfig#r#CheckUsage()<cr>'
    exec 'nnoremap <buffer>' g:tterminal#map_leader .'d :call tterminal#runconfig#r#Debug(expand("<cword>"))<cr>'
    exec 'xnoremap <buffer>' g:tterminal#map_leader .'d ""y:call tterminal#runconfig#r#Debug(@")<cr>'
    if g:tterminal#runconfig#r#use_formatR
        exec 'nmap <buffer>' g:tterminal#map_leader .'f :set opfunc=tterminal#runconfig#r#Format<CR>g@'
        exec 'xmap <buffer>' g:tterminal#map_leader .'f :<C-U>call tterminal#runconfig#r#Format(visualmode(), 1)<CR>'
        exec 'nmap <buffer>' g:tterminal#map_leader .'ff' g:tterminal#map_leader .'ip'
    endif
    exec 'nnoremap <buffer>' g:tterminal#map_leader .'i :call tterminal#SendLine((''str(<c-r><c-w>)'')<cr>'
    exec 'nnoremap <buffer>' g:tterminal#map_leader .'k :call tterminal#SendLine(''tterminalKeyword(<c-r><c-w>, "<c-r><c-w>")'')<cr>'
    exec 'nnoremap <buffer>' g:tterminal#map_leader .'q :call tterminal#quicklist#Select(expand("<cword>"))<cr>'
    exec 'xnoremap <buffer>' g:tterminal#map_leader .'q :call tterminal#quicklist#Select(join(tlib#selection#GetSelection("v"), " "))<cr>'
    if &l:keywordprg =~# '^\%(man\>\|:help$\|$\)'
        nnoremap <buffer> K :call tterminal#SendLine('?"<c-r><c-w>"')<cr>
    endif
    if &buftype !=# 'nofile'
        let filename = substitute(expand('%:p'), '\\', '/', 'g')
        exec 'nnoremap <buffer>' g:tterminal#map_leader .'s :call tterminal#SendLine("source('. string(filename) .')")<cr>'
    endif
    call tterminal#complete#SetOmnifunc()
    syntax match Comment '^\s*#.*$'
    return tterminal#runconfig#r#New(a:runconfig)
endf


function! tterminal#runconfig#r#UndoBuffer(runconfig) abort "{{{3
    Tlibtrace 'tterminal', bufnr('')
    exec 'nunmap <buffer>' g:tterminal#map_leader .'cd'
    exec 'nunmap <buffer>' g:tterminal#map_leader .'cu'
    exec 'nunmap <buffer>' g:tterminal#map_leader .'d'
    exec 'xunmap <buffer>' g:tterminal#map_leader .'d'
    exec 'nunmap <buffer>' g:tterminal#map_leader .'i'
    exec 'nunmap <buffer>' g:tterminal#map_leader .'k'
    exec 'nunmap <buffer>' g:tterminal#map_leader .'q'
    exec 'xunmap <buffer>' g:tterminal#map_leader .'q'
    if g:tterminal#runconfig#r#use_formatR
        exec 'nunmap <buffer>' g:tterminal#map_leader .'f'
        exec 'xunmap <buffer>' g:tterminal#map_leader .'f'
        exec 'nunmap <buffer>' g:tterminal#map_leader .'ff'
    endif
    if &l:keywordprg =~# '^\%(man\>\|help$\|$\)'
        nunmap <buffer> K
    endif
    if &buftype !=# 'nofile'
        exec 'nunmap <buffer>' g:tterminal#map_leader .'s'
    endif
    call tterminal#complete#UnsetOmnifunc()
endf

