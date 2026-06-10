------------------------------------------------------------------------
-- Core/Utils.lua
-- Shared utility functions used across multiple tabs
------------------------------------------------------------------------
---@diagnostic disable: undefined-global, undefined-field
local E = EverythingDelves

------------------------------------------------------------------------
-- Local references for frequently accessed globals
------------------------------------------------------------------------
local math_floor, math_max, math_min = math.floor, math.max, math.min
local string_format = string.format
local tostring = tostring

------------------------------------------------------------------------
-- UI factory: flat dark-red button with hover highlight
------------------------------------------------------------------------
--- Create a styled button that matches the addon's visual theme.
--- @param parent Frame   Parent frame
--- @param width  number  Button width
--- @param height number  Button height
--- @param label  string  Display text
--- @return Button
function E:CreateButton(parent, width, height, label)
    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetSize(width, height)
    btn:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })

    -- HARDCODED colours: #6D0501 background, #EBB706 label, dark border.
    -- Buttons intentionally do NOT follow the accent-colour profile.
    local bg = E.Colors.buttonBg
    btn:SetBackdropColor(bg.r, bg.g, bg.b, bg.a)
    btn:SetBackdropBorderColor(0.10, 0.00, 0.00, 1.00)

    local text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetPoint("CENTER")
    text:SetFont(text:GetFont(), 11)
    text:SetText(label)
    -- #EBB706 (gold) label colour. SetTextColor (no inline |cFF code) so
    -- dim states can override the colour reliably.
    text:SetTextColor(0.922, 0.718, 0.024, 1.0)
    btn.label = text

    btn:SetScript("OnEnter", function(self)
        if self.dimmed then return end
        local hc = E.Colors.buttonHover
        self:SetBackdropColor(hc.r, hc.g, hc.b, hc.a)
    end)
    btn:SetScript("OnLeave", function(self)
        if self.dimmed then return end
        local bc = E.Colors.buttonBg
        self:SetBackdropColor(bc.r, bc.g, bc.b, bc.a)
    end)

    return btn
end

------------------------------------------------------------------------
-- TomTom integration helpers
------------------------------------------------------------------------
--- Check whether the TomTom addon is available and functional.
function E:IsTomTomLoaded()
    return (TomTom and TomTom.AddWaypoint) and true or false
end

--- Add a TomTom waypoint. Returns false and prints a warning if TomTom
--- is not loaded. Coordinates are in percentage form (e.g. 45.4).
--- @param mapID number  uiMapID
--- @param x     number  percentage (0-100)
--- @param y     number  percentage (0-100)
--- @param title string  Waypoint label
function E:AddTomTomWaypoint(mapID, x, y, title)
    if not self:IsTomTomLoaded() then
        print(E.CC.header .. "Everything Delves|r: TomTom is not installed.")
        return false
    end
    TomTom:AddWaypoint(mapID, x / 100, y / 100, { title = title })
    return true
end

------------------------------------------------------------------------
-- Blizzard map waypoint helper
------------------------------------------------------------------------
--- Set a Blizzard user waypoint (the built-in map pin).
--- C_Map.SetUserWaypoint() takes a UiMapPoint table:
---   { uiMapID = number, position = { x, y } }
--- C_SuperTrack.SetSuperTrackedUserWaypoint(true) makes the waypoint
--- show as the golden navigation arrow on-screen.
--- Set a Blizzard user waypoint (the built-in map pin).
--- Coordinates are in percentage form (e.g. 45.4 means 45.4% of the map).
--- C_Map.SetUserWaypoint() expects 0-1 range, so we divide by 100.
--- @param mapID number
--- @param x     number  percentage (0-100)
--- @param y     number  percentage (0-100)
function E:SetWaypoint(mapID, x, y)
    -- C_Map.SetUserWaypoint is confirmed available in Midnight 12.0.
    if C_Map and C_Map.SetUserWaypoint then
        local ok, err = pcall(function()
            local point = UiMapPoint.CreateFromCoordinates(mapID, x / 100, y / 100)
            C_Map.SetUserWaypoint(point)
            -- Make the waypoint the actively-tracked objective
            if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then
                C_SuperTrack.SetSuperTrackedUserWaypoint(true)
            end
        end)
        if not ok then
            print("|cFFFF2222[Everything Delves]|r Could not set waypoint: " .. tostring(err))
        end
    else
        print(E.CC.header .. "Everything Delves|r: Waypoint API unavailable.")
    end
end

------------------------------------------------------------------------
-- Tooltip helpers
------------------------------------------------------------------------

--- Flash a button's label to "Done!" in green, then restore after 1.5s.
--- @param btn Button  Must have a .label FontString
function E:FlashButtonConfirm(btn)
    if not btn or not btn.label then return end
    local original = btn.label:GetText()
    btn.label:SetText("|cFF00FF00Set!|r")
    C_Timer.After(1.5, function()
        if btn.label then
            btn.label:SetText(original)
        end
    end)
end

