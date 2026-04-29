------------------------------------------------------------------------
-- UI/TabDelveHistory.lua — Tab 5: Delve History
--
-- Displays lifetime stats and recent-run log for each Midnight delve
-- recorded in EverythingDelvesDB.delveHistory. The SCENARIO_COMPLETED
-- logger in EverythingDelves.lua populates that table; this tab only
-- reads it.
--
-- Memory rules honoured:
--   * No OnUpdate on this tab.
--   * No closures allocated in loops (header/run rows share a single
--     OnClick that reads self.delveKey).
--   * Delve header rows and per-run detail rows are recycled from
--     pools — we never destroy or recreate frames on refresh.
--   * Refresh fires only from OnShow and the explicit
--     E:RefreshDelveHistoryTab() hook called when a run is logged or
--     history is cleared.
------------------------------------------------------------------------
local E = EverythingDelves
---@diagnostic disable: need-check-nil

------------------------------------------------------------------------
-- Local references for frequently accessed globals
------------------------------------------------------------------------
local pairs, ipairs              = pairs, ipairs
local math_floor, math_max       = math.floor, math.max
local string_format              = string.format
local table_sort, table_insert   = table.sort, table.insert
local date, time                 = date, time

------------------------------------------------------------------------
-- Formatting helpers
------------------------------------------------------------------------
--- Return "Xm YYs" or "Xh Ym" depending on size.
local function FormatDuration(sec)
    sec = sec or 0
    if sec <= 0 then return "--" end
    if sec < 3600 then
        local m = math_floor(sec / 60)
        local s = sec - m * 60
        return string_format("%dm %02ds", m, s)
    end
    local h = math_floor(sec / 3600)
    local m = math_floor((sec - h * 3600) / 60)
    return string_format("%dh %dm", h, m)
end

--- Return a compact "Apr 22, 2026" date string.
local function FormatDate(ts)
    if not ts or ts == 0 then return "" end
    return date("%b %d, %Y", ts)
end

