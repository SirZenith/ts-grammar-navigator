local panelpal = require "panelpal"

local event = require "ts-grammar-nav.event"
local grammar_hint = require "ts-grammar-nav.grammar-hint"
local formatting = require "ts-grammar-nav.formatting"

local M = {}

local cmd_list = {
    {
        "TSNaviReload",
        function()
            event:emit("Reload")
        end,
        desc = "reload grammar data from current workspace"
    },
    {
        "TSNaviFormatSelection",
        formatting.format_selection,
        desc = "format selected S-expression"
    },
    {
        "TSNaviShowHint",
        function()
            panelpal.set_panel_visibility(
                grammar_hint.GRAMMAR_HINT_PANEL_NAME,
                true
            )
        end,
        desc = "display tree-sitter grammar hint panel"
    },
    {
        "TSNaviHideHit",
        function()
            panelpal.set_panel_visibility(
                grammar_hint.GRAMMAR_HINT_PANEL_NAME,
                false
            )
        end,
        desc = "hide tree-sitter grammar hint panel",
    },
}

function M.setup()
    for _, info in ipairs(cmd_list) do
        local options = {}
        for k, v in pairs(info) do
            if type(k) ~= "number" then options[k] = v end
        end
        vim.api.nvim_create_user_command(info[1], info[2], options)
    end
end

return M
