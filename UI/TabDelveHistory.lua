local E = EverythingDelves
local L = E.L

local pairs, ipairs, tostring = pairs, ipairs, tostring
local math_abs, math_ceil, math_floor, math_max = math.abs, math.ceil, math.floor, math.max
local string_format = string.format
local table_sort, table_insert = table.sort, table.insert
local date = date

local PAD_TOP, PAD_LEFT, PAD_RIGHT, PAD_BOTTOM, GROUP_GAP, INTRO_GAP = 20, 24, 14, 28, 22, 16
local HEAD, DELVE_ROW, RUN_ROW, EMPTY_ROW, HINT_GAP = 28, 32, 28, 44, 8
local INSET, CHEVRON, GAP, RUN_GAP, ICON, BUTTON = 14, 12, 10, 8, 14, 24
local NAME_X = INSET + CHEVRON + GAP
local TIER_W, TIME_W, DEATHS_W, BOSS_W, DATE_W, STORY_MIN, NAME_MIN = 30, 60, 90, 140, 116, 100, 150
local CHAMBERS_W, KEYS_W, KINDO_W, SPLITS_MIN = 30, 30, 72, 150
local NOTE_X, NOTE_PAD, NOTE_SIZE = 50, 6, 12
local NOTE_MAX = 280
local EDITOR_W, EDITOR_H, EDITOR_PAD, FIELD_H, FOOTER_H = 440, 304, 20, 110, 56
local ED_TEXTURES = "Interface\\AddOns\\EverythingDelves\\Media\\Textures\\"
local BOUNTIFUL_ATLAS = "delves-bountiful"
local QUOTE_OPEN, QUOTE_CLOSE, BULLET = "\226\128\156", "\226\128\157", "\226\128\162"

local STATS = {
    { key = "deaths",  label = L["Total Deaths:"], width = 84 },
    { key = "fastest", label = L["Fastest:"],      width = 72 },
    { key = "avg",     label = L["Avg:"],          width = 64 },
    { key = "best",    label = L["Best Tier:"],    width = 76 },
    { key = "runs",    label = L["Runs:"],         width = 64 },
}

-- A Labyrinth run can stop at any chamber, so an average or fastest over all of them compares unlike runs
local LAB_STATS = {
    { key = "kindo",    label = L["Kindo'jan"],  width = 84 },
    { key = "full",     label = L["Full clear"], width = 72 },
    { key = "chambers", label = L["Chambers"],   width = 64 },
    { key = "best",     label = L["Best Tier:"], width = 76 },
    { key = "runs",     label = L["Runs:"],      width = 64 },
}

local function FormatDuration(sec)
    sec = sec or 0
    if sec <= 0 then return "--" end
    if sec < 60 then
        return string_format("%ds", sec)
    end
    if sec < 3600 then
        local m = math_floor(sec / 60)
        local s = sec - m * 60
        return string_format("%dm %02ds", m, s)
    end
    local h = math_floor(sec / 3600)
    local m = math_floor((sec % 3600) / 60)
    local s = sec % 60
    return string_format("%dh %dm %02ds", h, m, s)
end

local function FormatDay(ts)
    if not ts or ts == 0 then return "" end
    return date("%Y-%m-%d", ts)
end

local function FormatStamp(ts)
    if not ts or ts == 0 then return "" end
    return date("%Y-%m-%d %H:%M", ts)
end

-- Prefer the live variant captured at log time; fall back to the delve's
-- signature story. nil when neither is known (e.g. Nemesis has no signature).
local function ResolveRunStory(run, delveKey)
    if run and run.story and run.story ~= "" then
        return E.StripColorEscapes(run.story)
    end
    return E.DelveStories and E.DelveStories[delveKey] or nil
end

-- The headings are the old "Runs:" phrases, drawn without their colon (a full-width one in Chinese)
local function NoColon(s)
    return (s:gsub("%s*:%s*$", ""):gsub("%s*\239\188\154%s*$", ""))
end