------------------------------------------------------------------------
-- MODULE INIT
------------------------------------------------------------------------
E:RegisterModule(function()
    local frame = CreateFrame("Frame", "EverythingDelvesTab5Content")

    --------------------------------------------------------------------
    -- Header: title + aggregate summary
    --------------------------------------------------------------------
    local HDR_X = 8
    local HDR_Y = -6

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", frame, "TOPLEFT", HDR_X, HDR_Y)
    title:SetFont(title:GetFont(), E.HEADER_FONT_SIZE, "OUTLINE")
    E:StyleAccentHeader(title, "Delve History")

    local summaryFS = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    summaryFS:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    summaryFS:SetFont(summaryFS:GetFont(), 11)

    local dc = E.Colors.divider
    local headerDiv = frame:CreateTexture(nil, "ARTWORK")
    headerDiv:SetHeight(1)
    headerDiv:SetPoint("TOPLEFT",  summaryFS, "BOTTOMLEFT", 0, -6)
    headerDiv:SetPoint("RIGHT",    frame, "RIGHT", -8, 0)
    E:StyleAccentDivider(headerDiv)

    --------------------------------------------------------------------
    -- Clear History button (top-right, subtle)
    --------------------------------------------------------------------
    local clearBtn = E:CreateButton(frame, 100, 20, "Clear History")
    clearBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -8, -6)
    if clearBtn.Text then
        clearBtn.Text:SetFont(clearBtn.Text:GetFont(), 10)
    end
    clearBtn:SetScript("OnClick", function()
        StaticPopup_Show("EVERYTHINGDELVES_CLEAR_HISTORY")
    end)
    clearBtn:SetScript("OnEnter", function(self)
        local hc = E.Colors.buttonHover
        self:SetBackdropColor(hc.r, hc.g, hc.b, hc.a)
        E:ShowTooltip(self, "Clear Delve History",
            "Erase all recorded delve runs and lifetime stats",
            E.CC.red .. "This cannot be undone." .. E.CC.close)
    end)
    clearBtn:SetScript("OnLeave", function(self)
        local bc = E.Colors.buttonBg
        self:SetBackdropColor(bc.r, bc.g, bc.b, bc.a)
        E:HideTooltip()
    end)

    --------------------------------------------------------------------
    -- Scroll frame + scroll child
    --------------------------------------------------------------------
    local scrollFrame = CreateFrame("ScrollFrame", nil, frame)
    scrollFrame:SetPoint("TOPLEFT",     headerDiv, "BOTTOMLEFT", 0, -4)
    scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -18, 4)
    scrollFrame:EnableMouseWheel(true)

    local sc = CreateFrame("Frame")
    sc:SetSize(1, 1)
    scrollFrame:SetScrollChild(sc)
    scrollFrame:SetScript("OnSizeChanged", function(_, w) sc:SetWidth(w) end)
    sc:SetHeight(400)

    -- Themed scrollbar
    local tabScrollBar = CreateFrame("Slider", nil, scrollFrame, "BackdropTemplate")
    tabScrollBar:SetWidth(14)
    tabScrollBar:SetPoint("TOPRIGHT",    scrollFrame, "TOPRIGHT",    16, 0)
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
        local newVal = math_max(0, math.min(
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
    -- Section headers (Nemesis, Midnight Delves) — pre-created, shown
    -- or hidden depending on whether content exists.
    --------------------------------------------------------------------
    local nemesisHeader = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    nemesisHeader:SetFont(nemesisHeader:GetFont(), E.HEADER_FONT_SIZE, "OUTLINE")
    E:StyleAccentHeader(nemesisHeader, "Seasonal Nemesis")

    local nemesisEmptyFS = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    nemesisEmptyFS:SetFont(nemesisEmptyFS:GetFont(), 10)
    nemesisEmptyFS:SetText(E.CC.muted
        .. "No nemesis delve runs recorded yet." .. E.CC.close)

    local midnightHeader = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    midnightHeader:SetFont(midnightHeader:GetFont(), E.HEADER_FONT_SIZE, "OUTLINE")
    E:StyleAccentHeader(midnightHeader, "Midnight Delves")

    local midnightEmptyFS = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    midnightEmptyFS:SetFont(midnightEmptyFS:GetFont(), 10)
    midnightEmptyFS:SetText(E.CC.muted
        .. "No Midnight delve runs recorded yet. Complete a delve to "
        .. "start tracking!" .. E.CC.close)

    -- Accent-colour dividers for the Seasonal Nemesis / Midnight Delves
    -- sections. Parented to `frame` (NOT `sc`) so they are not clipped
    -- to the ScrollFrame viewport — this lets them stretch the full
    -- frame width to match the top `headerDiv`. They are anchored
    -- vertically to scrollFrame TOP with offset = yCur in Refresh, and
    -- horizontally to frame edges to mirror headerDiv exactly.
    local nemesisDivider = frame:CreateTexture(nil, "ARTWORK")
    nemesisDivider:SetHeight(1)
    E:StyleAccentDivider(nemesisDivider)
    nemesisDivider:Hide()

    local midnightDivider = frame:CreateTexture(nil, "ARTWORK")
    midnightDivider:SetHeight(1)
    E:StyleAccentDivider(midnightDivider)
    midnightDivider:Hide()

    --------------------------------------------------------------------
    -- Frame pools
    --------------------------------------------------------------------
    local HEADER_ROW_HEIGHT = 22
    local RUN_ROW_HEIGHT    = 16

    local headerRowPool = {}  -- delve summary rows (collapsible)
    local runRowPool    = {}  -- individual run detail rows

    -- Track expanded state keyed by delve name — survives refresh.
    local expandedByKey = {}

    -- Forward-declared refresher so the toggle OnClick can call it.
    local Refresh

    --- Single shared OnClick used by every header row: flips the
    --- expanded flag for the bound delve key and triggers a refresh.
    local function HeaderRow_OnClick(self)
        local key = self.delveKey
        if not key then return end
        expandedByKey[key] = not expandedByKey[key]
        if Refresh then Refresh() end
    end

    -- Rows stay neutral on hover/click — no background tint.

    --- Create a reusable header row. All textual fields are FontStrings
    --- that are re-populated each refresh; the row is a plain Button
    --- with a shared OnClick so no closures are allocated per delve.
    local function CreateHeaderRow()
        local row = CreateFrame("Button", nil, sc)
        row:SetHeight(HEADER_ROW_HEIGHT)
        row:SetPoint("LEFT",  sc, "LEFT",  8,  0)
        row:SetPoint("RIGHT", sc, "RIGHT", -8, 0)

        local arrowFS = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        arrowFS:SetPoint("LEFT", row, "LEFT", 2, 0)
        arrowFS:SetFont(arrowFS:GetFont(), 11, "OUTLINE")
        row.arrowFS = arrowFS

        local nameFS = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        nameFS:SetPoint("LEFT", arrowFS, "RIGHT", 6, 0)
        nameFS:SetFont(nameFS:GetFont(), 11, "OUTLINE")
        nameFS:SetJustifyH("LEFT")
        nameFS:SetWidth(220)
        row.nameFS = nameFS

        local statsFS = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        statsFS:SetPoint("LEFT", nameFS, "RIGHT", 8, 0)
        statsFS:SetFont(statsFS:GetFont(), 10)
        statsFS:SetJustifyH("LEFT")
        row.statsFS = statsFS

        row:SetScript("OnClick", HeaderRow_OnClick)
        return row
    end

    --- Create a reusable per-run detail row.
    local function CreateRunRow()
        local row = CreateFrame("Frame", nil, sc)
        row:SetHeight(RUN_ROW_HEIGHT)
        row:SetPoint("LEFT",  sc, "LEFT",  32, 0)
        row:SetPoint("RIGHT", sc, "RIGHT", -8, 0)

        local textFS = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        textFS:SetPoint("LEFT", row, "LEFT", 0, 0)
        textFS:SetFont(textFS:GetFont(), 10)
        textFS:SetJustifyH("LEFT")
        row.textFS = textFS
        return row
    end

    local function AcquireHeaderRow(i)
        local row = headerRowPool[i]
        if not row then
            row = CreateHeaderRow()
            headerRowPool[i] = row
        end
        row:ClearAllPoints()
        return row
    end

    local function AcquireRunRow(i)
        local row = runRowPool[i]
        if not row then
            row = CreateRunRow()
            runRowPool[i] = row
        end
        row:ClearAllPoints()
        return row
    end

    --------------------------------------------------------------------
    -- Section-ordering scratch buffers (reused every refresh, wiped
    -- instead of reallocated).
    --------------------------------------------------------------------
    local nemesisKeys  = {}
    local midnightKeys = {}

    local function CollectKeys(history)
        for i = #nemesisKeys,  1, -1 do nemesisKeys[i]  = nil end
        for i = #midnightKeys, 1, -1 do midnightKeys[i] = nil end
        if not history then return end
        local nameMap = E.LoggableDelveNames
        for name, entry in pairs(history) do
            if entry and entry.lifetime and (entry.lifetime.totalRuns or 0) > 0 then
                local kind = nameMap and nameMap[name]
                if kind == "nemesis" then
                    table_insert(nemesisKeys, name)
                elseif kind == "regular" then
                    table_insert(midnightKeys, name)
                end
            end
        end
        table_sort(nemesisKeys)
        table_sort(midnightKeys)
    end

    --------------------------------------------------------------------
    -- Refresh (populate everything from E.db.delveHistory)
    --------------------------------------------------------------------
    local LEFT_X = 8
    local INDENT = 0

    function Refresh()
        local history = E.db and E.db.delveHistory or nil
        CollectKeys(history)

        -- Aggregate summary numbers
        local totalRuns, totalDeaths, totalDur = 0, 0, 0
        if history then
            for _, entry in pairs(history) do
                local l = entry and entry.lifetime
                if l then
                    totalRuns   = totalRuns   + (l.totalRuns     or 0)
                    totalDeaths = totalDeaths + (l.totalDeaths   or 0)
                    totalDur    = totalDur    + (l.totalDuration or 0)
                end
            end
        end
        summaryFS:SetFormattedText(
            "%sTotal Runs:%s %s%d%s   %s||%s   %sTotal Deaths:%s %s%d%s   %s||%s   %sTotal Time:%s %s%s%s",
            E.CC.muted, E.CC.close, E.CC.gold, totalRuns, E.CC.close,
            E.CC.muted, E.CC.close,
            E.CC.muted, E.CC.close, E.CC.gold, totalDeaths, E.CC.close,
            E.CC.muted, E.CC.close,
            E.CC.muted, E.CC.close, E.CC.gold, FormatDuration(totalDur), E.CC.close
        )

        -- Hide all pool rows up front; we'll anchor the used ones fresh.
        for _, r in ipairs(headerRowPool) do r:Hide() end
        for _, r in ipairs(runRowPool)    do r:Hide() end

        -- Hide both empty-state messages; they're only re-shown by
        -- PlaceAt() when the matching section is actually empty.
        nemesisEmptyFS:Hide()
        midnightEmptyFS:Hide()

        local hUsed, rUsed = 0, 0
        -- Running Y cursor (positive pixels from top of sc). Every
        -- widget anchors directly to sc "TOPLEFT" with a fixed X and
        -- yCur as its Y offset — no chained sibling anchors, so there
        -- is zero possibility of X-drift between rows.
        local yCur = 4
        local X_PARENT = 0                -- align section headers with "Delve History"
        local X_CHILD  = 16               -- indented child run row X

        local function PlaceAt(widget, x, h)
            widget:ClearAllPoints()
            widget:SetPoint("TOPLEFT", sc, "TOPLEFT", x, -yCur)
            widget:Show()
            yCur = yCur + h
        end

        local function PlaceRow(row, x, h)
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", sc, "TOPLEFT", x, -yCur)
            row:SetPoint("RIGHT",   sc, "RIGHT",  -8, 0)
            row:Show()
            yCur = yCur + h
        end

        ----------------------------------------------------------------
        -- Section: Seasonal Nemesis
        ----------------------------------------------------------------
        PlaceAt(nemesisHeader, X_PARENT, 20)

        if #nemesisKeys == 0 then
            PlaceAt(nemesisEmptyFS, X_PARENT, 16)
        else
            for _, key in ipairs(nemesisKeys) do
                hUsed = hUsed + 1
                local row = AcquireHeaderRow(hUsed)
                row:SetParent(sc)
                row.delveKey = key

                local entry   = history[key]
                local life    = entry.lifetime
                local expanded = expandedByKey[key] and true or false
                local arrow    = expanded and "|cFFFFD700v|r" or "|cFFFFD700>|r"
                row.arrowFS:SetText(arrow)

                -- Nemesis display includes the boss name (Nullaeus).
                local nem = E.NemesisDelve
                local niceName = key
                if nem and nem.boss then
                    niceName = key .. " (" .. nem.boss .. ")"
                end
                row.nameFS:SetText(E.CC.gold .. niceName .. E.CC.close)

                local avg = (life.totalRuns > 0)
                    and math_floor(life.totalDuration / life.totalRuns) or 0
                row.statsFS:SetFormattedText(
                    "%sRuns:%s %d  ||  %sBest Tier:%s T%d  ||  %sAvg:%s %s  ||  %sFastest:%s %s  ||  %sDeaths:%s %d",
                    E.CC.muted, E.CC.close, life.totalRuns,
                    E.CC.muted, E.CC.close, life.highestTier or 0,
                    E.CC.muted, E.CC.close, FormatDuration(avg),
                    E.CC.muted, E.CC.close, FormatDuration(life.fastestTime),
                    E.CC.muted, E.CC.close, life.totalDeaths or 0
                )

                PlaceRow(row, X_PARENT, HEADER_ROW_HEIGHT + 2)

                if expanded then
                    local recent = entry.recentRuns
                    if recent then
                        for _, run in ipairs(recent) do
                            rUsed = rUsed + 1
                            local rrow = AcquireRunRow(rUsed)
                            rrow:SetParent(sc)
                            local keyIcon = run.keyUsed
                                and (E.CC.gold .. "Key" .. E.CC.close)
                                or  (E.CC.muted .. "   " .. E.CC.close)
                            rrow.textFS:SetFormattedText(
                                "%sT%-2d%s  ||  %s%-8s%s  ||  %sDeaths: %d%s  ||  %s  ||  %s%s%s",
                                E:GetTierCC(run.tier or 0), run.tier or 0, E.CC.close,
                                E.CC.body, FormatDuration(run.duration), E.CC.close,
                                E.CC.body, run.deaths or 0, E.CC.close,
                                keyIcon,
                                E.CC.muted, FormatDate(run.timestamp), E.CC.close
                            )
                            PlaceRow(rrow, X_CHILD, RUN_ROW_HEIGHT + 1)
                        end
                    end
                end
            end
        end

        ----------------------------------------------------------------
        -- Spacer + accent divider + Section: Midnight Delves
        ----------------------------------------------------------------
        yCur = yCur + 12  -- breathing room above the divider

        -- Place + show the accent-colour separator across the FULL UI
        -- width. Parented to `frame`, vertical anchored to sc so it
        -- scrolls with content; horizontal anchored to frame edges so
        -- it matches the divider directly below the tab row.
        nemesisDivider:ClearAllPoints()
        nemesisDivider:SetPoint("LEFT",  frame,       "LEFT",   8, 0)
        nemesisDivider:SetPoint("RIGHT", frame,       "RIGHT", -8, 0)
        nemesisDivider:SetPoint("TOP",   scrollFrame, "TOP",    0, -yCur)
        nemesisDivider:SetHeight(1)
        nemesisDivider:Show()
        yCur = yCur + 14  -- breathing room below the divider

        PlaceAt(midnightHeader, X_PARENT, 24)

        -- Third full-width accent divider, directly below the Midnight
        -- Delves header.
        midnightDivider:ClearAllPoints()
        midnightDivider:SetPoint("LEFT",  frame,       "LEFT",   8, 0)
        midnightDivider:SetPoint("RIGHT", frame,       "RIGHT", -8, 0)
        midnightDivider:SetPoint("TOP",   scrollFrame, "TOP",    0, -yCur + 4)
        midnightDivider:SetHeight(1)
        midnightDivider:Show()
        yCur = yCur + 8  -- breathing room below the third divider

        if #midnightKeys == 0 then
            PlaceAt(midnightEmptyFS, X_PARENT, 16)
        else
            for _, key in ipairs(midnightKeys) do
                hUsed = hUsed + 1
                local row = AcquireHeaderRow(hUsed)
                row:SetParent(sc)
                row.delveKey = key

                local entry   = history[key]
                local life    = entry.lifetime
                local expanded = expandedByKey[key] and true or false
                local arrow    = expanded and "|cFFFF4444v|r" or "|cFFFF4444>|r"
                row.arrowFS:SetText(arrow)
                row.nameFS:SetText(E.CC.white .. key .. E.CC.close)

                local avg = (life.totalRuns > 0)
                    and math_floor(life.totalDuration / life.totalRuns) or 0
                row.statsFS:SetFormattedText(
                    "%sRuns:%s %d  ||  %sBest Tier:%s T%d  ||  %sAvg:%s %s  ||  %sFastest:%s %s  ||  %sDeaths:%s %d",
                    E.CC.muted, E.CC.close, life.totalRuns,
                    E.CC.muted, E.CC.close, life.highestTier or 0,
                    E.CC.muted, E.CC.close, FormatDuration(avg),
                    E.CC.muted, E.CC.close, FormatDuration(life.fastestTime),
                    E.CC.muted, E.CC.close, life.totalDeaths or 0
                )

                PlaceRow(row, X_PARENT, HEADER_ROW_HEIGHT + 2)

                if expanded then
                    local recent = entry.recentRuns
                    if recent then
                        for _, run in ipairs(recent) do
                            rUsed = rUsed + 1
                            local rrow = AcquireRunRow(rUsed)
                            rrow:SetParent(sc)
                            local keyIcon = run.keyUsed
                                and (E.CC.gold .. "Key" .. E.CC.close)
                                or  (E.CC.muted .. "   " .. E.CC.close)
                            rrow.textFS:SetFormattedText(
                                "%sT%-2d%s  ||  %s%-8s%s  ||  %sDeaths: %d%s  ||  %s  ||  %s%s%s",
                                E:GetTierCC(run.tier or 0), run.tier or 0, E.CC.close,
                                E.CC.body, FormatDuration(run.duration), E.CC.close,
                                E.CC.body, run.deaths or 0, E.CC.close,
                                keyIcon,
                                E.CC.muted, FormatDate(run.timestamp), E.CC.close
                            )
                            PlaceRow(rrow, X_CHILD, RUN_ROW_HEIGHT + 1)
                        end
                    end
                end
            end
        end

        sc:SetHeight(yCur + 20)
        UpdateScrollRange()
    end

    --------------------------------------------------------------------
    -- External hook: called by the delve logger when a run is recorded
    -- or when the player wipes history from the Options tab.
    --------------------------------------------------------------------
    function E:RefreshDelveHistoryTab()
        if frame:IsShown() then
            Refresh()
        end
    end

    frame:SetScript("OnShow", function()
        Refresh()
        scrollFrame:SetVerticalScroll(0)
        tabScrollBar:SetValue(0)
    end)

    --------------------------------------------------------------------
    -- Register with the main frame tab system
    --------------------------------------------------------------------
    E:RegisterTab(5, frame)
end)
