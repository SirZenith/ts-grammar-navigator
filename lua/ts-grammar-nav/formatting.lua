local panelpal = require "panelpal"

local M = {}

local TITLE_SEP_PATT = "^=+"
local SOURCE_SEP_PATT = "^%-+"
local EMPTY_LINE_PATT = "^%s*$"

local NEWLINE = "\n"
M.indent = "  "


---@class Node
---@field title string[]
---@field parent? Node
---@field children Node[]

---@param parent? Node
local function make_node(parent)
    local new_node = {
        title = {},
        parent = parent,
        children = {},
    }

    if parent then
        table.insert(parent.children, new_node)
    end

    return new_node
end

---@param text string
---@return Node
local function input_parsing(text)
    ---@type Node
    local root = make_node(nil)

    local cur_node = root
    local st = 1
    local read_non_name = true

    local function store_text(node, s, e, last_char_non_name)
        if last_char_non_name then return s end
        table.insert(node.title, text:sub(s, e))
        return e + 1
    end

    for i = 1, #text do
        local char = text:sub(i, i)
        local non_name = true

        if char == "(" then
            st = store_text(cur_node, st, i - 1, read_non_name)
            cur_node = make_node(cur_node)

        elseif char == ")" and cur_node.parent then
            st = store_text(cur_node, st, i - 1, read_non_name)
            cur_node = cur_node.parent --[[@as Node]]

        elseif char == " "
            or char == "\t"
            or char == "\v"
            or char == "\n"
            or char == "\r"
        then
            st = store_text(cur_node, st, i - 1, read_non_name)

        else
            if read_non_name then
                st = i
            end
            non_name = false

        end

        read_non_name = non_name
    end

    return root
end

---@param buffer string[] | nil
---@param node Node
---@param indent? number
---@return string[] buffer
local function format_node(buffer, node, indent)
    buffer = buffer or {}
    indent = indent or 0
    local is_wrapper_node = #node.title == 0

    if not is_wrapper_node then
        for _ = 1, indent do
            table.insert(buffer, M.indent)
        end
        table.insert(buffer, "(")
        table.insert(buffer, table.concat(node.title, " "))
    end

    local child_indent = is_wrapper_node and indent or indent + 1
    for i, child in ipairs(node.children) do
        if i > 1 or not is_wrapper_node then
            table.insert(buffer, NEWLINE)
        end
        format_node(buffer, child, child_indent)
    end

    if not is_wrapper_node then
        table.insert(buffer, ")")
    end

    return buffer
end

-- ----------------------------------------------------------------------------

---@param lines string[]
---@param workspace string[]
---@param offset number
---@return number | nil new_offset
---@return string postfix
local function find_title(lines, workspace, offset)
    local target_postfix = ""
    local new_offset = nil

    for i = offset, #lines do
        local line = lines[i]
        table.insert(workspace, line)

        if line:match(EMPTY_LINE_PATT) then
            -- pass

        elseif line:match(TITLE_SEP_PATT) then
            local postfix = line:gsub(TITLE_SEP_PATT, "")

            if postfix == target_postfix then
                new_offset = i + 1
                break

            else
                target_postfix = postfix
                new_offset = nil

            end
        end
    end

    return new_offset, target_postfix
end

---@param lines string[]
---@param workspace string[]
---@param offset number
---@param target_postfix string
---@return number | nil new_offset
local function find_source(lines, workspace, offset, target_postfix)
    local new_offset = nil

    for i = offset, #lines do
        local line = lines[i]
        table.insert(workspace, line)

        if line:match(SOURCE_SEP_PATT) then
            local postfix = line:gsub(SOURCE_SEP_PATT, "")
            if postfix == target_postfix then
                new_offset = i + 1
                break
            end

        end
    end

    return new_offset
end

---@param lines string[]
---@param workspace string[]
---@param offset number
---@return number new_offset
local function find_s_expr(lines, workspace, offset)
    local new_offset = nil
    local buffer = {}

    for i = offset, #lines do
        local line = lines[i]
        if line:match(TITLE_SEP_PATT) then
            new_offset = i
            break

        elseif line:match(EMPTY_LINE_PATT) then
            -- pass

        else
            table.insert(buffer, line)

        end
    end

    local text = table.concat(buffer, " ")
    local node = input_parsing(text)
    local result = format_node(nil, node)
    local result_lines = vim.split(table.concat(result, ""), "\n")

    table.insert(workspace, "")
    for _, line in ipairs(result_lines) do
        table.insert(workspace, line)
    end
    table.insert(workspace, "")

    return new_offset or #lines + 1
end

---@param lines string[]
---@return string[] result
---@return string | nil
local function process_lines(lines)
    local result = {}

    local workspace = {}

    ---@type number | nil
    local offset = 1
    local postfix = nil
    while offset <= #lines do
        if not offset then return result, "nil index" end

        offset, postfix = find_title(lines, workspace, offset)
        if not offset then
            local err = "failed to find match title separator starting from line " .. tostring(offset)
            return result, err
        end

        offset = find_source(lines, workspace, offset, postfix)
        if not offset then
            local err = "can't find sourc-expression separator starting from line " .. tostring(offset)
            return result, err
        end

        offset = find_s_expr(lines, workspace, offset)

        for i, line in ipairs(workspace) do
            table.insert(result, line)
            workspace[i] = nil
        end
    end

    return result, nil
end

-- ----------------------------------------------------------------------------

function M.format_selection()
    local text = panelpal.visual_selection_text()
    if not text then return end

    local r_st, c_st, r_ed, c_ed = panelpal.visual_selection_range()
    if c_st ~= 0 then
        vim.notify("selection must starts at line beginning.")
        return
    end

    local root = input_parsing(text)
    local buffer = format_node(nil, root)

    local result = table.concat(buffer)
    local lines = vim.split(result, "\n")
    vim.api.nvim_buf_set_text(0, r_st, c_st, r_ed, c_ed, lines)
end

function M.format_file()
    local lines = vim.api.nvim_buf_get_lines(0, 0, -1, true)
    local result, err = process_lines(lines)
    if err then
        vim.notify(err)
    else
        if result[#result] == "" then
            table.remove(result)
        end
        vim.api.nvim_buf_set_lines(0, 0, -1, true, result)
    end
end

function M.setup(options)
    M.indent = options.indent or M.indent
end

return M
