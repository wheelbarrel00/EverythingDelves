------------------------------------------------------------------------
-- UI/TabShardTracker.lua — Tab 4: Shard Tracker
-- Tracks Coffer Key Shards, Bountiful Keys, weekly shard income from
-- every known source, and session-level earnings.
--
-- Display-only: reads C_CurrencyInfo, quest completion status, and
-- session counters. No gameplay automation.
------------------------------------------------------------------------
local E = EverythingDelves

------------------------------------------------------------------------
-- Local references for frequently accessed globals
------------------------------------------------------------------------
local pairs, ipairs, type, time = pairs, ipairs, type, time
local math_floor, math_max, math_min = math.floor, math.max, math.min
local string_format = string.format
local table_insert, table_sort, wipe = table.insert, table.sort, wipe

------------------------------------------------------------------------
-- Local helpers
------------------------------------------------------------------------


--- Read a currency quantity safely.
local function GetCurrency(currencyID)
    if C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo then
        local info = C_CurrencyInfo.GetCurrencyInfo(currencyID)
        if info then
            return info.quantity or 0
        end
    end
    return 0
end

--- Read full currency info for weekly cap tracking.
--- Returns quantity, maxWeeklyQuantity, quantityEarnedThisWeek
local function GetCurrencyFull(currencyID)
    if C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo then
        local info = C_CurrencyInfo.GetCurrencyInfo(currencyID)
        if info then
            return info.quantity or 0,
                   info.maxWeeklyQuantity or 0,
                   info.quantityEarnedThisWeek or 0
        end
    end
    return 0, 0, 0
end

--- Format a number with commas (e.g. 1234 → "1,234")
local function FormatNumber(n)
    if n < 1000 then return tostring(n) end
    local s = tostring(n)
    local pos = #s % 3
    if pos == 0 then pos = 3 end
    local formatted = s:sub(1, pos)
    for i = pos + 1, #s, 3 do
        formatted = formatted .. "," .. s:sub(i, i + 2)
    end
    return formatted
end

------------------------------------------------------------------------
-- Cached currency values — updated by RefreshAll on currency events,
-- read by RefreshSessionTimer to avoid per-second API table churn.
local cachedShards = 0
local cachedKeys   = 0

-- Cached quest line results — these don't change mid-session.
local questLineCache = {}

-- Cached undercoins icon — resolved once, never changes.
local cachedUcIcon = nil

