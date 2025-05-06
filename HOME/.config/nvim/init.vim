" Basic settings
set encoding=utf-8
set backspace=indent,eol,start
set completeopt=menuone,noselect
set history=1000
"set dictionary=/usr/share/dict/words
set startofline
set mouse=a
set clipboard=unnamedplus
set cmdheight=1
set conceallevel=0
set undofile
set noshowmode

" Mapping waiting time
set notimeout
set ttimeout
set ttimeoutlen=100

"Display
set showmatch
set scrolloff=3
set synmaxcol=300
set laststatus=2
set nolist
set nofoldenable
set foldlevel=4
set foldmethod=syntax
set wrap
set noeol
set showbreak=no

" Sidebar
set number
set relativenumber
set numberwidth=3
set signcolumn=yes
set modelines=0
set showcmd

" Search
set incsearch
set ignorecase
set smartcase
set matchtime=2
set matchpairs+=<:>

" White characters / indentation
set autoindent
set tabstop=2
set shiftwidth=2
set formatoptions=qnj1
set expandtab
set smartindent
set splitbelow
set splitright

" Backup
set nobackup
set nowritebackup
set noswapfile
"set undodir=~/.vim/tmp/undo//
"set backupdir=~/.vim/tmp/backup//
"set directory=~/.vim/tmp/swap//

let g:loaded_netrw = 1
let g:loaded_netrwPlugin = 1

" Filetype settings
au FileType python set ts=4 sw=4
au BufRead,BufNewFile *.md,*.rmd,*.ppmd,*.markdown set ft=mkd tw=80 syntax=markdown
au BufRead,BufNewFile *.slimbars set syntax=slim

" Command mode
set wildmenu
set wildignore=deps,.svn,CVS,.git,.hg,*.o,*.a,*.class,*.mo,*.la,*.so,*.obj,*.swp,*.jpg,*.png,*.xpm,*.gif,.DS_Store,*.aux,*.out,*.toc

" Cursorline behavior
augroup cline
  autocmd!
    autocmd WinLeave * set nocursorline
      autocmd WinEnter * set cursorline
        autocmd InsertEnter * set nocursorline
	  autocmd InsertLeave * set cursorline
	  augroup END

	  " Minimap
	  let g:minimap_auto_start = 0
	  let g:minimap_auto_start_win_enter = 0

	  " Colorscheme
	  set t_Co=256
	  set termguicolors
	  " acolorscheme dracula
	  hi Normal guibg=NONE ctermbg=NONE

	  " VimR
	  let g:rout_follow_colorscheme = 1


