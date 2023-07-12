local Source = require "ts-grammar-nav.source"

local M = {}

function M.setup()
    local cmp = require "cmp"

    local source = Source:new()
    cmp.register_source(source.name, source)

    local augroup = vim.api.nvim_create_augroup("ts-grammar-navigator.setup", { clear = true })
    vim.api.nvim_create_autocmd("VimEnter", {
        group = augroup,
        callback = function()
            local dir = vim.fn.getcwd()

            local grammar_path = vim.fn.join({ dir, "grammar.js" }, "/")
            if vim.fn.filereadable(grammar_path) == 0 then
                return
            end

            local node_type_path = vim.fn.join({ dir, "src", "node-types.json" }, "/")
            if vim.fn.filereadable(node_type_path) == 0 then
                return
            end

            source:load_node_types(node_type_path)
        end,
    })
end

return M
