local E = EverythingDelves
local L = E.L

-- Map IDs confirmed from live Midnight 12.0 data.
E.Zones = {
    { name = "Eversong Woods",        mapID = 2395 },
    { name = "Harandar",              mapID = 2413 },
    { name = "Voidstorm",             mapID = 2405 },
    { name = "Zul'Aman",              mapID = 2437 },
    { name = "Silvermoon",            mapID = 2393 },
    { name = "Isle of Quel'Danas",    mapID = 2424 },
    { name = "The Coiled Isle",       mapID = 2512 },
}

-- Coordinates are percentages (45.4 = 0.454). SetWaypoint conversion happens
-- at the call site. Every poiID here has been read off a live POI except where
-- an entry says otherwise.
E.DelveData = {
    {
        name  = "Parhelion Plaza",
        zone  = "Isle of Quel'Danas",
        x     = 46.3,  y = 41.62,
        mapID = 2424,
        poiID = 8428,  normalPoiID = 8427,
    },
    {
        name  = "The Shadow Enclave",
        zone  = "Eversong Woods",
        x     = 45.4,  y = 86.0,
        mapID = 2395,
        poiID = 8438,  normalPoiID = 8437,
    },
    {
        name  = "Atal'Aman",
        zone  = "Zul'Aman",
        x     = 24.8,  y = 53.0,
        mapID = 2437,
        poiID = 8444,  normalPoiID = 8443,
    },
    {
        name  = "Twilight Crypt",
        zone  = "Zul'Aman",
        x     = 25.4,  y = 84.3,
        mapID = 2437,
        poiID = 8442,  normalPoiID = 8441,
    },
    {
        name  = "Shadowguard Point",
        zone  = "Voidstorm",
        x     = 37.38, y = 47.7,
        mapID = 2405,
        poiID = 8432,  normalPoiID = 8431,
    },
    {
        name  = "Sunkiller Sanctum",
        zone  = "Voidstorm",
        x     = 54.8,  y = 47.0,
        mapID = 2405,
        poiID = 8430,  normalPoiID = 8429,
    },
    {
        name  = "The Gulf of Memory",
        zone  = "Harandar",
        x     = 36.3,  y = 49.2,
        mapID = 2413,
        poiID = 8436,  normalPoiID = 8435,
    },
    {
        name  = "The Grudge Pit",
        zone  = "Harandar",
        x     = 70.5,  y = 64.92,
        mapID = 2413,
        poiID = 8434,  normalPoiID = 8433,
    },
    {
        name  = "Collegiate Calamity",
        zone  = "Silvermoon",
        x     = 40.76, y = 54.06,
        mapID = 2393,
        poiID = 8426,  normalPoiID = 8425,
    },
    {
        name  = "The Darkway",
        zone  = "Silvermoon",
        x     = 39.3,  y = 31.8,
        mapID = 2393,
        poiID = 8440,  normalPoiID = 8439,
    },
    -- The Coiled Isle pair inverts the pairing: bountiful is normal-1, not
    -- normal+1. Both IDs were read live off a bountiful day.
    {
        name  = "Gnarldor Isle",
        zone  = "The Coiled Isle",
        x     = 64.54, y = 77.58,
        mapID = 2512,
        poiID = 8760,  normalPoiID = 8761,
    },
    {
        name  = "The Ring of Glory",
        zone  = "The Coiled Isle",
        x     = 71.35, y = 56.54,
        mapID = 2512,
        poiID = 8763,  normalPoiID = 8764,
    },
}

E.TOTAL_DELVES = #E.DelveData

-- Seasonal Nemesis delve. Kept out of E.DelveData so location/bountiful
-- iterators are unaffected.
E.NemesisDelve = {
    name  = "Venomfall Deeps",
    boss  = "Azta'rec",
    tiers = { 8, 11 },
}

-- Every season's nemesis, so old history keeps its own boss label instead of
-- inheriting the current season's.
E.NemesisBossByDelve = {
    ["Venomfall Deeps"] = "Azta'rec",
    ["Torment's Rise"]  = "Nullaeus",
}

-- SCENARIO_COMPLETED filters on this so only Midnight delves are logged.
E.LoggableDelveNames = {}
for _, d in ipairs(E.DelveData) do
    E.LoggableDelveNames[d.name] = "regular"
