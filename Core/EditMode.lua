local _, ns = ...

local LEM = LibStub("LibEQOLEditMode-1.0")
local LSM = LibStub("LibSharedMedia-3.0")
local L   = ns.L

function ns:RegisterEditModeCallbacks()
    if self.editModeCallbacksRegistered then
        return
    end

    LEM:RegisterCallback("enter", function()
        ns:Debug("Edit Mode enter")
        ns:EnableEditModePreview()
    end)

    LEM:RegisterCallback("exit", function()
        ns:Debug("Edit Mode exit")
        ns:DisableEditModePreview()
    end)

    self.editModeCallbacksRegistered = true
end

-- =========================================
-- Position Settings
-- =========================================

function ns:GetLastSavedFramePosition()
    return {
        point = self:GetLayoutConfig("frame.point"),
        relativePoint = self:GetLayoutConfig("frame.relativePoint"),
        x = self:GetLayoutConfig("frame.x"),
        y = self:GetLayoutConfig("frame.y"),
    }
end

function ns:GetDefaultFramePosition()
    return {
        point = ns.defaults.frame.point,
        relativePoint = ns.defaults.frame.relativePoint,
        x = ns.defaults.frame.x,
        y = ns.defaults.frame.y,
    }
end

local function EnsureLayoutConfig()
    if not ns:GetConfig("editMode") then
        ns:SetConfig("editMode", {})
    end

    if not ns:GetConfig("editMode.layouts") then
        ns:SetConfig("editMode.layouts", {})
    end

    local layoutName = LEM.GetActiveLayoutName()
    local layoutPath = "editMode.layouts." .. layoutName
    if not ns:GetConfig(layoutPath) then
        ns:SetConfig(layoutPath, {})
    end

    return ns:GetLayoutConfig("")
end

function ns:GetCurrentLayoutFramePosition()
    local layoutConfig = EnsureLayoutConfig()

    if not layoutConfig
        or not layoutConfig.frame
        or not layoutConfig.frame.point
    then
        return self:GetDefaultFramePosition()
    end

    return layoutConfig.frame
end

local orientationAnchor = {
    [ns.enums.Orientation.HorizontalLeftToRight] = ns.enums.Blizz.FramePoint.Left,
    [ns.enums.Orientation.HorizontalRightToLeft] = ns.enums.Blizz.FramePoint.Right,
    [ns.enums.Orientation.HorizontalCenter]      = ns.enums.Blizz.FramePoint.Center,
    [ns.enums.Orientation.VerticalTopToBottom]   = ns.enums.Blizz.FramePoint.Top,
    [ns.enums.Orientation.VerticalBottomToTop]   = ns.enums.Blizz.FramePoint.Bottom,
    [ns.enums.Orientation.VerticalCenter]        = ns.enums.Blizz.FramePoint.Center,
}


function ns:GetOrientationAnchor()
    local orientation = self:GetLayoutConfig("icon.orientation")
    return orientationAnchor[orientation] or ns.enums.Blizz.FramePoint.Center
end

local function SaveFramePositionForAnchor(frame, anchor)
    local screenX, screenY
    if anchor == ns.enums.Blizz.FramePoint.Left then
        screenX = frame:GetLeft()
        _, screenY = frame:GetCenter()
    elseif anchor == ns.enums.Blizz.FramePoint.Right then
        screenX = frame:GetRight()
        _, screenY = frame:GetCenter()
    elseif anchor == ns.enums.Blizz.FramePoint.Top then
        screenX, _ = frame:GetCenter()
        screenY = frame:GetTop()
    elseif anchor == ns.enums.Blizz.FramePoint.Bottom then
        screenX, _ = frame:GetCenter()
        screenY = frame:GetBottom()
    else
        screenX, screenY = frame:GetCenter()
    end

    local uiCenterX = UIParent:GetWidth()  / 2
    local uiCenterY = UIParent:GetHeight() / 2
    local uiAnchorX, uiAnchorY
    if anchor == ns.enums.Blizz.FramePoint.Left then
        uiAnchorX, uiAnchorY = 0, uiCenterY
    elseif anchor == ns.enums.Blizz.FramePoint.Right then
        uiAnchorX, uiAnchorY = UIParent:GetWidth(), uiCenterY
    elseif anchor == ns.enums.Blizz.FramePoint.Top then
        uiAnchorX, uiAnchorY = uiCenterX, UIParent:GetHeight()
    elseif anchor == ns.enums.Blizz.FramePoint.Bottom then
        uiAnchorX, uiAnchorY = uiCenterX, 0
    else
        uiAnchorX, uiAnchorY = uiCenterX, uiCenterY
    end

    ns:SetLayoutConfig("frame.point", anchor)
    ns:SetLayoutConfig("frame.relativePoint", anchor)
    ns:SetLayoutConfig("frame.x", screenX - uiAnchorX)
    ns:SetLayoutConfig("frame.y", screenY - uiAnchorY)
