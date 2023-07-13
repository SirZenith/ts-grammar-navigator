local event = require "ts-grammar-nav.event"
local source = require "ts-grammar-nav.source"
local grammar_hint = require "ts-grammar-nav.grammar-hint"

local M = {}

event:init()
source:init()
grammar_hint:init()

function M.setup()
    local cmp = require "cmp"
    cmp.register_source(source.name, source)
end

return M
