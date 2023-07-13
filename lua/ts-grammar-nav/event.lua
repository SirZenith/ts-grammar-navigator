---@alias EventCallback fun(...: any)
---@alias CallbacnInfo { obj: any, callback: EventCallback }
---@alias ChannelGroup { [string]: CallbacnInfo[] }

-- ----------------------------------------------------------------------------

local M = {}

local id_counter = 0

---@type ChannelGroup
local autocmd_channels = {
    DirChanged = {},
    VimEnter = {},
}

---@type ChannelGroup
local channels = {
    UpdateParentNode = {}, -- fun(node_name: string)
}

-- ----------------------------------------------------------------------------

---@return number
local function get_new_id()
    local id = id_counter + 1
    id_counter = id
    return id
end

---@param group ChannelGroup
---@param event_name string
---@param callback EventCallback
---@param obj? any
---@return number | nil handle
local function on(group, event_name, callback, obj)
    local channel = group[event_name]
    if not channel then
        error(event_name .. " does not exists", 2)
        return nil
    end

    local id = get_new_id()
    channel[id] = { obj = obj, callback = callback }

    return id
end

---@param group ChannelGroup
---@param event_name string
---@param handle number
local function off(group, event_name, handle)
    local channel = group[event_name]
    if not channel then return end

    channel[handle] = nil
end

---@param group ChannelGroup
---@param event_name string
---@param ... any
local function emit(group, event_name, ...)
    local channel = group[event_name]
    if not channel then return end

    for _, callback_info in pairs(channel) do
        local callback = callback_info.callback
        local obj = callback_info.obj
        if obj ~= nil then
            callback(obj, ...)
        else
            callback(...)
        end
    end
end

-- ----------------------------------------------------------------------------

---@param event_name string
---@param callback EventCallback
---@return number | nil handle
function M:on(event_name, callback, obj)
    return on(channels, event_name, callback, obj)
end

---@param handle number
function M:off(event_name, handle)
    off(channels, event_name, handle)
end

---@param event_name string
---@param ... any
function M:emit(event_name, ...)
    emit(channels, event_name, ...)
end

---@param event_name string
---@param callback EventCallback
---@return number | nil handle
function M:on_autocmd(event_name, callback, obj)
    return on(autocmd_channels, event_name, callback, obj)
end

---@param handle number
function M:off_autocmd(event_name, handle)
    off(autocmd_channels, event_name, handle)
end

-- ----------------------------------------------------------------------------

function M:init()
    local augroup = vim.api.nvim_create_augroup("ts-grammar-navigator.event.setup", { clear = true })

    for event_name in pairs(autocmd_channels) do
        vim.api.nvim_create_autocmd(event_name, {
            group = augroup,
            callback = function(info)
                emit(autocmd_channels, event_name, info)
            end,
        })
    end
end

return M
