local lines = {
  "  Leader key: <Space>                          ",
  "                                               ",
  "── File Tree ─────────────────────────────────",
  "  <Space>e       Toggle file tree              ",
  "  <Space>ee      Open tree, close empty buffer ",
  "  <Space>ef      Focus file tree               ",
  "  <Space>er      Refresh file tree             ",
  "  n  (in tree)   Open file in nano             ",
  "                                               ",
  "── Find (Telescope) ──────────────────────────",
  "  <Space>ff      Find files                    ",
  "  <Space>fg      Live grep                     ",
  "  <Space>fw      Grep word under cursor        ",
  "  <Space>fb      List open buffers             ",
  "  <Space>fh      Search help tags              ",
  "  <Space>fk      Search keymaps                ",
  "  <Space>fr      Recent files                  ",
  "  <Space>fc      Find in current buffer        ",
  "                                               ",
  "── Buffers ───────────────────────────────────",
  "  <Space>bd      Delete buffer                 ",
  "  <Tab>          Next buffer                   ",
  "  <S-Tab>        Previous buffer               ",
  "                                               ",
  "── Windows ───────────────────────────────────",
  "  <Space>wv      Vertical split                ",
  "  <Space>wh      Horizontal split              ",
  "  <Space>wq      Close window                  ",
  "  Ctrl+h/j/k/l   Navigate windows              ",
  "                                               ",
  "── Editing ───────────────────────────────────",
  "  <Space>w       Save file                     ",
  "  jk             Escape insert mode            ",
  "  Esc Esc        Clear search highlights       ",
  "                                               ",
  "── SSH / Clipboard ───────────────────────────",
  "  \"+y            Yank to system clipboard      ",
  "  Ctrl+Shift+C   Copy (GNOME Terminal)         ",
  "  Ctrl+Shift+V   Paste (GNOME Terminal)        ",
  "  (mouse disabled over SSH — drag to select)   ",
  "                                               ",
  "── nano ──────────────────────────────────────",
  "  Ctrl+X         Exit nano / close split       ",
  "  Ctrl+\\ Ctrl+n  Return to nvim normal mode    ",
  "                                               ",
  "  <Space>?       All keymaps (which-key)       ",
  "  q / Esc        Close this window             ",
}

local function show()
  local width = 51
  local height = math.min(#lines, vim.o.lines - 6)
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.bo[buf].bufhidden = 'wipe'
  vim.bo[buf].filetype = 'cheat'

  local win = vim.api.nvim_open_win(buf, true, {
    relative = 'editor',
    width = width,
    height = height,
    row = row,
    col = col,
    style = 'minimal',
    border = 'rounded',
    title = ' loom-vim cheat sheet ',
    title_pos = 'center',
  })

  vim.wo[win].wrap = false
  vim.wo[win].cursorline = true
  vim.wo[win].scrolloff = 3

  vim.keymap.set('n', 'q',   '<Cmd>close<CR>', { buffer = buf, silent = true })
  vim.keymap.set('n', '<Esc>', '<Cmd>close<CR>', { buffer = buf, silent = true })
end

vim.api.nvim_create_user_command('Cheat', show, { desc = 'Show loom-vim cheat sheet' })
vim.cmd('cabbrev cheat Cheat')
