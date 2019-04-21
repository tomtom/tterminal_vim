" @Author:      Tom Link (mailto:micathom AT gmail com?subject=[vim])
" @Website:     https://github.com/tomtom
" @License:     GPL (see http://www.gnu.org/licenses/gpl.txt)
" @Last Change: 2019-04-13
" @Revision:    2


if !exists('g:tterminal#quicklist#handlers')
    let g:tterminal#quicklist#handlers = [{'key': 5, 'agent': 'tterminal#quicklist#EditItem', 'key_name': '<c-e>', 'help': 'Edit item'}]   "{{{2
endif


function! tterminal#quicklist#Select(word) "{{{3
    Tlibtrace 'tterminal', a:word
    if !exists('g:loaded_tlib')
        throw 'tterminal#quicklist#Select requires tlib to be installed'
    endif
    let l:runconfig = tterminal#GetTerminalRunConfig()
    if exists('g:tterminal#runconfig#'. rdef.name .'#quicklist')
        let quicklist = g:tterminal#runconfig#r#quicklist
    else
        let quicklist = []
    endif
    if !empty(quicklist)
        let filename = expand('%:p')
        if has_key(l:runconfig, 'GetFilename')
            let filename = l:runconfig.GetFilename(filename)
        endif
        let dict = {
                    \ 'filename': filename,
                    \ 'cword': a:word}
        let ql = map(copy(quicklist), 'tlib#string#Format(v:val, dict)')
        let code = tlib#input#List('s', 'Select function:', ql, g:tterminal#quicklist#handlers)
        if !empty(code)
            call tterminal#SendLine(code)
        endif
    endif
endf


function! tterminal#quicklist#EditItem(world, items) "{{{3
    " TLogVAR a:items
    let item = get(a:items, 0, '')
    call inputsave()
    let item = input('Edit> ', item)
    call inputrestore()
    " TLogVAR item
    if !empty(item)
        let a:world.rv = item
        let a:world.state = 'picked'
        return a:world
    endif
    let a:world.state = 'redisplay'
    return a:world
endf


