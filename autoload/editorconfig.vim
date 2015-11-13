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
  let opt = s:trim(strpart(a:line, 0, sep))
  let val = s:trim(strpart(a:line, sep+1))
  return [opt, val]
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

  for f in findfile("_editorconfig", path . ';', -1)
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

" Teardown:{{{1
"reset &cpo back to users setting
let &cpo = s:save_cpo

" Template From: https://github.com/dahu/Area-41/
" vim: set sw=2 sts=2 et fdm=marker:
