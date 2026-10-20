local E = EverythingDelves
local L = E.L

local ipairs, pairs, time, tostring = ipairs, pairs, time, tostring
local math_abs, math_ceil, math_floor, math_max = math.abs, math.ceil, math.floor, math.max
local table_sort, table_concat = table.sort, table.concat

local PAD_TOP, PAD_LEFT, PAD_RIGHT, PAD_BOTTOM, INTRO_GAP, HINT_GAP = 20, 24, 14, 28, 16, 8
local HEAD, ROW, EMPTY_ROW = 28, 28, 44
local INSET, GAP, NAME_MIN, NAME_GAP, CHECK, BUTTON, SORT_ICON, SORT_GAP, CELL_PAD = 14, 10, 140, 6, 14, 24, 10, 4, 4

local COLUMNS = {
    { key = "ilvl",     label = L["iLvl"] },
    { key = "keys",     label = L["Keys"] },
    { key = "shards",   label = L["Shards"] },
    { key = "wkshards", label = L["Wk Shards"] },
    { key = "bounty",   label = L["Bounty"] },
    { key = "vault",    label = L["Vault"] },
    { key = "gilded",   label = L["Gilded"] },
    { key = "weekly",   label = L["Weekly"], check = true },
    { key = "trove",    label = L["Trove"],  check = true },
    -- A count until every step is done, then the check
    { key = "wahdu",    label = E.WahduName(), check = true, text = true },
}

local function FormatAgo(secs)
    if not secs or secs < 0 then return "?" end
    if secs < 60    then return L["just now"] end
    if secs < 3600  then return L["%dm ago"]:format(math_floor(secs / 60)) end
    if secs < 86400 then return L["%dh ago"]:format(math_floor(secs / 3600)) end
    return L["%dd ago"]:format(math_floor(secs / 86400))
end

