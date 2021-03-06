" @Author:      Tom Link (mailto:micathom AT gmail com?subject=[vim])
" @Website:     https://github.com/tomtom
" @License:     GPL (see http://www.gnu.org/licenses/gpl.txt)
" @Last Change: 2019-05-06
" @Revision:    441


if !exists('g:tterminal#map_leader')
    let g:tterminal#map_leader = '<localleader>e'   "{{{2
endif


if !exists('g:tterminal#name_includes_dir')
    let g:tterminal#name_includes_dir = 1   "{{{2
endif


if !exists('g:tterminal#cmd_map')
    " :read: let g:tterminal#cmd_map = {...}   "{{{2
    let g:tterminal#cmd_map = {
                \ }
endif
if exists('g:tterminal#cmd_map_user')
    let g:tterminal#cmd_map = extend(g:tterminal#cmd_map, g:tterminal#cmd_map_user)
endif


if !exists('g:tterminal#runconfigs')
    " :read: let g:tterminal#runconfigs = {...}   "{{{2
    let g:tterminal#runconfigs = {'r': {'cmd_name': 'R'}
                \ , 'r-nosave': {'cmd_name': 'R', 'save': 0, 'restore': 0}
                \ }
endif
if exists('g:tterminal#runconfigs_user')
    let g:tterminal#runconfigs = extend(g:tterminal#runconfigs, g:tterminal#runconfigs_user)
endif


if !exists('g:tterminal#rows')
    let g:tterminal#rows = 10   "{{{2
endif


if !exists('g:tterminal#cols')
    let g:tterminal#cols = 0   "{{{2
endif


if !exists('g:tterminal#interaction_mode')
    " Possible values:
    " - terminal
    " - scrape
    " - file
    let g:tterminal#interaction_mode = has('win32') || has('win64') ? 'file' : 'terminal'   "{{{2
endif


let s:prototype = {}

function! s:prototype.UnwrapScrapedOutput(lines) abort dict "{{{3
    Tlibtrace 'tterminal', a:lines
    for l:lnum2 in range(len(a:lines) - 1, 0, -1)
        let l:lend = a:lines[l:lnum2]
        if l:lend =~# '^'. self.next_end_marker .'$'
            for l:lnum1 in range(l:lnum2 - 1, 0, -1)
                let l:lbeg = a:lines[l:lnum1]
                if l:lbeg =~# '^'. self.next_begin_marker .'$'
                    let l:lines = a:lines[l:lnum1 + 1 : l:lnum2 -1]
                    return [1, join(l:lines, '\n')]
                endif
            endfor
            break
        endif
    endfor
    return [0, '']
endf


let s:terminals = {}

function! tterminal#Terminal(...) abort "{{{3
    let l:cmd_prefix = a:0 >= 1 ? a:1 : ''
    let l:runconfig_name = a:0 >= 2 && a:2 !=# '-' ? a:2 : &filetype
    let l:terminal_id = a:0 >= 3 ? a:3 : ''
    Tlibtrace 'tterminal', l:cmd_prefix, l:terminal_id, l:runconfig_name
    if empty(l:terminal_id)
        if g:tterminal#name_includes_dir
            let l:terminal_id = getcwd()
        endif
        let l:terminal_id .= '*'. l:runconfig_name
    endif
    if has_key(s:terminals, l:terminal_id)
        let l:runconfig = tterminal#GetTerminalIdRunConfig(l:terminal_id)
        let l:runconfig_name = l:runconfig.runconfig_name
    else
        let l:runconfig = deepcopy(get(g:tterminal#runconfigs, l:runconfig_name, {}))
        let l:runconfig = extend(l:runconfig, s:prototype)
        if empty(l:runconfig) && !executable(l:runconfig_name)
            let l:runconfig.cmd_name = &shell
        endif
        let l:runconfig['runconfig_name'] = l:runconfig_name
        let l:runconfig['terminal_id'] = l:terminal_id
    endif
    Tlibtrace 'tterminal', l:runconfig_name, l:runconfig
    if has_key(l:runconfig, 'cmd_prefix')
        if empty(l:cmd_prefix)
            let l:cmd_prefix = l:runconfig.cmd_prefix
        endif
    elseif !empty(l:cmd_prefix)
        let l:runconfig['cmd_prefix'] = l:cmd_prefix
    endif
    let l:bufnr = bufnr('')
    let l:winid = win_getid()
    let l:terminal_bufnr = s:GetTerminalBufnr()
    if l:terminal_bufnr != -1
        call s:ShowTerminal(l:cmd_prefix, l:terminal_bufnr)
    elseif has_key(s:terminals, l:terminal_id)
        call setbufvar(l:bufnr, 'terminal_id', l:terminal_id)
        let l:runconfig = s:SetupBuffer(l:bufnr, l:terminal_id, l:runconfig)
        let l:terminal_bufnr = s:GetTerminalBufnr(-1, 1)
        call s:ShowTerminal(l:cmd_prefix, l:terminal_bufnr)
        call add(s:terminals[l:terminal_id].buffers, l:bufnr)
    else
        let l:runconfig = s:SetupBuffer(l:bufnr, l:terminal_id, l:runconfig)
        call setbufvar(l:bufnr, 'terminal_id', l:terminal_id)
        let l:cmd_name = get(l:runconfig, 'cmd_name', l:runconfig.runconfig_name)
        let l:cmd = get(l:runconfig, 'cmd', get(g:tterminal#cmd_map, l:cmd_name, l:cmd_name))
        " let l:terminal = 'terminal ++norestore ++close ++kill=quit'
        " if l:cmd_prefix =~# '\<vert\%[ical]\>'
        "     let l:cols = get(l:runconfig, 'cols', g:tterminal#cols)
        "     if l:cols > 0
        "         let l:terminal .= ' ++cols='. l:cols
        "     endif
        " else
        "     let l:rows = get(l:runconfig, 'rows', g:tterminal#rows)
        "     if l:rows > 0
        "         let l:terminal .= ' ++rows='. l:rows
        "     endif
        " endif
        " exec l:cmd_prefix l:terminal l:cmd
        " let l:runconfig.tterminal_bufnr = bufnr('')
        """ Use term_start() instead of :terminal for extended options
        """ Rely on exit_cb instead of eof_chars -> allows for cleanup
        let l:toptions = {'term_name': l:terminal_id
                    \, 'exit_cb': function('s:ExitCb', [l:terminal_id]) 
                    \, 'norestore': 1
                    \, 'term_finish': 'close'
                    \, 'term_kill': 'quit'
                    \}
        " if has_key(l:runconfig, 'eof')
        "     let l:toptions.eof_chars = l:runconfig.eof
        " endif
        if l:cmd_prefix =~# '\<vert\%[ical]\>'
            let l:toptions.vertical = 1
            let l:cols = get(l:runconfig, 'cols', g:tterminal#cols)
            if l:cols > 0
                let l:toptions.term_cols = l:cols
            endif
        else
            let l:rows = get(l:runconfig, 'rows', g:tterminal#rows)
            if l:rows > 0
                let l:toptions.term_rows = l:rows
            endif
        endif
        let l:runconfig.tterminal_bufnr = term_start(l:cmd, l:toptions)
        if has_key(l:runconfig, 'wait_init')
            call term_wait(l:runconfig.tterminal_bufnr, l:runconfig.wait_init)
        endif
        let l:runconfig = s:SetupTerminal(l:runconfig)
        let s:terminals[l:terminal_id] = {'runconfig': l:runconfig, 'buffers': [l:bufnr]}
    endif
    call feedkeys("\<c-w>N")
    call win_gotoid(l:winid)
endf


function! s:ShowTerminal(cmd_prefix, bufnr) abort "{{{3
    Tlibtrace 'tterminal', a:cmd_prefix, a:bufnr
    if bufwinnr(a:bufnr) == -1
        exec a:cmd_prefix 'sbuffer' a:bufnr
    endif
endf


function! s:ExitCb(terminal_id, job, status) abort "{{{3
    let l:terminal_bufnr = s:GetTerminalBufnr(-2, 0, a:terminal_id)
    if !getbufvar(l:terminal_bufnr, 'tterminal_shutdown', 0)
        let l:buffers = tterminal#GetTerminalBuffers({}, a:terminal_id)
        for l:bufnr in l:buffers
            call s:UndoBuffer(l:bufnr, a:terminal_id)
        endfor
    endif
endf


function! s:SetupTerminal(runconfig) abort "{{{3
    Tlibtrace 'tterminal', a:runconfig
    let l:runconfig = a:runconfig
    " let b:tterminal_runconfig = l:runconfig
    if has_key(l:runconfig, 'init')
        for l:line in l:runconfig.init
            call tterminal#SendLine(l:line, l:runconfig.tterminal_bufnr)
        endfor
    endif
    if has_key(l:runconfig, 'Init')
        call l:runconfig.Init()
    endif
    try
        let l:runconfig = tterminal#runconfig#{a:runconfig.runconfig_name}#SetupTerminal(l:runconfig)
    catch /^Vim\%((\a\+)\)\=:E117/
        " echom 'DBG No SetupTerminal fn for' a:runconfig.runconfig_name
    endtry
    return l:runconfig
endf


function! s:SetupBuffer(bufnr, terminal_id, runconfig) abort "{{{3
    Tlibtrace 'tterminal', a:bufnr, a:terminal_id
    let l:runconfig = a:runconfig
    call tterminal#EnableBuffer()
    if b:tterminal_enabled != 2
        let b:tterminal_enabled = 2
        augroup Tterminal
            exec 'autocmd BufUnload <buffer='. a:bufnr .'> call s:DisconnectBuffer('. string(a:terminal_id) .', '. a:bufnr .')'
        augroup END
        try
            let l:runconfig = tterminal#runconfig#{a:runconfig.runconfig_name}#SetupBuffer(l:runconfig)
        catch /^Vim\%((\a\+)\)\=:E117/
            " echom 'DBG No SetupBuffer fn for' l:runconfig.runconfig_name
            Tlibtrace 'tterminal', v:exception
        endtry
        Tlibtrace 'tterminal', l:runconfig
    endif
    return l:runconfig
endf


function! s:UndoBuffer(...) abort "{{{3
    let l:bufnr = a:0 >= 1 ? a:1 : bufnr('')
    let l:terminal_id = a:0 >= 2 ? a:2 : getbufvar(l:bufnr, 'terminal_id', '')
    Tlibtrace 'tterminal', l:bufnr, l:terminal_id, bufnr('')
    if getbufvar(l:bufnr, 'tterminal_enabled', 0) == 2
        " if empty(l:terminal_id)
        "     throw 'Tterminal: Not connected to a terminal'
        " endif
        call setbufvar(l:bufnr, 'tterminal_enabled', 1)
        exec 'autocmd! Tterminal BufUnload <buffer='. l:bufnr .'>'
        let l:runconfig = tterminal#GetTerminalIdRunConfig(l:terminal_id)
        let l:cbufnr = bufnr('')
        if l:cbufnr != l:bufnr
            exec 'buffer!' l:bufnr
        endif
        try
            call tterminal#runconfig#{l:runconfig.runconfig_name}#UndoBuffer(l:runconfig)
        catch /^Vim\%((\a\+)\)\=:E117/
            " echom 'DBG No SetupBuffer fn for' l:runconfig.runconfig_name
            Tlibtrace 'tterminal', v:exception
        finally
            if l:cbufnr != l:bufnr && bufexists(l:cbufnr)
                exec 'buffer!' l:cbufnr
            endif
        endtry
        call s:DisconnectBuffer(l:terminal_id, l:bufnr)
        call setbufvar(l:bufnr, 'tterminal_id', '')
    endif
endf


function! s:DisconnectBuffer(terminal_id, bufnr) abort "{{{3
    Tlibtrace 'tterminal', a:terminal_id, a:bufnr
    let l:tdef = tterminal#GetTerminalDef(a:terminal_id)
    if empty(l:tdef)
        throw 'Tterminal: Internal error: Close lost tterminal buffer: '. a:bufnr .':'. a:terminal_id
    else
        let l:bidx = index(l:tdef.buffers, a:bufnr)
        if l:bidx == -1
            throw 'Tterminal: Internal error: Close unregistered buffer: '. a:bufnr
        else
            call remove(l:tdef.buffers, l:bidx)
            Tlibtrace 'tterminal', l:tdef.buffers
            if empty(l:tdef.buffers)
                call s:ExitTerminal(a:terminal_id, l:tdef)
            endif
        endif
    endif
endf


function! s:ExitTerminal(terminal_id, tdef) abort "{{{3
    let l:runconfig = tterminal#GetTerminalDefRunConfig(a:tdef)
    try
        if has_key(l:runconfig, 'Exit')
            " let l:terminal_bufnr = s:GetTerminalBufnr(a:bufnr, 1, a:terminal_id)
            let l:terminal_bufnr = l:runconfig.tterminal_bufnr
            if !getbufvar(l:terminal_bufnr, 'tterminal_shutdown', 0)
                call setbufvar(l:terminal_bufnr, 'tterminal_shutdown', 1)
            endif
            try
                return l:runconfig.Exit()
            finally
                call setbufvar(l:terminal_bufnr, 'tterminal_shutdown', 0)
            endtry
        endif
    finally
        unlet! s:terminals[a:terminal_id]
    endtry
endf


function! tterminal#SendLine(...) abort "{{{3
    Tlibtrace 'tterminal', a:000
    let l:text = (a:0 >= 1 ? a:1 : getline('.'))
    let l:terminal_bufnr = a:0 >= 2 ? a:2 : s:GetTerminalBufnr()
    if type(l:text) ==# v:t_list
        let l:keys = join(l:text, "\<cr>") ."\<cr>"
    else
        let l:keys = l:text ."\<cr>"
    endif
    call tterminal#SendKeys(l:keys, l:terminal_bufnr)
endf


function! tterminal#SendKeys(keys, ...) abort "{{{3
    let l:terminal_bufnr = a:0 >= 1 ? a:1 : s:GetTerminalBufnr()
    Tlibtrace 'tterminal', l:terminal_bufnr, &filetype, a:keys
    if l:terminal_bufnr == -1
        if index(g:tterminal_autoenable_filetypes, &filetype) != -1
            " Tterminal
            call tterminal#Terminal('')
            let l:terminal_bufnr = s:GetTerminalBufnr()
            Tlibtrace 'tterminal', l:terminal_bufnr
            if l:terminal_bufnr == -1
                throw 'Failed to automatically start tterminal!'
            endif
        else
            throw 'Not a tterminal!'
        endif
    endif
    call term_sendkeys(l:terminal_bufnr, a:keys)
endf


function! tterminal#Eval(code, ...) abort "{{{3
    let l:default = a:0 >= 1 ? a:1 : ''
    Tlibtrace 'tterminal', a:code, l:default, bufnr('')
    let l:terminal_id = s:GetTerminalID(-1, 1)
    let l:terminal_bufnr = s:GetTerminalBufnr(-1, 1, l:terminal_id)
    let l:code = a:code
    let l:runconfig = tterminal#GetTerminalIdRunConfig(l:terminal_id)
    let l:interaction_mode = get(l:runconfig, 'interaction_mode', g:tterminal#interaction_mode)
    let l:code = l:runconfig.WrapCode(a:code, l:interaction_mode)
    let l:result = s:GetResult_{l:interaction_mode}(l:runconfig, l:terminal_bufnr, l:code, l:default)
    Tlibtrace 'tterminal', l:result
    return l:result
endf


function! s:GetResult_terminal(runconfig, terminal_bufnr, code, default) abort "{{{3
    call tterminal#SendKeys(a:code ."\n", a:terminal_bufnr)
    try
        for l:wait in range(10)
            call term_wait(a:terminal_bufnr, 200)
            if exists('s:tterminal_eval_result')
                break
            endif
        endfor
        return exists('s:tterminal_eval_result') ? s:tterminal_eval_result : a:default
    finally
        if exists('s:tterminal_eval_result')
            unlet s:tterminal_eval_result
        endif
    endtry
endf


function! Tapi_TterminalEvalCb(bufnum, arglist)
    let s:tterminal_eval_result = a:arglist
endf


function! s:GetResult_scrape(runconfig, terminal_bufnr, code, default) abort "{{{3
    let l:llnum = term_getsize(l:terminal_bufnr)[0] + 1
    let l:output = []
    let l:json = ''
    let l:done = 0
    let l:result = a:default
    call tterminal#SendKeys(a:code ."\n", a:terminal_bufnr)
    for l:wait in range(10)
        call term_wait(a:terminal_bufnr, 200)
        for l:clnum in range(l:llnum, term_getsize(a:terminal_bufnr)[0])
            call add(l:output, term_getline(a:terminal_bufnr, l:clnum))
            let l:llnum += 1
        endfor
        Tlibtrace 'tterminal', l:llnum, l:wait, l:output
        let [l:done, l:json] = a:runconfig.UnwrapScrapedOutput(l:output)
        if l:done
            let l:result = json_decode(l:json)
            break
        endif
    endfor
    return l:result
endf


function! s:GetResult_file(runconfig, terminal_bufnr, code, default) abort "{{{3
    let l:tmpfile = a:runconfig.tmpfile
    call tterminal#SendKeys(a:code ."\n", a:terminal_bufnr)
    for l:wait in range(10)
        call term_wait(a:terminal_bufnr, 200)
        if filereadable(l:tmpfile)
            try
                let l:json = join(readfile(l:tmpfile), '\n')
                return json_decode(l:json)
            finally
                unlet! a:runconfig.tmpfile
                call delete(l:tmpfile)
            endtry
        endif
    endfor
    return a:default
endf


function! s:GetTerminalID(...) abort "{{{3
    let l:bufnr = a:0 >= 1 && a:1 != -1 ? a:1 : bufnr('')
    let l:must_work = a:0 >= 2 ? a:2 : 0
    let l:terminal_id = getbufvar(l:bufnr, 'terminal_id', '')
    if l:must_work && empty(l:terminal_id)
        throw 'Tterminal ID: Buffer is not connected to any terminal'
    else
        return l:terminal_id
    endif
endf


function! s:GetTerminalBufnr(...) abort "{{{3
    let l:bufnr = a:0 >= 1 && a:1 != -1 ? a:1 : bufnr('')
    let l:must_work = a:0 >= 2 ? a:2 : 0
    let l:terminal_id = a:0 >= 3 ? a:3 : getbufvar(l:bufnr, 'terminal_id', '')
    Tlibtrace 'tterminal', l:bufnr, l:terminal_id, l:must_work
    if !empty(l:terminal_id)
        let l:tdef = get(s:terminals, l:terminal_id, {})
        if !empty(l:tdef)
            let l:runconfig = get(l:tdef, 'runconfig', {})
            if !empty(l:runconfig)
                let l:terminal_bufnr = get(l:runconfig, 'tterminal_bufnr', -1)
                Tlibtrace 'tterminal', l:terminal_bufnr
                if l:terminal_bufnr != -1
                    return l:terminal_bufnr
                endif
            endif
        endif
    endif
    if l:must_work
        throw 'Tterminal: Buffer is not connected to any terminal'
    else
        return -1
    endif
endf


function! tterminal#GetTerminalDef(...) abort "{{{3
    let l:terminal_id = a:0 >= 1 ? a:1 : getbufvar('', 'terminal_id', '')
    if !empty(l:terminal_id)
        return get(s:terminals, l:terminal_id, {})
    else
        throw 'Tterminal: Buffer is not connected to any terminal'
    endif
endf


function! tterminal#GetTerminalBuffers(...) abort "{{{3
    let l:tdef = a:0 >= 1 && !empty(a:1) ? a:1 : call(function('tterminal#GetTerminalDef'), a:000[1:-1])
    return get(l:tdef, 'buffers', [])
endf


function! tterminal#GetTerminalDefRunConfig(tdef) abort "{{{3
    return get(a:tdef, 'runconfig', {})
endf


function! tterminal#GetTerminalIdRunConfig(terminal_id) abort "{{{3
    let l:tdef = tterminal#GetTerminalDef(a:terminal_id)
    return tterminal#GetTerminalDefRunConfig(l:tdef)
endf


function! tterminal#GetTerminalRunConfig() abort "{{{3
    let l:terminal_id = s:GetTerminalID(-1, 1)
    return tterminal#GetTerminalIdRunConfig(l:terminal_id)
endf


function! tterminal#Echohl(text, ...) abort dict "{{{3
    let l:hl = a:0 >= 1 ? a:1 : 'WarningMsg'
    exec 'echohl' l:hl
    try
        echom a:text
    finally
        echohl NONE
    endtry
endf


function! tterminal#EnableBuffer() abort "{{{3
    if !getbufvar('', 'tterminal_enabled', 0)
        let b:tterminal_enabled = 1
        nnoremap <buffer> <c-cr> :call tterminal#SendLine()<cr>j
        inoremap <buffer> <c-cr> <c-\><c-o>:call tterminal#SendLine()<cr><Down>
        if exists('g:loaded_tlib')
            vnoremap <buffer> <c-cr> :call tterminal#SendLine(tlib#selection#GetSelection("v"))<cr>
        endif
        return 1
    else
        return 0
    endif
endf


" function! tterminal#DisableBuffer(...) abort "{{{3
"     let l:fully = a:0 >= 1 ? a:1 : 0
"     let l:bufnr = a:0 >= 2 ? a:2 : bufnr('')
"     call s:UndoBuffer(l:bufnr)
"     if l:fully && getbufvar(l:bufnr, 'tterminal_enabled', 0) == 1
"         nunmap <buffer> <c-cr>
"         iunmap <buffer> <c-cr>
"         if exists('g:loaded_tlib')
"             vunmap <buffer> <c-cr>
"         endif
"         unlet b:tterminal_enabled
"     endif
" endf

