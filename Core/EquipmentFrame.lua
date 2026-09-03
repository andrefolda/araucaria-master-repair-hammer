local _, ns = ...

local L = ns.L

-- MainHand/OffHand can hold any weapon bucket (or a shield, OffHand only), so their
-- macro depends on the currently equipped item and must be resolved every refresh.
-- The other 8 (pure armor) slots are resolved once at login, see SetArmorSlotMacro.
local dynamicMacroSlots = { [16] = true, [17] = true }

local warningIconTexturePath = "Interface\\DialogFrame\\UI-Dialog-Icon-AlertNew"

local function ShowTooltip(owner)
    if not owner.slotId then
        return
    end

    GameTooltip:SetOwner(owner, ns.enums.Blizz.TooltipAnchor.AnchorLeft)
    GameTooltip:SetInventoryItem(ns.enums.Blizz.Unit.Player, owner.slotId)

    if ShoppingTooltip1 then
        ShoppingTooltip1:Hide()
    end

    if ShoppingTooltip2 then
        ShoppingTooltip2:Hide()
    end

    GameTooltip:Show()
end

local function HideTooltip()
    GameTooltip:Hide()

    if ShoppingTooltip1 then
        ShoppingTooltip1:Hide()
    end

    if ShoppingTooltip2 then
        ShoppingTooltip2:Hide()
    end
end

local function SetArmorSlotMacro(iconFrame, slotId)
    local plan = ns.repairPlan and ns.repairPlan.bySlot[slotId]

    if plan then
        iconFrame:SetAttribute("macrotext", "/use item:" .. plan.hammerItemId .. "\r\n/use " .. slotId)
    end
end

local function CreateEquipmentIconFrame(frame, slotId)

    local iconFrame = CreateFrame(
        ns.enums.Blizz.FrameType.Button,
        ns.const.UI.SlotFrameName[slotId],
        frame,
        ns.enums.Blizz.Template.SecureActionButtonTemplate
    )

    iconFrame:Hide()
    iconFrame:RegisterForClicks(ns.enums.Blizz.ClickButton.AnyDown)

    iconFrame.texture = iconFrame:CreateTexture(
        ns.const.UI.IconTextureName[slotId],
        ns.enums.Blizz.DrawLayer.Artwork
    )
    iconFrame.texture:SetAllPoints(iconFrame)

    iconFrame.text = iconFrame:CreateFontString(
        ns.const.UI.DurabilityStringName[slotId],
        ns.enums.Blizz.DrawLayer.Overlay
    )

    iconFrame.text:SetFont(
        ns:GetLayoutConfig("icon.durabilityText.font"),
        ns:GetLayoutConfig("icon.durabilityText.size"),
        ns:GetLayoutConfig("icon.durabilityText.outline")
    )

    iconFrame.warningIcon = CreateFrame(ns.enums.Blizz.FrameType.Frame, nil, iconFrame)
    iconFrame.warningIcon:EnableMouse(true)
    iconFrame.warningIcon:Hide()

    -- Poor man's outline: a black copy of the same texture, slightly larger and
    -- drawn behind (Artwork < Overlay), peeking out around the icon's shape.
    iconFrame.warningIcon.outline = iconFrame.warningIcon:CreateTexture(nil, ns.enums.Blizz.DrawLayer.Artwork)
    iconFrame.warningIcon.outline:SetTexture(warningIconTexturePath)
    iconFrame.warningIcon.outline:SetVertexColor(0, 0, 0, 1)
    iconFrame.warningIcon.outline:SetPoint(ns.enums.Blizz.FramePoint.TopLeft, iconFrame.warningIcon, -1, 1)
    iconFrame.warningIcon.outline:SetPoint(ns.enums.Blizz.FramePoint.BottomRight, iconFrame.warningIcon, 1, -1)

    iconFrame.warningIcon.texture = iconFrame.warningIcon:CreateTexture(nil, ns.enums.Blizz.DrawLayer.Overlay)
    iconFrame.warningIcon.texture:SetAllPoints(iconFrame.warningIcon)
    iconFrame.warningIcon.texture:SetTexture(warningIconTexturePath)

    iconFrame.warningIcon:SetScript(ns.enums.Blizz.ScriptTypeName.ScriptRegion.OnEnter, function(self)
        GameTooltip:SetOwner(self, ns.enums.Blizz.TooltipAnchor.AnchorRight)
        GameTooltip:SetText(L.CANNOT_REPAIR_TOOLTIP)
        GameTooltip:Show()
    end)

    iconFrame.warningIcon:SetScript(ns.enums.Blizz.ScriptTypeName.ScriptRegion.OnLeave, function()
        GameTooltip:Hide()
    end)

    iconFrame.slotId = slotId
    iconFrame.current = nil
    iconFrame.maximum = nil
    iconFrame.ratio = nil

    iconFrame:SetScript(ns.enums.Blizz.ScriptTypeName.ScriptRegion.OnEnter, function(self)
        ShowTooltip(self)
    end)

    iconFrame:SetScript(ns.enums.Blizz.ScriptTypeName.ScriptRegion.OnLeave, function()
        HideTooltip()
    end)

    iconFrame:SetAttribute("type", "macro")

    if not dynamicMacroSlots[slotId] then
        SetArmorSlotMacro(iconFrame, slotId)
    end

    ns:HookGoldTrackingForIcon(iconFrame)

    return iconFrame
