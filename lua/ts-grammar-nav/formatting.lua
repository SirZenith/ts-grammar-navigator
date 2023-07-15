local panelpal = require "panelpal"

local M = {}

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

---@param buffer string[]
---@param node Node
---@param indent? number
local function format_node(buffer, node, indent)
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
end

function M.format_selection()
    local text = panelpal.visual_selection_text()
    if not text then return end

    local r_st, c_st, r_ed, c_ed = panelpal.visual_selection_range()
    if c_st ~= 0 then
        vim.notify("selection must starts at line beginning.")
        return
    end

    local root = input_parsing(text)
    local buffer = {}
    format_node(buffer, root)

    local result = table.concat(buffer)
    local lines = vim.split(result, "\n")
    vim.api.nvim_buf_set_text(0, r_st, c_st, r_ed, c_ed, lines)
end

function M.setup(options)
    M.indent = options.indent or M.indent
end

return M
