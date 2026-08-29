local addonName, ns = ...

local function RegisterBlacksmithListeners(frame)
    frame:RegisterEvent(ns.enums.Blizz.Events.PaperDollInfo.PlayerEquipmentChanged)
    frame:RegisterEvent(ns.enums.Blizz.Events.PaperDollInfo.UpdateInventoryDurability)
    frame:RegisterEvent(ns.enums.Blizz.Events.SystemInfo.PlayerRegenEnabled)
    frame:RegisterEvent(ns.enums.Blizz.Events.SystemInfo.PlayerEnteringWorld)
    ns:Debug("Equipment/durability listeners registered")
end

-- On a fresh login (not /reload), GetInventoryItemDurability can return nil for
-- everything for a little while -- the client hasn't synced it from the server yet,
-- and no event reliably signals when it has (confirmed: PLAYER_ENTERING_WORLD fires
-- too early, and UPDATE_INVENTORY_DURABILITY only fires on a *change*). Keep retrying
-- every few seconds until it's confirmed synced, instead of guessing a fixed delay
-- that might not be enough on a slow connection/PC.
local durabilitySyncAttempts = 0
local durabilitySyncRunning = false
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
        return
    end

    durabilitySyncRunning = false
end

-- Runs after a loading screen too, not just at login: zoning puts the client back in
-- the same "durability not synced yet" state, and login and zoning overlap (both fire
-- on a fresh login), so only one retry chain is allowed at a time.
local function StartDurabilitySyncRetry()
    if durabilitySyncRunning then
        return
    end

    durabilitySyncRunning = true
    durabilitySyncAttempts = 0
    C_Timer.After(2, RetryRefreshUntilDurabilitySynced)
end

-- Durability events only fire on a *change*, and gear only wears down in combat, so
-- nothing brings the frame back for gear that was already below the threshold before
-- a loading screen. Poll for it.
local function StartRefreshTicker()
    if ns.refreshTicker then
        return
    end

    ns.refreshTicker = C_Timer.NewTicker(ns.const.RefreshIntervalSeconds, function()
        if ns.isPreviewMode then
            return -- Edit Mode is driving the frame, don't fight it
        end

        ns:RefreshFrame()
    end)
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
        StartRefreshTicker()
        StartDurabilitySyncRetry()
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

local function OnPlayerEnteringWorld()
    ns:Debug("PLAYER_ENTERING_WORLD fired")
    ns:RefreshFrame()
    StartDurabilitySyncRetry()
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
    elseif event == ns.enums.Blizz.Events.SystemInfo.PlayerEnteringWorld then
        OnPlayerEnteringWorld()
    end
end)

ns:RegisterEditModeCallbacks()
