local config = require("wtf.config")
local get_line_range = require("wtf.util.get_line_range")
local get_logical_block = require("wtf.util.get_logical_block")
local get_programming_language = require("wtf.util.get_programming_language")
local hooks = require("wtf.hooks")
local notify = require("wtf.util.notify")
local popup = require("wtf.ui.popup")
local save_chat = require("wtf.util.save_chat")

--- @param line1 number
--- @param line2 number
--- @return boolean
local function is_selection_blank(line1, line2)
  for line_num = line1, line2 do
    if not vim.fn.getline(line_num):match("^%s*$") then
      return false
    end
  end
  return true
end

--- @param response string
--- @return boolean success
local function handle_response(response)
  save_chat(response)

  local success, popup_err = popup.show(response)
  if popup_err then
    vim.notify(popup_err, vim.log.levels.ERROR)
    return false
  end

  return success ~= nil and success or false
end

--- @param programming_language string
--- @param selected_code string
--- @param block_code string
--- @param instructions string|nil
--- @return string
local function build_payload(programming_language, selected_code, block_code, instructions)
  local payload_parts = {
    "The programming language is " .. programming_language .. ".",
    "This is the selected code:\n```\n" .. selected_code .. "\n```",
    "This is the surrounding logical block for context:\n```\n" .. block_code .. "\n```",
  }

  if config.options.additional_instructions then
    table.insert(payload_parts, config.options.additional_instructions)
  end

  if instructions then
    table.insert(payload_parts, instructions)
  end

  return table.concat(payload_parts, "\n")
end

local function explain(opts)
  hooks.run_started_hook()

  local language = config.options.language

  local SYSTEM_PROMPT = "You are an expert coder. "
    .. "Explain what the selected code does, including the context of the surrounding logical block "
    .. "(e.g., whether it is inside a loop, conditional branch, or function). "
    .. "Be concise. "
    .. "When appropriate, give examples as fenced codeblocks with a language identifier "
    .. "to enable syntax highlighting. "
    .. "Never show line numbers on solutions, so they are easily copy and pastable."
    .. "Always explain in "
    .. language

  local line1, line2 = get_line_range(opts)

  -- Return to normal mode
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<esc>", true, false, true), "x", true)

  local instructions = opts and opts.instructions

  if is_selection_blank(line1, line2) then
    vim.notify("No code selected", vim.log.levels.WARN)
    hooks.run_finished_hook()
    return "No code selected"
  end

  local block = get_logical_block(line1, line2)
  local programming_language = get_programming_language()
  local payload =
    build_payload(programming_language, block.selected_code, block.block_code, instructions)

  notify.ai_task_started("Explaining")

  -- Use coroutine since client function is async
  local co = coroutine.create(function()
    local client = require("wtf.ai.client")
    local response, client_err = client(SYSTEM_PROMPT, payload, 0.5)

    if client_err then
      vim.notify(client_err, vim.log.levels.ERROR)
      hooks.run_finished_hook()
      return nil
    elseif response then
      handle_response(response)
      hooks.run_finished_hook()
    end

    return response
  end)

  coroutine.resume(co)
end

return explain