end

function ns:ApplyCurrentLayoutFramePosition(frame)
    if not frame then
        return
    end

    local position = self:GetCurrentLayoutFramePosition()
    local anchor   = self:GetOrientationAnchor()

    frame:ClearAllPoints()
    frame:SetPoint(anchor, UIParent, anchor, position.x, position.y)
end

-- =========================================
-- Addon Configuration Settings
-- =========================================

local function BuildOrientationValues()
    return {
        { text = L.ORIENTATION_HORIZONTAL_CENTER, value = ns.enums.Orientation.HorizontalCenter },
        { text = L.ORIENTATION_HORIZONTAL_LTR,    value = ns.enums.Orientation.HorizontalLeftToRight },
        { text = L.ORIENTATION_HORIZONTAL_RTL,    value = ns.enums.Orientation.HorizontalRightToLeft },
        { text = L.ORIENTATION_VERTICAL_CENTER,   value = ns.enums.Orientation.VerticalCenter },
        { text = L.ORIENTATION_VERTICAL_TTB,      value = ns.enums.Orientation.VerticalTopToBottom },
        { text = L.ORIENTATION_VERTICAL_BTT,      value = ns.enums.Orientation.VerticalBottomToTop },
    }
end

local function BuildFontValues()
    local values = {}
    local fontNames = LSM:List("font")

    for _, fontName in ipairs(fontNames) do
        values[#values + 1] = {
            text = fontName,
            value = LSM:Fetch("font", fontName) or nil,
        }
    end

    return values
end

local function ThresholdToPercent(t)
    return math.floor(t * 100 + 0.5)
end

local function PercentToThreshold(p)
    return p / 100
end