-- The summary phrase carries its own colors, which the library's look drops
local function StripCodes(s)
    return (s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
end

local function SortVal(e, key)
    local rec = e.rec
    if key == "name"     then return (rec.name or e.key):lower() end
    if key == "ilvl"     then return rec.ilvl or 0 end
    if key == "keys"     then return rec.keys or 0 end
    if key == "shards"   then return rec.shards or 0 end
    if key == "wkshards" then return e.valid and (rec.shardsEarnedWeek or 0) or -1 end
    if key == "bounty"   then return rec.bountyMaps or 0 end
    if key == "vault"    then return e.valid and (rec.vaultSlots or 0) or -1 end
    if key == "gilded"   then return e.valid and (rec.gildedCollected or 0) or -1 end
    if key == "weekly"   then return e.valid and (rec.weeklyQuestDone and 1 or 0) or -1 end
    if key == "trove"    then return e.valid and (rec.bountyLooted and 1 or 0) or -1 end
    if key == "wahdu"    then return rec.wahdu or -1 end
    return rec.updated or 0
end

local function WahduValue(rec)
    if not rec.wahdu then return nil end
    local total = rec.wahduTotal or 0
    if total > 0 and rec.wahdu >= total then return true end
    return rec.wahdu .. "/" .. total
end

local function Values(e)
    local rec, valid = e.rec, e.valid
    return {
        ilvl     = rec.ilvl and tostring(rec.ilvl) or nil,
        keys     = tostring(rec.keys or 0),
        shards   = tostring(rec.shards or 0),
        wkshards = (valid and (rec.shardsMaxWeek or 0) > 0) and ((rec.shardsEarnedWeek or 0) .. "/" .. rec.shardsMaxWeek) or nil,
        bounty   = tostring(rec.bountyMaps or 0),
        vault    = (valid and (rec.vaultTotal or 0) > 0) and ((rec.vaultSlots or 0) .. "/3") or nil,
        gilded   = (valid and rec.gildedTotal) and ((rec.gildedCollected or 0) .. "/" .. rec.gildedTotal) or nil,
        weekly   = (valid and rec.weeklyQuestDone) and true or nil,
        trove    = (valid and rec.bountyLooted) and true or nil,
        wahdu    = WahduValue(rec),
    }
end

local function TipLines(e, now)
    local rec = e.rec
    local tip = {
        L["Item level: %s"]:format(rec.ilvl or "?"),
        L["Coffer Keys: %d   Shards: %d"]:format(rec.keys or 0, rec.shards or 0),
        L["Bounty maps: %d"]:format(rec.bountyMaps or 0),
    }
    if e.valid then
        if (rec.shardsMaxWeek or 0) > 0 then
            tip[#tip + 1] = L["Weekly shards earned: %d/%d"]:format(rec.shardsEarnedWeek or 0, rec.shardsMaxWeek)
        end
        tip[#tip + 1] = L["Great Vault delves: %d/%d  (%d/3 slots)"]
            :format(rec.vaultProgress or 0, rec.vaultTotal or 0, rec.vaultSlots or 0)
        if rec.gildedTotal then
            tip[#tip + 1] = L["Gilded Stash: %d/%d"]:format(rec.gildedCollected or 0, rec.gildedTotal)
        end
        tip[#tip + 1] = L["Trovehunter's Bounty: %s"]:format(rec.bountyLooted and L["looted this week"] or L["not looted"])
    else
        tip[#tip + 1] = L["Weekly data resets at the next reset"]
    end
    tip[#tip + 1] = L["Updated: %s"]:format(FormatAgo(now - (rec.updated or now)))
    return table_concat(tip, "\n")
end

local function BuildIntro(ui, content, v)
    local b = ui:CreateTextBlock(content)
    v.summaryLine = b:AddLine("", "label")
    b:AddLine(L["Log into a character to record it. Click a column to sort; hover a row for detail."], "hint",
        { gap = HINT_GAP })
    v.intro = b
end

local function HeadCell(ui, head, v, key, label, right)
    local cell = CreateFrame("Button", nil, head)
    cell:SetHeight(HEAD)
    cell.key = key
    cell.text = ui:CreateText(cell, label, "groupLabel")
    cell.text:SetWordWrap(false)
    cell.chevron = cell:CreateTexture(nil, "ARTWORK")
    cell.chevron:SetSize(SORT_ICON, SORT_ICON)
    cell.chevron:SetTexture(ui:Texture("chevron-down"))
    cell.chevron:SetVertexColor(ui:Color("text"))
    cell.right = right
    cell:SetScript("OnClick", function(self)
        if v.sortKey == self.key then
            v.sortDesc = not v.sortDesc
        else
            v.sortKey, v.sortDesc = self.key, self.key ~= "name"
        end
        v.relayout()
    end)
    cell:SetScript("OnEnter", function(self) self.text:SetTextColor(ui:Color("text")) end)
    cell:SetScript("OnLeave", function(self)
        if v.sortKey ~= self.key then self.text:SetTextColor(ui:Color("muted")) end
    end)
    return cell
end

local function PaintHead(ui, v, cell, width)
    local on = v.sortKey == cell.key
    local textW = math_ceil(cell.text:GetStringWidth() or 0) + 1
    local group = textW + (on and (SORT_GAP + SORT_ICON) or 0)
    cell.text:ClearAllPoints()
    cell.text:SetPoint("LEFT", cell, "LEFT", cell.right and math_max(0, width - group) or 0, 0)
    cell.text:SetTextColor(ui:Color(on and "text" or "muted"))
    cell.chevron:SetShown(on)
    cell.chevron:ClearAllPoints()
    cell.chevron:SetPoint("LEFT", cell.text, "RIGHT", SORT_GAP, 0)
    if v.sortDesc then cell.chevron:SetTexCoord(0, 1, 0, 1) else cell.chevron:SetTexCoord(0, 1, 1, 0) end
end

local function NewRow(ui, t, v)
    local r = CreateFrame("Button", nil, t)
    r:SetHeight(ROW)
    r.you = ui:Paint(r, "accentSoft", "divider", "T")
    local hl = r:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(ui:Color("hover"))
    r.name = E.NamePair(ui, r, "value")
    r.suffix = ui:CreateText(r, "", "label")
    r.suffix:SetTextColor(ui:Color("muted"))
    r.suffix:SetWordWrap(false)
    r.cells, r.checks = {}, {}
    for _, col in ipairs(COLUMNS) do
        local fs = ui:CreateText(r, "", "label")
        fs:SetWordWrap(false)
        fs:SetJustifyH("RIGHT")
        r.cells[col.key] = fs
        if col.check then
            local c = r:CreateTexture(nil, "ARTWORK")
            c:SetSize(CHECK, CHECK)
            c:SetTexture(ui:Texture("check"))
            c:SetVertexColor(ui:Color("label"))
            r.checks[col.key] = c
        end
    end
    r.remove = ui:CreateIconButton(r, "close", BUTTON)
    r.remove:SetPoint("RIGHT", r, "RIGHT", -INSET, 0)
    r.remove:SetScript("OnClick", function(self) v.removeChar(self:GetParent()) end)
    r.remove:SetScript("OnEnter", function(self) ui:ShowTooltip(self, L["Remove"], nil) end)
    r.remove:SetScript("OnLeave", function() ui:HideTooltip() end)
    r:SetScript("OnEnter", function(self) ui:ShowTooltip(self, self.title, self.tip) end)
    r:SetScript("OnLeave", function() ui:HideTooltip() end)
    return r
end

local function FillRow(ui, r, e, isCur, now)
    local rec = e.rec
    r.entry = e
    r.you:SetShown(isCur)
    r.remove:SetShown(not isCur)
    r.title = (rec.name or e.key) .. " - " .. (rec.realm or "?")
    r.tip = TipLines(e, now)
    r.shownName = E.ShowNamePair(ui, r.name, rec.name or e.key, E.ClassRGB(ui, rec.class))
    r.suffix:SetText((rec.level and tostring(rec.level) or "") .. (isCur and ("  " .. L["(you)"]) or ""))
    local values = Values(e)
    for _, col in ipairs(COLUMNS) do
        local val = values[col.key]
        local fs = r.cells[col.key]
        if col.check then
            r.checks[col.key]:SetShown(val == true)
            fs:SetText((val == true and "") or val or "--")
        else
            fs:SetText(val or "--")
        end
        fs:SetTextColor(ui:Color(val and "label" or "muted"))
    end
end

local function ColumnWidths(t, rows, used, v)
    local widths = {}
    for i, col in ipairs(COLUMNS) do
        local cell = t.heads[i + 1]
        local w = math_ceil(cell.text:GetStringWidth() or 0) + 1 + (v.sortKey == col.key and (SORT_GAP + SORT_ICON) or 0)
        for r = 1, used do
            local fs = rows[r].cells[col.key]
            fs:SetWidth(0)
            local text = math_ceil(fs:GetStringWidth() or 0)
            w = math_max(w, (col.check and not col.text) and CHECK or (col.check and math_max(CHECK, text) or text))
        end
        widths[i] = w + CELL_PAD
    end
    return widths
end

-- Spans the whole card, past the card's own inset, so a row's tint and divider reach both edges
local function Place(item, t, y)
    item:SetPoint("TOPLEFT", t, "TOPLEFT", -INSET, -y)
    item:SetPoint("TOPRIGHT", t, "TOPRIGHT", INSET, -y)
end

local function PlaceColumns(r, widths, cellFor)
    local right = INSET + BUTTON + GAP
    for i = #COLUMNS, 1, -1 do
        local cell = cellFor(r, i)
        cell:ClearAllPoints()
        cell:SetPoint("RIGHT", r, "RIGHT", -right, 0)
        cell:SetWidth(widths[i])
        local check = r.checks and r.checks[COLUMNS[i].key]
        if check then
            check:ClearAllPoints()
            check:SetPoint("RIGHT", r, "RIGHT", -right, 0)
        end
        right = right + widths[i] + GAP
    end
    return right
end

local function RowCell(r, i)
    return r.cells[COLUMNS[i].key]
end

E:RegisterModule(function()
    local ui = E.ui
    local frame = CreateFrame("Frame", "EverythingDelvesTabRosterContent")
    local area = ui:CreateScrollArea(frame, { clearGrip = true })
    area:SetAllPoints(frame)
    local content = area.content

    local v = { sortKey = "ilvl", sortDesc = true }
    BuildIntro(ui, content, v)

    local card = ui:CreateGroup(content, nil)
    local t = CreateFrame("Frame", nil, content)
    t.head = CreateFrame("Frame", nil, t)
    t.head:SetHeight(HEAD)
    t.heads = { HeadCell(ui, t.head, v, "name", L["Character"], false) }
    for _, col in ipairs(COLUMNS) do t.heads[#t.heads + 1] = HeadCell(ui, t.head, v, col.key, col.label, true) end
    t.empty = ui:CreateText(t, L["No characters tracked yet."], "label")
    t.empty:SetTextColor(ui:Color("muted"))
    t.rows = {}
    card:Add(t, { height = EMPTY_ROW, fill = true })

    v.removeChar = function(row)
        local delKey = row.entry and row.entry.key
        if not delKey then return end
        E:ShowDialog({
            text = L["Remove %s from the roster?\n\nThis only clears the saved snapshot; logging into that character records it again."]
                :format(row.entry.rec.name or delKey),
            button1 = L["Remove"], button2 = L["Cancel"], danger = true,
            onAccept = function()
                local saved = EverythingDelvesDB
                if saved and saved.roster then saved.roster[delKey] = nil end
                -- The Delver's Call roll-up lists from its own table
                if saved and saved.delversCallRoster then saved.delversCallRoster[delKey] = nil end
                v.relayout()
            end,
        })
    end

    local lastWidth = 0
    local function ViewWidth()
        local w = area.scroll:GetWidth() or 0
        if w <= 0 then w = (frame:GetWidth() or 0) - 10 end
        return math_max(1, w)
    end

    local function Render()
        E:CaptureRosterSnapshot()
        local sv = EverythingDelvesDB
        local roster = (sv and sv.roster) or {}
        local curKey = E.CharKey()
        local now = time()

        -- Wrap records (don't add transient fields to the persisted tables).
        local list = {}
        for k, rec in pairs(roster) do
            list[#list + 1] = { key = k, rec = rec, valid = rec.weekEnd and now < rec.weekEnd }
        end
        table_sort(list, function(a, b)
            local va, vb = SortVal(a, v.sortKey), SortVal(b, v.sortKey)
            if va == vb then return (a.rec.name or a.key) < (b.rec.name or b.key) end
            if v.sortDesc then return va > vb end
            return va < vb
        end)

        local keys, bounty, weekly = 0, 0, 0
        for _, e in ipairs(list) do
            keys = keys + (e.rec.keys or 0)
            bounty = bounty + (e.rec.bountyMaps or 0)
            if e.valid and e.rec.weeklyQuestDone then weekly = weekly + 1 end
        end
        v.summaryLine:SetText(StripCodes(L["%s%d|r %scharacters|r   %s\194\183|r   %s%d|r %skeys|r   %s\194\183|r   %s%d|r %sbounty maps|r   %s\194\183|r   %s%d|r %sweekly delve quest done|r"]
            :format("", #list, "", "", "", keys, "", "", "", bounty, "", "", "", weekly, "")))

        for i, e in ipairs(list) do
            if not t.rows[i] then t.rows[i] = NewRow(ui, t, v) end
            FillRow(ui, t.rows[i], e, e.key == curKey, now)
        end
        for i = #list + 1, #t.rows do t.rows[i]:Hide() end
        for i, col in ipairs(COLUMNS) do
            if col.key == "wahdu" then t.heads[i + 1].text:SetText(E.WahduName()) end
        end

        local widths = ColumnWidths(t, t.rows, #list, v)
        local view = ViewWidth()
        lastWidth = view
        local cols = INSET + BUTTON + GAP
        for _, w in ipairs(widths) do cols = cols + w + GAP end
        -- Wider than the window, the table scrolls sideways rather than squeezing the names
        local width = math_max(view, INSET + NAME_MIN + cols + PAD_LEFT + PAD_RIGHT)
        content:SetWidth(width)

        t.head:SetShown(#list > 0)
        t.empty:SetShown(#list == 0)
        local y
        if #list == 0 then
            t.empty:ClearAllPoints()
            t.empty:SetPoint("LEFT", t, "TOPLEFT", 0, -EMPTY_ROW / 2)
            y = EMPTY_ROW
        else
            t.head:ClearAllPoints()
            Place(t.head, t, 0)
            local nameRight = PlaceColumns(t.head, widths, function(_, i) return t.heads[i + 1] end)
            local nameCell = t.heads[1]
            nameCell:ClearAllPoints()
            nameCell:SetPoint("LEFT", t.head, "LEFT", INSET, 0)
            nameCell:SetPoint("RIGHT", t.head, "RIGHT", -nameRight, 0)
            for i, cell in ipairs(t.heads) do
                PaintHead(ui, v, cell, i == 1 and (cell:GetWidth() or 0) or widths[i - 1])
            end
            y = HEAD
            for i = 1, #list do
                local r = t.rows[i]
                r:ClearAllPoints()
                Place(r, t, y)
                r:Show()
                nameRight = PlaceColumns(r, widths, RowCell)
                r.shownName:ClearAllPoints()
                r.shownName:SetPoint("LEFT", r, "LEFT", INSET, 0)
                r.suffix:ClearAllPoints()
                r.suffix:SetPoint("LEFT", r.shownName, "RIGHT", NAME_GAP, 0)
                r.suffix:SetPoint("RIGHT", r, "RIGHT", -nameRight, 0)
                y = y + ROW
            end
        end
        t:SetHeight(y)
        t._euiRow:SetHeight(y)

        local top = PAD_TOP
        v.intro:ClearAllPoints()
        v.intro:SetPoint("TOPLEFT", content, "TOPLEFT", PAD_LEFT, -top)
        v.intro:SetPoint("TOPRIGHT", content, "TOPRIGHT", -PAD_RIGHT, -top)
        top = top + v.intro:Measure() + INTRO_GAP
        card:ClearAllPoints()
        card:SetPoint("TOPLEFT", content, "TOPLEFT", PAD_LEFT, -top)
        card:SetPoint("TOPRIGHT", content, "TOPRIGHT", -PAD_RIGHT, -top)
        card:Layout()
        area:SetContentSize(width, top + card:GetHeight() + PAD_BOTTOM)
    end
    v.relayout = Render

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

    local function OnData()
        if frame:IsVisible() then Render() else E:CaptureRosterSnapshot() end
    end
    E:RegisterCallback("CurrencyUpdate",   OnData)
    E:RegisterCallback("QuestLogUpdate",   OnData)
    E:RegisterCallback("BagUpdate",        OnData)
    E:RegisterCallback("InventoryChanged", OnData)

    C_Timer.After(2, function() E:CaptureRosterSnapshot() end)

    E:RegisterTab(9, frame)
end)
