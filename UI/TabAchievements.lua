local E = EverythingDelves
local L = E.L

local ipairs, pairs = ipairs, pairs
local math_abs, math_ceil, math_max, math_min = math.abs, math.ceil, math.max, math.min

local PAD_TOP, PAD_LEFT, PAD_RIGHT, PAD_BOTTOM, GROUP_GAP, INTRO_GAP = 20, 24, 14, 28, 22, 16
local ROW, LIST_ROW, HINT_GAP, COL_GAP, ITEM_GAP = 44, 28, 8, 10, 8
local CHEVRON, CHECK, CELL_CHECK, STAR, CHECK_GAP = 12, 14, 12, 14, 6
local NAME_MIN, REWARD_LINE, PILLAR_LINE, STORY_HEAD, STORY_LINE = 150, 20, 24, 18, 22
local CRIT_HEAD, CRIT_LINE, CRIT_GAP, CRIT_INDENT = 20, 22, 6, CHEVRON + ITEM_GAP
local TIER_BOX, TIER_GAP, TIER_CHECK, TIER_LABEL, TIER_VALUE, ACH_ROW, FEAT_HEAD = 28, 4, 10, 110, 56, 42, 30
local STAR_ICON = "Interface\\Common\\FavoritesIcon"
local FEATS_CATEGORY = 81

local COLUMNS = {
    { key = "today",   label = L["Today's Story"], width = 150 },
    { key = "best",    label = L["Your Best"],     width = 58, right = true },
    { key = "depths",  label = L["Depths"],        width = 58, right = true, check = true },
    { key = "chests",  label = L["Chests"],        width = 58, right = true, check = true },
    { key = "stories", label = L["Stories"],       width = 58, right = true, check = true },
    { key = "zone",    label = L["Zone"],          width = 112 },
}