end
for nemesisName in pairs(E.NemesisBossByDelve) do
    E.LoggableDelveNames[nemesisName] = "nemesis"
end

E.DelveDataByName = {}
for _, d in ipairs(E.DelveData) do
    E.DelveDataByName[d.name] = d
end

-- Fallback name lookup when GetRealZoneText()/GetInstanceInfo() don't
-- return a recognizable delve name at SCENARIO_COMPLETED time.
E.DelveZoneIDs = {
    [2633] = "The Ring of Glory",
    [2635] = "Gnarldor Isle",
    [2933] = "Collegiate Calamity",
    [2952] = "The Shadow Enclave",
    [2953] = "Parhelion Plaza",
    [2961] = "Twilight Crypts",
    [2962] = "Atal'Aman",
    [2963] = "The Grudge Pit",
    [2964] = "The Gulf of Memory",
    [2965] = "Sunkiller Sanctum",
    [2966] = "Torment's Rise",
    [2979] = "Shadowguard Point",
    [3003] = "The Darkway",
}

-- `delve` MUST match the E.DelveData name exactly so rows line up with the
-- Delve Locations tab (note: "Twilight Crypt", singular).
E.DelversCall = {
    { delve = "Atal'Aman",           questID = 93409 },
    { delve = "Collegiate Calamity", questID = 93384 },
    { delve = "Parhelion Plaza",     questID = 93386 },
    { delve = "Shadowguard Point",   questID = 93428 },
    { delve = "Sunkiller Sanctum",   questID = 93427 },
    { delve = "The Darkway",         questID = 93385 },
    { delve = "The Grudge Pit",      questID = 93421 },
    { delve = "The Gulf of Memory",  questID = 93416 },
    { delve = "The Shadow Enclave",  questID = 93372 },
    { delve = "Twilight Crypt",      questID = 93410 },
}

local delversCallQuestByDelve = {}
for _, entry in ipairs(E.DelversCall) do
    delversCallQuestByDelve[entry.delve] = entry.questID
end

function E:IsDelversCallComplete(delveName)
    local questID = delversCallQuestByDelve[delveName]
    if not questID or not (C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted) then
        return false
    end
    return C_QuestLog.IsQuestFlaggedCompleted(questID) and true or false
end

E.BossRoleMeta = {
    interrupt = { label = L["Interrupt"], rgb = { 0.95, 0.45, 0.30 } },
    dps       = { label = L["Priority"],  rgb = { 0.95, 0.75, 0.30 } },
    general   = { label = L["Tactic"],    rgb = { 0.80, 0.80, 0.85 } },
    tank      = { label = L["Tank"],      rgb = { 0.40, 0.65, 0.95 } },
    healer    = { label = L["Healer"],    rgb = { 0.45, 0.85, 0.55 } },
}
-- Unlisted roles fall to the end.
E.BossRoleOrder = { "interrupt", "dps", "general", "tank", "healer" }

local VENOMBORNE = {
    name  = "Replicating Venomborne",
    brief = L["Kill every Lesser Venomborne that Serpentogenesis spawns - each one still alive heals him on the next cast."],
    notes = {
        { role = "dps",     text = L["Serpentogenesis spawns Lesser Venomborne adds. Kill them before the next cast, because every survivor heals him."] },
        { role = "general", text = L["Venom Splash leaves poison pools where it lands. Move out of them."] },
        { role = "healer",  text = L["Hydra Strike stacks a nature damage-over-time, so incoming damage climbs the longer the fight runs."] },
    },
}

local VASHNIK = {
    name  = "Disciple of Vash'nik",
    brief = L["Interrupt Malignance every cast, sidestep the Living Venom channel, and kill the slime it leaves behind."],
    notes = {
        { role = "interrupt", text = L["Malignance - his most dangerous cast. It stacks nature damage and slows you, so never let one finish."] },
        { role = "general",   text = L["Step out of the Living Venom channel, then kill the slime add it spawns when the cast ends."] },
        { role = "healer",    text = L["Toxic Froth is a short poison damage-over-time. Heal through it rather than saving a dispel for it."] },
    },
}

