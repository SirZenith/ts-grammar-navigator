local event = require "ts-grammar-nav.event"
local source = require "ts-grammar-nav.source"
local grammar_hint = require "ts-grammar-nav.grammar-hint"
local formatting = require "ts-grammar-nav.formatting"

local M = {}

event:init()
source:init()
grammar_hint:init()

function M.setup(options)
    options = options or {}

    local cmp = require "cmp"
    cmp.register_source(source.name, source)

    formatting.setup({
        indent = options.indent
    })
end

return M