--- Show a simple tooltip anchored to a frame.
--- @param owner    Frame
--- @param title    string
--- @param ...      string  Additional lines
function E:ShowTooltip(owner, title, ...)
    GameTooltip:SetOwner(owner, "ANCHOR_CURSOR")
    GameTooltip:AddLine(title, 1, 0.84, 0, true) -- gold
    for i = 1, select("#", ...) do
        local line = select(i, ...)
        if line and line ~= "" then
            GameTooltip:AddLine(line, 0.88, 0.88, 0.88, true) -- off-white, wrap
        end
    end
    GameTooltip:Show()
end

function E:HideTooltip()
    GameTooltip:Hide()
end

------------------------------------------------------------------------
-- Progress bar factory (shared by multiple tabs)
------------------------------------------------------------------------
--- Create a themed progress bar with a fill texture and a value label.
--- The returned frame has a :SetProgress(current, max) method.
--- When `caption` is supplied, a left-aligned title is drawn inside the
--- bar (e.g. "Weekly Bountiful") and the numeric value moves to the
--- right so the two never overlap; without it the value stays centered
--- (backward-compatible with existing call sites).
--- @param parent Frame
--- @param width  number  Bar width in pixels, or 0 for anchor-based sizing
--- @param height number
--- @param caption string|nil  Optional left-aligned bar title
--- @return Frame
function E:CreateProgressBar(parent, width, height, caption)
    local bar = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    if width and width > 0 then
        bar:SetSize(width, height)
    else
        bar:SetHeight(height)
    end
    bar:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    bar:SetBackdropColor(0.10, 0.10, 0.10, 1)
    bar:SetBackdropBorderColor(0.30, 0.30, 0.30, 0.60)

    local fill = bar:CreateTexture(nil, "ARTWORK")
    fill:SetPoint("TOPLEFT", bar, "TOPLEFT", 1, -1)
    fill:SetHeight(height - 2)
    bar.fill = fill

    -- Theme: accent-driven fill color. Tabs that need a status-driven
    -- override (e.g. gold-when-complete) just call fill:SetColorTexture
    -- directly; the next ApplyAccentColor will re-paint back to accent.
    E:RegisterThemed(function(p)
        if fill.SetColorTexture then
            fill:SetColorTexture(p.progressFill.r, p.progressFill.g,
                                 p.progressFill.b, p.progressFill.a)
        end
    end)

    local label = bar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetFont(label:GetFont(), 10, "OUTLINE")
    bar.label = label

    -- With a caption, draw the title on the left and push the numeric
    -- value to the right edge so they share the bar without overlapping.
    -- Without one, keep the value centered (legacy behaviour).
    if caption and caption ~= "" then
        local cap = bar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        cap:SetPoint("LEFT", bar, "LEFT", 6, 0)
        cap:SetFont(cap:GetFont(), 10, "OUTLINE")
        cap:SetText("|cFFFFFFFF" .. caption .. "|r")
        bar.caption = cap

        label:SetPoint("RIGHT", bar, "RIGHT", -6, 0)
    else
        label:SetPoint("CENTER")
    end

    --- Update the bar to show current / max progress.
    function bar:SetProgress(current, max)
        local pct = (max > 0) and (current / max) or 0
        pct = math_min(pct, 1)
        self.fill:SetWidth(math_max(1, (self:GetWidth() - 2) * pct))
        self.label:SetText(
            string_format("|cFFFFFFFF%d / %d  (%d%%)|r", current, max, math_floor(pct * 100))
        )
    end

    return bar
end

------------------------------------------------------------------------
-- Trovehunter's Bounty map detection
------------------------------------------------------------------------
-- Single source of truth for "does the player hold a bounty map", shared
-- by the entry popup and the Tier Guide status line so they can never
-- disagree. Kept as a list so a second ID can be added trivially if one
-- is ever confirmed -- a previously-suspected alternate (265714) was
-- ruled out by /dump (returns 0 for a confirmed map holder), so only the
-- proven map item (252415) is checked.
E.TROVE_MAP_ITEM_IDS = { 252415 }

--- Total count of Trovehunter's Bounty maps held across all known item
--- IDs. Bags only (not bank) on purpose: the map can only be used from
--- bags inside a delve, so a banked copy must not trip the reminder.
--- @return number
function E:GetTrovehunterMapCount()
    if not (C_Item and C_Item.GetItemCount) then return 0 end
    local total = 0
    for _, id in ipairs(E.TROVE_MAP_ITEM_IDS) do
        ---@diagnostic disable-next-line: deprecated
        total = total + (C_Item.GetItemCount(id) or 0)
    end
    return total
end

------------------------------------------------------------------------
-- Accent-theme helpers (used widely by tab modules)
------------------------------------------------------------------------

--- Set a FontString to a section-header style using the active accent
--- color, and register it for repaint when the accent changes.
--- Pass the raw text (no color codes); we wrap it.
function E:StyleAccentHeader(fs, rawText)
    if not fs or not rawText then return end
    fs:SetText(self.CC.header .. rawText .. self.CC.close)
    self:RegisterThemed(function(_)
        if fs and fs.SetText then
            fs:SetText(E.CC.header .. rawText .. E.CC.close)
        end
    end)
