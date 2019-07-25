autocmd BufEnter * call s:associate_with_tab()
autocmd BufEnter * call s:calculate_airline_buffers_var()
autocmd TabClosed * call s:remove_tab_from_buffers()
autocmd TabNew,TabClosed * call s:associate_tabs_with_ids()
""autocmd TabEnter * call s:set_tab_excludes()
autocmd SessionLoadPost * call s:load_from_session()

command! -nargs=0 AirlineBuffersPrevious call s:buffer_nav(-1)
command! -nargs=0 AirlineBuffersNext call s:buffer_nav(1)
command! -nargs=0 AirlineBuffersClose call s:close_buffer()
command! -nargs=0 AirlineBuffersFirst call s:buffer_nav('first')
command! -nargs=0 AirlineBuffersLast call s:buffer_nav('last')
command! -nargs=1 AirlineBuffersGoTo call s:buffer_goto(<f-args>)
command! -nargs=1 AirlineBuffersMove call s:move_buffer(<f-args>)

if !exists('g:Airline_buffers')
    let g:Airline_buffers = "{}"
endif

if !exists('g:Airline_tabs')
    let g:Airline_tabs = "[]"
endif

let s:buflist_path = expand('<sfile>:p:h') . '/../buflist.vim'

function! s:load_from_session()
    let Func = function('s:do_load_from_session')
    let timer = timer_start(0, Func)
endfunction

function! s:do_load_from_session(...)
    let tabs = []
    let buffers = {}
    let sort_orders = {}
    if exists('g:Airline_tabs')
        let tabs = eval(g:Airline_tabs)
    endif
    if exists('g:Airline_buffers')
        let buffers = eval(g:Airline_buffers)
    endif
    if exists('g:Airline_buffers_order')
        let sort_orders = eval(g:Airline_buffers_order)
    endif

    for idx in range(len(tabs))
        call settabvar(idx + 1, 'tab_id', tabs[idx])
    endfor

    if len(tabs) == 0
        call s:new_tab_id()
        for info in getbufinfo()
            let info.variables.tabpages = [t:tab_id]
        endfor
    else
        for info in getbufinfo()
            if has_key(buffers, info.name)
                let info.variables.tabpages = buffers[info.name]
            endif

            if has_key(sort_orders, info.name)
                let info.variables.sort_order = sort_orders[info.name]
            endif
        endfor
    endif

    ""let Func = function('s:set_tab_excludes')
    ""let timer = timer_start(0, Func)
endfunction

function! s:associate_tabs_with_ids()
    if exists('g:SessionLoad')
        return
    endif
    let ids = []
    for info in gettabinfo()
        if !has_key(info.variables, 'tab_id')
            let info.variables.tab_id = localtime()
        endif
        call add(ids, info.variables.tab_id)
    endfor

    let g:Airline_tabs = string(ids)
endfunction

function! s:associate_with_tab()
    if exists('g:SessionLoad')
        return
    endif
    call s:new_tab_id()
    if !exists('b:tabpages')
        let b:tabpages = []
    endif

    if index(b:tabpages, t:tab_id) == -1
        call add(b:tabpages, t:tab_id)
    endif

    call s:generate_sort_order()
endfunction

function! s:calculate_airline_buffers_var()
    if exists('g:SessionLoad')
        return
    endif
    let buffers = {}
    let sort_orders = {}
    for info in getbufinfo()
        if !info.listed
            continue
        endif
        let tabs = []
        if has_key(info.variables, 'tabpages')
            let tabs = info.variables.tabpages
        endif
        if has_key(info.variables, 'sort_order')
            let sort_orders[info.name] = info.variables.sort_order
        endif
        let buffers[info.name] = tabs
    endfor

    let g:Airline_buffers = string(buffers)
    let g:Airline_buffers_order = string(sort_orders)
endfunction

function! s:remove_tab_from_buffers()
    if exists('g:SessionLoad')
        return
    endif
    let ids = []
    for info in gettabinfo()
        if has_key(info.variables, 'tab_id')
            call add(ids, info.variables.tab_id)
        endif
    endfor

    for info in getbufinfo()
        if has_key(info.variables, 'tabpages')
            call filter(info.variables.tabpages, {idx, val -> index(ids, val) != -1})
        endif
    endfor

    call s:calculate_airline_buffers_var()
endfunction

function! s:new_tab_id()
    if !exists('t:tab_id')
        let t:tab_id = localtime()
    endif
endfunction

function! Airline_sort_buffers(b1, b2)
    let o1 = getbufvar(a:b1, 'sort_order', bufnr(a:b1))
    let o2 = getbufvar(a:b2, 'sort_order', bufnr(a:b2))

    return o1 > o2 ? 1 : -1
endfunction

