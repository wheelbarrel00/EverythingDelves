-- Second home for the changelog (CHANGELOG.md is canonical); keep in sync on release.
local E = EverythingDelves

E.Changelog = {
    {
        version = "1.31.0", date = "2026-08-26",
        sections = {
            { head = "New", items = {
                "Valeera's Poison slot is covered - Season 2 gave her a third slot beside Combat and Utility, and the curio popup now includes it. It shows the recommended poison, and hovering the section lists all six with what each one does and when it is the right pick, including which three you have to unlock from the Slithering Spoils quest. The poison does not change with the role you give her, so one pick serves every setup. The delve HUD shows it alongside your Combat and Utility curios.",
            }},
            { head = "Fixed", items = {
                "Great Vault item levels were too low from Tier 6 up - the Tier Guide and the panel beside the difficulty picker listed a Tier 8 Great Vault reward as item level 298 when it is really 305. Tier 6 and Tier 7 were short by the same margin, and Tiers 9 through 11 followed Tier 8. All of them now read correctly, and the gear track beside them moves with the numbers - Tier 8 and above are Hero track, not Champion. Thanks to fastenough69 for the report.",
                "Champion, Hero and Myth crests could show as capped when they were not - those three turned red on the Shard Tracker as though you had hit the seasonal cap, once you had earned and then spent past it. Unlike Adventurer and Veteran they cap what you can hold rather than what you can earn, so spending frees the room again. The warning now follows the number the cap actually applies to, and shows on the column it applies to.",
                "Frostheart Venom was spelled \"Frosthearth\" on the Nemesis tab.",
            }},
            { head = "Improved", items = {
                "The six languages cover the new Poison slot - German, French, Russian, Korean, Simplified Chinese and Traditional Chinese are complete again at 764 phrases each. The same pass corrected the in-game names for the Leech, Avoidance and Speed stats, which several languages had rendered with an everyday word rather than the one the game itself uses.",
            }},
        },
    },
    {
        version = "1.30.0", date = "2026-08-23",
        sections = {
            { head = "New", items = {
                "The What's New window can be moved, and told not to come back - drag it anywhere and it remembers the spot. A new \"Don't show this again\" box stops it returning after future updates, with a matching setting in Options if you change your mind. You can always reopen it from the About tab or with /ed whatsnew.",
                "Cooldown Master is listed on the About tab - the other addons list was missing it, so it now sits alongside Everything Quests and Loot Pro with links to CurseForge and GitHub.",
            }},
            { head = "Fixed", items = {
                "The Nemesis Strongbox tracker has shown nothing since the start of Season 2 - the in-delve HUD counts the enemy packs by watching their marker on the map, and Season 2 renamed that marker. The addon was still looking for Season 1's, so the pack line simply never appeared, on any character, in any Tier 4 or higher delve. It now recognizes both seasons.",
                "\"Grand Spoils earned!\" could appear while the Voidfused Rager was still alive - clicking the Sanctified Banner, spawning the Rager and then dying to it made the HUD announce the Grand Spoils as earned the moment you loaded back in, and it stayed wrong for the rest of the run. The Rager now has to be genuinely gone for three seconds, and loading screens no longer count as it leaving.",
                "A death could bank the wrong pack kill count for the rest of the run - the loading screen after a death counted every pack seen so far as killed. The display looked right until you reloaded, at which point the objective could read something like \"3/5 packs\" with two packs still alive.",
            }},
            { head = "Coming next", items = {
                "Curios are still not finished. Season 2's Poisons slot is not covered by the curio reminder yet, and it remains the next thing being worked on. The Nemesis tab already recommends a poison for Azta'rec in the meantime.",
            }},
        },
    },
    {
        version = "1.29.0", date = "2026-08-21",
        sections = {
            { head = "New", items = {
                "Every language is now complete - German, French, Russian, Korean, Simplified Chinese and Traditional Chinese have gone from a handful of translated phrases to all 749. Every tab, the HUD, the reminders and the slash commands are covered. Delve, boss, zone and story names still stay exactly as your own client shows them, because the addon matches them against the game's own text.",
            }},
            { head = "Fixed", items = {
                "The Azta'rec title rewards were labeled \"document heading\" - in Russian, Korean, Simplified Chinese and Traditional Chinese the two title rewards on the Nemesis tab used the word for the heading of a document rather than the word for a player title. Both now use the right one.",
                "The gold accent color was labeled as money - the color picker in Options offered \"gold coins\" in Russian, Korean, Simplified Chinese and Traditional Chinese, in a list where every other entry was a color. It now reads as the color it sets.",
            }},
            { head = "Improved", items = {
                "Boss tips spell out \"percent\" - a bare percent sign in the addon's own English text stops that phrase from being translated at all, so fifteen tips were reworded. English readers will see \"10 percent damage\" where it used to read \"10% damage\", and in exchange those tips now reach all six languages.",
            }},
            { head = "Coming next", items = {
                "The new translations have not been reviewed by a native speaker yet. Corrections are worth more than anything else right now and are very welcome.",
                "Curios are still not finished. Season 2's Poisons slot is not covered by the curio reminder yet, and it remains the next thing being worked on. The Nemesis tab already recommends a poison for Azta'rec in the meantime.",
            }},
        },
    },
    {
        version = "1.28.0", date = "2026-08-20",
        sections = {
            { head = "New", items = {
                "Everything Delves now speaks six more languages - German, French, Russian, Korean, Simplified Chinese and Traditional Chinese. Around 750 phrases across every tab, the HUD, the reminders and the slash commands are now translatable. Anything not yet translated simply shows in English, so a partial translation is never a broken one. Most of the addon is still English today, because the translations are only just starting, but will be coming very soon! Delve, boss, zone and story names deliberately stay exactly as your own client shows them, because the addon matches them against the game's own text.",
                "Translations are shared with the author's other addons - they live in one place, so a phrase used by more than one addon only ever gets translated once. Contributions are very welcome. The README explains how to send one.",
                "Translator credits on the About tab - Zox, Malevi4, labrie75, Keriaovo, BNS333 and Stonetwist, whose work every non-English string in this addon comes from.",
            }},
            { head = "Fixed", items = {
                "The curio reminder recommended last season's curios - it still suggested Porcelain Blade Tip and Mandate of Sacred Death, which are Season 1 items. It now recommends Season 2's Corrosive Bilespear for Combat and Soul-Cracking Dreamcatcher for Utility, for all three companion roles.",
                "The Nemesis tab said Venomfall Deeps had not opened yet - it told you the delve only opens once Season 2 begins, which stopped being true on 18 August. It now explains what actually gates it: a Tier 7 clear with at least one life left for the lower difficulty, or a Tier 10 clear for the harder one, and the clear does not have to be in Venomfall Deeps.",
                "The About tab named the wrong patch - it read 12.0.x when the addon targets 12.1.0.",
            }},
            { head = "Coming next", items = {
                "Curios are not finished yet and another update is coming soon. Season 2 also gave your companion a Poisons slot, and the curio reminder does not cover it yet. Poison recommendations, and the rest of the Season 2 curio list, are what is being worked on now. The Nemesis tab already recommends a poison for Azta'rec in the meantime.",
                "Ratings for 12.1's stories are still to come. No guide ranks any of them, so their grades can only come from timed runs.",
            }},
        },
    },
    {
        version = "1.27.0", date = "2026-08-19",
        sections = {
            { head = "New", items = {
                "The new story for eight of the older Delves - patch 12.1 gave every Season 1 Delve except The Gulf of Memory and Sunkiller Sanctum a Children of Ula'tek story, and the addon knew about none of them. All eight are in now, with their objectives and their bosses: Academic Antitoxin, Basilisk Blitz, Venomous Vapors, Fungal Pharmacon, Caustic Crush, Why'd It Have to Be Snakes?, Infiltrate and Ameliorate and Eggsplosive Growth.",
                "Tactics for the three new bosses - Replicating Venomborne, Disciple of Vash'nik and Abominable Blunder each expand into a full breakdown like every other Delve boss, covering what to interrupt, what to dodge, and which adds heal the boss if you leave them alive.",
                "Objectives for the two new Delves' stories - Olds and Ends, Minchi's Osseous Adventure, Speaking Their Language, Open Night, Game Day and Adopt-a-thon now tell you what the run actually asks of you.",
            }},
            { head = "Fixed", items = {
                "Delves no longer show a rating that belongs to a different story - when today's story had no rating of its own, Delve Locations fell back to the Delve's usual grade. For 12.1's new stories that meant Collegiate Calamity showing S, Parhelion Plaza A and The Shadow Enclave C for stories nobody has rated, and that borrowed A was driving the \"Best value\" pick. Your own recorded clear times are untouched.",
                "Today's boss is marked again on the Bountiful tab - Twilight Crypt and The Gulf of Memory appear under their in-game map name, which differs slightly from the name the addon files them under, so neither could work out which boss was today's.",
                "The Great Vault no longer names the wrong reset day - the Tier Guide told everyone rewards unlock on Tuesday, which is wrong outside the Americas. It now counts down the time remaining instead of naming a day.",
                "Delve History no longer keeps an impossible fastest time - the login cleanup that scrubs corrupted run timers left the Delve's \"Fastest\" record sitting at the bad value.",
                "The Coffer Key Shard world quest list refreshes properly - if it came up empty because the zone maps had not loaded yet, reopening the tab could keep showing nothing for up to a minute.",
            }},
            { head = "Improved", items = {
                "The addon stops doing work while its window is closed - whichever tab you last had open kept rebuilding itself on every currency, quest and map update for the rest of the session. On the Shard Tracker that was a full rebuild up to four times a second while questing.",
            }},
            { head = "Coming next", items = {
                "Ratings for 12.1's stories are still to come. No guide ranks any of them, so their grades can only come from timed runs.",
            }},
        },
    },
    {
        version = "1.26.0", date = "2026-08-18",
        sections = {
            { head = "Fixed", items = {
                "Bountiful Delves count the full set again - Gnarldor Isle was invisible to every Bountiful code path because its Bountiful map pin ID had never been confirmed, so a day it rolled Bountiful counted one Delve too few and the progress bar read \"1 / 3\" instead of \"1 / 4\". Its real ID has been read off a live Bountiful day and written in, along with The Ring of Glory's.",
                "The Tier Guide shows Season 2 item levels - every number in the tier table was still Season 1, so at 278 equipped it recommended Tier 11 when Tier 6 is the right answer.",
                "Reward gear tracks are named correctly - Season 2's upgrade tracks overlap, so an item level alone cannot say which track it is, and several Bountiful Loot and Great Vault values were labelled one track too low.",
                "The crest tracker follows Season 2 - the Shard Tracker was still watching last season's Dawncrests, so every row sat at zero while your Mistcrests were nowhere in the tab.",
            }},
            { head = "Improved", items = {
                "The Tier Guide reads its recommended item levels from the game rather than a baked-in table. It is read from the Delve entrance whenever you open one and remembered for the season, so it corrects itself on your first Delve of a new season.",
                "The crest panel takes its heading from the currency in game, so it will name itself correctly next season without an update.",
                "The pre-run clear-time estimate was anchored to a Season 1 gear reference that every Season 2 character is past. It now follows the live tier table.",
            }},
            { head = "Coming next", items = {
                "I am actively working to get all of Season 2's features live and we are getting close.",
                "Still to come: Tier ratings for the two new Delves, their Delver's Call quests, and the new story variant 12.1 added to eight of the ten older Delves.",
            }},
        },
    },
    {
        version = "1.25.0", date = "2026-08-14",
        sections = {
            { head = "New", items = {
                "Boss tactics for the two new Delves - Gnarldor Isle covers Gralka Snake-Eater and Osseous Amalgamation, The Ring of Glory covers Drakta, Hero of the Arena and Gnok, with today's boss marked.",
                "The Open Night arena gauntlet is written out in full - Crushfoot, the Bluegill Brothers, Brinebeater, Guth'kar the Bound and Hexspitter Zit'ka, including which casts to interrupt.",
                "The Nemesis tab now covers Season 2 - Azta'rec in Venomfall Deeps, with his main-phase kit, the Sermon of Ula'tek memory pattern, what changes on Tier \"??\", the Valeera role and curio setup including her new Poisons slot, and the reward list.",
                "The World Quest scanner now covers The Coiled Isle, which was being skipped entirely.",
            }},
            { head = "Fixed", items = {
                "Coffer Key Shards no longer reads \"0 / 0\" on the Bountiful tab - it compared your shards against a cap that is always zero for that currency, and now shows this week's real earn cap.",
                "The Bountiful progress bar no longer reads \"0 / 1\" until Bountiful Delves are unlocked, claiming a Delve existed that did not.",
                "The Bountiful tab now explains an empty list instead of leaving column headers over blank space, and says when data is still loading.",
                "Delve History keeps the right Nemesis name - your existing Torment's Rise runs still show Nullaeus rather than the new season's boss.",
            }},
            { head = "Coming next", items = {
                "Bountiful tracking, Delver's Call quests and Tier ratings for the two new Delves need data that will be updated very soon.",
                "Patch 12.1 also added a new story variant to eight of the ten older Delves. Those are being worked through and land in upcoming updates.",
            }},
        },
    },
    {
        version = "1.24.0", date = "2026-08-10",
        sections = {
            { head = "New", items = {
                "The two new Delves are on the map - Gnarldor Isle and The Ring of Glory, both on The Coiled Isle, with map pins, TomTom waypoints, today's story, and their Stories and Discoveries achievements.",
            }},
            { head = "Coming next", items = {
                "Bountiful tracking, Delver's Call quests, boss tactics, and Tier ratings for the two new Delves land in the next update - that data only becomes readable once the patch is live and the Delves have been run.",
            }},
        },
    },
    {
        version = "1.23.1", date = "2026-07-31",
        sections = {
            { head = "Fixed", items = {
                "Gilded Stash progress counts only your own runs - an alt sharing a profile no longer reads your main's Tier 11 Bountiful runs as its own and shows \"earned\" before running anything.",
                "Curio recommendations follow your actual companion - the slash command and keybind showed Brann's curios on a Midnight character, and pinned that wrong companion for the in-delve HUD too.",
                "Escape now closes the Trovehunter reminder during combat, instead of doing nothing and possibly throwing an interface error.",
                "The Tier Guide's \"Your Equipped iLvl\" no longer counts higher-item-level gear sitting in your bags, which could recommend a tier above your actual gear.",
                "Shards per hour is accurate - the rate divided shards earned since opening the tab by the time since login. All session stats now start together when you first open the Shard Tracker.",
                "Completing one of the day's Bountiful Delves no longer fires the \"New Bountiful Delves are available today!\" alert.",
                "The Special Assignment alert is per character - it no longer announces an assignment you accepted days ago after swapping characters.",
                "Delve Speed and average times ignore runs whose timer was scrubbed by the invalid-timer cleanup, which made clears look far faster than they were.",
            }},
            { head = "Thanks", items = {
                "Special thanks to Agaman for his work on this update! I really appreciate all your help lately!",
            }},
        },
    },
    {
        version = "1.23.0", date = "2026-07-25",
        sections = {
            { head = "New", items = {
                "Keybindings for the main window, curio recommendations, and the Delve HUD - set them in the game's Key Bindings menu under \"Everything Delves\".",
                "A one-click \"Use Trovehunter's Bounty\" button on the Trovehunter reminder, so you can use the bounty before finishing the delve.",
                "Roster columns for weekly Coffer Key Shard progress (Wk Shards) and whether you've looted the Trovehunter's Bounty this week (Trove).",
                "An optional warning (on by default) when your Delve companion has no role assigned.",
            }},
            { head = "Improved", items = {
                "Curio recommendations in the companion popup and the in-delve HUD now use your companion's actual assigned role instead of your own spec, so off-role players get the right picks.",
                "Great Vault item levels now fill in at login without opening the vault.",
                "Remix/Timerunning characters are no longer shown in the account Roster.",
            }},
        },
    },
    {
        version = "1.22.2", date = "2026-07-18",
        sections = {
            { head = "Fixed", items = {
                "\"Reset All Settings\" no longer erases your data - it only restores options to their defaults now, keeping your Roster, learned delve bosses, and Gilded Stash history.",
                "The companion level and XP bar now show on non-English game clients (they were blank before).",
                "Fixed an error that could blank the Shard Tracker tab when many Coffer Shard world quests were active at once.",
                "Gilded Stash progress is more accurate - no more false \"Done\" right after login, and runs made near the weekly reset are counted correctly.",
                "The Tier Guide now updates Gilded Stash, Great Vault, and Renown live while the tab is open, instead of only when you switch away and back.",
                "The Current Bountiful tab no longer shows a duplicate row or an inflated count for a delve whose map name differs from its internal name.",
                "The Special Assignment chat alert no longer false-fires when you first enable it, and now fires in the background instead of only while the Shard Tracker tab is open.",
                "The Current Bountiful tab's Session Completions counter increments again.",
                "Options checkboxes now stay in sync after a reset or a slash-command toggle.",
                "The curio popup highlights your role for solo players too.",
                "Muting the companion's chat bubbles no longer disables all chat bubbles in non-delve scenarios.",
                "Duplicating a profile into an existing name with the Enter key now reports the collision instead of doing nothing.",
                "Deleting a run no longer lowers your recorded highest tier or best time when the record is in older, trimmed history.",
                "Corrected the Profiles tab note about what a profile stores.",
            }},
            { head = "Improved", items = {
                "Dragging the UI Scale slider now applies the new scale when you release it, instead of rescaling the window as you drag.",
            }},
            { head = "Thanks", items = {
                "A special thank you to Agaman for his help on this update - you rock!",
            }},
        },
    },
    {
        version = "1.22.1", date = "2026-07-18",
        sections = {
            { head = "Fixed", items = {
                "The Sanctified Banner in the Bonus Spoils tracker now registers for your whole group - when anyone in your party collects the banner, every member's tracker marks it secured, instead of only updating for the person who clicked it. Thanks to DrahgunFyre for reporting it.",
            }},
        },
    },
    {
        version = "1.22.0", date = "2026-07-08",
        sections = {
            { head = "New", items = {
                "Delver's Call progress on the Delve Locations tab - turn on the new checkbox at the bottom of the Delver's Call tab, and every delve whose Delver's Call you've already turned in gets a green checkmark next to its name on the Delve Locations tab. Thanks to DrahgunFyre for the suggestion!",
            }},
            { head = "Fixed", items = {
                "The Nemesis Strongbox pack count no longer doubles (such as 3/6 instead of 0/3) after you leave a delve and quickly re-enter - the tally resets cleanly on re-entry and no longer sticks through a reload.",
            }},
            { head = "Thanks", items = {
                "A special thank you to Agaman for his help making Everything Delves great.",
            }},
        },
    },
    {
        version = "1.21.3", date = "2026-07-05",
        sections = {
            { head = "Fixed", items = {
                "Mousing over a nameplate buff or debuff outside the world map (for example in a Time-walking dungeon) no longer throws an error from the delve achievement map tooltip - it now ignores frames that aren't map pins.",
                "The minimap button icon no longer turns into a garbled, stretched texture after a zone change or reload when another addon organizes your minimap buttons - it re-applies its correct artwork automatically instead of needing a click.",
                "The Nullaeus tab no longer claims the weekly Nemesis quest is complete every week - it was reading the one-time 'Nulling Nullaeus' seasonal quest, and the status line now reflects that seasonal quest correctly.",
            }},
        },
    },
    {
        version = "1.21.2", date = "2026-06-30",
        sections = {
            { head = "Fixed", items = {
                "The Tier & Achievement panel at a delve entrance could show a different delve's name, achievements, and rewards than the entrance you were standing at - it now reads the delve straight from the picker, so the name and info always match. Thanks to charswebdev2 for the report!",
            }},
        },
    },
    {
        version = "1.21.1", date = "2026-06-30",
        sections = {
            { head = "Fixed", items = {
                "The Gilded Stash counter no longer stays at 0/4 after a Tier 11 Bountiful run when the in-delve count didn't re-sync - your logged Tier 11 Bountiful runs for the week now count as a backup, and the in-delve count re-syncs on its own after the boss.",
            }},
        },
    },
    {
        version = "1.21.0", date = "2026-06-28",
        sections = {
            { head = "New", items = {
                "Delve HUD run result - the run timer stays on screen after you beat the boss, green if you beat your best time for that delve and tier or red if not, plus your best time shown during the run. Toggle in Options (on by default). Thanks to BanditC64 for the suggestion!",
                "Optional tooltip format (off by default) showing your Coffer Key Shards as owned / still-earnable-this-week on the minimap and broker button.",
            }},
            { head = "Improved", items = {
                "The minimap button, broker display, and AddOns-list entry now use the bountiful delve icon instead of the old placeholder key.",
                "The delve achievement breakdown on the map tooltip is reorganized - each achievement shows a short label with its progress and a check or x per step, instead of repeated 'Achievement' labels and a raw criterion line.",
            }},
            { head = "Fixed", items = {
                "The Nemesis Strongbox pack tally no longer doubles (such as 3/6 instead of 0/3) when in-delve pack markers refresh during a run - each pack is counted once.",
                "The Tier & Achievement panel no longer appears at the new Ritual Site entrances (which reuse the delve picker) - it attaches only to delves now.",
            }},
        },
    },
    {
        version = "1.20.1", date = "2026-06-25",
        sections = {
            { head = "Fixed", items = {
                "The Delve HUD and Run Timer now show on their own, without needing the Bonus Spoils Tracker enabled.",
                "The first delve entered after logging in or reloading no longer fails to start - the HUD, run timer, and bonus-objective tracking stayed blank (and the run went untimed and unlogged) when the entry didn't trigger a fresh loading screen.",
            }},
        },
    },
    {
        version = "1.20.0", date = "2026-06-25",
        sections = {
            { head = "Improved", items = {
                "Speed estimates now scale with your item level, so an undergeared character sees realistic clear times instead of a one-size-fits-all guess. Your own logged average still takes over after a single run.",
                "The Tier & Achievement panel shown at a delve entrance can now be turned off in Options (on by default).",
            }},
            { head = "Fixed", items = {
                "Changelog entries on the About tab no longer occasionally overlap.",
            }},
        },
    },
    {
        version = "1.19.0", date = "2026-06-23",
        sections = {
            { head = "New", items = {
                "Delve HUD - an on-screen panel while in a delve: story variant and grade, recommended Combat/Utility curios, a live run timer, and your remaining lives and deaths.",
                "Run timer - a live elapsed-time clock for your run, on the HUD or standalone.",
                "Difficulty picker info - opening a delve entrance shows that delve's achievement status and a tier-by-tier reward table beside the picker.",
            }},
            { head = "Improved", items = {
                "The Pin button now tracks the real delve entrance with the game's on-screen arrow, as a toggle with a live tracking highlight.",
                "Great Vault Progress now shows all three reward slots with each one's item level and unlock progress.",
                "Per-tier loot is coloured by gear track (Adventurer through Myth), with the track named in the tooltip.",
            }},
            { head = "Fixed", items = {
                "Dying in a delve no longer resets the run timer, death count, or Bonus Spoils progress.",
                "Reloading mid-delve keeps your Nemesis Strongbox pack count.",
                "Reloading after the boss no longer shows a phantom new run.",
            }},
        },
    },
    {
        version = "1.18.0", date = "2026-06-22",
        sections = {
            { head = "New", items = {
                "Roster tab - an account-wide overview of every character: item level, keys, shards, bounty maps, Great Vault delve slots, Gilded Stash, and the weekly delve quest. Sort by any column and hover a row for detail.",
                "Live broker text - the minimap/broker now shows Keys, weekly shards, and time to reset without hovering (handy for Titan Panel and ElvUI).",
                "Bounty Map tooltip - hovering a Trovehunter's Bounty shows whether it is still unused this week, or active right now.",
            }},
        },
    },
    {
        version = "1.17.1", date = "2026-06-18",
        sections = {
            { head = "Changed", items = {
                "Some code clean up.",
                ".toc bump.",
            }},
        },
    },
    {
        version = "1.17.0", date = "2026-06-17",
        sections = {
            { head = "New", items = {
                "Delver's Journey on the Tier Guide - your level, a progress bar, and the milestone reward icons for each level.",
                "Hover help on the companion curio reminder - the title and each bag-count number now explain themselves.",
                "Map achievement tooltips redesigned - the full Stories / Discoveries / Delver of the Depths list, each criterion green when earned and red when still needed.",
            }},
        },
    },
    {
        version = "1.16.0", date = "2026-06-13",
        sections = {
            { head = "New", items = {
                "About tab - addon info, command reference, links, and this changelog.",
                "\"Keys used\" counter on each Delve History header.",
                "Weekly Shard Sources rebuilt and verified, with the correct 600/week cap read live from the game.",
                "Hover tooltips explaining the Dawncrest columns (On Hand / Season Max / Season Total).",
            }},
            { head = "Fixed", items = {
                "Delve runs no longer log \"--\" or an inflated time after a mid-run reload.",
                "A bountiful coffer's \"Key\" is now reliably tagged on the run.",
                "Nemesis Strongbox now counts every pack (was stuck at 1/3).",
                "A resumed run shows the correct tier mid-run instead of the previous run's.",
            }},
        },
    },
    {
        version = "1.15.0", date = "2026-06-11",
        sections = {
            { head = "New", items = {
                "Bonus Spoils tracker for a delve's two bonus chests (off by default).",
                "Delve achievements listed on the map-pin tooltips (Shift for full detail).",
            }},
            { head = "Fixed", items = {
                "Delve run times are accurate again (no more inflated durations).",
                "The gold \"Key\" tag now appears when a bountiful coffer key is spent.",
            }},
            { head = "Improved", items = {
                "Dawncrests panel shows your season maximum per crest tier.",
            }},
        },
    },
    {
        version = "1.14.0", date = "2026-06-10",
        sections = {
            { head = "New", items = {
                "Exact weekly Gilded Stash count read straight from the game.",
                "Dawncrest tracker added to the Shard Tracker tab.",
                "Companion level and XP bar shown inline on the Tier Guide.",
                "Delete a single run from Delve History (repairs that delve's stats).",
            }},
            { head = "Fixed", items = {
                "Per-run \"Key used\" detection now watches the correct currency.",
            }},
        },
    },
    {
        version = "1.13.1", date = "2026-06-07",
        sections = {
            { head = "Fixed", items = {
                "The Grudge Pit now logs its correct boss (Gyrospore).",
                "Delve runs survive a mid-run disconnect with their real time intact.",
            }},
        },
    },
    {
        version = "1.13.0", date = "2026-06-07",
        sections = {
            { head = "New", items = {
                "Quickest Delve & Best Value - per-delve clear-time estimates and a sortable Speed column.",
            }},
        },
    },
    {
        version = "1.12.2", date = "2026-06-03",
        sections = {
            { head = "Fixed", items = {
                "Sunkiller Sanctum shows the correct boss on its \"Not What I Expected\" variant.",
            }},
        },
    },
    {
        version = "1.12.1", date = "2026-06-03",
        sections = {
            { head = "Fixed", items = {
                "Deaths during a delve survive a mid-run /reload.",
            }},
        },
    },
    {
        version = "1.12.0", date = "2026-06-01",
        sections = {
            { head = "New", items = {
                "Join our Discord! link added to the main window and What's New popup.",
            }},
            { head = "Fixed", items = {
                "The \"Default Tab\" option now applies every time you open the window.",
            }},
        },
    },
    {
        version = "1.11.0", date = "2026-05-29",
        sections = {
            { head = "New", items = {
                "Choose how many runs to keep per delve (20-100) in Delve History.",
            }},
            { head = "Fixed", items = {
                "Trovehunter's Bounty reminder now fires in Twilight Crypts.",
                "Completed Bountiful delves show a proper checkmark.",
            }},
        },
    },
}
