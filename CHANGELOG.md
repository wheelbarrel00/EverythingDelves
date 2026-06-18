# Changelog

All notable changes to Everything Delves will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.17.0] - 2026-06-17

### New Features

- **Delver's Journey on the Tier Guide** - The Tier Guide tab now shows your Delver's Journey right under Great Vault Progress: your current Journey level, a progress bar toward the next level, and a row of milestone reward icons for each level - the current level highlighted, earned levels bright, locked levels dimmed. Hover an icon to see its reward.
- **Companion curio tooltips** - The companion curio reminder now has hover help: mouse over its title for a plain explanation of what it shows, or over any bag-count number to learn that it is how many of that curio you currently have (green means you have at least one, red means none yet).
- **Map achievement tooltips redesigned** - The delve achievements shown on a map pin (hold Shift to expand) now list every related achievement - Stories, Discoveries, and Delver of the Depths - in a clean two-column layout, with each criterion coloured green when earned and red when still needed.

## [1.16.0] - 2026-06-13

### New Features

- **About tab** - A new About tab brings the addon's info, a slash-command reference, and handy links (Discord, CurseForge, GitHub, and a bug-report link) together in one place - and it keeps the full changelog so you can catch up on anything you missed. Find it as the last tab, or type `/ed about`.
- **"Keys used" counter** - Delve History now shows how many Restored Coffer Keys you've spent on each delve, right on its header row.

### Improvements

- **Weekly Shard Sources rebuilt and verified** - The Shard Tracker's source list was fact-checked against the live game: the weekly shard cap now reads the correct 600 per week straight from the game, Saltheril's Soiree and the Haranir relic weekly are named and valued correctly, World Quests and Abundance were added, and a few unconfirmed sources were removed.
- **Dawncrest column tooltips** - Hovering the On Hand, Season Max, or Season Total headers on the Dawncrests panel now explains what each one means.

### Bug Fixes

- **Delve run times after a reload** - A run could log "--" or an inflated time if you reloaded or reconnected partway through; runs are now recovered and timed from their real start. Thanks to BanditC64 for the report.
- **Bountiful coffer "Key" tag** - Spending a Restored Coffer Key on a bountiful coffer is now reliably detected and tagged on the run (and counted by the new "Keys used" stat).
- **Nemesis Strongbox pack counter** - The Bonus Spoils tracker now counts every Nemesis Strongbox pack instead of getting stuck at "1 / 3".

## [1.15.0] - 2026-06-11

### New Features

- **Bonus Spoils tracker** - An optional on-screen tracker for a delve's two bonus chests: the Nemesis Strongbox packs (from clearing the Pactsworn groups) and the Sanctified Banner. It shows at a glance when you've secured the extra loot so you know it's safe to pull the boss, and hides itself when you leave the delve. Off by default - turn it on under Options, then drag it wherever you like. Suggested by Puzzleheaded-Pie-506.
- **Achievements on map tooltips** - Hovering a delve's pin on the world map now lists its achievements right in the tooltip: a quick summary by default, or hold Shift for the full criteria and progress. Choose summary, full details, or off in Options. Thanks to 8six753o9 for the idea.

### Bug Fixes

- **Delve run times are accurate again** - Some runs logged a wildly inflated time - a 15 minute delve showing up as over an hour - because a run could carry over the start time of the previous run instead of timing from its own entry. Runs are now always timed from the moment you enter, so the duration, average, and fastest-time stats stay correct. Any bad entries you already have can be removed with the per-run delete button, which also repairs that delve's averages. Thanks to BanditC64 for the detailed report.
- **"Key used" tag now appears** - The gold "Key" tag in Delve History still wasn't showing up. A bountiful coffer's key is spent when you loot it, which happens just after the run is marked complete, so the old check ran a moment too early and always missed it. Key usage is now watched across the whole run and the post-clear looting, so spending a key on the bountiful coffer reliably tags the run.

### Improvements

- **Dawncrest season cap** - The Dawncrests panel now shows your season maximum for each crest tier alongside the amount on hand. Crest caps are currently lifted for the rest of the season, so it reads "Uncapped".

## [1.14.0] - 2026-06-10

