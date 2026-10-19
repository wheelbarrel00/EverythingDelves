local E = EverythingDelves
local L = E.L

local math_abs, math_max = math.abs, math.max
local table_insert, table_sort, table_concat = table.insert, table.sort, table.concat

local filteredData   = {}

local todayStoryByName = {}
local todayStoryIDByName = {}
local todayTierByName  = {}
local todayMeasuredByName = {}
local todayMineByName  = {}
local todaySpeedByName  = {}
local todaySpeedSrcByName = {}

local hoverTipLines = {}

local delveLowerName = {}
local delveLowerZone = {}
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

local DLOC_TIER_ORDER = E.DelveList.GRADE_ORDER

local DELVE_NOTES = {
    ["Collegiate Calamity"] = { tier="A", story="Invasive Glow",     note=L["Compact layout with easy boss access. NPC debuffs boost damage — the bomb DoT scales with tier and trivializes the clear."] },
    ["The Gulf of Memory"]  = { tier="S", story="Sporasaur Special",  note=L["Glide or use a parasol toy to reach the boss platform quickly. Kite dinos and kick spores back to break their shields."] },
    ["The Darkway"]         = { tier="A", story="Ogre Powered",        note=L["Straightforward paths to the boss. Kill Unstable Aberrations before moving — they leash and give chase."] },
    ["Parhelion Plaza"]     = { tier="A", story="Holding the Line",    note=L["Take the staircase down for the fastest route. Kill enemies instead of healing allies for quicker progress."] },
    ["Sunkiller Sanctum"]   = { tier="B", story="Core of the Problem", note=L["Straight routes with easy kill objectives. Use portals in Core of the Problem to shortcut around the map."] },
    ["Twilight Crypt"]      = { tier="B", story="Party Crasher",       note=L["Pull levers to deactivate traps before advancing — limits large pulls. Party Crasher is the most direct variant."] },
    ["Atal'Aman"]           = { tier="C", story="Toadly Unbecoming",  note=L["Open layout adds traverse time even when mounted. Toadly Unbecoming: decurse frogs to spawn the boss."] },
    ["The Shadow Enclave"]  = { tier="C", story="Traitor's Due",       note=L["Large unwalkable map — slow regardless of story. Use the Eye of Antenorian buff whenever it's available."] },
    ["The Grudge Pit"]      = { tier="D", story="Arena Champion",      note=L["Compact and mountable but long RP transitions and non-combat objectives in all three variants hurt efficiency."] },
    ["The Ring of Glory"]   = { tier="A", story="Adopt-a-thon" },
    ["Gnarldor Isle"]       = { tier="F", story="Speaking Their Language" },
    ["Shadowguard Point"]   = { tier="C", story="Calamitous",        note=L["Enormous mountable map with required secondary objectives. Avoid if faster options are bountiful today."] },
}

-- Published for other tabs as a story fallback when a run captured no live story.
E.DelveStories = E.DelveStories or {}
for delveName, info in pairs(DELVE_NOTES) do
    E.DelveStories[delveName] = info.story
end

-- Published for Core/SpeedRank.lua as a tier fallback for an unrecognized variant.
E.DelveSignatureTier = E.DelveSignatureTier or {}
for delveName, info in pairs(DELVE_NOTES) do
    E.DelveSignatureTier[delveName] = info.tier
end

