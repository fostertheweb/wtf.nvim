local config = require("wtf.config")

local function split_string_by_line(text)
  local lines = {}
  for line in (text .. "\n"):gmatch("(.-)\n") do
    table.insert(lines, line)
  end
  return lines
end

local function create_buffer()
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].modifiable = false
  vim.bo[buf].readonly = true
  vim.bo[buf].filetype = "markdown"
  return buf
end

local function apply_window_options(win)
  vim.wo[win].wrap = true
  vim.wo[win].linebreak = true
  vim.wo[win].winhighlight = config.options.winhighlight
end

local M = {}

M.show = function(message)
  local formatted_message = split_string_by_line(message)
  local popup_type = config.options.popup_type

  local buf = create_buffer()
  local win

  if popup_type == "vertical" then
    win = vim.api.nvim_open_win(buf, true, {
      split = "right",
      width = math.floor(vim.o.columns * 0.5),
    })
    apply_window_options(win)
  elseif popup_type == "horizontal" then
    win = vim.api.nvim_open_win(buf, true, {
      split = "below",
      height = math.floor(vim.o.lines * 0.38),
    })
    apply_window_options(win)
  elseif popup_type == "popup" then
    local padding = 1
    local total_width = math.floor(vim.o.columns * 0.62)
    local total_height = math.floor(vim.o.lines * 0.62)
    local content_width = math.max(1, total_width - padding * 2)
    local content_height = math.max(1, total_height - padding * 2)
    local row = math.floor((vim.o.lines - total_height) / 2)
    local col = math.floor((vim.o.columns - total_width) / 2)

    win = vim.api.nvim_open_win(buf, true, {
      relative = "editor",
      row = row,
      col = col,
      width = content_width,
      height = content_height,
      style = "minimal",
      border = "rounded",
      zindex = 50,
    })
    apply_window_options(win)

    vim.api.nvim_create_autocmd("BufLeave", {
      buffer = buf,
      once = true,
      callback = function()
        if vim.api.nvim_win_is_valid(win) then
          vim.api.nvim_win_close(win, true)
        end
        if vim.api.nvim_buf_is_valid(buf) then
          vim.api.nvim_buf_delete(buf, { force = true })
        end
      end,
    })

    local refresh_group = vim.api.nvim_create_augroup("refresh_wtf_popup_layout", { clear = true })
    vim.api.nvim_create_autocmd("WinResized", {
      group = refresh_group,
      callback = function()
        if not vim.api.nvim_win_is_valid(win) then
          return
        end

        local new_total_width = math.floor(vim.o.columns * 0.62)
        local new_total_height = math.floor(vim.o.lines * 0.62)
        local new_content_width = math.max(1, new_total_width - padding * 2)
        local new_content_height = math.max(1, new_total_height - padding * 2)
        local new_row = math.floor((vim.o.lines - new_total_height) / 2)
        local new_col = math.floor((vim.o.columns - new_total_width) / 2)

        vim.api.nvim_win_set_config(win, {
          relative = "editor",
          row = new_row,
          col = new_col,
          width = new_content_width,
          height = new_content_height,
        })
      end,
    })
  else
    return nil, "Invalid popup type"
  end

  vim.api.nvim_buf_set_lines(buf, 0, 1, false, formatted_message)

  return { bufnr = buf, win = win }
end

return M