-- Keyed by the exact E.DelveData name.
E.DelveBosses = {
    ["Collegiate Calamity"] = {
        {
            name  = "Hydrangea",
            brief = L["Interrupt the Wildwood Weed channel to break its root, then sidestep the Lightbloom Salvo volley."],
            notes = {
                { role = "interrupt", text = L["Wildwood Weed channel — interrupting it frees you from the root. If you're rooted when Lightbloom Salvo fires, the zones become impossible to avoid."] },
                { role = "general",   text = L["Dodge the Lightbloom Salvo projectiles."] },
            },
        },
        {
            name  = "Infiltrator Garand",
            brief = L["Leave melee before Shadow Laceration lands, and move off your spot after Twilight Crash."],
            notes = {
                { role = "general", text = L["Step out of melee range before Shadow Laceration connects to avoid the bleed DoT."] },
                { role = "general", text = L["Move away from your position once Twilight Crash is cast — Garand leaps to where you were standing."] },
            },
        },
        {
            name  = "Voidscorned Vagrant",
            brief = L["Interrupt Terrifying Power and step out of the Void Eruption zones."],
            notes = {
                { role = "interrupt", text = L["Terrifying Power — fears the whole group and deals damage."] },
                { role = "general",   text = L["Sidestep the Void Eruption zones."] },
            },
        },
    },
    ["The Shadow Enclave"] = {
        {
            name  = "Lord Antenorian",
            brief = L["Interrupt Shadow Bolt on cooldown; during Shadowveil Annihilation, destroy all three Shadow Orbs before the channel ends."],
            notes = {
                { role = "interrupt", text = L["Shadow Bolt — top interrupt priority; never let a cast finish."] },
                { role = "dps",       text = L["While Shadowveil Annihilation is channeling he is immune — destroy all three Shadow Orbs before it ends to shatter his shield and raise his damage taken."] },
            },
        },
        {
            name  = "Abominable Blunder",
            brief = L["Dodge Searing Spew and the Acid Spray wave, and heal off the Corrosive Bile damage."],
            notes = {
                { role = "general", text = L["Searing Spew is a telegraphed area attack. Move out of it."] },
                { role = "general", text = L["Acid Spray is a channeled wave that leaves short-lived poison where it lands. Keep moving out of the poison."] },
                { role = "healer",  text = L["Corrosive Bile is nature damage that has to be healed off rather than avoided."] },
            },
        },
    },
    ["Parhelion Plaza"] = {
        {
            name  = "Gladius Slaurna",
            brief = L["Kill the Sacrificial Voidcallers before Devouring Nova, keep him off the platform edges, and dodge Voidscar Raze."],
            notes = {
                { role = "dps",       text = L["Kill the Sacrificial Voidcallers before Devouring Nova fires — each one he consumes grants a permanent 10 percent damage buff."] },
                { role = "general",   text = L["Keep the boss away from the platform edges — Devouring Nova's knockback is lethal near an edge."] },
                { role = "interrupt", text = L["Void Bolt on the Sacrificial Voidcallers."] },
                { role = "general",   text = L["Dodge the Voidscar Raze directional line attack."] },
            },
        },
        VENOMBORNE,
    },
    ["Twilight Crypt"] = {
        {
            name  = "Blademaster Darza",
            brief = L["Hug melee range to stop Dark Pursuit, dodge Shade Cleave, and pull her out of the Bask in the Twilight zones."],
            notes = {
                { role = "general", text = L["Stay in close melee range — proximity prevents Dark Pursuit."] },
                { role = "general", text = L["Sidestep the Shade Cleave cone."] },
                { role = "general", text = L["Move Darza out of the Bask in the Twilight void zones — she gains 30 percent increased damage while standing in them."] },
            },
        },
        VENOMBORNE,
    },
    ["Atal'Aman"] = {
        {
            name  = "Spiritflayer Jin'Ma",
            brief = L["Gather the spirits dropped by Flaying Knife for a damage buff, and collect them all before Claim Spirits resolves."],
            notes = {
                { role = "general", text = L["Collect the spirits spawned by Flaying Knife — each grants a 10 percent damage buff. Grab the ones inside Raging Spirits zones first, before they are destroyed."] },
                { role = "general", text = L["Collect every spirit before Claim Spirits completes — each one left behind gives Jin'Ma a stacking damage buff."] },
            },
        },
        VASHNIK,
    },
    ["The Darkway"] = {
        {
            name  = "Infiltrator Gulkat",
            brief = L["Interrupt the Twilight Seekers, dodge the Abyssal Burst cone, and keep clear of the Illusory Deceit illusions."],
            notes = {
                { role = "interrupt", text = L["Twilight Seekers."] },
                { role = "general",   text = L["Dodge the Abyssal Burst frontal cone."] },
                { role = "general",   text = L["Keep your distance from the Illusory Deceit illusions before they explode."] },
            },
        },
        VENOMBORNE,
    },
    ["The Grudge Pit"] = {
        {
            name  = "Brightthorn",
            brief = L["Interrupt Thorn Burst, turn away before Binding Burst resolves, and fight near the arena walls."],
            notes = {
                { role = "interrupt", text = L["Thorn Burst — a heavy single-target hit."] },
                { role = "general",   text = L["Turn away before Binding Burst resolves to avoid being disoriented."] },
                { role = "general",   text = L["Stay near the arena edges — Solar Charge leaves lasting puddles, so hugging a wall costs the least space."] },
            },
        },
        {
            name  = "Gyrospore",
            brief = L["Kite the boss along the edges during Fungistorm, then burst it while it's dizzy afterward."],
            notes = {
                { role = "general", text = L["Fungistorm: the boss chases a player while whirlwinding — kite it near the arena edges to conserve space."] },
                { role = "dps",     text = L["Once Fungistorm ends the boss is dizzy (25 percent increased damage taken) — save your cooldowns for this window."] },
                { role = "general", text = L["Sidestep Fungal Charge."] },
            },
        },
        {
            name  = "Mycomight",
            brief = L["Pure positioning fight: drop Rancid Rain at the edges, dodge The Fungi's Fist, and sidestep Fling Chair."],
            notes = {
                { role = "general", text = L["Rancid Rain: move to the arena edges so the poison clouds land away from the center."] },
                { role = "general", text = L["The Fungi's Fist: dodge the slam and all five projectiles — a hit stuns you for 3s."] },
                { role = "general", text = L["Fling Chair: sidestep it to avoid the knockback and disorient."] },
            },
        },
        VENOMBORNE,
    },
    ["The Gulf of Memory"] = {
        {
            name  = "Lumenia",
            brief = L["Kite the Command Light adds through the floor zones, turn from Lumenia's circles, and defensive Malignant Gleam."],
            notes = {
                { role = "dps",     text = L["Kill the Command Light adds before they reach you — kite them through the floor zones to stun them."] },
                { role = "general", text = L["Turn away from Lumenia's ground circles before they activate to avoid being disoriented."] },
                { role = "general", text = L["Use a defensive for Malignant Gleam — a holy damage hit."] },
            },
        },
        {
            name  = "Mul'tha'ul",
            brief = L["Keep moving through Tear It Down, kite away on Unanswered Call, and interrupt Hopelessness every cast."],
            notes = {
                { role = "general",   text = L["Tear It Down: the tentacles slam after a short delay — keep moving to dodge the impact."] },
                { role = "general",   text = L["Unanswered Call fixates a player for 8s — use a movement ability to kite the boss away immediately."] },
                { role = "healer",    text = L["Dispel Hopelessness if it's missed — a curse that lowers Haste and Movement Speed for everyone."] },
                { role = "interrupt", text = L["Hopelessness — every cast; the movement slow combined with the fixate is lethal at higher tiers."] },
            },
        },
    },
    ["Sunkiller Sanctum"] = {
        {
            name  = "Esuritus",
            brief = L["Interrupt Calling Bolt, dodge Crushing Rift, and clear every Voidcaller before Gorge."],
            notes = {
                { role = "interrupt", text = L["Calling Bolt — spawns a Voidcaller if it lands."] },
                { role = "general",   text = L["Dodge Crushing Rift — being hit spawns four Voidcallers at once."] },
                { role = "dps",       text = L["Kill all Voidcallers before Gorge — each one consumed grants Esuritus a damage buff. Interrupt their Commune with the Void channel."] },
            },
        },
        {
            name  = "Corrupted Umbraroot",
            brief = L["Three elites instead of a single boss — pull them one at a time, interrupt Lightbloom Beam, and dodge Blooming Bile and Rotting Charge."],
            notes = {
                { role = "general",   text = L["Three Corrupted Umbraroot elites end this story — pull them one at a time, never all at once."] },
                { role = "interrupt", text = L["Lightbloom Beam — finishes into a channel that hits one player for heavy damage."] },
                { role = "general",   text = L["Dodge the Blooming Bile frontal cone — heavy damage and it summons voidspawn; kill the adds quickly."] },
                { role = "general",   text = L["Sidestep Rotting Charge and stay out of the puddle it leaves behind."] },
            },
        },
    },
    ["Gnarldor Isle"] = {
        {
            name  = "Gralka Snake-Eater",
            brief = L["Drag her out of her own venom, sidestep the Purging Breath waves, and do not spend a kick on the channel."],
            notes = {
                { role = "dps",     text = L["Snake Eater grants her two stacks per cast. Game data has each stack raising the damage she TAKES by 15 percent, so a stacked Gralka is your burn window - hold cooldowns for it."] },
                { role = "general", text = L["Every Snake Eater cast leaves a venom puddle where she fed. Pull her off it instead of fighting inside it."] },
                { role = "general", text = L["Purging Breath is a 6 second channel that spends one stack every 2 seconds and throws a toxic wave at whoever she is targeting. The waves one-shot, but she stands completely still while channeling, so they are easy to walk out of."] },
                { role = "general", text = L["Do not interrupt Purging Breath. It can be kicked, but she is stationary and the waves are dodgeable, so the kick is worth more elsewhere."] },
                { role = "healer",  text = L["Venomblade Slash hits for physical and leaves a nature damage-over-time that ticks harder for every Snake Eater stack. Valeera as Healer dispels the poison and, just as usefully, will not waste the interrupt on Purging Breath."] },
            },
        },
        {
            name  = "Osseous Amalgamation",
            brief = L["Marrowgar's kit in a delve: interrupt Bone Shield, run out of Bonestorm, keep moving off the spikes."],
            notes = {
                { role = "interrupt", text = L["Bone Shield applies a large absorb. Kick it, or you chew through the whole shield before your damage counts again."] },
                { role = "general",   text = L["Bonestorm deals physical damage to everything nearby - walk out and kite until it ends."] },
                { role = "general",   text = L["Bone Spike erupts in a run of small spikes underneath you, one after another. Keep moving; a hit is moderate damage plus a short knockback."] },
            },
        },
    },
    ["The Ring of Glory"] = {
        {
            name  = "Drakta, Hero of the Arena",
            brief = L["Fight him beside a pillar so you can break line of sight on both Death Grip and Roar of the Champion."],
            notes = {
                { role = "general", text = L["Soul Cleave drops a large circle around him and leaves a voidzone behind. Move around the pillar rather than straight out, so Death Grip cannot drag you back into it."] },
                { role = "general", text = L["Death Grip pulls his furthest target to him. Fighting next to a pillar is the whole answer - line of sight beats the pull."] },
                { role = "general", text = L["Roar of the Champion slows him but raises his damage by 80 percent. Break line of sight and wait it out instead of trading with him."] },
            },
        },
        {
            name  = "Gnok",
            brief = L["Dodge the Upheaval circles, then keep going - he dies once and comes back at full health."],
            notes = {
                { role = "general", text = L["Phase 1: Upheaval marks his furthest target with a large circle and leaves a puddle where it lands. Move out before the cast finishes."] },
                { role = "general", text = L["Phase 1: Pulverize is moderate damage on his current target."] },
                { role = "general", text = L["At 0 health he is resurrected at full health and phase 2 begins - do not walk off when he drops."] },
                { role = "general", text = L["Phase 2: Necrotic Upheaval is a frontal you can sidestep, and it leaves voidzones behind it."] },
                { role = "general", text = L["Phase 2: Ejecting Decay spawns small circles around him plus a large circle on you and Valeera. The large ones throw you into the air, so clear both."] },
            },
        },
        {
            name  = "Open Night arena champions",
            brief = L["Open Night is a gauntlet before Drakta: clear the floor, then Crushfoot, the Bluegill Brothers, Brinebeater, Guth'kar the Bound and Hexspitter Zit'ka."],
            notes = {
                { role = "general",   text = L["Clear the arena floor first. On higher tiers some of those enemies are replaced by Nemesis mobs, so look before you pull."] },
                { role = "general",   text = L["Crushfoot, a rhino, opens. Savage Gore bleeds his target, and Stampeding Charge hits hard unless you put a wall between you and him to break the cast."] },
                { role = "interrupt", text = L["The Bluegill Brothers, three murlocs, come next - focus and interrupt the two smaller casters."] },
                { role = "interrupt", text = L["Brinebeater, a sea giant, follows. Tidal Rage raises his damage by 60 percent and should be interrupted every time."] },
                { role = "general",   text = L["Brinebeater's Tidal Smash drops a large circle around him, and Break Water puts a circle on you and Valeera that launches you if you stay in it."] },
                { role = "interrupt", text = L["Guth'kar the Bound, a voidwalker, is straightforward as long as Curse of Dread is kicked. Valeera on DPS covers his Void Bolts."] },
                { role = "interrupt", text = L["Three ghostly trolls close it out - focus Hexspitter Zit'ka and keep her interrupted."] },
            },
        },
    },
    ["Shadowguard Point"] = {
        {
            name  = "Chief-Arcanist Patram",
            brief = L["Interrupt Submit to the Void, kill the Dark Harbinger before Dark Prayer finishes, and dodge Discordant Hymn."],
            notes = {
                { role = "interrupt", text = L["Submit to the Void — a stacking magic DoT."] },
                { role = "dps",       text = L["Kill the Dark Harbinger before Dark Prayer finishes (15s) — success grants you 20 percent Versatility + 30 percent cooldown reduction; failure gives Patram a damage buff."] },
                { role = "general",   text = L["Dodge the Discordant Hymn void zones — heavy damage if they catch you."] },
            },
        },
        VASHNIK,
    },
}