local function RefreshFilteredData(sortField, sortAscending)
    wipe(filteredData)
    for _, delve in ipairs(E.DelveData) do
        table_insert(filteredData, delve)
    end

    wipe(todayStoryByName)
    wipe(todayStoryIDByName)
    wipe(todayTierByName)
    wipe(todayMeasuredByName)
    wipe(todayMineByName)
    wipe(todaySpeedByName)
    wipe(todaySpeedSrcByName)
    for _, delve in ipairs(E.DelveData) do
        local story, widget = E:GetDelveStoryVariant(delve.name)
        local id = E:StoryID(widget, story)
        todayStoryIDByName[delve.name] = id
        todayStoryByName[delve.name] = id and E:StoryName(id) or story
        local tier, measured, mine
        if id then
            tier, measured, mine = E:StoryGrade(id)
        else
            local dn = DELVE_NOTES[delve.name]
            tier = dn and dn.tier
            measured = tier
        end
        todayTierByName[delve.name] = tier
        todayMeasuredByName[delve.name] = measured
        todayMineByName[delve.name] = mine

        local secs, src = E:GetDelveSpeed(delve.name, measured)
        todaySpeedByName[delve.name]    = secs
        todaySpeedSrcByName[delve.name] = src
    end

    table_sort(filteredData, function(a, b)
        local wa, wb = todayMineByName[a.name] == "x", todayMineByName[b.name] == "x"
        if wa ~= wb then return wb end
        if sortField == "tier" then
            local oa = DLOC_TIER_ORDER[todayTierByName[a.name] or ""] or 7
            local ob = DLOC_TIER_ORDER[todayTierByName[b.name] or ""] or 7
            if oa ~= ob then
                if sortAscending then return oa < ob else return oa > ob end
            end
            return GetLowerName(a) < GetLowerName(b)
        end
        if sortField == "speed" then
            -- Unrankable delves (no time) always sink to the bottom regardless of direction.
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

local PAD_TOP, PAD_LEFT, PAD_RIGHT, PAD_BOTTOM = 20, 24, 14, 28
local BAR_H, HINT_GAP, HINT_H, SUMMARY_GAP = 32, 10, 16, 16
local SEP = "   \226\128\162   "

local COLUMNS = {
    { key = "zone",  label = L["Zone"],          width = 118, sort = "zone" },
    { key = "tier",  label = L["Tier"],          width = 34,  sort = "tier", align = "CENTER", weight = "navActive" },
    { key = "story", label = L["Today's Story"], width = 156 },
    { key = "speed", label = L["Speed"],         width = 50,  sort = "speed", align = "RIGHT",
      tip = { L["Sort by Speed"], L["Quickest clear first. Shows your own average time once you've run a delve, or a tier- and gear-based estimate (marked *) until then."] } },
}

local function IsBountiful(delve)
    if not E.currentBountifulNames then return false end
    return (E.currentBountifulNames[delve.name]
        or E.currentBountifulNames[GetLowerName(delve)]
        or (E.currentBountifulPOIs and delve.poiID and E.currentBountifulPOIs[delve.poiID])) and true or false
end

local function TipBody(delve, isBountiful, expanded)
    local lines = hoverTipLines
    wipe(lines)
    if isBountiful then lines[#lines + 1] = L["* Bountiful Delve today!"] end
    lines[#lines + 1] = L["Zone:"] .. " " .. delve.zone

    local story = todayStoryByName[delve.name]
    local id = todayStoryIDByName[delve.name]
    if story and story ~= "" then
        local mine = todayMineByName[delve.name]
        lines[#lines + 1] = ""
        if id and mine ~= "x" and todayTierByName[delve.name] then
            lines[#lines + 1] = L["Today's Story:"] .. " " .. story .. "  (" .. L["%s Tier"]:format(todayTierByName[delve.name]) .. ")"
        else
            lines[#lines + 1] = L["Today's Story:"] .. " " .. story
        end
        if mine == "x" then
            lines[#lines + 1] = L["You marked this story as one you won't run."]
        elseif mine then
            lines[#lines + 1] = L["Your grade (compendium: %s)"]:format(todayMeasuredByName[delve.name] or "--")
        end
        if id then lines[#lines + 1] = E.Stories[id].note end
    end

    local secs = todaySpeedByName[delve.name]
    if secs then
        local label = E:GetSpeedGrade(secs)
        lines[#lines + 1] = ""
        if todaySpeedSrcByName[delve.name] == "personal" then
            lines[#lines + 1] = L["Your average clear:"] .. " " .. E:FormatClock(secs) .. "  (" .. label .. ")"
        else
            lines[#lines + 1] = L["Estimated clear:"] .. " " .. E:FormatClock(secs) .. "  (" .. label .. ")"
            lines[#lines + 1] = L["Run it once to replace this with your own time."]
        end
    end

    if E:GetDelveBosses(delve.name) or id then lines[#lines + 1] = "" end
    if E:GetDelveBosses(delve.name) then
        lines[#lines + 1] = expanded and L["Click to hide boss tactics"] or L["Click to show boss tactics"]
    end
    if id then lines[#lines + 1] = L["Right-click to set your own grade"] end
    return table_concat(lines, "\n")
end

local function BuildModels(list)
    local models = {}
    for i, delve in ipairs(filteredData) do
        local name = delve.name
        local hist = E:GetDelveHistory(name)
        local runs = hist and hist.lifetime and hist.lifetime.totalRuns
        local tier = todayTierByName[name]
        local mine = todayMineByName[name]
        local wont = mine == "x" or nil
        local story = todayStoryByName[name]
        local secs = todaySpeedByName[name]
        local estimate = todaySpeedSrcByName[name] == "estimate"
        local bountiful = IsBountiful(delve)
        models[i] = {
            key = name, delve = delve, bossName = name, name = name,
            bountiful = bountiful, storyID = todayStoryIDByName[name], muted = wont,
            runs = (runs and runs > 0) and runs or nil,
            call = (E.db and E.db.showDelversCallDone and E:IsDelversCallComplete(name)) or nil,
            cells = {
                zone  = { text = delve.zone, muted = wont },
                tier  = E.DelveList.GradeCell(tier, nil, mine),
                story = (story and story ~= "") and { text = story, muted = wont } or { text = "--", muted = true },
                speed = secs and { text = E:FormatClock(secs) .. (estimate and "*" or ""), muted = estimate or wont }
                    or { text = "--", muted = true },
            },
            tip = { name, TipBody(delve, bountiful, list.expanded[name]) },
        }
    end
    return models
end

local function LabyrinthModels()
    local lab = E.DelveList.Labyrinth()
    return { {
        key = lab.key, delve = lab.entrance, name = lab.name, bountiful = lab.open or nil, runs = lab.runs,
        line2 = lab.locked and { text = lab.locked } or nil,
        cells = { zone = { text = lab.zone }, story = { text = L["Always bountiful"], muted = true } },
        tip = lab.tip,
    } }
end

local function SummaryText()
    local quickName, quickSecs, quickSrc
    local bestName, bestScore, bestSecs, bestTier, bestSrc, bestMine
    for _, delve in ipairs(filteredData) do
        local name = delve.name
        local mine = todayMineByName[name]
        if mine ~= "x" then
            local secs = todaySpeedByName[name]
            if secs and (not quickSecs or secs < quickSecs) then
                quickSecs, quickName, quickSrc = secs, name, todaySpeedSrcByName[name]
            end
            local score, vsecs, vtier, vsrc = E:GetDelveValue(name, todayMeasuredByName[name], todayTierByName[name])
            if score and (not bestScore or score > bestScore) then
                bestScore, bestName, bestSecs, bestTier, bestSrc, bestMine = score, name, vsecs, vtier, vsrc, mine
            end
        end
    end
    if not quickName then return "" end

    local muted, label = E.DelveList.cc("muted"), E.DelveList.cc("label")
    local text = muted .. L["Quickest:"] .. "|r " .. label .. quickName .. " " .. E:FormatClock(quickSecs) .. "|r"
        .. (quickSrc == "estimate" and (muted .. "*|r") or "")
    if bestName then
        text = text .. muted .. SEP .. L["Best value:"] .. "|r " .. label .. bestName .. "|r "
            .. E:GetGradeCC(bestTier) .. (bestTier or "?") .. "|r" .. (bestMine and E.DelveList.Mark() or "")
            .. " " .. label .. E:FormatClock(bestSecs) .. "|r"
            .. (bestSrc == "estimate" and (muted .. "*|r") or "")
    end
    return text
end

local function SetAllWaypoints()
    if not E:IsTomTomLoaded() then
        print(E.CC.header .. "Everything Delves|r: " .. L["TomTom is required for bulk waypoints."])
        return
    end
    for _, delve in ipairs(filteredData) do
        E:AddTomTomWaypoint(delve.mapID, delve.x, delve.y, delve.name)
    end
    local lab = E.LabyrinthEntrance()
    E:AddTomTomWaypoint(lab.mapID, lab.x, lab.y, lab.name)
    print(E.CC.header .. "Everything Delves|r: " .. L["Added %d TomTom waypoints."]:format(#filteredData + 1))
end

E:RegisterModule(function()
    local ui = E.ui
    local frame = CreateFrame("Frame", "EverythingDelvesTab1Content")
    local area = ui:CreateScrollArea(frame, { clearGrip = true })
    area:SetAllPoints(frame)
    local content = area.content
    local Render

    local setAll = ui:CreateButton(content, L["Set All Waypoints"], nil, SetAllWaypoints,
        L["Adds TomTom waypoints for every delve in the list."] .. "\n\n" .. L["Requires TomTom addon."])
    local summary = ui:CreateText(content, "", "label")
    summary:SetWordWrap(false)
    local hint = ui:CreateText(content, L["Click a delve for boss tactics  \226\128\148  click headers to sort"], "hint")
    hint:SetWordWrap(false)

    local list = E.DelveList.New(content, {
        columns = COLUMNS, nameLabel = L["Delve Name"], nameSort = "name", sortKey = "tier",
        onChange = function() Render() end,
    })

    local lastWidth = 0
    local function ViewWidth()
        local w = area.scroll:GetWidth() or 0
        if w <= 0 then w = (frame:GetWidth() or 0) - 10 end
        return math_max(1, w)
    end

    function Render()
        RefreshFilteredData(list.sortKey, list.sortAsc)
        local width = ViewWidth()
        lastWidth = width
        content:SetWidth(width)

        setAll:Fit()
        setAll:ClearAllPoints()
        setAll:SetPoint("TOPRIGHT", content, "TOPRIGHT", -PAD_RIGHT, -PAD_TOP)
        summary:ClearAllPoints()
        summary:SetPoint("LEFT", content, "TOPLEFT", PAD_LEFT, -(PAD_TOP + BAR_H / 2))
        summary:SetPoint("RIGHT", setAll, "LEFT", -SUMMARY_GAP, 0)
        summary:SetText(SummaryText())

        local y = PAD_TOP + BAR_H + HINT_GAP
        hint:ClearAllPoints()
        hint:SetPoint("TOPLEFT", content, "TOPLEFT", PAD_LEFT, -y)
        hint:SetPoint("RIGHT", content, "RIGHT", -PAD_RIGHT, 0)
        y = y + HINT_H + HINT_GAP

        y = list:Layout(y, BuildModels(list), PAD_LEFT, PAD_RIGHT, LabyrinthModels())
        area:SetContentSize(width, y + PAD_BOTTOM)
    end

    area.scroll:HookScript("OnSizeChanged", function(_, w)
        if frame:IsVisible() and math_abs((w or 0) - lastWidth) >= 1 then Render() end
    end)

    frame:SetScript("OnShow", function()
        Render()
        area:ScrollTo(0, 0)
    end)

    function E:RefreshDelveLocations()
        if frame:IsVisible() then Render() end
    end

    E:RegisterCallback("AreaPoisUpdated", function()
        if frame:IsVisible() then Render() end
    end)
    E:RegisterCallback("StoryGradesChanged", function()
        if frame:IsVisible() then Render() end
    end)

    E:RegisterTab(1, frame)

    RefreshFilteredData(list.sortKey, list.sortAsc)
end)
