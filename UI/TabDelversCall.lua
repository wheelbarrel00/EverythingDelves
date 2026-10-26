local E = EverythingDelves
local L = E.L

local ipairs, pairs, select, time = ipairs, pairs, select, time
local math_abs, math_max = math.abs, math.max
local table_sort = table.sort

local PAD_TOP, PAD_LEFT, PAD_RIGHT, PAD_BOTTOM, GROUP_GAP, INTRO_GAP = 20, 24, 14, 28, 22, 16
local ROW, LIST_ROW, HINT_GAP, COL_GAP, NAME_GAP = 44, 28, 8, 12, 6
local ZONE_W, STATUS_W, COUNT_W, CHECK, CHECK_GAP = 160, 150, 90, 14, 6

local STATE_LABEL = {
    fresh      = L["Available"],
    inProgress = L["In Progress"],
    ready      = L["Banked"],
    completed  = L["Turned In"],
}
local ROLLUP = { "inProgress", "ready", "completed", "fresh" }

local function GetState(questID)
    if not questID or not C_QuestLog then return "fresh" end
    if C_QuestLog.IsQuestFlaggedCompleted
            and C_QuestLog.IsQuestFlaggedCompleted(questID) then
        return "completed"
    end
    local logIdx = C_QuestLog.GetLogIndexForQuestID
        and C_QuestLog.GetLogIndexForQuestID(questID)
    if logIdx then
        -- pcall both turn-in APIs: their signatures have shifted across patches.
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

-- Alts' quest logs aren't readable, so each character snapshots its own states here.
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

