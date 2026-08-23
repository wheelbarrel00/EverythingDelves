-- Locales/enUS.lua
-- Default locale + source-of-truth phrase list for Everything Delves.
--
-- E.L["English string"] returns the localized text for the player's client
-- (per GetLocale()), or the English string itself when no translation exists
-- (the metatable __index below). So EVERY wrapped string is safe to use even
-- with zero translations loaded. Untranslated text simply renders in English.
--
-- Everything Delves keeps its namespace on the global EverythingDelves table
-- rather than the private addon vararg, so this file builds the table on `ns`
-- and EverythingDelves.lua bridges it across as E.L. The `ns` spelling is not
-- cosmetic: the EverythingLocales tooling reads the header up to and including
-- the `local L = ns.L` line verbatim, and rewrites everything below it.
--
-- Translations are bundled directly in the other Locales/*.lua files as
-- L["key"] = "value" lines, NOT fetched through an @localization@ packager
-- token. That token fails the CurseForge build with errorCode 1002 on a project
-- without localization enabled, so it must never be added here.
--
-- Pattern: the English string IS the key (no semantic IDs). Keep keys in sync
-- with the code. If you reword an English string, update it here too or the
-- existing translation orphans (and the new text falls back to English).
--
-- Delve, boss, zone, story-variant, curio and achievement names are deliberately
-- NOT wrapped. They double as lookup keys against Blizzard's own localized
-- strings, and translating them here would break every match.
--
-- Core/Changelog.lua, UI/WhatsNew.lua's ENTRIES and the /ed diagnostic output are
-- also deliberately NOT wrapped. Changelog text churns every release, and
-- diagnostics have to read the same in every bug report.
--
-- GENERATED FILE: the phrase list is a pure function of the L[...] usages in the
-- code. Do not hand-edit. It is rebuilt by scan.py in the EverythingLocales repo,
-- which also regenerates the translation files from the shared store.


local _, ns = ...

ns.L = setmetatable({}, { __index = function(_, k) return k end })
local L = ns.L

-- UI/MainFrame.lua
L["Join our Discord!"] = true
L["Join our Discord"] = true
L["Click to copy the invite link."] = true
L["Coffer Key Shards:"] = true
L["owned / earnable this week"] = true
L["Bountiful Keys:"] = true
L["Undercoins:"] = true
L["Active Bountiful:"] = true
L["Weekly Reset:"] = true
L["%dd %dh %dm"] = true
L["%dd %dh"] = true
L["Keys: %s%d|r  Shards: %s%s|r  Reset: %s%s|r"] = true
L["Left-click: Toggle window"] = true
L["Right-click: Options"] = true
L["Drag: Reposition"] = true

-- UI/TabDelveLocations.lua
L["Compact layout with easy boss access. NPC debuffs boost damage — the bomb DoT scales with tier and trivializes the clear."] = true
L["Glide or use a parasol toy to reach the boss platform quickly. Kite dinos and kick spores back to break their shields."] = true
L["Straightforward paths to the boss. Kill Unstable Aberrations before moving — they leash and give chase."] = true
L["Take the staircase down for the fastest route. Kill enemies instead of healing allies for quicker progress."] = true
L["Straight routes with easy kill objectives. Use portals in Core of the Problem to shortcut around the map."] = true
L["Pull levers to deactivate traps before advancing — limits large pulls. Party Crasher is the most direct variant."] = true
L["Open layout adds traverse time even when mounted. Toadly Unbecoming: decurse frogs to spawn the boss."] = true
L["Large unwalkable map — slow regardless of story. Use the Eye of Antenorian buff whenever it's available."] = true
L["Compact and mountable but long RP transitions and non-combat objectives in all three variants hurt efficiency."] = true
L["Enormous mountable map with required secondary objectives. Avoid if faster options are bountiful today."] = true
L["Note"] = true
L["TomTom Waypoint"] = true
L["Add an arrow waypoint via TomTom."] = true
L["TomTom Not Installed"] = true
L["Install the TomTom addon to use arrow waypoints."] = true
L["* Bountiful Delve today!"] = true
L["Zone:"] = true
L["Today's Story:"] = true
L["%s Tier"] = true
L["Your average clear:"] = true
L["Estimated clear:"] = true
L["Run it once to replace this with your own time."] = true
L["Click to hide boss tactics"] = true
L["Click to show boss tactics"] = true
L["Set All Waypoints"] = true
L["TomTom is required for bulk waypoints."] = true
L["Added %d TomTom waypoints."] = true
L["Adds TomTom waypoints for every delve in the list."] = true
L["Requires TomTom addon."] = true
L["Quickest:"] = true
L["Best value:"] = true
L["Click a delve for boss tactics  \226\128\148  click headers to sort"] = true
L["Delve Name"] = true
L["Zone"] = true
L["Tier"] = true
L["Pin"] = true
L["Today's Story"] = true
L["Speed"] = true
L["Sort by Speed"] = true
L["Quickest clear first. Shows your own average time once you've run a delve, or a tier- and gear-based estimate (marked *) until then."] = true
L["(today's boss)"] = true

-- UI/TabCurrentBountiful.lua
L["Bomb DoT scales with tier — keep it rolling and the clear is trivial."] = true
L["Straight shot to boss. Kill Unstable Aberrations before moving on."] = true
L["Kite dinos and kick spores back to break their shields for bonus damage."] = true
L["Head down the staircase; kill enemies (not heal allies) for the fastest route."] = true
L["Scattered powerful items help, but it can't match Invasive Glow."] = true
L["Use portals to shortcut around the map. Kill enemies and collect orbs."] = true
L["Revelation mechanic requires revealing many NPCs, adding significant time."] = true
L["Hit levers to disable traps while defeating 4 Twilight Summoners."] = true
L["Large crystal collection loop adds time compared to Ogre Powered."] = true
L["Decurse frogs to spawn the boss. Open layout adds traverse time even when mounted."] = true
L["Same quick route as Sporasaur Special but extra objectives slow it down."] = true
L["Click Lightbloom crates and activate security. Displacement Portal clones help in combat."] = true
L["Teleported inside — must rescue hostages on the way back to the entrance."] = true
L["Take the bird north. Avoid the captured loa's lightning — it hits hard."] = true
L["Large unwalkable map. Defeat void foci and elites with the Eye of Antenorian buff."] = true
L["Inspecting every leyline adds a lot of time."] = true
L["Same quick pathing as Sporasaur but extra objectives add considerable time."] = true
L["Flying to collect Singularity Coils breaks the route significantly."] = true
L["Use Evasive Elixir before the patrolling loa attacks to avoid a big stun."] = true
L["Navigate south freeing furbolgs. Haunted weapons deal decent bonus damage."] = true
L["Enormous mountable map with required secondary objectives in all three variants."] = true
L["Defeat two named enemies then collect mold samples from Moldering Fighters."] = true
L["Activating sentinels is slow with no direct path to the boss."] = true
L["Destroying void portals makes for one of the slowest clears."] = true
L["Repositioning mirrors to reflect light is tedious. Mind positioning to avoid debuffs."] = true
L["Collecting 30 supplies from enemies and the floor is very slow."] = true
L["Free caged wildlife; use worm bait on Void Researchers to spawn the boss."] = true
L["Use the Galvanic Rifle on mana barrels and free 8 prisoners from Mana Siphoners."] = true
L["Free fighters and defend barricades against Thornmaws using nearby barrels."] = true
L["Taunt the crowd, click dirt piles, defeat spawns carefully to avoid being overwhelmed."] = true
L["Ally with the Tortollan Tormunda to rescue the elders the Djaradin captured, and recover their relics."] = true
L["Search the bone piles and take hearts from the Gnarldor Djaradin to summon the Osseous Amalgamation."] = true
L["Rescue the turtles and the supplies the Djaradin stole, then send the siege-trained turtles in as tanks."] = true
L["An arena gauntlet - clear the floor, then the champions, then Drakta."] = true
L["Ghostly Headball - collect skulls from your kills and kick them at the pillars to score."] = true
L["Rescue the small animals caught in the middle of the gladiator fights."] = true
L["Escort Marla and clear the Children of Ula'tek poison contamination. Ends on Disciple of Vash'nik."] = true
L["Divert the shields, then kill the basilisks channeling energy to the boss."] = true
L["Brew an antidote with Sir Finley - cleanse poison patches and heal students. No final boss."] = true
L["Loot Fungal Pharmacon from around the pit and break the four pillars the Children of Ula'tek burrow through."] = true
L["Stop the Children of Ula'tek summoning slimes, using Fungal Pharmacon and dodging the caustic waves."] = true
L["Hunt snake relics through the crypts, clearing poison patches with Fungal Pharmacon."] = true
L["Sabotage the summoning - kick summoners into the abyss and spike the cauldrons with the wrong ingredients."] = true
L["Destroy the Children of Ula'tek eggs nesting in the tunnels using the Venom-Clogged Leyline pylons."] = true
L["Resets in %dh %dm"] = true
L["Reset timer unavailable"] = true
L["Best Pick:"] = true
L["New Bountiful Delves are available today! Open Everything Delves to see them."] = true
L["Overcharged"] = true
L["(Normal version available)"] = true
L["No bountiful delves are active right now.\nThey rotate daily - check back after reset."] = true
L["Loading bountiful delve data...\nClick Refresh if this does not clear."] = true
L["Keys from Shards:"] = true
L["Journey:"] = true
L["Bountiful Reset:"] = true
L["Session Completions:"] = true
L["(%d / %d this week)"] = true
L["Stage %d"] = true
L["Bountiful Delves Completed"] = true
L["Great Vault"] = true
L["Great Vault UI could not be loaded."] = true
L["Open the Great Vault reward panel."] = true
L["Start LFG"] = true
L["LFG UI could not be loaded."] = true
L["Cannot list while in a raid group."] = true
L["Only the group leader can list."] = true
L["Open the Group Finder to list a Delve group."] = true
L["Today's Bountiful Delves"] = true
L["Delves unlock at Level 68"] = true
L["Refresh"] = true
L["Re-query bountiful delve data and currency values."] = true

-- UI/TabTierGuide.lua
L["Rec. Gear iLvl"] = true
L["Bountiful Loot"] = true
L["Entry-level delves. Good for gearing up alts."] = true
L["Mid-tier delves. Solid upgrades for mains early in the season."] = true
L["Endgame delves. Best loot, toughest challenge."] = true
L["Recommended iLvl:"] = true
L["Bountiful Loot:"] = true
L["Great Vault:"] = true
L["Tier %d"] = true
L["Your Equipped iLvl:"] = true
L["Recommended Tier: %s - running this tier gives you the best gear upgrade chance"] = true
L["Great Vault Progress"] = true
L["Mythic+ Dungeons"] = true
L["Delves / World Content"] = true
L["Rewards are claimable after the weekly reset"] = true
L["Great Vault data not available yet - enter a dungeon, raid or delve first"] = true
L["Reward Slot %d"] = true
L["Item level %d"] = true
L["No reward unlocked yet"] = true
L["Unlocked - claim after the weekly reset"] = true
L["%d / %d  (%d more)"] = true
L["Next slot in %d more"] = true
L["All slots unlocked"] = true
L["Delver's Journey"] = true
L["Your progress through this season's Delves track."] = true
L["Each level unlocks a milestone reward - hover an icon to see it."] = true
L["Delver's Journey data not available yet - open the Journeys panel once to sync."] = true
L["Level %d"] = true
L["Complete - all milestones earned!"] = true
L["(earned)"] = true
L["(locked)"] = true
L["Companion"] = true
L["Companion UI not available - visit Valeera at Delvers HQ."] = true
L["Open Valeera's companion menu to manage her role and curios."] = true
L["Companion level unavailable."] = true
L["Level %d - Max"] = true
L["Trovehunter's Bounty"] = true
L["Bounty looted and used this week. [Done]"] = true
L["Bounty looted - not yet used this week."] = true
L["You can still get a Trovehunter's Bounty this week!"] = true
L["You have a Trovehunter's Bounty in your bag - don't forget to use it!"] = true
L["Your Trovehunter's Bounty is active. Happy looting!"] = true
L["Gilded Stash Progress"] = true
L["Gilded Stash"] = true
L["Complete 4 Tier 11 Bountiful Delves this week\nto earn a Gilded Stash reward."] = true
L["[Done] Gilded Stash earned! (%d / %d)"] = true
L["All Gilded Stashes looted this week."] = true
L["All T11 Bountiful Delve runs complete this week."] = true
L["%d / %d Gilded Stashes looted this week"] = true
L["%d / %d T11 runs this week"] = true
L["%d more to go."] = true
L["Exact count, synced in-delve."] = true
L["Estimate - enter a delve to sync the exact count."] = true
L["0 / %d - no Gilded Stashes looted yet this week"] = true
L["0 / %d - no T11 runs yet this week"] = true
L["Run 4 Tier 11 Bountiful Delves for the Gilded Stash."] = true
L["Midnight Faction Renown"] = true
L["Max (%d / %d)"] = true

-- UI/TabNullaeus.lua
L["The Nemesis Delve"] = true
L["Season 2 Nemesis  \226\128\148  two difficulties, Tier \"?\" and Tier \"??\""] = true
L["Set Waypoint"] = true
L["Pin Venomfall Deeps on your map."] = true
L["Add a TomTom arrow to Venomfall Deeps."] = true
L["Overview"] = true
L["Venomfall Deeps is open, but his lair has to be unlocked first."] = true
L["Clear a Tier 7 delve with at least one life left to unlock the lower difficulty, or a Tier 10 clear for the harder one. The clear does not have to be in Venomfall Deeps. Azta'rec can also be met the other way listed below."] = true
L["Azta'rec is the Midnight Season 2 Nemesis, and you can meet him two separate ways:"] = true
L["Inside any delve"] = true
L["he can appear at random in any Tier 8 or higher delve, and can also be summoned on the spot with a Scalebound Herald's Flute."] = true
L["the dedicated Nemesis delve on The Coiled Isle. This is the full fight \226\128\148 the mechanics and intermissions below cover it, and it is what awards the achievements, mount, and titles."] = true
L["Tier \"?\""] = true
L["the easier of the two. Recommended item level 290."] = true
L["Tier \"??\""] = true
L["everything hits far harder, and he summons an Echo of himself during every intermission. This is the one the title and the Fabled title require."] = true
L["The entrance is on the north side of The Coiled Isle, inside one of the snake buildings (use Pin or TomTom above). Your first kill awards a bonus 30 Hero Mistcrests, which do not count toward the season maximum."] = true
L["The encounter is deliberately punishing and expects deaths while you learn it, especially at lower item levels."] = true
L["Beacon of Hope"] = true
L["Use a Beacon of Hope inside a delve to call the Nemesis rather than waiting on his random spawn. Season 2 also introduces the Scalebound Herald's Flute, which summons Azta'rec inside the delve \226\128\148 its cost and vendor are not tracked here yet. The Undercoin bar tracks the Beacon, not the Flute."] = true
L["Boss Mechanics"] = true
L["The fight splits into a main phase and an intermission at 90, 60 and 30 percent health. Two casts decide whether you live:"] = true
L["%s (interrupt) and %s (dispel). Pull him to the edge of the room so the Noxious Bile puddles land away from the middle."] = true
L["Companion: as DPS or tank, set Valeera to Healer and she dispels Void Toxin while you cover the interrupt; as a healer, set her to DPS so she interrupts Soul Extinction and you dispel instead."] = true
L["Interrupt - Top Priority"] = true
L["An interruptible cast that deals lethal damage if it completes. Kick it every single time. Valeera interrupts it for you when her role is set to DPS, which is the reason a healer should run her that way."] = true
L["Dispel"] = true
L["A dispellable magic debuff that ticks for heavy damage and cuts the damage you deal by 40 percent. Remove it as soon as it lands. Valeera dispels it for you when her role is set to Healer."] = true
L["Frontal"] = true
L["A frontal cone that hits hard if you stay in it, and it leaves venom puddles behind on the floor. Aim it toward the outside of the room and step out once he has aimed it, so the middle of the arena stays clean for the intermission."] = true
L["Keep Moving"] = true
L["Summons venom waves that crawl slowly across the arena and deal heavy damage to anyone they catch. They are slow enough to walk away from, so keep moving rather than reacting late."] = true
L["Tank Hit"] = true
L["Only used while you are in a tank specialization, and only a small amount of physical damage. Nothing to plan around."] = true
L["Intermissions"] = true
L["At 90, 60 and 30 percent health Azta'rec walks to the centre and channels Sermon of Ula'tek, taking 99 percent reduced damage for the whole intermission. The room splits into quarters: three flood with venom and one is safe. It is a memory test, not a damage test \226\128\148 place four world markers on the quadrants before you pull and call the safe spot by marker."] = true
L["90 / 60 / 30 percent HP"] = true
L["The same intermission runs at all three health thresholds, one step longer each time."] = true
L["Shown pattern"] = true
L["He marks one safe quarter and covers the other three, with an animation showing which is which. You get a few seconds to run to the safe quarter. Stand close to him so every quarter is within reach."] = true
L["Repeated pattern"] = true
L["He then replays the same sequence with no animation at all. You have to remember the order the safe zones came in - this is what kills people, not the damage."] = true
L["Length"] = true
L["On Tier \"?\" the sequence runs 3 times, then 4, then 5 across the three intermissions. On Tier \"??\" it runs 5, then 6, then 7."] = true
L["Lingering venom"] = true
L["Keep the middle of the room clear of Noxious Bile puddles during the main phase, or you will be dodging your own leftovers while running the pattern."] = true
L["Tier \"??\" only"] = true
L["On the harder difficulty he also summons an Echo of himself during the intermission."] = true
L["It does not have much health, but it uses every ability from his main phase - including Soul Extinction, which will one-shot you if it lands. Crowd control it and kill it fast; leaving it up makes the whole intermission far harder."] = true
L["Cover the Echo's casts"] = true
L["If Valeera is set to Healer, you must interrupt the Echo yourself. If she is set to DPS she covers the interrupt, but then you have to dispel Void Toxin."] = true
L["Extra venom sets"] = true
L["Two additional venom coverings are added, so the pattern you must memorise reaches five safe zones."] = true
L["Final push"] = true
L["After the 30 percent intermission there are no more, and the main phase runs until he dies. Save Bloodlust or Heroism for after the last intermission on Tier \"?\", or during the last intermission on Tier \"??\" to kill the Echo faster."] = true
L["Before you pull"] = true
L["Drop a world marker on each of the four quadrants, then call the safe zones by marker during the Sermon. Remembering \"blue, yellow, purple\" is far easier than remembering positions on a venom-covered floor."] = true
L["Companion & Loadout"] = true
L["Only two mechanics need covering, and Valeera can take exactly one of them. Give her whichever you cannot cover yourself:"] = true
L["DPS / Tank"] = true
L["run Valeera as Healer \226\128\148 she dispels Void Toxin, and you interrupt Soul Extinction yourself."] = true
L["Healer"] = true
L["run Valeera as DPS \226\128\148 she interrupts Soul Extinction, and you dispel Void Toxin yourself."] = true
L["Curios"] = true
L["Valeera has a third slot this season: Combat, Utility and a new Poisons slot. The picks do not change with your own role."] = true
L["Poison"] = true
L["Frosthearth Venom \226\128\148 cuts enemy attack and cast speed by 20 percent, which buys time on both Soul Extinction and the Void Toxin dispel."] = true
L["Combat"] = true
L["Corrosive Bilespear for straight damage. Ouroboric Curse is the alternative, but much of this delve one-shots, so its effect is hard to keep procced."] = true
L["Utility"] = true
L["Soul-Cracking Dreamcatcher \226\128\148 because you interrupt so often it is close to permanent uptime, and the debuff sits on the boss, so Valeera's own interrupts keep it up even while you play healer. 30 percent damage at Rank 3 or higher."] = true
L["Consumables"] = true
L["carry health and DPS potions, and hold Bloodlust or Heroism for after the final intermission on Tier \"?\", or for killing the Echo during the final intermission on Tier \"??\"."] = true
L["Rewards"] = true
L["Collectibles for defeating Azta'rec this season (item icons appear once their IDs are confirmed):"] = true
L["Cloak Transmog"] = true
L["Defeat Azta'rec on either difficulty during Season 2 (My Venomous Nemesis, a Feat of Strength)."] = true
L["Your first kill also grants 30 Hero Mistcrests, which do not count toward the season maximum."] = true
L["Toy"] = true
L["Reward from the Fangs for the Memories quest."] = true
L["Mount"] = true
L["Solo Azta'rec (Let Me Solo Him: Azta'rec)."] = true
L["Title"] = true
L["Defeat Azta'rec on Tier \"??\" (Purging the Poison)."] = true
L["Defeat him in his lair on Tier \"??\" with no other players in your party, within the first week of Season 2 (Fabled Let Me Solo Him: Azta'rec)."] = true
L["Fangs for the Memories \226\128\148 the one-time seasonal quest that awards the Corrosive Victory toy. Live tracking starts once its quest ID is confirmed."] = true
L["[Done] Fangs for the Memories complete \226\128\148 Corrosive Victory earned."] = true
L["Fangs for the Memories in progress \226\128\148 check your quest log."] = true
L["Fangs for the Memories available"] = true
L["the one-time seasonal quest; defeat Azta'rec to earn it."] = true
L["[Ready] Beacon of Hope in inventory (%d)"] = true
L["go get that Nemesis!"] = true
L["No Beacon of Hope in bags or bank."] = true
L["Insufficient Undercoins."] = true
L["You have enough Undercoins to purchase a Beacon!"] = true

-- UI/TabShardTracker.lua
L["Currency Overview"] = true
L["Shards to Next Key"] = true
L["Weekly Shard Cap"] = true
L["Crests"] = true
L["On Hand"] = true
L["How many of this crest you currently have available to spend on gear upgrades."] = true
L["Season Max"] = true
L["The most of this crest you're allowed to earn this season - the seasonal earning cap."] = true
L["Shows \"Uncapped\" when Blizzard has lifted the cap for the rest of the season."] = true
L["Season Total"] = true
L["How many of this crest you've earned in total this season - including any you've already spent on upgrades."] = true
L["Usually higher than \"On Hand\" for that reason."] = true
L["Crest"] = true
L["Weekly Shard Sources"] = true
L["Source"] = true
L["Per"] = true
L["Weekly Cap"] = true
L["Status"] = true
L["* Value unconfirmed - may differ in game"] = true
L["Session Tracker"] = true
L["Tracking starts when you first open this tab, not at login. Resets on /reload."] = true
L["Special Assignments"] = true
L["Weekly Delve Quests"] = true
L["Coffer Shard World Quests"] = true
L["Refresh WQs"] = true
L["Force rescan all Midnight zones for\nCoffer Key Shard world quests."] = true
L["WQs rewarding Coffer Key Shards. Rewards rotate - click Refresh to update."] = true
L["Weekly shard cap reached — shards will not be awarded until reset."] = true
L["Quest"] = true
L["Shards"] = true
L["No Coffer Key Shard WQs found. Click Refresh to rescan."] = true
L["Tip: Open your World Map to each Midnight zone first to load quest data."] = true
L["* Tip: Visit zone maps to load WQ data before refreshing."] = true
L["Unknown Quest"] = true
L["Zone %d"] = true
L["|cFF999999Shards earned: |r|cFFFFD700+%s|r"] = true
L["|cFF999999Shards earned: |r|cFFFF3333%s|r"] = true
L["|cFF999999Keys earned: |r|cFFFFD700+%d|r"] = true
L["|cFF999999Keys earned: |r|cFFFF3333%d|r"] = true
L["|cFF999999Session time: |r|cFFE0E0E0%s|r"] = true
L["|cFF999999Rate: ~|r|cFFFFD700%s shards/hour|r"] = true
L["Progress toward next key - %s shards remaining"] = true
L["Weekly shard cap - %s shards remaining this week"] = true
L["Weekly shard cap data unavailable"] = true
L["Uncapped"] = true
L["Trackable"] = true
L["Manual"] = true
L["Weekly cap:"] = true
L["%s shards/week"] = true
L["SA: %s - Locked"] = true
L["[Done] SA: %s"] = true
L["SA: %s - active"] = true
L["SA: %s"] = true
L["%s / %d completed"] = true
L["%d active"] = true
L["[Done] %s - completed"] = true
L["%s - not yet done"] = true
L["(!) Low shards!"] = true
L["You have %s shards, below your %s threshold."] = true
L["%s active"] = true
L["A Special Assignment is now available! Check the Shard Tracker tab."] = true

-- UI/TabDelveHistory.lua
L["Delve History"] = true
L["Note: Closing the WoW client during a delve will reset that run's timer. /reload is fine."] = true
L["Clear History"] = true
L["Clear Delve History"] = true
L["Erase all recorded delve runs and lifetime stats"] = true
L["This cannot be undone."] = true
L["Runs kept per delve:"] = true
L["History kept per delve"] = true
L["How many recent runs to store for each delve (newest first)."] = true
L["Default 20, up to %d. Raising it keeps more history from now on; runs already trimmed can't be recovered. Lowering it trims a delve's oldest runs the next time you run it."] = true
L["Seasonal Nemesis"] = true
L["No nemesis delve runs recorded yet."] = true
L["Midnight Delves"] = true
L["No Midnight delve runs recorded yet. Complete a delve to start tracking!"] = true
L["Run Note"] = true
L["Save"] = true
L["Cancel"] = true
L["Delete"] = true
L["Delete Note"] = true
L["Removes this run's note."] = true
L["Add a Note"] = true
L["Click to attach a free-form note to this run."] = true
L["Delete this %s run?\n\n%s\n\nIts time, deaths, and key usage are removed from the delve's lifetime stats. This cannot be undone."] = true
L["Delete Run"] = true
L["Permanently remove this run and its\ncontribution to lifetime stats."] = true
L["Bountiful"] = true
L["This run was in a Bountiful Delve."] = true
L["Runs:"] = true
L["Best Tier:"] = true
L["Avg:"] = true
L["Fastest:"] = true
L["Latest: %s on %s"] = true
L["Keys used:"] = true
L["Total Deaths:"] = true
L["%sTotal Runs:%s %s%d%s   %s||%s   %sTotal Deaths:%s %s%d%s   %s||%s   %sTotal Time:%s %s%s%s"] = true
L["Deaths:"] = true
L["Key"] = true

-- UI/TabDelversCall.lua
L["Available"] = true
L["In Progress"] = true
L["Banked"] = true
L["Turned In"] = true
L["Delver's Call"] = true
L["World Tour weekly quest tracker"] = true
L["Each rotational delve has a Delver's Call quest. Run every delve once to pick the quest up, but %s \226\128\148 the XP scales to your level at turn-in. Bank all %d, then cash them in once you're a few levels short of cap for a push through the final levels."] = true
L["don't turn it in yet"] = true
L["Delve"] = true
L["Alt Rollup"] = true
L["(you)"] = true
L["%s%s|r %s(%s)|r%s  \226\128\148  %s%d|r in progress  %s%d|r banked  %s%d|r done  %s%d|r left"] = true
L["No characters tracked yet."] = true
L["Show a green checkmark on the Delve Locations tab for delves whose Delver's Call you've turned in"] = true
L["%sThis character:|r  %s%d|r available   %s%d|r in progress   %s%d|r banked   %s%d|r turned in   %s(of %d)|r"] = true

-- UI/TabRoster.lua
L["Character"] = true
L["iLvl"] = true
L["Keys"] = true
L["Wk Shards"] = true
L["Bounty"] = true
L["Vault"] = true
L["Gilded"] = true
L["Weekly"] = true
L["Trove"] = true
L["Updated"] = true
L["just now"] = true
L["%dm ago"] = true
L["%dh ago"] = true
L["%dd ago"] = true
L["Roster"] = true
L["Account-wide alt overview"] = true
L["Log into a character to record it. Click a column to sort; hover a row for detail."] = true
L["Remove %s from the roster?\n\nThis only clears the saved snapshot; logging into that character records it again."] = true
L["Remove"] = true
L["%s%d|r %scharacters|r   %s\194\183|r   %s%d|r %skeys|r   %s\194\183|r   %s%d|r %sbounty maps|r   %s\194\183|r   %s%d|r %sweekly delve quest done|r"] = true
L["Done"] = true
L["Item level: %s"] = true
L["Coffer Keys: %d   Shards: %d"] = true
L["Bounty maps: %d"] = true
L["Weekly shards earned: %d/%d"] = true
L["Great Vault delves: %d/%d  (%d/3 slots)"] = true
L["Gilded Stash: %d/%d"] = true
L["Trovehunter's Bounty: %s"] = true
L["looted this week"] = true
L["not looted"] = true
L["Weekly data resets at the next reset"] = true
L["Updated: %s"] = true

-- UI/TabOptions.lua
L["General"] = true
L["Default Tab (opens to this tab)"] = true
L["UI Scale"] = true
L["Reset"] = true
L["Show Minimap / Broker Button"] = true
L["Show weekly earnable shards in button tooltip"] = true
L["Weekly Shards in Tooltip"] = true
L["On the minimap / broker button tooltip, shows your Coffer Key Shards as owned / still-earnable-this-week instead of just the owned count."] = true
L["Show What's New after an update"] = true
L["What's New Popup"] = true
L["Shows the What's New window once after each update. You can always reopen it from the About tab or with /ed whatsnew."] = true
L["Show Trovehunter's Bounty reminder on Delve entry"] = true
L["Display"] = true
L["%s (default)"] = true
L["Gold"] = true
L["Red"] = true
L["Purple"] = true
L["Dark Green"] = true
L["Dark Blue"] = true
L["Accent Color"] = true
L["Summary line — hold Shift for details (default)"] = true
L["Always show full details"] = true
L["Off"] = true
L["Delve Achievements on Map Tooltips"] = true
L["Show Bonus Spoils Tracker"] = true
L["Bonus Spoils Tracker"] = true
L["While inside a delve, tracks the two bonus-chest objectives - Nemesis Strongbox packs and the Sanctified Banner - so you know you've grabbed the extra loot before pulling the boss."] = true
L["Drag the tracker to move it."] = true
L["Show Run Timer"] = true
L["Run Timer"] = true
L["Shows your elapsed run time on a small on-screen display while you're inside a delve. Works on its own - you don't need the Bonus Spoils tracker."] = true
L["Drag the display to move it."] = true
L["Show Delve HUD"] = true
L["Delve HUD"] = true
L["An on-screen panel while inside a delve showing the story variant and its grade, the recommended curios for your role, your run timer, and your death count."] = true
L["Shares the on-screen frame with the Run Timer and Bonus Spoils tracker - drag any of them to move it."] = true
L["Show Best Time & keep timer after boss"] = true
L["Best Time & Run Result"] = true
L["Adds your fastest time for the current delve to the on-screen panel (your best at this tier, or your overall best labelled with its tier), and keeps the run timer up after you beat the boss - green if you beat your best time at this tier, red if not. Needs one previous run logged."] = true
L["Show Tier & Achievement Panel at Delve Entrance"] = true
L["Tier & Achievement Panel"] = true
L["When you open a delve's difficulty picker at its entrance, shows a panel with the loot and Great Vault item levels for every tier, plus your story, chest, and tier-goal achievement progress for that delve."] = true
L["Alerts & Tracking"] = true
L["Low Shard Warning"] = true
L["Warning Threshold"] = true
L["%d shards"] = true
L["Chat Alert When New Bountiful Delves Rotate In"] = true
L["Chat Alert for Special Assignments"] = true
L["Warn When Companion Has No Role Assigned"] = true
L["Companion Audio"] = true
L["Mute Valeera voice lines"] = true
L["Suppress Valeera speech bubbles"] = true
L["Mute Dundun (Abundance event rat) voice lines"] = true
L["Who is Dundun?"] = true
L["Dundun is the rat loa who hosts the Abundance cave events and repeats his voice lines endlessly. Muting only silences his audio - the event itself is unaffected."] = true
L["Reset all Everything Delves settings to defaults?"] = true
L["Yes"] = true
L["All settings reset."] = true
L["Are you sure you want to clear all Delve History?\n\nThis will permanently erase all lifetime stats, run history, and personal bests for every delve on this character. This cannot be undone."] = true
L["Yes, Erase Everything"] = true
L["Delve history cleared."] = true
L["Reset All Settings"] = true
L["Reset Settings"] = true
L["Restore every option to its default value."] = true
L["Erase all recorded delve runs and lifetime stats for this character."] = true

-- UI/TabProfiles.lua
L["Profiles"] = true
L["Switch"] = true
L["Name for the new (empty) profile:"] = true
L["Create"] = true
L["Could not create profile."] = true
L["Now using profile '%s'."] = true
L["Name for the copy of the current profile:"] = true
L["Duplicate"] = true
L["Could not duplicate profile."] = true
L["Duplicated into '%s' and switched to it."] = true
L["Permanently delete profile '%s'?\n\nThis erases that profile's delve history. This cannot be undone."] = true
L["Could not delete profile."] = true
L["Deleted profile '%s'."] = true
L["New Profile"] = true
L["Duplicate Current"] = true
L["Profiles are per-character. Your delve history lives in the active profile; UI settings (colors, scale, alerts) stay account-wide.\nSwitching profiles never deletes data — it only changes which profile this character uses."] = true
L["This character:"] = true
L["Active profile:"] = true
L["(%d char)"] = true
L["(%d chars)"] = true

-- UI/TabAbout.lua
L["Open or close the main window"] = true
L["Toggle the Bonus Spoils tracker (also /ed spoils)"] = true
L["Toggle the curio reminder popup"] = true
L["Show the What's New popup again"] = true
L["Open this About tab"] = true
L["Reset all settings to defaults"] = true
L["Special thanks to %s for the many hours spent translating Everything Delves into French."] = true
L["Special thanks to %s for the many hours spent translating Everything Delves into Russian."] = true
L["Special thanks to %s for the many hours spent translating Everything Delves into Korean."] = true
L["Special thanks to %s for the many hours spent translating Everything Delves into Simplified Chinese."] = true
L["Special thanks to %s for the many hours spent translating Everything Delves into Traditional Chinese."] = true
L["Special thanks to %s for the many hours spent translating Everything Delves into German."] = true
L["by Wheelbarrel00    -    for WoW Midnight (%s)"] = true
L["A complete Delves companion: track delve locations, bountiful status, coffer key shards, tiers, your run history, and more - all in one window."] = true
L["Report a Bug"] = true
L["What's New"] = true
L["Commands"] = true
L["Tip: right-click the minimap button to jump to Options. For support, the author may ask you to run a debug command."] = true
L["Tutorials"] = true
L["Video tutorials are coming soon - watch this space."] = true
L["More Add-ons by Wheelbarrel00"] = true
L["Thanks"] = true
L["Built with feedback, reports, and ideas from the community - especially %s. Thank you!"] = true
L["Changelog"] = true
L["Older versions are on CurseForge"] = true

-- Core/Achievements.lua
L["any tier"] = true
L["Tier 4+"] = true
L["Tier 8+"] = true
L["Tier 11"] = true

-- Core/Constants.lua
L["Delve Locations"] = true
L["Current Bountiful Delves"] = true
L["Tier Guide"] = true
L["Shard Tracker"] = true
L["Options"] = true
L["About"] = true
L["Prey Quests"] = true
L["World Map Rares"] = true
L["World Quests"] = true
L["World Map Treasures"] = true
L["Abundance Events"] = true

-- Core/Data.lua
L["Interrupt"] = true
L["Priority"] = true
L["Tactic"] = true
L["Tank"] = true
L["Kill every Lesser Venomborne that Serpentogenesis spawns - each one still alive heals him on the next cast."] = true
L["Serpentogenesis spawns Lesser Venomborne adds. Kill them before the next cast, because every survivor heals him."] = true
L["Venom Splash leaves poison pools where it lands. Move out of them."] = true
L["Hydra Strike stacks a nature damage-over-time, so incoming damage climbs the longer the fight runs."] = true
L["Interrupt Malignance every cast, sidestep the Living Venom channel, and kill the slime it leaves behind."] = true
L["Malignance - his most dangerous cast. It stacks nature damage and slows you, so never let one finish."] = true
L["Step out of the Living Venom channel, then kill the slime add it spawns when the cast ends."] = true
L["Toxic Froth is a short poison damage-over-time. Heal through it rather than saving a dispel for it."] = true
L["Interrupt the Wildwood Weed channel to break its root, then sidestep the Lightbloom Salvo volley."] = true
L["Wildwood Weed channel — interrupting it frees you from the root. If you're rooted when Lightbloom Salvo fires, the zones become impossible to avoid."] = true
L["Dodge the Lightbloom Salvo projectiles."] = true
L["Leave melee before Shadow Laceration lands, and move off your spot after Twilight Crash."] = true
L["Step out of melee range before Shadow Laceration connects to avoid the bleed DoT."] = true
L["Move away from your position once Twilight Crash is cast — Garand leaps to where you were standing."] = true
L["Interrupt Terrifying Power and step out of the Void Eruption zones."] = true
L["Terrifying Power — fears the whole group and deals damage."] = true
L["Sidestep the Void Eruption zones."] = true
L["Interrupt Shadow Bolt on cooldown; during Shadowveil Annihilation, destroy all three Shadow Orbs before the channel ends."] = true
L["Shadow Bolt — top interrupt priority; never let a cast finish."] = true
L["While Shadowveil Annihilation is channeling he is immune — destroy all three Shadow Orbs before it ends to shatter his shield and raise his damage taken."] = true
L["Dodge Searing Spew and the Acid Spray wave, and heal off the Corrosive Bile damage."] = true
L["Searing Spew is a telegraphed area attack. Move out of it."] = true
L["Acid Spray is a channeled wave that leaves short-lived poison where it lands. Keep moving out of the poison."] = true
L["Corrosive Bile is nature damage that has to be healed off rather than avoided."] = true
L["Kill the Sacrificial Voidcallers before Devouring Nova, keep him off the platform edges, and dodge Voidscar Raze."] = true
L["Kill the Sacrificial Voidcallers before Devouring Nova fires — each one he consumes grants a permanent 10 percent damage buff."] = true
L["Keep the boss away from the platform edges — Devouring Nova's knockback is lethal near an edge."] = true
L["Void Bolt on the Sacrificial Voidcallers."] = true
L["Dodge the Voidscar Raze directional line attack."] = true
L["Hug melee range to stop Dark Pursuit, dodge Shade Cleave, and pull her out of the Bask in the Twilight zones."] = true
L["Stay in close melee range — proximity prevents Dark Pursuit."] = true
L["Sidestep the Shade Cleave cone."] = true
L["Move Darza out of the Bask in the Twilight void zones — she gains 30 percent increased damage while standing in them."] = true
L["Gather the spirits dropped by Flaying Knife for a damage buff, and collect them all before Claim Spirits resolves."] = true
L["Collect the spirits spawned by Flaying Knife — each grants a 10 percent damage buff. Grab the ones inside Raging Spirits zones first, before they are destroyed."] = true
L["Collect every spirit before Claim Spirits completes — each one left behind gives Jin'Ma a stacking damage buff."] = true
L["Interrupt the Twilight Seekers, dodge the Abyssal Burst cone, and keep clear of the Illusory Deceit illusions."] = true
L["Twilight Seekers."] = true
L["Dodge the Abyssal Burst frontal cone."] = true
L["Keep your distance from the Illusory Deceit illusions before they explode."] = true
L["Interrupt Thorn Burst, turn away before Binding Burst resolves, and fight near the arena walls."] = true
L["Thorn Burst — a heavy single-target hit."] = true
L["Turn away before Binding Burst resolves to avoid being disoriented."] = true
L["Stay near the arena edges — Solar Charge leaves lasting puddles, so hugging a wall costs the least space."] = true
L["Kite the boss along the edges during Fungistorm, then burst it while it's dizzy afterward."] = true
L["Fungistorm: the boss chases a player while whirlwinding — kite it near the arena edges to conserve space."] = true
L["Once Fungistorm ends the boss is dizzy (25 percent increased damage taken) — save your cooldowns for this window."] = true
L["Sidestep Fungal Charge."] = true
L["Pure positioning fight: drop Rancid Rain at the edges, dodge The Fungi's Fist, and sidestep Fling Chair."] = true
L["Rancid Rain: move to the arena edges so the poison clouds land away from the center."] = true
L["The Fungi's Fist: dodge the slam and all five projectiles — a hit stuns you for 3s."] = true
L["Fling Chair: sidestep it to avoid the knockback and disorient."] = true
L["Kite the Command Light adds through the floor zones, turn from Lumenia's circles, and defensive Malignant Gleam."] = true
L["Kill the Command Light adds before they reach you — kite them through the floor zones to stun them."] = true
L["Turn away from Lumenia's ground circles before they activate to avoid being disoriented."] = true
L["Use a defensive for Malignant Gleam — a holy damage hit."] = true
L["Keep moving through Tear It Down, kite away on Unanswered Call, and interrupt Hopelessness every cast."] = true
L["Tear It Down: the tentacles slam after a short delay — keep moving to dodge the impact."] = true
L["Unanswered Call fixates a player for 8s — use a movement ability to kite the boss away immediately."] = true
L["Dispel Hopelessness if it's missed — a curse that lowers Haste and Movement Speed for everyone."] = true
L["Hopelessness — every cast; the movement slow combined with the fixate is lethal at higher tiers."] = true
L["Interrupt Calling Bolt, dodge Crushing Rift, and clear every Voidcaller before Gorge."] = true
L["Calling Bolt — spawns a Voidcaller if it lands."] = true
L["Dodge Crushing Rift — being hit spawns four Voidcallers at once."] = true
L["Kill all Voidcallers before Gorge — each one consumed grants Esuritus a damage buff. Interrupt their Commune with the Void channel."] = true
L["Three elites instead of a single boss — pull them one at a time, interrupt Lightbloom Beam, and dodge Blooming Bile and Rotting Charge."] = true
L["Three Corrupted Umbraroot elites end this story — pull them one at a time, never all at once."] = true
L["Lightbloom Beam — finishes into a channel that hits one player for heavy damage."] = true
L["Dodge the Blooming Bile frontal cone — heavy damage and it summons voidspawn; kill the adds quickly."] = true
L["Sidestep Rotting Charge and stay out of the puddle it leaves behind."] = true
L["Drag her out of her own venom, sidestep the Purging Breath waves, and do not spend a kick on the channel."] = true
L["Snake Eater grants her two stacks per cast. Game data has each stack raising the damage she TAKES by 15 percent, so a stacked Gralka is your burn window - hold cooldowns for it."] = true
L["Every Snake Eater cast leaves a venom puddle where she fed. Pull her off it instead of fighting inside it."] = true
L["Purging Breath is a 6 second channel that spends one stack every 2 seconds and throws a toxic wave at whoever she is targeting. The waves one-shot, but she stands completely still while channeling, so they are easy to walk out of."] = true
L["Do not interrupt Purging Breath. It can be kicked, but she is stationary and the waves are dodgeable, so the kick is worth more elsewhere."] = true
L["Venomblade Slash hits for physical and leaves a nature damage-over-time that ticks harder for every Snake Eater stack. Valeera as Healer dispels the poison and, just as usefully, will not waste the interrupt on Purging Breath."] = true
L["Marrowgar's kit in a delve: interrupt Bone Shield, run out of Bonestorm, keep moving off the spikes."] = true
L["Bone Shield applies a large absorb. Kick it, or you chew through the whole shield before your damage counts again."] = true
L["Bonestorm deals physical damage to everything nearby - walk out and kite until it ends."] = true
L["Bone Spike erupts in a run of small spikes underneath you, one after another. Keep moving; a hit is moderate damage plus a short knockback."] = true
L["Fight him beside a pillar so you can break line of sight on both Death Grip and Roar of the Champion."] = true
L["Soul Cleave drops a large circle around him and leaves a voidzone behind. Move around the pillar rather than straight out, so Death Grip cannot drag you back into it."] = true
L["Death Grip pulls his furthest target to him. Fighting next to a pillar is the whole answer - line of sight beats the pull."] = true
L["Roar of the Champion slows him but raises his damage by 80 percent. Break line of sight and wait it out instead of trading with him."] = true
L["Dodge the Upheaval circles, then keep going - he dies once and comes back at full health."] = true
L["Phase 1: Upheaval marks his furthest target with a large circle and leaves a puddle where it lands. Move out before the cast finishes."] = true
L["Phase 1: Pulverize is moderate damage on his current target."] = true
L["At 0 health he is resurrected at full health and phase 2 begins - do not walk off when he drops."] = true
L["Phase 2: Necrotic Upheaval is a frontal you can sidestep, and it leaves voidzones behind it."] = true
L["Phase 2: Ejecting Decay spawns small circles around him plus a large circle on you and Valeera. The large ones throw you into the air, so clear both."] = true
L["Open Night is a gauntlet before Drakta: clear the floor, then Crushfoot, the Bluegill Brothers, Brinebeater, Guth'kar the Bound and Hexspitter Zit'ka."] = true
L["Clear the arena floor first. On higher tiers some of those enemies are replaced by Nemesis mobs, so look before you pull."] = true
L["Crushfoot, a rhino, opens. Savage Gore bleeds his target, and Stampeding Charge hits hard unless you put a wall between you and him to break the cast."] = true
L["The Bluegill Brothers, three murlocs, come next - focus and interrupt the two smaller casters."] = true
L["Brinebeater, a sea giant, follows. Tidal Rage raises his damage by 60 percent and should be interrupted every time."] = true
L["Brinebeater's Tidal Smash drops a large circle around him, and Break Water puts a circle on you and Valeera that launches you if you stay in it."] = true
L["Guth'kar the Bound, a voidwalker, is straightforward as long as Curse of Dread is kicked. Valeera on DPS covers his Void Bolts."] = true
L["Three ghostly trolls close it out - focus Hexspitter Zit'ka and keep her interrupted."] = true
L["Interrupt Submit to the Void, kill the Dark Harbinger before Dark Prayer finishes, and dodge Discordant Hymn."] = true
L["Submit to the Void — a stacking magic DoT."] = true
L["Kill the Dark Harbinger before Dark Prayer finishes (15s) — success grants you 20 percent Versatility + 30 percent cooldown reduction; failure gives Patram a damage buff."] = true
L["Dodge the Discordant Hymn void zones — heavy damage if they catch you."] = true

-- Core/SpeedRank.lua
L["Fast"] = true
L["Brisk"] = true
L["Average"] = true
L["Slow"] = true
L["Long"] = true

-- Core/Utils.lua
L["TomTom is not installed."] = true
L["Could not set waypoint: %s"] = true
L["Waypoint API unavailable."] = true
L["Tracking This Delve"] = true
L["The on-screen arrow is guiding you here."] = true
L["Click to stop tracking."] = true
L["Track This Delve"] = true
L["Point the on-screen arrow at this entrance."] = true
L["Click again to stop."] = true
L["Set!"] = true

-- EverythingDelves.lua
L["Join the Everything Delves community for help, feedback, and updates.\n\nCopy the invite below (it's pre-selected — just press Ctrl+C):"] = true
L["Close"] = true
L["Copy the link below (it's pre-selected - just press Ctrl+C):"] = true
L["Invalid name."] = true
L["A profile with that name already exists."] = true
L["Source profile missing."] = true
L["Profile missing."] = true
L["Can't delete the profile you're currently using."] = true
L["Toggle Main Window"] = true
L["Toggle Curio Recommendations"] = true
L["Toggle Delve HUD"] = true
L["Delve HUD enabled."] = true
L["Delve HUD disabled."] = true
L["Settings reset to defaults."] = true
L["Bonus Spoils tracker |cFF22FF22ON|r - it appears while you're inside a delve."] = true
L["Bonus Spoils tracker |cFFFF2222OFF|r"] = true
L["v%s loaded. Type |cFFFFD700/ed|r to open."] = true
L["Your Delve companion has no role assigned!"] = true
L["Your Delve companion has no role assigned - open the companion panel to set one."] = true
L["Cleaned up %d run with an invalid timer."] = true
L["Cleaned up %d runs with an invalid timer."] = true
L["Repaired %d mis-flagged bountiful run from today."] = true
L["Repaired %d mis-flagged bountiful runs from today."] = true

-- UI/CurioReminder.lua
L["Damage"] = true
L["Companion Curios"] = true
L["The Combat and Utility curios your delve companion needs, listed for each role (Tank / Healer / Damage)."] = true
L["Your current role is highlighted in %s with a \"%s\"."] = true
L["gold"] = true
L["Slot these curios on your companion to boost her in delves."] = true
L["Season 2 also gives her a Poison slot. This popup does not cover it yet - the Nemesis tab already recommends one for Azta'rec."] = true
L["Currently in your bags"] = true
L["How many of this curio you have on you right now."] = true
L["%s = you have at least one."] = true
L["Green"] = true
L["%s = you have none yet \226\128\148 pick one up before your next delve."] = true
L["(no role set)"] = true
L["Combat:"] = true
L["Utility:"] = true
L["unknown companion \"%s\". Use |cFFFFFFFFbrann|r or |cFFFFFFFFvaleera|r."] = true

-- UI/DelveObjectives.lua
L["Bonus Spoils: Nemesis Strongbox packs + the Sanctified Banner — the bonus loot to grab before the boss."] = true
L["Delve HUD: variant, grade, recommended curios and deaths for this run."] = true
L["The clock shows your elapsed run time."] = true
L["Drag to move; toggle in Options."] = true
L["Variant:"] = true
L["Lives:"] = true
L["Best:"] = true
L["Nemesis Strongbox: %d/%d packs"] = true
L["Sanctified Banner - Grand Spoils earned!"] = true
L["Sanctified Banner found - bonus Spoils secured"] = true
L["Sanctified Banner - kill the Voidfused Rager!"] = true
L["Sanctified Banner - find it for bonus loot"] = true
L["Bonus loot secured - go get the boss!"] = true
L["All bonus loot accounted for."] = true

-- UI/DelvesPickerInfo.lua
L["Achievements"] = true
L["Loot"] = true
L["Highlighted = your gear tier"] = true
L["Achievement data unavailable"] = true
L["All achievements complete"] = true
L["Complete"] = true
L["Incomplete"] = true
L["(today counts!)"] = true
L["Story:"] = true
L["Chests:"] = true
L["Tier goals:"] = true
L["%d to go"] = true
L["Rewards by Tier"] = true
L["you: ~T%d"] = true

-- UI/PinAchievements.lua
L["Delve Achievements"] = true
L["Stories"] = true
L["Sturdy Chests"] = true
L["Delver of the Depths"] = true
L["%d to earn here"] = true
L["(press Shift for details)"] = true
L["Today's story (%s) still counts — run it today!"] = true

-- UI/TrovehunterReminder.lua
L["Trovehunter's Bounty Reminder"] = true
L["Don't forget to use your Trovehunter's Bounty before completing this Delve!"] = true
L["Don't show this reminder again"] = true
L["Use Trovehunter's Bounty"] = true
L["Bounty active this week - happy looting!"] = true
L["Not used yet - use it inside a Bountiful Delve."] = true

-- UI/WhatsNew.lua
L["Don't show this again"] = true
L["Got it"] = true

-- Convert the `true` sentinels to their key (the self-keyed English default).
for k, v in pairs(L) do if v == true then L[k] = k end end
