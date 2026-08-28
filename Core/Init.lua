local addonName, ns = ...

local function RegisterBlacksmithListeners(frame)
    frame:RegisterEvent(ns.enums.Blizz.Events.PaperDollInfo.PlayerEquipmentChanged)
    frame:RegisterEvent(ns.enums.Blizz.Events.PaperDollInfo.UpdateInventoryDurability)
    frame:RegisterEvent(ns.enums.Blizz.Events.SystemInfo.PlayerRegenEnabled)
    ns:Debug("Equipment/durability listeners registered")
end

-- On a fresh login (not /reload), GetInventoryItemDurability can return nil for
-- everything for a little while -- the client hasn't synced it from the server yet,
-- and no event reliably signals when it has (confirmed: neither PLAYER_ENTERING_WORLD
-- nor UPDATE_INVENTORY_DURABILITY fire in time for this -- the latter only fires on a
-- *change*). Keep retrying every few seconds until it's confirmed synced, instead of
-- guessing a fixed delay that might not be enough on a slow connection/PC.
local durabilitySyncAttempts = 0
local maxDurabilitySyncAttempts = 8 -- ~24s worst case (3s apart)

local function IsDurabilitySynced()
    for _, slotId in ipairs(ns.const.Equipment.WatchedSlots) do
        if GetInventoryItemDurability(slotId) ~= nil then
            return true
        end
    end

    return false
end

local function RetryRefreshUntilDurabilitySynced()
    durabilitySyncAttempts = durabilitySyncAttempts + 1
    ns:RefreshFrame()

    if not IsDurabilitySynced() and durabilitySyncAttempts < maxDurabilitySyncAttempts then
        ns:Debug("Durability not synced yet, retrying (" .. durabilitySyncAttempts .. ")")
        C_Timer.After(3, RetryRefreshUntilDurabilitySynced)
    end
end

local function OnAddonLoaded(_, _, loadedAddonName)

    if loadedAddonName ~= addonName then
        return
    end

    ns:InitializeConfig()
    ns:InitializeCharConfig()
    ns:ApplyDebugLocale()
    ns:Debug("Config loaded")
end

local function OnPlayerLogin(frame)
    ns:Debug("PLAYER_LOGIN fired")

    ns.hasBlacksmithing = ns:HasBlacksmithing()

    if ns.hasBlacksmithing then
        ns:Debug("Blacksmithing detected")

        ns:BuildRepairEligibilityCache()
        ns:BuildRepairPlan()

        ns:EnsureLayoutDefaults()
        ns:CreateAddonFrame()
        ns:RegisterFrameWithEditMode(ns.equipmentFrame)
        ns:RefreshFrame()

        RegisterBlacksmithListeners(frame)

        durabilitySyncAttempts = 0
        C_Timer.After(2, RetryRefreshUntilDurabilitySynced)
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
    ns:ProcessPendingGoldSaved()
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
