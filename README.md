<p align="center">
  <img width="200" height="200" alt="unnamed" src="https://github.com/user-attachments/assets/929c1569-0631-45e5-97ec-ca4f2ebbb550" />

</p>
<h1 align="center">Everything Delves</h1>
<p align="center">
  <strong>The all-in-one Delves companion for World of Warcraft: Midnight</strong>
</p>
<p align="center">
  <a href="https://github.com/wheelbarrel00/EverythingDelves/releases"><img src="https://img.shields.io/github/v/release/wheelbarrel00/EverythingDelves?color=FF2222&label=Version" alt="Version" /></a>
  <img src="https://img.shields.io/badge/WoW-Midnight%2012.0-8B0000?style=flat-square" alt="WoW Version" />
  <img src="https://img.shields.io/badge/Interface-120005-333333?style=flat-square" alt="Interface" />
  <a href="LICENSE"><img src="https://img.shields.io/github/license/wheelbarrel00/EverythingDelves?style=flat-square&color=333333" alt="License" /></a>
  <img src="https://img.shields.io/badge/Memory-~600kb-333333?style=flat-square" alt="Memory" />
</p>
<p align="center">
  Track bountiful delves, shard income, tier rewards, faction renown, delve history, and more — in a single dark-red themed window.
</p>
<details>
<summary>Screenshots</summary>
<img width="1265" height="916" alt="Delve Locations" src="https://github.com/user-attachments/assets/95c4c29c-028a-40ba-aec5-b4d5d6ce8ccf" />
<img width="1265" height="912" alt="Bountiful Delves" src="https://github.com/user-attachments/assets/27dc373f-479a-4571-9e4f-24a501958f2b" />
<img width="1269" height="917" alt="Tier Gude" src="https://github.com/user-attachments/assets/242a10f3-80a9-4cf8-a9c1-0af622787015" />
<img width="1268" height="916" alt="Shard Tracker" src="https://github.com/user-attachments/assets/df555bea-774c-4c8b-ad6f-c30ea18bee79" />
<img width="1271" height="921" alt="Options" src="https://github.com/user-attachments/assets/daf7b38c-af87-4bf2-8949-5b93a137f208" />
</details>

---

## Overview

Everything Delves is a display-only companion addon for WoW: Midnight (12.0 Season 1). It reads currencies, quest logs, map data, and item levels to give you a complete picture of your weekly delve progress — without automating any gameplay.

Open with **`/ed`** or the minimap button. Right-click the minimap button to jump to Options.

---

## Everything in One Window

- **Delve Locations** — all 10 Midnight delves with tier ratings, today's story, waypoints, and expandable boss tactics
- **Current Bountiful Delves** — live bountiful detection, a "Best Pick", an auto-filling checklist, and a daily reset timer
- **Tier Guide** — T1–T11 reward iLvls, Great Vault progress, Gilded Stash, Trovehunter's Bounty, and faction renown
- **Nullaeus** — the weekly seasonal nemesis boss delve: mechanics, phases, and the full reward track
- **Shard Tracker** — every shard source, currency bars, a session shards/hour rate, and a world-quest scanner
- **Delve History** — per-character run log with times, tiers, the boss you faced, story variants, and your own notes
- **Delver's Call** — weekly World Tour quest tracker (Available → In Progress → Banked → Turned In) with an account-wide rollup
- **Options & Profiles** — color themes, alerts, companion-audio mutes, and per-character history profiles

---

## Features

### Delve Locations
All 10 Midnight delves across 6 zones in a sortable list — sort by name, zone, or tier rating by clicking the column headers. Each delve shows its **tier rating (S–F)** for today's story variant, today's story, and a per-delve run count. Set a Blizzard map pin or TomTom waypoint with one click, or drop waypoints for the whole list with "Set All Waypoints". Bountiful delves are highlighted with a gold star. **Click any delve to expand it for boss tactics** — every boss's mechanics with a one-line summary plus a full role-by-role breakdown, and today's boss marked with a star.

### Current Bountiful Delves
Live bountiful detection via `C_AreaPoiInfo` — no manual data entry. At a glance, see your Bountiful Keys, Coffer Key Shards, Delver's Journey stage, and a live **daily** reset countdown (bountiful delves and story variants rotate daily). Each delve shows its story variant, tier rating, and overcharged status, with a "Best Pick" suggestion for the highest-value bountiful. The checklist and progress bar fill in **automatically** from your completed runs. Quick-launch buttons for the Great Vault and Group Finder, and the **same expandable boss tactics** as the Delve Locations tab.

