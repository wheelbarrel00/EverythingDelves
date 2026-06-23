local E = EverythingDelves

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
    "Delve Locations",
    "Current Bountiful Delves",
    "Tier Guide",
    "Nullaeus",
    "Shard Tracker",
    "Delve History",
    "Delver's Call",
    "Roster",
    "Options",
    "Profiles",
    "About",
}
E.NUM_TABS = #E.TAB_NAMES

-- index == tier number (1-11); Midnight Season 1 iLvl references, static for S1.
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

-- Midnight S1 delve reward tracks by item level (Adventurer 220-230,
-- Veteran 233-243, Champion 246-256, Hero 259). Champion/Hero are both Epic
-- quality, so distinct track colors are used rather than the quality color.
local LOOT_TRACKS = {
    { max = 232, name = "Adventurer", cc = "|cFF1EFF00" },
    { max = 244, name = "Veteran",    cc = "|cFF0070DD" },
    { max = 256, name = "Champion",   cc = "|cFFA335EE" },
    { max = 271, name = "Hero",       cc = "|cFFE268FF" },
}
function E:GetLootTrack(ilvl)
    ilvl = tonumber(ilvl) or 0
    for _, t in ipairs(LOOT_TRACKS) do
        if ilvl <= t.max then return t.name, t.cc end
    end
    return "Myth", "|cFFFF8000"
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
        name         = "Prey Quests",
        shardsEach   = 75,
        weeklyMax    = nil,
        trackable    = true,
        questLineID  = 5945,
    },
    {
        name        = "World Map Rares",
        shardsEach  = 50,
        weeklyMax   = nil,
        trackable   = false,
    },
    {
        name        = "World Quests",
        shardsEach  = 50,
        weeklyMax   = nil,
        trackable   = false,
    },
    {
        name        = "World Map Treasures",
        shardsEach  = "11-14",
        weeklyMax   = nil,
        unconfirmed = true,
        trackable   = false,
    },
    {
        name        = "Abundance Events",
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

-- Always read the cap live (info.maxQuantity): a 2026-05-19 hotfix removed the
-- weekly caps, so maxQuantity reads 0 (uncapped). Never hardcode it. label is
-- only a fallback; the display name is read live from the currency API.
E.Dawncrests = {
    { id = 3383, label = "Adventurer Dawncrest" },
    { id = 3341, label = "Veteran Dawncrest"    },
    { id = 3343, label = "Champion Dawncrest"   },
    { id = 3345, label = "Hero Dawncrest"       },
    { id = 3347, label = "Myth Dawncrest"       },
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

E.ThemedWidgets = {}

-- Invoked immediately so the widget picks up the current theme.
function E:RegisterThemed(fn)
    if type(fn) ~= "function" then return end
    self.ThemedWidgets[#self.ThemedWidgets + 1] = fn
    fn(self:GetAccentPreset())
end

function E:GetAccentPreset()
    local key = (self.db and self.db.accentColor) or "gold"
    return self.AccentPresets[key] or self.AccentPresets.gold
end

function E:GetAccentColor()
    local key = (self.db and self.db.accentColor) or "gold"
    return self.AccentColors[key] or self.AccentColors.gold
end

-- Mutates E.Colors/E.CC in place so existing reads stay valid.
function E:ApplyAccentColor(name)
    if name and self.AccentPresets[name] then
        if self.db then self.db.accentColor = name end
    end
    -- Skip the full repaint if the accent is already active.
    local applied = name or (self.db and self.db.accentColor) or "gold"
    if self._lastAppliedAccent == applied then return end
    self._lastAppliedAccent = applied

    local p = self:GetAccentPreset()

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