function! airline#extensions#tabline#formatters#foo#get_tab_buffers()
    if exists('g:SessionLoad')
        return 
    endif
    call s:new_tab_id()

    let result = {'buffers': [], 'current': bufnr('%')}

    for info in getbufinfo()
        if has_key(info.variables, 'tabpages') && index(info.variables.tabpages, t:tab_id) != -1 && info.listed && info.name != ''
            call add(result.buffers, info.bufnr)
        endif
    endfor

    call sort(result.buffers, "Airline_sort_buffers")

    return result
endfunction

function! s:close_buffer()
    if exists('g:SessionLoad')
        return
    endif
    let nr = bufnr('#')
    let buffers = airline#extensions#tabline#formatters#foo#get_tab_buffers()
    let tabpages = b:tabpages
    let name = bufname('%')
    if name == ''
        execute "bdelete"
        execute "buffer " . nr
        return
    endif
    if exists('t:tab_id') && exists('b:tabpages')
        call filter(b:tabpages, {idx, val -> val != t:tab_id})
    endif
    if nr != -1 && index(buffers.buffers, nr) != -1
        execute "buffer " . nr
    elseif len(buffers.buffers) > 1
        let i = len(buffers.buffers) - 1
        while buffers.buffers[i] == bufnr('%')
            let i -= 1
        endwhile
        execute "buffer " . buffers.buffers[i]
    endif

    if len(tabpages) == 0
        execute "bdelete " . name
    elseif len(buffers.buffers) == 1
        execute "tabclose"
    endif
endfunction

function! s:remove_buffer_from_list()
    echomsg "BUF IS" . bufname('%')
endfunction

function! s:buffer_goto(idx)
    call s:buffer_nav('idx' . (a:idx - 1))
endfunction

function! s:buffer_nav(where)
    if exists('g:SessionLoad')
        return
    endif
    let buffers = airline#extensions#tabline#formatters#foo#get_tab_buffers()
    if len(buffers.buffers) == 0
        return
    endif
    let pattern = '\vidx([0-9]+)$'
    if a:where == 'first'
        let idx = 0
    elseif a:where == 'last'
        let idx = len(buffers.buffers) - 1
    elseif a:where =~ pattern
        let idx = substitute(a:where, pattern, '\1', 'g')
    else
        let idx = index(buffers.buffers, buffers.current)
        let idx += a:where
    endif
    if idx < 0
        let idx = len(buffers.buffers) - 1
    endif
    if idx >= len(buffers.buffers)
        let idx = 0
    endif

    let buf = buffers.buffers[idx]

    execute "buffer " . buf
endfunction

function! airline#extensions#tabline#formatters#foo#format(bufnr, buffers)
    let idx = index(a:buffers, a:bufnr)
    return (idx == -1 ? '' : idx + 1) . ' ' . fnamemodify(bufname(a:bufnr), ':t')
endfunction

function! s:set_tab_excludes(...)
    if exists('g:SessionLoad')
        return
    endif
    let excludes = []
    let buffers = airline#extensions#tabline#formatters#foo#get_tab_buffers()

    for info in getbufinfo()
        if index(buffers.buffers, info.bufnr) == -1 && info.name != ''
            call add(excludes, bufname(info.bufnr))
        endif
    endfor

    let g:airline#extensions#tabline#excludes = excludes
    execute "so " . s:buflist_path
endfunction

function! s:do_refresh_bufline(...)
    keepalt keepjumps AirlineBuffersPrevious
endfunction

function! s:refresh_bufline()
    if exists('g:SessionLoad')
        return
    endif
    let Func = function('s:do_refresh_bufline')
    keepalt keepjumps AirlineBuffersNext
    let timer = timer_start(0, Func)
endfunction

function! s:generate_sort_order(...)
    if a:0
        let buffers = a:1
    else
        let _tmp = airline#extensions#tabline#formatters#foo#get_tab_buffers()
        let buffers = _tmp.buffers
    endif
    let sort_order = -len(buffers)
    for buf in buffers
        call setbufvar(buf, 'sort_order', sort_order)
        let sort_order += 1
    endfor
endfunction

function! s:move_buffer(where)
    let buffers = airline#extensions#tabline#formatters#foo#get_tab_buffers()

    let f = filter(copy(buffers.buffers), 'v:val == ' . buffers.current)
    let current_idx = index(buffers.buffers, buffers.current)

    if current_idx != -1 && current_idx + a:where >= 0 && current_idx + a:where < len(buffers.buffers)
        unlet buffers.buffers[current_idx]
        let current_idx += a:where

        let result = []
        let i = 0
        while i < len(buffers.buffers)
            if i == current_idx
                call add(result, buffers.current)
            endif

            call add(result, buffers.buffers[i])

            let i += 1
        endwhile

        if current_idx == len(buffers.buffers)
            call add(result, buffers.current)
        endif

        call s:generate_sort_order(result)

        call s:refresh_bufline()
    endif
endfunction