local function AddFrameSettings(frame)
    local settings = {

        {
            id = "durabilityThresholdConfig",
            name = L.DURABILITY_THRESHOLD_SETTINGS,
            kind = LEM.SettingType.Collapsible,
            defaultCollapsed = false,
        },
        {
            parentId = "durabilityThresholdConfig",
            name = L.SHOW_DURABILITY,
            kind = LEM.SettingType.Slider,
            field = "durabilityThreshold",
            default = ThresholdToPercent(ns.defaults.durabilityThreshold),
            minValue = 0,
            maxValue = 100,
            valueStep = 1,
            allowInput = true,
            formatter = function(value)
                return string.format("%d%%", value)
            end,
            get = function()
                return ThresholdToPercent(ns:GetLayoutConfig("durabilityThreshold"))
            end,
            set = function(_, value)
                ns:SetLayoutConfig("durabilityThreshold", PercentToThreshold(value), true)
            end,
        },
        {
            parentId = "durabilityThresholdConfig",
            name = L.LOW_DURABILITY,
            kind = LEM.SettingType.Slider,
            field = "lowDurabilityThreshold",
            default = ThresholdToPercent(ns.defaults.lowDurabilityThreshold),
            minValue = 0,
            maxValue = 100,
            valueStep = 1,
            allowInput = true,
            formatter = function(value)
                return string.format("%d%%", value)
            end,
            get = function()
                return ThresholdToPercent(ns:GetLayoutConfig("lowDurabilityThreshold"))
            end,
            set = function(_, value)
                ns:SetLayoutConfig("lowDurabilityThreshold", PercentToThreshold(value), true)
            end,
        },
        {
            parentId = "durabilityThresholdConfig",
            name = L.CRITICAL_DURABILITY,
            kind = LEM.SettingType.Slider,
            field = "criticalDurabilityThreshold",
            default = ThresholdToPercent(ns.defaults.criticalDurabilityThreshold),
            minValue = 0,
            maxValue = 100,
            valueStep = 1,
            allowInput = true,
            formatter = function(value)
                return string.format("%d%%", value)
            end,
            get = function()
                return ThresholdToPercent(ns:GetLayoutConfig("criticalDurabilityThreshold"))
            end,
            set = function(_, value)
                ns:SetLayoutConfig("criticalDurabilityThreshold", PercentToThreshold(value), true)
            end,
        },



        {
            id = "iconConfigs",
            name = L.ICON_SETTINGS,
            kind = LEM.SettingType.Collapsible,
            defaultCollapsed = false,
        },
        {
            parentId = "iconConfigs",
            name = L.ORIENTATION,
            kind = LEM.SettingType.Dropdown,
            field = "orientation",
            default = ns.defaults.icon.orientation,
            values = BuildOrientationValues(),
            useOldStyle = true,
            get = function()
                return ns:GetLayoutConfig("icon.orientation")
            end,
            set = function(_, value)
                local newAnchor = orientationAnchor[value] or ns.enums.Blizz.FramePoint.Center
                if ns.equipmentFrame then
                    SaveFramePositionForAnchor(ns.equipmentFrame, newAnchor)
                end
                ns:SetLayoutConfig("icon.orientation", value, true)
            end,
        },
        {
            parentId = "iconConfigs",
            name = L.ICON_SIZE,
            kind = LEM.SettingType.Slider,
            field = "iconSize",
            default = ns.defaults.icon.width,
            minValue = 5,
            maxValue = 100,
            valueStep = 1,
            allowInput = true,
            formatter = function(value)
                return tostring(value)
            end,
            get = function()
                return ns:GetLayoutConfig("icon.width")
            end,
            set = function(_, value)
                ns:SetLayoutConfig("icon.width", value, true)
                ns:SetLayoutConfig("icon.height", value, true)
            end,
        },



        {
            id = "iconDurabilityTextConfigs",
            name = L.DURABILITY_TEXT_SETTINGS,
            kind = LEM.SettingType.Collapsible,
            defaultCollapsed = false,
        },
        {
            parentId = "iconDurabilityTextConfigs",
            name = L.SIZE,
            kind = LEM.SettingType.Slider,
            field = "durabilityTextSize",
            default = ns.defaults.icon.durabilityText.size,
            minValue = 6,
            maxValue = 32,
            valueStep = 1,
            allowInput = true,
            formatter = function(value)
                return tostring(value)
            end,
            get = function()
                return ns:GetLayoutConfig("icon.durabilityText.size")
            end,
            set = function(_, value)
                ns:SetLayoutConfig("icon.durabilityText.size", value, true)
            end,
        },
        {
            parentId = "iconDurabilityTextConfigs",
            name = L.FONT,
            kind = LEM.SettingType.Dropdown,
            field = "durabilityTextFont",
            default = ns.defaults.icon.durabilityText.font,
            values = BuildFontValues(),
            useOldStyle = true,
            height = 300,
            get = function()
                return ns:GetLayoutConfig("icon.durabilityText.font")
            end,
            set = function(_, value)
                ns:SetLayoutConfig("icon.durabilityText.font", value, true)
            end,
        },
        {
            parentId = "iconDurabilityTextConfigs",
            name = L.X_OFFSET,
            kind = LEM.SettingType.Slider,
            field = "durabilityTextXOffset",
            default = ns.defaults.icon.durabilityText.position.xOffset,
            minValue = -50,
            maxValue = 50,
            valueStep = 1,
            allowInput = true,
            formatter = function(value)
                return tostring(value)
            end,
            get = function()
                return ns:GetLayoutConfig("icon.durabilityText.position.xOffset")
            end,
            set = function(_, value)
                ns:SetLayoutConfig("icon.durabilityText.position.xOffset", value, true)
            end,
        },
        {
            parentId = "iconDurabilityTextConfigs",
            name = L.Y_OFFSET,
            kind = LEM.SettingType.Slider,
            field = "durabilityTextYOffset",
            default = ns.defaults.icon.durabilityText.position.yOffset,
            minValue = -50,
            maxValue = 50,
            valueStep = 1,
            allowInput = true,
            formatter = function(value)
                return tostring(value)
            end,
            get = function()
                return ns:GetLayoutConfig("icon.durabilityText.position.yOffset")
            end,
            set = function(_, value)
                ns:SetLayoutConfig("icon.durabilityText.position.yOffset", value, true)
            end,
        },



    }

    LEM:AddFrameSettings(frame, settings)
end

-- =========================================
-- Edit Mode Register
-- =========================================

function ns:RegisterFrameWithEditMode(frame)
    if not frame then
        return
    end

    if frame.isRegisteredWithLEM then
        return
    end

    local defaults = self:GetDefaultFramePosition()
    defaults.showReset = false
    defaults.enableOverlayToggle = true

    LEM:AddFrame(
        frame,
        function(_, layoutName, point, x, y)
            SaveFramePositionForAnchor(frame, ns:GetOrientationAnchor())
            ns:Debug("EditMode moved:", layoutName, point, x, y)
            ns:RefreshFrame()
        end,
        defaults
    )

    AddFrameSettings(frame)

    frame.isRegisteredWithLEM = true
end