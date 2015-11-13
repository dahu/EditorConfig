" Vim global plugin for honouring editorconfig files
" Maintainer:	Barry Arthur <barry.arthur@gmail.com>
" License:	Vim License (see :help license)
" Location:	plugin/editorconfig.vim
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

" if exists("g:loaded_editorconfig")
"       \ || v:version < 700
"       \ || v:version == 703 && !has('patch338')
"       \ || &compatible
"   let &cpo = s:save_cpo
"   finish
" endif
let g:loaded_editorconfig = 1

" Options: {{{1
if !exists('g:editorconfig_some_plugin_option')
  let g:editorconfig_some_plugin_option = 0
endif

" Public Interface: {{{1
function! EditorConfig(...)
  let path = a:0 ? a:1 : '.'
  call editorconfig#run(path)
endfunction

command! -nargs=? -bar EditorConfig call EditorConfig(<q-args>)

" Teardown: {{{1
" reset &cpo back to users setting
let &cpo = s:save_cpo

" Template From: https://github.com/dahu/Area-41/
" vim: set sw=2 sts=2 et fdm=marker:
