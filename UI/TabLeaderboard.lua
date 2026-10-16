local E = EverythingDelves
local L = E.L

local ipairs, select, tostring = ipairs, select, tostring
local math_abs, math_ceil, math_floor, math_max = math.abs, math.ceil, math.floor, math.max
local string_format = string.format
local table_sort = table.sort
local date = date

local PAD_TOP, PAD_LEFT, PAD_RIGHT, PAD_BOTTOM, GROUP_GAP, INTRO_GAP = 20, 24, 14, 28, 22, 16
local SUMMARY_H, HINT_GAP, FILTER_GAP, FILTER_SPACE = 18, 8, 12, 8
-- Sized for the longest translated labels, and a spec followed by its class
local FILTER_WIDTHS = { 140, 180, 240 }
local HEAD, DELVE_ROW, RANK_ROW, EMPTY_ROW = 28, 32, 28, 44
local INSET, CHEVRON, GAP, NAME_GAP, NAME_MIN, STORY_MIN = 14, 12, 10, 6, 150, 100
local NAME_X = INSET + CHEVRON + GAP
local ALL_CLASSES, ALL_SPECS = "", 0

-- The headings reuse the "Fastest:" style phrases, drawn without their colon (a full-width one in Chinese)
local function NoColon(s)
    return (s:gsub("%s*:%s*$", ""):gsub("%s*\239\188\154%s*$", ""))
end

local function ShortName(v, char)
    local rec = v.roster[char]
    return (rec and rec.name) or char:match("^(.-) %- ") or char
end

local function ClassOf(v, char, run)
    if run and run.class then return run.class end
    local rec = v.roster[char]
    return rec and rec.class
end

local function SpecName(specID)
    if not (specID and GetSpecializationInfoByID) then return nil end
    local _, name = GetSpecializationInfoByID(specID)
    return name
end

local function SpecClass(specID)
    if not (specID and GetSpecializationInfoByID) then return nil end
    return (select(6, GetSpecializationInfoByID(specID)))
end

local function ClassName(classFile)
    return (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[classFile]) or classFile
end

local LAB_MARKS = { 3, 6, 9, "kindo" }

local function LabyrinthRowName(mark)
    if mark == "kindo" then return L["Kindo'jan"] end
    return L["%d chambers"]:format(mark)
end

