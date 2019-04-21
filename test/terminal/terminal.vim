function! Tapi_Impression(bufnum, arglist)
    if len(a:arglist) == 2
        call inputdialog(string(a:arglist))
        " echomsg "impression " . a:arglist[0]
        " echomsg "count " . a:arglist[1]
    endif
endfunc

let s:sbufnr = bufnr('')
let s:winid = win_getid()
terminal ++close
let s:tbufnr = bufnr('')
call win_gotoid(s:winid)
call term_sendkeys(s:tbufnr, 'printf ''\x1b]51;["call", "Tapi_Impression", ["play", 14]]\07''')
sleep 1
call term_sendkeys(s:tbufnr, "\<c-d>")

