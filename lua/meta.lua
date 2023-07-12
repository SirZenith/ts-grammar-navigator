---@meta

---@class NodeSimpleInfo
---@field type string
---@field named boolean

---@class NodeChildInfo
---@field required boolean
---@field multiple boolean
---@field types NodeSimpleInfo[]

---@class NodeInfo : NodeSimpleInfo
---@field fields? { [string]: NodeChildInfo }
---@field children? NodeChildInfo

---@class CompletionItem
---@field label string
---@field dup number
