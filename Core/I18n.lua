local _, ns = ...

-- currentLocaleTable is an upvalue shared between the ns.L proxy and
-- applyLocale(). Reassigning it here is visible to the __index closure,
-- so any existing "local L = ns.L" references update automatically.
local currentLocaleTable = {}

ns.L = setmetatable({}, {
    __index = function(_, key)
        return currentLocaleTable[key]
    end
})

local function applyLocale(localeName)
    local target   = ns.Locales[localeName]
    local fallback = ns.Locales["enUS"] or {}

    if target and target ~= fallback then
        currentLocaleTable = setmetatable(target, { __index = fallback })
    else
        currentLocaleTable = fallback
    end
end

-- Apply immediately using the client locale.
applyLocale(GetLocale())

-- Called after config is loaded to optionally override the locale for debugging.
function ns:ApplyDebugLocale()
    if self.config
        and self.config.debugEnabled
        and self.config.debugLocale
    then
        applyLocale(self.config.debugLocale)
    end
end
