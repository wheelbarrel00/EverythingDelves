------------------------------------------------------------------------
-- Core/Constants.lua
-- Static data: colors, tier tables, shard sources, difficulty ranges
------------------------------------------------------------------------
local E = EverythingDelves

------------------------------------------------------------------------
-- RGBA color tables (0-1 floats) for SetBackdropColor / SetTextColor
------------------------------------------------------------------------
E.Colors = {
    -- Frame chrome
    background  = { r = 0.05, g = 0.05, b = 0.05, a = 0.95 },  -- #0D0D0D
    border      = { r = 0.55, g = 0.00, b = 0.00, a = 1.00 },  -- deep red
    divider     = { r = 0.55, g = 0.00, b = 0.00, a = 0.80 },

    -- Tabs
    tabActive   = { r = 0.55, g = 0.00, b = 0.00, a = 1.00 },  -- #8B0000
    tabInactive = { r = 0.15, g = 0.15, b = 0.15, a = 1.00 },

    -- Text
    header      = { r = 1.00, g = 0.13, b = 0.13, a = 1.00 },  -- #FF2222

    -- Buttons
    buttonBg    = { r = 0.40, g = 0.00, b = 0.00, a = 1.00 },
    buttonHover = { r = 0.55, g = 0.05, b = 0.05, a = 1.00 },
}

------------------------------------------------------------------------
-- WoW color escape codes for inline string formatting
-- Usage: E.CC.gold .. "123" .. E.CC.close
------------------------------------------------------------------------
E.CC = {
    header = "|cFFFF2222",
    body   = "|cFFE0E0E0",
    muted  = "|cFF999999",
    gold   = "|cFFFFD700",
    green  = "|cFF33CC33",
    yellow = "|cFFFFD100",
    red    = "|cFFFF3333",
    purple = "|cFFB280FF",
    white  = "|cFFFFFFFF",
    close  = "|r",
}

------------------------------------------------------------------------
-- Tab definitions (order matters — matches button layout)
------------------------------------------------------------------------
E.TAB_NAMES = {
    "Delve Locations",
    "Current Bountiful Delves",
    "Tier Guide",
    "Shard Tracker",
    "Options",
}
E.NUM_TABS = #E.TAB_NAMES

------------------------------------------------------------------------
-- Tier data: index == tier number (1–11)
-- Values are Midnight Season 1 iLvl references.
-- These are static for S1; update if a future patch changes reward scaling.
------------------------------------------------------------------------
E.TierData = {
    { tier =  1, recGear = 170, bountifulLoot = 220, greatVault = 233 },
    { tier =  2, recGear = 187, bountifulLoot = 224, greatVault = 237 },
    { tier =  3, recGear = 200, bountifulLoot = 227, greatVault = 240 },
    { tier =  4, recGear = 213, bountifulLoot = 230, greatVault = 243 },
    { tier =  5, recGear = 222, bountifulLoot = 233, greatVault = 246 },
    { tier =  6, recGear = 229, bountifulLoot = 237, greatVault = 253 },
    { tier =  7, recGear = 235, bountifulLoot = 246, greatVault = 256 },
    { tier =  8, recGear = 244, bountifulLoot = 250, greatVault = 259 },
    { tier =  9, recGear = 250, bountifulLoot = 250, greatVault = 259 },
    { tier = 10, recGear = 257, bountifulLoot = 250, greatVault = 259 },
    { tier = 11, recGear = 265, bountifulLoot = 250, greatVault = 259 },
}

------------------------------------------------------------------------
-- Tier → color mapping
-- T1–T4 = green (entry), T5–T8 = yellow (mid), T9–T11 = red (hard)
-- (Ranges used directly in GetTierColor/GetTierCC below)
------------------------------------------------------------------------

--- Return the RGBA color table for a given tier number.
function E:GetTierColor(tier)
    if tier <= 4 then
        return self.Colors.green
    elseif tier <= 8 then
        return self.Colors.yellow
    else
        return self.Colors.red
    end
end

--- Return the CC escape code for a given tier number.
function E:GetTierCC(tier)
    if tier <= 4 then
        return self.CC.green
    elseif tier <= 8 then
        return self.CC.yellow
    else
        return self.CC.red
    end
end

------------------------------------------------------------------------
-- Coffer Key Shard sources
-- Each entry describes a weekly shard income stream.
-- `trackable` = true means we can query completion via API.
------------------------------------------------------------------------
E.ShardSources = {
    {
        name         = "Haradar's Legend Relics",
        shardsEach   = 100,
        weeklyMax    = 7,
        trackable    = true,
        questLineID  = 6015,  -- C_QuestLine.GetQuestLineQuests(6015)
    },
    {
        name         = "Saltheril's Haven Weekly",
        shardsEach   = 100,
        weeklyMax    = 4,
        trackable    = true,
        questIDs     = { 90573, 90574, 90575, 90576 },
    },
    {
        name         = "Prey Quests",
        shardsEach   = 75,
        weeklyMax    = 8,
        trackable    = true,
        questLineID  = 5945,  -- C_QuestLine.GetQuestLineQuests(5945)
    },
    {
        name        = "World Map Rares",
        shardsEach  = 50,
        weeklyMax   = nil,
        trackable   = false,
    },
    {
        name        = "World Map Treasures",
        shardsEach  = "3–15",
        weeklyMax   = nil,
        unconfirmed = true,
        trackable   = false,
    },
    {
        name        = "Preyseeker's Satchels (Uncommon)",
        shardsEach  = 50,
        weeklyMax   = nil,
        unconfirmed = true,
        trackable   = false,
    },
    {
        name        = "Preyseeker's Satchels (Rare)",
        shardsEach  = 60,
        weeklyMax   = nil,
        unconfirmed = true,
        trackable   = false,
    },
    {
        name        = "Preyseeker's Satchels (Epic)",
        shardsEach  = 80,
        weeklyMax   = nil,
        unconfirmed = true,
        trackable   = false,
    },
    {
        name        = "Blue Fly-through Stars",
        shardsEach  = "1–3",
        weeklyMax   = nil,
        unconfirmed = true,
        trackable   = false,
    },
}

------------------------------------------------------------------------
-- Currency IDs (Midnight 12.0 Season 1)
-- Queryable via C_CurrencyInfo.GetCurrencyInfo(id)
-- Currency IDs (confirmed from BountifulDelvesHunter-Midnight reference)
------------------------------------------------------------------------
E.CurrencyIDs = {
    cofferKeyShards = 3310,
    bountifulKeys   = 3028,
    undercoins      = 2803,
}

------------------------------------------------------------------------
-- Key crafting & beacon costs (Midnight S1 values)
------------------------------------------------------------------------
E.SHARDS_PER_KEY      = 100
------------------------------------------------------------------------
-- Item IDs for C_Item.GetItemIconByID() — used to show currency icons inline
------------------------------------------------------------------------
E.ItemIcons = {
    cofferKey   = 224172,  -- Coffer Key (bountiful key)
    cofferShard = 236096,  -- Coffer Key Shard
}

-- Cached icon texture IDs — resolved once at load to avoid per-refresh API calls
E.CachedIcons = {
    cofferKey   = C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(224172) or nil,
    cofferShard = C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(236096) or nil,
}

------------------------------------------------------------------------
-- Accent color presets (selectable in Options tab)
------------------------------------------------------------------------
E.AccentPresets = {
    red = {
        border   = { r = 0.55, g = 0.00, b = 0.00, a = 1.00 },
        header   = { r = 1.00, g = 0.13, b = 0.13, a = 1.00 },
        headerCC = "|cFFFF2222",
    },
    gold = {
        border   = { r = 0.60, g = 0.50, b = 0.00, a = 1.00 },
        header   = { r = 1.00, g = 0.84, b = 0.00, a = 1.00 },
        headerCC = "|cFFFFD700",
    },
    purple = {
        border   = { r = 0.40, g = 0.20, b = 0.60, a = 1.00 },
        header   = { r = 0.70, g = 0.50, b = 1.00, a = 1.00 },
        headerCC = "|cFFB280FF",
    },
}