### Tier Guide
Full T1–T11 reward reference: recommended gear iLvl, bountiful loot iLvl, and Great Vault iLvl. Your equipped iLvl is read automatically and the recommended tier is highlighted. This tab also includes:
- **Great Vault Progress** — bars for Mythic+ Dungeons, Delves/World Content, and PvP
- **Valeera Companion** — one-click launcher for the companion configuration UI
- **Trovehunter's Bounty** — looted/used/active status with bag and aura checks
- **Gilded Stash** — 4× T11 Bountiful weekly reward progress
- **Midnight Faction Renown** — Silvermoon Court, Amani Tribe, Hara'ti, The Singularity

### Nullaeus (Seasonal Nemesis)
A dedicated tab for the weekly **Nullaeus** boss delve in Torment's Rise (Voidstorm): quest status with a one-click map pin / TomTom waypoint, a **Beacon of Hope** inventory and Undercoin tracker, the full boss mechanics list, the three phase transitions, and the reward track — the Nullaeus Domaneye helm, Dominating Victory toy, Arcanovoid Construct mount, and the Ominous / Fabled Vanquisher titles, each with a live item tooltip.

### Shard Tracker
Your shard economy dashboard. Currency overview with progress bars for next key and weekly cap. All 9 known shard sources with live quest completion tracking. Also includes:
- **Session Tracker** — shards earned, keys earned, elapsed time, shards/hour rate
- **Special Assignments** — all 8 tracked with unlock, active, and completed status
- **Weekly Delve Quest** — "Midnight: Delves" completion status
- **World Quest Scanner** — all 6 Midnight zones scanned for shard-rewarding WQs
- **Low Shard Warning** — configurable threshold alert