end

function ns:CreateAddonFrame()
    ns:Debug("ns:CreateAddonFrame - start")

    if self.equipmentFrame then
        return
    end

    local frame = CreateFrame(
        ns.enums.Blizz.FrameType.Frame,
        ns.const.UI.MainFrameName,
        UIParent,
        ns.enums.Blizz.Template.BackdropTemplate
    )

    frame.editModeName = ns.const.UI.EditModeFrameName

    frame:SetSize(0, 0)
    ns:ApplyCurrentLayoutFramePosition(frame)
    frame:Hide()

    frame.icons = {}

    for i, slotId in ipairs(ns.const.Equipment.WatchedSlots) do
        frame.icons[i] = CreateEquipmentIconFrame(frame, slotId)
    end

    if self.config and self.config.debugEnabled then
        frame:SetBackdrop({
            edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
            edgeSize = 4,
        })
    end

    self.equipmentFrame = frame
    ns:Debug("ns:CreateAddonFrame - end")
end

local function GetLowDurabilityItems()
    local threshold = ns:GetLayoutConfig("durabilityThreshold")
    local showOnlyRepairable = ns:GetLayoutConfig("showOnlyRepairable")
    local lowDurabilityItems = {}

    for _, slotId in ipairs(ns.const.Equipment.WatchedSlots) do
        local current, maximum = GetInventoryItemDurability(slotId)

        if current and maximum and maximum > 0 then
            local ratio = current / maximum

            if ratio <= threshold then
                local texture = GetInventoryItemTexture(ns.enums.Blizz.Unit.Player, slotId)

                if texture then
                    local itemLevelReq, classID, subclassID
                    local itemLink = GetInventoryItemLink(ns.enums.Blizz.Unit.Player, slotId)

                    if itemLink then
                        local _, _, _, _, minLevel, _, _, _, _, _, _, itemClassID, itemSubClassID =
                            C_Item.GetItemInfo(itemLink)
                        itemLevelReq = minLevel
                        classID = itemClassID
                        subclassID = itemSubClassID
                    end

                    local repairable = ns:CanRepairSlot(slotId, itemLevelReq, classID, subclassID)

                    if repairable or not showOnlyRepairable then
                        lowDurabilityItems[slotId] = {
                            slotId = slotId,
                            texture = texture,
                            current = current,
                            maximum = maximum,
                            ratio = ratio,
                            itemLevelReq = itemLevelReq,
                            classID = classID,
                            subclassID = subclassID,
                            repairable = repairable,
                        }
                    end
                end
            end
        end
    end

    return lowDurabilityItems
end

