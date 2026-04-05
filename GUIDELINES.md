# ArauMRHTool — Development Guidelines

## Overview

World of Warcraft addon (Interface 120001) that monitors equipment durability and facilitates repair via the **Thalassian Master Repair Hammer** (`item:238020`). Only activates for characters with the Blacksmithing profession.

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
Core/Config.lua        ← config API
Core/Utils.lua         ← debug helpers, profession check
Core/EditMode.lua      ← LibEQOL integration, position + settings (uses local L = ns.L)
Core/EquipmentFrame.lua← frame creation and refresh pipeline
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

Config lives in `ArauMRHToolDB` (SavedVariable), mirrored as `ns.config`. All layout-specific settings are scoped per Edit Mode layout:

```
ArauMRHToolDB.editMode.layouts[layoutName].<path>
```

### API

Always use the config API — never access `ArauMRHToolDB` or `ns.config` directly in feature code:

```lua
-- Read (layout-scoped)
ns:GetLayoutConfig("icon.width")
ns:GetLayoutConfig("icon.durabilityText.font")

-- Write (layout-scoped), pass true to trigger a frame refresh
ns:SetLayoutConfig("icon.width", 40, true)
ns:SetLayoutConfig("durabilityThreshold", 0.5, true)

-- Low-level (not layout-scoped, for internal/global config)
ns:GetConfig("debugEnabled")
ns:SetConfig("debugEnabled", true)
```

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
              → ns:ApplyDebugLocale()   ← overrides locale if debugLocale is set
PLAYER_LOGIN  → ns:HasBlacksmithing()?
                  yes → ns:CreateAddonFrame()
                        ns:RegisterFrameWithEditMode(frame)
                        ns:RefreshFrame()
                        RegisterBlacksmithListeners()
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

---

## Repair Buttons

Each icon frame is a `SecureActionButtonTemplate` button. Macro on click:

```
/use item:238020
/use <slotId>
```

This fires the repair hammer at the specific slot.

**Secure frame restriction:** `SecureActionButtonTemplate` frames cannot have position, size, or attributes changed during combat lockdown. Any code that calls `ClearAllPoints`, `SetPoint`, or `SetSize` on an icon frame — including `RefreshFrame` — must be guarded with `InCombatLockdown()`. The current guard is in `RefreshFrame`; do not bypass it.

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

## Known Pitfalls

Nenhum pitfall ativo no momento.

---

## Adding a New Feature — Checklist

- [ ] Add any new constants to `ns.const` in `ArauMRHTool.lua`
- [ ] Add defaults to `ns.defaults` in `ArauMRHTool.lua`
- [ ] Add new enums to `Core/Enum.lua`
- [ ] Config reads/writes go through `ns:GetLayoutConfig` / `ns:SetLayoutConfig`
- [ ] If it affects the UI, trigger via `ns:RefreshFrame()` or `SetLayoutConfig(..., true)`
- [ ] If it modifies icon frame position/size, ensure it only runs outside combat (`InCombatLockdown()` guard already exists in `RefreshFrame` — don't bypass it)
- [ ] If it needs an Edit Mode panel control, add it in `AddFrameSettings()` in `EditMode.lua`
- [ ] If it needs dummy data, update `GetDummyItems()` in `EquipmentFrame.lua`
- [ ] Debug with `ns:Debug(...)` — never use bare `print()` in production paths
- [ ] Any user-visible string goes through `L.<KEY>` — add the key to all locale files in `Locales/`
