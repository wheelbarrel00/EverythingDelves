------------------------------------------------------------------------
-- Core/Changelog.lua - in-addon changelog shown on the About tab.
--
-- Keep the most recent ~10 releases here, condensed; older versions live
-- on CurseForge (linked from the About tab). This is a SECOND home for the
-- changelog (CHANGELOG.md is the canonical repo file), so add a new entry
-- here whenever CHANGELOG.md gets one - it's part of the release routine.
--
-- Newest first. Each entry: { version, date, sections = { { head, items } } }.
-- `head` is a category ("New", "Fixed", "Improved"); `items` are terse
-- one-line bullets (full prose lives in CHANGELOG.md).
------------------------------------------------------------------------
local E = EverythingDelves

E.Changelog = {
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