ns.forceDummyRefresh = false
ns.dummyItems = {}
local function GetDummyItems()

    if ns.forceDummyRefresh then
        ns.forceDummyRefresh = false
        ns.dummyItems = {}
    end

    if next(ns.dummyItems) then
        return ns.dummyItems
    end

    local dummyTextures = {
        [1] = 133159,  -- Head
        [3] = 135062,  -- Shoulder
        [5] = 132750,  -- Chest
        [6] = 132504,  -- Waist
        [7] = 134581,  -- Legs
        [8] = 132541,  -- Feet
        [9] = 132609,  -- Wrist
        [10] = 132939, -- Hands
        [16] = 135274, -- MainHand
        [17] = 134950, -- OffHand
    }

    local durabilityThreshold = ns:GetLayoutConfig("durabilityThreshold")
    local showOnlyRepairable = ns:GetLayoutConfig("showOnlyRepairable")

    local slots = ns.const.Equipment.WatchedSlots
    local unrepairableSlots = {}
    do
        local pool = {}
        for i, slotId in ipairs(slots) do
            pool[i] = slotId
        end

        local unrepairableCount = math.min(math.random(1, 3), #pool)
        for _ = 1, unrepairableCount do
            local index = math.random(1, #pool)
            unrepairableSlots[table.remove(pool, index)] = true
        end
    end

    for _, slotId in ipairs(slots) do

        local ratio = math.random() * durabilityThreshold

        local texture = dummyTextures[slotId]
        local repairable = not unrepairableSlots[slotId]

        if repairable or not showOnlyRepairable then
            ns.dummyItems[slotId] = {
                slotId = slotId,
                texture = texture,
                current = ratio * 100,
                maximum = 100,
                ratio = ratio,
                itemLevelReq = 90,
                classID = ns.enums.Blizz.Item.ClassID.Armor,
                subclassID = repairable
                    and ns.enums.Blizz.Item.ArmorSubclassID.Plate
                    or ns.enums.Blizz.Item.ArmorSubclassID.Leather,
                repairable = repairable,
            }
        end

    end

    return ns.dummyItems
end

local function LayoutIconText(iconFrame, itemData)

    iconFrame.text:SetPoint(
        ns:GetLayoutConfig("icon.durabilityText.position.point"),
        iconFrame,
        ns:GetLayoutConfig("icon.durabilityText.position.relative"),
        ns:GetLayoutConfig("icon.durabilityText.position.xOffset"),
        ns:GetLayoutConfig("icon.durabilityText.position.yOffset")
    )

    iconFrame.text:SetFont(
        ns:GetLayoutConfig("icon.durabilityText.font"),
        ns:GetLayoutConfig("icon.durabilityText.size"),
        ns:GetLayoutConfig("icon.durabilityText.outline")
    )
    local percent = math.floor((itemData.ratio * 100) + 0.5)
    iconFrame.text:SetText(percent .. "%")

    local lowThreshold = ns:GetLayoutConfig("lowDurabilityThreshold")
    local criticalThreshold = ns:GetLayoutConfig("criticalDurabilityThreshold")

    if itemData.ratio <= criticalThreshold then
        iconFrame.text:SetTextColor(unpack(ns:GetLayoutConfig("icon.durabilityText.color.criticalDurability")))
    elseif itemData.ratio <= lowThreshold then
        iconFrame.text:SetTextColor(unpack(ns:GetLayoutConfig("icon.durabilityText.color.lowDurability")))
    else
        iconFrame.text:SetTextColor(unpack(ns:GetLayoutConfig("icon.durabilityText.color.default")))
    end
end

local function SetWeaponSlotMacro(iconFrame, slotId, itemData)
    local plan = ns:GetRepairPlanEntry(slotId, itemData.classID, itemData.subclassID)

    if plan then
        iconFrame:SetAttribute("macrotext", "/use item:" .. plan.hammerItemId .. "\r\n/use " .. slotId)
    end
end

local function LayoutWarningIcon(iconFrame, itemData)
    local size = ns:GetLayoutConfig("icon.warningIcon.size")

    iconFrame.warningIcon:SetSize(size, size)
    iconFrame.warningIcon:ClearAllPoints()
    iconFrame.warningIcon:SetPoint(
        ns.enums.Blizz.FramePoint.TopRight,
        iconFrame,
        ns.enums.Blizz.FramePoint.TopRight,
        ns:GetLayoutConfig("icon.warningIcon.position.xOffset"),
        ns:GetLayoutConfig("icon.warningIcon.position.yOffset")
    )

    if itemData.repairable == false then
        iconFrame.warningIcon:Show()
    else
        iconFrame.warningIcon:Hide()
    end
end

local function LayoutIcon(iconPoint, iconFrame, itemData)

    local frame = ns.equipmentFrame

    local iconWidth = ns:GetLayoutConfig("icon.width")
    local iconHeight = ns:GetLayoutConfig("icon.height")

    iconFrame:ClearAllPoints()
    iconFrame:SetPoint(iconPoint.point, frame, iconPoint.point, iconPoint.xOffset, iconPoint.yOffset)

    iconFrame:SetSize(iconWidth, iconHeight)
    iconFrame.texture:SetTexture(itemData.texture)
    iconFrame.texture:SetDesaturated(itemData.repairable == false)

    iconFrame.current = itemData.current
    iconFrame.maximum = itemData.maximum
    iconFrame.ratio = itemData.ratio
    iconFrame.repairable = itemData.repairable

    LayoutIconText(iconFrame, itemData)

    if dynamicMacroSlots[iconFrame.slotId] then
        SetWeaponSlotMacro(iconFrame, iconFrame.slotId, itemData)
    end

    LayoutWarningIcon(iconFrame, itemData)

    iconFrame:Show()
end

local function ResetIcon(iconFrame)
    local frame = ns.equipmentFrame

    iconFrame:ClearAllPoints()
    iconFrame:SetPoint(ns.enums.Blizz.FramePoint.Left, frame, ns.enums.Blizz.FramePoint.Left, 0, 0)

    iconFrame.texture:SetTexture(nil)
    iconFrame.text:SetText("")
    iconFrame.warningIcon:Hide()

    iconFrame.current = nil
    iconFrame.maximum = nil
    iconFrame.ratio = nil
    iconFrame.repairable = nil

    iconFrame:Hide()
end

local function LayoutFrame(iconsAmount)
    local frame = ns.equipmentFrame

    if iconsAmount < 1 then
        frame:SetSize(0, 0)
        frame:Hide()
        return
    end

    local iconWidth = ns:GetLayoutConfig("icon.width")
    local iconHeight = ns:GetLayoutConfig("icon.height")
    local padding = ns:GetLayoutConfig("frame.padding")
    local orientation = ns:GetLayoutConfig("icon.orientation")

    local xSize = iconWidth
    local ySize = iconHeight

    if
        orientation == ns.enums.Orientation.VerticalCenter
        or orientation == ns.enums.Orientation.VerticalTopToBottom
        or orientation == ns.enums.Orientation.VerticalBottomToTop
    then
        ySize = (iconHeight * iconsAmount) + (padding * (iconsAmount - 1))
    else
        xSize = (iconWidth * iconsAmount) + (padding * (iconsAmount - 1))
    end

    frame:SetSize(xSize, ySize)
    ns:ApplyCurrentLayoutFramePosition(frame)
    frame:Show()
end

local function GetItems()
    if ns.isPreviewMode then
        ns:Debug("GetItems: getting dummy items")
        return GetDummyItems()
    end

    return GetLowDurabilityItems()
end

local function CalculateIconPoints(total)
    local points = {}

    if total == 0 then
        return points
    end

    local iconWidth  = ns:GetLayoutConfig("icon.width")
    local iconHeight = ns:GetLayoutConfig("icon.height")
    local padding    = ns:GetLayoutConfig("frame.padding")
    local orientation = ns:GetLayoutConfig("icon.orientation")

    local stepX = iconWidth  + padding
    local stepY = iconHeight + padding

    for i = 1, total do
        local idx = i - 1
        local point, xOffset, yOffset

        if orientation == ns.enums.Orientation.HorizontalLeftToRight
        or orientation == ns.enums.Orientation.HorizontalCenter then
            point   = ns.enums.Blizz.FramePoint.Left
            xOffset = idx * stepX
            yOffset = 0

        elseif orientation == ns.enums.Orientation.HorizontalRightToLeft then
            point   = ns.enums.Blizz.FramePoint.Left
            xOffset = (total - 1 - idx) * stepX
            yOffset = 0

        elseif orientation == ns.enums.Orientation.VerticalTopToBottom
        or orientation == ns.enums.Orientation.VerticalCenter then
            point   = ns.enums.Blizz.FramePoint.Top
            xOffset = 0
            yOffset = -idx * stepY

        elseif orientation == ns.enums.Orientation.VerticalBottomToTop then
            point   = ns.enums.Blizz.FramePoint.Top
            xOffset = 0
            yOffset = -(total - 1 - idx) * stepY
        end

        points[i] = { point = point, xOffset = xOffset, yOffset = yOffset }
    end

    return points
end

function ns:RefreshFrame()
    ns:Debug("ns:RefreshFrame - start")

    if not self.equipmentFrame then
        return
    end

    if InCombatLockdown() then
        ns:Debug("ns:RefreshFrame - in combat, deferring")
        self.pendingRefresh = true
        return
    end

    local items = GetItems()
    local frame = self.equipmentFrame

    local visibleIcons = {}
    for _, iconFrame in ipairs(frame.icons) do
        local itemData = items[iconFrame.slotId]

        if itemData then
            visibleIcons[#visibleIcons + 1] = { iconFrame = iconFrame, itemData = itemData }
        else
            ResetIcon(iconFrame)
        end
    end

    ns:Debug("ns:RefreshFrame - visibleIcons count:", #visibleIcons)

    local iconPoints = CalculateIconPoints(#visibleIcons)

    for i, entry in ipairs(visibleIcons) do
        LayoutIcon(iconPoints[i], entry.iconFrame, entry.itemData)
    end

    LayoutFrame(#visibleIcons)

    ns:Debug("ns:RefreshFrame - end")
end

-- Called on PLAYER_REGEN_DISABLED, not through RefreshFrame: the icons are
-- SecureActionButtonTemplate and RefreshFrame's own InCombatLockdown() guard would
-- just bail out immediately anyway. Hiding the (non-secure) parent frame directly is
-- unrestricted in combat. PLAYER_REGEN_ENABLED already re-runs RefreshFrame once
-- combat ends (via pendingRefresh), which re-shows the frame if there's still damaged
-- gear -- so this only needs to hide, never show.
function ns:HideFrameForCombat()
    if not self.equipmentFrame then
        return
    end

    if self.isPreviewMode then
        return -- Edit Mode preview always shows, regardless of this setting
    end

    if not self:GetLayoutConfig("hideInCombat") then
        return
    end

    ns:Debug("ns:HideFrameForCombat - hiding for combat")
    self.equipmentFrame:Hide()
    self.pendingRefresh = true
end