### Delve History
Lifetime stats and recent run history for every Midnight delve, including the Seasonal Nemesis (Torment's Rise / Nullaeus). Auto-detected — just play normally and runs are logged automatically. Grouped by delve with collapsible detail rows:
- **Total runs, highest tier, average & fastest times, and total deaths** per delve
- **Latest run** time and date shown on each delve's summary line
- **Per-run detail** for the last 20 runs: tier, time, deaths, Coffer Key used, story variant, the **boss you faced**, and the date + time of day
- **Free-form notes** — attach a note to any run (a build you tested, a notable drop, a curio experiment); click the note icon to add, edit, or clear it
- Lifetime totals persist across sessions with minimal memory cost

### Delver's Call
Tracks all 10 weekly World Tour quests across four states — **Available, In Progress, Banked, and Turned In** — auto-detected from your quest log. The strategy: bank the quests and hold them until you're near max level, then turn them all in for a leveling burst. Includes a rollup showing progress across every character on your account.

### Options
UI scale, accent color theme (red / gold / purple / green / dark blue), default tab, minimap button toggle, session tracking, completed item display, low shard warning threshold, bountiful rotation alerts, Special Assignment alerts, and **Companion Audio** mutes (silence Valeera and/or Dun-dun while inside a delve). `/ed reset` resets **only** account-wide settings — your delve history and profiles are never touched.

### Profiles
Delve history, completion marks, and Gilded Stash progress are tracked **per character**. The Profiles tab lets you see the active profile, switch to another, create a fresh empty one, duplicate the current one, or delete an unused one. Switching never erases data — it only changes which history that character uses. Your existing history **migrates automatically and is never deleted**: log your main in first after updating and it keeps everything with zero clicks; every other character starts fresh with its own. UI settings (colors, scale, alerts) stay account-wide so you only set them once.

### Quality of Life
- **Curio reminder** — an optional popup when you open the companion configuration, reminding you which curios to slot
- **What's New** — a one-time popup highlighting each feature release

---

## Installation

### From CurseForge
1. Install via the [CurseForge app](https://www.curseforge.com/) or download manually
2. The addon will be placed automatically in your AddOns folder

### Manual Install
1. Download the latest release from the [Releases](https://github.com/wheelbarrel00/EverythingDelves/releases) page
2. Extract the `EverythingDelves` folder into:
   ```
   World of Warcraft/_retail_/Interface/AddOns/
   ```
3. Restart WoW or type `/reload` if already in-game
4. Enable **Everything Delves** at the character select screen

---

## Usage

| Command | Action |
|---|---|
| `/ed` | Toggle the main window |
| `/everythingdelves` | Toggle the main window (alternate) |
| `/ed reset` | Reset account-wide settings to defaults (delve history & profiles untouched) |
| **Left-click** minimap button | Toggle window |
| **Right-click** minimap button | Open directly to Options |
| **Drag** minimap button | Reposition around minimap |

The minimap tooltip shows a live snapshot of your currencies, active bountiful count, and weekly reset timer.

---

## Zones & Delves Covered

| Zone | Delves |
|---|---|
| Isle of Quel'Danas | Parhelion Plaza |
| Eversong Woods | The Shadow Enclave |
| Zul'Aman | Atal'Aman, Twilight Crypt |
| Voidstorm | Shadowguard Point, Sunkiller Sanctum, Torment's Rise (Seasonal Nemesis) |
| Harandar | The Gulf of Memory, The Grudge Pit |
| Silvermoon | Collegiate Calamity, The Darkway |

---

## Dependencies

**Required:** None — Everything Delves is fully standalone.

**Optional:**
- [TomTom](https://www.curseforge.com/wow/addons/tomtom) — enables arrow waypoints and the "Set All Waypoints" bulk feature
- [LibDBIcon](https://www.curseforge.com/wow/addons/libdbicon-1-0) — enhanced minimap button (addon auto-detects and upgrades if available)

LibStub, LibDataBroker-1.1, and CallbackHandler-1.0 stubs are included for broker display compatibility (ElvUI, Titan Panel, etc.).

---

## Technical Details

| Metric | Value |
|---|---|
| Memory footprint | ~600 KB |
| Lua files | 18 |
| Interface version | 120007 (Midnight 12.0) |
| SavedVariables | `EverythingDelvesDB` |
| API compliance | Display-only — no taint, no automation |

### Architecture
```
EverythingDelves/
├── EverythingDelves.lua          # Bootstrap: namespace, events, slash commands
├── EverythingDelves.toc          # Addon manifest
├── Core/
│   ├── Constants.lua             # Colors, tier data, shard sources, currency IDs
│   ├── Data.lua                  # Delve directory (names, zones, coordinates, POI IDs)
│   └── Utils.lua                 # UI factories, waypoint helpers, tooltip, progress bars
├── UI/
│   ├── MainFrame.lua             # Window, tabs, minimap button, LibDataBroker
│   ├── TabDelveLocations.lua     # Tab 1: sortable delve list + boss tactics
│   ├── TabCurrentBountiful.lua   # Tab 2: live bountiful detection + currency dashboard
│   ├── TabTierGuide.lua          # Tab 3: tier table, vault, renown, gilded stash
│   ├── TabNullaeus.lua           # Tab 4: seasonal nemesis boss delve
│   ├── TabShardTracker.lua       # Tab 5: shard economy, session tracker, WQ scanner
│   ├── TabDelveHistory.lua       # Tab 6: lifetime stats + run history, notes, bosses
│   ├── TabDelversCall.lua        # Tab 7: weekly World Tour quest tracker
│   ├── TabOptions.lua            # Tab 8: all user settings
│   ├── TabProfiles.lua           # Tab 9: per-character profile management
│   ├── CurioReminder.lua         # Curio reminder popup
│   ├── CompanionAudio.lua        # Optional Valeera / Dun-dun mute
│   ├── TrovehunterReminder.lua   # Trovehunter's Bounty reminder
│   └── WhatsNew.lua              # One-time feature-release popup
└── Libs/                         # LibStub, LibDataBroker, LibDBIcon, CallbackHandler
```

Modules register via `E:RegisterModule(callback)` at load time. All callbacks execute inside `InitMainFrame()` after the main window is built on `PLAYER_LOGIN`. Data events propagate through a callback system (`E:RegisterCallback` / `FireCallbacks`) so multiple modules can safely listen to the same WoW event.

---

## Contributing

Contributions are welcome! If you'd like to help:

1. **Fork** the repo
2. **Create a branch** for your feature (`git checkout -b feature/my-feature`)
3. **Commit** your changes (`git commit -m "Add my feature"`)
4. **Push** to your branch (`git push origin feature/my-feature`)
5. Open a **Pull Request**

### Reporting Bugs

Please use the [GitHub Issues](https://github.com/wheelbarrel00/EverythingDelves/issues) tab. Include:
- Your WoW client version and region
- Steps to reproduce
- Any error messages from `/console scriptErrors 1`
- Screenshot if applicable

---

## Roadmap

- [ ] Companion (Valeera) curio recommendations per tier
- [ ] Multi-character shard tracking
- [ ] Localization support (enUS, deDE, frFR, etc.)

---

## License

This project is licensed under the [MIT License](LICENSE).

---

## Acknowledgments

- Built by Wheelbarrel00
- Packaged and deployed with **[BigWigsMods/packager](https://github.com/BigWigsMods/packager)**
- Minimap button powered by **[LibDBIcon](https://www.curseforge.com/wow/addons/libdbicon-1-0)** and **[LibDataBroker](https://www.curseforge.com/wow/addons/libdatabroker-1-1)**
- WoW API references from **[Warcraft Wiki](https://warcraft.wiki.gg)**

---

<p align="center">
  <sub>Made for the Midnight expansion · Season 1 · 2026</sub>
</p>
