# ArauMRHTool — Development Guidelines

## Overview

World of Warcraft addon (Interface 120007) that monitors equipment durability and facilitates repair via a **Master Repair Hammer**. Only activates for characters with the Blacksmithing profession.

There are 3 hammers, one per expansion (Dragon Isles, Khaz Algar/The War Within,
Midnight), each gated by its own Blacksmithing specialization tree and covering item
req. levels up to its own ceiling. The addon resolves which hammer/track applies per
slot — see [Repair Eligibility & Multi-Expansion Hammers](#repair-eligibility--multi-expansion-hammers).

It also tracks how much gold repairing with the hammer has saved compared to paying
an NPC — see [Gold Savings Tracking](#gold-savings-tracking).

---

## File Load Order

Defined in `ArauMRHTool.toc`. Order matters — modules depend on earlier ones:

```
Libs/LibStub/LibStub.lua
Libs/LibEQOL/LibEQOL.xml
Libs/LibSharedMedia-3.0/...

Locales/enUS.lua       ← populates ns.Locales["enUS"]
Locales/ptBR.lua       ← populates ns.Locales["ptBR"]
Core/Enum.lua          ← ns.enums defined here
Core/I18n.lua          ← reads GetLocale(), builds ns.L from ns.Locales
ArauMRHTool.lua        ← ns.const and ns.defaults (uses ns.L)
Core/RepairTracks.lua  ← per-expansion hammer/track data + repair eligibility logic (needs ns.const)
Core/Config.lua        ← config API
Core/Utils.lua         ← debug helpers, profession check
Core/EditMode.lua      ← LibEQOL integration, position + settings (uses local L = ns.L)
Core/EquipmentFrame.lua← frame creation and refresh pipeline
Core/GoldTracking.lua  ← gold/repair-count tracking, slash commands
Core/Init.lua          ← event registration, addon lifecycle (always last)
```

---

## Namespace (`ns`)

All modules share the addon namespace via `local addonName, ns = ...`. Never use globals — attach everything to `ns`.

```lua
-- Correct
function ns:MyFunction() end
ns.myValue = 123

-- Wrong
MyGlobalFunction = function() end
```

---

## Configuration System

### Storage

Config lives in `ArauMRHToolDB` (account-wide `SavedVariables`), mirrored as `ns.config`. All layout-specific settings are scoped per Edit Mode layout:

```
ArauMRHToolDB.editMode.layouts[layoutName].<path>
```

`layoutName` is used as a **raw table key** — never concatenate it into a dot path
(see [Known Pitfalls](#a-layout-name-can-contain-a-dot)). `<path>` is layout-relative,
which is also how it's looked up in `ns.defaults`.

There's also `ArauMRHToolCharDB` (per-character `SavedVariablesPerCharacter`), mirrored
as `ns.charConfig`, used for data that must NOT be shared account-wide (currently only
gold/repair-count tracking — see [Gold Savings Tracking](#gold-savings-tracking)).

### API

Always use the config API — never access `ArauMRHToolDB`/`ArauMRHToolCharDB` or `ns.config`/`ns.charConfig` directly in feature code:

```lua
-- Read (layout-scoped)
ns:GetLayoutConfig("icon.width")
ns:GetLayoutConfig("icon.durabilityText.font")

-- Write (layout-scoped), pass true to trigger a frame refresh
ns:SetLayoutConfig("icon.width", 40, true)
ns:SetLayoutConfig("durabilityThreshold", 0.5, true)

-- Low-level (not layout-scoped, for internal/global account-wide config)
ns:GetConfig("debugEnabled")
ns:SetConfig("debugEnabled", true)

-- Per-character (not layout-scoped, ArauMRHToolCharDB)
ns:GetCharConfig("goldSaved.total")
ns:SetCharConfig("goldSaved.total", 0)
```

`GetCharConfig`/`SetCharConfig` mirror `GetConfig`/`SetConfig` exactly (same deep-copy-on-miss
default behavior against `ns.defaults`, same dot-path format) but read/write
`ns.charConfig` instead. `SetCharConfig` has no `refreshEquipmentFrame` parameter —
none of the current per-character data needs to trigger a visual refresh.

### Critical Rule: Never Reference `ns.defaults` Directly

`GetConfig` automatically deep-copies defaults on first access. Returning a reference to a defaults table would cause mutations to corrupt the default values.

```lua
-- WRONG — exposes mutable reference to defaults
local pos = ns.defaults.frame

-- CORRECT — go through the config API (it deep-copies on miss)
local pos = ns:GetLayoutConfig("frame.point")
```

### Path Format

Dot-separated string keys. No leading/trailing dots.

```lua
"durabilityThreshold"
"icon.width"
"icon.durabilityText.position.xOffset"
"frame.point"
```

---

## Frame Lifecycle

```
ADDON_LOADED  → ns:InitializeConfig()
              → ns:InitializeCharConfig()
              → ns:ApplyDebugLocale()   ← overrides locale if debugLocale is set
PLAYER_LOGIN  → ns:HasBlacksmithing()?
                  yes → ns:BuildRepairEligibilityCache()  ← per-track spec mastery, see below
                        ns:BuildRepairPlan()               ← resolves best track per slot/bucket
                        ns:CreateAddonFrame()
                        ns:RegisterFrameWithEditMode(frame)
                        ns:RefreshFrame()
                        RegisterBlacksmithListeners()
                        (schedule adaptive retry, see Known Pitfalls)
                  no  → (addon stays dormant)
```

The addon is entirely **inert** for non-Blacksmiths. Do not activate any UI outside this guard.

### Refresh Pipeline

Every visual change goes through `ns:RefreshFrame()`:

```
ns:RefreshFrame()
  └─ InCombatLockdown()? → set pendingRefresh = true, return early
  └─ GetItems()                        ← real or dummy items
  └─ collect visibleIcons[], ResetIcon for hidden slots
  └─ CalculateIconPoints(#visibleIcons) ← compute {point, xOffset, yOffset} per icon
  └─ LayoutIcon(iconPoint, iconFrame, itemData)
       └─ LayoutIconText(iconFrame, itemData)
  └─ LayoutFrame(visibleCount)         ← resize frame + ApplyCurrentLayoutFramePosition
```

To trigger a visual update, call `ns:RefreshFrame()` or pass `true` as the third argument to `ns:SetLayoutConfig`.

**Combat lockdown:** `RefreshFrame` bails out silently if `InCombatLockdown()` is true and sets `ns.pendingRefresh = true`. The `PLAYER_REGEN_ENABLED` event clears the flag and re-runs the refresh when combat ends.

---

## Watched Equipment Slots

Defined in `ns.const.Equipment.WatchedSlots` (`ArauMRHTool.lua`):

| Slot ID | Slot     |
|---------|----------|
| 1       | Head     |
| 3       | Shoulder |
| 5       | Chest    |
| 6       | Waist    |
| 7       | Legs     |
| 8       | Feet     |
| 9       | Wrist    |
| 10      | Hands    |
| 16      | Main Hand|
| 17      | Off Hand |

Adding a new slot requires updating `WatchedSlots`, `SlotFrameName`, `IconTextureName`, `DurabilityStringName`, and the dummy textures table in `EquipmentFrame.lua`.

---

## Orientation System

Defined in `ns.enums.Orientation`. Controls both the direction icons grow and the anchor point used to position the frame on screen.

| Value  | Constant              | Frame anchor | Icon growth direction |
|--------|-----------------------|--------------|-----------------------|
| `"HLR"`| HorizontalLeftToRight | LEFT         | → right (index order) |
| `"HRL"`| HorizontalRightToLeft | RIGHT        | ← left (index order)  |
| `"HC"` | HorizontalCenter      | CENTER       | → right (index order) |
| `"VTB"`| VerticalTopToBottom   | TOP          | ↓ down (index order)  |
| `"VBT"`| VerticalBottomToTop   | BOTTOM       | ↑ up (index order)    |
| `"VC"` | VerticalCenter        | CENTER       | ↓ down (index order)  |

The frame anchor is derived from orientation via `orientationAnchor` in `EditMode.lua` and applied by `ns:GetOrientationAnchor()`. Always validate orientation values with `ns:IsValidOrientation(value)` before storing.

### `CalculateIconPoints(total)`

Called by `RefreshFrame` to compute the `{point, xOffset, yOffset}` for each visible icon. Always anchors icons to a **fixed point of the frame** (`LEFT` for horizontal, `TOP` for vertical), independent of `frame.point` saved in config:

- `HorizontalLeftToRight` / `HorizontalCenter`: `LEFT`, xOffset grows right by index
- `HorizontalRightToLeft`: `LEFT`, xOffset reversed — first icon placed at the far right
- `VerticalTopToBottom` / `VerticalCenter`: `TOP`, yOffset grows downward (negative)
- `VerticalBottomToTop`: `TOP`, yOffset reversed — first icon placed at the bottom

### Frame position and orientation changes

`SaveFramePositionForAnchor(frame, anchor)` in `EditMode.lua` reads the frame's current screen coordinates and saves `frame.x / frame.y` relative to the new anchor on UIParent. Called in two places:

1. **LEM drag callback** — after the user moves the frame in Edit Mode
2. **Orientation `set`** — before saving the new orientation, converts the stored position to the new anchor so the frame stays visually in place

---

## Edit Mode Integration (LibEQOL)

Registration happens in `ns:RegisterFrameWithEditMode(frame)` (`EditMode.lua`).

- `LEM:AddFrame(frame, onMovedCallback, defaults)` — registers the frame as draggable
- `LEM:AddFrameSettings(frame, settings)` — adds the settings panel
- Callbacks `"enter"` / `"exit"` toggle `ns.isPreviewMode` and call `ns:RefreshFrame()`

### Adding a New Setting

Add an entry to the `settings` table inside `AddFrameSettings()` in `EditMode.lua`. The table is passed directly to `LEM:AddFrameSettings(frame, settings)`.

#### Common fields (all types)

| Field | Type | Required | Description |
|---|---|---|---|
| `kind` | `LEM.SettingType.*` | yes | Widget type (see below) |
| `name` | string | yes | Label shown in the panel |
| `id` | string | no | Unique key; defaults to `name`. Required for Collapsible and when children need `parentId` |
| `parentId` | string | no | `id` of a Collapsible this entry is grouped under |
| `tooltip` | string | no | Hover tooltip text |
| `isShown` | `function(layoutName, layoutIndex) → bool` | no | Return `false` to dynamically hide the row |
| `hidden` | `function(layoutName, layoutIndex) → bool` | no | Alternative to `isShown` (inverted logic) |
| `isEnabled` | `function(layoutName, layoutIndex) → bool` | no | Return `false` to disable (grey out) the row |

The `get`/`set` callbacks always receive `(layoutName, value, layoutIndex)` from LibEQOL. In this addon we ignore those parameters and always call through `ns:GetLayoutConfig` / `ns:SetLayoutConfig` instead.

The `name` field must always use a localized string via `L.<KEY>` — never a hardcoded string literal.

---

#### `Collapsible` — section header that collapses/expands its children

```lua
{
    id = "myGroupId",                  -- children reference this via parentId
    name = "My Section",
    kind = LEM.SettingType.Collapsible,
    defaultCollapsed = false,          -- optional; starts expanded by default
},
```

| Field | Notes |
|---|---|
| `defaultCollapsed` | `true` = starts collapsed |
| `getCollapsed` | `function(layoutName, layoutIndex) → bool` — dynamic initial state |
| `setCollapsed` | `function(layoutName, collapsed, layoutIndex)` — persist state externally |

---

#### `Slider` — numeric range with optional text input

```lua
{
    parentId = "myGroupId",
    name = "Icon Size",
    kind = LEM.SettingType.Slider,
    default = ns.defaults.icon.width,
    minValue = 5,
    maxValue = 100,
    valueStep = 1,
    allowInput = true,
    formatter = function(value) return tostring(value) end,
    get = function()
        return ns:GetLayoutConfig("icon.width")
    end,
    set = function(_, value)
        ns:SetLayoutConfig("icon.width", value, true)
    end,
},
```

| Field | Notes |
|---|---|
| `minValue` / `maxValue` | Number bounds |
| `valueStep` | Step size; if ≥ 1 and integer, formatter defaults to integer display |
| `allowInput` | Show a text box next to the slider |
| `formatter` | `function(value) → string`; optional, auto-inferred for integers |

---

#### `Dropdown` — single-select list

```lua
{
    parentId = "myGroupId",
    name = "Orientation",
    kind = LEM.SettingType.Dropdown,
    default = ns.defaults.icon.orientation,
    values = {
        { text = "Horizontal - Centered",    value = ns.enums.Orientation.HorizontalCenter },
        { text = "Horizontal - Left to Right", value = ns.enums.Orientation.HorizontalLeftToRight },
        -- ...
    },
    useOldStyle = true,   -- use classic DropdownButton; recommended for consistency
    get = function()
        return ns:GetLayoutConfig("icon.orientation")
    end,
    set = function(_, value)
        ns:SetLayoutConfig("icon.orientation", value, true)
    end,
},
```

| Field | Notes |
|---|---|
| `values` | Array of `{ text, value }`. If `value` is omitted, `text` is used as the stored value |
| `generator` | `function(owner, rootDescription, data)` — alternative to `values` for dynamic menus |
| `useOldStyle` | `true` = classic `WowStyle1DropdownTemplate`; default is new `SettingsDropdown` |
| `height` | Number — enables scroll at this pixel height (useful for long lists like fonts) |

---

#### `MultiDropdown` — multi-select list

Same fields as `Dropdown`, plus:

| Field | Notes |
|---|---|
| `default` | Table of pre-selected values |
| `hideSummary` / `noSummary` | Hide the selected-items summary line below the dropdown |
| `customDefaultText` | Placeholder text shown when nothing is selected |

---

#### `Checkbox` — boolean toggle

```lua
{
    parentId = "myGroupId",
    name = "Show Text",
    kind = LEM.SettingType.Checkbox,
    default = true,
    get = function()
        return ns:GetLayoutConfig("icon.durabilityText.visible")
    end,
    set = function(_, value)
        ns:SetLayoutConfig("icon.durabilityText.visible", value, true)
    end,
},
```

---

#### `Color` — color picker swatch (opens `ColorPickerFrame`)

```lua
{
    parentId = "myGroupId",
    name = "Default Color",
    kind = LEM.SettingType.Color,
    default = { r = 1, g = 1, b = 1, a = 1 },
    hasOpacity = true,   -- show opacity slider in color picker
    get = function()
        local c = ns:GetLayoutConfig("icon.durabilityText.color.default")
        return c[1], c[2], c[3], c[4]   -- unpack {r,g,b,a}
    end,
    set = function(_, color)
        -- color = { r, g, b, a }
        ns:SetLayoutConfig("icon.durabilityText.color.default",
            { color.r, color.g, color.b, color.a }, true)
    end,
},
```

`get` may return either `r, g, b, a` as multiple values or a `{r,g,b,a}` table — LibEQOL normalises both.
`set` always receives `{ r, g, b, a }`.

---

#### `Input` — free-text or numeric input box

```lua
{
    parentId = "myGroupId",
    name = "Custom Label",
    kind = LEM.SettingType.Input,
    numeric = false,     -- true = only accept numbers
    maxChars = 32,
    get = function()
        return ns:GetLayoutConfig("some.text.path")
    end,
    set = function(_, value)
        ns:SetLayoutConfig("some.text.path", value, true)
    end,
},
```

| Field | Notes |
|---|---|
| `numeric` | Accept only numbers; `set` receives a `number` |
| `readOnly` | Display only; `set` is never called |
| `maxChars` | Max character limit |
| `labelWidth` / `inputWidth` | Override default widths |
| `selectAllOnFocus` | Select all text when focused |

---

#### `Divider` — visual separator line

```lua
{ kind = LEM.SettingType.Divider },
```

No other fields needed.

---

## Internationalization (i18n)

### Structure

```
Locales/
  enUS.lua   ← ns.Locales["enUS"] = { KEY = "English string", ... }
  ptBR.lua   ← ns.Locales["ptBR"] = { KEY = "Portuguese string", ... }
Core/
  I18n.lua   ← builds ns.L from ns.Locales using GetLocale() (or debugLocale)
```

### How `ns.L` works

`I18n.lua` exposes `ns.L` as a proxy table backed by an internal upvalue `currentLocaleTable`. The active locale table is set with fallback to `enUS`:

```lua
-- If client is ptBR: L.SHOW_DURABILITY → "Exibir Durabilidade"
-- If client is enUS: L.SHOW_DURABILITY → "Show Durability"
-- If key missing in active locale: falls back to enUS value automatically
```

Because `ns.L` is always the **same table reference**, `local L = ns.L` cached at file load time stays valid even when `ApplyDebugLocale()` swaps the active locale after `ADDON_LOADED`.

### Usage

In any module, declare at the top of the file:

```lua
local L = ns.L
```

Then use symbolic keys with dot notation:

```lua
name = L.SHOW_DURABILITY
name = L.ORIENTATION_HORIZONTAL_LTR
```

Never use string literals for user-visible text — always go through `L`.

### Adding a new string

1. Add the key to **both** locale files with identical structure:

```lua
-- Locales/enUS.lua
MY_NEW_KEY = "My new label",

-- Locales/ptBR.lua
MY_NEW_KEY = "Meu novo rótulo",
```

2. Use `L.MY_NEW_KEY` in code.

### Adding a new locale

1. Create `Locales/xxXX.lua` with the same key structure as `enUS.lua`
2. Register it in `ArauMRHTool.toc` before `Core/I18n.lua`
3. Optionally add `## Title-xxXX` and `## Notes-xxXX` in the `.toc` for the addon list UI

### TOC localization

The `.toc` supports locale-specific metadata natively — no Lua code needed:

```
## Title: Araucaria Master Repair Hammer
## Title-ptBR: Araucaria Martelo de Reparo do Mestre
## Notes: English description...
## Notes-ptBR: Descrição em português...
```

WoW selects the correct entry automatically based on the client locale.

---

## Preview / Dummy Mode

When Edit Mode is active, `ns.isPreviewMode = true`. `GetItems()` returns dummy data from `GetDummyItems()` instead of real durability values.

- Dummy items are cached in `ns.dummyItems` for stability during the session
- Set `ns.forceDummyRefresh = true` to invalidate the cache on the next refresh
- Dummy items have no repair interaction (clicking does nothing meaningful)
- Dummy textures are hardcoded per slot in `EquipmentFrame.lua`
- 1-3 random slots are marked `repairable = false` each time the dummy cache is
  rebuilt, so the warning icon/desaturation can be previewed in Edit Mode

---

## Repair Eligibility & Multi-Expansion Hammers

There are 3 Master Repair Hammers, one per expansion, each gated by its own
Blacksmithing specialization tree and covering item req. levels up to its own
ceiling (higher tiers cover a superset of lower ones — see `ns.const.RepairTracks`
in `Core/RepairTracks.lua` for the exact IDs and comments).

### The repair plan (computed once at login)

```lua
ns:BuildRepairEligibilityCache()  -- per track: which slot/weapon-bucket perks are unlocked
ns:BuildRepairPlan()              -- per slot/bucket: best (newest mastered) track → { maxItemLevelReq, hammerItemId }
```

Both run in `Init.lua`'s `OnPlayerLogin`, right after `HasBlacksmithing()` confirms
true and before `CreateAddonFrame()`. The resulting `ns.repairPlan` is a plain lookup
table — checking eligibility or picking a hammer at refresh time never calls
`C_ProfSpecs` again. **If the player masters a new track mid-session, they need to
`/reload`** for this to update (there's no live-update mechanism, by design).

### Eligibility query

```lua
ns:CanRepairSlot(slotId, itemLevelReq, classID, subclassID)  -- bool
ns:GetRepairPlanEntry(slotId, classID, subclassID)           -- { maxItemLevelReq, hammerItemId } or nil
```

Rule (see `Core/RepairTracks.lua`):
- Armor (`classID` = `ns.enums.Blizz.Item.ClassID.Armor`): `subclassID` = `Plate` →
  checks that specific slot's perk; `subclassID` = `Shield` (only valid in OffHand,
  slot 17) → checks the shield perk. Any other armor subclass is never repairable.
- Weapon (`classID` = `Weapon`): resolves a bucket (`longBlades`/`shortBlades`/
  `maces`/`axesPolearms`) from `subclassID` via `ns:GetWeaponBucket`, then checks that
  bucket's perk. Subclasses with no bucket mapping (bows, guns, wands, staves,
  crossbows, thrown, fishing poles) are never repairable — Blacksmiths don't craft
  those weapon types.

`itemLevelReq`/`classID`/`subclassID` come from `C_Item.GetItemInfo(itemLink)` (5th,
12th, 13th return values) in `GetLowDurabilityItems`/`GetDummyItems`.

### `showOnlyRepairable` and the warning icon

`ns:GetLayoutConfig("showOnlyRepairable")` (layout-scoped checkbox) controls whether
`GetLowDurabilityItems`/`GetDummyItems` drop non-repairable slots entirely, or include
them with `itemData.repairable = false`. When included, `LayoutIcon` desaturates the
main texture and shows `iconFrame.warningIcon` (a small bordered/outlined triangle,
size and offset configurable) with its own tooltip.

### Macro per icon: two different update strategies

- **The 8 pure armor slots** (Head/Shoulder/Chest/Waist/Legs/Feet/Wrist/Hands): the
  slot's "category" never changes at runtime (Chest is always a chest piece, whatever
  its armor subtype) — the macro is written **once**, in `CreateEquipmentIconFrame`
  at login (`SetArmorSlotMacro`), reading `ns.repairPlan.bySlot[slotId]` directly.
  Never touched again during the session.
- **MainHand/OffHand**: the category (weapon bucket, or shield for OffHand) depends on
  whatever is currently equipped — the macro is recalculated every `LayoutIcon` call
  (`SetWeaponSlotMacro`/`ns:GetRepairPlanEntry`), inside the same `InCombatLockdown()`
  guard already in `RefreshFrame`.

Firing the macro against an item the chosen hammer can't actually repair is
harmless — the game just shows an in-combat-log-style message, no Lua error — so
there's no need to clear a stale macro when an item stops being repairable.

---

## Repair Buttons

Each icon frame is a `SecureActionButtonTemplate` button. Its `macrotext` attribute
is set dynamically — see [Repair Eligibility & Multi-Expansion Hammers](#repair-eligibility--multi-expansion-hammers)
above for exactly when/how — but always follows this shape:

```
/use item:<hammerItemId>
/use <slotId>
```

This fires the resolved Master Repair Hammer at the specific slot.

**Secure frame restriction:** `SecureActionButtonTemplate` frames cannot have position, size, or attributes changed during combat lockdown. Any code that calls `ClearAllPoints`, `SetPoint`, `SetSize`, or `SetAttribute` on an icon frame — including `RefreshFrame` — must be guarded with `InCombatLockdown()`. The current guard is in `RefreshFrame`; do not bypass it.

---

## Font System (LibSharedMedia)

- **Store font paths** in config, never font names
- Retrieve path from name: `LSM:Fetch("font", fontName)`
- Retrieve name from path: use the local `GetFontNameFromPath()` in `EditMode.lua`
- The font dropdown (`BuildFontValues()`) can be large — avoid calling it repeatedly

---

## Enums

All enums live in `Core/Enum.lua` and are attached to `ns.enums`. Use them instead of raw strings:

```lua
-- Correct
ns.enums.Blizz.FramePoint.Center
ns.enums.Blizz.Events.SystemInfo.PlayerLogin

-- Wrong
"CENTER"
"PLAYER_LOGIN"
```

When adding new Blizzard API values (frame types, events, etc.), add them to the appropriate table in `Enum.lua` first.

Item classification constants used by the repair eligibility system live under
`ns.enums.Blizz.Item`: `ClassID` (Armor/Weapon), `ArmorSubclassID` (Cloth/Leather/
Mail/Plate/Cosmetic/Shield), `WeaponSubclassID` (Axe1H, Sword2H, Dagger, etc. — numeric
IDs from `C_Item.GetItemInfo`'s 12th/13th return values).

---

## Debug System

### Logs

Enable via:

```
/run ArauMRHToolDB.debugEnabled = true; ReloadUI()
```

```lua
ns:Debug("message", value1, value2)    -- single-line debug
ns:DebugTable("label", someTable)      -- flat table dump
ns:DebugTable2("label", nestedTable)   -- nested table dump
```

Debug output is prefixed with `[ArauMRHTool]` in green. The frame backdrop border is also enabled when debug mode is on.

### Debug Locale

Forces a specific locale regardless of the client language. Useful for testing translations without changing the client locale. Only takes effect when `debugEnabled` is also `true`.

```
/run ArauMRHToolDB.debugEnabled = true; ArauMRHToolDB.debugLocale = "ptBR"; ReloadUI()
```

To clear:

```
/run ArauMRHToolDB.debugLocale = nil; ReloadUI()
```

Supported locale codes match the keys in `Locales/` (e.g. `"enUS"`, `"ptBR"`).

---

## Gold Savings Tracking

`Core/GoldTracking.lua` tracks how much gold repairing with the hammer saved compared
to paying an NPC, plus how many repairs were done. Everything is tracked in parallel
for **character** (`ArauMRHToolCharDB`, via `ns:GetCharConfig`/`SetCharConfig`) and
**account** (`ArauMRHToolDB`, via `ns:GetConfig`/`SetConfig`):

```
goldSaved.total / goldSaved.daily["yyyymmdd"]
repairCount.total / repairCount.daily["yyyymmdd"]
goldSaved.history / goldSaved.dailyHistory       ← archived on reset, keyed by time()
repairCount.history / repairCount.dailyHistory
```

### Detecting a successful repair

The repair button is a secure macro — there's no native "hammer used successfully"
event. `ns:HookGoldTrackingForIcon(iconFrame)` (called once per icon in
`CreateEquipmentIconFrame`) adds a non-secure `OnClick` hook:

1. On click, if `iconFrame.repairable` is falsy (per the last refresh), do nothing —
   this slot isn't eligible for MRH repair, so tracking it as pending would risk a
   later unrelated durability increase (e.g. a paid vendor repair) getting wrongly
   credited as hammer savings.
2. Otherwise, read `C_TooltipInfo.GetInventoryItem(unit, slotId).repairCost` (exact
   cost, works anywhere, no vendor required) and store
   `ns.pendingGoldSaved[slotId] = { repairCost, previousCurrent }`.
3. On the **next** `UPDATE_INVENTORY_DURABILITY` (`ns:ProcessPendingGoldSaved`,
   called from `Init.lua` before `RefreshFrame`), compare current durability to
   `previousCurrent`; if it increased, credit `repairCost` to both totals. **The
   pending entry is always removed at this point, matched or not** — it never waits
   past the next event, so it can't be credited by a later unrelated change.

### Reset & summary (slash commands)

`SLASH_ARAUMRHTOOL1 = "/amrh"`, handled in `Core/GoldTracking.lua`:

- `/amrh` — prints today's and all-time gold saved + repair count (character scope).
- `/amrh reset char|account` / `/amrh resettoday char|account` — archives the current
  value (both gold and repair count, same timestamp key) into the matching `history`/
  `dailyHistory` table, then zeroes it. No confirmation popup — nothing is ever
  actually discarded, so the cost of a misfire is low.

### Adding a new tracked stat

Follow the same shape: add the default under `ns.defaults.<stat>` (`total`,
`daily = {}`, plus `history`/`dailyHistory` if it should be resettable), increment it
in `ProcessPendingGoldSaved` for both scopes, and wire it into `PrintSummary`/the
reset functions if it should be reset/reported alongside gold.

---

## Known Pitfalls

### `GetInventoryItemDurability` can return `nil` for everything right after a fresh login

Confirmed via debug logs: on a genuine fresh connect (not `/reload`), durability data
isn't synced from the server yet at the exact moment `PLAYER_LOGIN` fires, so
`RefreshFrame`'s first pass finds 0 damaged items and hides the frame. This is
**not** rescued by `UPDATE_INVENTORY_DURABILITY` (only fires on a *change*, and
nothing changed — the data just wasn't there) nor by `PLAYER_ENTERING_WORLD` (tested,
doesn't help either). The fix already in place is an adaptive retry in `Init.lua`
(`RetryRefreshUntilDurabilitySynced`, every 3s up to 8 attempts, stops as soon as
`GetInventoryItemDurability` returns non-nil for any watched slot). Don't remove this
retry or replace it with a single fixed-delay `C_Timer.After` — it was specifically
built to handle slow connections/PCs without guessing a delay that might not be
enough.

### `C_Item.GetItemInfo` can return `nil` for an equipped item's classID/subclassID

Same root cause as above (client hasn't cached the item yet) but for item metadata
instead of durability — happens less often since it's covered by the same retry
loop, but if you see `itemLevelReq`/`classID`/`subclassID` come back `nil` in
`GetLowDurabilityItems`, this is why. There's no dedicated retry for this specific
case; the durability retry loop happens to cover it too since it calls
`RefreshFrame()` again.

### A layout name can contain a dot

Edit Mode layout names are free text, and ElvUI auto-creates one named `1.0 EUI`.
Building a config path as `"editMode.layouts." .. layoutName .. "." .. path` splits
such a name into two keys, so the defaults lookup misses and `GetLayoutConfig`
returns `nil` forever — every read on that layout crashes on the value (`ratio <= nil`,
`unpack(nil)`, …). `Core/Config.lua` therefore resolves `layouts[layoutName]` as a table
key and walks the layout-relative path inside it. `ns:EnsureLayoutDefaults()` copies the
old split-key data over on first use so those users keep their settings.

### Firing the repair macro on a non-repairable item is silent and harmless

Confirmed in-game: using the wrong hammer, or repairing a slot the player hasn't
specialized in, produces no Lua error — just an in-game message, and nothing
happens. Don't add defensive checks purely to avoid this; it's expected and cheap
(see [Repair Eligibility & Multi-Expansion Hammers](#repair-eligibility--multi-expansion-hammers)).

---

## Adding a New Feature — Checklist

- [ ] Add any new constants to `ns.const` in `ArauMRHTool.lua` (unless the feature
      owns a dedicated module with its own data + logic, like `RepairTracks.lua` —
      see that file's own const table for the precedent/exception)
- [ ] Add defaults to `ns.defaults` in `ArauMRHTool.lua`
- [ ] Add new enums to `Core/Enum.lua`
- [ ] Decide account-wide vs per-character storage: `ns:GetConfig`/`SetConfig`
      (`ArauMRHToolDB`) vs `ns:GetCharConfig`/`SetCharConfig` (`ArauMRHToolCharDB`) —
      layout-scoped visual settings always go through `GetLayoutConfig`/`SetLayoutConfig`
- [ ] Config reads/writes go through `ns:GetLayoutConfig` / `ns:SetLayoutConfig`
- [ ] If it affects the UI, trigger via `ns:RefreshFrame()` or `SetLayoutConfig(..., true)`
- [ ] If it modifies icon frame position/size, ensure it only runs outside combat (`InCombatLockdown()` guard already exists in `RefreshFrame` — don't bypass it)
- [ ] If it needs an Edit Mode panel control, add it in `AddFrameSettings()` in `EditMode.lua`
- [ ] If it needs dummy data, update `GetDummyItems()` in `EquipmentFrame.lua`
- [ ] Debug with `ns:Debug(...)` — never use bare `print()` in production paths
- [ ] Any user-visible string goes through `L.<KEY>` — add the key to all locale files in `Locales/`
- [ ] Update this file (`GUIDELINES.md`) if the feature adds a new subsystem,
      changes the load order, or introduces a new pitfall worth remembering