-- MODULE INIT
------------------------------------------------------------------------
E:RegisterModule(function()
    local frame = CreateFrame("Frame", "EverythingDelvesTab4Content")
    --------------------------------------------------------------------
    -- SCROLLABLE AREA
    --------------------------------------------------------------------
    local scrollFrame = CreateFrame("ScrollFrame", nil, frame)
    scrollFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -18, 0)
    scrollFrame:EnableMouseWheel(true)

    local sc = CreateFrame("Frame")
    sc:SetSize(1, 1)
    scrollFrame:SetScrollChild(sc)

    scrollFrame:SetScript("OnSizeChanged", function(self, w)
        sc:SetWidth(w)
    end)
    -- Initial oversize; UpdateContentHeight() recomputes after layout so
    -- the WQ list at the bottom is never clipped regardless of row count.
    sc:SetHeight(1400)

    -- Themed scrollbar: dark track, red thumb
    local tabScrollBar = CreateFrame("Slider", nil, scrollFrame, "BackdropTemplate")
    tabScrollBar:SetWidth(14)
    tabScrollBar:SetPoint("TOPRIGHT", scrollFrame, "TOPRIGHT", 16, 0)
    tabScrollBar:SetPoint("BOTTOMRIGHT", scrollFrame, "BOTTOMRIGHT", 16, 0)
    tabScrollBar:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    tabScrollBar:SetBackdropColor(0.08, 0.08, 0.08, 0.90)
    tabScrollBar:SetBackdropBorderColor(0.25, 0.25, 0.25, 0.50)
    local sbThumb = tabScrollBar:CreateTexture(nil, "OVERLAY")
    sbThumb:SetSize(12, 40)
    sbThumb:SetColorTexture(0.55, 0, 0, 0.80)
    tabScrollBar:SetThumbTexture(sbThumb)
    tabScrollBar:SetOrientation("VERTICAL")
    tabScrollBar:SetMinMaxValues(0, 1)
    tabScrollBar:SetValue(0)
    tabScrollBar:SetValueStep(1)
    tabScrollBar:SetObeyStepOnDrag(true)
    tabScrollBar:SetScript("OnValueChanged", function(_, value)
        scrollFrame:SetVerticalScroll(value)
    end)

    scrollFrame:SetScript("OnMouseWheel", function(self, delta)
        local maxScroll = math_max(0, sc:GetHeight() - self:GetHeight())
        local newVal = math_max(0, math_min(
            self:GetVerticalScroll() - delta * 30, maxScroll))
        self:SetVerticalScroll(newVal)
        tabScrollBar:SetValue(newVal)
    end)

    local function UpdateScrollRange()
        local maxScroll = math_max(0, sc:GetHeight() - scrollFrame:GetHeight())
        tabScrollBar:SetMinMaxValues(0, maxScroll)
        if maxScroll <= 0 then
            tabScrollBar:Hide()
        else
            tabScrollBar:Show()
        end
    end


    --------------------------------------------------------------------
    -- SECTION 1: Currency Overview
    -- Two big numbers side-by-side: Shards | Bountiful Keys
    --------------------------------------------------------------------
    local SECT_X = 8
    local SECT_Y = -6

    local currHeader = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    currHeader:SetPoint("TOPLEFT", sc, "TOPLEFT", SECT_X, SECT_Y)
    currHeader:SetFont(currHeader:GetFont(), 12, "OUTLINE")
    currHeader:SetText(E.CC.header .. "Currency Overview" .. E.CC.close)

    -- Coffer Key Shards
    local shardIcon = sc:CreateTexture(nil, "ARTWORK")
    shardIcon:SetPoint("TOPLEFT", currHeader, "BOTTOMLEFT", 0, -4)
    shardIcon:SetSize(16, 16)

    local shardLabelFS = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    shardLabelFS:SetPoint("LEFT", shardIcon, "RIGHT", 4, 0)
    shardLabelFS:SetFont(shardLabelFS:GetFont(), 11)
    shardLabelFS:SetText(E.CC.muted .. "Coffer Key Shards:" .. E.CC.close)

    local shardValueFS = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    shardValueFS:SetPoint("LEFT", shardLabelFS, "RIGHT", 6, 0)
    shardValueFS:SetFont(shardValueFS:GetFont(), 13, "OUTLINE")

    -- Bountiful Keys
    local keyIcon = sc:CreateTexture(nil, "ARTWORK")
    keyIcon:SetPoint("LEFT", shardValueFS, "RIGHT", 24, 0)
    keyIcon:SetSize(16, 16)

    local keyLabelFS = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    keyLabelFS:SetPoint("LEFT", keyIcon, "RIGHT", 4, 0)
    keyLabelFS:SetFont(keyLabelFS:GetFont(), 11)
    keyLabelFS:SetText(E.CC.muted .. "Bountiful Keys:" .. E.CC.close)

    local keyValueFS = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    keyValueFS:SetPoint("LEFT", keyLabelFS, "RIGHT", 6, 0)
    keyValueFS:SetFont(keyValueFS:GetFont(), 13, "OUTLINE")

    -- Undercoins
    local ucIcon = sc:CreateTexture(nil, "ARTWORK")
    ucIcon:SetPoint("TOPLEFT", shardIcon, "BOTTOMLEFT", 0, -4)
    ucIcon:SetSize(16, 16)

    local ucLabelFS = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    ucLabelFS:SetPoint("LEFT", ucIcon, "RIGHT", 4, 0)
    ucLabelFS:SetFont(ucLabelFS:GetFont(), 11)
    ucLabelFS:SetText(E.CC.muted .. "Undercoins:" .. E.CC.close)

    local ucValueFS = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    ucValueFS:SetPoint("LEFT", ucLabelFS, "RIGHT", 6, 0)
    ucValueFS:SetFont(ucValueFS:GetFont(), 13, "OUTLINE")

    -- Progress bar: shards toward next key
    local nextKeyBar = E:CreateProgressBar(sc, 0, 14)
    nextKeyBar:SetPoint("TOPLEFT", ucIcon, "BOTTOMLEFT", 0, -8)
    nextKeyBar:SetPoint("RIGHT", sc, "RIGHT", -20, 0)

    local nextKeyNote = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    nextKeyNote:SetPoint("TOPLEFT", nextKeyBar, "BOTTOMLEFT", 0, -2)
    nextKeyNote:SetFont(nextKeyNote:GetFont(), 10)

    -- Weekly shard cap bar
    local weeklyCapBar = E:CreateProgressBar(sc, 0, 14)
    weeklyCapBar:SetPoint("TOPLEFT", nextKeyNote, "BOTTOMLEFT", 0, -6)
    weeklyCapBar:SetPoint("RIGHT", sc, "RIGHT", -20, 0)

    local weeklyCapNote = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    weeklyCapNote:SetPoint("TOPLEFT", weeklyCapBar, "BOTTOMLEFT", 0, -2)
    weeklyCapNote:SetFont(weeklyCapNote:GetFont(), 10)

    --------------------------------------------------------------------
    -- Thin red divider
    --------------------------------------------------------------------
    local dc = E.Colors.divider
    local div1 = sc:CreateTexture(nil, "ARTWORK")
    div1:SetHeight(1)
    div1:SetPoint("TOPLEFT", weeklyCapNote, "BOTTOMLEFT", 0, -8)
    div1:SetPoint("RIGHT", sc, "RIGHT", -8, 0)
    div1:SetColorTexture(dc.r, dc.g, dc.b, dc.a)

    --------------------------------------------------------------------
    -- SECTION 2: Weekly Shard Sources
    -- Scrollable list of every shard source with earned/available status
    --------------------------------------------------------------------
    local srcHeader = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    srcHeader:SetPoint("TOPLEFT", div1, "BOTTOMLEFT", 0, -8)
    srcHeader:SetFont(srcHeader:GetFont(), 12, "OUTLINE")
    srcHeader:SetText(E.CC.header .. "Weekly Shard Sources" .. E.CC.close)

    local weeklyTotalFS = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    weeklyTotalFS:SetPoint("LEFT", srcHeader, "RIGHT", 16, 0)
    weeklyTotalFS:SetFont(weeklyTotalFS:GetFont(), 11)

    -- Column headers
    local COL_HEADERS_Y = -4
    local colNameFS = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    colNameFS:SetPoint("TOPLEFT", srcHeader, "BOTTOMLEFT", 0, COL_HEADERS_Y)
    colNameFS:SetFont(colNameFS:GetFont(), 10, "OUTLINE")
    colNameFS:SetText(E.CC.muted .. "Source" .. E.CC.close)

    local colPerFS = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    colPerFS:SetPoint("TOPLEFT", colNameFS, "TOPLEFT", 260, 0)
    colPerFS:SetFont(colPerFS:GetFont(), 10, "OUTLINE")
    colPerFS:SetText(E.CC.muted .. "Per" .. E.CC.close)

    local colCapFS = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    colCapFS:SetPoint("TOPLEFT", colNameFS, "TOPLEFT", 310, 0)
    colCapFS:SetFont(colCapFS:GetFont(), 10, "OUTLINE")
    colCapFS:SetText(E.CC.muted .. "Weekly Cap" .. E.CC.close)

    local colStatusFS = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    colStatusFS:SetPoint("TOPLEFT", colNameFS, "TOPLEFT", 405, 0)
    colStatusFS:SetFont(colStatusFS:GetFont(), 10, "OUTLINE")
    colStatusFS:SetText(E.CC.muted .. "Status" .. E.CC.close)

    -- Source rows
    local ROW_HEIGHT    = 20
    local SOURCE_ROW_Y  = COL_HEADERS_Y - 16
    local sourceRows    = {}

    for i, src in ipairs(E.ShardSources) do
        local rowY = SOURCE_ROW_Y - ((i - 1) * ROW_HEIGHT)

        -- Alternating row background
        if i % 2 == 0 then
            local rowBg = sc:CreateTexture(nil, "BACKGROUND")
            rowBg:SetPoint("TOPLEFT", srcHeader, "BOTTOMLEFT", -2, rowY + 2)
            rowBg:SetSize(500, ROW_HEIGHT)
            rowBg:SetColorTexture(0.08, 0.08, 0.08, 0.50)
        end

        -- Source name (with asterisk if unconfirmed)
        local nameFS = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        nameFS:SetPoint("TOPLEFT", srcHeader, "BOTTOMLEFT", 0, rowY)
        nameFS:SetFont(nameFS:GetFont(), 10)
        nameFS:SetWidth(255)
        nameFS:SetJustifyH("LEFT")

        -- Per-unit shards (with asterisk if unconfirmed)
        local perFS = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        perFS:SetPoint("TOPLEFT", srcHeader, "BOTTOMLEFT", 260, rowY)
        perFS:SetFont(perFS:GetFont(), 10)

        -- Weekly cap
        local capFS = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        capFS:SetPoint("TOPLEFT", srcHeader, "BOTTOMLEFT", 310, rowY)
        capFS:SetFont(capFS:GetFont(), 10)

        -- Status (trackable vs not)
        local statusFS = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        statusFS:SetPoint("TOPLEFT", srcHeader, "BOTTOMLEFT", 405, rowY)
        statusFS:SetFont(statusFS:GetFont(), 10)

        sourceRows[i] = {
            nameFS   = nameFS,
            perFS    = perFS,
            capFS    = capFS,
            statusFS = statusFS,
            src      = src,
        }
    end

    --------------------------------------------------------------------
    -- Thin red divider after source list
    --------------------------------------------------------------------
    local lastRowY = SOURCE_ROW_Y - ((#E.ShardSources - 1) * ROW_HEIGHT)
    local belowLastRow = lastRowY - ROW_HEIGHT  -- bottom edge of last row

    -- Footnote for unconfirmed values
    local footnoteFS = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    footnoteFS:SetPoint("TOPLEFT", srcHeader, "BOTTOMLEFT", 0, belowLastRow - 2)
    footnoteFS:SetFont(footnoteFS:GetFont(), 9)
    footnoteFS:SetText(E.CC.muted .. "* Value unconfirmed — may differ in game" .. E.CC.close)

    local div2 = sc:CreateTexture(nil, "ARTWORK")
    div2:SetHeight(1)
    div2:SetPoint("TOPLEFT", srcHeader, "BOTTOMLEFT", 0, belowLastRow - 16)
    div2:SetPoint("RIGHT", sc, "RIGHT", -8, 0)
    div2:SetColorTexture(dc.r, dc.g, dc.b, dc.a)

    --------------------------------------------------------------------
    -- SECTION 3: Session Tracker
    -- Shows shards earned and keys earned since login.
    --------------------------------------------------------------------
    local sessHeader = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    sessHeader:SetPoint("TOPLEFT", div2, "BOTTOMLEFT", 0, -8)
    sessHeader:SetFont(sessHeader:GetFont(), 12, "OUTLINE")
    sessHeader:SetText(E.CC.header .. "Session Tracker" .. E.CC.close)

    local sessShardsFS = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    sessShardsFS:SetPoint("TOPLEFT", sessHeader, "BOTTOMLEFT", 0, -4)
    sessShardsFS:SetFont(sessShardsFS:GetFont(), 11)

    local sessKeysFS = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    sessKeysFS:SetPoint("TOPLEFT", sessShardsFS, "BOTTOMLEFT", 0, -2)
    sessKeysFS:SetFont(sessKeysFS:GetFont(), 11)

    local sessTimeFS = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    sessTimeFS:SetPoint("TOPLEFT", sessKeysFS, "BOTTOMLEFT", 0, -2)
    sessTimeFS:SetFont(sessTimeFS:GetFont(), 11)

    local sessRateFS = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    sessRateFS:SetPoint("TOPLEFT", sessTimeFS, "BOTTOMLEFT", 0, -2)
    sessRateFS:SetFont(sessRateFS:GetFont(), 10)

    --------------------------------------------------------------------
    -- Thin red divider after session tracker
    --------------------------------------------------------------------
    local div3 = sc:CreateTexture(nil, "ARTWORK")
    div3:SetHeight(1)
    div3:SetPoint("TOPLEFT", sessRateFS, "BOTTOMLEFT", 0, -8)
    div3:SetPoint("RIGHT", sc, "RIGHT", -8, 0)
    div3:SetColorTexture(dc.r, dc.g, dc.b, dc.a)

    --------------------------------------------------------------------
    -- SECTION 3b: Special Assignments
    -- 8 known Special Assignment quest IDs. Track active/completed.
    -- Weekly limit is 3 (you can complete 3 per week).
    --------------------------------------------------------------------
    local SPECIAL_ASSIGNMENTS = {
        { questID = 93013, unlockID = 94391, title = "Push back the Light" },
        { questID = 92063, unlockID = 94390, title = "A Hunter's Regret" },
        { questID = 92145, unlockID = 92848, title = "The Grand Magister's Drink" },
        { questID = 91796, unlockID = 94866, title = "Ours Once More!" },
        { questID = 93244, unlockID = 94795, title = "Agents of the Shield" },
        { questID = 92139, unlockID = 95435, title = "Shade and Claw" },
        { questID = 91390, unlockID = 94865, title = "What Remains of a Temple Broken" },
        { questID = 93438, unlockID = 94743, title = "Precision Excision" },
    }
    local SA_WEEKLY_MAX = 3

    local saHeader = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    saHeader:SetPoint("TOPLEFT", div3, "BOTTOMLEFT", 0, -8)
    saHeader:SetFont(saHeader:GetFont(), 12, "OUTLINE")
    saHeader:SetText(E.CC.header .. "Special Assignments" .. E.CC.close)

    local saSummaryFS = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    saSummaryFS:SetPoint("LEFT", saHeader, "RIGHT", 12, 0)
    saSummaryFS:SetFont(saSummaryFS:GetFont(), 11)

    -- Create rows for each assignment
    local saRows = {}
    for i, sa in ipairs(SPECIAL_ASSIGNMENTS) do
        local fs = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        fs:SetPoint("TOPLEFT", saHeader, "BOTTOMLEFT", 0, -4 - ((i - 1) * 16))
        fs:SetFont(fs:GetFont(), 10)
        fs:SetWidth(500)
        fs:SetJustifyH("LEFT")
        saRows[i] = { fs = fs, questID = sa.questID, unlockID = sa.unlockID, title = sa.title }
    end

    -- Divider after Special Assignments
    local div3b = sc:CreateTexture(nil, "ARTWORK")
    div3b:SetHeight(1)
    div3b:SetPoint("TOPLEFT", saRows[#saRows].fs, "BOTTOMLEFT", 0, -8)
    div3b:SetPoint("RIGHT", sc, "RIGHT", -8, 0)
    div3b:SetColorTexture(dc.r, dc.g, dc.b, dc.a)

    --------------------------------------------------------------------
    -- SECTION 3c: Weekly Delve Quests
    -- Quest 93595 "A Call to Delves" — weekly from Archmage Aethas
    -- Sunreaver, requires completing 5 Midnight Delves.
    --------------------------------------------------------------------
    local WEEKLY_DELVE_QUESTS = {
        { questID = 93595, title = "A Call to Delves" },
    }

    local wdqHeader = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    wdqHeader:SetPoint("TOPLEFT", div3b, "BOTTOMLEFT", 0, -8)
    wdqHeader:SetFont(wdqHeader:GetFont(), 12, "OUTLINE")
    wdqHeader:SetText(E.CC.header .. "Weekly Delve Quests" .. E.CC.close)

    local wdqRows = {}
    for i, wq in ipairs(WEEKLY_DELVE_QUESTS) do
        local fs = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        fs:SetPoint("TOPLEFT", wdqHeader, "BOTTOMLEFT", 0, -4 - ((i - 1) * 16))
        fs:SetFont(fs:GetFont(), 10)
        fs:SetWidth(500)
        fs:SetJustifyH("LEFT")
        wdqRows[i] = { fs = fs, questID = wq.questID, title = wq.title }
    end

    -- Divider after Weekly Delve Quests
    local div3c = sc:CreateTexture(nil, "ARTWORK")
    div3c:SetHeight(1)
    div3c:SetPoint("TOPLEFT", wdqRows[#wdqRows].fs, "BOTTOMLEFT", 0, -8)
    div3c:SetPoint("RIGHT", sc, "RIGHT", -8, 0)
    div3c:SetColorTexture(dc.r, dc.g, dc.b, dc.a)

    --------------------------------------------------------------------
    -- SECTION 4: Low-Shard Warning
    -- Reads lowShardWarning + lowShardThreshold from SavedVariables.
    --------------------------------------------------------------------
    local warnFS = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    warnFS:SetPoint("TOPLEFT", div3c, "BOTTOMLEFT", 0, -6)
    warnFS:SetFont(warnFS:GetFont(), 11)

    --------------------------------------------------------------------
    -- SECTION 5: Coffer Shard World Quests
    -- Scans Midnight zones for active WQs rewarding currency 3310.
    --------------------------------------------------------------------
    local WQ_ZONES = { 2395, 2413, 2405, 2437, 2393, 2424 }
    local WQ_CURRENCY = 3310
    local MAX_WQ_ROWS = 12  -- max rows to pre-create

    -- Divider before WQ section
    local div4 = sc:CreateTexture(nil, "ARTWORK")
    div4:SetHeight(1)
    div4:SetPoint("TOPLEFT", warnFS, "BOTTOMLEFT", 0, -8)
    div4:SetPoint("RIGHT", sc, "RIGHT", -8, 0)
    div4:SetColorTexture(dc.r, dc.g, dc.b, dc.a)

    local wqHeader = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    wqHeader:SetPoint("TOPLEFT", div4, "BOTTOMLEFT", 0, -8)
    wqHeader:SetFont(wqHeader:GetFont(), 12, "OUTLINE")
    wqHeader:SetText(E.CC.header .. "Coffer Shard World Quests" .. E.CC.close)

    local wqCountFS = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    wqCountFS:SetPoint("LEFT", wqHeader, "RIGHT", 12, 0)
    wqCountFS:SetFont(wqCountFS:GetFont(), 11)

    -- Refresh button for WQ section
    local wqRefreshBtn = E:CreateButton(sc, 60, 18, "Refresh")
    wqRefreshBtn.label:SetFont(wqRefreshBtn.label:GetFont(), 9)
    wqRefreshBtn:SetPoint("LEFT", wqCountFS, "RIGHT", 12, 0)
    wqRefreshBtn:SetScript("OnEnter", function(self)
        local hc = E.Colors.buttonHover
        self:SetBackdropColor(hc.r, hc.g, hc.b, hc.a)
        E:ShowTooltip(self, "Refresh WQs",
            "Force rescan all Midnight zones for\nCoffer Key Shard world quests.")
    end)
    wqRefreshBtn:SetScript("OnLeave", function(self)
        local bc = E.Colors.buttonBg
        self:SetBackdropColor(bc.r, bc.g, bc.b, bc.a)
        E:HideTooltip()
    end)

    local wqNoteFS = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    wqNoteFS:SetPoint("TOPLEFT", wqHeader, "BOTTOMLEFT", 0, -2)
    wqNoteFS:SetFont(wqNoteFS:GetFont(), 9)
    wqNoteFS:SetText(
        E.CC.muted .. "WQs rewarding Coffer Key Shards. Rewards rotate — "
        .. "click Refresh to update." .. E.CC.close
    )

    -- Column headers for WQ list
    local wqColY = -18
    for _, col in ipairs({
        { label = "Zone",   x = 0   },
        { label = "Quest",  x = 140 },
        { label = "Shards", x = 380 },
        { label = "Pin",    x = 430 },
    }) do
        local fs = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        fs:SetPoint("TOPLEFT", wqNoteFS, "BOTTOMLEFT", col.x, wqColY)
        fs:SetFont(fs:GetFont(), 10, "OUTLINE")
        fs:SetText(E.CC.muted .. col.label .. E.CC.close)
    end

    -- Pre-create reusable WQ rows
    local wqRows = {}
    for i = 1, MAX_WQ_ROWS do
        local rowY = wqColY - 14 - ((i - 1) * 18)

        local zoneFS = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        zoneFS:SetPoint("TOPLEFT", wqNoteFS, "BOTTOMLEFT", 0, rowY)
        zoneFS:SetFont(zoneFS:GetFont(), 10)
        zoneFS:SetWidth(135)
        zoneFS:SetJustifyH("LEFT")

        local nameFS = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        nameFS:SetPoint("TOPLEFT", wqNoteFS, "BOTTOMLEFT", 140, rowY)
        nameFS:SetFont(nameFS:GetFont(), 10)
        nameFS:SetWidth(235)
        nameFS:SetJustifyH("LEFT")

        local amountFS = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        amountFS:SetPoint("TOPLEFT", wqNoteFS, "BOTTOMLEFT", 380, rowY)
        amountFS:SetFont(amountFS:GetFont(), 10)

        local wpBtn = E:CreateButton(sc, 30, 16, "Pin")
        wpBtn.label:SetFont(wpBtn.label:GetFont(), 9)
        wpBtn:SetPoint("TOPLEFT", wqNoteFS, "BOTTOMLEFT", 430, rowY + 2)
        wpBtn:SetScript("OnEnter", function(self)
            local hc = E.Colors.buttonHover
            self:SetBackdropColor(hc.r, hc.g, hc.b, hc.a)
        end)
        wpBtn:SetScript("OnLeave", function(self)
            local bc = E.Colors.buttonBg
            self:SetBackdropColor(bc.r, bc.g, bc.b, bc.a)
        end)
        -- Single shared OnClick closure; reads the current wq from the
        -- button's .wq field (set on each refresh) so we don't allocate
        -- a new closure per-row per-refresh.
        wpBtn:SetScript("OnClick", function(self)
            local wq = self.wq
            if wq and C_TaskQuest and C_TaskQuest.GetQuestLocation then
                local x, y = C_TaskQuest.GetQuestLocation(wq.questID, wq.zoneID)
                if x and y then
                    E:SetWaypoint(wq.zoneID, x * 100, y * 100)
                    E:FlashButtonConfirm(self)
                end
            end
        end)

        wqRows[i] = {
            zoneFS   = zoneFS,
            nameFS   = nameFS,
            amountFS = amountFS,
            wpBtn    = wpBtn,
            visible  = false,
        }
        -- Hide by default
        zoneFS:Hide()
        nameFS:Hide()
        amountFS:Hide()
        wpBtn:Hide()
    end

    local wqEmptyFS = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    wqEmptyFS:SetPoint("TOPLEFT", wqNoteFS, "BOTTOMLEFT", 0, wqColY - 14)
    wqEmptyFS:SetFont(wqEmptyFS:GetFont(), 10)
    wqEmptyFS:SetText(
        E.CC.yellow .. "No Coffer Key Shard WQs found. Click Refresh to rescan.\n"
        .. E.CC.close .. E.CC.muted
        .. "Tip: Open your World Map to each Midnight zone first to load quest data."
        .. E.CC.close
    )
    wqEmptyFS:Hide()

    --- Scan all Midnight zones for WQs rewarding shard currency.
    --- Results are cached and only rescanned when forced or stale (>60s).
    --- Primes map data before querying. Auto-retries once after 3s on
    --- empty results (map data may not be loaded for unvisited zones).
    local wqCache      = {}    -- reusable results table
    local wqCacheTime  = 0     -- epoch when cache was last populated
    local WQ_CACHE_TTL = 60    -- seconds before cache is considered stale
    local wqRetryPending = false
    local mapsPrimed   = {}    -- [mapID] = true after first prime this session

    -- Cache zone names once (resolved lazily on first scan)
    local zoneNameCache = {}   -- [mapID] = "Zone Name"

    -- Reusable dedupe set (wiped each scan)
    local seenQuestIDs = {}

    --- Forward declaration so retry can call RefreshAll
    local RefreshAll  -- defined below

    -- Reusable sort comparator (avoids creating a closure each scan)
    local function wqSortFunc(a, b)
        if a.zone == b.zone then return a.title < b.title end
        return a.zone < b.zone
    end

    local function ScanCofferShardWQs(forceRescan)
        -- Return cached results if fresh enough
        if not forceRescan and #wqCache > 0
                and (time() - wqCacheTime) < WQ_CACHE_TTL then
            return wqCache
        end

        wipe(wqCache)
        wipe(seenQuestIDs)
        if not (C_TaskQuest and C_TaskQuest.GetQuestsOnMap
                and C_QuestLog and C_QuestLog.GetQuestRewardCurrencies) then
            return wqCache
        end

        for _, zoneID in ipairs(WQ_ZONES) do
            -- Prime map data once per session so the client loads zone WQs
            if not mapsPrimed[zoneID] then
                if C_Map and C_Map.GetMapInfo then
                    C_Map.GetMapInfo(zoneID)
                end
                if C_MapExplorationInfo
                        and C_MapExplorationInfo.GetExploredMapTextures then
                    C_MapExplorationInfo.GetExploredMapTextures(zoneID)
                end
                mapsPrimed[zoneID] = true
            end

            local quests = C_TaskQuest.GetQuestsOnMap(zoneID)

            if quests then
                for _, qData in ipairs(quests) do
                    local qid = qData.questID
                    -- Dedupe: C_TaskQuest.GetQuestsOnMap returns subzone
                    -- quests too, so the same quest may appear under
                    -- multiple parent scans.
                    if qid and qid > 0 and not seenQuestIDs[qid]
                            and C_QuestLog.IsWorldQuest
                            and C_QuestLog.IsWorldQuest(qid)
                            and not (C_QuestLog.IsQuestFlaggedCompleted
                                     and C_QuestLog.IsQuestFlaggedCompleted(qid))
                    then
                        local currencies = C_QuestLog
                            .GetQuestRewardCurrencies(qid)
                        if currencies then
                            for _, ci in ipairs(currencies) do
                                if ci.currencyID == WQ_CURRENCY then
                                    local title = "Unknown Quest"
                                    if C_TaskQuest.GetQuestInfoByQuestID then
                                        title = C_TaskQuest
                                            .GetQuestInfoByQuestID(qid)
                                            or title
                                    end
                                    -- Resolve zone name from the quest's
                                    -- OWN mapID (its actual location), not
                                    -- the parent map being scanned. Falls
                                    -- back to the scanned zone if absent.
                                    local questMapID = qData.mapID or zoneID
                                    if not zoneNameCache[questMapID] then
                                        local mi = C_Map and C_Map.GetMapInfo
                                                   and C_Map.GetMapInfo(questMapID)
                                        zoneNameCache[questMapID] =
                                            (mi and mi.name)
                                            or ("Zone " .. questMapID)
                                    end
                                    seenQuestIDs[qid] = true
                                    table_insert(wqCache, {
                                        questID = qid,
                                        title   = title,
                                        zone    = zoneNameCache[questMapID],
                                        zoneID  = questMapID,
                                        amount  = ci.totalRewardAmount or 0,
                                    })
                                    break
                                end
                            end
                        end
                    end
                end
            end
        end

        table_sort(wqCache, wqSortFunc)
        wqCacheTime = time()

        -- If scan returned 0 results, schedule one retry after 3s
        if #wqCache == 0 and not wqRetryPending then
            wqRetryPending = true
            C_Timer.After(3, function()
                wqRetryPending = false
                wqCacheTime = 0  -- invalidate cache
                if RefreshAll and frame:IsShown() then
                    RefreshAll(true)
                end
            end)
        end

        return wqCache
    end

    --------------------------------------------------------------------
    -- Session baseline — snapshot currencies at first refresh so we
    -- can compute session deltas.
    --------------------------------------------------------------------
    local sessionBaseline = nil  -- { shards = N, keys = N, time = epoch }

    local function EnsureBaseline()
        if not sessionBaseline then
            sessionBaseline = {
                shards = GetCurrency(E.CurrencyIDs.cofferKeyShards),
                keys   = GetCurrency(E.CurrencyIDs.bountifulKeys),
                time   = (E.sessionData and E.sessionData.loginTime) or time(),
            }
        end
    end

    --------------------------------------------------------------------
    -- MASTER REFRESH
    --------------------------------------------------------------------

    -- Lightweight: only updates the session timer and session deltas.
    -- Called every 1 second via OnUpdate while the tab is visible.
    local function RefreshSessionTimer()
        if not sessionBaseline then
            EnsureBaseline()
        end
        if not sessionBaseline then
            sessionBaseline = { shards = 0, keys = 0, time = time() }
        end

        local sessShards = cachedShards - sessionBaseline.shards
        local sessKeys   = cachedKeys   - sessionBaseline.keys
        local sessTime   = time() - sessionBaseline.time

        -- Format elapsed time as HH:MM:SS
        local hours   = math_floor(sessTime / 3600)
        local minutes = math_floor((sessTime % 3600) / 60)
        local seconds = sessTime % 60
        local elapsed = string_format("%d:%02d:%02d", hours, minutes, seconds)

        sessShardsFS:SetText(
            sessShards >= 0
                and string_format("|cFF999999Shards earned: |r|cFFFFD700+%s|r", FormatNumber(sessShards))
                or  string_format("|cFF999999Shards earned: |r|cFFFF3333%s|r", FormatNumber(sessShards))
        )

        sessKeysFS:SetText(
            sessKeys >= 0
                and string_format("|cFF999999Keys earned: |r|cFFFFD700+%d|r", sessKeys)
                or  string_format("|cFF999999Keys earned: |r|cFFFF3333%d|r", sessKeys)
        )

        sessTimeFS:SetText(
            string_format("|cFF999999Session time: |r|cFFE0E0E0%s|r", elapsed)
        )

        -- Shards per hour rate
        if sessTime >= 60 and sessShards > 0 then
            local perHour = math_floor(sessShards / (sessTime / 3600))
            sessRateFS:SetText(
                string_format("|cFF999999Rate: ~|r|cFFFFD700%s shards/hour|r", FormatNumber(perHour))
            )
            sessRateFS:Show()
        else
            sessRateFS:SetText("")
            sessRateFS:Hide()
        end
    end

    -- Full refresh: updates all sections. Called on OnShow, events,
    -- and manual Refresh button click — NOT on a timer.
    -- forceWQRescan: if true, bypasses the WQ scan cache.
    RefreshAll = function(forceWQRescan)

        ----------------------------------------------------------------
        -- Section 1: Currency overview
        ----------------------------------------------------------------
        cachedShards = GetCurrency(E.CurrencyIDs.cofferKeyShards)
        cachedKeys   = GetCurrency(E.CurrencyIDs.bountifulKeys)
        local shards = cachedShards
        local keys   = cachedKeys

        -- Weekly cap data from the currency API
        local _, weeklyCap, weeklyEarned = GetCurrencyFull(E.CurrencyIDs.cofferKeyShards)
        local weeklyRemaining = math_max(0, weeklyCap - weeklyEarned)

        -- Set currency icons via modern API
        shardIcon:SetTexture(E.CachedIcons.cofferShard or C_Item.GetItemIconByID(E.ItemIcons.cofferShard))
        keyIcon:SetTexture(E.CachedIcons.cofferKey or C_Item.GetItemIconByID(E.ItemIcons.cofferKey))

        -- Undercoins icon (cache after first successful resolve)
        if not cachedUcIcon then
            local ucInfo = C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo(E.CurrencyIDs.undercoins)
            if ucInfo and ucInfo.iconFileID then
                cachedUcIcon = ucInfo.iconFileID
            end
        end
        if cachedUcIcon then ucIcon:SetTexture(cachedUcIcon) end
        local uc = GetCurrency(E.CurrencyIDs.undercoins)
        ucValueFS:SetText(E.CC.gold .. FormatNumber(uc) .. E.CC.close)

        shardValueFS:SetText(E.CC.gold .. FormatNumber(shards) .. E.CC.close)
        keyValueFS:SetText(E.CC.gold .. FormatNumber(keys) .. E.CC.close)

        -- Progress toward next key
        local partial = shards % E.SHARDS_PER_KEY
        if partial == 0 and shards > 0 then
            partial = E.SHARDS_PER_KEY
        end
        nextKeyBar:SetProgress(partial, E.SHARDS_PER_KEY)
        local remaining = E.SHARDS_PER_KEY - partial
        nextKeyNote:SetText(
            E.CC.muted .. "Progress toward next key — "
            .. E.CC.close .. E.CC.gold .. remaining
            .. E.CC.close .. E.CC.muted .. " shards remaining"
            .. E.CC.close
        )

        -- Weekly shard cap progress
        if weeklyCap > 0 then
            weeklyCapBar:SetProgress(weeklyEarned, weeklyCap)
            weeklyCapNote:SetText(
                E.CC.muted .. "Weekly shard cap — "
                .. E.CC.close .. E.CC.gold .. weeklyRemaining
                .. E.CC.close .. E.CC.muted .. " shards remaining this week"
                .. E.CC.close
            )
            weeklyCapBar:Show()
            weeklyCapNote:Show()
        else
            -- API didn't return cap data; hide the bar
            weeklyCapBar:Hide()
            weeklyCapNote:SetText(
                E.CC.muted .. "Weekly shard cap data unavailable" .. E.CC.close
            )
        end

        ----------------------------------------------------------------
        -- Section 2: Weekly shard sources
        ----------------------------------------------------------------
        local weeklyTotal = 0

        for _, row in ipairs(sourceRows) do
            local src = row.src

            -- Name (with asterisk if unconfirmed)
            local displayName = src.name
            if src.unconfirmed then
                displayName = displayName .. " *"
            end
            row.nameFS:SetText(E.CC.body .. displayName .. E.CC.close)

            -- Per-unit (with asterisk if unconfirmed)
            local perText = tostring(src.shardsEach)
            if src.unconfirmed then
                perText = perText .. "*"
            end
            row.perFS:SetText(E.CC.gold .. perText .. E.CC.close)

            -- Weekly cap
            if src.weeklyMax then
                local maxShards = 0
                if type(src.shardsEach) == "number" then
                    maxShards = src.shardsEach * src.weeklyMax
                end
                row.capFS:SetText(
                    E.CC.body .. src.weeklyMax .. "x"
                    .. (maxShards > 0
                        and (" (" .. E.CC.gold .. maxShards .. E.CC.close
                             .. E.CC.body .. ")")
                        or "")
                    .. E.CC.close
                )
                if type(src.shardsEach) == "number" then
                    weeklyTotal = weeklyTotal + maxShards
                end
            else
                row.capFS:SetText(E.CC.muted .. "—" .. E.CC.close)
            end

            -- Status — live tracking for sources with questLineID or questIDs
            if src.trackable then
                local done, total = 0, 0

                if src.questLineID and C_QuestLine
                        and C_QuestLine.GetQuestLineQuests then
                    if not questLineCache[src.questLineID] then
                        questLineCache[src.questLineID] =
                            C_QuestLine.GetQuestLineQuests(src.questLineID) or {}
                    end
                    local quests = questLineCache[src.questLineID]
                    if quests then
                        total = #quests
                        for _, qid in ipairs(quests) do
                            if C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted
                                    and C_QuestLog.IsQuestFlaggedCompleted(qid) then
                                done = done + 1
                            end
                        end
                    end
                elseif src.questIDs then
                    total = #src.questIDs
                    for _, qid in ipairs(src.questIDs) do
                        if C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted
                                and C_QuestLog.IsQuestFlaggedCompleted(qid) then
                            done = done + 1
                        end
                    end
                end

                if total > 0 then
                    local cc = (done >= total) and E.CC.green or E.CC.yellow
                    row.statusFS:SetText(
                        cc .. done .. " / " .. total .. E.CC.close
                    )
                else
                    row.statusFS:SetText(
                        E.CC.green .. "Trackable" .. E.CC.close
                    )
                end
            else
                row.statusFS:SetText(
                    E.CC.muted .. "Manual" .. E.CC.close
                )
            end
        end

        weeklyTotalFS:SetText(
            E.CC.muted .. "Max trackable: " .. E.CC.close
            .. E.CC.gold .. FormatNumber(weeklyTotal) .. " shards/week"
            .. E.CC.close
        )

        -- Session tracker is updated separately by RefreshSessionTimer()
        RefreshSessionTimer()

        ----------------------------------------------------------------
        -- Section 3b: Special Assignments
        ----------------------------------------------------------------
        local saCompleted = 0
        local saActive    = 0
        for _, row in ipairs(saRows) do
            -- Check unlock status first
            local unlocked = true
            if row.unlockID and C_QuestLog
                    and C_QuestLog.IsQuestFlaggedCompleted then
                unlocked = C_QuestLog.IsQuestFlaggedCompleted(row.unlockID)
            end

            if not unlocked then
                row.fs:SetText(
                    E.CC.red .. "  SA: " .. row.title
                    .. " — Locked" .. E.CC.close
                )
            else
                local done = false
                local active = false
                if C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted then
                    done = C_QuestLog.IsQuestFlaggedCompleted(row.questID)
                end
                if not done and C_QuestLog and C_QuestLog.IsOnQuest then
                    active = C_QuestLog.IsOnQuest(row.questID)
                end

                if done then
                    saCompleted = saCompleted + 1
                    row.fs:SetText(
                        "|cFF33FF33" .. "  [Done] SA: " .. row.title .. E.CC.close
                    )
                elseif active then
                    saActive = saActive + 1
                    row.fs:SetText(
                        E.CC.green .. "  > SA: " .. row.title
                        .. " — active" .. E.CC.close
                    )
                else
                    row.fs:SetText(
                        E.CC.muted .. "  - SA: " .. row.title .. E.CC.close
                    )
                end
            end
        end

        saSummaryFS:SetText(
            E.CC.gold .. saCompleted .. E.CC.close
            .. E.CC.muted .. " / " .. SA_WEEKLY_MAX .. " completed"
            .. (saActive > 0
                and (" — " .. E.CC.green .. saActive
                     .. " active" .. E.CC.close)
                or "")
            .. E.CC.close
        )

        -- Special Assignment alert (F7)
        if E.db and E.db.alertSpecialAssignment then
            local currentActiveSAs = {}
            for _, row in ipairs(saRows) do
                local done = C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted
                             and C_QuestLog.IsQuestFlaggedCompleted(row.questID)
                local active = (not done) and C_QuestLog and C_QuestLog.IsOnQuest
                               and C_QuestLog.IsOnQuest(row.questID)
                if active then
                    table_insert(currentActiveSAs, row.questID)
                end
            end
            table_sort(currentActiveSAs)

            local storedSAs = E.db.lastKnownActiveSAs or {}
            local storedLookup = {}
            for _, id in ipairs(storedSAs) do storedLookup[id] = true end

            local hasNew = false
            for _, id in ipairs(currentActiveSAs) do
                if not storedLookup[id] then
                    hasNew = true
                    break
                end
            end

            if hasNew then
                print("|cFFFF2222[Everything Delves]|r A Special Assignment is now available! Check the Shard Tracker tab.")
            end
            E.db.lastKnownActiveSAs = currentActiveSAs
        end

        ----------------------------------------------------------------
        -- Section 3c: Weekly Delve Quests
        ----------------------------------------------------------------
        for _, row in ipairs(wdqRows) do
            local done = false
            if C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted then
                done = C_QuestLog.IsQuestFlaggedCompleted(row.questID)
            end
            if done then
                row.fs:SetText(
                    "|cFF33FF33" .. "  [Done] " .. row.title
                    .. " — completed" .. E.CC.close
                )
            else
                row.fs:SetText(
                    E.CC.green .. "  - " .. row.title
                    .. " — not yet done" .. E.CC.close
                )
            end
        end

        ----------------------------------------------------------------
        -- Section 4: Low-shard warning
        ----------------------------------------------------------------
        if E.db and E.db.lowShardWarning then
            local threshold = E.db.lowShardThreshold or 100
            if shards < threshold then
                warnFS:SetText(
                    E.CC.red .. "(!) Low shards! " .. E.CC.close
                    .. E.CC.body .. "You have "
                    .. E.CC.gold .. FormatNumber(shards) .. E.CC.close
                    .. E.CC.body .. " shards, below your "
                    .. E.CC.gold .. FormatNumber(threshold) .. E.CC.close
                    .. E.CC.body .. " threshold." .. E.CC.close
                )
                warnFS:Show()
            else
                warnFS:Hide()
            end
        else
            warnFS:Hide()
        end

        ----------------------------------------------------------------
        -- Section 5: Coffer Shard World Quests
        ----------------------------------------------------------------
        local wqs = ScanCofferShardWQs(forceWQRescan)
        wqCountFS:SetText(
            E.CC.gold .. #wqs .. E.CC.close
            .. E.CC.muted .. " active" .. E.CC.close
        )

        if #wqs == 0 then
            wqEmptyFS:Show()
            for _, row in ipairs(wqRows) do
                row.zoneFS:Hide()
                row.nameFS:Hide()
                row.amountFS:Hide()
                row.wpBtn:Hide()
            end
        else
            wqEmptyFS:Hide()
            for i, row in ipairs(wqRows) do
                if i <= #wqs then
                    local wq = wqs[i]
                    row.zoneFS:SetText(E.CC.body .. wq.zone .. E.CC.close)
                    row.nameFS:SetText(E.CC.purple .. wq.title .. E.CC.close)
                    row.amountFS:SetText(E.CC.gold .. wq.amount .. E.CC.close)
                    -- Attach current wq to the button; shared OnClick
                    -- closure (set at row creation) reads from self.wq.
                    row.wpBtn.wq = wq
                    row.zoneFS:Show()
                    row.nameFS:Show()
                    row.amountFS:Show()
                    row.wpBtn:Show()
                else
                    row.zoneFS:Hide()
                    row.nameFS:Hide()
                    row.amountFS:Hide()
                    row.wpBtn:Hide()
                end
            end
        end
    end

    -- Wire up Refresh button now that RefreshAll is defined
    wqRefreshBtn:SetScript("OnClick", function()
        wqCacheTime = 0  -- invalidate cache
        RefreshAll(true)
        E:FlashButtonConfirm(wqRefreshBtn)
    end)

    --------------------------------------------------------------------
    -- OnShow: refresh everything when the tab becomes visible
    --------------------------------------------------------------------
    -- Recompute the scroll child's real content height after layout so
    -- the scroll range matches the visible extent.
    local function UpdateContentHeight()
        -- Find the bottom of the last actually-visible element. The WQ
        -- rows may be hidden; fall back through candidates until we
        -- find one whose frame is laid out.
        local candidates = { wqEmptyFS }
        for i = #wqRows, 1, -1 do
            candidates[#candidates + 1] = wqRows[i].wpBtn
        end
        local scTop = sc:GetTop()
        local lowest
        for _, fr in ipairs(candidates) do
            if fr and fr:IsShown() then
                local b = fr:GetBottom()
                if b and (not lowest or b < lowest) then lowest = b end
            end
        end
        if scTop and lowest and scTop > lowest then
            sc:SetHeight((scTop - lowest) + 24)
        end
        UpdateScrollRange()
    end

    frame:SetScript("OnShow", function()
        EnsureBaseline()
        RefreshAll()
        C_Timer.After(0, UpdateContentHeight)
        UpdateScrollRange()
        scrollFrame:SetVerticalScroll(0)
        tabScrollBar:SetValue(0)
    end)

    --------------------------------------------------------------------
    -- OnUpdate timer: lightweight session timer refresh (1 second)
    -- Full data refresh is event-driven (OnShow, currency, quest log)
    --------------------------------------------------------------------
    local timerElapsed = 0
    frame:SetScript("OnUpdate", function(_, dt)
        timerElapsed = timerElapsed + dt
        if timerElapsed >= 1 then
            timerElapsed = 0
            if frame:IsShown() then
                RefreshSessionTimer()
            end
        end
    end)

    --------------------------------------------------------------------
    -- Register for currency and quest log events via callback list
    --------------------------------------------------------------------
    E:RegisterCallback("CurrencyUpdate", function()
        if frame:IsShown() then
            RefreshAll()
        end
    end)

    E:RegisterCallback("QuestLogUpdate", function()
        if frame:IsShown() then
            RefreshAll()  -- let WQ cache TTL handle freshness
        end
    end)

    --------------------------------------------------------------------
    -- Register with the main frame tab system
    --------------------------------------------------------------------
    E:RegisterTab(4, frame)
end)
