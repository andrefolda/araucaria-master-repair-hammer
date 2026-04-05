local addonName, ns = ...

ns.name = addonName

ns.isPreviewMode = false

-- =========================================
-- Constants
-- =========================================

ns.const = {
    Items = {
        ThalassianMasterRepairHammerId = 238020,
    },

    UI = {
        EditModeFrameName = ns.L.ADDON_NAME,
        InitFrame = "ARAU_MRH_TOOL_INIT_FRAME",
        MainFrameName = "ARAU_MRH_TOOL_FRAME",
        SlotFrameName = {
            [1] = "ARAU_MRH_TOOL_HEAD_ICON_FRAME",
            [3] = "ARAU_MRH_TOOL_SHOULDER_ICON_FRAME",
            [5] = "ARAU_MRH_TOOL_CHEST_ICON_FRAME",
            [6] = "ARAU_MRH_TOOL_WAIST_ICON_FRAME",
            [7] = "ARAU_MRH_TOOL_LEGS_ICON_FRAME",
            [8] = "ARAU_MRH_TOOL_FEET_ICON_FRAME",
            [9] = "ARAU_MRH_TOOL_WRIST_ICON_FRAME",
            [10] = "ARAU_MRH_TOOL_HANDS_ICON_FRAME",
            [16] = "ARAU_MRH_TOOL_MAIN_HAND_ICON_FRAME",
            [17] = "ARAU_MRH_TOOL_OFF_HAND_ICON_FRAME",
        },
        IconTextureName = {
            [1] = "ARAU_MRH_TOOL_HEAD_ICON_TEXTURE",
            [3] = "ARAU_MRH_TOOL_SHOULDER_ICON_TEXTURE",
            [5] = "ARAU_MRH_TOOL_CHEST_ICON_TEXTURE",
            [6] = "ARAU_MRH_TOOL_WAIST_ICON_TEXTURE",
            [7] = "ARAU_MRH_TOOL_LEGS_ICON_TEXTURE",
            [8] = "ARAU_MRH_TOOL_FEET_ICON_TEXTURE",
            [9] = "ARAU_MRH_TOOL_WRIST_ICON_TEXTURE",
            [10] = "ARAU_MRH_TOOL_HANDS_ICON_TEXTURE",
            [16] = "ARAU_MRH_TOOL_MAINHAND_ICON_TEXTURE",
            [17] = "ARAU_MRH_TOOL_OFFHAND_ICON_TEXTURE",
        },
        DurabilityStringName = {
            [1] = "ARAU_MRH_TOOL_HEAD_DURABILITY_STRING",
            [3] = "ARAU_MRH_TOOL_SHOULDER_DURABILITY_STRING",
            [5] = "ARAU_MRH_TOOL_CHEST_DURABILITY_STRING",
            [6] = "ARAU_MRH_TOOL_WAIST_DURABILITY_STRING",
            [7] = "ARAU_MRH_TOOL_LEGS_DURABILITY_STRING",
            [8] = "ARAU_MRH_TOOL_FEET_DURABILITY_STRING",
            [9] = "ARAU_MRH_TOOL_WRIST_DURABILITY_STRING",
            [10] = "ARAU_MRH_TOOL_HANDS_DURABILITY_STRING",
            [16] = "ARAU_MRH_TOOL_MAINHAND_DURABILITY_STRING",
            [17] = "ARAU_MRH_TOOL_OFFHAND_DURABILITY_STRING",
        },
    },

    Equipment = {
        WatchedSlots = {
            1,   -- Head
            3,   -- Shoulder
            5,   -- Chest
            6,   -- Waist
            7,   -- Legs
            8,   -- Feet
            9,   -- Wrist
            10,  -- Hands
            16,  -- MainHand
            17,  -- OffHand
        }
    },

    Profession = {
        BlacksmithSkillLineId = 164
    }
}

-- =========================================
-- Defaults
-- =========================================

ns.defaults = {

    durabilityThreshold = 0.6,
    lowDurabilityThreshold = 0.4,
    criticalDurabilityThreshold = 0.2,

    frame = {
        point = ns.enums.Blizz.FramePoint.Center,
        relativePoint = ns.enums.Blizz.FramePoint.Center,
        x = 0,
        y = 200,
        padding = 1,
    },

    icon = {
        width = 40,
        height = 40,
        orientation = ns.enums.Orientation.HorizontalCenter,
        durabilityText = {
            font = STANDARD_TEXT_FONT,
            size = 12,
            outline = ns.enums.Blizz.TBFFlags.Outline,
            position = {
                point = ns.enums.Blizz.FramePoint.Bottom,
                relative = ns.enums.Blizz.FramePoint.Bottom,
                xOffset = 0,
                yOffset = 2,
            },
            color = {
                default = {1, 1, 1, 1},
                lowDurability = {1, 1, 0, 1},
                criticalDurability = {1, 0, 0, 1}
            }
        },
    },
}
