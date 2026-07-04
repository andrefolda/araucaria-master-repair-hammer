local _, ns = ...

ns.Locales = ns.Locales or {}
ns.Locales["enUS"] = {
    ADDON_NAME                    = "Araucaria Master Repair Hammer",

    DURABILITY_THRESHOLD_SETTINGS = "Durability Threshold Settings",
    SHOW_DURABILITY               = "Show Durability",
    LOW_DURABILITY                = "Low Durability",
    CRITICAL_DURABILITY           = "Critical Durability",

    ICON_SETTINGS                 = "Icon Settings",
    ORIENTATION                   = "Orientation",
    ICON_SIZE                     = "Icon Size",
    ORIENTATION_HORIZONTAL_CENTER = "Horizontal - Centered",
    ORIENTATION_HORIZONTAL_LTR    = "Horizontal - Left to Right",
    ORIENTATION_HORIZONTAL_RTL    = "Horizontal - Right to Left",
    ORIENTATION_VERTICAL_CENTER   = "Vertical - Centered",
    ORIENTATION_VERTICAL_TTB      = "Vertical - Top to Bottom",
    ORIENTATION_VERTICAL_BTT      = "Vertical - Bottom to Top",

    DURABILITY_TEXT_SETTINGS      = "Durability Text Settings",
    SIZE                          = "Size",
    FONT                          = "Font",
    X_OFFSET                      = "X Offset",
    Y_OFFSET                      = "Y Offset",

    SHOW_ONLY_REPAIRABLE          = "Show Only Repairable",
    SHOW_ONLY_REPAIRABLE_TOOLTIP  = "Only show equipment slots your Master Repair Hammer can currently repair. If you just mastered a new specialization, reload your UI (/reload) for this to update.",
    CANNOT_REPAIR_TOOLTIP         = "Your Master Repair Hammer cannot repair this item yet.",
    WARNING_ICON_SETTINGS         = "Warning Icon Settings",

    TODAY_SAVED                   = "Today's Saved",
    TOTAL_SAVED                   = "Total Saved",
    GOLD_SAVED_THIS_REPAIR        = "You saved %s on this repair! Today: %s -- Total: %s",
    GOLD_RESET_CHAR_CONFIRM       = "Character gold counter reset. Previous total archived: %s across %d repairs.",
    GOLD_RESET_ACCOUNT_CONFIRM    = "Account gold counter reset. Previous total archived: %s across %d repairs.",
    GOLD_RESET_TODAY_CHAR_CONFIRM    = "Today's character gold counter reset. Previous amount archived: %s across %d repairs.",
    GOLD_RESET_TODAY_ACCOUNT_CONFIRM = "Today's account gold counter reset. Previous amount archived: %s across %d repairs.",
    GOLD_RESET_USAGE              = "Usage: /amrh reset char|account or /amrh resettoday char|account",
    GOLD_SUMMARY_TODAY            = "Today: %s saved across %d repairs.",
    GOLD_SUMMARY_TOTAL            = "All time: %s saved across %d repairs.",
}
