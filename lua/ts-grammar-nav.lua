local user = require "user"
local fs = require "user.utils.fs"
local workspace = require "user.workspace"
local cmp = require "cmp"

-- ----------------------------------------------------------------------------

---@param file_path string # path to node-types.json
---@return NodeInfo[]
---@return string | nil err
local function load_node_types(file_path)
    local file, err = io.open(file_path)
    if file == nil then
        return {}, err or ""
    end

    local content = file:read("a")
    local node_types = vim.fn.json_decode(content)
    return node_types, nil
end

-- ----------------------------------------------------------------------------

---@class GrammarSource
---@field name string
---@field node_types NodeInfo[]
local GrammarSource = {}
GrammarSource.__index = GrammarSource
GrammarSource.name = "tree-sitter-grammar"

---@param file_path string # path to node-types.json
function GrammarSource:new(file_path)
    ---@type GrammarSource
    local obj = setmetatable({}, GrammarSource)

    local node_types, err = load_node_types(file_path)
    obj.node_types = node_types
    if err then
        vim.notify(err)
    end

    return obj
end

---@param params any
---@param callback fun(result: { items: CompletionItem[], isIncomplete: boolean })
function GrammarSource:complete(params, callback)
    vim.print(params)

    -- vim.defer_fn(function()
    -- end, 100)
    local input = string.sub(params.context.cursor_before_line, params.offset)

    ---@type CompletionItem
    local items = {}

    callback({
        items = items,
        isIncomplete = false,
    })
end

-- Backtracing buffer lines. starting from current cursor line, until an empty
-- line is encountered.
function GrammarSource:_input_line_back_trace()
end

-- ----------------------------------------------------------------------------

local workspace_path = workspace.get_workspace_path()
local file_path = fs.path_join(workspace_path, "src", "node-types.json")
local source = GrammarSource:new(file_path)

cmp.register_source(source.name, source)
user.plugin.nvim_cmp.sources:append({ name = source.name })
