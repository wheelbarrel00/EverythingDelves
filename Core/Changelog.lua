-- Second home for the changelog (CHANGELOG.md is canonical); keep in sync on release.
local E = EverythingDelves

E.Changelog = {
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
