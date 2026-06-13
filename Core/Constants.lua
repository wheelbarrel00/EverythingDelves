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
    "Nullaeus",
    "Shard Tracker",
    "Delve History",
    "Delver's Call",
    "Options",
    "Profiles",
    "About",
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
        -- "Legends of the Haranir" weekly world event (Harandar zone): the
        -- weekly "Lost Legends" relic scenario grants 100 shards, ONCE per
        -- week (weeklyMax=1) - NOT 7. The old "7" mistook the 7 seasonal
        -- Hara'ti relics for a weekly count, producing a bogus "700" that
        -- exceeds the 600/wk cap. questLine 6015 IS those 7 relics, so the
        -- Status column reads SEASONAL relic progress (X/7) - cumulative,
        -- does not reset weekly.
        name         = "Legends of the Haranir",
        shardsEach   = 100,
        weeklyMax    = 1,
        trackable    = true,
        questLineID  = 6015,  -- C_QuestLine.GetQuestLineQuests(6015) = 7 relics
    },
    {
        -- Saltheril's Soiree: favors at the Soiree give ~30 shards each
        -- (~3/wk = ~90 total). The shard-granting favor quests are per-
        -- faction and aren't cleanly indexed, so we track the WEEKLY META
        -- instead: "Midnight: Saltheril's Soiree" (93889), completed by
        -- doing those favors (analogous to "Midnight: Delves" 93909).
        -- 91966 is the DAILY activity (resets daily), not a weekly source,
        -- so it is NOT tracked here. Status reflects the weekly meta
        -- (0/1 -> done); the "3x" cap is the favor estimate. Confirm 93889
        -- resets on the weekly reset in-game.
        name        = "Saltheril's Soiree",
        shardsEach  = 30,
        weeklyMax   = 3,
        trackable   = true,
        questIDs    = { 93889 },
    },
    {
        name         = "Prey Quests",
        shardsEach   = 75,
        -- 75/hunt confirmed (all difficulties). No documented per-week
        -- count - repeatable, bounded only by the 600/wk cap - so no
        -- per-source cap is shown (the old "8" was just 600/75).
        weeklyMax    = nil,
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
        name        = "World Quests",
        shardsEach  = 50,   -- when shards are the listed reward
        weeklyMax   = nil,
        trackable   = false,
    },
    {
        name        = "World Map Treasures",
        shardsEach  = "11-14",   -- farming-guide range (wiki cited ~5)
        weeklyMax   = nil,
        unconfirmed = true,
        trackable   = false,
    },
    {
        name        = "Abundance Events",
        shardsEach  = 13,   -- ~13/run with the Shard of Dundun
        weeklyMax   = nil,
        unconfirmed = true,
        trackable   = false,
    },
}

------------------------------------------------------------------------
-- Currency IDs (Midnight 12.0 Season 1)
-- Queryable via C_CurrencyInfo.GetCurrencyInfo(id)
------------------------------------------------------------------------
E.CurrencyIDs = {
    cofferKeyShards = 3310,
    bountifulKeys   = 3028,
    undercoins      = 2803,
}

------------------------------------------------------------------------
-- Dawncrest currency IDs (Midnight 12.0 Season 1 upgrade crests)
-- Ordered lowest -> highest tier. Seasonal cap mechanics: the cap
-- rides on info.maxQuantity and counts info.totalEarned (the
-- season-lifetime total; info.useTotalEarnedForMaxQty), with no
-- separate weekly field. Season 1 launched with +100/week escalating
-- caps, but the 2026-05-19 hotfix removed them for the rest of the
-- season — maxQuantity reads 0 (uncapped) live since then. Always
-- read the cap live; never hardcode it.
-- The display name is read live from the currency API; the label here
-- is only a fallback for undiscovered currencies.
------------------------------------------------------------------------
E.Dawncrests = {
    { id = 3383, label = "Adventurer Dawncrest" },
    { id = 3341, label = "Veteran Dawncrest"    },
    { id = 3343, label = "Champion Dawncrest"   },
    { id = 3345, label = "Hero Dawncrest"       },
    { id = 3347, label = "Myth Dawncrest"       },
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
