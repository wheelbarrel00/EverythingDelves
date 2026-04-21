# Changelog

All notable changes to Everything Delves will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.6] - 2026-04-21

### Fixed

- Weekly Delve Quest: corrected quest name from "A Call to Delves" to `Midnight: Delves` (Quest ID `93909`) so completion tracking in the Shard Tracker tab works properly.

## [1.0.5] - 2026-04-21

### Changed

- Updated TOC Interface version to `120005` for WoW patch 12.0.5.
- Updated release workflow (`.github/workflows/release.yml`): added `GITHUB_OAUTH: ${{ secrets.GITHUB_TOKEN }}` so the packager creates a proper GitHub Release and attaches the zip artifact (`EverythingDelves-vX.Y.Z.zip`) and `release.json`; added `workflow_dispatch` trigger for manual runs.

## [1.0.4] - 2026-04-20

### Fixed

- Scroll clipping in `TabTierGuide.lua` and `TabShardTracker.lua` — scroll child had hardcoded heights (550px / 950px) that clipped content when all sections were expanded (Midnight faction renown rows and WQ list were unreachable). Raised initial fallback to 1200/1400 and added a dynamic `UpdateContentHeight()` that measures actual content extent and calls `UpdateScrollRange()`. Invoked via `C_Timer.After(0, UpdateContentHeight)` in each tab's `OnShow` so recalculation runs after layout completes.

### Changed

- `TabShardTracker.lua`: replaced per-row closure allocation in the WQ button `OnClick` with a single shared closure set at row creation; the current WQ is stored as `row.wpBtn.wq` so refreshes no longer allocate a closure per row per event.
- `TabOptions.lua`: moved `StaticPopupDialogs["EVERYTHINGDELVES_RESET"]` table definition out of the Reset button's `OnClick` into a one-time module init, eliminating table rebuilds on every click.
- `TabCurrentBountiful.lua`: `E.db.manualComplete` now sweeps the entire table against the last weekly reset timestamp instead of only clearing keys for delves in the current rotation, preventing unbounded growth across seasons.

## [1.0.3] - 2026-04-20

### Fixed

- Coffer Shard World Quests now display the correct zone name for subzone quests (Zul'Aman was incorrectly showing as Eversong Woods)
- World quests no longer appear as duplicates when the same quest is surfaced by multiple parent zone scans

## [1.0.2] - 2026-04-19

### Fixed

- Re-enabled Weekly Delve Quests section (quest ID 93595 "A Call to Delves" confirmed valid)

### Changed

- Memory optimizations: local caching of globals (math.floor, string.format, table.insert, etc.) across all 7 Lua files
- WQ scanner: reuse tables via wipe() instead of creating new ones each scan
- WQ scanner: cache zone names and prime map data once per session
- Bountiful data: reuse E.currentBountifulNames and E.currentBountifulPOIs tables via wipe()
- Reduced scroll child heights (TabShardTracker 1400→950, TabTierGuide 700→550)
- Eliminated redundant C_Map.GetMapInfo() calls in WQ scanner

## [1.0.1] - 2026-04-18

### Fixed

- Replaced remaining `✓` (U+2713) characters that rendered as rectangles in WoW fonts
- Completed Special Assignments now display in bright green instead of muted gray
- Progress bar no longer shows 0/100 when shards are an exact multiple of 100
- "Progress toward next key" label now dynamically shows shards remaining

### Changed

- Suppressed 22 LuaLS false positive diagnostic warnings with proper annotations
- Marked optional callback parameters in TabOptions.lua factory functions
- Added nil guard for dbKey in CreateCheckbox
- Added .gitignore to exclude .vscode/ editor folder

## [1.0.0] - 2026-04-18

### Added

- **Delve Locations** — searchable directory of all 10 Midnight delves across 6 zones
- Zone filter dropdown, name search, sortable columns (name, zone)
- Blizzard map pin and TomTom waypoint buttons per delve
- "Set All Waypoints" bulk TomTom feature
- Per-delve run history tracking
- **Current Bountiful Delves** — live detection via C_AreaPoiInfo (no manual data)
- Currency dashboard: Coffer Key Shards, Bountiful Keys, Undercoins
- Delver's Journey / renown stage display
- Live weekly reset countdown (updates every second)
- Manual completion toggle (right-click) with weekly auto-expiry
- Great Vault and LFG (Delves category) quick-launch buttons
- Story variant and overcharged bountiful display
- Weekly bountiful progress bar
- **Tier Guide** — T1–T11 iLvl reference table with personalized recommendation
- Great Vault progress bars (Delves/Dungeons, World Content, PvP)
- Seasonal Nemesis tracker (Nullaeus at Torment's Rise) with waypoints
- Valeera companion config launcher
- Trovehunter's Bounty status with bag and aura detection
- Beacon of Hope inventory check with Undercoin progress bar
- Gilded Stash progress (4× T11 Bountiful weekly)
- Midnight faction renown bars (Silvermoon Court, Amani Tribe, Hara'ti, The Singularity)
- **Shard Tracker** — currency overview with next-key and weekly-cap progress bars
- 9 weekly shard sources with live quest-line completion tracking
- Session tracker: shards earned, keys earned, elapsed time, shards/hour rate
- 8 Special Assignments with unlock/active/completed status
- Weekly Delve Quest tracker ("A Call to Delves")
- Coffer Shard World Quest scanner across all 6 Midnight zones
- Low shard warning with configurable threshold
- **Options** — UI scale slider, accent color (red/gold/purple), default tab
- Minimap button toggle, session tracking, completed item display
- Bountiful rotation change alerts, Special Assignment alerts
- Full reset to defaults
- **General** — LibDataBroker launcher with live tooltip stats
- Minimap button (LibDBIcon with manual fallback)
- Draggable, position-saving window with ESC-to-close
- Slash commands: `/ed`, `/everythingdelves`, `/ed reset`
- Dark red Midnight-themed UI
- ~419kb memory footprint
