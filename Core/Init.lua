local addonName, ns = ...

local function RegisterBlacksmithListeners(frame)
    frame:RegisterEvent(ns.enums.Blizz.Events.PaperDollInfo.PlayerEquipmentChanged)
    frame:RegisterEvent(ns.enums.Blizz.Events.PaperDollInfo.UpdateInventoryDurability)
    frame:RegisterEvent(ns.enums.Blizz.Events.SystemInfo.PlayerRegenEnabled)
    ns:Debug("Equipment/durability listeners registered")
end

local function OnAddonLoaded(_, _, loadedAddonName)

    if loadedAddonName ~= addonName then
        return
    end

    ns:InitializeConfig()
    ns:ApplyDebugLocale()
    ns:Debug("Config loaded")
end

local function OnPlayerLogin(frame)
    ns:Debug("PLAYER_LOGIN fired")

    ns.hasBlacksmithing = ns:HasBlacksmithing()

    if ns.hasBlacksmithing then
        ns:Debug("Blacksmithing detected")

        ns:CreateAddonFrame()
        ns:RegisterFrameWithEditMode(ns.equipmentFrame)
        ns:RefreshFrame()

        RegisterBlacksmithListeners(frame)
    else
        ns:Debug("Blacksmithing not detected")
    end
end

local function OnTrackedEquipmentChanged(_, _, ...)
    ns:Debug("PLAYER_EQUIPMENT_CHANGED fired", ...)
    ns:RefreshFrame()
end

local function OnTrackedDurabilityUpdate()
    ns:Debug("UPDATE_INVENTORY_DURABILITY fired")
    ns:RefreshFrame()
end

local function OnPlayerRegenEnabled()
    ns:Debug("PLAYER_REGEN_ENABLED fired")
    if ns.pendingRefresh then
        ns.pendingRefresh = false
        ns:RefreshFrame()
    end
end

local frame = CreateFrame(ns.enums.Blizz.FrameType.Frame, ns.const.UI.InitFrame)
frame:RegisterEvent(ns.enums.Blizz.Events.AddOns.AddonLoaded)
frame:RegisterEvent(ns.enums.Blizz.Events.SystemInfo.PlayerLogin)

frame:SetScript(ns.enums.Blizz.ScriptTypeName.Frame.OnEvent, function(self, event, ...)
    if event == ns.enums.Blizz.Events.AddOns.AddonLoaded then
        OnAddonLoaded(self, event, ...)
    elseif event == ns.enums.Blizz.Events.SystemInfo.PlayerLogin then
        OnPlayerLogin(self)
    elseif event == ns.enums.Blizz.Events.PaperDollInfo.PlayerEquipmentChanged then
        OnTrackedEquipmentChanged(self, event, ...)
    elseif event == ns.enums.Blizz.Events.PaperDollInfo.UpdateInventoryDurability then
        OnTrackedDurabilityUpdate()
    elseif event == ns.enums.Blizz.Events.SystemInfo.PlayerRegenEnabled then
        OnPlayerRegenEnabled()
    end
end)

ns:RegisterEditModeCallbacks()
