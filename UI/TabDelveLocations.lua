------------------------------------------------------------------------
-- UI/TabDelveLocations.lua - Tab 1: Delve Locations
-- Complete directory of all Midnight delves with sorting, waypoints,
-- TomTom integration, and expandable per-delve boss tactics.
------------------------------------------------------------------------
local E = EverythingDelves

------------------------------------------------------------------------
-- Local references for frequently accessed globals
------------------------------------------------------------------------
local math_floor, math_max, math_min = math.floor, math.max, math.min
local table_insert, table_sort = table.insert, table.sort
local string_format = string.format

------------------------------------------------------------------------
-- Local state
------------------------------------------------------------------------
local filteredData   = {}  -- delves after sort (all delves; no filtering)
local sortField      = "name"  -- "name" | "zone" | "tier"
local sortAscending  = true
local ROW_HEIGHT     = 28

-- Expansion state (survives refresh). Delve-level keyed by delve name;
-- boss-level keyed by "<delveName>##<bossIndex>".
local expandedDelve  = {}
local expandedBoss   = {}

-- Today's live variant + its tier per delve, refreshed each
-- RefreshFilteredData so the badge, the sort, the Today's Story column,
-- and the tooltip all agree (and we avoid re-reading the POI per row).
local todayStoryByName = {}
local todayTierByName  = {}
-- Expected clear time (seconds) + its source ("personal"/"estimate") per
-- delve, computed alongside the tier so the Speed column, the speed sort,
-- and the summary banner all read the same values.
local todaySpeedByName  = {}
local todaySpeedSrcByName = {}

-- Reused scratch buffer for the row hover tooltip lines, wiped per hover
-- instead of allocating a fresh table on every OnEnter.
local hoverTipLines = {}

-- Cache of lower-cased / trimmed delve names so the sort comparator
-- never has to allocate ":lower()" strings inside the hot path.
local delveLowerName = {}  -- [delve] = lower(name)
local delveLowerZone = {}  -- [delve] = lower(zone)
local function GetLowerName(delve)
    local v = delveLowerName[delve]
    if v then return v end
    v = delve.name:lower()
    delveLowerName[delve] = v
    return v
end
local function GetLowerZone(delve)
    local v = delveLowerZone[delve]
    if v then return v end
    v = delve.zone:lower()
    delveLowerZone[delve] = v
    return v
end

------------------------------------------------------------------------
-- Per-delve tier and notes (Midnight Season 1)
------------------------------------------------------------------------
local DLOC_TIER_COLORS = {
    S = {1.00, 0.84, 0.00},
    A = {0.20, 0.85, 0.20},
    B = {0.10, 0.80, 0.90},
    C = {0.85, 0.75, 0.10},
    D = {0.55, 0.55, 0.55},
    F = {0.45, 0.20, 0.20},
}
local DLOC_TIER_ORDER = { S=1, A=2, B=3, C=4, D=5, F=6 }

local DELVE_NOTES = {
    ["Collegiate Calamity"] = { tier="S", story="Invasive Glow",      note="Compact layout with easy boss access. NPC debuffs boost damage — the bomb DoT scales with tier and trivializes the clear." },
    ["The Gulf of Memory"]  = { tier="A", story="Sporasaur Special",   note="Glide or use a parasol toy to reach the boss platform quickly. Kite dinos and kick spores back to break their shields." },
    ["The Darkway"]         = { tier="A", story="Ogre Powered",        note="Straightforward paths to the boss. Kill Unstable Aberrations before moving — they leash and give chase." },
    ["Parhelion Plaza"]     = { tier="A", story="Holding the Line",    note="Take the staircase down for the fastest route. Kill enemies instead of healing allies for quicker progress." },
    ["Sunkiller Sanctum"]   = { tier="B", story="Core of the Problem", note="Straight routes with easy kill objectives. Use portals in Core of the Problem to shortcut around the map." },
    ["Twilight Crypt"]      = { tier="B", story="Party Crasher",       note="Pull levers to deactivate traps before advancing — limits large pulls. Party Crasher is the most direct variant." },
    ["Atal'Aman"]           = { tier="B", story="Toadly Unbecoming",   note="Open layout adds traverse time even when mounted. Toadly Unbecoming: decurse frogs to spawn the boss." },
    ["The Shadow Enclave"]  = { tier="C", story="Traitor's Due",       note="Large unwalkable map — slow regardless of story. Use the Eye of Antenorian buff whenever it's available." },
    ["The Grudge Pit"]      = { tier="D", story="Arena Champion",      note="Compact and mountable but long RP transitions and non-combat objectives in all three variants hurt efficiency." },
    ["Shadowguard Point"]   = { tier="D", story="Calamitous",          note="Enormous mountable map with required secondary objectives. Avoid if faster options are bountiful today." },
}

