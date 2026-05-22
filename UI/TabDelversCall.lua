------------------------------------------------------------------------
-- UI/TabDelversCall.lua - Tab 7: Delver's Call
-- Weekly "World Tour" quest tracker. One rotational Delver's Call quest
-- per delve, auto-detected from the quest log (Available -> In Progress
-- -> Banked -> Turned In), plus a cross-character alt rollup.
--
-- "Banked" (objectives done, not yet turned in) is the leveling sweet
-- spot: turn-in XP scales to your level, so holding all 10 until you're
-- a few levels short of cap turns them into a burst to the finish.
------------------------------------------------------------------------
local E = EverythingDelves

local math_max, math_min = math.max, math.min

------------------------------------------------------------------------
-- State model (in alt-leveling progression order)
------------------------------------------------------------------------
local ORANGE = "|cFFFF8800"
local DC_STATE = {
    fresh      = { text = "Available",   cc = E.CC.muted },
    inProgress = { text = "In Progress", cc = ORANGE      },
    ready      = { text = "Banked",      cc = E.CC.gold   },
    completed  = { text = "Turned In",   cc = E.CC.green  },
}

--- Resolve the live quest state for a Delver's Call questID on the
--- CURRENT character. Other characters are read from the saved roster.
--- Returns one of: "fresh" | "inProgress" | "ready" | "completed".
local function GetState(questID)
    if not questID or not C_QuestLog then return "fresh" end
    if C_QuestLog.IsQuestFlaggedCompleted
            and C_QuestLog.IsQuestFlaggedCompleted(questID) then
        return "completed"
    end
    local logIdx = C_QuestLog.GetLogIndexForQuestID
        and C_QuestLog.GetLogIndexForQuestID(questID)
    if logIdx then
        -- In the log. Distinguish "ready to hand in" (banked) from "still
        -- working objectives". pcall both APIs — their signatures have
        -- shifted across patches.
        local objectivesDone = false
        if C_QuestLog.ReadyForTurnIn then
            local ok, ready = pcall(C_QuestLog.ReadyForTurnIn, questID)
            if ok and ready then objectivesDone = true end
        end
        if not objectivesDone and C_QuestLog.IsComplete then
            local ok, done = pcall(C_QuestLog.IsComplete, questID)
            if ok and done then objectivesDone = true end
        end
        return objectivesDone and "ready" or "inProgress"
    end
    return "fresh"
end

