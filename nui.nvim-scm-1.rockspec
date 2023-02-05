local _MODREV, _SPECREV = 'scm', '-1'
rockspec_format = "3.0"
package = 'nui.nvim'
version = _MODREV .. _SPECREV

description = {
   summary = 'UI Component Library for Neovim',
   labels = {
     'neovim',
     'plugin'
   },
   homepage = 'http://github.com/MunifTanjim/nui.nvim',
   license = 'MIT',
}

dependencies = {
   'lua >= 5.1',
}

source = {
   url = 'git://github.com/MunifTanjim/nui.nvim'
}

build = {
   type = 'builtin',
}
