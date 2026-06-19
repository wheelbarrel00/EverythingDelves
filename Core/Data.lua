local E = EverythingDelves

-- Map IDs confirmed from live Midnight 12.0 data.
E.Zones = {
    { name = "Eversong Woods",        mapID = 2395 },
    { name = "Harandar",              mapID = 2413 },
    { name = "Voidstorm",             mapID = 2405 },
    { name = "Zul'Aman",              mapID = 2437 },
    { name = "Silvermoon",            mapID = 2393 },
    { name = "Isle of Quel'Danas",    mapID = 2424 },
}

-- Confirmed live data from Midnight S1. Coordinates are percentages
-- (45.4 = 0.454); SetWaypoint conversion happens at the call site.
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
}

E.TOTAL_DELVES = #E.DelveData

-- Seasonal Nemesis delve. Kept out of E.DelveData so location/bountiful
-- iterators are unaffected.
E.NemesisDelve = {
    name  = "Torment's Rise",
    boss  = "Nullaeus",
    tiers = { 8, 11 },
}

-- SCENARIO_COMPLETED filters on this so only Midnight delves are logged.
E.LoggableDelveNames = {}
for _, d in ipairs(E.DelveData) do
    E.LoggableDelveNames[d.name] = "regular"
end
E.LoggableDelveNames[E.NemesisDelve.name] = "nemesis"

E.DelveDataByName = {}
for _, d in ipairs(E.DelveData) do
    E.DelveDataByName[d.name] = d
end

