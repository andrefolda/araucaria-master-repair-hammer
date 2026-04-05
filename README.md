# Araucaria Master Repair Hammer

[![CurseForge](https://img.shields.io/curseforge/v/1504924?label=CurseForge&logo=curseforge&color=F16436)](https://www.curseforge.com/wow/addons/araucaria-master-repair-hammer)
[![Wago](https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Faddons.wago.io%2Fapi%2Fproject%2FYOUR_WAGO_ID%2Fversion&query=%24.display_version&label=Wago&color=3B4FA3&logo=data:image/svg%2bxml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdCb3g9IjAgMCAxMDAgMTAwIj48dGV4dCB5PSIuOWVtIiBmb250LXNpemU9IjkwIj7wn5KVPC90ZXh0Pjwvc3ZnPg==)](https://addons.wago.io/addons/YOUR_WAGO_ID)
![WoW](https://img.shields.io/badge/WoW-11.2.0-blue?logo=battle.net)

A World of Warcraft addon for Blacksmiths who carry the **Thalassian Master Repair Hammer**. It monitors the durability of your equipped gear and shows clickable icons for each piece that needs repair — clicking an icon uses the hammer to repair that slot directly.

> Only activates if your character has the Blacksmithing profession.

---

## Features

- Displays an icon per damaged equipment slot (head, shoulders, chest, waist, legs, feet, wrist, hands, main hand, off hand)
- Each icon shows the current durability percentage
- Text color changes as durability drops: white → yellow → red
- Clicking an icon uses the Thalassian Master Repair Hammer on that slot
- Fully integrated with WoW's **Edit Mode** for positioning and configuration
- Per-layout settings (each Edit Mode layout has its own position and thresholds)

---

## Requirements

- Blacksmithing profession
- [Thalassian Master Repair Hammer](https://www.wowhead.com/item=238020) in your bags
- In order to repair that slot you, obviously, still need to master that equipment type at Armosmith/Weaponsmith Blacksmith specialization.

---

## Configuration

Open **Edit Mode** and select the addon frame to access its settings panel.

### Durability Threshold Settings

| Setting | Default | Description |
|---|---|---|
| Show Durability | 60% | Items at or below this durability will appear |
| Low Durability | 40% | Threshold for yellow text |
| Critical Durability | 20% | Threshold for red text |

### Icon Settings

| Setting | Default | Description |
|---|---|---|
| Orientation | Horizontal - Centered | How icons are arranged (6 layout options) |
| Icon Size | 40 | Width and height of each icon in pixels |

**Orientation options:** Horizontal Left to Right, Horizontal Right to Left, Horizontal Centered, Vertical Top to Bottom, Vertical Bottom to Top, Vertical Centered

### Durability Text Settings

Font, size, and X/Y offset of the durability percentage label shown on each icon.

---

## Usage

1. Have the Thalassian Master Repair Hammer in your bag
2. Icons will appear automatically when any gear falls below the **Show Durability** threshold
3. Click an icon to repair that piece
4. Drag the frame in Edit Mode to reposition it on your screen
