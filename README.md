<p align="center">
  <img src="https://img.icons8.com/color/96/world-of-warcraft.png" alt="Everything Delves" width="96" />
</p>

<h1 align="center">Everything Delves</h1>

<p align="center">
  <strong>The all-in-one Delves companion for World of Warcraft: Midnight</strong>
</p>

<p align="center">
  <a href="https://github.com/wheelbarrel00/EverythingDelves/releases"><img src="https://img.shields.io/github/v/release/wheelbarrel00/EverythingDelves?color=FF2222&label=Version" alt="Version" /></a>
  <img src="https://img.shields.io/badge/WoW-Midnight%2012.0-8B0000?style=flat-square" alt="WoW Version" />
  <img src="https://img.shields.io/badge/Interface-120001-333333?style=flat-square" alt="Interface" />
  <a href="LICENSE"><img src="https://img.shields.io/github/license/wheelbarrel00/EverythingDelves?style=flat-square&color=333333" alt="License" /></a>
  <img src="https://img.shields.io/badge/Memory-~419kb-333333?style=flat-square" alt="Memory" />
</p>

<p align="center">
  Track bountiful delves, shard income, tier rewards, faction renown, and more — in a single dark-red themed window.
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

## Features

### Delve Locations

All 10 Midnight delves across 6 zones in a searchable, sortable list. Filter by zone, search by name, and set Blizzard map pins or TomTom waypoints with one click. Bountiful delves are highlighted with a gold star. Per-delve run history tracks your completions over time.

### Current Bountiful Delves

Live bountiful detection via `C_AreaPoiInfo` — no manual data entry. At a glance, see your Bountiful Keys, Coffer Key Shards, Undercoins, Delver's Journey stage, and a live weekly reset countdown. Right-click any delve to mark it complete. Quick-launch buttons for the Great Vault and Group Finder. Story variants and overcharged status are displayed per delve.

### Tier Guide

Full T1–T11 reward reference: recommended gear iLvl, bountiful loot iLvl, and Great Vault iLvl. Your equipped iLvl is read automatically and the recommended tier is highlighted. This tab also includes:

- **Great Vault Progress** — bars for Delves/Dungeons, World Content, and PvP
- **Seasonal Nemesis** — Nullaeus quest tracker with waypoints to Torment's Rise
- **Valeera Companion** — one-click launcher for the companion configuration UI
- **Trovehunter's Bounty** — looted/used/active status with bag and aura checks
- **Beacon of Hope** — inventory check with Undercoin progress toward purchase
- **Gilded Stash** — 4× T11 Bountiful weekly reward progress
- **Midnight Faction Renown** — Silvermoon Court, Amani Tribe, Hara'ti, The Singularity

### Shard Tracker

Your shard economy dashboard. Currency overview with progress bars for next key and weekly cap. All 9 known shard sources (Haradar's Legend Relics, Saltheril's Haven, Prey Quests, rares, treasures, satchels, and more) with live quest completion tracking. Also includes:

- **Session Tracker** — shards earned, keys earned, elapsed time, shards/hour rate
- **Special Assignments** — all 8 tracked with unlock, active, and completed status
- **Weekly Delve Quests** — "Midnight: Delves" completion status
- **World Quest Scanner** — all 6 Midnight zones scanned for shard-rewarding WQs
- **Low Shard Warning** — configurable threshold alert

### Options

UI scale, accent color theme (red / gold / purple), default tab, minimap button toggle, session tracking, completed item display, low shard warning threshold, bountiful rotation alerts, and Special Assignment alerts.

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
| `/ed reset` | Reset all settings to defaults |
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
| Voidstorm | Shadowguard Point, Sunkiller Sanctum |
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
| Memory footprint | ~419 KB |
| Source lines | 5,265 |
| Lua files | 10 |
| Interface version | 120001 (Midnight 12.0) |
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
│   ├── TabDelveLocations.lua     # Tab 1: searchable/sortable delve list
│   ├── TabCurrentBountiful.lua   # Tab 2: live bountiful detection + currency dashboard
│   ├── TabTierGuide.lua          # Tab 3: tier table, nemesis, beacon, renown
│   ├── TabShardTracker.lua       # Tab 4: shard economy, session tracker, WQ scanner
│   └── TabOptions.lua            # Tab 5: all user settings
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
- [ ] Delve timer / speed-run tracking
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