-- Publish the signature story name for each delve so other tabs (the
-- History tab) can show it as a fallback when a run had no live story
-- captured. DELVE_NOTES stays the single source of truth.
E.DelveStories = E.DelveStories or {}
for delveName, info in pairs(DELVE_NOTES) do
    E.DelveStories[delveName] = info.story
end

-- Publish the signature reward tier for each delve so the speed/value
-- engine (Core/SpeedRank.lua) has a fallback tier when today's variant
-- isn't individually rated. DELVE_NOTES remains the source of truth.
E.DelveSignatureTier = E.DelveSignatureTier or {}
for delveName, info in pairs(DELVE_NOTES) do
    E.DelveSignatureTier[delveName] = info.tier
end

------------------------------------------------------------------------
-- Boss-note role colouring helpers (shared role metadata lives in
-- Core/Data.lua so both delve tabs render boss tactics identically).
------------------------------------------------------------------------
local function RoleCC(role)
    local m = E.BossRoleMeta and E.BossRoleMeta[role]
    local rgb = m and m.rgb or {0.80, 0.80, 0.85}
    return string_format("|cFF%02X%02X%02X",
        math_floor(rgb[1]*255), math_floor(rgb[2]*255), math_floor(rgb[3]*255))
end
local function RoleLabel(role)
    local m = E.BossRoleMeta and E.BossRoleMeta[role]
    return (m and m.label or "Note") .. ":"
end

------------------------------------------------------------------------
-- Sorting (all delves are shown; only ordering changes)
------------------------------------------------------------------------
local function RefreshFilteredData()
    wipe(filteredData)
    for _, delve in ipairs(E.DelveData) do
        table_insert(filteredData, delve)
    end

    -- Refresh today's variant + tier for every delve (one POI read each)
    -- so the sort and the rows below use today's live ratings, falling
    -- back to the delve's signature tier when a variant isn't rated.
    wipe(todayStoryByName)
    wipe(todayTierByName)
    wipe(todaySpeedByName)
    wipe(todaySpeedSrcByName)
    for _, delve in ipairs(E.DelveData) do
        local story = E.GetDelveStoryVariant and E:GetDelveStoryVariant(delve.name) or nil
        todayStoryByName[delve.name] = story
        local tier
        if story and story ~= "" and E.GetStoryTier then
            local si = E:GetStoryTier(story)
            tier = si and si.tier
        end
        if not tier then
            local dn = DELVE_NOTES[delve.name]
            tier = dn and dn.tier
        end
        todayTierByName[delve.name] = tier

        -- Expected clear time: the player's own average if they've run it,
        -- else a tier-based estimate. Pass today's tier so the engine
        -- doesn't re-read the POI we already have.
        if E.GetDelveSpeed then
            local secs, src = E:GetDelveSpeed(delve.name, tier)
            todaySpeedByName[delve.name]    = secs
            todaySpeedSrcByName[delve.name] = src
        end
    end

    -- Sort
    table_sort(filteredData, function(a, b)
        if sortField == "tier" then
            local oa = DLOC_TIER_ORDER[todayTierByName[a.name] or ""] or 7
            local ob = DLOC_TIER_ORDER[todayTierByName[b.name] or ""] or 7
            if oa ~= ob then
                if sortAscending then return oa < ob else return oa > ob end
            end
            return GetLowerName(a) < GetLowerName(b)
        end
        if sortField == "speed" then
            -- Quickest first when ascending. Unrankable delves (no time)
            -- always sink to the bottom regardless of direction.
            local sa = todaySpeedByName[a.name]
            local sb = todaySpeedByName[b.name]
            if sa ~= sb then
                if not sa then return false end
                if not sb then return true end
                if sortAscending then return sa < sb else return sa > sb end
            end
            return GetLowerName(a) < GetLowerName(b)
        end
        local va, vb
        if sortField == "name" then
            va, vb = GetLowerName(a), GetLowerName(b)
        elseif sortField == "zone" then
            va, vb = GetLowerZone(a), GetLowerZone(b)
        end
        if sortAscending then
            return va < vb
        else
            return va > vb
        end
    end)
end

