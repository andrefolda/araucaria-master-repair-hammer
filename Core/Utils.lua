local addonName, ns = ...

function ns:EnableEditModePreview()
    self.isPreviewMode = true
    self:RefreshFrame()
end

function ns:DisableEditModePreview()
    self.isPreviewMode = false
    self:RefreshFrame()
end

-- =========================================
-- Debug
-- =========================================

function ns:Debug(...)
    if not self.config or not self.config.debugEnabled then
        return
    end

    print("|cff00ff00[" .. addonName .. "]|r", ...)
end

function ns:DebugTable(msg, table)
    if not self.config or not self.config.debugEnabled then
        return
    end

    if msg then
        print("|cff00ff00[" .. addonName .. "]|r", msg)
    end

    for key, value in pairs(table) do
        print(key, value)
    end
end

function ns:DebugTable2(msg, tbl, depth)
    if not self.config or not self.config.debugEnabled then
        return
    end

    depth = depth or 0
    local indent = string.rep("  ", depth)

    if msg then
        print("|cff00ff00[" .. addonName .. "]|r", indent .. msg)
    end

    for key, value in pairs(tbl) do
        if type(value) == "table" then
            self:DebugTable2(tostring(key), value, depth + 1)
        else
            print(indent .. "  " .. tostring(key), value)
        end
    end
end

-- =========================================
-- Professions
-- =========================================

function ns:HasBlacksmithing()
    local prof1, prof2 = GetProfessions()

    local professionIndices = { prof1, prof2 }

    for _, professionIndex in ipairs(professionIndices) do
        if professionIndex then
            local _, _, _, _, _, _, skillLine = GetProfessionInfo(professionIndex)

            if skillLine == ns.const.Profession.BlacksmithSkillLineId then
                return true
            end
        end
    end

    return false
end
