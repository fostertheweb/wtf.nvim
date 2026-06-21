local BLOCK_NODE_TYPES = {
  function_declaration = true,
  function_definition = true,
  method_declaration = true,
  arrow_function = true,
  lambda = true,
  if_statement = true,
  else_clause = true,
  elseif_statement = true,
  for_statement = true,
  while_statement = true,
  do_statement = true,
  repeat_statement = true,
  try_statement = true,
  catch_clause = true,
  finally_clause = true,
  class_declaration = true,
  class_definition = true,
  struct_item = true,
  struct_spec = true,
  module = true,
  program = true,
}

--- @param line string
--- @return number
local function get_indent(line)
  return #(line:match("^%s*") or "")
end

--- Get content between specified lines with line numbers
--- @param start_line number
--- @param end_line number
--- @return string
local function get_content_between_lines(start_line, end_line)
  local lines = {}
  for line_num = start_line, end_line do
    local line = string.format("%d: %s", line_num, vim.fn.getline(line_num))
    table.insert(lines, line)
  end
  return table.concat(lines, "\n")
end

--- @param node TSNode
--- @param bufnr number
--- @return string text
--- @return number block_start
--- @return number block_end
local function get_node_text_with_line_numbers(node, bufnr)
  local start_row, _, end_row, _ = node:range()
  local lines = vim.api.nvim_buf_get_lines(bufnr, start_row, end_row, false)

  local numbered = {}
  for i, line in ipairs(lines) do
    table.insert(numbered, string.format("%d: %s", start_row + i, line))
  end

  return table.concat(numbered, "\n"), start_row + 1, end_row
end

--- @param line1 number
--- @param line2 number
--- @return { block_code: string, block_start: number, block_end: number }|nil
local function get_block_by_treesitter(line1, line2)
  local bufnr = vim.api.nvim_get_current_buf()
  local ok, parser = pcall(vim.treesitter.get_parser, bufnr)

  if not ok or not parser then
    return nil
  end

  local trees = parser:parse()
  if not trees or not trees[1] then
    return nil
  end

  local root = trees[1]:root()
  local target_row = line1 - 1
  local target_col = 0

  local node = root:descendant_for_range(target_row, target_col, target_row, target_col)
  if not node then
    return nil
  end

  while node do
    if BLOCK_NODE_TYPES[node:type()] then
      local text, block_start, block_end = get_node_text_with_line_numbers(node, bufnr)
      return {
        block_code = text,
        block_start = block_start,
        block_end = block_end,
      }
    end
    node = node:parent()
  end

  return nil
end

--- @param line number
--- @return number start_line
--- @return number end_line
local function expand_by_indentation(line)
  local total_lines = vim.api.nvim_buf_line_count(0)
  local original_line = vim.fn.getline(line)
  local original_indent = get_indent(original_line)

  local start_line = line
  while start_line > 1 do
    local prev = vim.fn.getline(start_line - 1)
    if prev:match("^%s*$") then
      break
    end

    local prev_indent = get_indent(prev)
    if prev_indent < original_indent then
      start_line = start_line - 1
      break
    end

    start_line = start_line - 1
  end

  local end_line = line
  while end_line < total_lines do
    local next_line = vim.fn.getline(end_line + 1)
    if next_line:match("^%s*$") then
      break
    end

    local next_indent = get_indent(next_line)
    if next_indent < original_indent then
      break
    end

    end_line = end_line + 1
  end

  return start_line, end_line
end

--- Get the selected code and its surrounding logical block
--- @param line1 number
--- @param line2 number
--- @return { selected_code: string, block_code: string, block_start: number, block_end: number }
local function get_logical_block(line1, line2)
  local selected_code = get_content_between_lines(line1, line2)

  local block = get_block_by_treesitter(line1, line2)
  if block then
    block.selected_code = selected_code
    return block
  end

  local block_start, block_end
  if line1 == line2 then
    block_start, block_end = expand_by_indentation(line1)
  else
    block_start, block_end = line1, line2
  end

  return {
    selected_code = selected_code,
    block_code = get_content_between_lines(block_start, block_end),
    block_start = block_start,
    block_end = block_end,
  }
end

return get_logical_block
