# Changelog

All notable changes to Everything Delves will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.3.1] - 2026-04-26

### Fixed

- **Shard Tracker scroll auto-reset** — the tab was scrolling back to ~25% from the top every few minutes because `CurrencyUpdate` and `QuestLogUpdate` event callbacks were calling `RefreshAll`, which deferred `UpdateContentHeight` via `C_Timer.After`. When the scroll child shrank, the scroll frame clamped the position. Both callbacks now save and restore the scroll position around the refresh so the view stays stable during background updates.
- **WQ cap warning placement** — the yellow "Weekly shard cap reached" warning was anchored above the WQ column headers at the top of the section instead of below the last WQ row. It now sits **16 px** below the last WQ row (or the empty-state message), with the grey tip text **12 px** below it, providing the breathing room that had been repeatedly requested.
- **WQ section header gap** — the grey description line ("WQs rewarding Coffer Key Shards...") was crammed 2 px below the "Coffer Shard World Quests" header. Increased to **14 px** for visible separation.
- **Pin/TomTom button border colour at cap** — the button borders remained gold/accent-coloured even when the shard cap was reached. Both borders are now set to `(0.35, 0.35, 0.35, 0.80)` grey when `isAtCap` is true and restored to the active accent preset border colour when the cap clears.

### Improved

- **Memory: ObjectiveTracker scraper** (`AutoDetectDelveTier`) no longer allocates `{ frame:GetRegions() }` / `{ frame:GetChildren() }` temporary tables on every recursive call. Switched to numeric `select(i, frame:GetRegions())` iteration and reduced four chained `:gsub()` calls to two, cutting GC pressure during delve entry.
- **Memory: SCENARIO\_UPDATE early exit** — when already inside a delve with a captured tier, redundant SCENARIO\_UPDATE fires (5–10× per entry) now short-circuit before reaching the ObjectiveTracker scrape.
- **Memory: widget set cache** (`TabCurrentBountiful`) — `C_UIWidgetManager.GetAllWidgetsBySetID()` results are now cached with a 5-second TTL so bursty `AREA_POIS_UPDATED` events don't each allocate a fresh table per POI.
- **Memory: delve name cache** (`TabDelveLocations`) — `MatchesFilter`, the sort comparator, and the bountiful name lookup no longer call `:lower()` / `strtrim():lower()` on every scroll repaint. Results are cached lazily per-delve.
- **Memory: `ApplyAccentColor` short-circuit** — skips the full `ThemedWidgets` repaint walk when the same colour is being re-applied (no-op on redundant calls).
- Fixed default fallback in `GetAccentPreset` / `GetAccentColor` to `"gold"` (was incorrectly `"red"`).

## [1.3.0] - 2026-04-25

### Added

- **TomTom buttons on Coffer Shard World Quests** — each WQ row in the Shard Tracker tab now has a "TomTom" button alongside the existing "Pin" button. Clicking it adds an arrow waypoint via TomTom to the quest's map location. The button tooltip indicates when TomTom is not installed (mirrors existing behaviour on the Delve Locations and Current Bountiful tabs).

### Fixed

- **Coffer Shard World Quest list cutoff** — the WQ rows at the bottom of the Shard Tracker tab were clipped when three or more WQs were active because the scroll child had a static height of 1400 px. `UpdateContentHeight()` is now called (deferred one frame via `C_Timer.After`) after every WQ refresh so the scroll child always expands to fit all visible rows.

### Improved

- **Minimap / broker tooltip data lines** — "Coffer Key Shards", "Bountiful Keys", "Undercoins", "Active Bountiful", and "Weekly Reset" labels and values are now white instead of grey, making them easier to read at a glance. Navigation hints (Left-click / Right-click / Drag) remain grey.

## [1.2.1] - 2026-04-25

### Fixed

- **Great Vault button** now works on stock Blizzard UI. `Blizzard_WeeklyRewards` is a load-on-demand addon that is not in memory until the player opens it for the first time; ElvUI happened to preload it, masking the issue. The button now calls `C_AddOns.LoadAddOn("Blizzard_WeeklyRewards")` before accessing `WeeklyRewardsFrame`, falling back to `ToggleGreatVaultUI` if present.
- **Start LFG button** applies the same load-on-demand fix for `Blizzard_GroupFinder` and `Blizzard_PVPUI` before accessing `PVEFrame` / `LFGListFrame`. Also added nil guards around frame references so a partial load cannot cause an error.
- Deduplicated the LFG click handler body (was copy-pasted between initial `OnClick` and `RefreshLFGButton`).

## [1.2.0] - 2026-04-25

### Added

- **Full accent color theme system** — every accent-driven UI element (frame border, window title, tab buttons, section headers, divider lines, scrollbar thumbs, progress bar fills, close button, action buttons) now repaints in real-time when the accent color is changed in Options.
- **Dark Green** accent option added (`#006400`). Total options: Red (default), Gold, Purple, Dark Green.
- `E:RegisterThemed(fn)` / `E:ApplyAccentColor(name)` architecture in `Core/Constants.lua` — single source of truth for all accent presets, no per-frame polling.
- `E:StyleAccentHeader`, `E:StyleAccentDivider`, `E:StyleAccentThumb` helper functions in `Core/Utils.lua` for consistent theming across all tabs.

### Fixed

- Fixed 52 mojibake encoding bugs (`â€"` broken em-dash and `â€ â€™` broken arrow sequences) across `MainFrame.lua`, `TabCurrentBountiful.lua`, `TabDelveLocations.lua`, `TabShardTracker.lua`, and `TabTierGuide.lua`.

### Removed

- Removed unused "H" (History) buttons from each bountiful delve row in the Current Bountiful Delves tab.

## [1.1.0] - 2026-04-23

### Added

- **Delve History tab** with lifetime stats and recent run history for every Midnight delve.
- Auto-detects delve tier during runs via `ObjectiveTracker` UI scraping — no manual input needed.
- Tracks total runs, highest tier, average and fastest completion times, deaths, and Coffer Key usage per delve.
- Seasonal Nemesis section (Torment's Rise / Nullaeus) displayed separately with a gold header.
- Last 20 individual runs stored per delve with tier, time, deaths, key used, and date.
- Lifetime summary stats persist across sessions with minimal memory footprint.
- Collapsible delve rows — click to expand and see individual run details.
- Clear History button with confirmation dialog to reset all stats.

### Changed

- Switched delve name detection to `GetRealZoneText()` with a zone ID fallback for reliability.
- Added zone ID lookup table for all 11 Midnight delves including Torment's Rise.

### Fixed

- Gilded Stash encoding bug (broken em dash character).

### Removed

- Debug output from the Delve History tracker.

## [1.0.7] - 2026-04-22

### Fixed

- **Memory leak / GC churn (root cause):** the Coffer Shard World Quest scanner in `TabShardTracker.lua` had an unbounded retry loop. When a character had no shard-rewarding WQs available (the common case outside of active gameplay), the empty-result retry rescheduled `RefreshAll(true)` via `C_Timer.After(3, ...)` every 3 seconds forever, generating ~300-500 short-lived strings plus `C_TaskQuest`/`C_QuestLog` API table churn on every tick. This produced the characteristic 2.66 MB → 6-7 MB sawtooth pattern players reported. The retry is now capped at one attempt; the budget resets on user-initiated refresh, on tab `OnShow`, and whenever a scan returns >0 quests. Memory now stays flat in steady state.

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
