local NEW_LINE = "\n"
local HINT_INDENT = "    "
local CHOICE_CHILD_PREFIX = "|    "
local TRANSPARENT_PREFIX = "_"

local M = {
    NEW_LINE = NEW_LINE,
}

-- ----------------------------------------------------------------------------

---@param buffer string[]
---@param indent_level number
local function add_indent(buffer, indent_level)
    if indent_level <= 0 then return end
    for _ = 1, indent_level do
        table.insert(buffer, HINT_INDENT)
    end
end

---@param buffer string[]
---@param indent_level number
---@param skip_nl? boolean
local function nl_indent(buffer, indent_level, skip_nl)
    if skip_nl or indent_level < 0 then
        return
    end

    table.insert(buffer, NEW_LINE)
    add_indent(buffer, indent_level)
end

---@param value string
---@param hl_name string
local function hl(value, hl_name)
    return { value, highlight = hl_name }
end

-- ----------------------------------------------------------------------------

---@param env { buffer: string[], rules: { [string]: RuleInfo } }
---@param info RuleInfo
---@param indent? number
---@param skip_nl? boolean
function M.format(env, info, indent, skip_nl)
    if not info then return end

    indent = indent or 0
    local rules = env.rules

    if info.name and info.name:sub(1, 1) == TRANSPARENT_PREFIX then
        M.format_rule_info(env.buffer, rules and rules[info.name], indent, skip_nl)
    else
        vim.print(info.type)
        local formatter = M[info.type]
        formatter(env.buffer, info, indent, skip_nl)
    end
end

M.ALIAS = function(env, info, indent, skip_nl)
    local buffer = env.buffer

    nl_indent(buffer, indent, skip_nl)
    table.insert(buffer, hl(info.value, "@define"))
    table.insert(buffer, " (")
    table.insert(buffer, { info.content.name, highlight = "@variable" })
    table.insert(buffer, ")")
end

M.BLANK = function(env, info, indent, skip_nl)
    local buffer = env.buffer

    nl_indent(buffer, indent, skip_nl)
    table.insert(buffer, hl("BLANK", "@constant.builtin"))
end

M.FIELD = function(env, info, indent, skip_nl)
    local buffer = env.buffer

    nl_indent(buffer, indent, skip_nl)
    table.insert(buffer, "#[")
    table.insert(buffer, { info.value, highlight = "@define" })
    table.insert(buffer, "]: ")
    M.format_rule_info(buffer, info.content, indent, true)
end

M.CHOICE = function(env, info, indent, skip_nl)
    local buffer = env.buffer

    -- recognizing optional node
    if #info.members == 2 then
        local m1, m2 = info.members[1], info.members[2]
        local child
        if m1.type == m2.type then
            -- pass
        elseif m1.type == "BLANK" then
            child = { type = "OPTIONAL", content = m2 }
        elseif m2.type == "BLANK" then
            child = { type = "OPTIONAL", content = m1 }
        end

        if child then
            M.format_rule_info(buffer, child, indent)
            return
        end
    end

    nl_indent(buffer, indent, skip_nl)
    table.insert(buffer, "[")

    for _, child in ipairs(info.members) do
        M.format_rule_info(buffer, child, indent + 1)
    end

    nl_indent(buffer, indent)
    table.insert(buffer, "]")
end

M.OPTIONAL = function(env, info, indent, skip_nl)
    local buffer = env.buffer

    nl_indent(buffer, indent, skip_nl)
    table.insert(buffer, "?")
    M.format_rule_info(buffer, info.content, indent, true)
end

M.PREC = function(env, info, indent, skip_nl)
    local buffer = env.buffer

    M.format_rule_info(buffer, info.content, indent)
end

M.PREC_LEFT = function(env, info, indent, skip_nl)
    local buffer = env.buffer

    M.format_rule_info(buffer, info.content, indent)
end

M.PREC_RIGHT = function(env, info, indent, skip_nl)
    local buffer = env.buffer

    M.format_rule_info(buffer, info.content, indent)
end

M.PREC_DYNAMIC = function(env, info, indent, skip_nl)
    local buffer = env.buffer

    M.format_rule_info(buffer, info.content, indent)
end

M.REPEAT = function(env, info, indent, skip_nl)
    local buffer = env.buffer

    nl_indent(buffer, indent, skip_nl)
    table.insert(buffer, "*{")

    M.format_rule_info(buffer, info.content, indent + 1)

    nl_indent(buffer, indent)
    table.insert(buffer, "}")
end

M.REPEAT1 = function(env, info, indent, skip_nl)
    local buffer = env.buffer

    nl_indent(buffer, indent, skip_nl)
    table.insert(buffer, "+{")

    M.format_rule_info(buffer, info.content, indent + 1)

    nl_indent(buffer, indent)
    table.insert(buffer, "}")
end

M.SEQ = function(env, info, indent, skip_nl)
    local buffer = env.buffer

    for _, child in ipairs(info.members) do
        M.format_rule_info(buffer, child, indent)
    end
end

M.SYMBOL = function(env, info, indent, skip_nl)
    local buffer = env.buffer

    nl_indent(buffer, indent, skip_nl)
    table.insert(buffer, info.name)
end

M.TOKEN = function(env, info, indent, skip_nl)
    local buffer = env.buffer

    M.format_rule_info(buffer, info.content, indent)
end

M.IMMEDIATE_TOKEN = function(env, info, indent, skip_nl)
    local buffer = env.buffer

    M.format_rule_info(buffer, info.content, indent)
end

M.STRING = function(env, info, indent, skip_nl)
    local buffer = env.buffer

    nl_indent(buffer, indent, skip_nl)
    local text = info.value:gsub("\n", "\\n")
        :gsub("\r", "\\r")
        :gsub("\t", "\\t")
        :gsub("\v", "\\v")
    table.insert(buffer, {
        highlight = "@string",
        ('"%s"'):format(text)
    })
end

M.PATTERN = function(env, info, indent, skip_nl)
    local buffer = env.buffer

    nl_indent(buffer, indent, skip_nl)
    table.insert(buffer, "`")
    table.insert(buffer, info.value)
    table.insert(buffer, "`")
end

return M
