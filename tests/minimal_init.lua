local function clone_repo(repo_url, dest_dir)
  if vim.fn.isdirectory(dest_dir) == 0 then
    vim.fn.system({ "git", "clone", repo_url, dest_dir })
  end
end

local plenary_dir = os.getenv("PLENARY_DIR") or "/tmp/plenary.nvim"

local plenary_repo = "https://github.com/nvim-lua/plenary.nvim"

clone_repo(plenary_repo, plenary_dir)

vim.opt.swapfile = false

vim.opt.rtp:append(".")
vim.opt.rtp:append(plenary_dir)

vim.cmd.runtime({ "plugin/plenary.vim" })
require("plenary.busted")
