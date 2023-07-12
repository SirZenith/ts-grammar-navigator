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

---@param params any
---@param callback fun(result: { items: CompletionItem[], isIncomplete: boolean } | nil)
function GrammarSource:complete(params, callback)
    if not self.node_type then
        callback(nil)
    end

    local line = params.context.cursor_before_line
    local last_character = line:sub(params.offset)
    local input = line:match("[%(%s](%S*)$") or ""
    if input == "" and last_character ~= "(" then
        callback(nil)
        return
    end

    local parent_node = self:_input_line_back_trace(params)
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

---@param params any
---@return string parent_node
function GrammarSource:_input_line_back_trace(params)
    local range_ed = params.context.cursor.line + 1
    local range_st = math.max(0, range_ed - 2)
    local lines = nvim_buf_get_lines(0, range_st, range_ed, false)
    local content = table.concat(lines, " ")
    local nodes = self:_find_nodes_from_line(content)

    local last_character = params.context.cursor_before_line:sub(params.offset)
    local result = table.remove(nodes)
    if last_character ~= "(" then
        -- `result` is the node that needs completion
        -- pop one more to get its parent
        result = table.remove(nodes)
    end

    return result
end

---@param line string
---@return string[] nodes
function GrammarSource:_find_nodes_from_line(line)
    local nodes = {}
    for node in line:gmatch("%(%s*(%S-)[%(%)%s]") do
        table.insert(nodes, node)
    end
    return nodes
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

return GrammarSource
