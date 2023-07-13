local event = require "ts-grammar-nav.event"
local formatter = require "ts-grammar-nav.grammar-hint.rule-formatter"

local panelpal = require "panelpal"
local ScrollMethod = panelpal.ScrollMethod
local PanelContentUpdateMethod = panelpal.PanelContentUpdateMethod

local api = vim.api

-- ----------------------------------------------------------------------------

---@alias RuleType
---| "ALIAS"
---| "BLANK"
---| "FIELD"
---| "CHOICE"
---| "PREC"
---| "PREC_LEFT"
---| "PREC_RIGHT"
---| "PREC_DYNAMIC"
---| "REPEAT"
---| "REPEAT1"
---| "SEQ"
---| "SYMBOL"
---| "TOKEN"
---| "IMMEDIATE_TOKEN"
---| "STRING"
---| "PATTERN"

---@class RuleInfo
---@field type RuleType
---@field name? string
---@field value? string
---@field members? RuleInfo[]
---@field content? RuleInfo

---@class HighLightInfo
---@field highlight string # highlight group name
---@field line number # 1-base line index
---@field from number # 1-base range start
---@field to number # 1-bases range end, excluded

-- ----------------------------------------------------------------------------

local GRAMMAR_HINT_PANEL_NAME = "ts-grammar-navigator.grammar-hint"
local GRAMMAR_HINT_HL_NS = 0

local M = {}

local rules = nil

---@param buf number
---@param hl_list HighLightInfo[]
local function draw_highlight(buf, hl_list)
    for _, info in ipairs(hl_list) do
        api.nvim_buf_add_highlight(
            buf,
            GRAMMAR_HINT_HL_NS,
            info.highlight,
            info.line,
            info.from,
            info.to
        )
    end
end

local handlers = {
    string = function(env, value)
        if value == formatter.NEW_LINE then
            table.insert(env.lines, table.concat(env.line_buffer))
            env.line_buffer = {}
            env.offset = 0
        else
            table.insert(env.line_buffer, value)
            env.offset = env.offset + #value
        end
    end,
    table = function(env, value)
        local text = value[1]
        local len = #text
        table.insert(env.line_buffer, text)
        table.insert(env.highlight, {
            line = #env.lines,
            from = env.offset,
            to = env.offset + len,
            highlight = value.highlight
        })
        env.offset = env.offset + len
    end,
}

---@param buf number
---@param node_name string
local function write_hint_to_buf(buf, node_name)
    local buffer = {
        "-- ", { node_name, highlight = "@type" }, " --", formatter.NEW_LINE,
    }
    local format_env = {
        buffer = buffer,
        rules = rules,
    }
    formatter.format(format_env, rules and rules[node_name])

    local env = {
        lines = {},
        line_buffer = {},
        highlight = {},
        offset = 0,
    }

    for _, value in ipairs(buffer) do
        local value_t = type(value)
        local handler = handlers[value_t]
        if handler then
            handler(env, value)
        end
    end

    if #env.line_buffer ~= 0 then
        table.insert(env.lines, table.concat(env.line_buffer))
    end

    panelpal.write_to_buf(buf, env.lines, PanelContentUpdateMethod.override)
    draw_highlight(buf, env.highlight)
end

-- ----------------------------------------------------------------------------

---@param file_path string # path to node-types.json
local function load_grammar(file_path)
    local file, err = io.open(file_path)
    if file == nil then
        vim.notify(err or "")
        return
    end

    local content = file:read("a")
    local grammar = vim.fn.json_decode(content)

    rules = grammar.rules or {}
end

---@param dir string # path to working directory
local function try_load_grammar(dir)
    rules = nil

    local grammar_path = vim.fn.join({ dir, "grammar.js" }, "/")
    if vim.fn.filereadable(grammar_path) == 0 then
        return
    end

    local node_type_path = vim.fn.join({ dir, "src", "grammar.json" }, "/")
    if vim.fn.filereadable(node_type_path) == 0 then
        return
    end

    load_grammar(node_type_path)
end

-- ----------------------------------------------------------------------------

local function on_vim_enter()
    local dir = vim.fn.getcwd()
    try_load_grammar(dir)
end

---@param info any
local function on_dir_changed(info)
    local dir = info.file
    try_load_grammar(dir)
end

---@param parent_node string
local function on_update_parent_node(parent_node)
    M.write_hint(parent_node)
end

-- ----------------------------------------------------------------------------

---@param force_show boolean
---@return number | nil buf
---@return number | nil win
local function get_buffer(force_show)
    local buf, win = panelpal.find_buf_with_name(GRAMMAR_HINT_PANEL_NAME)

    if not buf and force_show then
        buf, win = panelpal.set_panel_visibility(GRAMMAR_HINT_PANEL_NAME, true)
    end

    return buf, win
end

function M.clear_hint()
    local buf, win = get_buffer(false)
    if not (buf and win) then return end

    vim.bo[buf].modifiable = true
    panelpal.write_to_buf(buf, "", PanelContentUpdateMethod.override)
    api.nvim_buf_clear_namespace(buf, GRAMMAR_HINT_HL_NS, 0, -1)
    vim.bo[buf].modifiable = false
end

---@param node_name string
function M.write_hint(node_name)
    local buf, win = get_buffer(false)
    if not (buf and win) then return end

    M.clear_hint()

    vim.bo[buf].buftype = "nofile"
    vim.bo[buf].modifiable = true

    write_hint_to_buf(buf, node_name)
    if win then
        panelpal.scroll_win(win, ScrollMethod.top)
    end

    vim.bo[buf].modifiable = false
end

-- ----------------------------------------------------------------------------

vim.api.nvim_create_user_command("TSNaviShowHint", function()
    panelpal.set_panel_visibility(GRAMMAR_HINT_PANEL_NAME, true)
end, {
    desc = "display tree-sitter grammar hint panel"
})

vim.api.nvim_create_user_command("TSNaviHideHit", function()
    panelpal.set_panel_visibility(GRAMMAR_HINT_PANEL_NAME, false)
end, {
    desc = "hide tree-sitter grammar hint panel"
})

function M:init()
    event:on_autocmd("VimEnter", on_vim_enter)
    event:on_autocmd("DirChanged", on_dir_changed)
    event:on("UpdateParentNode", on_update_parent_node)
end

return M