------------------------------------------------------------------------
-- MODULE INIT - called via RegisterModule after the main frame exists
------------------------------------------------------------------------
E:RegisterModule(function()
    local frame = CreateFrame("Frame", "EverythingDelvesTab1Content")
    local TOOLBAR_Y = -4
    local LIST_Y    = -78

    -- Forward-declared rebuild so row/header click handlers can call it.
    local Refresh

    --------------------------------------------------------------------
    -- Pools (rows are re-anchored every Refresh via the Y-cursor; we
    -- never destroy frames — unused ones are hidden).
    --------------------------------------------------------------------
    local delveRowPool = {}
    local bossRowPool  = {}
    local noteLinePool = {}

    --------------------------------------------------------------------
    -- Scroll frame + scroll child
    --------------------------------------------------------------------
    local scrollFrame = CreateFrame("ScrollFrame", nil, frame)
    scrollFrame:SetPoint("TOPLEFT",     frame, "TOPLEFT",  4,   LIST_Y - 16)
    scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -22, 4)
    scrollFrame:EnableMouseWheel(true)

    local sc = CreateFrame("Frame")
    sc:SetSize(1, 1)
    scrollFrame:SetScrollChild(sc)
    scrollFrame:SetScript("OnSizeChanged", function(_, w) sc:SetWidth(w) end)
    sc:SetHeight(1)

    local scrollBar = CreateFrame("Slider", nil, scrollFrame, "BackdropTemplate")
    scrollBar:SetWidth(14)
    scrollBar:SetPoint("TOPRIGHT",    scrollFrame, "TOPRIGHT",    16, 0)
    scrollBar:SetPoint("BOTTOMRIGHT", scrollFrame, "BOTTOMRIGHT", 16, 0)
    scrollBar:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    scrollBar:SetBackdropColor(0.08, 0.08, 0.08, 0.90)
    scrollBar:SetBackdropBorderColor(0.25, 0.25, 0.25, 0.50)
    local sbThumb = scrollBar:CreateTexture(nil, "OVERLAY")
    sbThumb:SetSize(12, 40)
    E:StyleAccentThumb(sbThumb)
    scrollBar:SetThumbTexture(sbThumb)
    scrollBar:SetOrientation("VERTICAL")
    scrollBar:SetMinMaxValues(0, 1)
    scrollBar:SetValue(0)
    scrollBar:SetValueStep(1)
    scrollBar:SetObeyStepOnDrag(true)
    scrollBar:SetScript("OnValueChanged", function(_, value)
        scrollFrame:SetVerticalScroll(value)
    end)

    scrollFrame:SetScript("OnMouseWheel", function(self, delta)
        local maxScroll = math_max(0, sc:GetHeight() - self:GetHeight())
        local newVal = math_max(0, math_min(
            self:GetVerticalScroll() - delta * 30, maxScroll))
        self:SetVerticalScroll(newVal)
        scrollBar:SetValue(newVal)
    end)

    local function UpdateScrollRange()
        local maxScroll = math_max(0, sc:GetHeight() - scrollFrame:GetHeight())
        scrollBar:SetMinMaxValues(0, maxScroll)
        if maxScroll <= 0 then
            scrollBar:Hide()
        else
            scrollBar:Show()
        end
    end

    --------------------------------------------------------------------
    -- Row click handlers (shared — no per-row closures)
    --------------------------------------------------------------------
    local function DelveRow_Toggle(self)
        local d = self.delve
        if not d then return end
        expandedDelve[d.name] = not expandedDelve[d.name]
        if Refresh then Refresh() end
    end

    local function BossRow_OnClick(self)
        if not self.bossKey then return end
        expandedBoss[self.bossKey] = not expandedBoss[self.bossKey]
        if Refresh then Refresh() end
    end

    --------------------------------------------------------------------
    -- Delve row factory (all columns + waypoint buttons). Rows are
    -- re-anchored each Refresh, so the constructor only builds widgets.
    --------------------------------------------------------------------
    local function CreateDelveRow()
        local row = CreateFrame("Button", nil, sc, "BackdropTemplate")
        row:SetHeight(ROW_HEIGHT)
        row:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
        row:RegisterForClicks("LeftButtonUp")
        row:SetScript("OnClick", DelveRow_Toggle)

        -- Delve Name (caret prefix is baked into the text)
        local nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        nameText:SetPoint("LEFT", row, "LEFT", 4, 0)
        nameText:SetFont(nameText:GetFont(), 11)
        nameText:SetWidth(246)
        nameText:SetJustifyH("LEFT")
        nameText:SetWordWrap(false)
        row.nameText = nameText

        -- Zone
        local zoneText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        zoneText:SetPoint("LEFT", row, "LEFT", 256, 0)
        zoneText:SetFont(zoneText:GetFont(), 11)
        zoneText:SetWidth(120)
        zoneText:SetJustifyH("LEFT")
        zoneText:SetWordWrap(false)
        row.zoneText = zoneText

        -- Tier badge (S/A/B/C/D/F)
        local tierText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        tierText:SetPoint("LEFT", row, "LEFT", 380, 0)
        tierText:SetFont(tierText:GetFont(), 11, "OUTLINE")
        tierText:SetWidth(30)
        tierText:SetJustifyH("CENTER")
        row.tierText = tierText

        -- [Pin] button
        local wpBtn = E:CreateButton(row, 32, 20, "Pin")
        wpBtn.label:SetFont(wpBtn.label:GetFont(), 10)
        wpBtn:SetPoint("LEFT", row, "LEFT", 422, 0)
        wpBtn:SetScript("OnClick", function()
            if row.delve then
                E:SetWaypoint(row.delve.mapID, row.delve.x, row.delve.y)
                E:FlashButtonConfirm(wpBtn)
            end
        end)
        wpBtn:SetScript("OnEnter", function(self)
            local hc = E.Colors.buttonHover
            self:SetBackdropColor(hc.r, hc.g, hc.b, hc.a)
            E:ShowTooltip(self, "Set Waypoint",
                          "Places a Blizzard map pin on this delve's location.")
        end)
        wpBtn:SetScript("OnLeave", function(self)
            local bc = E.Colors.buttonBg
            self:SetBackdropColor(bc.r, bc.g, bc.b, bc.a)
            E:HideTooltip()
        end)
        row.wpBtn = wpBtn

        -- [TomTom] button
        local ttBtn = E:CreateButton(row, 50, 20, "TomTom")
        ttBtn.label:SetFont(ttBtn.label:GetFont(), 10)
        ttBtn:SetPoint("LEFT", row, "LEFT", 460, 0)
        ttBtn:SetScript("OnClick", function()
            if row.delve then
                E:AddTomTomWaypoint(row.delve.mapID,
                                    row.delve.x, row.delve.y,
                                    row.delve.name)
                E:FlashButtonConfirm(ttBtn)
            end
        end)
        ttBtn:SetScript("OnEnter", function(self)
            local hc = E.Colors.buttonHover
            self:SetBackdropColor(hc.r, hc.g, hc.b, hc.a)
            if E:IsTomTomLoaded() then
                E:ShowTooltip(self, "TomTom Waypoint",
                              "Add an arrow waypoint via TomTom.")
            else
                E:ShowTooltip(self, "TomTom Not Installed",
                              "Install the TomTom addon to use arrow waypoints.")
            end
        end)
        ttBtn:SetScript("OnLeave", function(self)
            local bc = E.Colors.buttonBg
            self:SetBackdropColor(bc.r, bc.g, bc.b, bc.a)
            E:HideTooltip()
        end)
        row.ttBtn = ttBtn

        -- Today's story variant (right edge trimmed to make room for Speed)
        local storyText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        storyText:SetPoint("LEFT",  row, "LEFT",  520, 0)
        storyText:SetPoint("RIGHT", row, "RIGHT", -96, 0)
        storyText:SetFont(storyText:GetFont(), 11)
        storyText:SetJustifyH("LEFT")
        storyText:SetWordWrap(false)
        row.storyText = storyText

        -- Speed: expected clear time (your average, or a pace-calibrated
        -- estimate marked *), coloured by speed grade. Pinned to the right.
        local speedText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        speedText:SetPoint("RIGHT", row, "RIGHT", -8, 0)
        speedText:SetWidth(82)
        speedText:SetFont(speedText:GetFont(), 11)
        speedText:SetJustifyH("RIGHT")
        speedText:SetWordWrap(false)
        row.speedText = speedText

        -- Row hover tooltip
        row:SetScript("OnEnter", function(self)
            if self.delve then
                local tipLines = hoverTipLines
                wipe(tipLines)
                if self.isBountiful then
                    table_insert(tipLines, E.CC.gold .. "* Bountiful Delve today!" .. E.CC.close)
                end
                table_insert(tipLines,
                    E.CC.muted .. "Zone: " .. E.CC.close
                        .. E.CC.body .. self.delve.zone .. E.CC.close)

                -- Use the value RefreshFilteredData already cached (the row
                -- column and sort read the same table) instead of a fresh
                -- live POI read on every mouse-over.
                local todayStory = todayStoryByName[self.delve.name]
                if todayStory and todayStory ~= "" then
                    local si = E.GetStoryTier and E:GetStoryTier(todayStory)
                    table_insert(tipLines, "")
                    if si and si.tier then
                        local tc = DLOC_TIER_COLORS[si.tier] or {0.6, 0.6, 0.6}
                        local cc = string_format("|cFF%02X%02X%02X",
                            math_floor(tc[1]*255), math_floor(tc[2]*255), math_floor(tc[3]*255))
                        table_insert(tipLines,
                            E.CC.muted .. "Today's Story: " .. E.CC.close
                            .. E.CC.body .. todayStory .. E.CC.close
                            .. E.CC.muted .. "  \226\128\148  " .. E.CC.close
                            .. cc .. si.tier .. " Tier|r")
                    else
                        table_insert(tipLines,
                            E.CC.muted .. "Today's Story: " .. E.CC.close
                            .. E.CC.body .. todayStory .. E.CC.close)
                    end
                    if si and si.note then
                        table_insert(tipLines, E.CC.muted .. si.note .. E.CC.close)
                    end
                end

                -- Speed line: your average vs a tier estimate.
                local secs = todaySpeedByName[self.delve.name]
                if secs and E.FormatClock then
                    local src = todaySpeedSrcByName[self.delve.name]
                    local label, gr, gg, gb = E:GetSpeedGrade(secs)
                    local gcc = string_format("|cFF%02X%02X%02X",
                        math_floor((gr or 0.7)*255), math_floor((gg or 0.7)*255),
                        math_floor((gb or 0.7)*255))
                    table_insert(tipLines, "")
                    if src == "personal" then
                        table_insert(tipLines,
                            E.CC.muted .. "Your average clear: " .. E.CC.close
                            .. gcc .. E:FormatClock(secs) .. "|r"
                            .. E.CC.muted .. "  (" .. label .. ")" .. E.CC.close)
                    else
                        table_insert(tipLines,
                            E.CC.muted .. "Estimated clear: " .. E.CC.close
                            .. gcc .. E:FormatClock(secs) .. "|r"
                            .. E.CC.muted .. "  (" .. label .. ")" .. E.CC.close)
                        table_insert(tipLines, E.CC.muted
                            .. "Run it once to replace this with your own time."
                            .. E.CC.close)
                    end
                end

                local bosses = E.GetDelveBosses and E:GetDelveBosses(self.delve.name)
                if bosses then
                    table_insert(tipLines, "")
                    table_insert(tipLines, E.CC.muted
                        .. (expandedDelve[self.delve.name]
                            and "Click to hide boss tactics"
                            or  "Click to show boss tactics")
                        .. E.CC.close)
                end

                E:ShowTooltip(self, self.delve.name, unpack(tipLines))
            end
        end)
        row:SetScript("OnLeave", function()
            E:HideTooltip()
        end)

        return row
    end

    local function AcquireDelveRow(i)
        local row = delveRowPool[i]
        if not row then
            row = CreateDelveRow()
            delveRowPool[i] = row
        end
        row:ClearAllPoints()
        return row
    end

    --------------------------------------------------------------------
    -- Boss sub-row factory: caret + boss name on line 1, brief on line 2.
    --------------------------------------------------------------------
    local function CreateBossRow()
        local row = CreateFrame("Button", nil, sc)
        row:RegisterForClicks("LeftButtonUp")
        row:SetScript("OnClick", BossRow_OnClick)

        local caretFS = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        caretFS:SetPoint("TOPLEFT", row, "TOPLEFT", 0, -2)
        caretFS:SetFont(caretFS:GetFont(), 11, "OUTLINE")
        row.caretFS = caretFS

        local nameFS = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        nameFS:SetPoint("TOPLEFT", caretFS, "TOPRIGHT", 6, 0)
        nameFS:SetFont(nameFS:GetFont(), 11, "OUTLINE")
        nameFS:SetJustifyH("LEFT")
        row.nameFS = nameFS

        local briefFS = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        briefFS:SetPoint("TOPLEFT", row, "TOPLEFT", 18, -17)
        briefFS:SetFont(briefFS:GetFont(), 10)
        briefFS:SetJustifyH("LEFT")
        briefFS:SetSpacing(2)
        row.briefFS = briefFS

        return row
    end

    local function AcquireBossRow(i)
        local row = bossRowPool[i]
        if not row then
            row = CreateBossRow()
            bossRowPool[i] = row
        end
        row:ClearAllPoints()
        return row
    end

    local function AcquireNoteLine(i)
        local fs = noteLinePool[i]
        if not fs then
            fs = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            fs:SetFont(fs:GetFont(), 10)
            fs:SetJustifyH("LEFT")
            fs:SetSpacing(2)
            noteLinePool[i] = fs
        end
        fs:ClearAllPoints()
        return fs
    end

    --------------------------------------------------------------------
    -- Toolbar: [Set All Waypoints] only (search box + zone filter removed)
    --------------------------------------------------------------------
    local setAllBtn = E:CreateButton(frame, 130, 24, "Set All Waypoints")
    setAllBtn.label:SetFont(setAllBtn.label:GetFont(), 10)
    setAllBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -22, TOOLBAR_Y)
    setAllBtn:SetScript("OnClick", function()
        if not E:IsTomTomLoaded() then
            print(E.CC.header .. "Everything Delves|r: "
                .. "TomTom is required for bulk waypoints.")
            return
        end
        for _, delve in ipairs(filteredData) do
            E:AddTomTomWaypoint(delve.mapID, delve.x, delve.y, delve.name)
        end
        print(E.CC.header .. "Everything Delves|r: Added "
            .. #filteredData .. " TomTom waypoints.")
    end)
    setAllBtn:SetScript("OnEnter", function(self)
        local hc = E.Colors.buttonHover
        self:SetBackdropColor(hc.r, hc.g, hc.b, hc.a)
        E:ShowTooltip(self, "Set All Waypoints",
                      "Adds TomTom waypoints for every delve",
                      "in the list.",
                      "",
                      E.CC.muted .. "Requires TomTom addon." .. E.CC.close)
    end)
    setAllBtn:SetScript("OnLeave", function(self)
        local bc = E.Colors.buttonBg
        self:SetBackdropColor(bc.r, bc.g, bc.b, bc.a)
        E:HideTooltip()
    end)

    --------------------------------------------------------------------
    -- Summary banner: today's quickest clear + best value-per-minute
    -- pick. Rebuilt by Refresh from the cached speed/tier data.
    --------------------------------------------------------------------
    local summaryFS = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    summaryFS:SetPoint("LEFT", frame, "TOPLEFT", 6, TOOLBAR_Y - 8)
    summaryFS:SetPoint("RIGHT", setAllBtn, "LEFT", -10, 0)
    summaryFS:SetFont(summaryFS:GetFont(), 11)
    summaryFS:SetJustifyH("LEFT")
    summaryFS:SetWordWrap(false)

    -- Rebuild the banner text from filteredData + the per-delve caches.
    local function UpdateSummary()
        local quickName, quickSecs, quickSrc
        local bestName, bestScore, bestSecs, bestTier, bestSrc
        for _, delve in ipairs(filteredData) do
            local secs = todaySpeedByName[delve.name]
            if secs and (not quickSecs or secs < quickSecs) then
                quickSecs, quickName = secs, delve.name
                quickSrc = todaySpeedSrcByName[delve.name]
            end
            if E.GetDelveValue then
                local score, vsecs, vtier, vsrc = E:GetDelveValue(delve.name,
                    todayTierByName[delve.name])
                if score and (not bestScore or score > bestScore) then
                    bestScore, bestName, bestSecs, bestTier, bestSrc =
                        score, delve.name, vsecs, vtier, vsrc
                end
            end
        end

        if not quickName then
            summaryFS:SetText("")
            return
        end

        local qSuffix = (quickSrc == "estimate")
            and (E.CC.muted .. "*" .. E.CC.close) or ""
        local qcc = E.SpeedColorCode and E:SpeedColorCode(quickSecs) or E.CC.body
        local text = E.CC.gold .. "Quickest: " .. E.CC.close
            .. E.CC.body .. quickName .. E.CC.close
            .. E.CC.muted .. " " .. E.CC.close
            .. qcc .. E:FormatClock(quickSecs) .. "|r" .. qSuffix

        if bestName then
            local tc = DLOC_TIER_COLORS[bestTier] or {0.6, 0.6, 0.6}
            local tcc = string_format("|cFF%02X%02X%02X",
                math_floor(tc[1]*255), math_floor(tc[2]*255), math_floor(tc[3]*255))
            local bcc = E.SpeedColorCode and E:SpeedColorCode(bestSecs) or E.CC.body
            local bSuffix = (bestSrc == "estimate")
                and (E.CC.muted .. "*" .. E.CC.close) or ""
            text = text
                .. E.CC.muted .. "      \226\128\162      " .. E.CC.close
                .. E.CC.gold .. "Best value: " .. E.CC.close
                .. E.CC.body .. bestName .. E.CC.close
                .. E.CC.muted .. " " .. E.CC.close
                .. tcc .. (bestTier or "?") .. "|r"
                .. E.CC.muted .. " " .. E.CC.close
                .. bcc .. E:FormatClock(bestSecs) .. "|r" .. bSuffix
        end
        summaryFS:SetText(text)
    end

    -- Hint text in the gap between toolbar and column headers
    local sortHint = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    sortHint:SetPoint("TOPRIGHT", frame, "TOPLEFT", 514, LIST_Y + 46)
    sortHint:SetFont(sortHint:GetFont(), 9)
    sortHint:SetTextColor(0.38, 0.38, 0.38, 1)
    sortHint:SetJustifyH("RIGHT")
    sortHint:SetText("Click a delve for boss tactics  \226\128\148  click headers to sort")

    --------------------------------------------------------------------
    -- Column headers (clickable to re-sort)
    --------------------------------------------------------------------
    local headerLineTop = frame:CreateTexture(nil, "ARTWORK")
    headerLineTop:SetHeight(1)
    headerLineTop:SetPoint("TOPLEFT",  frame, "TOPLEFT",  4,   LIST_Y + 36)
    headerLineTop:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -22, LIST_Y + 36)
    E:StyleGreyLine(headerLineTop)

    do
        local cols = {
            { field = "name", label = "Delve Name",  width = 250, anchor = 0   },
            { field = "zone", label = "Zone",         width = 120, anchor = 256 },
            { field = "tier", label = "Tier",         width = 35,  anchor = 378 },
        }
        for _, col in ipairs(cols) do
            local btn = CreateFrame("Button", nil, frame)
            btn:SetSize(col.width, 22)
            btn:SetPoint("TOPLEFT", frame, "TOPLEFT", col.anchor, LIST_Y + 22)
            local text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            text:SetPoint("LEFT")
            if col.field == "name" then
                text:SetFont(text:GetFont(), E.HEADER_FONT_SIZE, "OUTLINE")
            else
                text:SetFont(text:GetFont(), 11, "OUTLINE")
            end
            E:StyleAccentHeader(text, col.label)
            btn:SetScript("OnClick", function()
                if sortField == col.field then
                    sortAscending = not sortAscending
                else
                    sortField = col.field
                    sortAscending = true
                end
                if Refresh then Refresh() end
            end)
        end

        for _, info in ipairs({
            { label = "Pin",            x = 422 },
            { label = "TomTom",         x = 462 },
            { label = "Today's Story",  x = 520 },
        }) do
            local fs = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            fs:SetPoint("LEFT", frame, "TOPLEFT", info.x, LIST_Y + 22 - 11)
            fs:SetFont(fs:GetFont(), 11, "OUTLINE")
            E:StyleAccentHeader(fs, info.label)
        end

        -- Speed sort header (right-aligned to the Speed column).
        local speedHeader = CreateFrame("Button", nil, frame)
        speedHeader:SetSize(82, 22)
        speedHeader:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -32, LIST_Y + 22)
        local shText = speedHeader:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        shText:SetPoint("RIGHT")
        shText:SetFont(shText:GetFont(), 11, "OUTLINE")
        E:StyleAccentHeader(shText, "Speed")
        speedHeader:SetScript("OnClick", function()
            if sortField == "speed" then
                sortAscending = not sortAscending
            else
                sortField = "speed"
                sortAscending = true
            end
            if Refresh then Refresh() end
        end)
        speedHeader:SetScript("OnEnter", function(self)
            E:ShowTooltip(self, "Sort by Speed",
                "Quickest clear first. Shows your own average time once",
                "you've run a delve, or a tier-based estimate (marked *)",
                "until then.")
        end)
        speedHeader:SetScript("OnLeave", function() E:HideTooltip() end)
    end

    local headerLineBot = frame:CreateTexture(nil, "ARTWORK")
    headerLineBot:SetHeight(1)
    headerLineBot:SetPoint("TOPLEFT",  frame, "TOPLEFT",  4,   LIST_Y - 8)
    headerLineBot:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -22, LIST_Y - 8)
    E:StyleGreyLine(headerLineBot)

    --------------------------------------------------------------------
    -- Refresh: rebuild the list (delve rows + expanded boss tactics)
    --------------------------------------------------------------------
    function Refresh()
        RefreshFilteredData()

        for _, r in ipairs(delveRowPool) do r:Hide() end
        for _, r in ipairs(bossRowPool)  do r:Hide() end
        for _, r in ipairs(noteLinePool) do r:Hide() end

        local dUsed, bUsed, nUsed = 0, 0, 0
        local yCur = 2

        local function PlaceRow(row, x, h)
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", sc, "TOPLEFT", x, -yCur)
            row:SetPoint("RIGHT",   sc, "RIGHT",  -2, 0)
            row:Show()
            yCur = yCur + h
        end

        for _, delve in ipairs(filteredData) do
            dUsed = dUsed + 1
            local row = AcquireDelveRow(dUsed)
            row:SetParent(sc)
            row.delve = delve

            -- Alternate shading by emission order.
            if dUsed % 2 == 0 then
                row:SetBackdropColor(0.08, 0.08, 0.08, 0.50)
            else
                row:SetBackdropColor(0.05, 0.05, 0.05, 0.20)
            end

            -- Bountiful star + run count.
            local isBountiful = false
            if E.currentBountifulNames then
                isBountiful = E.currentBountifulNames[delve.name]
                    or E.currentBountifulNames[GetLowerName(delve)]
                    or (E.currentBountifulPOIs and delve.poiID
                        and E.currentBountifulPOIs[delve.poiID])
                    or false
            end
            row.isBountiful = isBountiful

            local hist = E:GetDelveHistory(delve.name)
            local runSuffix = ""
            local totalRuns = hist and hist.lifetime and hist.lifetime.totalRuns
            if totalRuns and totalRuns > 0 then
                runSuffix = E.CC.muted .. " (" .. totalRuns .. "x)" .. E.CC.close
            end

            local caret = E.CC.gold
                .. (expandedDelve[delve.name] and "v" or ">") .. E.CC.close
            if isBountiful then
                row.nameText:SetText(caret .. " "
                    .. E.CC.gold .. "* " .. delve.name .. E.CC.close .. runSuffix)
            else
                row.nameText:SetText(caret .. " "
                    .. E.CC.body .. delve.name .. E.CC.close .. runSuffix)
            end

            row.zoneText:SetText(E.CC.body .. delve.zone .. E.CC.close)

            local tierLetter = todayTierByName[delve.name]
            if tierLetter then
                local tc = DLOC_TIER_COLORS[tierLetter]
                if tc then
                    row.tierText:SetTextColor(tc[1], tc[2], tc[3])
                else
                    row.tierText:SetTextColor(0.60, 0.60, 0.60)
                end
                row.tierText:SetText(tierLetter)
            else
                row.tierText:SetText("")
            end

            local story = todayStoryByName[delve.name]
            if story and story ~= "" then
                row.storyText:SetText(E.CC.body .. story .. E.CC.close)
            else
                row.storyText:SetText(E.CC.muted .. "--" .. E.CC.close)
            end

            -- Speed cell: "M:SS" for a real personal average, "M:SS*" for a
            -- tier-based estimate (trailing * reads as "estimated" without
            -- the leading-tilde looking like a negative sign), coloured by
            -- speed grade.
            local secs = todaySpeedByName[delve.name]
            if secs and E.FormatClock then
                local suffix = (todaySpeedSrcByName[delve.name] == "estimate")
                    and (E.CC.muted .. "*" .. E.CC.close) or ""
                local cc = E.SpeedColorCode and E:SpeedColorCode(secs) or E.CC.body
                row.speedText:SetText(cc .. E:FormatClock(secs) .. "|r" .. suffix)
            else
                row.speedText:SetText(E.CC.muted .. "--" .. E.CC.close)
            end

            PlaceRow(row, 0, ROW_HEIGHT)

            -- Expanded: list this delve's boss tactics.
            if expandedDelve[delve.name] then
                local bosses = E.GetDelveBosses and E:GetDelveBosses(delve.name)
                if bosses then
                    local todaysBoss = E.GetTodaysBossName
                        and E:GetTodaysBossName(delve.name)
                    for bi, boss in ipairs(bosses) do
                        bUsed = bUsed + 1
                        local brow = AcquireBossRow(bUsed)
                        brow:SetParent(sc)
                        local bossKey = delve.name .. "##" .. bi
                        brow.bossKey = bossKey

                        local bExpanded = expandedBoss[bossKey]
                        brow.caretFS:SetText(E.CC.muted
                            .. (bExpanded and "v" or ">") .. E.CC.close)
                        if todaysBoss and boss.name == todaysBoss then
                            brow.nameFS:SetText(
                                "|TInterface\\Common\\FavoritesIcon:14:14|t "
                                .. E.CC.gold .. boss.name .. E.CC.close
                                .. E.CC.muted .. "   (today's boss)" .. E.CC.close)
                        else
                            brow.nameFS:SetText(E.CC.white .. boss.name .. E.CC.close)
                        end

                        local briefW = math_max(150,
                            (sc:GetWidth() or 600) - 18 - 16)
                        brow.briefFS:SetWidth(briefW)
                        brow.briefFS:SetText(E.CC.muted .. (boss.brief or "") .. E.CC.close)

                        local bh = 18 + (brow.briefFS:GetStringHeight() or 12) + 6
                        brow:SetHeight(bh)
                        PlaceRow(brow, 24, bh)

                        if bExpanded and boss.notes then
                            for _, note in ipairs(boss.notes) do
                                nUsed = nUsed + 1
                                local nl = AcquireNoteLine(nUsed)
                                nl:SetParent(sc)
                                local w = math_max(150,
                                    (sc:GetWidth() or 600) - 48 - 12)
                                nl:SetWidth(w)
                                nl:SetText(
                                    RoleCC(note.role) .. RoleLabel(note.role) .. "|r  "
                                    .. E.CC.body .. note.text .. E.CC.close)
                                local h = (nl:GetStringHeight() or 12) + 5
                                nl:SetPoint("TOPLEFT", sc, "TOPLEFT", 48, -yCur)
                                nl:Show()
                                yCur = yCur + h
                            end
                        end
                    end
                end
            end
        end

        sc:SetHeight(yCur + 8)
        UpdateScrollRange()
        UpdateSummary()
    end

    --------------------------------------------------------------------
    -- Show / refresh hooks
    --------------------------------------------------------------------
    frame:SetScript("OnShow", function()
        Refresh()
        scrollFrame:SetVerticalScroll(0)
        scrollBar:SetValue(0)
    end)

    E:RegisterCallback("AreaPoisUpdated", function()
        if frame:IsShown() then
            Refresh()
        end
    end)

    --------------------------------------------------------------------
    -- Register with the main frame tab system
    --------------------------------------------------------------------
    E:RegisterTab(1, frame)

    -- Seed the initial data set
    RefreshFilteredData()
end)
