local _, ns = ...

local Item = ns.enums.Blizz.Item

-- =========================================
-- Repair Tracks (per-expansion Master Repair Hammers)
-- =========================================
--
-- Ordered newest-first: ns:BuildRepairPlan() relies on this order to pick the
-- best (highest maxItemLevelReq) mastered track for each slot/weapon bucket.
ns.const.RepairTracks = {
    {
        key = "midnight",
        maxItemLevelReq = 90,
        hammerItemId = 238020, -- Thalassian Master Repair Hammer
        specSkillLineId = 2907, -- Midnight Blacksmithing
        requiredPerkBySlot = {
            [1] = 104519,  -- Head
            [3] = 104513,  -- Shoulder
            [5] = 104544,  -- Chest
            [6] = 104494,  -- Waist
            [7] = 104538,  -- Legs
            [8] = 104507,  -- Feet
            [9] = 104488,  -- Wrist
            [10] = 104482, -- Hands
            [17] = 104532, -- OffHand (shield)
        },
        requiredPerkByWeaponBucket = {
            longBlades = 104601,
            shortBlades = 104607,
            maces = 104589,
            axesPolearms = 104583,
        },
    },
    {
        key = "khazAlgar", -- The War Within
        maxItemLevelReq = 80,
        hammerItemId = 225660, -- Earthen Master's Hammer
        specSkillLineId = 2872, -- Khaz Algar Blacksmithing
        requiredPerkBySlot = {
            [1] = 99182,  -- Head
            [3] = 99176,  -- Shoulder
            [5] = 99207,  -- Chest
            [6] = 99157,  -- Waist
            [7] = 99201,  -- Legs
            [8] = 99170,  -- Feet
            [9] = 99151,  -- Wrist
            [10] = 99145, -- Hands
            [17] = 99195, -- OffHand (shield)
        },
        requiredPerkByWeaponBucket = {
            longBlades = 99422,
            shortBlades = 99428,
            maces = 99410,
            axesPolearms = 99404,
        },
    },
    {
        key = "dragonIsles",
        maxItemLevelReq = 70,
        hammerItemId = 201366, -- Master's Hammer
        specSkillLineId = 2822, -- Dragon Isles Blacksmithing
        requiredPerkBySlot = {
            [1] = 23851,  -- Head
            [3] = 23844,  -- Shoulder
            [5] = 23879,  -- Chest
            [6] = 23823,  -- Waist
            [7] = 23872,  -- Legs
            [8] = 23837,  -- Feet
            [9] = 23816,  -- Wrist
            [10] = 23809, -- Hands
            [17] = 23865, -- OffHand (shield)
        },
        requiredPerkByWeaponBucket = {
            longBlades = 23693,
            shortBlades = 23700,
            maces = 23679,
            axesPolearms = 23672,
        },
    },
}

-- =========================================
-- Weapon subclass -> bucket
-- =========================================

local weaponSubclassToBucket = {
    [Item.WeaponSubclassID.Sword1H] = "longBlades",
    [Item.WeaponSubclassID.Sword2H] = "longBlades",
    [Item.WeaponSubclassID.Warglaive] = "longBlades",
    [Item.WeaponSubclassID.Dagger] = "shortBlades",
    [Item.WeaponSubclassID.FistWeapon] = "shortBlades",
    [Item.WeaponSubclassID.Mace1H] = "maces",
    [Item.WeaponSubclassID.Mace2H] = "maces",
    [Item.WeaponSubclassID.Axe1H] = "axesPolearms",
    [Item.WeaponSubclassID.Axe2H] = "axesPolearms",
    [Item.WeaponSubclassID.Polearm] = "axesPolearms",
}

function ns:GetWeaponBucket(subclassID)
    return weaponSubclassToBucket[subclassID]
end

-- =========================================
-- Eligibility cache + repair plan (built once at login)
-- =========================================

function ns:BuildRepairEligibilityCache()
    self.repairEligibility = {}

    for _, track in ipairs(self.const.RepairTracks) do
        local configID = C_ProfSpecs.GetConfigIDForSkillLine(track.specSkillLineId)
        local eligibility = { bySlot = {}, byWeaponBucket = {} }

        if configID and configID > 0 then
            for slotId, perkId in pairs(track.requiredPerkBySlot) do
                eligibility.bySlot[slotId] = C_ProfSpecs.GetStateForPerk(perkId, configID) == 2
            end

            for bucket, perkId in pairs(track.requiredPerkByWeaponBucket) do
                eligibility.byWeaponBucket[bucket] = C_ProfSpecs.GetStateForPerk(perkId, configID) == 2
            end
        end

        self.repairEligibility[track.key] = eligibility

        self:Debug("Repair eligibility built for track", track.key, "configID:", configID)
    end
end

function ns:BuildRepairPlan()
    local plan = { bySlot = {}, byWeaponBucket = {} }

    for _, track in ipairs(self.const.RepairTracks) do
        local eligibility = self.repairEligibility[track.key]

        for slotId in pairs(track.requiredPerkBySlot) do
            if not plan.bySlot[slotId] and eligibility.bySlot[slotId] then
                plan.bySlot[slotId] = { maxItemLevelReq = track.maxItemLevelReq, hammerItemId = track.hammerItemId }
            end
        end

        for bucket in pairs(track.requiredPerkByWeaponBucket) do
            if not plan.byWeaponBucket[bucket] and eligibility.byWeaponBucket[bucket] then
                plan.byWeaponBucket[bucket] = { maxItemLevelReq = track.maxItemLevelReq, hammerItemId = track.hammerItemId }
            end
        end
    end

    self.repairPlan = plan

    self:DebugTable2("Repair plan built", plan)
end

-- =========================================
-- Eligibility queries
-- =========================================

function ns:GetRepairPlanEntry(slotId, classID, subclassID)
    if not self.repairPlan then
        return nil
    end

    if classID == Item.ClassID.Armor then
        if subclassID == Item.ArmorSubclassID.Plate then
            return self.repairPlan.bySlot[slotId]
        elseif subclassID == Item.ArmorSubclassID.Shield then
            return self.repairPlan.bySlot[17] -- shields only ever occupy OffHand
        end

        return nil
    end

    if classID == Item.ClassID.Weapon then
        local bucket = self:GetWeaponBucket(subclassID)
        return bucket and self.repairPlan.byWeaponBucket[bucket] or nil
    end

    return nil
end

function ns:CanRepairSlot(slotId, itemLevelReq, classID, subclassID)
    local plan = self:GetRepairPlanEntry(slotId, classID, subclassID)

    return plan ~= nil and itemLevelReq ~= nil and itemLevelReq <= plan.maxItemLevelReq
end
