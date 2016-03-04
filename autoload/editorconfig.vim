" Vim library for parsing and processing editorconfig files
" Maintainer:	Barry Arthur <barry.arthur@gmail.com>
" License:	Vim License (see :help license)
" Location:	autoload/editorconfig.vim
" Website:	https://github.com/dahu/editorconfig
"
" See editorconfig.txt for help.  This can be accessed by doing:
"
" :helptags ~/.vim/doc
" :help editorconfig

" Vimscript Setup: {{{1
" Allow use of line continuation.
let s:save_cpo = &cpo
set cpo&vim

" if exists("g:loaded_lib_editorconfig")
"       \ || v:version < 700
"       \ || v:version == 703 && !has('patch338')
"       \ || &compatible
"   let &cpo = s:save_cpo
"   finish
" endif
let g:loaded_lib_editorconfig = 1

" Vim Script Information Function: {{{1
" Use this function to return information about your script.
function! editorconfig#info()
  let info = {}
  let info.name = 'editorconfig'
  let info.version = 1.0
  let info.description = 'Parsing and processing editorconfig files'
  let info.dependencies = []
  return info
endfunction

" Private Functions {{{1

function! s:set_option(option, value, bufnr)
  let all_options = {
        \  'indent_style'             : {
        \    'space' : ['setlocal et']
        \   ,'tab'   : ['setlocal noet']
        \  }
        \ ,'indent_size'              : {
        \    'tab'     : ['setlocal sw=0']
        \   ,'^\d\+$'  : ['setlocal sw=' . a:value]
        \  }
        \ ,'tab_width'                : {
        \    '^\d\+$'  : ['setlocal ts=8 sts=' . a:value . ' sw=' . a:value]
        \  }
        \ ,'end_of_line'              : {
        \    'lf'   : ['edit ++ff=unix']
        \   ,'cr'   : ['edit ++ff=mac']
        \   ,'crlf' : ['edit ++ff=dos']
        \  }
        \ ,'charset'                  : {
        \    'latin1'   : ['edit ++enc=' . a:value]
        \   ,'utf-8'    : ['edit ++enc=' . a:value]
        \   ,'utf-16be' : ['edit ++enc=' . a:value]
        \   ,'utf-16le' : ['edit ++enc=' . a:value]
        \  }
        \ ,'trim_trailing_whitespace' : {
        \    'true'  : []
        \   ,'false' : []
        \  }
        \ ,'insert_final_newline'     : {
        \    'true'  : []
        \   ,'false' : []
        \  }
        \ ,'max_line_length'          : {
        \    '^\d\+$'  : ['setlocal tw=' . a:value]
        \  }
        \}
  if ! has_key(all_options, a:option)
    echohl Warning
    echom 'EditorConfig: Unhandled option ' . a:option
    echohl NONE
    return
  endif
  let option = all_options[a:option]
  let commands = []
  for subopt in keys(option)
    if a:value =~ subopt
      let commands = option[subopt]
    endif
  endfor
  for c in commands
    exe c
  endfor
endfunction

function! s:snake_to_camel(name)
  return substitute(substitute(tolower(a:name), '^\w', '\U&', ''), '_\(\w\)', '\U\1', 'g')
endfunction

function! s:trim(string)
  return matchstr(a:string, '^\s*\zs.\{-}\ze\s*$')
endfunction

function! s:extend(glob, config, options)
  if a:glob == ''
    call extend(a:config.global, a:options)
  else
    if ! has_key(a:config.globs, a:glob)
      let a:config.globs[a:glob] = {}
    endif
    call extend(a:config.globs[a:glob], a:options)
  endif
endfunction

function! s:optval(line)
  let sep = stridx(a:line, '=')
  if sep == -1
    let sep = stridx(a:line, ':')
    if sep == -1
      throw "editorconfig#s:optval : Error : Internal : entry line doesn't contain '=' or ':'"
    endif
  endif
  let opt = s:trim(tolower(strpart(a:line, 0, sep)))
  let val = s:trim(strpart(a:line, sep+1))
  return [opt, val]