local function Stats(life)
    local timed = life.timedRuns or life.totalRuns or 0
    local avg = timed > 0 and math_floor((life.totalDuration or 0) / timed) or 0
    return { runs = tostring(life.totalRuns or 0), best = "T" .. (life.highestTier or 0), avg = FormatDuration(avg),
             fastest = FormatDuration(life.fastestTime), deaths = string_format("%d", life.totalDeaths or 0) }
end

local function LabStats(life)
    return { runs = tostring(life.totalRuns or 0), best = "T" .. (life.highestTier or 0),
             chambers = string_format("%d", life.chambers or 0), full = FormatDuration(life.fullClear),
             kindo = string_format("%d", life.kindoKills or 0) }
end

local function Collect(v)
    local history = E.db and E.db.delveHistory or nil
    v.history = history
    v.nemesisKeys, v.labyrinthKeys, v.midnightKeys = {}, {}, {}
    local runs, deaths, dur = 0, 0, 0
    if history then
        local nameMap = E.LoggableDelveNames
        for name, entry in pairs(history) do
            local life = entry and entry.lifetime
            if life then
                runs = runs + (life.totalRuns or 0)
                deaths = deaths + (life.totalDeaths or 0)
                dur = dur + (life.totalDuration or 0)
                if (life.totalRuns or 0) > 0 then
                    local kind = nameMap and nameMap[name]
                    if kind == "nemesis" then
                        table_insert(v.nemesisKeys, name)
                    elseif kind == "labyrinth" then
                        table_insert(v.labyrinthKeys, name)
                    elseif kind == "regular" then
                        table_insert(v.midnightKeys, name)
                    end
                end
            end
        end
    end
    table_sort(v.nemesisKeys)
    table_sort(v.midnightKeys)
    -- Its colors arrive as arguments, so empty ones leave the plain text
    v.summary = L["%sTotal Runs:%s %s%d%s   %s||%s   %sTotal Deaths:%s %s%d%s   %s||%s   %sTotal Time:%s %s%s%s"]
        :format("", "", "", runs, "", "", "", "", "", "", deaths, "", "", "", "", "", "", FormatDuration(dur), "")
end

local function NiceName(key, nemesis, labyrinth)
    if labyrinth then return E.LabyrinthDisplayName() end
    if not nemesis then return key end
    local nem = E.NemesisDelve
    local boss = (E.NemesisBossByDelve and E.NemesisBossByDelve[key]) or (nem and nem.boss)
    return boss and (key .. " (" .. boss .. ")") or key
end

local function MouseIcon(ui, parent, title, body)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(ICON, ICON)
    f.tex = f:CreateTexture(nil, "ARTWORK")
    f.tex:SetAllPoints()
    f:EnableMouse(true)
    f:SetScript("OnEnter", function(self) ui:ShowTooltip(self, title, body) end)
    f:SetScript("OnLeave", function() ui:HideTooltip() end)
    return f
end

local function BuildIntro(ui, content, v)
    local b = ui:CreateTextBlock(content)
    v.summaryLine = b:AddLine("", "label")
    b:AddLine(L["Note: Closing the WoW client during a delve will reset that run's timer. /reload is fine."], "hint",
        { gap = HINT_GAP })
    v.intro = b
end

local function NewSection(ui, content, label, emptyText, kind)
    local card = ui:CreateGroup(content, label)
    local t = CreateFrame("Frame", nil, content)
    t.nemesis, t.labyrinth = kind == "nemesis", kind == "labyrinth"
    t.stats = t.labyrinth and LAB_STATS or STATS
    t.head = CreateFrame("Frame", nil, t)
    t.head:SetHeight(HEAD)
    t.head.name = ui:CreateText(t.head, L["Delve Name"], "groupLabel")
    t.head.name:SetPoint("LEFT", t.head, "LEFT", NAME_X, 0)
    t.head.cells = {}
    for _, s in ipairs(t.stats) do
        local fs = ui:CreateText(t.head, NoColon(s.label), "groupLabel")
        fs:SetWordWrap(false)
        fs:SetJustifyH("RIGHT")
        t.head.cells[s.key] = fs
    end
    t.empty = ui:CreateText(t, emptyText, "label")
    t.empty:SetTextColor(ui:Color("muted"))
    t.empty:SetWordWrap(false)
    t.rows, t.runs, t.notes = {}, {}, {}
    card:Add(t, { height = EMPTY_ROW, fill = true })
    t.card = card
    return t