### New Features

- **Exact Gilded Stash count** - The Tier Guide's Gilded Stash bar now reads the exact weekly count straight from the game whenever you're inside a delve, and remembers it until the weekly reset - so the bar matches the server even for runs done before the addon was installed or that it missed logging. Until your first delve of the week it still estimates from your logged T11 Bountiful runs, and the note under the bar tells you which source you're seeing.
- **Dawncrest tracker** - The Shard Tracker tab has a new Dawncrests section listing all five crest tiers (Adventurer through Myth) with the amount on hand and your season total, right alongside your keys and shards.
- **Companion level at a glance** - The Tier Guide's companion row now shows Valeera's level and an XP progress bar inline, so you can check how close the next companion unlock is without opening her menu. Built to pick up future expansions' companions automatically.
- **Delete a single run** - Each run row in Delve History now has a small X button. Remove a bogus run (a disconnect artifact, a test run) and its time, deaths, and key usage are subtracted from that delve's lifetime stats - no more clearing the entire history over one bad entry. Record stats like fastest time recalculate automatically if the deleted run held them.

### Bug Fixes

- **"Key used" is now detected** - Run logging watched the wrong currency to decide whether you spent a Restored Coffer Key during a run, so the gold "Key" tag in Delve History never appeared and lifetime key counts stayed at zero. Runs from now on record key usage correctly. (Displayed key counts were always right - only the per-run detection was affected.)

### Improvements

- **Dundun, explained** - The "Mute Dundun voice lines" option now says who Dundun is (the Abundance event rat loa) and a hover tooltip explains that muting only silences his audio, not the event.

## [1.13.1] - 2026-06-07

### Bug Fixes

- **The Grudge Pit now logs the correct boss** - Its Arena Champion is shown in-game as Gyrospore, but the encounter reports a different internal name, so Delve History recorded the wrong boss. Runs now record and show "Gyrospore", and the fix also corrects the name on runs you already have saved. Thanks to BanditC64 for the report.
- **Delve runs survive a disconnect** - If you got disconnected partway through a delve, the timer restarted when you logged back in and recorded a much-too-fast time for that run. A run interrupted by a disconnect now keeps its original start time and records its real elapsed time. (A run interrupted by a full game restart is still timed fresh, as before.) Thanks to BanditC64 for the report.

## [1.13.0] - 2026-06-07

### New Features

- **Quickest Delve & Best Value** - The Delve Locations tab now shows an expected clear time for every delve in a new **Speed** column you can sort by, so you can line up your fastest runs first. Once you've run a delve it shows your own average time; until then it shows a pace-calibrated estimate (marked with `*`) based on how quickly you clear other delves - so a geared main and a levelling alt each see realistic numbers. Times are colour-graded relative to your own pace (Fast to Long). A new summary line at the top of the tab calls out today's **Quickest** delve and the **Best value** pick - the most reward for your time, weighing the tier, your clear speed, and whether it's bountiful today.

## [1.12.2] - 2026-06-03

### Bug Fixes

- **Sunkiller Sanctum now shows the correct boss on its "Not What I Expected" day** - This delve fields a different finale depending on the story variant, but it was always marking Esuritus as today's boss. On the "Not What I Expected" variant the run instead ends with three Corrupted Umbraroot, and the "today's boss" highlight now points to them, with their own tactics (pull one at a time, interrupt Lightbloom Beam, dodge Blooming Bile and Rotting Charge). The other two variants still correctly show Esuritus.

## [1.12.1] - 2026-06-03

### Bug Fixes

- **Deaths now survive a mid-run `/reload`** - If you died during a delve and then reloaded your UI (or reconnected) before finishing the run, the death was dropped and Delve History recorded "Deaths: 0". Your death count is now saved the moment it happens, so it survives a reload and is logged correctly when the run completes.

## [1.12.0] - 2026-06-01

### New Features