-- Alternate spellings (e.g. plural "Twilight Crypts" from DelveZoneIDs)
-- that must still resolve to the canonical boss list.
local BOSS_NAME_ALIASES = {
    ["Twilight Crypts"] = "Twilight Crypt",
    ["Gulf of Memory"]  = "The Gulf of Memory",
}

function E:GetDelveBosses(delveName)
    if not delveName then return nil end
    local list = E.DelveBosses[delveName]
    if list then return list end
    local alias = BOSS_NAME_ALIASES[delveName]
    if alias then return E.DelveBosses[alias] end
    return nil
end

-- Story-variant -> boss for every multi-boss delve, so "today's boss" is known
-- from first login before any live ENCOUNTER_END capture. Some variants carry
-- duplicate keys for alternate spellings. A delve gaining a second boss must
-- map ALL its variants. A variant with no final boss is deliberately absent.
E.DelveBossByVariant = {
    ["Gnarldor Isle"] = {
        ["Speaking Their Language"]     = "Gralka Snake-Eater",
        ["Olds and Ends"]               = "Gralka Snake-Eater",
        ["Minchi's Osseous Adventure"]  = "Osseous Amalgamation",
        ["Minchi's Osseous Adventurer"] = "Osseous Amalgamation",
    },
    ["The Ring of Glory"] = {
        ["Open Night"]   = "Drakta, Hero of the Arena",
        ["Game Day"]     = "Drakta, Hero of the Arena",
        ["Adopt-a-thon"] = "Gnok",
    },
    ["Collegiate Calamity"] = {
        ["Invasive Glow"]        = "Hydrangea",
        ["Faculty of Fear"]      = "Infiltrator Garand",
        ["Academy Under Siege"]  = "Voidscorned Vagrant",
    },
    ["The Grudge Pit"] = {
        ["Lightbloom Invasion"]  = "Brightthorn",
        ["Arena Champion"]       = "Gyrospore",
        ["Dastardly Rotstalk"]   = "Mycomight",
        ["Dastardly Rootstalks"] = "Mycomight",
        ["Fungal Pharmacon"]     = "Replicating Venomborne",
    },
    ["The Gulf of Memory"] = {
        ["Alnmoth Munchies"]      = "Lumenia",
        ["Sporasaur Special"]     = "Lumenia",
        ["Sporasaurus Surprise"]  = "Lumenia",
        ["Descent of the Haranir"] = "Mul'tha'ul",
    },
    ["Sunkiller Sanctum"] = {
        ["Core of the Problem"]      = "Esuritus",
        ["The Gravitational Effect"] = "Esuritus",
        ["Not What I Expected"]      = "Corrupted Umbraroot",
    },
    ["Shadowguard Point"] = {
        ["Calamitous"]        = "Chief-Arcanist Patram",
        ["Captured Wildlife"] = "Chief-Arcanist Patram",
        ["Captured Wild"]     = "Chief-Arcanist Patram",
        ["Captured Widlife"]  = "Chief-Arcanist Patram",
        ["Stolen Mana"]       = "Chief-Arcanist Patram",
        ["Basilisk Blitz"]    = "Disciple of Vash'nik",
        ["Basalisk Blitz"]    = "Disciple of Vash'nik",
    },
    ["Atal'Aman"] = {
        ["Ritual Interrupted"]  = "Spiritflayer Jin'Ma",
        ["Toadly Unbecoming"]   = "Spiritflayer Jin'Ma",
        ["Totem Annihilation"]  = "Spiritflayer Jin'Ma",
        ["Venomous Vapors"]     = "Disciple of Vash'nik",
    },
    ["Parhelion Plaza"] = {
        ["Bombing Run"]                 = "Gladius Slaurna",
        ["Holding the Line"]            = "Gladius Slaurna",
        ["March of the Arcane Brigade"] = "Gladius Slaurna",
        ["March of the Arcane Parade"]  = "Gladius Slaurna",
        ["Caustic Crush"]               = "Replicating Venomborne",
    },
    ["Twilight Crypt"] = {
        ["Loosed Loa"]                  = "Blademaster Darza",
        ["Loose Loa"]                   = "Blademaster Darza",
        ["Party Crasher"]               = "Blademaster Darza",
        ["Trapped"]                     = "Blademaster Darza",
        ["Why'd It Have to Be Snakes?"] = "Replicating Venomborne",
    },
    ["The Darkway"] = {
        ["Focusers Under Pressure"] = "Infiltrator Gulkat",
        ["Leyline Technician"]      = "Infiltrator Gulkat",
        ["Ogre Powered"]            = "Infiltrator Gulkat",
        ["Eggsplosive Growth"]      = "Replicating Venomborne",
    },
    ["The Shadow Enclave"] = {
        ["Mirror Shine"]              = "Lord Antenorian",
        ["Shadowy Supplies"]          = "Lord Antenorian",
        ["Traitor's Due"]             = "Lord Antenorian",
        ["Infiltrate and Ameliorate"] = "Abominable Blunder",
    },
}

