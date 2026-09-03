# Changelog

All notable changes to this addon are documented here. This file is what gets shown
as the release changelog on CurseForge and Wago.

## [1.1.1] - 2026-08-28

### Fixed

- Damaged gear now shows up after a loading screen. Previously the display only
  updated when durability actually changed, so gear that was already worn stayed
  hidden until the next hit you took.

- The addon showed nothing and spammed Lua errors while an Edit Mode layout with a
  dot in its name was active — such as the "1.0 EUI" layout ElvUI creates. Settings
  saved on those layouts are recovered, not lost.
- Switching Edit Mode layouts now applies that layout's position and settings right
  away, instead of waiting for the next equipment or durability change.

## [1.1.0] - 2026-07-04

### Added

- Track how much gold you've saved by using the Master Repair Hammer instead of
  paying an NPC to repair — shown for today and all-time.
- A short chat message after each repair showing how much you just saved.
- `/amrh` prints a quick summary of today's and total gold saved.
- `/amrh reset char|account` and `/amrh resettoday char|account` to reset the
  counters (previous totals are archived, never lost).
- A warning icon (and a new "Show Only Repairable" option) for equipment the Master
  Repair Hammer can't actually repair yet — for example, if you haven't specialized
  in that particular armor piece or weapon type.
- Support for the Master Repair Hammers from previous expansions (Dragonflight, The
  War Within), not just the current one — the addon now picks the right hammer
  automatically based on what you're able to repair.

### Fixed

- The addon could fail to show up right after logging in, only appearing after a
  `/reload` or opening Edit Mode. It now shows up correctly on the first try.

## [1.0.0] - Initial release

- First release: durability tracking and one-click repair with the Master Repair
  Hammer, fully configurable through Edit Mode.
