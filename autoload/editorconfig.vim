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
  let config.global.root = 0
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

function! editorconfig#