end

--- Color a thin horizontal divider texture with the accent divider hue
--- and register it for repaint.
function E:StyleAccentDivider(tex)
    if not tex or not tex.SetColorTexture then return end
    local d = self.Colors.divider
    tex:SetColorTexture(d.r, d.g, d.b, d.a)
    self:RegisterThemed(function(p)
        if tex and tex.SetColorTexture then
            tex:SetColorTexture(p.divider.r, p.divider.g, p.divider.b, p.divider.a)
        end
    end)
end

--- Color a horizontal line texture with the hardcoded grey (#4A4A4A).
--- Used for column-header separators that must NEVER change with the
--- accent colour profile.
function E:StyleGreyLine(tex)
    if not tex or not tex.SetColorTexture then return end
    local g = self.Colors.greyLine
    tex:SetColorTexture(g.r, g.g, g.b, g.a)
end

------------------------------------------------------------------------
-- Delve companion level / XP
------------------------------------------------------------------------
-- The companion's progression is a friendship reputation whose reaction
-- string reads "Level N" (each expansion's companion follows the same
-- pattern). Rather than hardcoding a faction ID per expansion, scan the
-- friendship faction ID range once and cache the hit account-wide; the
-- cache invalidates when the account's expansion level changes so a new
-- expansion's companion replaces the old one automatically.
-- LIMITATION: the "Level %d" reaction match is English-only (same
-- limitation as the deferred companion-localization audit finding).

local COMPANION_SCAN_FROM = 3100  -- scan DESCENDING so the newest
local COMPANION_SCAN_TO   = 2600  -- expansion's companion wins

local function ScanForCompanionFaction()
    if not (C_GossipInfo and C_GossipInfo.GetFriendshipReputation) then
        return nil
    end
    for id = COMPANION_SCAN_FROM, COMPANION_SCAN_TO, -1 do
        local ok, d = pcall(C_GossipInfo.GetFriendshipReputation, id)
        if ok and d and d.friendshipFactionID and d.friendshipFactionID > 0
                and type(d.reaction) == "string"
                and d.reaction:match("^Level %d+") then
            return id
        end
    end
    return nil
end

--- Friendship faction ID of the current expansion's delve companion.
--- Resolved by scan once, then cached account-wide (the ID itself is
--- global; only the standing is per character). Returns nil when the
--- companion isn't found (e.g. not unlocked yet) — re-scans next call.
function E:GetCompanionFactionID()
    local xpac = GetAccountExpansionLevel and GetAccountExpansionLevel() or 0
    local db = self.db
    if db and db.companionFactionID and db.companionFactionXpac == xpac then
        return db.companionFactionID
    end
    local id = ScanForCompanionFaction()
    if id and db then
        db.companionFactionID   = id
        db.companionFactionXpac = xpac
    end
    return id
end

--- Live companion progression for this character.
--- @return table|nil  { name, level, xpCurrent, xpMax, isMaxLevel }
function E:GetCompanionData()
    local id = self:GetCompanionFactionID()
    if not id then return nil end
    local ok, d = pcall(C_GossipInfo.GetFriendshipReputation, id)
    if not (ok and d and d.friendshipFactionID
            and d.friendshipFactionID > 0) then
        return nil
    end

    -- Level: prefer the ranks API; fall back to parsing the reaction.
    local level = 0
    if C_GossipInfo.GetFriendshipReputationRanks then
        local ok2, ranks = pcall(
            C_GossipInfo.GetFriendshipReputationRanks, id)
        if ok2 and ranks and ranks.currentLevel then
            level = ranks.currentLevel
        end
    end
    if level == 0 and type(d.reaction) == "string" then
        level = tonumber(d.reaction:match("(%d+)")) or 0
    end

    local floor = d.reactionThreshold or 0
    local ceil  = d.nextThreshold              -- nil at max level
    return {
        name       = (d.name and d.name ~= "") and d.name or "Companion",
        level      = level,
        xpCurrent  = (d.standing or floor) - floor,
        xpMax      = ceil and math.max(1, ceil - floor) or 0,
        isMaxLevel = (ceil == nil),
    }
end

--- Color a scrollbar thumb texture and register for repaint.
function E:StyleAccentThumb(tex)
    if not tex or not tex.SetColorTexture then return end
    self:RegisterThemed(function(p)
        if tex and tex.SetColorTexture then
            tex:SetColorTexture(p.scrollThumb.r, p.scrollThumb.g,
                                p.scrollThumb.b, p.scrollThumb.a)
        end
    end)
end

------------------------------------------------------------------------
-- Sort helpers
------------------------------------------------------------------------
--- Case-insensitive string comparison for table.sort.
function E.CompareAlpha(a, b)
    return (a or ""):lower() < (b or ""):lower()
end

------------------------------------------------------------------------
-- Delve history helpers
------------------------------------------------------------------------
--- Get history for a delve. Returns entry or nil.
--- @param delveName string
--- @return table|nil
function E:GetDelveHistory(delveName)
    if not self.db or not self.db.delveHistory then return nil end
    return self.db.delveHistory[delveName]
end