------------------------------------------------------------------------
-- MODULE INIT
------------------------------------------------------------------------
E:RegisterModule(function()
    local frame = CreateFrame("Frame", "EverythingDelvesTabDelversCallContent")

    --------------------------------------------------------------------
    -- SCROLLABLE AREA
    --------------------------------------------------------------------
    local scrollFrame = CreateFrame("ScrollFrame", nil, frame)
    scrollFrame:SetPoint("TOPLEFT",     frame, "TOPLEFT",     0,   0)
    scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -18, 0)
    scrollFrame:EnableMouseWheel(true)

    local sc = CreateFrame("Frame")
    sc:SetSize(1, 1)
    scrollFrame:SetScrollChild(sc)

    scrollFrame:SetScript("OnSizeChanged", function(self, w)
        sc:SetWidth(w)
    end)
    sc:SetHeight(900)

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

    local GRID_X = 8

    -- Column offsets (relative to each row's left edge).
    local COL_NAME   = 12
    local COL_ZONE   = 230
    local COL_STATUS = 400
    local ROW_HEIGHT = 22

    -- delve name -> zone, pulled from the shared directory for context.
    local delveZone = {}
    if E.DelveData then
        for _, d in ipairs(E.DelveData) do
            if d.name and d.zone and not delveZone[d.name] then
                delveZone[d.name] = d.zone
            end
        end
    end

    --------------------------------------------------------------------
    -- HEADER + STRATEGY
    --------------------------------------------------------------------
    local mainHeader = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    mainHeader:SetPoint("TOPLEFT", sc, "TOPLEFT", GRID_X, -4)
    mainHeader:SetFont(mainHeader:GetFont(), E.HEADER_FONT_SIZE, "OUTLINE")
    E:StyleAccentHeader(mainHeader, "Delver's Call")

    local subFS = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    subFS:SetPoint("LEFT", mainHeader, "RIGHT", 10, -1)
    subFS:SetFont(subFS:GetFont(), 11)
    subFS:SetText(E.CC.muted .. "World Tour weekly quest tracker" .. E.CC.close)

    local strategyFS = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    strategyFS:SetPoint("TOPLEFT", mainHeader, "BOTTOMLEFT", 0, -8)
    strategyFS:SetPoint("RIGHT", sc, "RIGHT", -20, 0)
    strategyFS:SetFont(strategyFS:GetFont(), 11)
    strategyFS:SetJustifyH("LEFT")
    strategyFS:SetText(
        E.CC.body .. "Each rotational delve has a Delver's Call quest. Run every"
        .. " delve once to pick the quest up, but " .. E.CC.close
        .. E.CC.gold .. "don't turn it in yet" .. E.CC.close
        .. E.CC.body .. " \226\128\148 the XP scales to your level at turn-in."
        .. " Bank all " .. (#E.DelversCall) .. ", then cash them in once you're"
        .. " a few levels short of cap for a push through the final levels."
        .. E.CC.close
    )

    local summaryFS = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    summaryFS:SetPoint("TOPLEFT", strategyFS, "BOTTOMLEFT", 0, -10)
    summaryFS:SetFont(summaryFS:GetFont(), 11)

    local div1 = sc:CreateTexture(nil, "ARTWORK")
    div1:SetHeight(1)
    div1:SetPoint("TOPLEFT", summaryFS, "BOTTOMLEFT", 0, -10)
    div1:SetPoint("RIGHT", sc, "RIGHT", -8, 0)
    E:StyleAccentDivider(div1)

    --------------------------------------------------------------------
    -- COLUMN HEADERS
    --------------------------------------------------------------------
    local colHead = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    colHead:SetPoint("TOPLEFT", div1, "BOTTOMLEFT", COL_NAME, -8)
    colHead:SetFont(colHead:GetFont(), 10)
    colHead:SetText(E.CC.muted .. "Delve" .. E.CC.close)

    local colHeadZone = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    colHeadZone:SetPoint("TOPLEFT", colHead, "TOPLEFT", COL_ZONE - COL_NAME, 0)
    colHeadZone:SetFont(colHeadZone:GetFont(), 10)
    colHeadZone:SetText(E.CC.muted .. "Zone" .. E.CC.close)

    local colHeadStatus = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    colHeadStatus:SetPoint("TOPLEFT", colHead, "TOPLEFT", COL_STATUS - COL_NAME, 0)
    colHeadStatus:SetFont(colHeadStatus:GetFont(), 10)
    colHeadStatus:SetText(E.CC.muted .. "Status" .. E.CC.close)

    --------------------------------------------------------------------
    -- PER-DELVE ROWS (one per E.DelversCall entry, built once)
    --------------------------------------------------------------------
    local rowWidgets = {}
    local rowAnchor  = colHead
    for i, entry in ipairs(E.DelversCall) do
        local row = CreateFrame("Frame", nil, sc)
        row:SetHeight(ROW_HEIGHT)
        -- First row hangs off the column header (which sits +COL_NAME in),
        -- so pull back -COL_NAME to land on the divider's left margin;
        -- later rows chain straight down at x=0 (no staircase).
        row:SetPoint("TOPLEFT",  rowAnchor, "BOTTOMLEFT", (i == 1) and -COL_NAME or 0, (i == 1) and -4 or -2)
        row:SetPoint("RIGHT", sc, "RIGHT", -20, 0)

        -- Left accent bar, shown only for "Banked" rows (the do-this-next state).
        local bar = row:CreateTexture(nil, "ARTWORK")
        bar:SetPoint("LEFT", row, "LEFT", 0, 0)
        bar:SetSize(3, ROW_HEIGHT - 4)
        bar:SetColorTexture(1, 0.82, 0, 1)
        bar:Hide()

        local nameFS = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        nameFS:SetPoint("LEFT", row, "LEFT", COL_NAME, 0)
        nameFS:SetWidth(COL_ZONE - COL_NAME - 6)
        nameFS:SetJustifyH("LEFT")
        nameFS:SetFont(nameFS:GetFont(), 11)
        nameFS:SetText(E.CC.body .. entry.delve .. E.CC.close)

        local zoneFS = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        zoneFS:SetPoint("LEFT", row, "LEFT", COL_ZONE, 0)
        zoneFS:SetWidth(COL_STATUS - COL_ZONE - 6)
        zoneFS:SetJustifyH("LEFT")
        zoneFS:SetFont(zoneFS:GetFont(), 11)
        zoneFS:SetText(E.CC.muted .. (delveZone[entry.delve] or "") .. E.CC.close)

        local statusFS = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        statusFS:SetPoint("LEFT", row, "LEFT", COL_STATUS, 0)
        statusFS:SetJustifyH("LEFT")
        statusFS:SetFont(statusFS:GetFont(), 11)

        rowWidgets[i] = { row = row, status = statusFS, bar = bar }
        rowAnchor = row
    end

    local div2 = sc:CreateTexture(nil, "ARTWORK")
    div2:SetHeight(1)
    div2:SetPoint("TOPLEFT", rowAnchor, "BOTTOMLEFT", 0, -10)
    div2:SetPoint("RIGHT", sc, "RIGHT", -8, 0)
    E:StyleAccentDivider(div2)

    --------------------------------------------------------------------
    -- ALT ROLLUP
    --------------------------------------------------------------------
    local rollupHeader = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    rollupHeader:SetPoint("TOPLEFT", div2, "BOTTOMLEFT", GRID_X, -16)
    rollupHeader:SetFont(rollupHeader:GetFont(), E.HEADER_FONT_SIZE, "OUTLINE")
    E:StyleAccentHeader(rollupHeader, "Alt Rollup")

    -- Pooled rollup lines (one per tracked character; count varies).
    local rollupPool = {}
    local function GetRollupLine(i)
        local fs = rollupPool[i]
        if not fs then
            fs = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            fs:SetFont(fs:GetFont(), 11)
            fs:SetJustifyH("LEFT")
            rollupPool[i] = fs
        end
        return fs
    end

    -- Bottom-most visible element, used to size the scroll child.
    local rollupBottom = rollupHeader

    --------------------------------------------------------------------
    -- REFRESH
    --------------------------------------------------------------------
    --- Compute live state for every delve on the current character.
    local function ComputeStates()
        local states = {}
        local counts = { fresh = 0, inProgress = 0, ready = 0, completed = 0 }
        for _, entry in ipairs(E.DelversCall) do
            local st = GetState(entry.questID)
            states[entry.delve] = st
            counts[st] = (counts[st] or 0) + 1
        end
        return states, counts
    end

    --- Snapshot the current character's states into the account-wide
    --- roster so the rollup can show this character alongside alts (whose
    --- quest logs we can't read directly).
    local function PersistRoster(states)
        local sv = EverythingDelvesDB
        if not sv then return end
        sv.delversCallRoster = sv.delversCallRoster or {}
        local key = E.CharKey()
        local rec = sv.delversCallRoster[key] or {}
        rec.name    = UnitName("player")  or rec.name
        rec.realm   = GetRealmName()      or rec.realm
        rec.class   = select(2, UnitClass("player")) or rec.class
        rec.states  = states
        rec.updated = time()
        sv.delversCallRoster[key] = rec
    end

    local function RefreshRollup()
        local sv = EverythingDelvesDB
        local roster = (sv and sv.delversCallRoster) or {}
        local total  = #E.DelversCall
        local curKey = E.CharKey()

        local keys = {}
        for k in pairs(roster) do keys[#keys + 1] = k end
        table.sort(keys)

        local last = rollupHeader
        local idx  = 0
        for _, k in ipairs(keys) do
            idx = idx + 1
            local rec = roster[k]
            local inProg, ready, done = 0, 0, 0
            if rec.states then
                for _, st in pairs(rec.states) do
                    if     st == "inProgress" then inProg = inProg + 1
                    elseif st == "ready"      then ready  = ready  + 1
                    elseif st == "completed"  then done   = done   + 1 end
                end
            end
            local remaining = math_max(0, total - inProg - ready - done)
            local isCur   = (k == curKey)
            local nameCC  = isCur and E.CC.white or E.CC.body
            local youTag  = isCur and (E.CC.muted .. "  (you)" .. E.CC.close) or ""

            local line = GetRollupLine(idx)
            line:ClearAllPoints()
            line:SetPoint("TOPLEFT", last, "BOTTOMLEFT", (idx == 1) and 4 or 0, (idx == 1) and -8 or -4)
            line:SetText(string.format(
                "%s%s|r %s(%s)|r%s  \226\128\148  %s%d|r in progress  %s%d|r banked  %s%d|r done  %s%d|r left",
                nameCC, rec.name or k,
                E.CC.muted, rec.realm or "?", youTag,
                ORANGE, inProg,
                E.CC.gold, ready,
                E.CC.green, done,
                E.CC.muted, remaining
            ))
            line:Show()
            last = line
        end

        -- Hide any pooled lines left over from a larger previous roster.
        for j = idx + 1, #rollupPool do
            rollupPool[j]:Hide()
        end

        if idx == 0 then
            local line = GetRollupLine(1)
            line:ClearAllPoints()
            line:SetPoint("TOPLEFT", rollupHeader, "BOTTOMLEFT", 4, -8)
            line:SetText(E.CC.muted .. "No characters tracked yet." .. E.CC.close)
            line:Show()
            last = line
        end

        rollupBottom = last
    end

    local function UpdateContentHeight()
        local scTop   = sc:GetTop()
        local lastBot = rollupBottom and rollupBottom:GetBottom()
        if scTop and lastBot and scTop > lastBot then
            sc:SetHeight((scTop - lastBot) + 24)
        end
        UpdateScrollRange()
    end

    local function RefreshAll()
        local states, counts = ComputeStates()

        for i, entry in ipairs(E.DelversCall) do
            local st  = states[entry.delve] or "fresh"
            local def = DC_STATE[st] or DC_STATE.fresh
            local w   = rowWidgets[i]
            w.status:SetText(def.cc .. def.text .. E.CC.close)
            w.bar:SetShown(st == "ready")
        end

        summaryFS:SetText(string.format(
            "%sThis character:|r  %s%d|r available   %s%d|r in progress   %s%d|r banked   %s%d|r turned in   %s(of %d)|r",
            E.CC.body,
            E.CC.muted, counts.fresh,
            ORANGE, counts.inProgress,
            E.CC.gold, counts.ready,
            E.CC.green, counts.completed,
            E.CC.muted, #E.DelversCall
        ))

        PersistRoster(states)
        RefreshRollup()
        C_Timer.After(0, UpdateContentHeight)
    end

    --------------------------------------------------------------------
    -- EVENTS
    --------------------------------------------------------------------
    frame:SetScript("OnShow", function()
        RefreshAll()
        UpdateScrollRange()
        scrollFrame:SetVerticalScroll(0)
        tabScrollBar:SetValue(0)
    end)

    -- Keep the roster fresh even when the tab is closed, so the rollup is
    -- accurate the moment it's opened. Only repaint the UI when visible.
    E:RegisterCallback("QuestLogUpdate", function()
        if frame:IsShown() then
            RefreshAll()
        else
            PersistRoster((ComputeStates()))
        end
    end)

    -- Seed the roster shortly after login (quest data may not be ready at
    -- module-init time) so this character appears in the rollup before the
    -- first quest-log event or tab open.
    C_Timer.After(2, function()
        PersistRoster((ComputeStates()))
    end)

    --------------------------------------------------------------------
    -- Register with the main frame tab system
    --------------------------------------------------------------------
    E:RegisterTab(7, frame)
end)