end

local function NewDelveRow(ui, t, v)
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
    r.name = ui:CreateText(r, "", "value")
    r.name:SetWordWrap(false)
    r.cells = {}
    for _, s in ipairs(t.stats) do
        local fs = ui:CreateText(r, "", "label")
        fs:SetWordWrap(false)
        fs:SetJustifyH("RIGHT")
        r.cells[s.key] = fs
    end
    r:SetScript("OnClick", function(self)
        v.open[self.key] = not v.open[self.key]
        v.relayout()
    end)
    r:SetScript("OnEnter", function(self) ui:ShowTooltip(self, self.nice, self.tip) end)
    r:SetScript("OnLeave", function() ui:HideTooltip() end)
    return r
end

local function AddRunButtons(ui, r, v)
    r.del = ui:CreateIconButton(r, "close", BUTTON)
    r.del:SetPoint("RIGHT", r, "RIGHT", -INSET, 0)
    r.note = E.DelveList.IconButton(r, ED_TEXTURES .. "icon-note")
    r.note:SetPoint("RIGHT", r.del, "LEFT", -RUN_GAP, 0)
    r.date = ui:CreateText(r, "", "label")
    r.date:SetTextColor(ui:Color("muted"))
    r.date:SetWordWrap(false)
    r.date:SetWidth(DATE_W)
    r.date:SetPoint("RIGHT", r.note, "LEFT", -RUN_GAP, 0)

    r.note:SetScript("OnClick", function(self)
        local row = self:GetParent()
        if row.run then v.openNote(row.delveKey, row.run, row.nice) end
    end)
    r.note:SetScript("OnEnter", function(self)
        local note = self:GetParent().run and self:GetParent().run.note
        if note and note ~= "" then
            ui:ShowTooltip(self, L["Run Note"], note)
        else
            ui:ShowTooltip(self, L["Add a Note"], L["Click to attach a free-form note to this run."])
        end
    end)
    r.note:SetScript("OnLeave", function() ui:HideTooltip() end)
    r.del:SetScript("OnClick", function(self) v.deleteRun(self:GetParent()) end)
    r.del:SetScript("OnEnter", function(self)
        ui:ShowTooltip(self, L["Delete Run"], L["Permanently remove this run and its\ncontribution to lifetime stats."])
    end)
    r.del:SetScript("OnLeave", function() ui:HideTooltip() end)
end

local function NewRunRow(ui, t, v)
    local r = CreateFrame("Frame", nil, t)
    r:SetHeight(RUN_ROW)
    ui:Paint(r, "input", "divider", "T")

    r.bount = MouseIcon(ui, r, L["Bountiful"], L["This run was in a Bountiful Delve."])
    if r.bount.tex.SetAtlas then r.bount.tex:SetAtlas(BOUNTIFUL_ATLAS) end
    r.bount:SetPoint("LEFT", r, "LEFT", NAME_X, 0)
    local x = NAME_X + ICON + RUN_GAP
    local function cell(w)
        local fs = ui:CreateText(r, "", "label")
        fs:SetWordWrap(false)
        fs:SetPoint("LEFT", r, "LEFT", x, 0)
        fs:SetWidth(w)
        x = x + w + RUN_GAP
        return fs
    end
    r.tier = cell(TIER_W)
    r.time = cell(TIME_W)
    r.deaths = cell(DEATHS_W)
    r.key = MouseIcon(ui, r, L["Key"], nil)
    r.key.tex:SetTexture(ED_TEXTURES .. "icon-key")
    r.key.tex:SetVertexColor(ui:Color("label"))
    r.key:SetPoint("LEFT", r, "LEFT", x, 0)
    x = x + ICON + RUN_GAP

    AddRunButtons(ui, r, v)
    r.boss = ui:CreateText(r, "", "label")
    r.boss:SetWordWrap(false)
    r.boss:SetWidth(BOSS_W)
    r.boss:SetPoint("RIGHT", r.date, "LEFT", -RUN_GAP, 0)
    r.story = ui:CreateText(r, "", "label")
    r.story:SetWordWrap(false)
    r.story:SetPoint("LEFT", r, "LEFT", x, 0)
    r.story:SetPoint("RIGHT", r.boss, "LEFT", -RUN_GAP, 0)
    return r