endfunction

function! s:glob_to_vim(glob, ...)
  let glob = a:glob
  let globs = a:0 ? a:1 : []
  if glob =~ '^{.*}$'
    for g in split(glob[1:-2], '\\\@<!,')
      call s:glob_to_vim(g, globs)
    endfor
  else
    call add(globs, substitute(glob, '\[!', '[^', 'g'))
  endif
  return globs
endfunction

" Public Interface {{{1

function! editorconfig#parse(data)
  if type(a:data) == type('')
    if ! filereadable(a:data)
      throw 'editorconfig#parse : Error : File unreadable, ' . a:data
    endif
    return editorconfig#parse(readfile(a:data))
  elseif type(a:data) != type([])
    throw 'editorconfig#parse : Error : Unexpected argument type, ' . type(a:data)
  endif

  let config             = {}
  let config.global      = {}
  let config.global.root = ''
  let config.glob_list   = []
  let config.globs       = {}
  let glob               = ''
  let options            = {}

  let line_num = 0
  for line in a:data
    let line_num += 1
    if line =~ '^\s*\([#;].*\)\?$'
      continue
    endif
    let line = substitute(line, '\\\@<!;.*', '', '')
    if line =~ '^\[.\+\]$'
      call s:extend(glob, config, options)
      let options = {}
      let glob = strpart(line, 1, len(line)-2)
      call add(config.glob_list, glob)
    elseif line =~ '^\w\+\s*[=:]\s*\w'
      let [opt, val] = s:optval(line)
      let options[opt] = val
    else
      throw 'editorconfig#parse : Error : Syntax error on line ' . line_num . ', #' . line . '#'
    endif
  endfor
  call s:extend(glob, config, options)

  return config
endfunction

function! editorconfig#init(...)
  let path             = a:0 ? a:1 : '.'
  let configs          = []
  let config           = {}
  let config.global    = {}
  let config.glob_list = []
  let config.globs     = {}
  let root             = ''

  for f in findfile(".editorconfig", path . ';', -1)
    try
      let c = editorconfig#parse(f)
    catch /editorconfig#parse : Error/
      throw 'editorconfig#init : Error : ' . f . ', ' . v:exception
    endtry
    call add(configs, c)
    if c.global.root ==? 'true'
      break
    endif
  endfor
  for c in configs
    call extend(config.global, c.global, "keep")
    for glob in c.glob_list
      if index(config.glob_list, glob) == -1
        call add(config.glob_list, glob)
      endif
    endfor
    for [glob, opts] in items(c.globs)
      if ! has_key(config.globs, glob)
        let config.globs[glob] = {}
      endif
      call extend(config.globs[glob], opts, "keep")
    endfor
    let root = c.global.root
  endfor
  let config.global.root = root
  return config
endfunction

function! editorconfig#set(options)
  for [name, value] in items(a:options)
    let fname = s:snake_to_camel(name)
    if exists('*' . fname)
      call call(fname, [value, bufnr('.')])
    else
      call s:set_option(name, value, bufnr('.'))
    endif
  endfor
endfunction

function! editorconfig#process(config)
  let config = a:config
  for glob in config.glob_list
    let options = config.globs[glob]
    for vimglob in s:glob_to_vim(glob)
      if expand('%') =~ glob2regpat(vimglob)
        call editorconfig#set(options)
      endif
    endfor
  endfor
endfunction

function! editorconfig#run(...)
  let path = a:0 ? a:1 : '.'
  call editorconfig#process(editorconfig#init(path))
endfunction

" Teardown:{{{1
"reset &cpo back to users setting
let &cpo = s:save_cpo

" Template From: https://github.com/dahu/Area-41/
" vim: set sw=2 sts=2 et fdm=marker:
