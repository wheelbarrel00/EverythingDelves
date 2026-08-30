local E = EverythingDelves
local L = E.L

E.Colors = {
    background  = { r = 0.05, g = 0.05, b = 0.05, a = 0.95 },
    border      = { r = 0.55, g = 0.00, b = 0.00, a = 1.00 },
    divider     = { r = 0.55, g = 0.00, b = 0.00, a = 0.80 },

    tabActive   = { r = 0.55, g = 0.00, b = 0.00, a = 1.00 },
    tabInactive = { r = 0.15, g = 0.15, b = 0.15, a = 1.00 },

    header      = { r = 1.00, g = 0.13, b = 0.13, a = 1.00 },

    -- Intentionally hardcoded, not themed by accent color.
    buttonBg    = { r = 0.427, g = 0.020, b = 0.004, a = 1.00 },
    buttonHover = { r = 0.541, g = 0.024, b = 0.004, a = 1.00 },

    -- Intentionally not themed by accent color.
    greyLine    = { r = 0.290, g = 0.290, b = 0.290, a = 1.00 },
}

E.HEADER_FONT_SIZE = 20

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
    btnText = "|cFFEBB706",
    close  = "|r",
}

-- Order matters: matches the tab button layout.
E.TAB_NAMES = {
    L["Delve Locations"],
    L["Current Bountiful Delves"],
    L["Tier Guide"],
    "Azta'rec",
    L["Shard Tracker"],
    L["Delve History"],
    L["Delver's Call"],
    L["Roster"],
    L["Options"],
    L["Profiles"],
    L["About"],
}
E.NUM_TABS = #E.TAB_NAMES

-- index == tier number (1-11). recGear is seeded from a live read of
-- C_DelvesUI.GetDelveEntranceTiers().suggestedILvl and is re-read whenever the
-- player opens a delve entrance, so a season flip corrects it on the first
-- visit. The two reward columns have no live API and are hand-authored.
E.TierData = {
    { tier =  1, recGear = 170, bountifulLoot = 266, greatVault = 279 },
    { tier =  2, recGear = 187, bountifulLoot = 269, greatVault = 282 },
    { tier =  3, recGear = 200, bountifulLoot = 272, greatVault = 285 },
    { tier =  4, recGear = 259, bountifulLoot = 276, greatVault = 289 },
    { tier =  5, recGear = 268, bountifulLoot = 279, greatVault = 292 },
    { tier =  6, recGear = 275, bountifulLoot = 282, greatVault = 298 },
    { tier =  7, recGear = 281, bountifulLoot = 292, greatVault = 302 },
    { tier =  8, recGear = 290, bountifulLoot = 295, greatVault = 305 },
    { tier =  9, recGear = 296, bountifulLoot = 295, greatVault = 305 },
    { tier = 10, recGear = 303, bountifulLoot = 295, greatVault = 305 },
    { tier = 11, recGear = 309, bountifulLoot = 295, greatVault = 305 },
}

-- Gear track per reward column. Season 2 track bands OVERLAP (each track starts
-- at the previous track's rank 5/6), so an item level alone cannot name a track
-- and these have to be stored rather than derived.
local BOUNTIFUL_TRACK = {
    "Adventurer", "Adventurer", "Adventurer", "Adventurer", "Veteran", "Veteran",
    "Champion", "Champion", "Champion", "Champion", "Champion",
}
local VAULT_TRACK = {
    "Veteran", "Veteran", "Veteran", "Veteran", "Champion", "Champion",
    "Champion", "Hero", "Hero", "Hero", "Hero",
}
for i, td in ipairs(E.TierData) do
    td.bountifulTrack = BOUNTIFUL_TRACK[i]
    td.vaultTrack     = VAULT_TRACK[i]
end

-- Ritual Sites and Lairs (new in 12.1) share the delve entrance picker and
-- quote their own item levels, so the ladder is only ours for type Delve.
local function EntranceIsDelve()
    if not (C_DelvesUI and C_DelvesUI.GetTieredEntranceType
            and Enum and Enum.TieredEntranceType) then
        return false
    end
    local ok, entranceType = pcall(C_DelvesUI.GetTieredEntranceType)
    return ok and entranceType == Enum.TieredEntranceType.Delve
end

local function CurrentSeason()
    if not (C_DelvesUI and C_DelvesUI.GetCurrentDelvesSeasonNumber) then return nil end
    local ok, n = pcall(C_DelvesUI.GetCurrentDelvesSeasonNumber)
    return (ok and type(n) == "number") and n or nil
end

-- suggestedILvl is what the picker renders as "Recommended for adventurers at
-- item level %d". It only reads while a delve entrance interaction is open, so
-- callers cache the result rather than asking at login.
function E:ReadLiveTierData()
    if not (C_DelvesUI and C_DelvesUI.GetDelveEntranceTiers) then return nil end
    if not EntranceIsDelve() then return nil end
    local ok, tiers = pcall(C_DelvesUI.GetDelveEntranceTiers)
    if not ok or type(tiers) ~= "table" or #tiers == 0 then return nil end

    local byTier = {}
    for _, info in ipairs(tiers) do
        if type(info) == "table" then
            local tier, ilvl = info.tier, info.suggestedILvl
            if type(tier) == "number" and type(ilvl) == "number"
                    and tier >= 1 and tier <= #self.TierData and ilvl > 0 then
                byTier[tier] = math.floor(ilvl)
            end
        end
    end

    return next(byTier) and byTier or nil
end

-- Both recommended-tier scans keep the LAST row the player's ilvl clears, so a
-- non-ascending ladder silently recommends the wrong tier. A partial read merges
-- into the shipped rows, so it is the MERGED result that has to ascend.
-- Returns ok, changed -- the two are separate because a rejected ladder and an
-- identical one are both "not changed" but only one may be cached.
function E:ApplyTierData(byTier)
    if type(byTier) ~= "table" then return false, false end

    local merged, changed = {}, false
    for tier, td in ipairs(self.TierData) do
        local ilvl = byTier[tier]
        if type(ilvl) ~= "number" then ilvl = td.recGear end
        if tier > 1 and ilvl < merged[tier - 1] then return false, false end
        merged[tier] = ilvl
        if ilvl ~= td.recGear then changed = true end
    end

    for tier, ilvl in ipairs(merged) do
        self.TierData[tier].recGear = ilvl
    end
    return true, changed
end

function E:RefreshTierDataFromGame()
    local byTier = self:ReadLiveTierData()
    if not byTier then return false end
    local ok, changed = self:ApplyTierData(byTier)
    if not ok then return false end

    -- Cache only a ladder covering every tier. A partial one would be merged
    -- with next season's stale shipped rows at login and read as a whole.
    local complete = true
    for tier = 1, #self.TierData do
        if type(byTier[tier]) ~= "number" then complete = false break end
    end

    local season = CurrentSeason()
    if complete and self.db and season then
        -- Stamped with the build too: the season number advances at patch day
        -- while the ladder is still the old season's, so season alone would
        -- restore a pre-season capture as if it were current.
        self.db.tierCache = {
            season  = season,
            build   = select(2, GetBuildInfo()),
            recGear = byTier,
        }
    end
    if changed and self.FireCallback then self:FireCallback("TierDataChanged") end
    return true
end

-- A cache from another season or another build is worse than the shipped table,
-- and so is one we cannot date, so every leg has to match before it is trusted.
function E:RestoreCachedTierData()
    local cache = self.db and self.db.tierCache
    if type(cache) ~= "table" or type(cache.recGear) ~= "table" then return false end
    local season = CurrentSeason()
    if not season or cache.season ~= season then return false end
    if cache.build ~= select(2, GetBuildInfo()) then return false end
    local ok = self:ApplyTierData(cache.recGear)
    return ok
end

function E:GetTierColor(tier)
    if tier <= 4 then
        return self.Colors.green
    elseif tier <= 8 then
        return self.Colors.yellow
    else
        return self.Colors.red
    end
end

function E:GetTierCC(tier)
    if tier <= 4 then
        return self.CC.green
    elseif tier <= 8 then
        return self.CC.yellow
    else
        return self.CC.red
    end
end

-- Story-grade letter colors; mirror TabCurrentBountiful's TIER_COLORS.
local GRADE_CC = {
    S = "|cFFFFD600", A = "|cFF33D933", B = "|cFF19CCE6",
    C = "|cFFD9BF19", D = "|cFF8C8C8C", F = "|cFF733333",
}
function E:GetGradeCC(letter)
    return GRADE_CC[letter] or "|cFFAAAAAA"
end

-- Champion/Hero are both Epic quality, so distinct track colors are used
-- rather than the quality color.
local TRACK_CC = {
    Adventurer = "|cFF1EFF00",
    Veteran    = "|cFF0070DD",
    Champion   = "|cFFA335EE",
    Hero       = "|cFFE268FF",
    Myth       = "|cFFFF8000",
}

-- Season 2 track tops. Only a last-resort fallback: the bands overlap, so this
-- under-names any item level that two tracks share. Pass the stored track name
-- whenever the caller has one.
local TRACK_TOPS = {
    { max = 282, name = "Adventurer" },
    { max = 295, name = "Veteran"    },
    { max = 308, name = "Champion"   },
    { max = 321, name = "Hero"       },
}
function E:GetLootTrack(ilvl, track)
    if track and TRACK_CC[track] then return track, TRACK_CC[track] end
    ilvl = tonumber(ilvl) or 0
    for _, t in ipairs(TRACK_TOPS) do
        if ilvl <= t.max then return t.name, TRACK_CC[t.name] end
    end
    return "Myth", TRACK_CC.Myth
end

-- trackable = true means completion is queryable via the quest API.
E.ShardSources = {
    {
        -- weeklyMax=1 (100 shards once/wk), NOT 7: the 7 is the seasonal
        -- Hara'ti relic count (questLine 6015), which would bust the 600/wk cap.
        name         = "Legends of the Haranir",
        shardsEach   = 100,
        weeklyMax    = 1,
        trackable    = true,
        questLineID  = 6015,
    },
    {
        -- Track the weekly meta 93889, not the daily activity 91966.
        name        = "Saltheril's Soiree",
        shardsEach  = 30,
        weeklyMax   = 3,
        trackable   = true,
        questIDs    = { 93889 },
    },
    {
        -- Repeatable with no per-source cap; bounded only by 600/wk.
        name         = L["Prey Quests"],
        shardsEach   = 75,
        weeklyMax    = nil,
        trackable    = true,
        questLineID  = 5945,
    },
    {
        name        = L["World Map Rares"],
        shardsEach  = 50,
        weeklyMax   = nil,
        trackable   = false,
    },
    {
        name        = L["World Quests"],
        shardsEach  = 50,
        weeklyMax   = nil,
        trackable   = false,
    },
    {
        name        = L["World Map Treasures"],
        shardsEach  = "11-14",
        weeklyMax   = nil,
        unconfirmed = true,
        trackable   = false,
    },
    {
        name        = L["Abundance Events"],
        shardsEach  = 13,
        weeklyMax   = nil,
        unconfirmed = true,
        trackable   = false,
    },
}

E.CurrencyIDs = {
    cofferKeyShards = 3310,
    bountifulKeys   = 3028,
    undercoins      = 2803,
}

-- Season 2 Mistcrests, all five read off a live client on 2026-08-18. Always
-- read the cap live (info.maxQuantity): a hotfix can drop it to 0 (uncapped).
-- label is only a fallback, the display name comes from the currency API.
-- Season 1 Dawncrests were 3383/3341/3343/3345/3347.
-- ⚠️ 3440 and 3441 also resolve, with the SAME display names as Hero and Myth
-- below, but maxQuantity 0 and discovered false. Five consecutive IDs from the
-- first Mistcrest picks up those two decoys instead of the real currencies.
E.Crests = {
    { id = 3442, label = "Adventurer Mistcrest" },
    { id = 3443, label = "Veteran Mistcrest"    },
    { id = 3444, label = "Champion Mistcrest"   },
    { id = 3445, label = "Hero Mistcrest"       },
    { id = 3446, label = "Myth Mistcrest"       },
}

E.SHARDS_PER_KEY      = 100

E.ItemIcons = {
    cofferKey   = 224172,
    cofferShard = 236096,
}

-- Resolved once at load to avoid per-refresh API calls.
E.CachedIcons = {
    cofferKey   = C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(224172) or nil,
    cofferShard = C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(236096) or nil,
}

E.AccentColors = {
    red      = { r = 0.55, g = 0.00, b = 0.00, hex = "8B0000" },
    gold     = { r = 1.00, g = 0.82, b = 0.00, hex = "FFD100" },
    purple   = { r = 0.42, g = 0.05, b = 0.68, hex = "6A0DAD" },
    green    = { r = 0.00, g = 0.39, b = 0.00, hex = "006400" },
    darkblue = { r = 0.00, g = 0.19, b = 0.56, hex = "00308F" },
}

E.AccentPresets = {
    red = {
        border      = { r = 0.55, g = 0.00, b = 0.00, a = 1.00 },
        divider     = { r = 0.55, g = 0.00, b = 0.00, a = 0.80 },
        tabActive   = { r = 0.55, g = 0.00, b = 0.00, a = 1.00 },
        tabBorder   = { r = 0.70, g = 0.00, b = 0.00, a = 1.00 },
        tabHover    = { r = 0.30, g = 0.00, b = 0.00, a = 0.80 },
        header      = { r = 1.00, g = 0.13, b = 0.13, a = 1.00 },
        headerCC    = "|cFFFF2222",
        buttonBg    = { r = 0.40, g = 0.00, b = 0.00, a = 1.00 },
        buttonHover = { r = 0.55, g = 0.05, b = 0.05, a = 1.00 },
        progressFill= { r = 0.55, g = 0.00, b = 0.00, a = 0.90 },
        scrollThumb = { r = 0.55, g = 0.00, b = 0.00, a = 0.80 },
        closeBg     = { r = 0.30, g = 0.00, b = 0.00, a = 0.80 },
        closeHover  = { r = 0.55, g = 0.05, b = 0.05, a = 1.00 },
    },
    gold = {
        border      = { r = 1.00, g = 0.82, b = 0.00, a = 1.00 },
        divider     = { r = 1.00, g = 0.82, b = 0.00, a = 0.80 },
        tabActive   = { r = 0.78, g = 0.61, b = 0.04, a = 1.00 },
        tabBorder   = { r = 1.00, g = 0.82, b = 0.00, a = 1.00 },
        tabHover    = { r = 0.50, g = 0.40, b = 0.00, a = 0.80 },
        header      = { r = 1.00, g = 0.84, b = 0.00, a = 1.00 },
        headerCC    = "|cFFFFD100",
        buttonBg    = { r = 0.45, g = 0.36, b = 0.00, a = 1.00 },
        buttonHover = { r = 0.78, g = 0.61, b = 0.04, a = 1.00 },
        progressFill= { r = 0.78, g = 0.61, b = 0.04, a = 0.90 },
        scrollThumb = { r = 0.78, g = 0.61, b = 0.04, a = 0.80 },
        closeBg     = { r = 0.40, g = 0.32, b = 0.00, a = 0.80 },
        closeHover  = { r = 0.78, g = 0.61, b = 0.04, a = 1.00 },
    },
    purple = {
        border      = { r = 0.42, g = 0.05, b = 0.68, a = 1.00 },
        divider     = { r = 0.42, g = 0.05, b = 0.68, a = 0.80 },
        tabActive   = { r = 0.42, g = 0.05, b = 0.68, a = 1.00 },
        tabBorder   = { r = 0.55, g = 0.10, b = 0.80, a = 1.00 },
        tabHover    = { r = 0.25, g = 0.03, b = 0.40, a = 0.80 },
        header      = { r = 0.70, g = 0.50, b = 1.00, a = 1.00 },
        headerCC    = "|cFFB280FF",
        buttonBg    = { r = 0.30, g = 0.04, b = 0.50, a = 1.00 },
        buttonHover = { r = 0.50, g = 0.10, b = 0.75, a = 1.00 },
        progressFill= { r = 0.42, g = 0.05, b = 0.68, a = 0.90 },
        scrollThumb = { r = 0.42, g = 0.05, b = 0.68, a = 0.80 },
        closeBg     = { r = 0.22, g = 0.02, b = 0.36, a = 0.80 },
        closeHover  = { r = 0.50, g = 0.10, b = 0.75, a = 1.00 },
    },
    green = {
        border      = { r = 0.00, g = 0.39, b = 0.00, a = 1.00 },
        divider     = { r = 0.00, g = 0.39, b = 0.00, a = 0.80 },
        tabActive   = { r = 0.00, g = 0.45, b = 0.00, a = 1.00 },
        tabBorder   = { r = 0.10, g = 0.55, b = 0.10, a = 1.00 },
        tabHover    = { r = 0.00, g = 0.25, b = 0.00, a = 0.80 },
        header      = { r = 0.30, g = 0.85, b = 0.30, a = 1.00 },
        headerCC    = "|cFF4CD94C",
        buttonBg    = { r = 0.00, g = 0.30, b = 0.00, a = 1.00 },
        buttonHover = { r = 0.05, g = 0.45, b = 0.05, a = 1.00 },
        progressFill= { r = 0.00, g = 0.45, b = 0.00, a = 0.90 },
        scrollThumb = { r = 0.00, g = 0.45, b = 0.00, a = 0.80 },
        closeBg     = { r = 0.00, g = 0.22, b = 0.00, a = 0.80 },
        closeHover  = { r = 0.05, g = 0.45, b = 0.05, a = 1.00 },
    },
    darkblue = {
        border      = { r = 0.00, g = 0.19, b = 0.56, a = 1.00 },
        divider     = { r = 0.00, g = 0.19, b = 0.56, a = 0.80 },
        tabActive   = { r = 0.00, g = 0.22, b = 0.60, a = 1.00 },
        tabBorder   = { r = 0.10, g = 0.30, b = 0.70, a = 1.00 },
        tabHover    = { r = 0.00, g = 0.12, b = 0.35, a = 0.80 },
        header      = { r = 0.20, g = 0.55, b = 1.00, a = 1.00 },
        headerCC    = "|cFF3388FF",
        buttonBg    = { r = 0.00, g = 0.15, b = 0.45, a = 1.00 },
        buttonHover = { r = 0.00, g = 0.22, b = 0.60, a = 1.00 },
        progressFill= { r = 0.00, g = 0.22, b = 0.60, a = 0.90 },
        scrollThumb = { r = 0.00, g = 0.22, b = 0.60, a = 0.80 },
        closeBg     = { r = 0.00, g = 0.10, b = 0.32, a = 0.80 },
        closeHover  = { r = 0.00, g = 0.22, b = 0.60, a = 1.00 },
    },
}

local function ShadeClass(c, f, a)
    return { r = c.r * f, g = c.g * f, b = c.b * f, a = a or 1.00 }
end

local function PlayerClassColor()
    local _, classFile = UnitClass("player")
    if not classFile then return nil end
    -- Both overriding conventions before the C API, which only ever returns
    -- Blizzard's own values and so would mask either one.
    local c = (CUSTOM_CLASS_COLORS and CUSTOM_CLASS_COLORS[classFile])
        or (RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile])
        or (C_ClassColor and C_ClassColor.GetClassColor
            and C_ClassColor.GetClassColor(classFile))
    if type(c) ~= "table" or type(c.r) ~= "number" then return nil end
    return c
end

-- Built on first use, not at load: first use is PLAYER_LOGIN, by which point a
-- UI that replaces the class colors is already up.
function E:EnsureClassAccent()
    if self.AccentPresets.class then return true end
    local c = PlayerClassColor()
    if not c then return false end

    local hex = string.format("%02X%02X%02X",
        math.floor(c.r * 255 + 0.5),
        math.floor(c.g * 255 + 0.5),
        math.floor(c.b * 255 + 0.5))

    self.AccentColors.class = { r = c.r, g = c.g, b = c.b, hex = hex }
    self.AccentPresets.class = {
        border      = ShadeClass(c, 0.80),
        divider     = ShadeClass(c, 0.80, 0.80),
        tabActive   = ShadeClass(c, 0.45),
        tabBorder   = ShadeClass(c, 0.85),
        tabHover    = ShadeClass(c, 0.28, 0.80),
        header      = ShadeClass(c, 1.00),
        headerCC    = "|cFF" .. hex,
        buttonBg    = ShadeClass(c, 0.35),
        buttonHover = ShadeClass(c, 0.55),
        progressFill= ShadeClass(c, 0.60, 0.90),
        scrollThumb = ShadeClass(c, 0.60, 0.80),
        closeBg     = ShadeClass(c, 0.28, 0.80),
        closeHover  = ShadeClass(c, 0.55),
    }
    return true
end

function E:GetClassAccentColor()
    if self:EnsureClassAccent() then return self.AccentColors.class end
    return self.AccentColors.gold
end

E.ThemedWidgets = {}

-- Invoked immediately so the widget picks up the current theme.
function E:RegisterThemed(fn)
    if type(fn) ~= "function" then return end
    self.ThemedWidgets[#self.ThemedWidgets + 1] = fn
    fn(self:GetAccentPreset())
end

function E:GetAccentPreset()
    local key = (self.db and self.db.accentColor) or "gold"
    if key == "class" then self:EnsureClassAccent() end
    return self.AccentPresets[key] or self.AccentPresets.gold
end

function E:GetAccentColor()
    local key = (self.db and self.db.accentColor) or "gold"
    if key == "class" then self:EnsureClassAccent() end
    return self.AccentColors[key] or self.AccentColors.gold
end

-- Mutates E.Colors/E.CC in place so existing reads stay valid.
function E:ApplyAccentColor(name)
    if name == "class" then self:EnsureClassAccent() end
    if name and self.AccentPresets[name] then
        if self.db then self.db.accentColor = name end
    end

    -- Compared as the resolved preset, not the name, so a class accent that fell
    -- back to gold still repaints once the class preset can be built.
    local p = self:GetAccentPreset()
    if self._lastAppliedPreset == p then return end
    self._lastAppliedPreset = p

    local function copy(dst, src)
        dst.r, dst.g, dst.b, dst.a = src.r, src.g, src.b, src.a
    end
    copy(self.Colors.border,      p.border)
    copy(self.Colors.divider,     p.divider)
    copy(self.Colors.tabActive,   p.tabActive)
    copy(self.Colors.header,      p.header)
    -- Buttons are intentionally hardcoded, not copied from the accent preset.
    self.CC.header = p.headerCC

    local list = self.ThemedWidgets
    for i = 1, #list do
        list[i](p)
    end
end
