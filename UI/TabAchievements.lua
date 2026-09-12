local E = EverythingDelves
local L = E.L

local math_max, math_min = math.max, math.min

local ROW_HEIGHT = 26
local LINE_HEIGHT = 16

local COL_NAME    = 4
local COL_ZONE    = 240
local COL_STORIES = 386
local COL_CHESTS  = 452
local COL_DEPTHS  = 518
local COL_BEST    = 584
local COL_TODAY   = 656

local ICON_DONE  = "|TInterface\\RaidFrame\\ReadyCheck-Ready:12:12:0:0|t"
local ICON_TODO  = "|TInterface\\RaidFrame\\ReadyCheck-NotReady:12:12:0:0|t"
local ICON_TODAY = "|TInterface\\Common\\FavoritesIcon:14:14|t"

local expandedDelve = {}

local function Fraction(done, total)
    if not total or total == 0 then
        return E.CC.muted .. "--" .. E.CC.close
    end
    local cc = (done >= total) and E.CC.green or E.CC.red
    return cc .. done .. "/" .. total .. E.CC.close
end

local function CountDone(criteria)
    local n = 0
    for _, c in ipairs(criteria or {}) do
        if c.completed then n = n + 1 end
    end
    return n
end

E:RegisterModule(function()
    local frame = CreateFrame("Frame", "EverythingDelvesTabAchievementsContent")

    local Refresh

    local scrollFrame = CreateFrame("ScrollFrame", nil, frame)
    scrollFrame:SetPoint("TOPLEFT",     frame, "TOPLEFT",     0, 0)
    scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -18, 0)
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
        scrollBar:SetShown(maxScroll > 0)
    end

    local linePool, dividerPool, rowPool = {}, {}, {}

    local function AcquireLine(i)
        local fs = linePool[i]
        if not fs then
            fs = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            fs:SetFont(fs:GetFont(), 11)
            fs:SetJustifyH("LEFT")
            linePool[i] = fs
        end
        fs:ClearAllPoints()
        fs:SetWordWrap(false)
        return fs
    end

    local function AcquireDivider(i)
        local tex = dividerPool[i]
        if not tex then
            tex = sc:CreateTexture(nil, "ARTWORK")
            tex:SetHeight(1)
            E:StyleAccentDivider(tex)
            dividerPool[i] = tex
        end
        tex:ClearAllPoints()
        return tex
    end

    local function Row_Toggle(self)
        if not self.delveName then return end
        expandedDelve[self.delveName] = not expandedDelve[self.delveName]
        if Refresh then Refresh() end
    end

    local function CreateRow()
        local row = CreateFrame("Button", nil, sc, "BackdropTemplate")
        row:SetHeight(ROW_HEIGHT)
        row:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
        row:RegisterForClicks("LeftButtonUp")
        row:SetScript("OnClick", Row_Toggle)

        local function Col(x, width, justify)
            local fs = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            fs:SetPoint("LEFT", row, "LEFT", x, 0)
            fs:SetFont(fs:GetFont(), 11)
            fs:SetWidth(width)
            fs:SetJustifyH(justify or "LEFT")
            fs:SetWordWrap(false)
            return fs
        end

        row.nameFS    = Col(COL_NAME,    COL_ZONE - COL_NAME - 6)
        row.zoneFS    = Col(COL_ZONE,    COL_STORIES - COL_ZONE - 6)
        row.storiesFS = Col(COL_STORIES, 60, "CENTER")
        row.chestsFS  = Col(COL_CHESTS,  60, "CENTER")
        row.depthsFS  = Col(COL_DEPTHS,  60, "CENTER")
        row.bestFS    = Col(COL_BEST,    60, "CENTER")

        local todayFS = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        todayFS:SetPoint("LEFT",  row, "LEFT",  COL_TODAY, 0)
        todayFS:SetPoint("RIGHT", row, "RIGHT", -8, 0)
        todayFS:SetFont(todayFS:GetFont(), 11)
        todayFS:SetJustifyH("LEFT")
        todayFS:SetWordWrap(false)
        row.todayFS = todayFS

        row:SetScript("OnEnter", function(self)
            if not self.delveName then return end
            E:ShowTooltip(self, self.delveName,
                E.CC.muted .. (expandedDelve[self.delveName]
                    and L["Click to hide what's left here."]
                    or  L["Click to see what's left here."]) .. E.CC.close)
        end)
        row:SetScript("OnLeave", function() E:HideTooltip() end)

        return row
    end

    local function AcquireRow(i)
        local row = rowPool[i]
        if not row then
            row = CreateRow()
            rowPool[i] = row
        end
        row:ClearAllPoints()
        return row
    end

    local mainHeader = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    mainHeader:SetPoint("TOPLEFT", sc, "TOPLEFT", 8, -4)
    mainHeader:SetFont(mainHeader:GetFont(), E.HEADER_FONT_SIZE, "OUTLINE")
    E:StyleAccentHeader(mainHeader, L["Delve Achievements"])

    local subFS = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    subFS:SetPoint("LEFT", mainHeader, "RIGHT", 10, -1)
    subFS:SetFont(subFS:GetFont(), 11)
    subFS:SetText(E.CC.muted
        .. L["Story variants, Sturdy Chests and tier goals for every delve"]
        .. E.CC.close)

    local hideCheck = CreateFrame("CheckButton", nil, sc, "UICheckButtonTemplate")
    hideCheck:SetSize(22, 22)
    local hideLabel = hideCheck:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    hideLabel:SetPoint("LEFT", hideCheck, "RIGHT", 2, 0)
    hideLabel:SetFont(hideLabel:GetFont(), 11)
    hideLabel:SetText(E.CC.body .. L["Hide finished delves"] .. E.CC.close)
    hideCheck:SetScript("OnClick", function(self)
        if E.db then
            E.db.achHideCompleted = self:GetChecked() and true or false
        end
        if Refresh then Refresh() end
    end)

    function Refresh()
        for _, fs  in ipairs(linePool)    do fs:Hide()  end
        for _, tex in ipairs(dividerPool) do tex:Hide() end
        for _, row in ipairs(rowPool)     do row:Hide() end

        local lUsed, dUsed, rUsed = 0, 0, 0
        local yCur = 34

        local function Place(widget, x, h)
            widget:ClearAllPoints()
            widget:SetPoint("TOPLEFT", sc, "TOPLEFT", x, -yCur)
            widget:Show()
            yCur = yCur + h
        end

        -- Rows stretch to the right edge, so they need the second anchor set
        -- after Place's ClearAllPoints, not before it.
        local function PlaceRow(row, h)
            Place(row, 0, h)
            row:SetPoint("RIGHT", sc, "RIGHT", -2, 0)
        end

        local function AddLine(text, x, h)
            lUsed = lUsed + 1
            local fs = AcquireLine(lUsed)
            fs:SetText(text)
            Place(fs, x or 8, h or LINE_HEIGHT)
            return fs
        end

        local function AddDivider(gapBefore, gapAfter)
            yCur = yCur + (gapBefore or 8)
            dUsed = dUsed + 1
            local tex = AcquireDivider(dUsed)
            tex:SetPoint("TOPLEFT",  sc, "TOPLEFT",  8, -yCur)
            tex:SetPoint("TOPRIGHT", sc, "TOPRIGHT", -8, -yCur)
            tex:Show()
            yCur = yCur + 1 + (gapAfter or 8)
        end

        AddLine(E.CC.muted
            .. L["Achievements are account-wide and cover all of Midnight, not only this season."]
            .. E.CC.close, 8, 18)
        AddLine(E.CC.muted
            .. L["Your Best is the highest tier Everything Delves has logged you clearing, so it only counts runs since you installed it."]
            .. E.CC.close, 8, 20)

        local statusByDelve = {}
        for _, d in ipairs(E.DelveData or {}) do
            statusByDelve[d.name] = E:GetDelveAchievementStatus(d.name)
        end

        local glory = E.GetGloryStatus and E:GetGloryStatus()
        if glory then
            local state
            if glory.done then
                state = E.CC.green .. L["Complete"] .. E.CC.close
            elseif glory.remaining > 0 then
                state = E.CC.red .. L["%d of %d still to earn"]
                    :format(glory.remaining, #glory.pillars) .. E.CC.close
            else
                state = E.CC.red .. L["Incomplete"] .. E.CC.close
            end
            AddLine(E.CC.gold .. tostring(glory.name or "") .. E.CC.close
                .. "   " .. state, 8, 20)
            if glory.reward then
                AddLine(E.CC.muted .. glory.reward .. E.CC.close, 8, 18)
            end
            for _, p in ipairs(glory.pillars) do
                local icon = p.done and ICON_DONE or ICON_TODO
                local cc   = p.done and E.CC.green or E.CC.body
                local tail = ""
                if not p.done and p.left and p.left > 0 then
                    tail = E.CC.muted .. "   " .. L["%d left"]:format(p.left)
                        .. E.CC.close
                end
                AddLine("   " .. icon .. " " .. cc .. p.name .. E.CC.close .. tail, 8)
            end
        else
            AddLine(E.CC.muted .. L["Achievement data unavailable"] .. E.CC.close,
                8, 20)
        end

        AddDivider()

        local credits, variantByDelve = {}, {}
        if E.GetTodaysStoryCredits then
            credits, variantByDelve = E:GetTodaysStoryCredits(statusByDelve)
        end
        if #credits > 0 then
            AddLine(E.CC.gold
                .. L["%d of today's story variants are ones you still need"]
                    :format(#credits)
                .. E.CC.close, 8, 20)
            for _, c in ipairs(credits) do
                AddLine("   " .. E.CC.green .. c.delve .. E.CC.close
                    .. E.CC.muted .. "  \226\128\148  " .. E.CC.close
                    .. E.CC.body .. c.variant .. E.CC.close, 8)
            end
        else
            AddLine(E.CC.muted
                .. L["None of today's story variants are new to you."]
                .. E.CC.close, 8, 20)
        end

        AddDivider()

        local storiesLeft, chestsLeft, depthsLeft = 0, 0, 0
        for _, st in pairs(statusByDelve) do
            if st then
                if st.stories then
                    -- Unnamed criteria are skipped by the expanded list, so
                    -- counting them here would claim more than it can show.
                    for _, c in ipairs(st.stories.criteria) do
                        if not c.completed and c.name ~= "" then
                            storiesLeft = storiesLeft + 1
                        end
                    end
                end
                if st.discoveries and st.discoveries.total > 0 then
                    chestsLeft = chestsLeft
                        + math_max(0, st.discoveries.total - st.discoveries.found)
                end
                depthsLeft = depthsLeft + #(st.depthsMissing or {})
            end
        end

        AddLine(E.CC.body .. L["Still to earn: %s%d|r story variants, %s%d|r Sturdy Chests, %s%d|r tier goals"]
            :format(E.CC.gold, storiesLeft,
                    E.CC.gold, chestsLeft,
                    E.CC.gold, depthsLeft) .. E.CC.close,
            8, 22)

        hideCheck:ClearAllPoints()
        hideCheck:SetPoint("TOPLEFT", sc, "TOPLEFT", 6, -yCur)
        hideCheck:SetChecked(E.db and E.db.achHideCompleted == true)
        hideCheck:Show()
        yCur = yCur + 26

        AddLine(E.CC.muted .. L["Delve"] .. E.CC.close, COL_NAME + 4, 0)
        AddLine(E.CC.muted .. L["Zone"] .. E.CC.close, COL_ZONE, 0)
        AddLine(E.CC.muted .. L["Stories"] .. E.CC.close, COL_STORIES, 0)
        AddLine(E.CC.muted .. L["Chests"] .. E.CC.close, COL_CHESTS, 0)
        AddLine(E.CC.muted .. L["Depths"] .. E.CC.close, COL_DEPTHS, 0)
        AddLine(E.CC.muted .. L["Your Best"] .. E.CC.close, COL_BEST, 0)
        AddLine(E.CC.muted .. L["Today's Story"] .. E.CC.close, COL_TODAY, 18)

        local creditByDelve = {}
        for _, c in ipairs(credits) do creditByDelve[c.delve] = c.variant end

        local hideDone = E.db and E.db.achHideCompleted
        local shown = 0

        for _, delve in ipairs(E.DelveData or {}) do
            local st = statusByDelve[delve.name]
            local finished = st and st.allDone
            if not (hideDone and finished) then
                shown = shown + 1
                rUsed = rUsed + 1
                local row = AcquireRow(rUsed)
                row:SetParent(sc)
                row.delveName = delve.name

                if rUsed % 2 == 0 then
                    row:SetBackdropColor(0.08, 0.08, 0.08, 0.50)
                else
                    row:SetBackdropColor(0.05, 0.05, 0.05, 0.20)
                end

                local caret = E.CC.gold
                    .. (expandedDelve[delve.name] and "v" or ">") .. E.CC.close
                local nameCC = finished and E.CC.green or E.CC.body
                row.nameFS:SetText(caret .. " " .. nameCC .. delve.name .. E.CC.close)
                row.zoneFS:SetText(E.CC.muted .. delve.zone .. E.CC.close)

                if st then
                    local s = st.stories
                    if s then
                        row.storiesFS:SetText(
                            Fraction(CountDone(s.criteria), #s.criteria))
                    else
                        row.storiesFS:SetText(E.CC.muted .. "--" .. E.CC.close)
                    end

                    local d = st.discoveries
                    if d and d.total > 0 then
                        row.chestsFS:SetText(Fraction(d.found, d.total))
                    else
                        row.chestsFS:SetText(E.CC.muted .. "--" .. E.CC.close)
                    end

                    if st.depthsUnknown then
                        row.depthsFS:SetText(E.CC.yellow .. "?" .. E.CC.close)
                    elseif st.depths and #st.depths > 0 then
                        local tDone = #st.depths - #st.depthsMissing
                        row.depthsFS:SetText(Fraction(tDone, #st.depths))
                    else
                        row.depthsFS:SetText(E.CC.muted .. "--" .. E.CC.close)
                    end
                else
                    row.storiesFS:SetText(E.CC.muted .. "--" .. E.CC.close)
                    row.chestsFS:SetText(E.CC.muted .. "--" .. E.CC.close)
                    row.depthsFS:SetText(E.CC.muted .. "--" .. E.CC.close)
                end

                local hist = E.GetDelveHistory and E:GetDelveHistory(delve.name)
                local best = hist and hist.lifetime and hist.lifetime.highestTier
                if best and best > 0 then
                    row.bestFS:SetText(E.CC.body .. "T" .. best .. E.CC.close)
                else
                    row.bestFS:SetText(E.CC.muted .. "--" .. E.CC.close)
                end

                local todayVariant = variantByDelve[delve.name]
                if creditByDelve[delve.name] then
                    row.todayFS:SetText(ICON_TODAY .. " " .. E.CC.green
                        .. creditByDelve[delve.name] .. E.CC.close)
                elseif todayVariant and todayVariant ~= "" then
                    row.todayFS:SetText(E.CC.muted .. todayVariant .. E.CC.close)
                else
                    row.todayFS:SetText(E.CC.muted .. "--" .. E.CC.close)
                end

                PlaceRow(row, ROW_HEIGHT)

                if expandedDelve[delve.name] and st then
                    local s = st.stories
                    if s and #s.criteria > 0 then
                        AddLine(E.CC.gold .. L["Stories"] .. E.CC.close
                            .. "   " .. Fraction(CountDone(s.criteria), #s.criteria),
                            28, 18)
                        for _, c in ipairs(s.criteria) do
                            if c.name ~= "" then
                                local icon = c.completed and ICON_DONE or ICON_TODO
                                local cc = c.completed and E.CC.green or E.CC.body
                                AddLine(icon .. " " .. cc .. c.name .. E.CC.close, 44)
                            end
                        end
                    end

                    local d = st.discoveries
                    if d and d.total > 0 then
                        AddLine(E.CC.gold .. L["Sturdy Chests"] .. E.CC.close
                            .. "   " .. Fraction(d.found, d.total), 28, 18)
                    end

                    if st.depths and #st.depths > 0 then
                        local tDone = #st.depths - #st.depthsMissing
                        AddLine(E.CC.gold .. L["Delver of the Depths"] .. E.CC.close
                            .. "   " .. Fraction(tDone, #st.depths), 28, 18)
                        for _, t in ipairs(st.depths) do
                            local icon = t.completed and ICON_DONE or ICON_TODO
                            local cc = t.completed and E.CC.green or E.CC.body
                            -- An earned series credits every delve, so show the
                            -- earned date rather than implying this delve was
                            -- cleared at that tier.
                            local tail = ""
                            if t.seriesEarned then
                                tail = E.CC.muted .. "   "
                                    .. (t.earnedText
                                        and L["achievement earned %s"]:format(t.earnedText)
                                        or L["earned account-wide"])
                                    .. E.CC.close
                            end
                            AddLine(icon .. " " .. cc .. t.label .. E.CC.close
                                .. tail, 44)
                        end
                    end

                    if st.depthsUnknown then
                        AddLine(E.CC.yellow
                            .. L["Tier progress for this delve could not be read."]
                            .. E.CC.close, 28, 18)
                    end

                    yCur = yCur + 4
                end
            end
        end

        if shown == 0 then
            AddLine(E.CC.green .. L["Every delve is finished. Nothing left to earn."]
                .. E.CC.close, 8, 20)
        end

        sc:SetHeight(yCur + 12)
        UpdateScrollRange()
    end

    frame:SetScript("OnShow", function()
        Refresh()
        scrollFrame:SetVerticalScroll(0)
        scrollBar:SetValue(0)
    end)

    E:RegisterCallback("AchievementUpdate", function()
        if frame:IsVisible() then Refresh() end
    end)
    -- AreaPoisUpdated is debounced at 0.25s and only today's story can change
    -- on it, so this throttles rather than running a full pass 4x a second.
    local lastPoiRefresh = 0
    E:RegisterCallback("AreaPoisUpdated", function()
        if not frame:IsVisible() then return end
        local now = GetTime()
        if now - lastPoiRefresh < 5 then return end
        lastPoiRefresh = now
        Refresh()
    end)

    E:RegisterTab(8, frame)
end)
