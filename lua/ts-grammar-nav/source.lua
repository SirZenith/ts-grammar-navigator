local api = vim.api
local nvim_buf_get_lines = api.nvim_buf_get_lines

---@generic T
---@param list T[] | nil
---@param cond_func fun(T): boolean
---@return T[]
local function filter(list, cond_func)
    local result = {}
    if not list then return result end

    for _, value in ipairs(list) do
        if cond_func(value) then
            table.insert(result, value)
        end
    end

    return result
end

---@class GrammarSource
---@field name string
---@field node_type? { [string]: NodeInfo }
local GrammarSource = {}
GrammarSource.__index = GrammarSource
GrammarSource.name = "tree-sitter-grammar"

function GrammarSource:new()
    ---@type GrammarSource
    local obj = setmetatable({}, GrammarSource)

    return obj
end

-- ----------------------------------------------------------------------------

---@return string[]
function GrammarSource:get_trigger_characters()
    return { "(" }
end

function GrammarSource:is_available()
    return self.node_type ~= nil
end

-- Completion only start on a line ends with pattern `%(%S*`.
---@param params any
---@param callback fun(result: { items: CompletionItem[], isIncomplete: boolean } | nil)
function GrammarSource:complete(params, callback)
    if not self.node_type then
        callback(nil)
    end

    local line = params.context.cursor_before_line
    local input = line:match("%((%S*)$")
    if not input then
        callback(nil)
        return
    end

    local parent_node = self:_find_parent_node(params)
    local info = self.node_type[parent_node]
    if not info then
        callback(nil)
        return
    end

    local items = self:_gen_completion(info)
    callback({ items = items, isIncomplete = false })
end

-- ----------------------------------------------------------------------------

---@param file_path string # path to node-types.json
function GrammarSource:load_node_types(file_path)
    local file, err = io.open(file_path)
    if file == nil then
        vim.notify(err or "")
        return
    end

    local content = file:read("a")
    local type_list = vim.fn.json_decode(content) ---@type NodeInfo[]
    type_list = filter(type_list, function(info)
        return info.named
    end)

    local node_type = {}
    for _, t in ipairs(type_list) do
        node_type[t.type] = t
    end

    self.node_type = node_type
end

---@param info NodeInfo
---@return CompletionItem[]
function GrammarSource:_gen_completion(info)
    ---@type CompletionItem[]
    local items = {}

    if info.fields then
        for _, field in pairs(info.fields) do
            for _, t in ipairs(field.types) do
                self:_append_comp_item(items, t.type)
            end
        end
    end

    if info.children then
        for _, t in ipairs(info.children.types) do
            self:_append_comp_item(items, t.type)
        end
    end

    return items
end

---@param list CompletionItem[]
---@param label string
function GrammarSource:_append_comp_item(list, label)
    table.insert(list, {
        label = label,
        dup = 0,
        kind = vim.lsp.protocol.CompletionItemKind.Field,
    })
end

-- ----------------------------------------------------------------------------

---@param params any
---@return string | nil parent_node
function GrammarSource:_find_parent_node(params)
    local result = self:_check_cursor_line(params) or self:_check_earlier_lines(params)
    return result or ""
end

---@param params any
---@return string | nil parent_node
function GrammarSource:_check_cursor_line(params)
    local line = params.context.cursor_before_line
    -- skip incomplete name at the end of the line
    local skip_cnt = line:sub(#line) ~= "(" and 1 or 0
    return self:_find_last_open_node(line,skip_cnt)
end

-- Try finding parent node on each earlier line, until a parent node is found,
-- or an empty line/line with only `-` is encountered.
---@param params any
function GrammarSource:_check_earlier_lines(params)
    local result

    local curline = params.context.cursor.line
    for index = curline - 1, 1, -1 do
        local line = nvim_buf_get_lines(0, index, index + 1, true)[1]
        if line:match("^%s*$") or line:match("^%-+$") then
            break
        end

        result = self:_find_last_open_node(line)
        if result then
            break
        end
    end

    return result
end

---@param line string
---@param skip_cnt? number
---@return string | nil node_name
function GrammarSource:_find_last_open_node(line, skip_cnt)
    local len = #line
    local nested_level = 0
    local st, ed
    local read_non_name = true
    skip_cnt = skip_cnt or 0

    local result

    for i = len, 1, -1 do
        local char = line:sub(i, i)
        if char == "(" then
            -- valid sub string range
            local ok = nested_level == 0 and st and ed and st <= ed
            if not ok then
                -- pass
            elseif skip_cnt > 0 then
                skip_cnt = skip_cnt - 1
            else
                result = line:sub(st, ed)
                break
            end
            nested_level = math.max(0, nested_level - 1)
            read_non_name = true
        elseif char == ")" then
            nested_level = nested_level + 1
            read_non_name = true
        elseif char == " "
            or char == "\t"
            or char == "\v"
            or char == "\r"
            or char == "\n"
        then
            read_non_name = true
        else
            if read_non_name then
                ed = i
            else
                st = i
            end
            read_non_name = false
        end
    end

    return result
end

-- ----------------------------------------------------------------------------

return GrammarSource