local function Collect(v)
    v.runs = E.CollectLeaderboardRuns()
    local sv = EverythingDelvesDB
    v.roster = (sv and sv.roster) or {}
    v.me = E.CharKey()
    local has, tiers, nemesis, seenNem, classes, specs = {}, {}, {}, {}, {}, {}
    v.anyLabyrinth = false
    for _, r in ipairs(v.runs) do
        if not has[r.tier] then
            has[r.tier] = true
            tiers[#tiers + 1] = r.tier
        end
        if r.kind == "nemesis" and not seenNem[r.delve] then
            seenNem[r.delve] = true
            nemesis[#nemesis + 1] = r.delve
        end
        if r.kind == "labyrinth" then v.anyLabyrinth = true end
        if r.class then classes[r.class] = true end
        if r.spec then specs[r.spec] = true end
    end
    -- A run with no ranked time has no board entry, but the card must not say there are no runs
    local labHist = E.Labyrinth and E.db and E.db.delveHistory and E.db.delveHistory[E.Labyrinth.name]
    if labHist and labHist.recentRuns and #labHist.recentRuns > 0 then v.anyLabyrinth = true end
    if v.cls ~= ALL_CLASSES and not classes[v.cls] then v.cls = ALL_CLASSES end
    if v.spec ~= ALL_SPECS and not specs[v.spec] then v.spec = ALL_SPECS end
    table_sort(tiers)
    table_sort(nemesis)
    v.tiers, v.nemesisKeys = tiers, nemesis
    local saved = E.db and E.db.leaderboardTier
    v.tier = (saved and has[saved]) and saved or E.MostRunTier(v.runs)
    local midnight = {}
    for _, d in ipairs(E.DelveData or {}) do midnight[#midnight + 1] = d.name end
    table_sort(midnight, function(a, b) return a:lower() < b:lower() end)
    v.midnightKeys = midnight
    v.labyrinthKeys, v.labyrinthMarks = {}, {}
    for _, mark in ipairs(LAB_MARKS) do
        local key = E.LabyrinthBoardKey(mark)
        v.labyrinthKeys[#v.labyrinthKeys + 1] = key
        v.labyrinthMarks[key] = mark
    end
end

local function Rank(v, delve)
    if not v.tier then return {} end
    return E.RankLeaderboard(v.runs, delve, v.tier, v.cls ~= ALL_CLASSES and v.cls or nil,
        v.spec ~= ALL_SPECS and v.spec or nil)
end

local function YourPlace(v, list)
    for i, r in ipairs(list) do
        if r.char == v.me then return i end
    end
    return nil
end

local function TierOptions(v)
    local out = {}
    for _, t in ipairs(v.tiers or {}) do out[#out + 1] = { value = t, label = L["Tier %d"]:format(t) } end
    return out
end

local function ClassOptions(v)
    local out, seen, list = { { value = ALL_CLASSES, label = L["All classes"] } }, {}, {}
    for _, r in ipairs(v.runs or {}) do
        if r.class and not seen[r.class] then
            seen[r.class] = true
            list[#list + 1] = r.class
        end
    end
    table_sort(list, function(a, b) return ClassName(a) < ClassName(b) end)
    for _, c in ipairs(list) do out[#out + 1] = { value = c, label = ClassName(c) } end
    return out
end

-- Two classes can share a spec's name (Frost, Holy), so with every class listed each spec names its class
local function SpecOptions(v)
    local out, seen, list = { { value = ALL_SPECS, label = L["All specs"] } }, {}, {}
    for _, r in ipairs(v.runs or {}) do
        if r.spec and not seen[r.spec] and (v.cls == ALL_CLASSES or r.class == v.cls) then
            seen[r.spec] = true
            list[#list + 1] = { spec = r.spec, class = r.class, name = SpecName(r.spec) or tostring(r.spec) }
        end
    end
    table_sort(list, function(a, b)
        if a.name ~= b.name then return a.name < b.name end
        return ClassName(a.class or "") < ClassName(b.class or "")
    end)
    for _, s in ipairs(list) do
        out[#out + 1] = { value = s.spec, label = s.name,
            suffix = (v.cls == ALL_CLASSES and s.class) and ClassName(s.class) or nil }
    end
    return out
end

local function Hex(r, g, b)
    return string_format("|cff%02x%02x%02x", math_floor(r * 255 + 0.5), math_floor(g * 255 + 0.5), math_floor(b * 255 + 0.5))
end

local function Text(ui, parent, style, right, muted)
    local fs = ui:CreateText(parent, "", style)
    fs:SetWordWrap(false)
    if right then fs:SetJustifyH("RIGHT") end
    if muted then fs:SetTextColor(ui:Color("muted")) end
    return fs
end

local function NewSection(ui, content, label, emptyText)
    local card = ui:CreateGroup(content, label)
    local t = CreateFrame("Frame", nil, content)
    t.head = CreateFrame("Frame", nil, t)
    t.head:SetHeight(HEAD)
    t.head.name = Text(ui, t.head, "groupLabel")
    t.head.name:SetText(L["Delve Name"])
    t.head.time = Text(ui, t.head, "groupLabel", true)
    t.head.time:SetText(NoColon(L["Fastest:"]))
    t.head.who = Text(ui, t.head, "groupLabel")
    t.head.who:SetText(L["Character"])
    t.head.story = Text(ui, t.head, "groupLabel")
    t.head.story:SetText(NoColon(L["Story:"]))
    t.head.place = Text(ui, t.head, "groupLabel", true)
    t.head.place:SetText(L["Your rank"])
    t.empty = Text(ui, t, "label", false, true)
    t.empty:SetWordWrap(true)
    t.empty:SetText(emptyText)
    t.rows, t.ranks, t.rankHeads = {}, {}, {}
    card:Add(t, { height = EMPTY_ROW, fill = true })
    t.card = card
    return t
end

local function NewBoardRow(ui, t, v)
    local r = CreateFrame("Button", nil, t)
    r:SetHeight(DELVE_ROW)
    r:RegisterForClicks("LeftButtonUp")
    local hl = r:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(ui:Color("hover"))
    ui:Paint(r, nil, "divider", "T")
    r.chevron = r:CreateTexture(nil, "ARTWORK")
    r.chevron:SetSize(CHEVRON, CHEVRON)
    r.chevron:SetPoint("LEFT", r, "LEFT", INSET, 0)
    r.chevron:SetVertexColor(ui:Color("muted"))
    r.name = Text(ui, r, "value")
    r.time = Text(ui, r, "label", true)
    r.who = E.NamePair(ui, r, "label")
    r.suffix = Text(ui, r, "label", false, true)
    r.story = Text(ui, r, "label")
    r.place = Text(ui, r, "label", true)
    r:SetScript("OnClick", function(self)
        if not self.ranked then return end
        v.open[self.key] = not v.open[self.key]
        v.relayout()
    end)
    r:SetScript("OnEnter", function(self) if self.title then ui:ShowTooltip(self, self.title, nil) end end)
    r:SetScript("OnLeave", function() ui:HideTooltip() end)
    return r
end

local function NewRankHead(ui, t)
    local h = CreateFrame("Frame", nil, t)
    h:SetHeight(RANK_ROW)
    ui:Paint(h, "input", "divider", "T")
    h.pos = Text(ui, h, "groupLabel", true)
    h.pos:SetText(L["Rank"])
    h.who = Text(ui, h, "groupLabel")
    h.who:SetText(L["Character"])
    h.spec = Text(ui, h, "groupLabel")
    h.spec:SetText(L["Spec"])
    h.time = Text(ui, h, "groupLabel", true)
    h.time:SetText(NoColon(L["Fastest:"]))
    h.story = Text(ui, h, "groupLabel")
    h.story:SetText(NoColon(L["Story:"]))
    h.deaths = Text(ui, h, "groupLabel", true)
    h.deaths:SetText(NoColon(L["Deaths:"]))
    h.date = Text(ui, h, "groupLabel")
    h.date:SetText(L["Date"])
    return h
end

local function NewRankRow(ui, t)
    local r = CreateFrame("Frame", nil, t)
    r:SetHeight(RANK_ROW)
    r:EnableMouse(true)
    ui:Paint(r, "input", "divider", "T")
    r.you = ui:Paint(r, "accentSoft")
    r.you:SetDrawLayer("BACKGROUND", 1)
    r.pos = Text(ui, r, "label", true)
    r.who = E.NamePair(ui, r, "label")
    r.suffix = Text(ui, r, "label", false, true)
    r.spec = Text(ui, r, "label", false, true)
    r.time = Text(ui, r, "label", true)
    r.story = Text(ui, r, "label")
    r.deaths = Text(ui, r, "label", true)
    r.date = Text(ui, r, "label", false, true)
    r:SetScript("OnEnter", function(self) ui:ShowTooltip(self, self.title, nil) end)
    r:SetScript("OnLeave", function() ui:HideTooltip() end)
    return r
end

local function Acquire(pool, i, make)
    local item = pool[i]
    if not item then
        item = make()
        pool[i] = item
    end
    item:ClearAllPoints()
    item:Show()
    return item
end

-- Unanchored first: a string held at both ends measures no wider than the gap between them
local function Width(fs)
    fs:ClearAllPoints()
    fs:SetWidth(0)
    return math_ceil(fs:GetStringWidth() or 0) + 1
end

-- Every row is filled first and measured across both cards, so the columns line up from card to card
local function FillSection(ui, v, t, keys, emptyWhen)
    for _, pool in ipairs({ t.rows, t.ranks, t.rankHeads }) do
        for _, item in ipairs(pool) do item:Hide() end
    end
    t.items = {}
    t.isEmpty = emptyWhen
    if emptyWhen then return end
    local nRows, nRanks, nHeads = 0, 0, 0
    for _, key in ipairs(keys) do
        local list = Rank(v, key)
        local top = list[1]
        nRows = nRows + 1
        local r = Acquire(t.rows, nRows, function() return NewBoardRow(ui, t, v) end)
        r.key, r.ranked = key, top ~= nil
        r.title = top and top.char or nil
        local open = top ~= nil and v.open[key] == true
        r.chevron:SetShown(top ~= nil)
        r.chevron:SetTexture(ui:Texture(open and "chevron-down" or "chevron-right"))
        local nice = key
        local boss = t.nemesis and E.NemesisBossByDelve and E.NemesisBossByDelve[key]
        if boss then nice = key .. " (" .. boss .. ")" end
        if t.labyrinth then nice = LabyrinthRowName(v.labyrinthMarks[key]) end
        r.name:SetText(nice)
        if top then
            r.time:SetText(E:FormatClock(top.duration))
            r.time:SetTextColor(ui:Color("label"))
            r.shown = E.ShowNamePair(ui, r.who, ShortName(v, top.char), E.ClassRGB(ui, ClassOf(v, top.char, top)))
            r.suffix:SetText(((top.char == v.me) and (L["(you)"] .. "  ") or "") .. (SpecName(top.spec) or "--"))
            local story = top.story and E.StripColorEscapes(top.story)
            r.story:SetText(story or (t.labyrinth and "" or "--"))
            r.story:SetTextColor(ui:Color(story and "label" or "muted"))
            local place = YourPlace(v, list)
            r.place:SetText(place and L["#%d of %d"]:format(place, #list) or "--")
            r.place:SetTextColor(ui:Color(place == 1 and "text" or (place and "label" or "muted")))
        else
            r.time:SetText("--")
            r.time:SetTextColor(ui:Color("muted"))
            r.shown = E.ShowNamePair(ui, r.who, "", ui:Color("label"))
            r.suffix:SetText("")
            r.story:SetText("")
            r.place:SetText("--")
            r.place:SetTextColor(ui:Color("muted"))
        end
        t.items[#t.items + 1] = { kind = "row", frame = r }
        if open then
            nHeads = nHeads + 1
            local h = Acquire(t.rankHeads, nHeads, function() return NewRankHead(ui, t) end)
            t.items[#t.items + 1] = { kind = "rankHead", frame = h }
            for i, run in ipairs(list) do
                nRanks = nRanks + 1
                local rr = Acquire(t.ranks, nRanks, function() return NewRankRow(ui, t) end)
                local mine = run.char == v.me
                rr.you:SetShown(mine)
                rr.title = run.char
                rr.pos:SetText(tostring(i))
                rr.pos:SetTextColor(ui:Color(i == 1 and "text" or "label"))
                rr.shown = E.ShowNamePair(ui, rr.who, ShortName(v, run.char), E.ClassRGB(ui, ClassOf(v, run.char, run)))
                rr.suffix:SetText(mine and L["(you)"] or "")
                rr.spec:SetText(SpecName(run.spec) or "--")
                rr.time:SetText(E:FormatClock(run.duration))
                local story = run.story and E.StripColorEscapes(run.story)
                rr.story:SetText(story or (t.labyrinth and "" or "--"))
                rr.story:SetTextColor(ui:Color(story and "label" or "muted"))
                rr.deaths:SetText(tostring(run.deaths or 0))
                rr.date:SetText(run.timestamp > 0 and date("%Y-%m-%d", run.timestamp) or "--")
                t.items[#t.items + 1] = { kind = "rank", frame = rr }
            end
        end
    end
end

local function Measure(sections)
    local w = { time = 0, who = 0, story = 0, place = 0, pos = 0, rwho = 0, spec = 0, rtime = 0, deaths = 0, date = 0 }
    local function grow(key, n) if n > w[key] then w[key] = n end end
    for _, t in ipairs(sections) do
        grow("time", Width(t.head.time))
        grow("who", Width(t.head.who))
        grow("story", Width(t.head.story))
        grow("place", Width(t.head.place))
        for _, it in ipairs(t.items or {}) do
            local f = it.frame
            if it.kind == "row" then
                grow("time", Width(f.time))
                local suffix = Width(f.suffix)
                grow("who", Width(f.shown) + (suffix > 1 and (NAME_GAP + suffix) or 0))
                grow("story", Width(f.story))
                grow("place", Width(f.place))
            elseif it.kind == "rankHead" then
                grow("pos", Width(f.pos))
                grow("rwho", Width(f.who))
                grow("spec", Width(f.spec))
                grow("rtime", Width(f.time))
                grow("deaths", Width(f.deaths))
                grow("date", Width(f.date))
            else
                grow("pos", Width(f.pos))
                local suffix = Width(f.suffix)
                grow("rwho", Width(f.shown) + (suffix > 1 and (NAME_GAP + suffix) or 0))
                grow("spec", Width(f.spec))
                grow("rtime", Width(f.time))
                grow("deaths", Width(f.deaths))
                grow("date", Width(f.date))
            end
        end
    end
    return w
end

-- Spans the whole card, past the card's own inset, so each row's tint and divider reach both edges
local function Place(item, t, y)
    item:SetPoint("TOPLEFT", t, "TOPLEFT", -INSET, -y)
    item:SetPoint("TOPRIGHT", t, "TOPRIGHT", INSET, -y)
end

local function Cell(fs, row, x, width)
    fs:ClearAllPoints()
    fs:SetPoint("LEFT", row, "LEFT", x, 0)
    fs:SetWidth(width)
end

local function FromRight(fs, row, right, width)
    fs:ClearAllPoints()
    fs:SetPoint("RIGHT", row, "RIGHT", -right, 0)
    fs:SetWidth(width)
end

local function PlaceBoard(row, w, nameFs, whoFs, suffixFs)
    local right = INSET
    FromRight(row.place, row, right, w.place)
    right = right + w.place + GAP
    FromRight(row.story, row, right, w.story)
    right = right + w.story + GAP
    local whoLeft = right + w.who
    whoFs:ClearAllPoints()
    whoFs:SetPoint("LEFT", row, "RIGHT", -whoLeft, 0)
    if suffixFs then
        suffixFs:ClearAllPoints()
        suffixFs:SetPoint("LEFT", whoFs, "RIGHT", NAME_GAP, 0)
        suffixFs:SetPoint("RIGHT", row, "RIGHT", -right, 0)
    end
    right = whoLeft + GAP
    FromRight(row.time, row, right, w.time)
    right = right + w.time + GAP
    nameFs:ClearAllPoints()
    nameFs:SetPoint("LEFT", row, "LEFT", NAME_X, 0)
    nameFs:SetPoint("RIGHT", row, "RIGHT", -right, 0)
end

local function PlaceRank(row, w, whoFs, suffixFs)
    local x = NAME_X
    Cell(row.pos, row, x, w.pos)
    x = x + w.pos + GAP
    whoFs:ClearAllPoints()
    whoFs:SetPoint("LEFT", row, "LEFT", x, 0)
    if suffixFs then
        suffixFs:ClearAllPoints()
        suffixFs:SetPoint("LEFT", whoFs, "RIGHT", NAME_GAP, 0)
    end
    x = x + w.rwho + GAP
    Cell(row.spec, row, x, w.spec)
    x = x + w.spec + GAP
    Cell(row.time, row, x, w.rtime)
    x = x + w.rtime + GAP
    FromRight(row.date, row, INSET, w.date)
    FromRight(row.deaths, row, INSET + w.date + GAP, w.deaths)
    row.story:ClearAllPoints()
    row.story:SetPoint("LEFT", row, "LEFT", x, 0)
    row.story:SetPoint("RIGHT", row, "RIGHT", -(INSET + w.date + GAP + w.deaths + GAP), 0)
end

local function LayoutSection(t, w)
    t.head:SetShown(not t.isEmpty)
    t.empty:SetShown(t.isEmpty)
    local y
    if t.isEmpty then
        t.empty:ClearAllPoints()
        t.empty:SetPoint("LEFT", t, "TOPLEFT", 0, -EMPTY_ROW / 2)
        t.empty:SetPoint("RIGHT", t, "TOPRIGHT", 0, -EMPTY_ROW / 2)
        y = EMPTY_ROW
    else
        t.head:ClearAllPoints()
        Place(t.head, t, 0)
        PlaceBoard(t.head, w, t.head.name, t.head.who, nil)
        y = HEAD
        for _, it in ipairs(t.items) do
            local f = it.frame
            Place(f, t, y)
            if it.kind == "row" then
                PlaceBoard(f, w, f.name, f.shown, f.suffix)
                y = y + DELVE_ROW
            elseif it.kind == "rankHead" then
                PlaceRank(f, w, f.who, nil)
                y = y + RANK_ROW
            else
                PlaceRank(f, w, f.shown, f.suffix)
                y = y + RANK_ROW
            end
        end
    end
    t:SetHeight(y)
    t._euiRow:SetHeight(y)
end

E:RegisterModule(function()
    local ui = E.ui
    local frame = CreateFrame("Frame", "EverythingDelvesTabLeaderboardContent")
    local area = ui:CreateScrollArea(frame, { clearGrip = true })
    area:SetAllPoints(frame)
    local content = area.content

    local v = { open = {}, cls = ALL_CLASSES, spec = ALL_SPECS, runs = {}, tiers = {} }

    v.summary = E.NamePair(ui, content, "label")
    local hints = ui:CreateTextBlock(content)
    hints:AddLine(L["Your characters, ranked by their fastest clear of each delve at the tier you pick. Click a delve for the full ranking."], "hint")
    hints:AddLine(L["Other players' delve times are not available to addons, so only the characters on this account are ranked."], "hint")

    local filters = CreateFrame("Frame", nil, content)
    filters:SetHeight(ui:Spacing("fieldHeight"))
    filters._controls = {}
    local tierBox = ui:CreateDropdown(filters, nil, function() return TierOptions(v) end,
        function() return v.tier end,
        function(value)
            v.tier = value
            if E.db then E.db.leaderboardTier = value end
            v.relayout()
        end)
    local classBox = ui:CreateDropdown(filters, nil, function() return ClassOptions(v) end,
        function() return v.cls end,
        function(value)
            v.cls = value
            if value ~= ALL_CLASSES and v.spec ~= ALL_SPECS and SpecClass(v.spec) ~= value then
                v.spec = ALL_SPECS
            end
            v.relayout()
        end)
    local specBox = ui:CreateDropdown(filters, nil, function() return SpecOptions(v) end,
        function() return v.spec end,
        function(value)
            v.spec = value
            v.relayout()
        end)
    local boxes = { tierBox, classBox, specBox }
    local x = 0
    for i, box in ipairs(boxes) do
        box:SetWidth(FILTER_WIDTHS[i])
        box:ClearAllPoints()
        box:SetPoint("LEFT", filters, "LEFT", x, 0)
        x = x + FILTER_WIDTHS[i] + FILTER_SPACE
    end

    local nemesis = NewSection(ui, content, L["Seasonal Nemesis"], L["No nemesis delve runs recorded yet."])
    nemesis.nemesis = true
    local labyrinth = NewSection(ui, content, E.LabyrinthDisplayName(), L["No Labyrinth runs recorded yet."])
    labyrinth.labyrinth = true
    local midnight = NewSection(ui, content, L["Midnight Delves"],
        L["No Midnight delve runs recorded yet. Complete a delve to start tracking!"])
    local sections = { nemesis, labyrinth, midnight }

    local lastWidth = 0
    local function ViewWidth()
        local w = area.scroll:GetWidth() or 0
        if w <= 0 then w = (frame:GetWidth() or 0) - 10 end
        return math_max(1, w)
    end

    local function Render(recollect)
        if recollect or not v.collected then
            Collect(v)
            v.collected = true
        end
        local any = #v.runs > 0
        for _, box in ipairs(boxes) do box:Refresh() end
        filters:SetShown(any)

        local held, total = 0, 0
        for _, list in ipairs({ v.nemesisKeys, v.labyrinthKeys, v.midnightKeys }) do
            for _, key in ipairs(list) do
                local top = Rank(v, key)[1]
                if top then
                    total = total + 1
                    if top.char == v.me then held = held + 1 end
                end
            end
        end
        local me = ShortName(v, v.me)
        local summary = L["%s holds %d of %d records"]:format(Hex(E.ClassRGB(ui, ClassOf(v, v.me))) .. me .. "|r", held, total)
        local shown = E.ShowNamePair(ui, v.summary, summary, ui:Color("label"))
        if not any then
            v.summary.plain:Hide()
            v.summary.data:Hide()
        end

        FillSection(ui, v, nemesis, v.nemesisKeys, #v.nemesisKeys == 0)
        FillSection(ui, v, labyrinth, v.labyrinthKeys, not v.anyLabyrinth)
        FillSection(ui, v, midnight, v.midnightKeys, not any)
        local w = Measure(sections)

        local view = ViewWidth()
        lastWidth = view
        local boardNeed = NAME_X + NAME_MIN + w.time + w.who + w.story + w.place + GAP * 4 + INSET
        local rankNeed = NAME_X + w.pos + w.rwho + w.spec + w.rtime + STORY_MIN + w.deaths + w.date + GAP * 6 + INSET
        -- Wider than the window, the tables scroll sideways rather than squeezing the names
        local width = math_max(view, math_max(boardNeed, rankNeed) + PAD_LEFT + PAD_RIGHT)
        content:SetWidth(width)

        for _, t in ipairs(sections) do LayoutSection(t, w) end

        local y = PAD_TOP
        if any then
            shown:ClearAllPoints()
            shown:SetPoint("TOPLEFT", content, "TOPLEFT", PAD_LEFT, -y)
            shown:SetPoint("RIGHT", content, "RIGHT", -PAD_RIGHT, 0)
            y = y + SUMMARY_H + HINT_GAP
        end
        hints:ClearAllPoints()
        hints:SetPoint("TOPLEFT", content, "TOPLEFT", PAD_LEFT, -y)
        hints:SetPoint("TOPRIGHT", content, "TOPRIGHT", -PAD_RIGHT, -y)
        y = y + hints:Measure()
        if any then
            y = y + FILTER_GAP
            filters:ClearAllPoints()
            filters:SetPoint("TOPLEFT", content, "TOPLEFT", PAD_LEFT, -y)
            filters:SetPoint("TOPRIGHT", content, "TOPRIGHT", -PAD_RIGHT, -y)
            y = y + filters:GetHeight()
        end
        y = y + INTRO_GAP
        for i, t in ipairs(sections) do
            if i > 1 then y = y + GROUP_GAP end
            t.card:ClearAllPoints()
            t.card:SetPoint("TOPLEFT", content, "TOPLEFT", PAD_LEFT, -y)
            t.card:SetPoint("TOPRIGHT", content, "TOPRIGHT", -PAD_RIGHT, -y)
            t.card:Layout()
            y = y + t.card:GetHeight()
        end
        area:SetContentSize(width, y + PAD_BOTTOM)
    end
    v.relayout = function() Render(false) end

    function E.RefreshLeaderboardTab()
        if frame:IsVisible() then Render(true) end
    end

    -- Wrapped text measured before its first draw can come up short, so the page is measured again a frame later
    local pending = false
    local function RenderSoon()
        if pending then return end
        pending = true
        C_Timer.After(0, function()
            pending = false
            if frame:IsVisible() then Render() end
        end)
    end

    area.scroll:HookScript("OnSizeChanged", function(_, w)
        if frame:IsVisible() and math_abs((w or 0) - lastWidth) >= 1 then
            Render()
            RenderSoon()
        end
    end)

    frame:SetScript("OnShow", function()
        Render(true)
        area:ScrollTo(0, 0)
        RenderSoon()
    end)

    E:RegisterTab(10, frame)
end)