- **Join our Discord!** - Everything Delves now has a community Discord for help, feedback, suggestions, and update news. A "Join our Discord!" link sits in the top-left of the main window (and in the What's New popup); since the game can't open a browser, clicking it pops a pre-selected invite link you can copy with Ctrl+C. Come say hi!

### Bug Fixes

- **"Default Tab" option now works every time** - The Default Tab setting only took effect the first time the window was built; afterward it reopened to whatever tab you last viewed. The window now opens to your chosen default tab every time.

## [1.11.0] - 2026-05-29

### New Features

- **Choose how much delve history to keep** - By popular request, a new slider in the Delve History tab lets you set how many recent runs are stored per delve, from 20 up to 100 (default 20). Raise it to keep a longer record going forward; the runs already saved are unaffected.

### Bug Fixes

- **Trovehunter's Bounty reminder now works in Twilight Crypts** - The entry reminder could silently skip a delve whose in-game name differs slightly from the addon's internal name (such as Twilight Crypts), so the popup never appeared there even with an unused Bounty Map in your bags. These delves are now matched correctly - which also fixes their Bountiful status feeding the Gilded Stash progress and the Delve Locations highlight.
- **Completed Bountiful delves show a checkmark** - Finished delves in the Current Bountiful Delves tab displayed a grey box where the game font had no matching character; they now use a proper checkmark icon.

## [1.10.1] - 2026-05-28

### Bug Fixes

- **Trovehunter's Bounty reminder reliability** - The reminder now detects your Bounty Map correctly and still appears after a `/reload` partway through a delve, fixing cases where it could stay hidden even with an unused bounty in your bags.
- **Accurate Bountiful completion count** - The Current Bountiful Delves progress bar now counts finished delves correctly - completing one reads "1 / 4 (25%)" instead of dropping the delve off the list and shrinking the total. Finished delves now stay in the checklist, dimmed, so you can see the full day at a glance.
- **Bountiful history accuracy** - A one-time history repair was checking a weekly window for the daily-rotating Bountiful set, which could mislabel older runs as Bountiful and inflate the Gilded Stash counter. It now uses the correct daily window.
- **Trovehunter status wording** - The Tier Guide no longer reads "looted and used this week" while a Bounty Map is still in your bags; the status line and the reminder now agree.
- **Companion bubble muting** - The chat-bubble suppression for Valeera no longer keeps running in the open world after you leave a delve.

### Improvements

- **Labeled progress bars** - Every progress bar now has a clear caption so you can tell at a glance what it tracks - the Bountiful completion bar, the Shard Tracker's "Shards to Next Key" and "Weekly Shard Cap" bars, and the rest. Thanks to BanditC64 for the suggestion!
- **Great Vault cleanup** - Removed the PvP row from the Great Vault section. PvP no longer contributes to the Great Vault, so that bar could only ever read 0 / 3; the section now shows just the Mythic+ Dungeons and Delves / World Content rows that actually apply.
- **Options tidy-up** - Removed several settings that no longer had any effect, so every control in the Options panel now does what it says.
- **Delve History legend** - The "B" marker on a run (Bountiful) now shows a tooltip explaining what it means.
- **Daily wording** - Cleaned up the last few "this week" references that should read "today" for the daily Bountiful rotation.

## [1.10.0] - 2026-05-26

### New Features

- **Run notes** - Attach a free-form note to any run in the Delve History tab to jot down a build you tested, a notable drop, or a curio experiment. Click the note icon beside a run to add, edit, or clear it. Thanks to BanditC64 for the suggestion!
- **Boss tactics in the delve lists** - Click any delve in Delve Locations or Current Bountiful Delves to expand it and read each boss's mechanics: a one-line summary plus a full role-by-role breakdown. Multi-boss delves list every boss. Also suggested by BanditC64.
- **Today's boss** - Delves that field different bosses depending on the story variant now mark today's boss with a star when expanded, using a verified variant-to-boss table so it is correct from the first login.

### Improvements

- **Delve History detail** - Each run now records the boss you faced in its own column, the summary line shows the latest run's time and date, run rows are aligned into clean columns, and run dates now include the time of day.
- **Delve Locations cleanup** - Removed the search box and zone filter; sort by clicking the Name, Zone, or Tier column headers instead. Rows now expand to show boss tactics.

### Bug Fixes

- **No more 26-hour runs** - A run could occasionally be logged with a wildly inflated duration when an in-progress run saved in a previous session was resumed onto a new one. Run start times are now validated against the wall clock, and any existing run with an impossible duration is cleaned up automatically on login.
- **Steady section dividers in Delve History** - The divider lines between the Seasonal Nemesis and Midnight Delves sections no longer float over your runs as you scroll - they now scroll with their section.

## [1.9.2] - 2026-05-25

### Bug Fixes

- **Accurate time on back-to-back delves** - Running the same delve twice in a row no longer records an inflated time on the second run. Previously, when a run ended without fully resetting - for example re-entering the same delve without passing through the open world - the next run's timer could carry over the previous run's start time, logging a far longer duration than the run actually took.
- **Accurate tier on every delve** - Each completed run now records the tier you actually played. The tier is now confirmed when the run completes, fixing cases where a run could be stamped with the previous delve's tier (for example a Tier 8 run recorded as a Tier 11).

## [1.9.1] - 2026-05-25

### Improvements

- **Daily rotation accuracy** - Delve story variants and Bountiful delves rotate daily, not weekly. Wording across the addon now says "Today" instead of "this week", the Current Bountiful tab shows a daily reset countdown, and the Delve Locations tier badge, tier sort, and hover tooltip now reflect today's actual story variant (with its strategy note) instead of a static "best variant". Thanks to BanditC64 for the reports.
- **Automatic Bountiful completion** - The Current Bountiful Delves checklist and progress bar now fill in automatically from your completed runs. The manual right-click "mark complete" option has been removed, and the internal completion history is now recorded in a single consistent format.
- **Delve Locations run count** - The "(Nx)" run-count beside each delve now reflects your actual logged runs.

### Bug Fixes

- **Curio recommendations popup** - No longer overlaps the companion configuration window in the default UI layout; it now opens on whichever side of the frame has room.

## [1.9.0] - 2026-05-24

### New Features

- **Story variant on every delve** - Delve History now records the actual story variant for every completed run, not just Bountiful ones, by reading it from the delve's map POI. The Delve Locations tab also gained a "This Week's Story" column showing each delve's current rotation at a glance. Thanks to BanditC64 for the suggestion and for helping track down where the data lived.

### Bug Fixes

- **Tab row no longer overflows the window** - The main window now sizes itself to fit the full row of tabs, so the rightmost tab (Profiles) no longer spills outside the frame in the default UI font.
- **Correct tier and time on re-entered delves** - A persisted in-progress run is now only resumed after a genuine `/reload`, not whenever you re-enter a delve. Previously a leftover run could be restored onto a fresh entry, logging the old start time and tier (e.g. a fresh Tier 8 recorded as a 1h+ Tier 11). `/reload` mid-delve still preserves the timer as before.

## [1.8.0] - 2026-05-24

### New Features

- **Story variants in Delve History** - Each run in the Delve History tab now shows its story variant. Older runs display the delve's signature story, while runs you finish while a delve is Bountiful from now on record the actual variant you played that week. Thanks to BanditC64 for the suggestion!

### Improvements

- **Nullaeus rewards & mechanics refresh** - The Nullaeus tab now lists the real season rewards - the Nullaeus Domaneye helm, Dominating Victory toy, and Arcanovoid Construct mount each show their item icon with a live tooltip on hover, alongside the Ominous and Fabled Vanquisher titles and their unlock conditions. The boss ability list and the three phase intermissions (Null Zone, Gravity Well, Umbral Rage) have been corrected to match the actual encounter.

## [1.7.1] - 2026-05-22

### Maintenance

- Packaging and changelog housekeeping. No gameplay changes.

## [1.7.0] - 2026-05-21

### New Features

- **Delver's Call quest tracker** - A new Delver's Call tab tracks all 10 weekly World Tour quests across four states: Available, In Progress, Banked, and Turned In. State is auto-detected from your quest log. Bank the quests and hold them until you are near max level, then turn them all in for a leveling burst. Includes a rollup showing progress across every character on your account.
- **Nullaeus tab** - A new tab dedicated to the weekly Nullaeus Nemesis boss delve: a Beacon of Hope inventory and Undercoin tracker, the full boss mechanics list, phase transitions, and the reward track. Pin the location on your map or send it to TomTom in one click.

### Improvements

- **Sortable tier column** - The tier column header on the Delve Locations tab is now clickable to sort by tier, alongside the existing Name and Zone sorting. A small hint above the list reminds you the column headers are sortable.
- **Live bountiful story in tooltips** - Hovering a delve that is currently bountiful on the Delve Locations tab now shows the active story variant and its tier badge.

### Bug Fixes

- **Minimap right-click** - Right-clicking the minimap button now correctly opens the Options tab instead of the Delve History tab.

## [1.6.1] - 2026-05-21

### New Features

- **Tier badges on Bountiful tab** - Each row on the Current Bountiful Delves tab now shows a color-coded tier badge (S/A/B/C/D/F) based on the active story variant. The list is sorted by tier (best first), and hovering a row shows the tier letter plus a quick strategy tip for that story.
- **Best Pick banner** - A "Best Pick" line below the Bountiful tab header highlights the highest-tier non-completed delve at a glance, showing delve name, story variant, and tier.
- **Tier badges on Delve Locations tab** - A color-coded tier column (S/A/B/C/D) has been added to the Delve Locations tab, showing the best achievable tier for each delve.
- **Delve rundown tooltips** - Hovering any row on the Delve Locations tab now shows the best story name and a quick strategy note for that delve.

## [1.6.0] - 2026-05-21

### New Features

- **Companion Audio** - New section in the Options tab with three independent toggles: mute Valeera's companion voice lines, suppress her in-delve speech bubbles, and mute Dundun's voice lines. Bubble suppression uses selective per-companion hiding when the client supports it, with a fallback that disables all chat bubbles while inside a delve.
- **Curio Reminder** - A popup now appears automatically when you open the companion configuration screen inside a delve, showing which combat and utility curios to bring for your current role. Highlights your role and shows live bag counts in green (have it) or red (missing). Also accessible at any time via `/ed curios` or `/ed curios valeera`.
- **Overcharged Bountiful** - Overcharged delves are highlighted with a gold "Overcharged" prefix on the Bountiful tab. Active overcharged delves show the prefix in gold; completed ones in muted grey. The hover tooltip also reflects overcharged status.
- **What's New popup** - A brief popup now appears on first login after each feature release summarising what changed. Dismiss it once and it never shows again for that version. Re-open it any time with `/ed whatsnew`.

### Bug Fixes

- **Great Vault bar labels** - The progress bars on the Tier Guide tab now correctly label the activity types. Delves count toward "Delves / World Content", not "Mythic+ Dungeons". The previous labels were causing confusion about which activities fed which vault slot.

## [1.5.0] - 2026-05-12

**Delve history is now per-character.** Before this update every character on your account shared one history, so an alt could wrongly show your main's Gilded Stash progress (e.g. "3/4" on a level-90 alt). Each character now tracks its own.

**You don't need to do anything — and nothing is deleted.** Your existing history is preserved automatically and handed to the first character you log in after updating, so **log your main in first** and it keeps everything with zero clicks. Other characters start fresh with their own history. A new **Profiles** tab (the last tab) lets you switch between profiles, create a new one, duplicate, or delete — switching never erases data, it only changes which history that character uses. UI settings (colors, scale, alerts) stay account-wide so you still only set them once.

### New Features

- **Per-character profiles** - Delve history, completion marks, and Gilded Stash progress are now tracked **per character** instead of being shared account-wide. Previously every character on your account read the same history, so an alt could show "3/4 Gilded Stash" from your main's runs. A new **Profiles** tab lets you see the active profile, switch profiles, create a fresh empty one, duplicate the current one, or delete an unused one. UI settings (accent color, scale, minimap button, alert toggles, the Trovehunter reminder) intentionally stay account-wide so you only configure them once.
- **Non-destructive migration** - Your existing history is **never deleted**. On first login after updating, the old account-wide data is moved intact into a profile named "Original", and the first character you log in claims it automatically (log in your main first and it keeps everything with zero clicks). Every other character starts with its own fresh profile. If an alt ever inherits the wrong data, just switch its profile on the Profiles tab - nothing is lost.

### Internal

- `E.db` is now a transparent proxy: profile-scoped keys (`delveHistory`, `manualComplete`, `activeRun`) redirect to the active profile while everything else maps to the account-wide SavedVariables table. All existing call sites are unchanged - the per-character behavior is contained in one place.
- `/ed reset` and the "Reset All Settings" button now reset **only account-wide settings**. They no longer touch profiles, so a settings reset can never wipe delve history.

## [1.4.10] - 2026-05-12

### Bug Fixes

- **Tier detection regression from 1.4.9** - The ObjectiveTracker scrape in `AutoDetectDelveTier` was modified in 1.4.9 to fix a misfire where the player's lives counter was being read as the tier. The change accidentally broke tier detection entirely: Methods 1 and 2 (`GetInstanceInfo().difficultyName` and `C_Scenario.GetInfo().scenarioName`) both just return `"Delves"` in Midnight with no tier number, leaving the modified Method 3 with nothing useful to fall back on. Every run was logged as `tier=0`, breaking the Delve History tier display and zeroing out the Gilded Stash counter (which requires `tier >= 11`). Restored Method 3 to its exact pre-1.4.9 behavior - the original implementation's first-match heuristic is imperfect but reliably captures tier in the vast majority of runs, which is far better than logging tier=0 across the board.

## [1.4.9] - 2026-05-12

### Bug Fixes

- **Gilded Stash counter undercount** - Fixed the root cause where Tier 11 Bountiful runs sometimes failed to register toward the Gilded Stash counter. The `wasBountiful` flag was being stamped `false` on runs entered before the AreaPOI cache was loaded for that delve's zone. The bountiful snapshot now retries on every `SCENARIO_UPDATE` and at `SCENARIO_COMPLETED`, locking to `true` the moment the data becomes available. Captured tier now also persists to SavedVariables so `/reload` mid-delve no longer loses it. Combined with a new one-time auto-repair pass at login, this week's misflagged runs heal silently - your Gilded Stash counter will correct itself the next time you log in. Thanks to everyone who reported the undercount.
- **Trovehunter's Bounty popup not firing reliably** - The popup added in v1.4.8 had several races with delve entry: it depended on `SCENARIO_UPDATE` firing (sparse in quiet delves, silent after `/reload`), its `Show()` was called too early during the loading-screen-clear window so the frame was sometimes shown-but-invisible, and tier detection was occasionally matching the lives counter as "Tier 3". Rewrote the firing logic with a 1Hz heartbeat that runs for 30 seconds after delve entry, a 2-second deferred Show that lets the UI settle, a live game-state re-check at fire time that prevents the popup from appearing as you exit a delve, and a 60-second elapsed guard. Also dropped the tier-8+ requirement - Trovehunter maps work in any Tier 4+ delve and nobody with a map is running sub-T8 anyway.

### Improvements

- **Delve History - bountiful indicator** - Each run row now shows a gold **B** to its left when the run was flagged bountiful. Previously there was no way to see which runs counted toward the Gilded Stash without running diagnostic commands. If a run ever does fail to flag correctly going forward, you'll spot it immediately on this tab.

### Internal

- AreaPOI cache for every delve zone is pre-warmed at `PLAYER_LOGIN` via `C_AreaPoiInfo.GetAreaPOIForMap`, eliminating the cold-cache race that caused `wasBountiful=false` for players teleporting directly into a delve from an unrelated zone.
- New helper `E:AutoRepairBountifulHistory` cross-checks this week's recorded runs against the live bountiful list and corrects any `wasBountiful=false` flag that should have been `true`. Runs once per session after the first `RefreshBountifulData`. Past weeks' runs are unrecoverable (the live bountiful list rotates weekly) and irrelevant anyway since the Gilded Stash counter only counts the current week.
- Removed the standalone-number fallback in `AutoDetectDelveTier`'s ObjectiveTracker scrape - it was misidentifying the player's "lives remaining" counter as a tier value. Only the explicit `"Tier N"` pattern is now accepted.

## [1.4.8] - 2026-05-10

### New Features

- **Trovehunter's Bounty Reminder** — A small popup now appears when you enter a Tier 8+ Bountiful Delve while you have an unused Trovehunter's Bounty Map in your bags and the bounty buff is not already active. Includes a dismiss button, a "Don't show this reminder again" checkbox (which disables the popup globally), and the actual in-game item icon so you know what to look for. Toggle is in **Options > General** and is enabled by default. Thanks to **herky4life** for the suggestion!

### Improvements

- **Section spacing across the last four tabs** — Added significant breathing room between every section on the **Tier Guide**, **Shard Tracker**, **Delve History**, and **Options** tabs. Sections were previously cramped against each other; the new uniform spacing makes everything much easier to scan.
- **Options - General layout** — The Trovehunter reminder toggle is anchored to the right side of the General section (inline with the Default Tab readout) so it doesn't add another row to the General block.

## [1.4.7] - 2026-05-08

### Internal

- Minor TOC header cleanup.

## [1.4.6] - 2026-05-08

### Internal

- Updated `## Interface` to `120001, 120005, 120007`.

## [1.4.5] - 2026-05-06

### Internal

- Removed stray `.claude/` Claude Code settings folder from packaged release. The folder is now ignored by both `.gitignore` and the BigWigsMods packager (`.pkgmeta`), so it will not appear in future release zips.

## [1.4.4] - 2026-05-06

### Bug Fixes

- **Coffer Shard WQ — Empty State Spacing** — "No Coffer Key Shard WQs found" message now renders with proper breathing room below the column header divider when no shard world quests are active. Previously the text was anchored 2px above the divider line, causing it to visually smash against it.

### Improvements

- **Great Vault Progress — Corrected Bar Labels** — "Delves / Dungeons" bar (wired to `Activities`) has been renamed to "Mythic+ Dungeons" to accurately reflect that `Enum.WeeklyRewardChestThresholdType.Activities` only tracks Mythic+/Heroic+ dungeon runs. "World Content" bar has been renamed to "Delves / World Content" since `Enum.WeeklyRewardChestThresholdType.World` is where delve completions (and world quests) are tracked by the API. Also corrected the hardcoded `max` for the World row from 3 to 8.

## [1.4.3] - 2026-05-03

### Bug Fixes

- **Delve Duration Tracking** — Run timer now survives `/reload` and brief disconnects. `startTime` is persisted to `E.db.activeRun` (SavedVariables) at delve entry and restored when re-entering the same zone, so the elapsed time continues from the original start rather than resetting to zero. Full client restarts still reset the timer (by design — `GetTime()` resets to near-zero on relaunch, making the saved timestamp unrecoverable).
- **Delve Duration Formatter** — Fixed display of runs lasting 1 hour or longer. Previously the formatter would stop at minutes; runs >= 60 minutes now display correctly as `Xh Ym Zs`.

### Improvements

- **Delve History tab** — Added a small note at the bottom of the tab clarifying that `/reload` is safe for the run timer, but closing the WoW client during a delve will reset that run's timer.

## [1.4.2] - 2026-04-29

### Bug Fixes

- **Gilded Stash Progress** — Fixed regression where Bountiful T11+ runs were not being counted unless the Current Bountiful Delves tab had been opened during the play session. The bountiful lookup table (`E.currentBountifulNames`) was only refreshed on `AreaPoisUpdated` events when Tab 2 was visible, so runs entered with a stale/empty table got stamped `wasBountiful = false`.

### Internal

- `AreaPoisUpdated` callback now always refreshes bountiful data; only the UI redraw remains gated on tab visibility.
- New public hook `E:RefreshBountifulData(force)` exposed so other modules can force a refresh.
- `BeginDelveRun` now forces a bountiful-data refresh before snapshotting `wasBountiful`, guaranteeing the lookup is current at delve entry regardless of which tab has been opened.

## [1.4.1] - 2026-04-28

### Bug Fixes

- **Gilded Stash Progress** — Bar now correctly tracks Bountiful Tier 11+ delve runs across the week. Previous version compared logged delve names against the live Bountiful POI list, which fails because completed bountifuls drop off the list mid-week. Bountiful status is now snapshotted at delve entry and persisted into each run record (`wasBountiful` flag on `recentRuns` entries).
- **Delve Locations — All Zones dropdown** — Click handler reworked to use `GLOBAL_MOUSE_DOWN` for reliable open/close behavior. Previously the dropdown could fail to open or close on click.

### Improvements

- **Current Bountiful Delves tab** — Removed red tint on row hover/selection. Hovering a delve row no longer changes its background color.
- **Delve History tab** — Removed red tint on row hover. Lower section dividers (Nemesis / Midnight) now match the width of the top header divider for visual consistency.
- **Delve Locations tab** — Removed red tint on row hover. Upper grey divider repositioned and thickness now matches the lower divider.
- **Shard Tracker tab** — "Weekly Shard Sources" header divider switched from accent-colored to grey, with added vertical spacing below for breathing room.
- **Bountiful Delve tooltips** — Tooltip now anchors to the right of the TomTom waypoint button instead of following the cursor, so it no longer covers the row while reading.

### Internal

- Run logging now persists `wasBountiful` per recent-run entry to support accurate weekly Gilded Stash tracking.

## [1.4.0] - 2026-04-27

### UI Overhaul (global)

- **Buttons** — All buttons across the entire addon are now hardcoded to a red (`#6D0501`) background with yellow (`#EBB706`) text. Buttons are no longer tied to the accent color profile. Greyed-out buttons (e.g., shard cap reached) retain their grey state.
- **Headers** — All section headers across all 6 tabs have been increased to a uniform larger font size (`E.HEADER_FONT_SIZE = 20`).
- **Title** — "Everything Delves" title is now font size 25 and centered, with balanced spacing above and below.

### Delve Locations Tab

- Removed scrollbar.
- Removed "Showing 10 of 10" text.
- Removed "(asc)" / "(desc)" indicators from the "Delve Name" header.
- Added permanent grey column-header lines above and below "Delve Name / Zone / Pin / TomTom".
- Added 20 px spacing below the All Zones / Search bar row.
- Fixed column header alignment so Pin and TomTom share the same baseline as Zone.
- Fixed All Zones dropdown — option clicks were being intercepted by the click-outside overlay; the overlay now sits below the menu's strata so zone selections register correctly.

### Current Bountiful Delves Tab

- Added accent-color line under the Great Vault / Start LFG buttons (full UI width).
- "This Week's Bountiful Delves" styled as a header with a permanent grey line above and below it.
- Added spacing to reduce crowding between the action buttons and the bountiful list.
- Removed the red background tint from delve rows; rows now use the same neutral tint as the Delve Locations tab.

### Tier Guide Tab

- Removed the yellow accent line above "Great Vault Progress".
- World Content progress bar now follows the accent color profile (was hardcoded gold when full).
- All red status text changed to hardcoded yellow (`#EBB706`) — "Quest available", "No Beacon of Hope in bags or bank", "Insufficient Undercoins", "0 / 4 — no T11 runs yet this week", and the undercoin count.
- Moved the **Valeera — Companion** button to the right side of the Seasonal Nemesis section, enlarged 2× (now 280×40 with 14 pt label), with a matching 32×32 circular portrait icon. The Nullaeus nemesis icon also receives the same circular alpha mask so the two read as a matched pair.

### Shard Tracker Tab

- Added accent-color line under the "Weekly Shard Sources" header.
- Added permanent grey column-header lines above and below the Coffer Shard WQ data table.
- Added breathing room below the bottom column-header line so the Pin / TomTom buttons no longer touch the line.
- Normalized grey line thickness across the WQ section.
- Cap-state restore now uses the hardcoded button border / label colour to match the new button system.

### Delve History Tab

- Aligned "Seasonal Nemesis" and "Midnight Delves" headers to match "Delve History" left alignment.
- Extended all divider lines to full UI width.
- "Seasonal Nemesis" header now follows the accent color profile.
- Added a separator line under the Seasonal Nemesis body text (between Nemesis and Midnight sections), plus a third divider directly below the Midnight Delves header.
- Normalized line thickness across all dividers.

### Options Tab

- Section headers ("General", "Display", "Alerts & Tracking") increased to match the uniform header size.

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
