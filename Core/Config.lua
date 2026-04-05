local _, ns = ...

local LEM = LibStub("LibEQOLEditMode-1.0")


local function removeLayoutFromPath(path)
    return string.gsub(path, "^editMode%.layouts%.[^%.]+%.", "")
end

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

function ns:GetConfig(path, fallback)
    if not self.config then
        return fallback
    end

    local value = GetNestedValue(self.config, path)

    if value == nil then

        local defaultValue = GetNestedValue(self.defaults, removeLayoutFromPath(path))

        if defaultValue == nil then
            return fallback
        end

        self:SetConfig(path, DeepCopy(defaultValue))

        return self:GetConfig(path, fallback)
    end

    return value
end

function ns:GetLayoutConfig(path, fallback)

    local layoutName = LEM.GetActiveLayoutName()
    local layoutConfigName = "editMode.layouts." .. layoutName
    path = layoutConfigName .. "." .. path

    return self:GetConfig(path, fallback)
end

function ns:IsValidOrientation(value)
    return value == ns.enums.Orientation.HorizontalCenter
        or value == ns.enums.Orientation.HorizontalLeftToRight
        or value == ns.enums.Orientation.HorizontalRightToLeft
        or value == ns.enums.Orientation.VerticalCenter
        or value == ns.enums.Orientation.VerticalTopToBottom
        or value == ns.enums.Orientation.VerticalBottomToTop
end

local function isValidSetConfig(path, value)
    if not ns.config then
        return false
    end

    local layoutlessPath = removeLayoutFromPath(path)

    if layoutlessPath == "icon.orientation" and not ns:IsValidOrientation(value) then
        return false
    end

    return true
end

function ns:SetConfig(path, value, refreshEquipmentFrame)
    if refreshEquipmentFrame == nil then
        refreshEquipmentFrame = false
    end

    if not isValidSetConfig(path, value) then
        return false
    end

    SetNestedValue(self.config, path, value)

    self:Debug("Config updated:", path, "=", value)

    if refreshEquipmentFrame then
        self:RefreshFrame()
    end

    return true
end

function ns:SetLayoutConfig(path, value, refreshEquipmentFrame)

    local layoutName = LEM.GetActiveLayoutName()
    local layoutConfigName = "editMode.layouts." .. layoutName
    path = layoutConfigName .. "." .. path

    return self:SetConfig(path, value, refreshEquipmentFrame)
end