end

local function NewLabRunRow(ui, t, v)
    local r = CreateFrame("Frame", nil, t)
    r:SetHeight(RUN_ROW)
    ui:Paint(r, "input", "divider", "T")
    r:EnableMouse(true)
    r:SetScript("OnEnter", function(self) ui:ShowTooltip(self, self.tipTitle, self.tipBody) end)
    r:SetScript("OnLeave", function() ui:HideTooltip() end)
    local x = NAME_X
    local function cell(w)
        local fs = ui:CreateText(r, "", "label")
        fs:SetWordWrap(false)
        fs:SetPoint("LEFT", r, "LEFT", x, 0)
        fs:SetWidth(w)
        x = x + w + RUN_GAP
        return fs
    end
    r.chambers = cell(CHAMBERS_W)
    r.tier = cell(TIER_W)
    r.time = cell(TIME_W)
    r.deaths = cell(DEATHS_W)
    r.key = MouseIcon(ui, r, L["Key"], nil)
    r.key.tex:SetTexture(ED_TEXTURES .. "icon-key")
    r.key.tex:SetVertexColor(ui:Color("label"))
    r.key:SetPoint("LEFT", r, "LEFT", x, 0)
    r.keys = ui:CreateText(r, "", "label")
    r.keys:SetPoint("LEFT", r.key, "RIGHT", 2, 0)
    x = x + KEYS_W + RUN_GAP

    AddRunButtons(ui, r, v)
    r.kindoCell = CreateFrame("Frame", nil, r)
    r.kindoCell:SetSize(KINDO_W, RUN_ROW)
    r.kindoCell:SetPoint("RIGHT", r.date, "LEFT", -RUN_GAP, 0)
    r.kindoIcon = r.kindoCell:CreateTexture(nil, "ARTWORK")
    r.kindoIcon:SetSize(ICON, ICON)
    r.kindoIcon:SetPoint("LEFT", r.kindoCell, "LEFT", 0, 0)
    r.kindoIcon:SetTexture(ED_TEXTURES .. "icon-nemesis")
    r.kindoIcon:SetVertexColor(ui:Color("muted"))
    r.kindo = ui:CreateText(r.kindoCell, "", "label")
    r.kindo:SetWordWrap(false)
    r.splits = ui:CreateText(r, "", "label")
    r.splits:SetWordWrap(false)
    r.splits:SetPoint("LEFT", r, "LEFT", x, 0)
    r.splits:SetPoint("RIGHT", r.kindoCell, "LEFT", -RUN_GAP, 0)
    return r
end

-- A note can be typed in any alphabet, so it is drawn in the client's own font
local function NewNoteLine(ui, t)
    local f = CreateFrame("Frame", nil, t)
    ui:Paint(f, "input")
    f.text = f:CreateFontString(nil, "OVERLAY")
    f.text:SetFontObject(GameFontHighlight)
    f.text:SetTextColor(ui:Color("muted"))
    f.text:SetJustifyH("LEFT")
    f.text:SetWordWrap(true)
    f.text:SetPoint("TOPLEFT", f, "TOPLEFT", NOTE_X, 0)
    return f
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

-- Spans the whole card, past the card's own inset, so each row's tint and divider reach both edges
local function Place(item, t, y)
    item:SetPoint("TOPLEFT", t, "TOPLEFT", -INSET, -y)
    item:SetPoint("TOPRIGHT", t, "TOPRIGHT", INSET, -y)
end

