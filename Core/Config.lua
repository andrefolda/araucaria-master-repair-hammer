local _, ns = ...

local LEM = LibStub("LibEQOLEditMode-1.0")


local function SplitPath(path)
    local parts = {}

    for part in string.gmatch(path, "[^%.]+") do
        parts[#parts + 1] = part
    end

    return parts
end

local function GetNestedValue(root, path)
    local current = root
    local parts = SplitPath(path)

    for _, part in ipairs(parts) do
        if type(current) ~= "table" then
            return nil
        end

        current = current[part]

        if current == nil then
            return nil
        end
    end

    return current
end

local function SetNestedValue(root, path, value)
    local current = root
    local parts = SplitPath(path)

    for i = 1, #parts - 1 do
        local part = parts[i]

        if type(current[part]) ~= "table" then
            current[part] = {}
        end

        current = current[part]
    end

    current[parts[#parts]] = value
end

local function DeepCopy(value)
    if type(value) ~= "table" then
        return value
    end

    local copy = {}

    for key, nestedValue in pairs(value) do
        copy[key] = DeepCopy(nestedValue)
    end

    return copy
end

function ns:InitializeConfig()
    ArauMRHToolDB = ArauMRHToolDB or {}
    self.config = ArauMRHToolDB
end

function ns:InitializeCharConfig()
    ArauMRHToolCharDB = ArauMRHToolCharDB or {}
    self.charConfig = ArauMRHToolCharDB
end

function ns:GetConfig(path, fallback)
    if not self.config then
        return fallback
    end

    local value = GetNestedValue(self.config, path)

    if value == nil then

        local defaultValue = GetNestedValue(self.defaults, path)

        if defaultValue == nil then
            return fallback
        end

        self:SetConfig(path, DeepCopy(defaultValue))

        return self:GetConfig(path, fallback)
    end

    return value
end

function ns:SetConfig(path, value, refreshEquipmentFrame)
    if not self.config then
        return false
    end

    SetNestedValue(self.config, path, value)

    self:Debug("Config updated:", path, "=", value)

    if refreshEquipmentFrame then
        self:RefreshFrame()
    end

    return true
end

function ns:GetCharConfig(path, fallback)
    if not self.charConfig then
        return fallback
    end

    local value = GetNestedValue(self.charConfig, path)

    if value == nil then

        local defaultValue = GetNestedValue(self.defaults, path)

        if defaultValue == nil then
            return fallback
        end

        self:SetCharConfig(path, DeepCopy(defaultValue))

        return self:GetCharConfig(path, fallback)
    end

    return value
end

function ns:SetCharConfig(path, value)
    if not self.charConfig then
        return false
    end

    SetNestedValue(self.charConfig, path, value)

    self:Debug("Char config updated:", path, "=", value)

    return true
end

-- =========================================
-- Layout scoped config
-- =========================================

-- The layout name is a table key, never part of the dot path: names may contain
-- dots ("1.0 EUI", created by ElvUI) and would otherwise split into two keys.
local function GetLayoutTable(create)
    local layoutName = LEM:GetActiveLayoutName()

    if not ns.config or not layoutName then
        return nil
    end

    local editMode = ns.config.editMode

    if not editMode then
        if not create then
            return nil
        end

        editMode = {}
        ns.config.editMode = editMode
    end

    local layouts = editMode.layouts

    if not layouts then
        if not create then
            return nil
        end

        layouts = {}
        editMode.layouts = layouts
    end

    if not layouts[layoutName] and create then
        layouts[layoutName] = {}
    end

    return layouts[layoutName]
end

function ns:GetLayoutConfig(path, fallback)
    local layout = GetLayoutTable(false)
    local value = layout and GetNestedValue(layout, path)

    if value ~= nil then
        return value
    end

    local defaultValue = GetNestedValue(self.defaults, path)

    if defaultValue == nil then
        return fallback
    end

    layout = GetLayoutTable(true)

    if not layout then
        return DeepCopy(defaultValue)
    end

    SetNestedValue(layout, path, DeepCopy(defaultValue))

    return GetNestedValue(layout, path)
end

function ns:IsValidOrientation(value)
    return value == ns.enums.Orientation.HorizontalCenter
        or value == ns.enums.Orientation.HorizontalLeftToRight
        or value == ns.enums.Orientation.HorizontalRightToLeft
        or value == ns.enums.Orientation.VerticalCenter
        or value == ns.enums.Orientation.VerticalTopToBottom
        or value == ns.enums.Orientation.VerticalBottomToTop
end

function ns:SetLayoutConfig(path, value, refreshEquipmentFrame)
    if path == "icon.orientation" and not self:IsValidOrientation(value) then
        return false
    end

    local layout = GetLayoutTable(true)

    if not layout then
        self:Debug("Layout config not updated, no active layout:", path)
        return false
    end

    SetNestedValue(layout, path, value)

    self:Debug("Layout config updated:", path, "=", value)

    if refreshEquipmentFrame then
        self:RefreshFrame()
    end

    return true
end

-- Layout names used to be concatenated into the config path, so a name with a dot
-- was stored split across two keys ("1.0 EUI" -> layouts["1"]["0 EUI"]). Copy that
-- data over to the correctly keyed table; the old keys are left untouched.
local function CopyLegacySplitLayoutConfig(layouts, layoutName)
    if not string.find(layoutName, ".", 1, true) then
        return nil
    end

    local legacy = GetNestedValue(layouts, layoutName)

    if type(legacy) ~= "table" then
        return nil
    end

    return DeepCopy(legacy)
end

function ns:EnsureLayoutDefaults()
    local layout = GetLayoutTable(true)

    if not layout then
        return
    end

    local layoutName = LEM:GetActiveLayoutName()
    local layouts = self.config.editMode.layouts

    if not next(layout) then
        layouts[layoutName] = CopyLegacySplitLayoutConfig(layouts, layoutName) or layout
        layout = layouts[layoutName]
    end

    for _, key in ipairs(ns.const.LayoutScopedDefaultKeys) do
        if layout[key] == nil then
            layout[key] = DeepCopy(self.defaults[key])
        end
    end
end