local function StripCodes(s)
    return (s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
end

-- A card centers a control in its row but never sizes it, and a row frame left with no height came up blank
-- after a cold login
local function Row(content, height)
    local f = CreateFrame("Frame", nil, content)
    if height then f:SetHeight(height) end
    return f
end

local function Check(ui, parent)
    local t = parent:CreateTexture(nil, "ARTWORK")
    t:SetSize(CHECK, CHECK)
    t:SetTexture(ui:Texture("check"))
    t:SetVertexColor(ui:Color("label"))
    return t
end

local function CallColumns(row, name, zone, status)
    status:SetPoint("LEFT", row, "RIGHT", -STATUS_W, 0)
    zone:SetPoint("LEFT", row, "RIGHT", -(STATUS_W + COL_GAP + ZONE_W), 0)
    zone:SetWidth(ZONE_W)
    name:SetPoint("LEFT")
    name:SetPoint("RIGHT", row, "RIGHT", -(STATUS_W + COL_GAP * 2 + ZONE_W), 0)
end

local function CountCells(ui, row, style)
    local cells = {}
    for i = #ROLLUP, 1, -1 do
        local fs = ui:CreateText(row, "", style)
        fs:SetWordWrap(false)
        fs:SetJustifyH("RIGHT")
        fs:SetWidth(COUNT_W)
        fs:SetPoint("RIGHT", row, "RIGHT", -(#ROLLUP - i) * (COUNT_W + COL_GAP), 0)
        cells[i] = fs
    end
    return cells
end

local COUNTS_W = #ROLLUP * COUNT_W + #ROLLUP * COL_GAP

local function BuildIntro(ui, content, v)
    local b = ui:CreateTextBlock(content)
    v.summary = b:AddLine("", "label")
    b:AddLine(L["World Tour weekly quest tracker"], "hint", { gap = HINT_GAP })
    v.intro = b
end

local function BuildStrategy(ui, content)
    local card = ui:CreateGroup(content, nil)
    local b = ui:CreateTextBlock(content)
    -- One string cannot change weight partway through a wrapped line, so the warning stands out by color
    local warn = E.DelveList.cc("text") .. L["don't turn it in yet"] .. "|r"
    b:AddLine(L["Each rotational delve has a Delver's Call quest. Run every delve once to pick the quest up, but %s \226\128\148 the XP scales to your level at turn-in. Bank all %d, then cash them in once you're a few levels short of cap for a push through the final levels."]
        :format(warn, #E.DelversCall))
    card:Add(b, { fitHeight = true })
    return card
end

local function StatusCell(ui, row)
    local cell = CreateFrame("Frame", nil, row)
    cell:SetSize(STATUS_W, LIST_ROW)
    cell.check = Check(ui, cell)
    cell.check:SetPoint("LEFT")
    cell.text = ui:CreateText(cell, "", "label")
    cell.text:SetWordWrap(false)
    cell.tag = ui:CreateTag(cell, STATE_LABEL.ready, "outline")
    cell.tag:SetPoint("LEFT")
    return cell
end

local function BuildCalls(ui, content, v)
    local card = ui:CreateGroup(content, L["Delver's Call"])

    local zoneOf = {}
    for _, d in ipairs(E.DelveData or {}) do
        if d.name and d.zone and not zoneOf[d.name] then zoneOf[d.name] = d.zone end
    end

    local head = Row(content, LIST_ROW)
    CallColumns(head, ui:CreateText(head, L["Delve"], "groupLabel"), ui:CreateText(head, L["Zone"], "groupLabel"),
        ui:CreateText(head, L["Status"], "groupLabel"))
    card:Add(head, { height = LIST_ROW, fill = true })

    v.calls = {}
    for i, entry in ipairs(E.DelversCall) do
        local row = Row(content, LIST_ROW)
        row.entry = entry
        row.name = ui:CreateText(row, entry.delve, "label")
        row.name:SetWordWrap(false)
        row.zone = ui:CreateText(row, zoneOf[entry.delve] or "", "label")
        row.zone:SetWordWrap(false)
        row.status = StatusCell(ui, row)
        CallColumns(row, row.name, row.zone, row.status)
        card:Add(row, { height = LIST_ROW, fill = true })
        v.calls[i] = row
    end

    local holder = Row(content, ROW)
    holder._controls = {}
    local box = ui:CreateCheckbox(holder,
        L["Show a green checkmark on the Delve Locations tab for delves whose Delver's Call you've turned in"],
        function() return E.db and E.db.showDelversCallDone == true end,
        function(on)
            if E.db then E.db.showDelversCallDone = on end
            if E.RefreshDelveLocations then E:RefreshDelveLocations() end
        end)
    box:SetPoint("LEFT")
    -- Long in every language, so it wraps inside the row rather than running past the card
    box.label:SetPoint("RIGHT", holder, "RIGHT")
    box.label:SetWordWrap(true)
    card:Add(holder, { height = ROW, fill = true })
    v.showDone = box
    return card
end

local function BuildRollup(ui, content, v)
    local card = ui:CreateGroup(content, L["Alt Rollup"])
    local head = Row(content, LIST_ROW)
    for i, fs in ipairs(CountCells(ui, head, "groupLabel")) do fs:SetText(STATE_LABEL[ROLLUP[i]]) end
    card:Add(head, { height = LIST_ROW, fill = true })
    v.rollHead = head

    v.rollEmpty = ui:CreateText(content, L["No characters tracked yet."], "label")
    v.rollEmpty:SetTextColor(ui:Color("muted"))
    card:Add(v.rollEmpty, { height = LIST_ROW, fill = true })

    v.rollCard, v.rollRows = card, {}
    return card
end

-- Rows join the card as characters appear, and the card stacks them after the heading and the empty line
local function RollupRow(ui, content, v, i)
    local row = v.rollRows[i]
    if row then return row end
    row = Row(content, LIST_ROW)
    row.name = E.NamePair(ui, row, "value")
    row.realm = E.NamePair(ui, row, "label")
    row.counts = CountCells(ui, row, "label")
    v.rollCard:Add(row, { height = LIST_ROW, fill = true })
    v.rollRows[i] = row
    return row
end

local function RenderRollup(ui, content, v)
    local sv = EverythingDelvesDB
    local roster = (sv and sv.delversCallRoster) or {}
    local total = #E.DelversCall
    local curKey = E.CharKey()

    local keys = {}
    for k in pairs(roster) do keys[#keys + 1] = k end
    table_sort(keys)

    for i, k in ipairs(keys) do
        local rec = roster[k]
        local n = { fresh = 0, inProgress = 0, ready = 0, completed = 0 }
        for _, st in pairs(rec.states or {}) do
            if n[st] and st ~= "fresh" then n[st] = n[st] + 1 end
        end
        n.fresh = math_max(0, total - n.inProgress - n.ready - n.completed)

        local row = RollupRow(ui, content, v, i)
        local name = E.ShowNamePair(ui, row.name, rec.name or k, E.ClassRGB(ui, rec.class))
        local mr, mg, mb = ui:Color("muted")
        local realm = E.ShowNamePair(ui, row.realm, "(" .. (rec.realm or "?") .. ")"
            .. (k == curKey and ("  " .. L["(you)"]) or ""), mr, mg, mb)
        name:ClearAllPoints()
        name:SetPoint("LEFT")
        realm:ClearAllPoints()
        realm:SetPoint("LEFT", name, "RIGHT", NAME_GAP, 0)
        realm:SetPoint("RIGHT", row, "RIGHT", -COUNTS_W, 0)
        for c, st in ipairs(ROLLUP) do row.counts[c]:SetText(tostring(n[st])) end
        row:Show()
    end
    for i = #keys + 1, #v.rollRows do v.rollRows[i]:Hide() end
    v.rollHead:SetShown(#keys > 0)
    v.rollEmpty:SetShown(#keys == 0)
end

local function PaintStatus(ui, cell, st)
    cell.check:SetShown(st == "completed")
    -- A tag sizes itself only when its text is set, which for this one was while the page was built
    cell.tag:Fit()
    cell.tag:SetShown(st == "ready")
    cell.text:SetShown(st ~= "ready")
    cell.text:ClearAllPoints()
    cell.text:SetPoint("LEFT", cell, "LEFT", st == "completed" and (CHECK + CHECK_GAP) or 0, 0)
    cell.text:SetText(STATE_LABEL[st] or STATE_LABEL.fresh)
    cell.text:SetTextColor(ui:Color((st == "completed" or st == "fresh") and "muted" or "label"))
end

E:RegisterModule(function()
    local ui = E.ui
    local frame = CreateFrame("Frame", "EverythingDelvesTabDelversCallContent")
    local area = ui:CreateScrollArea(frame, { clearGrip = true })
    area:SetAllPoints(frame)
    local content = area.content

    local v = {}
    BuildIntro(ui, content, v)
    local cards = { BuildStrategy(ui, content), BuildCalls(ui, content, v), BuildRollup(ui, content, v) }

    local lastWidth = 0
    local function ViewWidth()
        local w = area.scroll:GetWidth() or 0
        if w <= 0 then w = (frame:GetWidth() or 0) - 10 end
        return math_max(1, w)
    end

    local function Render()
        local width = ViewWidth()
        lastWidth = width
        content:SetWidth(width)

        local states, counts = ComputeStates()
        PersistRoster(states)
        v.summary:SetText(StripCodes(L["%sThis character:|r  %s%d|r available   %s%d|r in progress   %s%d|r banked   %s%d|r turned in   %s(of %d)|r"]
            :format("", "", counts.fresh, "", counts.inProgress, "", counts.ready, "", counts.completed, "", #E.DelversCall)))
        for _, row in ipairs(v.calls) do PaintStatus(ui, row.status, states[row.entry.delve] or "fresh") end
        v.showDone:Refresh()
        RenderRollup(ui, content, v)

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
        Render()
        area:ScrollTo(0, 0)
        RenderSoon()
    end)

    -- Saved with the tab closed too, since the other characters' roll-up reads it
    E:RegisterCallback("QuestLogUpdate", function()
        if frame:IsVisible() then
            Render()
        else
            PersistRoster((ComputeStates()))
        end
    end)

    -- Quest data may not be ready when the module loads, so the roster is seeded after login
    C_Timer.After(2, function()
        PersistRoster((ComputeStates()))
    end)

    E:RegisterTab(7, frame)
end)
