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

    -- Buttons (HARDCODED — not affected by accent color profile).
    -- bg #6D0501, hover #8A0601 (slightly lighter for OnEnter feedback).
    buttonBg    = { r = 0.427, g = 0.020, b = 0.004, a = 1.00 },
    buttonHover = { r = 0.541, g = 0.024, b = 0.004, a = 1.00 },

    -- Permanent grey divider line color (#4A4A4A). Used for column-
    -- header separators that should NOT change with accent color.
    greyLine    = { r = 0.290, g = 0.290, b = 0.290, a = 1.00 },
}

-- Unified header font size used by all section headers via
-- StyleAccentHeader. Section headers across every tab share this size
-- so visual hierarchy stays consistent.
E.HEADER_FONT_SIZE = 20

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
    btnText = "|cFFEBB706",  -- hardcoded button label colour (#EBB706)
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
    "Delve History",
    "Options",
    "Profiles",
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
-- Single source of truth for the entire addon's accent theme.
-- E:ApplyAccentColor(name) mutates E.Colors / E.CC in place from these
-- and walks the registered themed-widget list to repaint everything.
------------------------------------------------------------------------
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

------------------------------------------------------------------------
-- Theme registry
-- Widgets that need to repaint on accent change call E:RegisterThemed(fn).
-- The callback receives the active preset table and is invoked once at
-- registration time and again whenever E:ApplyAccentColor() is called.
------------------------------------------------------------------------
E.ThemedWidgets = {}

--- Register a repaint callback. The function is also invoked
--- immediately so the widget picks up the current theme.
--- @param fn fun(preset: table)
function E:RegisterThemed(fn)
    if type(fn) ~= "function" then return end
    self.ThemedWidgets[#self.ThemedWidgets + 1] = fn
    fn(self:GetAccentPreset())
end

--- Get the currently-selected accent preset table.
function E:GetAccentPreset()
    local key = (self.db and self.db.accentColor) or "gold"
    return self.AccentPresets[key] or self.AccentPresets.gold
end

--- Get the simple {r,g,b,hex} accent color (per the public AccentColors).
function E:GetAccentColor()
    local key = (self.db and self.db.accentColor) or "gold"
    return self.AccentColors[key] or self.AccentColors.gold
end

--- Apply an accent color theme. Mutates E.Colors and E.CC in place
--- (so any code that read them previously stays consistent) and
--- invokes every registered repaint callback.
--- @param name string|nil  "red" | "gold" | "purple" | "green" | "darkblue"
function E:ApplyAccentColor(name)
    if name and self.AccentPresets[name] then
        if self.db then self.db.accentColor = name end
    end
    -- Short-circuit if the requested color is already active. Repainting
    -- the entire ThemedWidgets list is wasted work in that case.
    local applied = name or (self.db and self.db.accentColor) or "gold"
    if self._lastAppliedAccent == applied then return end
    self._lastAppliedAccent = applied

    local p = self:GetAccentPreset()

    -- Mutate live color tables in place.
    local function copy(dst, src)
        dst.r, dst.g, dst.b, dst.a = src.r, src.g, src.b, src.a
    end
    copy(self.Colors.border,      p.border)
    copy(self.Colors.divider,     p.divider)
    copy(self.Colors.tabActive,   p.tabActive)
    copy(self.Colors.header,      p.header)
    -- Buttons are hardcoded (#6D0501 / #EBB706) and intentionally not
    -- copied from the accent preset.
    self.CC.header = p.headerCC

    -- Repaint every registered widget.
    local list = self.ThemedWidgets
    for i = 1, #list do
        list[i](p)
    end
end
