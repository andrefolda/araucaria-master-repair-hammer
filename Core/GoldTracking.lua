local addonName, ns = ...

local L = ns.L

ns.pendingGoldSaved = {}

local function PrintMessage(text)
    print(("|cff00ff00[%s]|r %s"):format(addonName, text))
end

local function TodayKey()
    return date("%Y%m%d")
end

-- =========================================
-- Detecting a successful repair
-- =========================================

local function OnRepairIconClick(iconFrame)
    local slotId = iconFrame.slotId

    if not slotId or not iconFrame.repairable then
        -- Not eligible for MRH repair (per the last refresh) -- don't track it as
        -- pending, or a later, unrelated durability increase (ex. a paid vendor
        -- repair) could get wrongly credited as hammer savings.
        return
    end

    local data = C_TooltipInfo.GetInventoryItem(ns.enums.Blizz.Unit.Player, slotId)
    local repairCost = data and data.repairCost

    if not repairCost or repairCost <= 0 then
        return
    end

    ns.pendingGoldSaved[slotId] = {
        repairCost = repairCost,
        previousCurrent = iconFrame.current,
    }
end

function ns:HookGoldTrackingForIcon(iconFrame)
    iconFrame:HookScript(ns.enums.Blizz.ScriptTypeName.Button.OnClick, OnRepairIconClick)
end

local function AddGoldSaved(amount)
    local dailyPath = "goldSaved.daily." .. TodayKey()

    local charTotal = (ns:GetCharConfig("goldSaved.total") or 0) + amount
    ns:SetCharConfig("goldSaved.total", charTotal)

    local charDaily = (ns:GetCharConfig(dailyPath) or 0) + amount
    ns:SetCharConfig(dailyPath, charDaily)

    local accountTotal = (ns:GetConfig("goldSaved.total") or 0) + amount
    ns:SetConfig("goldSaved.total", accountTotal)

    local accountDaily = (ns:GetConfig(dailyPath) or 0) + amount
    ns:SetConfig(dailyPath, accountDaily)

    return charTotal, charDaily
end

local function AddRepairCount()
    local dailyPath = "repairCount.daily." .. TodayKey()

    local charTotal = (ns:GetCharConfig("repairCount.total") or 0) + 1
    ns:SetCharConfig("repairCount.total", charTotal)

    local charDaily = (ns:GetCharConfig(dailyPath) or 0) + 1
    ns:SetCharConfig(dailyPath, charDaily)

    local accountTotal = (ns:GetConfig("repairCount.total") or 0) + 1
    ns:SetConfig("repairCount.total", accountTotal)

    local accountDaily = (ns:GetConfig(dailyPath) or 0) + 1
    ns:SetConfig(dailyPath, accountDaily)

    return charTotal, charDaily
end

function ns:ProcessPendingGoldSaved()
    for slotId, pending in pairs(self.pendingGoldSaved) do
        self.pendingGoldSaved[slotId] = nil -- one-shot: always clear, matched or not

        local current = GetInventoryItemDurability(slotId)

        if current and pending.previousCurrent and current > pending.previousCurrent then
            local charTotal, charDaily = AddGoldSaved(pending.repairCost)
            AddRepairCount()

            PrintMessage(L.GOLD_SAVED_THIS_REPAIR:format(
                GetMoneyString(pending.repairCost, true),
                GetMoneyString(charDaily, true),
                GetMoneyString(charTotal, true)
            ))
        end
    end
end

-- =========================================
-- Reset via slash command
-- =========================================

local function ArchiveAndReset(getFn, setFn, self, valuePath, historyPath)
    local value = getFn(self, valuePath) or 0
    local history = getFn(self, historyPath) or {}

    history[time()] = value

    setFn(self, historyPath, history)
    setFn(self, valuePath, 0)

    return value
end

local function GetScopeFns(scope)
    if scope == "char" then
        return ns.GetCharConfig, ns.SetCharConfig
    elseif scope == "account" then
        return ns.GetConfig, ns.SetConfig
    end

    return nil, nil
end

local function ResetGoldCounter(scope)
    local getFn, setFn = GetScopeFns(scope)

    if not getFn then
        return
    end

    local goldTotal = ArchiveAndReset(getFn, setFn, ns, "goldSaved.total", "goldSaved.history")
    local repairTotal = ArchiveAndReset(getFn, setFn, ns, "repairCount.total", "repairCount.history")

    if scope == "char" then
        PrintMessage(L.GOLD_RESET_CHAR_CONFIRM:format(GetMoneyString(goldTotal, true), repairTotal))
    else
        PrintMessage(L.GOLD_RESET_ACCOUNT_CONFIRM:format(GetMoneyString(goldTotal, true), repairTotal))
    end
end

local function ResetTodayGoldCounter(scope)
    local getFn, setFn = GetScopeFns(scope)

    if not getFn then
        return
    end

    local todayKey = TodayKey()
    local goldAmount = ArchiveAndReset(getFn, setFn, ns, "goldSaved.daily." .. todayKey, "goldSaved.dailyHistory")
    local repairAmount = ArchiveAndReset(getFn, setFn, ns, "repairCount.daily." .. todayKey, "repairCount.dailyHistory")

    if scope == "char" then
        PrintMessage(L.GOLD_RESET_TODAY_CHAR_CONFIRM:format(GetMoneyString(goldAmount, true), repairAmount))
    else
        PrintMessage(L.GOLD_RESET_TODAY_ACCOUNT_CONFIRM:format(GetMoneyString(goldAmount, true), repairAmount))
    end
end

-- =========================================
-- Summary (bare /amrh)
-- =========================================

local function PrintSummary()
    local dailyPath = "goldSaved.daily." .. TodayKey()
    local dailyCountPath = "repairCount.daily." .. TodayKey()

    local dailyGold = ns:GetCharConfig(dailyPath) or 0
    local dailyCount = ns:GetCharConfig(dailyCountPath) or 0
    local totalGold = ns:GetCharConfig("goldSaved.total") or 0
    local totalCount = ns:GetCharConfig("repairCount.total") or 0

    PrintMessage(L.GOLD_SUMMARY_TODAY:format(GetMoneyString(dailyGold, true), dailyCount))
    PrintMessage(L.GOLD_SUMMARY_TOTAL:format(GetMoneyString(totalGold, true), totalCount))
end

SLASH_ARAUMRHTOOL1 = "/amrh"
SlashCmdList.ARAUMRHTOOL = function(msg)
    local action, scope = (msg or ""):match("^(%S*)%s*(%S*)$")
    action = action and action:lower()
    scope = scope and scope:lower()

    if action == "" then
        PrintSummary()
        return
    end

    if scope ~= "char" and scope ~= "account" then
        PrintMessage(L.GOLD_RESET_USAGE)
        return
    end

    if action == "reset" then
        ResetGoldCounter(scope)
    elseif action == "resettoday" then
        ResetTodayGoldCounter(scope)
    else
        PrintMessage(L.GOLD_RESET_USAGE)
    end
end