local function PlaceStats(row, cells, widths, stats)
    local right = INSET
    for i, s in ipairs(stats) do
        local fs = cells[s.key]
        fs:ClearAllPoints()
        fs:SetPoint("RIGHT", row, "RIGHT", -right, 0)
        fs:SetWidth(widths[i])
        right = right + widths[i] + GAP
    end
    return right
end

local function FillDateAndNote(ui, r, run)
    r.date:SetText(FormatStamp(run.timestamp))
    local hasNote = run.note ~= nil and run.note ~= ""
    r.note:GetNormalTexture():SetVertexColor(ui:Color(hasNote and "text" or "navText"))
end

local function FillRun(ui, r, run, key)
    r.run, r.delveKey = run, key
    r.bount:SetShown(run.wasBountiful and true or false)
    r.tier:SetText("T" .. (run.tier or 0))
    r.time:SetText(FormatDuration(run.duration))
    r.deaths:SetText(E.DelveList.cc("muted") .. L["Deaths:"] .. "|r " .. string_format("%d", run.deaths or 0))
    r.key:SetShown(run.keyUsed and true or false)
    local story = ResolveRunStory(run, key)
    r.story:SetText(story or "--")
    r.story:SetTextColor(ui:Color(story and "label" or "muted"))
    -- Map legacy live encounter names (e.g. "Spinshroom" -> "Gyrospore").
    local boss = run.boss and E:NormalizeLiveBoss(key, run.boss)
    r.boss:SetText(boss or "")
    FillDateAndNote(ui, r, run)
end