function E:GetStaticBoss(delveName, variant)
    if not (delveName and variant and variant ~= "") then return nil end
    local byVariant = E.DelveBossByVariant[delveName]
    if not byVariant then
        local alias = BOSS_NAME_ALIASES[delveName]
        byVariant = alias and E.DelveBossByVariant[alias] or nil
    end
    if not byVariant then return nil end
    if byVariant[variant] then return byVariant[variant] end
    -- Substring scan guards against minor wording / spacing differences.
    local lower = variant:lower()
    for key, boss in pairs(byVariant) do
        local lk = key:lower()
        if lower:find(lk, 1, true) or lk:find(lower, 1, true) then
            return boss
        end
    end
    return nil
end

-- ENCOUNTER_END reports the encounter-journal name, which for the Grudge
-- Pit Arena Champion is "Spinshroom" (a reused under-the-hood encounter)
-- rather than the visible "Gyrospore". Scoped per delve so a name that is
-- correct elsewhere is never rewritten.
E.LiveBossNameFix = {
    ["The Grudge Pit"] = {
        ["Spinshroom"] = "Gyrospore",
    },
}

function E:NormalizeLiveBoss(delveName, bossName)
    if not (delveName and bossName) then return bossName end
    local fixes = E.LiveBossNameFix[delveName]
    if not fixes then
        local alias = BOSS_NAME_ALIASES[delveName]
        fixes = alias and E.LiveBossNameFix[alias] or nil
    end
    if fixes and fixes[bossName] then return fixes[bossName] end
    return bossName
end
