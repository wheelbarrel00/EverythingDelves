local E = EverythingDelves

local pairs, ipairs, type, time = pairs, ipairs, type, time
local math_floor, math_max, math_min = math.floor, math.max, math.min
local string_format = string.format
local table_insert, table_sort, wipe = table.insert, table.sort, wipe

local function GetCurrency(currencyID)
    if C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo then
        local info = C_CurrencyInfo.GetCurrencyInfo(currencyID)
        if info then
            return info.quantity or 0
        end
    end
    return 0
end

-- Returns quantity, maxWeeklyQuantity, quantityEarnedThisWeek
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

-- Cached for RefreshSessionTimer so the per-second tick avoids API table churn.
local cachedShards = 0
local cachedKeys   = 0

local questLineCache = {}
local cachedUcIcon = nil

-- Reusable scratch buffers for Special Assignment alert detection.
local saActiveBuf  = nil
local saLookupBuf  = nil

E:RegisterModule(function()
    local frame = CreateFrame("Frame", "EverythingDelvesTab4Content")

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
    -- Oversized initially; UpdateContentHeight() recomputes after layout.
    sc:SetHeight(1400)

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
    E:StyleAccentThumb(sbThumb)
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


    -- SECTION 1: Currency Overview
    local SECT_X = 8
    local SECT_Y = -6

    local currHeader = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    currHeader:SetPoint("TOPLEFT", sc, "TOPLEFT", SECT_X, SECT_Y)
    currHeader:SetFont(currHeader:GetFont(), E.HEADER_FONT_SIZE, "OUTLINE")
    E:StyleAccentHeader(currHeader, "Currency Overview")

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

    local nextKeyBar = E:CreateProgressBar(sc, 0, 14, "Shards to Next Key")
    nextKeyBar:SetPoint("TOPLEFT", ucIcon, "BOTTOMLEFT", 0, -8)
    nextKeyBar:SetPoint("RIGHT", sc, "RIGHT", -20, 0)

    local nextKeyNote = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    nextKeyNote:SetPoint("TOPLEFT", nextKeyBar, "BOTTOMLEFT", 0, -2)
    nextKeyNote:SetFont(nextKeyNote:GetFont(), 10)

    local weeklyCapBar = E:CreateProgressBar(sc, 0, 14, "Weekly Shard Cap")
    weeklyCapBar:SetPoint("TOPLEFT", nextKeyNote, "BOTTOMLEFT", 0, -6)
    weeklyCapBar:SetPoint("RIGHT", sc, "RIGHT", -20, 0)

    local weeklyCapNote = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    weeklyCapNote:SetPoint("TOPLEFT", weeklyCapBar, "BOTTOMLEFT", 0, -2)
    weeklyCapNote:SetFont(weeklyCapNote:GetFont(), 10)

    local dc = E.Colors.divider
    local div1 = sc:CreateTexture(nil, "ARTWORK")
    div1:SetHeight(1)
    div1:SetPoint("TOPLEFT", weeklyCapNote, "BOTTOMLEFT", 0, -32)
    div1:SetPoint("RIGHT", sc, "RIGHT", -8, 0)
    E:StyleAccentDivider(div1)

    -- SECTION 1b: Dawncrests
    -- "Season Max" is the per-tier seasonal cap (info.maxQuantity): Blizzard
    -- raises it weekly via hotfix, so it must be read live, never hardcoded.
    local crestHeader = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    crestHeader:SetPoint("TOPLEFT", div1, "BOTTOMLEFT", 0, -32)
    crestHeader:SetFont(crestHeader:GetFont(), E.HEADER_FONT_SIZE, "OUTLINE")
    E:StyleAccentHeader(crestHeader, "Dawncrests")

    local crestHeaderDiv = sc:CreateTexture(nil, "ARTWORK")
    crestHeaderDiv:SetHeight(1)
    crestHeaderDiv:SetPoint("TOPLEFT",  crestHeader, "BOTTOMLEFT",  0,  -2)
    crestHeaderDiv:SetPoint("TOPRIGHT", crestHeader, "BOTTOMLEFT", 545, -2)
    E:StyleGreyLine(crestHeaderDiv)

    -- Each data column gets a transparent hover frame for its tooltip;
    -- FontStrings can't take OnEnter scripts.
    local CREST_COL_Y = -12
    local CREST_COL_TIPS = {
        ["On Hand"] = {
            title = "On Hand",
            lines = {
                "How many of this crest you currently have",
                "available to spend on gear upgrades.",
            },
        },
        ["Season Max"] = {
            title = "Season Max",
            lines = {
                "The most of this crest you're allowed to earn",
                "this season - the seasonal earning cap.",
                " ",
                "Shows \"Uncapped\" when Blizzard has lifted the",
                "cap for the rest of the season.",
            },
        },
        ["Season Total"] = {
            title = "Season Total",
            lines = {
                "How many of this crest you've earned in total",
                "this season - including any you've already",
                "spent on upgrades.",
                " ",
                "Usually higher than \"On Hand\" for that reason.",
            },
        },
    }
    for _, col in ipairs({
        { label = "Crest",        x = 0   },
        { label = "On Hand",      x = 260 },
        { label = "Season Max",   x = 360 },
        { label = "Season Total", x = 460 },
    }) do
        local fs = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        fs:SetPoint("TOPLEFT", crestHeader, "BOTTOMLEFT", col.x, CREST_COL_Y)
        fs:SetFont(fs:GetFont(), 10, "OUTLINE")
        fs:SetText(E.CC.muted .. col.label .. E.CC.close)

        local tip = CREST_COL_TIPS[col.label]
        if tip then
            local hover = CreateFrame("Button", nil, sc)
            hover:SetPoint("TOPLEFT", fs, "TOPLEFT", -3, 2)
            hover:SetSize((fs:GetStringWidth() or 60) + 8, 16)
            hover:SetScript("OnEnter", function(self)
                E:ShowTooltip(self, tip.title, unpack(tip.lines))
            end)
            hover:SetScript("OnLeave", function() E:HideTooltip() end)
        end
    end

    local CREST_ROW_H  = 20
    local CREST_ROW_Y  = CREST_COL_Y - 16
    local crestRows    = {}

    for i, crest in ipairs(E.Dawncrests) do
        local rowY = CREST_ROW_Y - ((i - 1) * CREST_ROW_H)

        if i % 2 == 0 then
            local rowBg = sc:CreateTexture(nil, "BACKGROUND")
            rowBg:SetPoint("TOPLEFT", crestHeader, "BOTTOMLEFT", -2, rowY + 2)
            rowBg:SetSize(550, CREST_ROW_H)
            rowBg:SetColorTexture(0.08, 0.08, 0.08, 0.50)
        end

        local icon = sc:CreateTexture(nil, "ARTWORK")
        icon:SetPoint("TOPLEFT", crestHeader, "BOTTOMLEFT", 0, rowY + 1)
        icon:SetSize(14, 14)

        local nameFS = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        nameFS:SetPoint("TOPLEFT", crestHeader, "BOTTOMLEFT", 20, rowY)
        nameFS:SetFont(nameFS:GetFont(), 10)
        nameFS:SetWidth(235)
        nameFS:SetJustifyH("LEFT")

        local handFS = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        handFS:SetPoint("TOPLEFT", crestHeader, "BOTTOMLEFT", 260, rowY)
        handFS:SetFont(handFS:GetFont(), 10)

        local maxFS = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        maxFS:SetPoint("TOPLEFT", crestHeader, "BOTTOMLEFT", 360, rowY)
        maxFS:SetFont(maxFS:GetFont(), 10)

        local seasonFS = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        seasonFS:SetPoint("TOPLEFT", crestHeader, "BOTTOMLEFT", 460, rowY)
        seasonFS:SetFont(seasonFS:GetFont(), 10)

        crestRows[i] = {
            id       = crest.id,
            label    = crest.label,
            icon     = icon,
            nameFS   = nameFS,
            handFS   = handFS,
            maxFS    = maxFS,
            seasonFS = seasonFS,
            iconSet  = false,
        }
    end

    local crestBottomY = CREST_ROW_Y - ((#E.Dawncrests - 1) * CREST_ROW_H)
        - CREST_ROW_H
    local div1b = sc:CreateTexture(nil, "ARTWORK")
    div1b:SetHeight(1)
    div1b:SetPoint("TOPLEFT", crestHeader, "BOTTOMLEFT", 0, crestBottomY - 16)
    div1b:SetPoint("RIGHT", sc, "RIGHT", -8, 0)
    E:StyleAccentDivider(div1b)

    -- SECTION 2: Weekly Shard Sources
    local srcHeader = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    srcHeader:SetPoint("TOPLEFT", div1b, "BOTTOMLEFT", 0, -32)
    srcHeader:SetFont(srcHeader:GetFont(), E.HEADER_FONT_SIZE, "OUTLINE")
    E:StyleAccentHeader(srcHeader, "Weekly Shard Sources")

    local srcHeaderDiv = sc:CreateTexture(nil, "ARTWORK")
    srcHeaderDiv:SetHeight(1)
    srcHeaderDiv:SetPoint("TOPLEFT",  srcHeader, "BOTTOMLEFT",  0,  -2)
    srcHeaderDiv:SetPoint("TOPRIGHT", srcHeader, "BOTTOMLEFT", 445, -2)
    E:StyleGreyLine(srcHeaderDiv)

    local weeklyTotalFS = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    weeklyTotalFS:SetPoint("LEFT", srcHeader, "RIGHT", 16, 0)
    weeklyTotalFS:SetFont(weeklyTotalFS:GetFont(), 11)

    local COL_HEADERS_Y = -12
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

    local ROW_HEIGHT    = 20
    local SOURCE_ROW_Y  = COL_HEADERS_Y - 16
    local sourceRows    = {}

    for i, src in ipairs(E.ShardSources) do
        local rowY = SOURCE_ROW_Y - ((i - 1) * ROW_HEIGHT)

        if i % 2 == 0 then
            local rowBg = sc:CreateTexture(nil, "BACKGROUND")
            rowBg:SetPoint("TOPLEFT", srcHeader, "BOTTOMLEFT", -2, rowY + 2)
            rowBg:SetSize(500, ROW_HEIGHT)
            rowBg:SetColorTexture(0.08, 0.08, 0.08, 0.50)
        end

        local nameFS = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        nameFS:SetPoint("TOPLEFT", srcHeader, "BOTTOMLEFT", 0, rowY)
        nameFS:SetFont(nameFS:GetFont(), 10)
        nameFS:SetWidth(255)
        nameFS:SetJustifyH("LEFT")

        local perFS = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        perFS:SetPoint("TOPLEFT", srcHeader, "BOTTOMLEFT", 260, rowY)
        perFS:SetFont(perFS:GetFont(), 10)

        local capFS = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        capFS:SetPoint("TOPLEFT", srcHeader, "BOTTOMLEFT", 310, rowY)
        capFS:SetFont(capFS:GetFont(), 10)

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

    local lastRowY = SOURCE_ROW_Y - ((#E.ShardSources - 1) * ROW_HEIGHT)
    local belowLastRow = lastRowY - ROW_HEIGHT

    local footnoteFS = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    footnoteFS:SetPoint("TOPLEFT", srcHeader, "BOTTOMLEFT", 0, belowLastRow - 2)
    footnoteFS:SetFont(footnoteFS:GetFont(), 9)
    footnoteFS:SetText(E.CC.muted .. "* Value unconfirmed - may differ in game" .. E.CC.close)

    local div2 = sc:CreateTexture(nil, "ARTWORK")
    div2:SetHeight(1)
    div2:SetPoint("TOPLEFT", srcHeader, "BOTTOMLEFT", 0, belowLastRow - 40)
    div2:SetPoint("RIGHT", sc, "RIGHT", -8, 0)
    E:StyleAccentDivider(div2)

    -- SECTION 3: Session Tracker
    local sessHeader = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    sessHeader:SetPoint("TOPLEFT", div2, "BOTTOMLEFT", 0, -32)
    sessHeader:SetFont(sessHeader:GetFont(), E.HEADER_FONT_SIZE, "OUTLINE")
    E:StyleAccentHeader(sessHeader, "Session Tracker")

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

    local div3 = sc:CreateTexture(nil, "ARTWORK")
    div3:SetHeight(1)
    div3:SetPoint("TOPLEFT", sessRateFS, "BOTTOMLEFT", 0, -32)
    div3:SetPoint("RIGHT", sc, "RIGHT", -8, 0)
    E:StyleAccentDivider(div3)

    -- SECTION 3b: Special Assignments (weekly limit of 3 completions)
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
    saHeader:SetPoint("TOPLEFT", div3, "BOTTOMLEFT", 0, -32)
    saHeader:SetFont(saHeader:GetFont(), E.HEADER_FONT_SIZE, "OUTLINE")
    E:StyleAccentHeader(saHeader, "Special Assignments")

    local saSummaryFS = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    saSummaryFS:SetPoint("LEFT", saHeader, "RIGHT", 12, 0)
    saSummaryFS:SetFont(saSummaryFS:GetFont(), 11)

    local saRows = {}
    for i, sa in ipairs(SPECIAL_ASSIGNMENTS) do
        local fs = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        fs:SetPoint("TOPLEFT", saHeader, "BOTTOMLEFT", 0, -4 - ((i - 1) * 16))
        fs:SetFont(fs:GetFont(), 10)
        fs:SetWidth(500)
        fs:SetJustifyH("LEFT")
        saRows[i] = { fs = fs, questID = sa.questID, unlockID = sa.unlockID, title = sa.title }
    end

    local div3b = sc:CreateTexture(nil, "ARTWORK")
    div3b:SetHeight(1)
    div3b:SetPoint("TOPLEFT", saRows[#saRows].fs, "BOTTOMLEFT", 0, -32)
    div3b:SetPoint("RIGHT", sc, "RIGHT", -8, 0)
    E:StyleAccentDivider(div3b)

    -- SECTION 3c: Weekly Delve Quests
    local WEEKLY_DELVE_QUESTS = {
        { questID = 93909, title = "Midnight: Delves" },
    }

    local wdqHeader = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    wdqHeader:SetPoint("TOPLEFT", div3b, "BOTTOMLEFT", 0, -32)
    wdqHeader:SetFont(wdqHeader:GetFont(), E.HEADER_FONT_SIZE, "OUTLINE")
    E:StyleAccentHeader(wdqHeader, "Weekly Delve Quests")

    local wdqRows = {}
    for i, wq in ipairs(WEEKLY_DELVE_QUESTS) do
        local fs = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        fs:SetPoint("TOPLEFT", wdqHeader, "BOTTOMLEFT", 0, -4 - ((i - 1) * 16))
        fs:SetFont(fs:GetFont(), 10)
        fs:SetWidth(500)
        fs:SetJustifyH("LEFT")
        wdqRows[i] = { fs = fs, questID = wq.questID, title = wq.title }
    end

    local div3c = sc:CreateTexture(nil, "ARTWORK")
    div3c:SetHeight(1)
    div3c:SetPoint("TOPLEFT", wdqRows[#wdqRows].fs, "BOTTOMLEFT", 0, -32)
    div3c:SetPoint("RIGHT", sc, "RIGHT", -8, 0)
    E:StyleAccentDivider(div3c)

    -- SECTION 4: Low-Shard Warning
    local warnFS = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    warnFS:SetPoint("TOPLEFT", div3c, "BOTTOMLEFT", 0, -6)
    warnFS:SetFont(warnFS:GetFont(), 11)

    -- SECTION 5: Coffer Shard World Quests (Midnight zones, currency 3310)
    local WQ_ZONES = { 2395, 2413, 2405, 2437, 2393, 2424 }
    local WQ_CURRENCY = 3310
    local MAX_WQ_ROWS = 12

    local div4 = sc:CreateTexture(nil, "ARTWORK")
    div4:SetHeight(1)
    div4:SetPoint("TOPLEFT", warnFS, "BOTTOMLEFT", 0, -32)
    div4:SetPoint("RIGHT", sc, "RIGHT", -8, 0)
    E:StyleAccentDivider(div4)

    local wqHeader = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    wqHeader:SetPoint("TOPLEFT", div4, "BOTTOMLEFT", 0, -32)
    wqHeader:SetFont(wqHeader:GetFont(), E.HEADER_FONT_SIZE, "OUTLINE")
    E:StyleAccentHeader(wqHeader, "Coffer Shard World Quests")

    local wqCountFS = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    wqCountFS:SetPoint("LEFT", wqHeader, "RIGHT", 12, 0)
    wqCountFS:SetFont(wqCountFS:GetFont(), 11)

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
    wqNoteFS:SetPoint("TOPLEFT", wqHeader, "BOTTOMLEFT", 0, -14)
    wqNoteFS:SetFont(wqNoteFS:GetFont(), 9)
    wqNoteFS:SetText(
        E.CC.muted .. "WQs rewarding Coffer Key Shards. Rewards rotate - "
        .. "click Refresh to update." .. E.CC.close
    )

    local wqCapWarningFS = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    wqCapWarningFS:SetPoint("TOPLEFT", wqNoteFS, "BOTTOMLEFT", 0, -2)
    wqCapWarningFS:SetFont(wqCapWarningFS:GetFont(), 9, "OUTLINE")
    wqCapWarningFS:SetWidth(540)
    wqCapWarningFS:SetJustifyH("LEFT")
    wqCapWarningFS:SetText(
        E.CC.gold .. "Weekly shard cap reached — shards will not be awarded until reset." .. E.CC.close
    )
    wqCapWarningFS:Hide()

    local wqColY = -18

    local wqHdrLineTop = sc:CreateTexture(nil, "ARTWORK")
    wqHdrLineTop:SetHeight(1)
    wqHdrLineTop:SetPoint("TOPLEFT",  wqNoteFS, "BOTTOMLEFT",  0, wqColY + 10)
    wqHdrLineTop:SetPoint("TOPRIGHT", wqNoteFS, "BOTTOMLEFT", 520, wqColY + 10)
    E:StyleGreyLine(wqHdrLineTop)

    for _, col in ipairs({
        { label = "Zone",   x = 0   },
        { label = "Quest",  x = 140 },
        { label = "Shards", x = 380 },
        { label = "Pin",    x = 430 },
        { label = "TomTom", x = 470 },
    }) do
        local fs = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        fs:SetPoint("TOPLEFT", wqNoteFS, "BOTTOMLEFT", col.x, wqColY)
        fs:SetFont(fs:GetFont(), 10, "OUTLINE")
        fs:SetText(E.CC.muted .. col.label .. E.CC.close)
    end

    local wqHdrLineBot = sc:CreateTexture(nil, "ARTWORK")
    wqHdrLineBot:SetHeight(1)
    wqHdrLineBot:SetPoint("TOPLEFT",  wqNoteFS, "BOTTOMLEFT",  0, wqColY - 16)
    wqHdrLineBot:SetPoint("TOPRIGHT", wqNoteFS, "BOTTOMLEFT", 520, wqColY - 16)
    E:StyleGreyLine(wqHdrLineBot)

    local wqRows = {}
    for i = 1, MAX_WQ_ROWS do
        local rowY = wqColY - 28 - ((i - 1) * 18)

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
            if self.dimmed then return end
            local hc = E.Colors.buttonHover
            self:SetBackdropColor(hc.r, hc.g, hc.b, hc.a)
        end)
        wpBtn:SetScript("OnLeave", function(self)
            if self.dimmed then return end
            local bc = E.Colors.buttonBg
            self:SetBackdropColor(bc.r, bc.g, bc.b, bc.a)
        end)
        -- Shared OnClick reads self.wq (set each refresh) to avoid a closure per row.
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

        local ttBtn = E:CreateButton(sc, 50, 16, "TomTom")
        ttBtn.label:SetFont(ttBtn.label:GetFont(), 9)
        ttBtn:SetPoint("TOPLEFT", wqNoteFS, "BOTTOMLEFT", 470, rowY + 2)
        ttBtn:SetScript("OnEnter", function(self)
            if not self.dimmed then
                local hc = E.Colors.buttonHover
                self:SetBackdropColor(hc.r, hc.g, hc.b, hc.a)
            end
            if E:IsTomTomLoaded() then
                E:ShowTooltip(self, "TomTom Waypoint",
                              "Add an arrow waypoint via TomTom.")
            else
                E:ShowTooltip(self, "TomTom Not Installed",
                              "Install the TomTom addon to use arrow waypoints.")
            end
        end)
        ttBtn:SetScript("OnLeave", function(self)
            if not self.dimmed then
                local bc = E.Colors.buttonBg
                self:SetBackdropColor(bc.r, bc.g, bc.b, bc.a)
            end
            E:HideTooltip()
        end)
        ttBtn:SetScript("OnClick", function(self)
            local wq = self.wq
            if not (wq and C_TaskQuest and C_TaskQuest.GetQuestLocation) then return end
            if not E:IsTomTomLoaded() then return end
            local x, y = C_TaskQuest.GetQuestLocation(wq.questID, wq.zoneID)
            if x and y then
                E:AddTomTomWaypoint(wq.zoneID, x * 100, y * 100, wq.title)
                E:FlashButtonConfirm(self)
            end
        end)

        wqRows[i] = {
            zoneFS   = zoneFS,
            nameFS   = nameFS,
            amountFS = amountFS,
            wpBtn    = wpBtn,
            ttBtn    = ttBtn,
            visible  = false,
        }
        zoneFS:Hide()
        nameFS:Hide()
        amountFS:Hide()
        wpBtn:Hide()
        ttBtn:Hide()
    end

    local wqEmptyFS = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    wqEmptyFS:SetPoint("TOPLEFT", wqNoteFS, "BOTTOMLEFT", 0, wqColY - 35)
    wqEmptyFS:SetFont(wqEmptyFS:GetFont(), 10)
    wqEmptyFS:SetText(
        E.CC.yellow .. "No Coffer Key Shard WQs found. Click Refresh to rescan.\n"
        .. E.CC.close .. E.CC.muted
        .. "Tip: Open your World Map to each Midnight zone first to load quest data."
        .. E.CC.close
    )
    wqEmptyFS:Hide()

    -- Anchor is updated in RefreshAll to follow the last visible row/message.
    local wqBottomFS = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    wqBottomFS:SetPoint("TOPLEFT", wqEmptyFS, "BOTTOMLEFT", 0, -14)
    wqBottomFS:SetFont(wqBottomFS:GetFont(), 9)
    wqBottomFS:SetText(
        E.CC.muted .. "* Tip: Visit zone maps to load WQ data before refreshing." .. E.CC.close
    )

    local wqCache      = {}
    local wqEntryPool  = {}
    local wqCacheTime  = 0
    local WQ_CACHE_TTL = 60    -- seconds before cache is considered stale
    local wqRetryPending = false
    local wqRetriesUsed  = 0
    local WQ_MAX_RETRIES = 1   -- one retry, then stop forever (see below)
    local mapsPrimed   = {}
    local zoneNameCache = {}
    local seenQuestIDs = {}

    local RefreshAll  -- forward decl; retry calls it
    local UpdateContentHeight  -- forward decl; assigned in OnShow setup

    local function wqSortFunc(a, b)
        if a.zone == b.zone then return a.title < b.title end
        return a.zone < b.zone
    end

    local function ScanCofferShardWQs(forceRescan)
        if not forceRescan and #wqCache > 0
                and (time() - wqCacheTime) < WQ_CACHE_TTL then
            return wqCache
        end

        -- Recycle entries into the pool rather than GC them, then empty the cache.
        for i = #wqCache, 1, -1 do
            local e = wqCache[i]
            wqCache[i] = nil
            wipe(e)
            wqEntryPool[#wqEntryPool + 1] = e
        end
        wipe(seenQuestIDs)
        if not (C_TaskQuest and C_TaskQuest.GetQuestsOnMap
                and C_QuestLog and C_QuestLog.GetQuestRewardCurrencies) then
            return wqCache
        end

        for _, zoneID in ipairs(WQ_ZONES) do
            -- Prime map data once per session so the client loads the zone's WQs.
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
                    -- GetQuestsOnMap returns subzone quests too, so dedupe across parent scans.
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
                                    -- Use the quest's own mapID (its location), not the scanned parent.
                                    local questMapID = qData.mapID or zoneID
                                    if not zoneNameCache[questMapID] then
                                        local mi = C_Map and C_Map.GetMapInfo
                                                   and C_Map.GetMapInfo(questMapID)
                                        zoneNameCache[questMapID] =
                                            (mi and mi.name)
                                            or ("Zone " .. questMapID)
                                    end
                                    seenQuestIDs[qid] = true
                                    local n = #wqEntryPool
                                    local entry
                                    if n > 0 then
                                        entry = wqEntryPool[n]
                                        wqEntryPool[n] = nil
                                    else
                                        entry = {}
                                    end
                                    entry.questID = qid
                                    entry.title   = title
                                    entry.zone    = zoneNameCache[questMapID]
                                    entry.zoneID  = questMapID
                                    entry.amount  = ci.totalRewardAmount or 0
                                    table_insert(wqCache, entry)
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

        -- Empty scan: retry once after 3s (unvisited-zone map data may be unloaded).
        -- The cap stops it rescheduling forever on chars with no shard WQs.
        if #wqCache == 0
                and not wqRetryPending
                and wqRetriesUsed < WQ_MAX_RETRIES then
            wqRetryPending = true
            wqRetriesUsed  = wqRetriesUsed + 1
            C_Timer.After(3, function()
                wqRetryPending = false
                wqCacheTime = 0
                if RefreshAll and frame:IsShown() then
                    RefreshAll(true)
                end
            end)
        elseif #wqCache > 0 then
            wqRetriesUsed = 0  -- reset budget once WQs are seen
        end

        return wqCache
    end

    -- Snapshot currencies at first refresh to compute session deltas.
    local sessionBaseline = nil  -- { shards, keys, time }

    local function EnsureBaseline()
        if not sessionBaseline then
            sessionBaseline = {
                shards = GetCurrency(E.CurrencyIDs.cofferKeyShards),
                keys   = GetCurrency(E.CurrencyIDs.bountifulKeys),
                time   = (E.sessionData and E.sessionData.loginTime) or time(),
            }
        end
    end

    -- Lightweight: session timer and deltas only. Called every 1s via OnUpdate.
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

    -- Full refresh of all sections. Event/OnShow/button driven, not timed.
    -- forceWQRescan bypasses the WQ scan cache.
    RefreshAll = function(forceWQRescan)

        -- Section 1: Currency overview
        cachedShards = GetCurrency(E.CurrencyIDs.cofferKeyShards)
        cachedKeys   = GetCurrency(E.CurrencyIDs.bountifulKeys)
        local shards = cachedShards
        local keys   = cachedKeys

        local _, weeklyCap, weeklyEarned = GetCurrencyFull(E.CurrencyIDs.cofferKeyShards)
        local weeklyRemaining = math_max(0, weeklyCap - weeklyEarned)
        local isAtCap = weeklyCap > 0 and weeklyEarned >= weeklyCap

        shardIcon:SetTexture(E.CachedIcons.cofferShard or C_Item.GetItemIconByID(E.ItemIcons.cofferShard))
        keyIcon:SetTexture(E.CachedIcons.cofferKey or C_Item.GetItemIconByID(E.ItemIcons.cofferKey))

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

        local partial = shards % E.SHARDS_PER_KEY
        if partial == 0 and shards > 0 then
            partial = E.SHARDS_PER_KEY
        end
        nextKeyBar:SetProgress(partial, E.SHARDS_PER_KEY)
        local remaining = E.SHARDS_PER_KEY - partial
        nextKeyNote:SetText(
            E.CC.muted .. "Progress toward next key - "
            .. E.CC.close .. E.CC.gold .. remaining
            .. E.CC.close .. E.CC.muted .. " shards remaining"
            .. E.CC.close
        )

        if weeklyCap > 0 then
            weeklyCapBar:SetProgress(weeklyEarned, weeklyCap)
            weeklyCapNote:SetText(
                E.CC.muted .. "Weekly shard cap - "
                .. E.CC.close .. E.CC.gold .. weeklyRemaining
                .. E.CC.close .. E.CC.muted .. " shards remaining this week"
                .. E.CC.close
            )
            weeklyCapBar:Show()
            weeklyCapNote:Show()
        else
            weeklyCapBar:Hide()
            weeklyCapNote:SetText(
                E.CC.muted .. "Weekly shard cap data unavailable" .. E.CC.close
            )
        end

        -- Section 1b: Dawncrests
        for _, row in ipairs(crestRows) do
            local info = C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo
                         and C_CurrencyInfo.GetCurrencyInfo(row.id)
            if info then
                if not row.iconSet and info.iconFileID then
                    row.icon:SetTexture(info.iconFileID)
                    row.iconSet = true
                end
                local crestName = (info.name and info.name ~= "")
                    and info.name or row.label
                local qty    = info.quantity or 0
                local season = info.totalEarned or 0
                -- Zero = uncapped (S1 caps removed by hotfix); read live so a
                -- reintroduced cap shows up without an addon update.
                local seasonMax = info.maxQuantity or 0
                row.nameFS:SetText(E.CC.body .. crestName .. E.CC.close)
                row.handFS:SetText(E.CC.gold .. FormatNumber(qty) .. E.CC.close)
                row.maxFS:SetText(seasonMax > 0
                    and (E.CC.body .. FormatNumber(seasonMax) .. E.CC.close)
                    or  (E.CC.muted .. "Uncapped" .. E.CC.close))
                -- Red once at cap: further crests from capped sources are lost.
                local seasonColor = E.CC.body
                if seasonMax > 0 and season >= seasonMax then
                    seasonColor = E.CC.red
                end
                row.seasonFS:SetText(season > 0
                    and (seasonColor .. FormatNumber(season) .. E.CC.close)
                    or  (E.CC.muted .. "-" .. E.CC.close))
            else
                row.nameFS:SetText(E.CC.muted .. row.label .. E.CC.close)
                row.handFS:SetText(E.CC.muted .. "-" .. E.CC.close)
                row.maxFS:SetText(E.CC.muted .. "-" .. E.CC.close)
                row.seasonFS:SetText(E.CC.muted .. "-" .. E.CC.close)
            end
        end

        -- Section 2: Weekly shard sources
        for _, row in ipairs(sourceRows) do
            local src = row.src

            local displayName = src.name
            if src.unconfirmed then
                displayName = displayName .. " *"
            end
            row.nameFS:SetText(E.CC.body .. displayName .. E.CC.close)

            local perText = tostring(src.shardsEach)
            if src.unconfirmed then
                perText = perText .. "*"
            end
            row.perFS:SetText(E.CC.gold .. perText .. E.CC.close)

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
            else
                row.capFS:SetText(E.CC.muted .. "-" .. E.CC.close)
            end

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

        -- Live cap from the currency API (600 in S1), not a sum of rows, so it never goes stale.
        if weeklyCap and weeklyCap > 0 then
            weeklyTotalFS:SetText(
                E.CC.muted .. "Weekly cap: " .. E.CC.close
                .. E.CC.gold .. FormatNumber(weeklyCap) .. " shards/week"
                .. E.CC.close
            )
        else
            weeklyTotalFS:SetText("")
        end

        RefreshSessionTimer()

        -- Section 3b: Special Assignments
        local saCompleted = 0
        local saActive    = 0
        for _, row in ipairs(saRows) do
            local unlocked = true
            if row.unlockID and C_QuestLog
                    and C_QuestLog.IsQuestFlaggedCompleted then
                unlocked = C_QuestLog.IsQuestFlaggedCompleted(row.unlockID)
            end

            if not unlocked then
                row.fs:SetText(
                    E.CC.red .. "  SA: " .. row.title
                    .. " - Locked" .. E.CC.close
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
                        .. " - active" .. E.CC.close
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
                and (" - " .. E.CC.green .. saActive
                     .. " active" .. E.CC.close)
                or "")
            .. E.CC.close
        )

        if E.db and E.db.alertSpecialAssignment then
            -- Reusable scratch tables to detect the "no SA" -> "SA active" transition.
            if not saActiveBuf  then saActiveBuf  = {} end
            if not saLookupBuf then saLookupBuf = {} end
            wipe(saActiveBuf)
            wipe(saLookupBuf)

            for _, row in ipairs(saRows) do
                local done = C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted
                             and C_QuestLog.IsQuestFlaggedCompleted(row.questID)
                local active = (not done) and C_QuestLog and C_QuestLog.IsOnQuest
                               and C_QuestLog.IsOnQuest(row.questID)
                if active then
                    table_insert(saActiveBuf, row.questID)
                end
            end
            table_sort(saActiveBuf)

            local storedSAs = E.db.lastKnownActiveSAs or {}
            for _, id in ipairs(storedSAs) do saLookupBuf[id] = true end

            local hasNew = false
            for _, id in ipairs(saActiveBuf) do
                if not saLookupBuf[id] then
                    hasNew = true
                    break
                end
            end

            if hasNew then
                print("|cFFFF2222[Everything Delves]|r A Special Assignment is now available! Check the Shard Tracker tab.")
            end
            -- Mutate in place rather than replacing the reference each refresh.
            if not E.db.lastKnownActiveSAs then E.db.lastKnownActiveSAs = {} end
            wipe(E.db.lastKnownActiveSAs)
            for i = 1, #saActiveBuf do
                E.db.lastKnownActiveSAs[i] = saActiveBuf[i]
            end
        end

        -- Section 3c: Weekly Delve Quests
        for _, row in ipairs(wdqRows) do
            local done = false
            if C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted then
                done = C_QuestLog.IsQuestFlaggedCompleted(row.questID)
            end
            if done then
                row.fs:SetText(
                    "|cFF33FF33" .. "  [Done] " .. row.title
                    .. " - completed" .. E.CC.close
                )
            else
                row.fs:SetText(
                    E.CC.green .. "  - " .. row.title
                    .. " - not yet done" .. E.CC.close
                )
            end
        end

        -- Section 4: Low-shard warning
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

        -- Section 5: Coffer Shard World Quests
        local wqs = ScanCofferShardWQs(forceWQRescan)
        wqCountFS:SetText(
            E.CC.gold .. #wqs .. E.CC.close
            .. E.CC.muted .. " active" .. E.CC.close
        )

        if isAtCap then
            wqCapWarningFS:Show()
        else
            wqCapWarningFS:Hide()
        end

        if #wqs == 0 then
            wqEmptyFS:Show()
            for _, row in ipairs(wqRows) do
                row.zoneFS:Hide()
                row.nameFS:Hide()
                row.amountFS:Hide()
                row.wpBtn:Hide()
                row.ttBtn:Hide()
            end
            wqCapWarningFS:ClearAllPoints()
            wqBottomFS:ClearAllPoints()
            if isAtCap then
                wqCapWarningFS:SetPoint("TOPLEFT", wqEmptyFS, "BOTTOMLEFT", 0, -16)
                wqBottomFS:SetPoint("TOPLEFT", wqCapWarningFS, "BOTTOMLEFT", 0, -12)
            else
                wqBottomFS:SetPoint("TOPLEFT", wqEmptyFS, "BOTTOMLEFT", 0, -14)
            end
        else
            wqEmptyFS:Hide()
            for i, row in ipairs(wqRows) do
                if i <= #wqs then
                    local wq = wqs[i]
                    local zoneCC   = isAtCap and E.CC.muted  or E.CC.body
                    local nameCC   = isAtCap and E.CC.muted  or E.CC.purple
                    local amountCC = isAtCap and E.CC.muted  or E.CC.gold
                    row.zoneFS:SetText(zoneCC   .. wq.zone   .. E.CC.close)
                    row.nameFS:SetText(nameCC   .. wq.title  .. E.CC.close)
                    row.amountFS:SetText(amountCC .. wq.amount .. E.CC.close)
                    -- Dim buttons at cap (still clickable); restored on uncap.
                    if isAtCap then
                        row.wpBtn.dimmed = true
                        row.ttBtn.dimmed = true
                        row.wpBtn:SetBackdropColor(0.15, 0.15, 0.15, 0.80)
                        row.ttBtn:SetBackdropColor(0.15, 0.15, 0.15, 0.80)
                        row.wpBtn:SetBackdropBorderColor(0.35, 0.35, 0.35, 0.80)
                        row.ttBtn:SetBackdropBorderColor(0.35, 0.35, 0.35, 0.80)
                        row.wpBtn.label:SetTextColor(0.55, 0.55, 0.55, 1)
                        row.ttBtn.label:SetTextColor(0.55, 0.55, 0.55, 1)
                    else
                        row.wpBtn.dimmed = false
                        row.ttBtn.dimmed = false
                        local bc = E.Colors.buttonBg
                        row.wpBtn:SetBackdropColor(bc.r, bc.g, bc.b, bc.a)
                        row.ttBtn:SetBackdropColor(bc.r, bc.g, bc.b, bc.a)
                        -- Buttons aren't accent-themed; restore the hardcoded dark border.
                        row.wpBtn:SetBackdropBorderColor(0.10, 0.00, 0.00, 1.00)
                        row.ttBtn:SetBackdropBorderColor(0.10, 0.00, 0.00, 1.00)
                        row.wpBtn.label:SetTextColor(0.922, 0.718, 0.024, 1)
                        row.ttBtn.label:SetTextColor(0.922, 0.718, 0.024, 1)
                    end
                    row.wpBtn.wq = wq
                    row.ttBtn.wq = wq
                    row.zoneFS:Show()
                    row.nameFS:Show()
                    row.amountFS:Show()
                    row.wpBtn:Show()
                    row.ttBtn:Show()
                else
                    row.zoneFS:Hide()
                    row.nameFS:Hide()
                    row.amountFS:Hide()
                    row.wpBtn:Hide()
                    row.ttBtn:Hide()
                end
            end
            local lastRow = wqRows[#wqs]
            wqCapWarningFS:ClearAllPoints()
            wqBottomFS:ClearAllPoints()
            if isAtCap then
                wqCapWarningFS:SetPoint("TOPLEFT", lastRow.zoneFS, "BOTTOMLEFT", 0, -16)
                wqBottomFS:SetPoint("TOPLEFT", wqCapWarningFS, "BOTTOMLEFT", 0, -12)
            else
                wqBottomFS:SetPoint("TOPLEFT", lastRow.zoneFS, "BOTTOMLEFT", 0, -14)
            end
        end

        -- Deferred to next frame so layout is settled before measuring.
        if UpdateContentHeight then
            C_Timer.After(0, UpdateContentHeight)
        end
    end

    wqRefreshBtn:SetScript("OnClick", function()
        wqCacheTime   = 0
        wqRetriesUsed = 0   -- give the retry budget back on user request
        RefreshAll(true)
        E:FlashButtonConfirm(wqRefreshBtn)
    end)

    -- Recompute the scroll child's content height to match the visible extent.
    UpdateContentHeight = function()
        -- WQ rows may be hidden; fall back through candidates to the lowest laid-out one.
        local candidates = { wqEmptyFS, wqBottomFS }
        for i = #wqRows, 1, -1 do
            candidates[#candidates + 1] = wqRows[i].wpBtn
            candidates[#candidates + 1] = wqRows[i].ttBtn
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
            sc:SetHeight((scTop - lowest) + 40)
        end
        UpdateScrollRange()
    end

    frame:SetScript("OnShow", function()
        EnsureBaseline()
        wqRetriesUsed = 0   -- fresh retry budget each time the tab opens
        RefreshAll()
        C_Timer.After(0, UpdateContentHeight)
        UpdateScrollRange()
        scrollFrame:SetVerticalScroll(0)
        tabScrollBar:SetValue(0)
    end)

    -- Timer refreshes the session clock only; full data is event-driven.
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

    -- Background event refreshes must not reset scroll: UpdateContentHeight can
    -- clamp it when content shrinks, so save and restore the value around it.
    local function RefreshPreservingScroll()
        if not frame:IsShown() then return end
        local prevScroll = scrollFrame:GetVerticalScroll()
        RefreshAll()
        C_Timer.After(0, function()
            if scrollFrame and scrollFrame.SetVerticalScroll then
                scrollFrame:SetVerticalScroll(prevScroll)
                if tabScrollBar and tabScrollBar.SetValue then
                    tabScrollBar:SetValue(prevScroll)
                end
            end
        end)
    end

    E:RegisterCallback("CurrencyUpdate", RefreshPreservingScroll)
    E:RegisterCallback("QuestLogUpdate", RefreshPreservingScroll)

    E:RegisterTab(5, frame)
end)