-- Times are a run's clock at each checkpoint, so a run that began partway has none that compare
local function LabSplits(run)
    if run.prior or type(run.at) ~= "table" then return nil end
    local parts = {}
    for mark = E.Labyrinth.checkpointEvery, E.Labyrinth.chambers, E.Labyrinth.checkpointEvery do
        if run.at[mark] then
            parts[#parts + 1] = E.DelveList.cc("muted") .. mark .. "|r " .. E:FormatClock(run.at[mark])
        end
    end
    return #parts > 0 and table.concat(parts, "   ") or nil
end

local function LabTip(run)
    local lines = {}
    for i, room in ipairs(run.rooms or {}) do
        lines[#lines + 1] = i .. ".  " .. (room.t or "--") .. (room.b and ("  (" .. room.b .. ")") or "") .. "   " .. FormatDuration(room.d)
    end
    local keys = run.keys or (run.keyUsed and 1 or 0)
    local extra = {}
    if run.kindo then extra[#extra + 1] = L["Kindo'jan:"] .. " " .. FormatDuration(run.kindo) end
    if run.left then extra[#extra + 1] = L["left early"] end
    if keys > 0 then extra[#extra + 1] = L["Keys used:"] .. " " .. string_format("%d", keys) end
    if #extra > 0 then
        if #lines > 0 then lines[#lines + 1] = " " end
        for _, line in ipairs(extra) do lines[#lines + 1] = line end
    end
    return "T" .. (run.tier or 0) .. "  " .. BULLET .. "  " .. FormatStamp(run.timestamp), table.concat(lines, "\n")
end

local function FillLabRun(ui, r, run, key)
    r.run, r.delveKey = run, key
    local total = (run.ch or 0) + (run.prior or 0)
    r.chambers:SetText(string_format("%d/%d", total, E.Labyrinth.chambers))
    r.chambers:SetTextColor(ui:Color(total >= E.Labyrinth.chambers and "text" or "label"))
    r.tier:SetText("T" .. (run.tier or 0))
    r.time:SetText(FormatDuration(run.duration))
    r.deaths:SetText(E.DelveList.cc("muted") .. L["Deaths:"] .. "|r " .. string_format("%d", run.deaths or 0))
    local keys = run.keys or (run.keyUsed and 1 or 0)
    r.key:SetShown(keys > 0)
    r.keys:SetText(keys > 0 and string_format("%d", keys) or "")
    local splits = LabSplits(run)
    r.splits:SetText(splits or "--")
    r.splits:SetTextColor(ui:Color(splits and "label" or "muted"))
    r.kindo:ClearAllPoints()
    r.kindoIcon:SetShown(run.kindo ~= nil)
    if run.kindo then
        r.kindo:SetPoint("LEFT", r.kindoIcon, "RIGHT", 4, 0)
        r.kindo:SetText(FormatDuration(run.kindo))
        r.kindo:SetTextColor(ui:Color("label"))
        r.kindoCell:SetWidth(KINDO_W)
    else
        r.kindo:SetPoint("LEFT", r.kindoCell, "LEFT", 0, 0)
        r.kindo:SetText(run.left and L["left early"] or "")
        r.kindo:SetTextColor(ui:Color("muted"))
        -- A longer translation widens the cell into the checkpoint times rather than over the date
        r.kindoCell:SetWidth(math_max(KINDO_W, math_ceil(r.kindo:GetStringWidth() or 0)))
    end
    FillDateAndNote(ui, r, run)
    r.tipTitle, r.tipBody = LabTip(run)
end

local function LayoutSection(ui, v, t, keys, widths, cardW)
    for _, pool in ipairs({ t.rows, t.runs, t.notes }) do
        for _, item in ipairs(pool) do item:Hide() end
    end
    t.head:SetShown(#keys > 0)
    t.empty:SetShown(#keys == 0)
    local y
    if #keys == 0 then
        t.empty:ClearAllPoints()
        t.empty:SetPoint("LEFT", t, "TOPLEFT", 0, -EMPTY_ROW / 2)
        y = EMPTY_ROW
    else
        t.head:ClearAllPoints()
        Place(t.head, t, 0)
        local used = PlaceStats(t.head, t.head.cells, widths, t.stats)
        y = HEAD
        local nRows, nRuns, nNotes = 0, 0, 0
        local makeRun = t.labyrinth and NewLabRunRow or NewRunRow
        local fillRun = t.labyrinth and FillLabRun or FillRun
        for _, key in ipairs(keys) do
            local entry = v.history[key]
            local life = entry.lifetime
            nRows = nRows + 1
            local r = Acquire(t.rows, nRows, function() return NewDelveRow(ui, t, v) end)
            Place(r, t, y)
            r.key, r.nice = key, NiceName(key, t.nemesis, t.labyrinth)
            local open = v.open[key] == true
            r.chevron:SetTexture(ui:Texture(open and "chevron-down" or "chevron-right"))
            r.name:SetText(r.nice)
            r.name:ClearAllPoints()
            r.name:SetPoint("LEFT", r, "LEFT", NAME_X, 0)
            r.name:SetPoint("RIGHT", r, "RIGHT", -used, 0)
            local stats = (t.labyrinth and LabStats or Stats)(life)
            PlaceStats(r, r.cells, widths, t.stats)
            for _, s in ipairs(t.stats) do r.cells[s.key]:SetText(stats[s.key]) end
            local latest = entry.recentRuns and entry.recentRuns[1]
            local tip = latest and L["Latest: %s on %s"]:format(FormatDuration(latest.duration), FormatDay(latest.timestamp)) or ""
            if (life.totalKeysUsed or 0) > 0 then
                tip = tip .. (tip ~= "" and "\n" or "") .. L["Keys used:"] .. " " .. string_format("%d", life.totalKeysUsed)
            end
            r.tip = tip
            y = y + DELVE_ROW
            if open then
                for _, run in ipairs(entry.recentRuns or {}) do
                    nRuns = nRuns + 1
                    local rr = Acquire(t.runs, nRuns, function() return makeRun(ui, t, v) end)
                    Place(rr, t, y)
                    rr.nice = r.nice
                    fillRun(ui, rr, run, key)
                    y = y + RUN_ROW
                    if run.note and run.note ~= "" then
                        nNotes = nNotes + 1
                        local nl = Acquire(t.notes, nNotes, function() return NewNoteLine(ui, t) end)
                        Place(nl, t, y)
                        local h = E.DelveList.WrapHeight(nl.text, QUOTE_OPEN .. run.note .. QUOTE_CLOSE,
                            math_max(40, cardW - NOTE_X - INSET), NOTE_SIZE) + NOTE_PAD
                        nl:SetHeight(h)
                        y = y + h
                    end
                end
            end
        end
    end
    t:SetHeight(y)
    t._euiRow:SetHeight(y)
end

local function BuildEditor(ui, v)
    local f = ui:CreateWindow({ name = "EverythingDelvesRunNote", title = L["Run Note"], width = EDITOR_W, height = EDITOR_H })
    f.context = ui:CreateText(f.body, "", "hint")
    f.context:SetPoint("TOPLEFT", f.body, "TOPLEFT", EDITOR_PAD, -16)
    f.field = ui:CreateMultilineField(f.body)
    f.field:SetPoint("TOPLEFT", f.body, "TOPLEFT", EDITOR_PAD, -40)
    f.field:SetPoint("TOPRIGHT", f.body, "TOPRIGHT", -EDITOR_PAD, -40)
    f.field:SetHeight(FIELD_H)
    f.field.box:SetMaxLetters(NOTE_MAX)
    f.count = ui:CreateText(f.body, "", "hint")
    f.count:SetPoint("TOPRIGHT", f.field, "BOTTOMRIGHT", 0, -6)
    f.field.box:HookScript("OnTextChanged", function(box) f.count:SetText(box:GetNumLetters() .. " / " .. NOTE_MAX) end)
    -- The box holds the keyboard, so Escape there would only let go of it. It cancels the note instead
    f.field.box:HookScript("OnEscapePressed", function() f:Hide() end)

    local footer = CreateFrame("Frame", nil, f.body)
    footer:SetPoint("BOTTOMLEFT")
    footer:SetPoint("BOTTOMRIGHT")
    footer:SetHeight(FOOTER_H)
    footer._controls = {}
    ui:Paint(footer, "chrome", "divider", "T")

    local function save(text)
        if f.delveKey and f.timestamp then E:SetRunNote(f.delveKey, f.timestamp, text) end
        f:Hide()
        v.relayout()
    end
    f.delete = ui:CreateButton(footer, L["Delete Note"], nil, function() save("") end, L["Removes this run's note."], "danger")
    f.delete:SetPoint("LEFT", footer, "LEFT", EDITOR_PAD, 0)
    f.save = ui:CreateButton(footer, L["Save"], nil, function() save(f.field:GetText()) end, nil, "primary")
    f.save:SetPoint("RIGHT", footer, "RIGHT", -EDITOR_PAD, 0)
    f.cancel = ui:CreateButton(footer, L["Cancel"], nil, function() f:Hide() end)
    f.cancel:SetPoint("RIGHT", f.save, "LEFT", -ui:Spacing("buttonGap"), 0)
    v.editor = f
    return f
end

local function OpenNoteEditor(ui, v, delveKey, run, nice)
    if not (delveKey and run) then return end
    local f = v.editor or BuildEditor(ui, v)
    f.delveKey, f.timestamp = delveKey, run.timestamp
    f:SetSection(nice or delveKey)
    f.context:SetText("T" .. (run.tier or 0) .. "  " .. BULLET .. "  " .. FormatStamp(run.timestamp))
    f.delete:SetShown(run.note ~= nil and run.note ~= "")
    f:Show()
    f:Raise()
    for _, b in ipairs({ f.delete, f.save, f.cancel }) do b:Fit() end
    f.field:SetText(run.note or "")
    f.field.box:SetCursorPosition(#(run.note or ""))
    f.field.box:SetFocus()
end

local function CloseOrphanEditor(v)
    local f = v.editor
    if not (f and f:IsShown()) then return end
    local entry = E.db and E.db.delveHistory and E.db.delveHistory[f.delveKey]
    for _, run in ipairs(entry and entry.recentRuns or {}) do
        if run.timestamp == f.timestamp then return end
    end
    f:Hide()
end

local function ConfirmDeleteRun(v, row)
    local run = row and row.run
    if not (run and run.timestamp) then return end
    local key, timestamp = row.delveKey, run.timestamp
    E:ShowDialog({
        text = L["Delete this %s run?\n\n%s\n\nIts time, deaths, and key usage are removed from the delve's lifetime stats. This cannot be undone."]
            :format(row.nice or key, "T" .. (run.tier or 0) .. "  -  " .. FormatStamp(timestamp)),
        button1 = L["Delete"], button2 = L["Cancel"], danger = true,
        onAccept = function()
            if E:DeleteRun(key, timestamp) then
                CloseOrphanEditor(v)
                v.relayout()
            end
        end,
    })
end

E:RegisterModule(function()
    local ui = E.ui
    local frame = CreateFrame("Frame", "EverythingDelvesTabHistoryContent")
    local area = ui:CreateScrollArea(frame, { clearGrip = true })
    area:SetAllPoints(frame)
    local content = area.content

    local v = { open = {} }
    BuildIntro(ui, content, v)
    local nemesis = NewSection(ui, content, L["Seasonal Nemesis"], L["No nemesis delve runs recorded yet."], "nemesis")
    local labyrinth = NewSection(ui, content, E.LabyrinthDisplayName(), L["No Labyrinth runs recorded yet."], "labyrinth")
    local midnight = NewSection(ui, content, L["Midnight Delves"],
        L["No Midnight delve runs recorded yet. Complete a delve to start tracking!"], "regular")
    local cards = { nemesis.card, labyrinth.card, midnight.card }

    local lastWidth = 0
    local function ViewWidth()
        local w = area.scroll:GetWidth() or 0
        if w <= 0 then w = (frame:GetWidth() or 0) - 10 end
        return math_max(1, w)
    end

    local function Render()
        Collect(v)
        local view = ViewWidth()
        lastWidth = view
        v.summaryLine:SetText(v.summary)

        local function Measure(t)
            local widths, used = {}, 0
            for i, s in ipairs(t.stats) do
                local fs = t.head.cells[s.key]
                fs:SetWidth(0)
                widths[i] = math_max(s.width, math_ceil(fs:GetStringWidth() or 0) + 1)
                used = used + widths[i] + GAP
            end
            return widths, used
        end
        local widths, used = Measure(nemesis)
        local labWidths, labUsed = Measure(labyrinth)
        -- A run row needs its fixed columns and some story. Narrower than that, the page scrolls sideways
        local runNeed = NAME_X + ICON + TIER_W + TIME_W + DEATHS_W + ICON + RUN_GAP * 5 + STORY_MIN
            + RUN_GAP * 4 + BOSS_W + DATE_W + BUTTON * 2 + INSET
        local labRunNeed = NAME_X + CHAMBERS_W + TIER_W + TIME_W + DEATHS_W + KEYS_W + RUN_GAP * 5 + SPLITS_MIN
            + RUN_GAP * 4 + KINDO_W + DATE_W + BUTTON * 2 + INSET
        local delveNeed = NAME_X + NAME_MIN + math_max(used, labUsed) + INSET
        local width = math_max(view, math_max(runNeed, labRunNeed, delveNeed) + PAD_LEFT + PAD_RIGHT)
        content:SetWidth(width)
        local cardW = width - PAD_LEFT - PAD_RIGHT

        LayoutSection(ui, v, nemesis, v.nemesisKeys, widths, cardW)
        LayoutSection(ui, v, labyrinth, v.labyrinthKeys, labWidths, cardW)
        LayoutSection(ui, v, midnight, v.midnightKeys, widths, cardW)

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
    v.relayout = Render
    v.openNote = function(key, run, nice) OpenNoteEditor(ui, v, key, run, nice) end
    v.deleteRun = function(row) ConfirmDeleteRun(v, row) end

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

    function E.RefreshDelveHistoryTab()
        CloseOrphanEditor(v)
        if frame:IsVisible() then Render() end
    end

    frame:SetScript("OnShow", function()
        Render()
        area:ScrollTo(0, 0)
        RenderSoon()
    end)

    E:RegisterTab(6, frame)
end)