local function StripCodes(s)
    return (s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
end

local function NoColon(s)
    return (s:gsub("%s*:%s*$", ""):gsub("%s*\239\188\154%s*$", ""))
end

local function CountDone(criteria)
    local n = 0
    for _, c in ipairs(criteria or {}) do
        if c.completed then n = n + 1 end
    end
    return n
end

local function Fraction(done, total)
    if not total or total == 0 then return "--", false, true end
    return done .. "/" .. total, done >= total, false
end

-- A card centers a control in its row but never sizes it, and a row frame left with no height came up blank
-- after a cold login
local function Row(content, height)
    local f = CreateFrame("Frame", nil, content)
    if height then f:SetHeight(height) end
    return f
end

local function Check(ui, parent, size)
    local t = parent:CreateTexture(nil, "ARTWORK")
    t:SetSize(size, size)
    t:SetTexture(ui:Texture("check"))
    t:SetVertexColor(ui:Color("label"))
    return t
end

-- Lines hang from the frame's top and the card centers the frame in its row, so it must be as tall as they are
local function MeasureLines(self)
    local h = self._linesH or 1
    self:SetHeight(h)
    return h
end

local function Muted(ui, fs)
    fs:SetTextColor(ui:Color("muted"))
    return fs
end

local function Collect()
    local data = { status = {} }
    for _, d in ipairs(E.DelveData or {}) do
        data.status[d.name] = E:GetDelveAchievementStatus(d.name)
    end
    data.glory = E.GetGloryStatus and E:GetGloryStatus()
    data.credits, data.variants = {}, {}
    if E.GetTodaysStoryCredits then
        data.credits, data.variants = E:GetTodaysStoryCredits(data.status)
    end
    data.creditByDelve = {}
    for _, c in ipairs(data.credits) do data.creditByDelve[c.delve] = c.variant end

    local stories, chests, depths = 0, 0, 0
    for _, st in pairs(data.status) do
        if st.stories then
            -- Unnamed criteria are skipped by the expanded list, so
            -- counting them here would claim more than it can show.
            for _, c in ipairs(st.stories.criteria) do
                if not c.completed and c.name ~= "" then stories = stories + 1 end
            end
        end
        if st.discoveries and st.discoveries.total > 0 then
            chests = chests + math_max(0, st.discoveries.total - st.discoveries.found)
        end
        depths = depths + #(st.depthsMissing or {})
    end
    data.totals = StripCodes(L["Still to earn: %s%d|r story variants, %s%d|r Sturdy Chests, %s%d|r tier goals"]
        :format("", stories, "", chests, "", depths))
    data.lab = E.LabyrinthAchievementStatus and E.LabyrinthAchievementStatus()
    return data
end

local function BuildIntro(ui, content, v)
    local b = ui:CreateTextBlock(content)
    b:AddLine(L["Story variants, Sturdy Chests and tier goals for every delve"], "label")
    b:AddLine(L["Achievements are account-wide and cover all of Midnight, not only this season."] .. " "
        .. L["Your Best is the highest tier Everything Delves has logged you clearing, so it only counts runs since you installed it."],
        "hint", { gap = HINT_GAP })
    v.intro = b
end

local function BuildGlory(ui, content, v)
    local card = ui:CreateGroup(content, nil)
    local top = Row(content, ROW)
    top.name = ui:CreateText(top, "", "title")
    top.name:SetWordWrap(false)
    top.name:SetPoint("LEFT")
    top.check = Check(ui, top, CHECK)
    top.state = Muted(ui, ui:CreateText(top, "", "label"))
    top.state:SetWordWrap(false)
    card:Add(top, { height = ROW, fill = true })

    local list = Row(content)
    list.reward = ui:CreateText(list, "", "hint")
    list.reward:SetWordWrap(false)
    list.reward:SetPoint("TOPLEFT")
    list.pillars = {}
    list.Measure = MeasureLines
    card:Add(list, { fitHeight = true, fill = true })

    v.gloryNone = Muted(ui, ui:CreateText(content, L["Achievement data unavailable"], "label"))
    card:Add(v.gloryNone, { height = ROW, fill = true })
    v.gloryTop, v.gloryList = top, list
    return card
end

local function PillarLine(ui, list, i)
    local p = list.pillars[i]
    if p then return p end
    p = { check = Check(ui, list, CHECK), name = ui:CreateText(list, "", "label") }
    p.name:SetWordWrap(false)
    p.left = Muted(ui, ui:CreateText(list, "", "label"))
    p.left:SetWordWrap(false)
    p.left:SetPoint("LEFT", p.name, "RIGHT", ITEM_GAP, 0)
    list.pillars[i] = p
    return p
end

local function RenderGlory(ui, v, glory)
    local top, list = v.gloryTop, v.gloryList
    top:SetShown(glory ~= nil)
    list:SetShown(glory ~= nil)
    v.gloryNone:SetShown(glory == nil)
    if not glory then return end

    top.name:SetText(glory.name or "")
    top.check:SetShown(glory.done)
    top.check:ClearAllPoints()
    top.check:SetPoint("LEFT", top.name, "RIGHT", ITEM_GAP + 2, 0)
    top.state:ClearAllPoints()
    if glory.done then
        top.state:SetPoint("LEFT", top.check, "RIGHT", CHECK_GAP, 0)
        top.state:SetText(L["Complete"])
    else
        top.state:SetPoint("LEFT", top.name, "RIGHT", ITEM_GAP + 2, 0)
        top.state:SetText(glory.remaining > 0 and L["%d of %d still to earn"]:format(glory.remaining, #glory.pillars)
            or L["Incomplete"])
    end

    local y = 0
    list.reward:SetShown(glory.reward ~= nil)
    if glory.reward then
        list.reward:SetText(glory.reward)
        y = REWARD_LINE
    end
    for i, pillar in ipairs(glory.pillars) do
        local p = PillarLine(ui, list, i)
        local mid = -(y + PILLAR_LINE / 2)
        p.check:ClearAllPoints()
        p.check:SetPoint("LEFT", list, "TOPLEFT", 0, mid)
        p.check:SetShown(pillar.done)
        p.name:ClearAllPoints()
        p.name:SetPoint("LEFT", list, "TOPLEFT", CHECK + ITEM_GAP, mid)
        p.name:SetText(pillar.name)
        p.name:Show()
        local left = not pillar.done and pillar.left and pillar.left > 0
        p.left:SetText(left and L["%d left"]:format(pillar.left) or "")
        p.left:SetShown(left and true or false)
        y = y + PILLAR_LINE
    end
    for i = #glory.pillars + 1, #list.pillars do
        local p = list.pillars[i]
        p.check:Hide()
        p.name:Hide()
        p.left:Hide()
    end
    list._linesH = math_max(1, y)
end

local function BuildToday(ui, content, v)
    local card = ui:CreateGroup(content, nil)
    local f = Row(content)
    f.head = ui:CreateText(f, "", "value")
    f.head:SetWordWrap(false)
    f.head:SetPoint("TOPLEFT")
    f.lines = {}
    f.Measure = MeasureLines
    card:Add(f, { fitHeight = true, fill = true })
    v.today = f
    return card
end

local function RenderToday(ui, v, credits)
    local f = v.today
    if #credits > 0 then
        f.head:SetText(L["%d of today's story variants are ones you still need"]:format(#credits))
        f.head:SetTextColor(ui:Color("text"))
    else
        f.head:SetText(L["None of today's story variants are new to you."])
        f.head:SetTextColor(ui:Color("muted"))
    end
    local dash = "  " .. E.DelveList.cc("muted") .. "-|r  "
    local y = STORY_HEAD + (#credits > 0 and CHECK_GAP or 0)
    for i, c in ipairs(credits) do
        local line = f.lines[i]
        if not line then
            line = { star = f:CreateTexture(nil, "ARTWORK"), text = ui:CreateText(f, "", "label") }
            line.star:SetSize(STAR, STAR)
            line.star:SetTexture(STAR_ICON)
            line.text:SetWordWrap(false)
            f.lines[i] = line
        end
        local mid = -(y + STORY_LINE / 2)
        line.star:ClearAllPoints()
        line.star:SetPoint("LEFT", f, "TOPLEFT", 0, mid)
        line.text:ClearAllPoints()
        line.text:SetPoint("LEFT", f, "TOPLEFT", STAR + ITEM_GAP, mid)
        line.text:SetText(c.delve .. dash .. c.variant)
        line.star:Show()
        line.text:Show()
        y = y + STORY_LINE
    end
    for i = #credits + 1, #f.lines do
        f.lines[i].star:Hide()
        f.lines[i].text:Hide()
    end
    f._linesH = y
end

local function NewDelveRow(ui, content, v, delve)
    local row = CreateFrame("Button", nil, content)
    row:SetHeight(LIST_ROW)
    row.delve = delve
    local hl = row:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(ui:Color("hover"))
    row.chevron = row:CreateTexture(nil, "ARTWORK")
    row.chevron:SetSize(CHEVRON, CHEVRON)
    row.chevron:SetPoint("LEFT")
    row.chevron:SetVertexColor(ui:Color("muted"))
    row.name = ui:CreateText(row, delve.name, "label")
    row.name:SetTextColor(ui:Color("text"))
    row.name:SetWordWrap(false)
    row.done = Check(ui, row, CELL_CHECK)
    row.cells, row.checks = {}, {}
    for _, col in ipairs(COLUMNS) do
        local fs = ui:CreateText(row, "", "label")
        fs:SetWordWrap(false)
        if col.right then fs:SetJustifyH("RIGHT") end
        row.cells[col.key] = fs
        if col.check then row.checks[col.key] = Check(ui, row, CELL_CHECK) end
    end
    row.star = row:CreateTexture(nil, "ARTWORK")
    row.star:SetSize(STAR, STAR)
    row.star:SetTexture(STAR_ICON)

    row:RegisterForClicks("LeftButtonUp")
    row:SetScript("OnClick", function(self)
        v.open[self.delve.name] = not v.open[self.delve.name]
        v.relayout()
    end)
    row:SetScript("OnEnter", function(self)
        local body = v.open[self.delve.name] and L["Click to hide what's left here."] or L["Click to see what's left here."]
        if self.unknown then body = body .. "\n" .. L["Tier progress for this delve could not be read."] end
        ui:ShowTooltip(self, self.delve.name, body)
    end)
    row:SetScript("OnLeave", function() ui:HideTooltip() end)
    return row
end

local function NewDetail(content)
    local f = Row(content)
    f.lines = {}
    f.Measure = MeasureLines
    return f
end

local function DetailLine(ui, f, i)
    local line = f.lines[i]
    if line then return line end
    line = { check = Check(ui, f, CHECK), head = ui:CreateText(f, "", "groupLabel"), text = ui:CreateText(f, "", "label") }
    line.tail = Muted(ui, ui:CreateText(f, "", "label"))
    for _, fs in ipairs({ line.head, line.text, line.tail }) do fs:SetWordWrap(false) end
    line.tail:SetPoint("LEFT", line.text, "RIGHT", CHECK_GAP, 0)
    f.lines[i] = line
    return line
end

local function FillDetail(ui, f, st)
    local items = {}
    local s = st.stories
    if s and #s.criteria > 0 then
        items[#items + 1] = { head = L["Stories"] .. "  " .. (Fraction(CountDone(s.criteria), #s.criteria)) }
        for _, c in ipairs(s.criteria) do
            if c.name ~= "" then items[#items + 1] = { text = c.name, done = c.completed } end
        end
    end
    local d = st.discoveries
    if d and d.total > 0 then
        items[#items + 1] = { head = L["Sturdy Chests"] .. "  " .. (Fraction(d.found, d.total)) }
    end
    if st.depths and #st.depths > 0 then
        items[#items + 1] = { head = L["Delver of the Depths"] .. "  "
            .. (Fraction(#st.depths - #st.depthsMissing, #st.depths)) }
        for _, t in ipairs(st.depths) do
            -- An earned series credits every delve, so show the
            -- earned date rather than implying this delve was
            -- cleared at that tier.
            local tail
            if t.seriesEarned then
                tail = t.earnedText and L["achievement earned %s"]:format(t.earnedText) or L["earned account-wide"]
            end
            items[#items + 1] = { text = t.label, done = t.completed, tail = tail }
        end
    end
    if st.depthsUnknown then
        items[#items + 1] = { note = L["Tier progress for this delve could not be read."] }
    end

    local y = 0
    for i, it in ipairs(items) do
        local line = DetailLine(ui, f, i)
        if it.head and i > 1 then y = y + CRIT_GAP end
        local h = it.head and CRIT_HEAD or CRIT_LINE
        local mid = -(y + h / 2)
        line.head:SetShown(it.head ~= nil)
        line.text:SetShown(it.head == nil)
        line.check:SetShown(it.done == true)
        line.tail:SetShown(it.tail ~= nil)
        if it.head then
            line.head:ClearAllPoints()
            line.head:SetPoint("LEFT", f, "TOPLEFT", CRIT_INDENT, mid)
            line.head:SetText(it.head)
        else
            line.check:ClearAllPoints()
            line.check:SetPoint("LEFT", f, "TOPLEFT", CRIT_INDENT, mid)
            line.text:ClearAllPoints()
            line.text:SetPoint("LEFT", f, "TOPLEFT", CRIT_INDENT + (it.note and 0 or CHECK + ITEM_GAP), mid)
            line.text:SetText(it.text or it.note)
            line.text:SetTextColor(ui:Color(it.note and "muted" or "label"))
            line.tail:SetText(it.tail or "")
        end
        y = y + h
    end
    for i = #items + 1, #f.lines do
        local line = f.lines[i]
        line.check:Hide()
        line.head:Hide()
        line.text:Hide()
        line.tail:Hide()
    end
    f._linesH = math_max(1, y)
end

local function BuildTable(ui, content, v)
    local card = ui:CreateGroup(content, L["Delve Achievements"])

    local top = Row(content, ROW)
    top._controls = {}
    top.box = ui:CreateCheckbox(top, L["Hide finished delves"],
        function() return E.db and E.db.achHideCompleted == true end,
        function(on)
            if E.db then E.db.achHideCompleted = on end
            v.relayout()
        end)
    top.totals = ui:CreateText(top, "", "label")
    top.totals:SetWordWrap(false)
    top.totals:SetPoint("LEFT")
    top.totals:SetPoint("RIGHT", top.box, "LEFT", -COL_GAP, 0)
    card:Add(top, { height = ROW, fill = true })
    v.top = top

    local head = Row(content, LIST_ROW)
    head.name = ui:CreateText(head, L["Delve"], "groupLabel")
    head.cells = {}
    for _, col in ipairs(COLUMNS) do
        local fs = ui:CreateText(head, col.label, "groupLabel")
        fs:SetWordWrap(false)
        if col.right then fs:SetJustifyH("RIGHT") end
        head.cells[col.key] = fs
    end
    card:Add(head, { height = LIST_ROW, fill = true })
    v.head = head

    v.rows = {}
    for i, delve in ipairs(E.DelveData or {}) do
        local row = NewDelveRow(ui, content, v, delve)
        card:Add(row, { height = LIST_ROW, fill = true })
        row.detail = NewDetail(content)
        card:Add(row.detail, { fitHeight = true, fill = true })
        v.rows[i] = row
    end

    v.empty = Muted(ui, ui:CreateText(content, L["Every delve is finished. Nothing left to earn."], "label"))
    card:Add(v.empty, { height = ROW, fill = true })
    return card
end

local function ColumnWidths(head)
    local widths, used = {}, 0
    for i, col in ipairs(COLUMNS) do
        local fs = head.cells[col.key]
        fs:SetWidth(0)
        widths[i] = math_max(col.width, math_ceil(fs:GetStringWidth() or 0) + 1)
        used = used + widths[i] + COL_GAP
    end
    return widths, used
end

local function PlaceCells(row, widths, used, nameX)
    local right = 0
    for i, col in ipairs(COLUMNS) do
        local fs = row.cells[col.key]
        local x = (col.key == "today" and row.starred) and (STAR + CHECK_GAP) or 0
        fs:ClearAllPoints()
        fs:SetPoint("LEFT", row, "RIGHT", -(right + widths[i]) + x, 0)
        fs:SetWidth(widths[i] - x)
        if col.key == "today" and row.star then
            row.star:ClearAllPoints()
            row.star:SetPoint("LEFT", row, "RIGHT", -(right + widths[i]), 0)
        end
        right = right + widths[i] + COL_GAP
    end
    row.name:ClearAllPoints()
    row.name:SetPoint("LEFT", row, "LEFT", nameX, 0)
    row.name:SetPoint("RIGHT", row, "RIGHT", -used, 0)
end

local function PlaceChecks(row, nameW)
    for key, check in pairs(row.checks) do
        local fs = row.cells[key]
        check:ClearAllPoints()
        check:SetPoint("RIGHT", fs, "RIGHT", -(math_ceil(fs:GetStringWidth() or 0) + 4), 0)
    end
    row.done:ClearAllPoints()
    row.done:SetPoint("LEFT", row.name, "LEFT", math_min(math_ceil(row.name:GetStringWidth() or 0), nameW) + CHECK_GAP, 0)
end

local function FillRow(ui, v, row, st)
    local name = row.delve.name
    row.chevron:SetTexture(ui:Texture(v.open[name] and "chevron-down" or "chevron-right"))
    row.done:SetShown(st ~= nil and st.allDone == true)
    row.unknown = st ~= nil and st.depthsUnknown

    local values = {}
    if st and st.stories then values.stories = { Fraction(CountDone(st.stories.criteria), #st.stories.criteria) } end
    if st and st.discoveries and st.discoveries.total > 0 then
        values.chests = { Fraction(st.discoveries.found, st.discoveries.total) }
    end
    if st and st.depthsUnknown then
        values.depths = { "?", false, true }
    elseif st and st.depths and #st.depths > 0 then
        values.depths = { Fraction(#st.depths - #st.depthsMissing, #st.depths) }
    end
    local hist = E.GetDelveHistory and E:GetDelveHistory(name)
    local best = hist and hist.lifetime and hist.lifetime.highestTier
    if best and best > 0 then values.best = { "T" .. best, false, false } end

    local credit = v.data.creditByDelve[name]
    local variant = credit or v.data.variants[name]
    if variant and variant ~= "" then values.today = { variant, false, false } end
    row.starred = credit ~= nil
    row.star:SetShown(row.starred)
    values.zone = { row.delve.zone or "", false, false }

    for _, col in ipairs(COLUMNS) do
        local val = values[col.key] or { "--", false, true }
        local fs = row.cells[col.key]
        fs:SetText(val[1])
        fs:SetTextColor(ui:Color(val[3] and "muted" or "label"))
        if row.checks[col.key] then row.checks[col.key]:SetShown(val[2]) end
    end
end

local function TipOnHover(ui, f)
    f:EnableMouse(true)
    f:SetScript("OnEnter", function(self)
        if self.tipTitle then ui:ShowTooltip(self, self.tipTitle, self.tipBody) end
    end)
    f:SetScript("OnLeave", function() ui:HideTooltip() end)
end

local function AchRow(ui, content)
    local row = Row(content, ACH_ROW)
    row.check = Check(ui, row, CHECK)
    row.check:SetPoint("LEFT")
    row.name = ui:CreateText(row, "", "value")
    row.name:SetWordWrap(false)
    row.reward = Muted(ui, ui:CreateText(row, "", "hint"))
    row.reward:SetWordWrap(false)
    row.prog = ui:CreateText(row, "", "label")
    row.prog:SetWordWrap(false)
    row.prog:SetPoint("RIGHT")
    TipOnHover(ui, row)
    return row
end

local function BuildLabyrinth(ui, content, v)
    local LAB = E.Labyrinth
    local card = ui:CreateGroup(content, " ")
    local strip = Row(content, ROW)
    strip.label = ui:CreateText(strip, NoColon(L["Tier goals:"]), "label")
    strip.label:SetWordWrap(false)
    strip.label:SetPoint("LEFT")
    strip.value = ui:CreateText(strip, "", "value")
    strip.value:SetWordWrap(false)
    strip.value:SetPoint("RIGHT")
    strip.boxes = {}
    for i = 1, #LAB.tierAchievements do
        local box = CreateFrame("Frame", nil, strip)
        box:SetHeight(TIER_BOX)
        ui:Paint(box, "input", "inputBorder")
        box.check = Check(ui, box, TIER_CHECK)
        box.text = ui:CreateText(box, "T" .. i, "hint")
        TipOnHover(ui, box)
        strip.boxes[i] = box
    end
    card:Add(strip, { height = ROW, fill = true })

    v.labRows = {}
    for i = 1, #LAB.achievementList do
        v.labRows[i] = AchRow(ui, content)
        card:Add(v.labRows[i], { height = ACH_ROW, fill = true })
    end
    local head = Row(content, FEAT_HEAD)
    head.text = Muted(ui, ui:CreateText(head, "", "groupLabel"))
    head.text:SetWordWrap(false)
    head.text:SetPoint("LEFT")
    card:Add(head, { height = FEAT_HEAD, fill = true })
    v.featRows = {}
    for i = 1, #LAB.featAchievements do
        v.featRows[i] = AchRow(ui, content)
        card:Add(v.featRows[i], { height = ACH_ROW, fill = true })
    end

    v.labNone = Muted(ui, ui:CreateText(content, L["Achievement data unavailable"], "label"))
    card:Add(v.labNone, { height = ROW, fill = true })
    v.labCard, v.labStrip, v.featHead = card, strip, head
    return card
end

local function RenderStrip(ui, strip, tiers, done, rowW)
    strip.value:SetText(done .. " / " .. #tiers)
    strip.label:SetWidth(0)
    local labelW = math_max(TIER_LABEL, math_ceil(strip.label:GetStringWidth() or 0) + ITEM_GAP)
    local valueW = math_max(TIER_VALUE, math_ceil(strip.value:GetStringWidth() or 0) + ITEM_GAP)
    local boxW = math_max(16, (rowW - labelW - valueW - TIER_GAP * (#tiers - 1)) / #tiers)
    for i, box in ipairs(strip.boxes) do
        local a = tiers[i]
        box:ClearAllPoints()
        box:SetPoint("LEFT", strip, "LEFT", labelW + (i - 1) * (boxW + TIER_GAP), 0)
        box:SetWidth(boxW)
        box.tipTitle, box.tipBody = a.name, a.description
        box.check:SetShown(a.done)
        box.text:SetTextColor(ui:Color(a.done and "text" or "muted"))
        box.text:ClearAllPoints()
        if a.done then
            box.text:SetPoint("CENTER", box, "CENTER", (TIER_CHECK + 3) / 2, 0)
            box.check:ClearAllPoints()
            box.check:SetPoint("RIGHT", box.text, "LEFT", -3, 0)
        else
            box.text:SetPoint("CENTER")
        end
    end
end

local function FillAch(ui, row, a)
    row:SetShown(a ~= nil)
    if not a then return end
    row.tipTitle, row.tipBody = a.name, a.description
    row.check:SetShown(a.done)
    row.name:SetText(a.name)
    row.name:SetTextColor(ui:Color(a.done and "muted" or "text"))
    row.prog:SetText((not a.done and a.total > 1) and (a.cur .. "/" .. a.total) or "")
    row.reward:SetShown(a.reward ~= nil)
    row.reward:SetText(a.reward or "")
    local x, right = CHECK + ITEM_GAP, math_ceil(row.prog:GetStringWidth() or 0) + ITEM_GAP
    row.name:ClearAllPoints()
    row.reward:ClearAllPoints()
    if a.reward then
        row.name:SetPoint("BOTTOMLEFT", row, "LEFT", x, 1)
        row.name:SetPoint("BOTTOMRIGHT", row, "RIGHT", -right, 1)
        row.reward:SetPoint("TOPLEFT", row, "LEFT", x, -1)
        row.reward:SetPoint("TOPRIGHT", row, "RIGHT", -right, -1)
    else
        row.name:SetPoint("LEFT", row, "LEFT", x, 0)
        row.name:SetPoint("RIGHT", row, "RIGHT", -right, 0)
    end
end

local function RenderLabyrinth(ui, v, st, inner)
    v.labCard.label:SetText(E.LabyrinthDisplayName())
    v.labNone:SetShown(st == nil)
    local tiers = st and st.tiers
    v.labStrip:SetShown(tiers ~= nil)
    if tiers then RenderStrip(ui, v.labStrip, tiers, st.tiersDone, inner - ui:Spacing("rowPadding") * 2) end
    for i, row in ipairs(v.labRows) do FillAch(ui, row, st and st.list[i]) end
    local feats = st and st.feats or {}
    local title = GetCategoryInfo and GetCategoryInfo(FEATS_CATEGORY)
    v.featHead.text:SetText(type(title) == "string" and title or "Feats of Strength")
    v.featHead:SetShown(#feats > 0)
    for i, row in ipairs(v.featRows) do FillAch(ui, row, feats[i]) end
end

E:RegisterModule(function()
    local ui = E.ui
    local frame = CreateFrame("Frame", "EverythingDelvesTabAchievementsContent")
    local area = ui:CreateScrollArea(frame, { clearGrip = true })
    area:SetAllPoints(frame)
    local content = area.content

    local v = { open = {} }
    BuildIntro(ui, content, v)
    local cards = { BuildGlory(ui, content, v), BuildLabyrinth(ui, content, v), BuildToday(ui, content, v),
        BuildTable(ui, content, v) }

    local lastWidth = 0
    local function ViewWidth()
        local w = area.scroll:GetWidth() or 0
        if w <= 0 then w = (frame:GetWidth() or 0) - 10 end
        return math_max(1, w)
    end

    local function Render(recollect)
        if recollect or not v.data then v.data = Collect() end
        local data = v.data
        local view = ViewWidth()
        lastWidth = view

        RenderGlory(ui, v, data.glory)
        RenderToday(ui, v, data.credits)
        v.top.totals:SetText(data.totals)
        v.top.box:Refresh()
        local boxLabel = math_ceil(v.top.box.label:GetStringWidth() or 0) + ui:Spacing("checkboxGap")
        v.top.box:ClearAllPoints()
        v.top.box:SetPoint("RIGHT", v.top, "RIGHT", -boxLabel, 0)
        -- The library sized the click area from the label as measured while the page was built
        v.top.box:SetHitRectInsets(0, -boxLabel, 0, 0)

        local widths, used = ColumnWidths(v.head)
        local nameX = CHEVRON + ITEM_GAP
        -- Narrower than this, the table scrolls sideways rather than squeezing the names
        local minWidth = nameX + NAME_MIN + used + ui:Spacing("rowPadding") * 2 + PAD_LEFT + PAD_RIGHT
        local width = math_max(view, minWidth)
        content:SetWidth(width)
        RenderLabyrinth(ui, v, data.lab, width - PAD_LEFT - PAD_RIGHT)
        local nameW = width - PAD_LEFT - PAD_RIGHT - ui:Spacing("rowPadding") * 2 - nameX - used
        PlaceCells(v.head, widths, used, nameX)

        local hideDone = E.db and E.db.achHideCompleted
        local shown = 0
        for _, row in ipairs(v.rows) do
            local st = data.status[row.delve.name]
            local visible = not (hideDone and st and st.allDone)
            row:SetShown(visible)
            local open = visible and st ~= nil and v.open[row.delve.name] == true
            row.detail:SetShown(open)
            if visible then
                shown = shown + 1
                FillRow(ui, v, row, st)
                PlaceCells(row, widths, used, nameX)
                PlaceChecks(row, nameW)
                if open then FillDetail(ui, row.detail, st) end
            end
        end
        v.empty:SetShown(shown == 0)

        local y = PAD_TOP
        v.intro:ClearAllPoints()
        v.intro:SetPoint("TOPLEFT", content, "TOPLEFT", PAD_LEFT, -y)
        v.intro:SetPoint("TOPRIGHT", content, "TOPRIGHT", -PAD_RIGHT, -y)
        y = y + v.intro:Measure() + INTRO_GAP
        for i, card in ipairs(cards) do
            if i > 1 then y = y + GROUP_GAP end
            card:ClearAllPoints()
            card:SetPoint("TOPLEFT", content, "TOPLEFT", PAD_LEFT, -y)
            card:SetPoint("TOPRIGHT", content, "TOPRIGHT", -PAD_RIGHT, -y)
            card:Layout()
            y = y + card:GetHeight()
        end
        area:SetContentSize(width, y + PAD_BOTTOM)
    end
    v.relayout = function() Render(false) end

    -- Wrapped text measured before its first draw can come up short, so the page is measured again a frame later
    local pending = false
    local function RenderSoon()
        if pending then return end
        pending = true
        C_Timer.After(0, function()
            pending = false
            if frame:IsVisible() then Render(false) end
        end)
    end

    area.scroll:HookScript("OnSizeChanged", function(_, w)
        if frame:IsVisible() and math_abs((w or 0) - lastWidth) >= 1 then
            Render(false)
            RenderSoon()
        end
    end)

    frame:SetScript("OnShow", function()
        Render(true)
        area:ScrollTo(0, 0)
        RenderSoon()
    end)

    E:RegisterCallback("AchievementUpdate", function()
        if frame:IsVisible() then Render(true) end
    end)
    -- AreaPoisUpdated is debounced at 0.25s and only today's story can change
    -- on it, so this throttles rather than running a full pass 4x a second.
    local lastPoiRefresh = 0
    E:RegisterCallback("AreaPoisUpdated", function()
        if not frame:IsVisible() then return end
        local now = GetTime()
        if now - lastPoiRefresh < 5 then return end
        lastPoiRefresh = now
        Render(true)
    end)

    E:RegisterTab(8, frame)
end)
