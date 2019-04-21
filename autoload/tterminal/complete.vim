" @Author:      Tom Link (mailto:micathom AT gmail com?subject=[vim])
" @Website:     https://github.com/tomtom
" @License:     GPL (see http://www.gnu.org/licenses/gpl.txt)
" @Last Change: 2019-04-20
" @Revision:    10


function! tterminal#complete#SetOmnifunc() abort "{{{3
    if exists('g:loaded_tlib') && &l:omnifunc !=# 'tterminal#complete#OmniComplete'
        if !empty(&l:omnifunc)
            let b:tterminal_orig_omnifunc = &l:omnifunc
        endif
        setlocal omnifunc=tterminal#complete#OmniComplete
    endif
endf


function! tterminal#complete#UnsetOmnifunc() abort "{{{3
    if exists('g:loaded_tlib') && &omnifunc ==# 'tterminal#complete#OmniComplete'
        if exists('b:tterminal_orig_omnifunc')
            let &l:omnifunc = b:tterminal_orig_omnifunc
            unlet! b:tterminal_orig_omnifunc
        else
            setlocal omnifunc=
        endif
    endif
endf


function! tterminal#complete#OmniComplete(findstart, base) abort "{{{3
    Tlibtrace 'tterminal', a:findstart, a:base, bufnr('')
    if !exists('g:loaded_tlib')
        throw 'tterminal#complete#OmniComplete requires tlib to be installed'
    endif
    let l:runconfig = tterminal#GetTerminalRunConfig()
    if !has_key(l:runconfig, 'Complete')
        if exists('b:tterminal_orig_omnifunc')
            let &l:omnifunc = b:tterminal_orig_omnifunc
            unlet! b:tterminal_orig_omnifunc
            return empty(&l:omnifunc) ? [] : call(&l:omnifunc, [a:findstart, a:base])
        endif
    else
        if a:findstart
            let line = getline('.')
            let start = col('.') - 1
            let rx = has_key(l:runconfig, 'GetKeywordRx') ? l:runconfig.GetKeywordRx() : '\k'
            while start > 0 && line[start - 1] =~ rx
                let start -= 1
            endwhile
            Tlibtrace 'tterminal', start
            return start
        else
            let values = l:runconfig.Complete(a:base)
            Tlibtrace 'tterminal', len(values), values
            if exists('b:tterminal_orig_omnifunc') && !empty(b:tterminal_orig_omnifunc) && exists('*'. b:tterminal_orig_omnifunc)
                let values += call(b:tterminal_orig_omnifunc, [a:findstart, a:base])
            endif
            return tlib#list#Uniq(values)
        endif
    endif
endf