-- Fallback name lookup when GetRealZoneText()/GetInstanceInfo() don't
-- return a recognizable delve name at SCENARIO_COMPLETED time.
E.DelveZoneIDs = {
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

E.BossRoleMeta = {
    interrupt = { label = "Interrupt", rgb = { 0.95, 0.45, 0.30 } },
    dps       = { label = "Priority",  rgb = { 0.95, 0.75, 0.30 } },
    general   = { label = "Tactic",    rgb = { 0.80, 0.80, 0.85 } },
    tank      = { label = "Tank",      rgb = { 0.40, 0.65, 0.95 } },
    healer    = { label = "Healer",    rgb = { 0.45, 0.85, 0.55 } },
}
-- Unlisted roles fall to the end.
E.BossRoleOrder = { "interrupt", "dps", "general", "tank", "healer" }

-- Keyed by the exact E.DelveData name.
E.DelveBosses = {
    ["Collegiate Calamity"] = {
        {
            name  = "Hydrangea",
            brief = "Interrupt the Wildwood Weed channel to break its root, then sidestep the Lightbloom Salvo volley.",
            notes = {
                { role = "interrupt", text = "Wildwood Weed channel — interrupting it frees you from the root. If you're rooted when Lightbloom Salvo fires, the zones become impossible to avoid." },
                { role = "general",   text = "Dodge the Lightbloom Salvo projectiles." },
            },
        },
        {
            name  = "Infiltrator Garand",
            brief = "Leave melee before Shadow Laceration lands, and move off your spot after Twilight Crash.",
            notes = {
                { role = "general", text = "Step out of melee range before Shadow Laceration connects to avoid the bleed DoT." },
                { role = "general", text = "Move away from your position once Twilight Crash is cast — Garand leaps to where you were standing." },
            },
        },
        {
            name  = "Voidscorned Vagrant",
            brief = "Interrupt Terrifying Power and step out of the Void Eruption zones.",
            notes = {
                { role = "interrupt", text = "Terrifying Power — fears the whole group and deals damage." },
                { role = "general",   text = "Sidestep the Void Eruption zones." },
            },
        },
    },
    ["The Shadow Enclave"] = {
        {
            name  = "Lord Antenorian",
            brief = "Interrupt Shadow Bolt on cooldown; during Shadowveil Annihilation, destroy all three Shadow Orbs before the channel ends.",
            notes = {
                { role = "interrupt", text = "Shadow Bolt — top interrupt priority; never let a cast finish." },
                { role = "dps",       text = "While Shadowveil Annihilation is channeling he is immune — destroy all three Shadow Orbs before it ends to shatter his shield and raise his damage taken." },
            },
        },
    },
    ["Parhelion Plaza"] = {
        {
            name  = "Gladius Slaurna",
            brief = "Kill the Sacrificial Voidcallers before Devouring Nova, keep him off the platform edges, and dodge Voidscar Raze.",
            notes = {
                { role = "dps",       text = "Kill the Sacrificial Voidcallers before Devouring Nova fires — each one he consumes grants a permanent 10% damage buff." },
                { role = "general",   text = "Keep the boss away from the platform edges — Devouring Nova's knockback is lethal near an edge." },
                { role = "interrupt", text = "Void Bolt on the Sacrificial Voidcallers." },
                { role = "general",   text = "Dodge the Voidscar Raze directional line attack." },
            },
        },
    },
    ["Twilight Crypt"] = {
        {
            name  = "Blademaster Darza",
            brief = "Hug melee range to stop Dark Pursuit, dodge Shade Cleave, and pull her out of the Bask in the Twilight zones.",
            notes = {
                { role = "general", text = "Stay in close melee range — proximity prevents Dark Pursuit." },
                { role = "general", text = "Sidestep the Shade Cleave cone." },
                { role = "general", text = "Move Darza out of the Bask in the Twilight void zones — she gains 30% increased damage while standing in them." },
            },
        },
    },
    ["Atal'Aman"] = {
        {
            name  = "Spiritflayer Jin'Ma",
            brief = "Gather the spirits dropped by Flaying Knife for a damage buff, and collect them all before Claim Spirits resolves.",
            notes = {
                { role = "general", text = "Collect the spirits spawned by Flaying Knife — each grants a 10% damage buff. Grab the ones inside Raging Spirits zones first, before they are destroyed." },
                { role = "general", text = "Collect every spirit before Claim Spirits completes — each one left behind gives Jin'Ma a stacking damage buff." },
            },
        },
    },
    ["The Darkway"] = {
        {
            name  = "Infiltrator Gulkat",
            brief = "Interrupt the Twilight Seekers, dodge the Abyssal Burst cone, and keep clear of the Illusory Deceit illusions.",
            notes = {
                { role = "interrupt", text = "Twilight Seekers." },
                { role = "general",   text = "Dodge the Abyssal Burst frontal cone." },
                { role = "general",   text = "Keep your distance from the Illusory Deceit illusions before they explode." },
            },
        },
    },
    ["The Grudge Pit"] = {
        {
            name  = "Brightthorn",
            brief = "Interrupt Thorn Burst, turn away before Binding Burst resolves, and fight near the arena walls.",
            notes = {
                { role = "interrupt", text = "Thorn Burst — a heavy single-target hit." },
                { role = "general",   text = "Turn away before Binding Burst resolves to avoid being disoriented." },
                { role = "general",   text = "Stay near the arena edges — Solar Charge leaves lasting puddles, so hugging a wall costs the least space." },
            },
        },
        {
            name  = "Gyrospore",
            brief = "Kite the boss along the edges during Fungistorm, then burst it while it's dizzy afterward.",
            notes = {
                { role = "general", text = "Fungistorm: the boss chases a player while whirlwinding — kite it near the arena edges to conserve space." },
                { role = "dps",     text = "Once Fungistorm ends the boss is dizzy (25% increased damage taken) — save your cooldowns for this window." },
                { role = "general", text = "Sidestep Fungal Charge." },
            },
        },
        {
            name  = "Mycomight",
            brief = "Pure positioning fight: drop Rancid Rain at the edges, dodge The Fungi's Fist, and sidestep Fling Chair.",
            notes = {
                { role = "general", text = "Rancid Rain: move to the arena edges so the poison clouds land away from the center." },
                { role = "general", text = "The Fungi's Fist: dodge the slam and all five projectiles — a hit stuns you for 3s." },
                { role = "general", text = "Fling Chair: sidestep it to avoid the knockback and disorient." },
            },
        },
    },
    ["The Gulf of Memory"] = {
        {
            name  = "Lumenia",
            brief = "Kite the Command Light adds through the floor zones, turn from Lumenia's circles, and defensive Malignant Gleam.",
            notes = {
                { role = "dps",     text = "Kill the Command Light adds before they reach you — kite them through the floor zones to stun them." },
                { role = "general", text = "Turn away from Lumenia's ground circles before they activate to avoid being disoriented." },
                { role = "general", text = "Use a defensive for Malignant Gleam — a holy damage hit." },
            },
        },
        {
            name  = "Mul'tha'ul",
            brief = "Keep moving through Tear It Down, kite away on Unanswered Call, and interrupt Hopelessness every cast.",
            notes = {
                { role = "general",   text = "Tear It Down: the tentacles slam after a short delay — keep moving to dodge the impact." },
                { role = "general",   text = "Unanswered Call fixates a player for 8s — use a movement ability to kite the boss away immediately." },
                { role = "healer",    text = "Dispel Hopelessness if it's missed — a curse that lowers Haste and Movement Speed for everyone." },
                { role = "interrupt", text = "Hopelessness — every cast; the movement slow combined with the fixate is lethal at higher tiers." },
            },
        },
    },
    ["Sunkiller Sanctum"] = {
        {
            name  = "Esuritus",
            brief = "Interrupt Calling Bolt, dodge Crushing Rift, and clear every Voidcaller before Gorge.",
            notes = {
                { role = "interrupt", text = "Calling Bolt — spawns a Voidcaller if it lands." },
                { role = "general",   text = "Dodge Crushing Rift — being hit spawns four Voidcallers at once." },
                { role = "dps",       text = "Kill all Voidcallers before Gorge — each one consumed grants Esuritus a damage buff. Interrupt their Commune with the Void channel." },
            },
        },
        {
            name  = "Corrupted Umbraroot",
            brief = "Three elites instead of a single boss — pull them one at a time, interrupt Lightbloom Beam, and dodge Blooming Bile and Rotting Charge.",
            notes = {
                { role = "general",   text = "Three Corrupted Umbraroot elites end this story — pull them one at a time, never all at once." },
                { role = "interrupt", text = "Lightbloom Beam — finishes into a channel that hits one player for heavy damage." },
                { role = "general",   text = "Dodge the Blooming Bile frontal cone — heavy damage and it summons voidspawn; kill the adds quickly." },
                { role = "general",   text = "Sidestep Rotting Charge and stay out of the puddle it leaves behind." },
            },
        },
    },
    ["Shadowguard Point"] = {
        {
            name  = "Chief-Arcanist Patram",
            brief = "Interrupt Submit to the Void, kill the Dark Harbinger before Dark Prayer finishes, and dodge Discordant Hymn.",
            notes = {
                { role = "interrupt", text = "Submit to the Void — a stacking magic DoT." },
                { role = "dps",       text = "Kill the Dark Harbinger before Dark Prayer finishes (15s) — success grants you 20% Versatility + 30% cooldown reduction; failure gives Patram a damage buff." },
                { role = "general",   text = "Dodge the Discordant Hymn void zones — heavy damage if they catch you." },
            },
        },
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

-- Story-variant -> boss for the four multi-boss delves, so "today's boss"
-- is known from first login before any live ENCOUNTER_END capture. Some
-- variants carry duplicate keys for alternate spellings the API returns.
E.DelveBossByVariant = {
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
