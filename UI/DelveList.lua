local E = EverythingDelves
local L = E.L

local ipairs = ipairs
local math_ceil, math_floor, math_max, math_min = math.ceil, math.floor, math.max, math.min
local string_format = string.format

local ED_TEXTURES  = "Interface\\AddOns\\EverythingDelves\\Media\\Textures\\"
local READY_ICON   = "Interface\\RaidFrame\\ReadyCheck-Ready"
local BOUNTIFUL_ATLAS = "delves-bountiful"

local SIDE, GAP, CHEVRON, BUTTON, BUTTON_GAP = 8, 10, 12, 24, 10
local MARK, MARK_GAP, SORT_ICON, SORT_GAP = 14, 6, 10, 4
local ROW, TWO_ROW, HEAD, PINNED_GAP = 28, 44, 28, 10
local LINE1_Y, LINE2_Y = -14, -31
local BOSS_LEFT, BOSS_RIGHT, BOSS_TOP, BOSS_BOTTOM = 30, 16, 4, 8
local BOSS_PAD, BOSS_TEXT, NAME_LINE, NOTE_GAP, LINE_EXTRA = 6, 20, 17, 6, 4
local FLASH_TIME = 1.5
local DIM = 0.4

local DL = {}
E.DelveList = DL

local function hexCode(r, g, b)
    return string_format("|cFF%02X%02X%02X", math_floor(r * 255 + 0.5), math_floor(g * 255 + 0.5), math_floor(b * 255 + 0.5))
end

local function cc(token)
    local r, g, b = E.ui:Color(token)
    return hexCode(r, g, b)
end
DL.cc = cc

-- A wrapped string's height, which the client can under-report before its first draw
local function wrapHeight(fs, text, width, size)
    fs:SetWidth(0)
    fs:SetText(text)
    local natural = fs:GetStringWidth() or 0
    fs:SetWidth(width)
    local lines = math_max(1, math_ceil(natural / math_max(1, width)))
    return math_max(fs:GetStringHeight() or 0, lines * (size + LINE_EXTRA))
end
DL.WrapHeight = wrapHeight

local pins = {}

local function paintPin(b)
    local on = b.delve and E:IsSuperTrackingDelve(b.delve)
    b:GetNormalTexture():SetVertexColor(E.ui:Color(on and "accentHi" or "navText"))
end

local pinWatch = CreateFrame("Frame")
pinWatch:RegisterEvent("SUPER_TRACKING_CHANGED")
pinWatch:SetScript("OnEvent", function()
    for _, b in ipairs(pins) do
        if b:IsVisible() then paintPin(b) end
    end
end)

local function flash(b)
    local tex = b:GetNormalTexture()
    tex:SetTexture(E.ui:Texture("check"))
    local token = {}
    b.flashToken = token
    C_Timer.After(FLASH_TIME, function()
        if b.flashToken == token then
            b.flashToken = nil
            tex:SetTexture(b.iconFile)
        end
    end)
end
DL.Flash = flash

local function iconButton(parent, file)
    local b = E.ui:CreateIconButton(parent, "icon-map", BUTTON)
    b:GetNormalTexture():SetTexture(file)
    b:GetDisabledTexture():SetTexture(file)
    b.iconFile = file
    return b
end
DL.IconButton = iconButton

local function newPin(row)
    local b = iconButton(row, E.ui:Texture("icon-map"))
    b:SetScript("OnClick", function(self)
        if not self.delve then return end
        if E:ToggleDelveSuperTrack(self.delve) == "waypoint" then flash(self) end
        paintPin(self)
    end)
    b:SetScript("OnEnter", function(self)
        if not self.delve then return end
        if E:IsSuperTrackingDelve(self.delve) then
            E.ui:ShowTooltip(self, L["Tracking This Delve"],
                L["The on-screen arrow is guiding you here."] .. "\n" .. L["Click to stop tracking."])
        else
            E.ui:ShowTooltip(self, L["Track This Delve"],
                L["Point the on-screen arrow at this entrance."] .. "\n" .. L["Click again to stop."])
        end
    end)
    b:SetScript("OnLeave", function() E.ui:HideTooltip() end)
    pins[#pins + 1] = b
    return b
end

local function newTomTom(row)
    local b = iconButton(row, ED_TEXTURES .. "icon-tomtom")
    b:SetScript("OnClick", function(self)
        local d = self.delve
        if d and E:AddTomTomWaypoint(d.mapID, d.x, d.y, d.name) then flash(self) end
    end)
    b:SetScript("OnEnter", function(self)
        if E:IsTomTomLoaded() then
            E.ui:ShowTooltip(self, L["TomTom Waypoint"], L["Add an arrow waypoint via TomTom."])
        else
            E.ui:ShowTooltip(self, L["TomTom Not Installed"], L["Install the TomTom addon to use arrow waypoints."])
        end
    end)
    b:SetScript("OnLeave", function() E.ui:HideTooltip() end)
    return b
end

local function headerCell(t, col)
    local ui = E.ui
    local cell = CreateFrame("Button", nil, t.header)
    cell:SetHeight(HEAD)
    cell.text = ui:CreateText(cell, col.label, "groupLabel")
    cell.text:SetWordWrap(false)
    if col.sort then
        cell.chevron = cell:CreateTexture(nil, "ARTWORK")
        cell.chevron:SetSize(SORT_ICON, SORT_ICON)
        cell.chevron:SetTexture(ui:Texture("chevron-down"))
        cell:SetScript("OnClick", function()
            if t.sortKey == col.sort then
                t.sortAsc = not t.sortAsc
            else
                t.sortKey, t.sortAsc = col.sort, true
            end
            if t.opts.onChange then t.opts.onChange() end
        end)
        cell:SetScript("OnEnter", function(self)
            self.text:SetTextColor(ui:Color("text"))
            if col.tip then ui:ShowTooltip(self, col.tip[1], col.tip[2]) end
        end)
        cell:SetScript("OnLeave", function(self)
            if t.sortKey ~= col.sort then self.text:SetTextColor(ui:Color("muted")) end
            ui:HideTooltip()
        end)
    end
    cell.col = col
    return cell
end

local function paintHeader(t)
    for _, cell in ipairs(t.headerCells) do
        local on = cell.col.sort ~= nil and t.sortKey == cell.col.sort
        local textW = math_ceil(cell.text:GetStringWidth() or 0) + 1
        local cellW = cell:GetWidth() or 0
        local groupW = textW + (on and (SORT_GAP + SORT_ICON) or 0)
        local align = cell.col.align or "LEFT"
        local x = 0
        if align == "RIGHT" then x = cellW - groupW elseif align == "CENTER" then x = (cellW - groupW) / 2 end
        x = math_max(0, x)
        cell.text:ClearAllPoints()
        cell.text:SetPoint("LEFT", cell, "LEFT", x, 0)
        cell.text:SetWidth(math_max(1, math_min(textW, cellW)))
        cell.text:SetTextColor(E.ui:Color(on and "text" or "muted"))
        if cell.chevron then
            cell.chevron:SetShown(on)
            cell.chevron:ClearAllPoints()
            cell.chevron:SetPoint("LEFT", cell.text, "RIGHT", SORT_GAP, 0)
            cell.chevron:SetVertexColor(E.ui:Color("text"))
            if t.sortAsc then cell.chevron:SetTexCoord(0, 1, 1, 0) else cell.chevron:SetTexCoord(0, 1, 0, 1) end
        end
    end
end

local function placeColumns(t, width)
    local right = SIDE + BUTTON * 2 + BUTTON_GAP + GAP
    for i = #t.cols, 1, -1 do
        local col = t.cols[i]
        local cell = t.headerCells[i + 1]
        local need = (cell.text:GetStringWidth() or 0) + (col.sort and (SORT_ICON + SORT_GAP) or 0)
        col.w = math_max(col.width, math_ceil(need))
        col.right = right
        right = right + col.w + GAP
    end
    t.nameLeft = SIDE + CHEVRON + GAP
    t.nameWidth = math_max(40, width - t.nameLeft - right)
    for i, cell in ipairs(t.headerCells) do
        cell:ClearAllPoints()
        if i == 1 then
            cell:SetPoint("LEFT", t.header, "LEFT", t.nameLeft, 0)
            cell:SetWidth(t.nameWidth)
        else
            local col = t.cols[i - 1]
            cell:SetPoint("RIGHT", t.header, "RIGHT", -col.right, 0)
            cell:SetWidth(col.w)
        end
    end
end

local function newRow(t)
    local ui = E.ui
    local r = CreateFrame("Button", nil, t.content)
    r:RegisterForClicks("LeftButtonUp")
    local hl = r:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(ui:Color("hover"))
    ui:Paint(r, nil, "divider", "B")

    r.chevron = r:CreateTexture(nil, "ARTWORK")
    r.chevron:SetSize(CHEVRON, CHEVRON)
    r.chevron:SetVertexColor(ui:Color("muted"))
    r.name = ui:CreateText(r, "", "label")
    r.name:SetWordWrap(false)
    r.mark = r:CreateTexture(nil, "ARTWORK")
    r.mark:SetSize(MARK, MARK)
    r.mark:SetAtlas(BOUNTIFUL_ATLAS)
    r.runs = ui:CreateText(r, "", "hint")
    r.runs:SetWordWrap(false)
    r.call = r:CreateTexture(nil, "ARTWORK")
    r.call:SetSize(12, 12)
    r.call:SetTexture(READY_ICON)
    r.done = r:CreateTexture(nil, "ARTWORK")
    r.done:SetSize(12, 12)
    r.done:SetTexture(ui:Texture("check"))
    r.done:SetVertexColor(ui:Color("label"))
    r.tag = ui:CreateTag(r, "", "outline")
    r.line2 = ui:CreateText(r, "", "hint")
    r.line2:SetWordWrap(false)

    r.cells = {}
    for i, col in ipairs(t.cols) do
        local fs = ui:CreateText(r, "", col.weight or "label")
        fs:SetWordWrap(false)
        fs:SetJustifyH(col.align or "LEFT")
        r.cells[i] = fs
    end
    r.tt = newTomTom(r)
    r.tt:SetPoint("RIGHT", r, "RIGHT", -SIDE, 0)
    r.pin = newPin(r)
    r.pin:SetPoint("RIGHT", r.tt, "LEFT", -BUTTON_GAP, 0)

    r:SetScript("OnClick", function(self)
        local m = self.model
        if not (m and E:GetDelveBosses(m.bossName)) then return end
        t.expanded[m.key] = not t.expanded[m.key]
        if t.opts.onChange then t.opts.onChange() end
    end)
    r:SetScript("OnEnter", function(self)
        local m = self.model
        if m and m.tip then ui:ShowTooltip(self, m.tip[1], m.tip[2]) end
    end)
    r:SetScript("OnLeave", function() ui:HideTooltip() end)
    return r
end

local function fillName(t, r, m, top)
    local ui = E.ui
    local marks = {}
    r.mark:SetShown(m.bountiful and true or false)
    if m.bountiful then marks[#marks + 1] = { r.mark, MARK } end
    r.runs:SetText(m.runs and ("(" .. m.runs .. "x)") or "")
    r.runs:SetShown(m.runs ~= nil)
    if m.runs then marks[#marks + 1] = { r.runs, math_ceil(r.runs:GetStringWidth() or 0) } end
    r.call:SetShown(m.call and true or false)
    if m.call then marks[#marks + 1] = { r.call, 12 } end
    r.done:SetShown(m.done and true or false)
    if m.done then marks[#marks + 1] = { r.done, 12 } end

    local extra = 0
    for _, mk in ipairs(marks) do extra = extra + MARK_GAP + mk[2] end
    r.name:SetWidth(0)
    r.name:SetText(m.name)
    r.name:SetTextColor(ui:Color(m.done and "muted" or "text"))
    local natural = math_ceil(r.name:GetStringWidth() or 0) + 1
    r.name:SetWidth(math_max(1, math_min(natural, t.nameWidth - extra)))
    r.name:ClearAllPoints()
    r.name:SetPoint("LEFT", r, "TOPLEFT", t.nameLeft, top)
    local prev = r.name
    for _, mk in ipairs(marks) do
        mk[1]:ClearAllPoints()
        mk[1]:SetPoint("LEFT", prev, "RIGHT", MARK_GAP, 0)
        prev = mk[1]
    end
end

local function fillLine2(t, r, m)
    local two = m.line2
    r.tag:SetShown(two ~= nil and two.tag ~= nil)
    r.line2:SetShown(two ~= nil)
    if not two then return end
    local x = t.nameLeft
    if two.tag then
        r.tag:SetText(two.tag)
        r.tag:ClearAllPoints()
        r.tag:SetPoint("LEFT", r, "TOPLEFT", x, LINE2_Y)
        x = x + (r.tag:GetWidth() or 0) + MARK_GAP
    end
    r.line2:ClearAllPoints()
    r.line2:SetPoint("LEFT", r, "TOPLEFT", x, LINE2_Y)
    r.line2:SetWidth(math_max(1, t.nameWidth - (x - t.nameLeft)))
    r.line2:SetText(two.text or "")
end

local function fillRow(t, r, m)
    local ui = E.ui
    r.model = m
    local two = m.line2 ~= nil
    local h = two and TWO_ROW or ROW
    r:SetHeight(h)
    local top = two and LINE1_Y or -(ROW / 2)
    local hasBosses = E:GetDelveBosses(m.bossName) ~= nil
    r.chevron:SetShown(hasBosses)
    r.chevron:SetTexture(ui:Texture(t.expanded[m.key] and "chevron-down" or "chevron-right"))
    r.chevron:ClearAllPoints()
    r.chevron:SetPoint("LEFT", r, "TOPLEFT", SIDE, top)
    fillName(t, r, m, top)
    fillLine2(t, r, m)
    for i, col in ipairs(t.cols) do
        local fs, cell = r.cells[i], m.cells[col.key] or {}
        fs:ClearAllPoints()
        fs:SetPoint("RIGHT", r, "TOPRIGHT", -col.right, -(h / 2))
        fs:SetWidth(col.w)
        fs:SetText(cell.text or "")
        if cell.color then
            fs:SetTextColor(cell.color[1], cell.color[2], cell.color[3])
        else
            fs:SetTextColor(ui:Color(cell.muted and "muted" or (col.weight == "value" and "text" or "label")))
        end
    end
    r.pin.delve, r.tt.delve = m.delve, m.delve
    paintPin(r.pin)
    r.tt:SetAlpha(E:IsTomTomLoaded() and 1 or DIM)
end

local function newBossRow(block)
    local ui = E.ui
    local b = CreateFrame("Button", nil, block)
    b:RegisterForClicks("LeftButtonUp")
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(ui:Color("hover"))
    b.chevron = b:CreateTexture(nil, "ARTWORK")
    b.chevron:SetSize(CHEVRON, CHEVRON)
    b.chevron:SetPoint("TOPLEFT", 0, -(BOSS_PAD + 3))
    b.chevron:SetVertexColor(ui:Color("muted"))
    b.name = ui:CreateText(b, "", "value")
    b.name:SetWordWrap(false)
    b.name:SetPoint("TOPLEFT", BOSS_TEXT, -BOSS_PAD)
    b.name:SetPoint("RIGHT")
    b.brief = ui:CreateText(b, "", "hint")
    b.brief:SetWordWrap(true)
    b.notes = {}
    b:SetScript("OnClick", function(self)
        self.table.bossOpen[self.key] = not self.open
        if self.table.opts.onChange then self.table.opts.onChange() end
    end)
    return b
end

local function noteText(note)
    local meta = E.BossRoleMeta and E.BossRoleMeta[note.role]
    local rgb = meta and meta.rgb or { 0.80, 0.80, 0.85 }
    return hexCode(rgb[1], rgb[2], rgb[3]) .. (meta and meta.label or L["Note"]) .. "|r  " .. note.text
end

local function fillBoss(t, b, boss, key, isToday, width)
    local ui = E.ui
    local open = t.bossOpen[key]
    if open == nil then open = isToday end
    b.table, b.key, b.open = t, key, open
    b.chevron:SetTexture(ui:Texture(open and "chevron-down" or "chevron-right"))
    b.name:SetText(boss.name .. (isToday and (" " .. cc("muted") .. L["(today's boss)"] .. "|r") or ""))
    local textW = math_max(40, width - BOSS_TEXT)
    local y = BOSS_PAD + NAME_LINE
    b.brief:ClearAllPoints()
    b.brief:SetPoint("TOPLEFT", BOSS_TEXT, -y)
    y = y + wrapHeight(b.brief, boss.brief or "", textW, 12)
    for _, fs in ipairs(b.notes) do fs:Hide() end
    if open and boss.notes then
        for i, note in ipairs(boss.notes) do
            local fs = b.notes[i]
            if not fs then
                fs = ui:CreateText(b, "", "hint")
                fs:SetWordWrap(true)
                fs:SetTextColor(ui:Color("label"))
                b.notes[i] = fs
            end
            y = y + NOTE_GAP
            fs:ClearAllPoints()
            fs:SetPoint("TOPLEFT", BOSS_TEXT, -y)
            y = y + wrapHeight(fs, noteText(note), textW, 12)
            fs:Show()
        end
    end
    y = y + BOSS_PAD
    b:SetHeight(y)
    return y
end

local function acquire(pool, used, make)
    local item = pool[used]
    if not item then
        item = make()
        pool[used] = item
    end
    item:ClearAllPoints()
    item:Show()
    return item
end

local function layoutBosses(t, m, y, left, right, width, used)
    local bosses = E:GetDelveBosses(m.bossName)
    if not (bosses and t.expanded[m.key]) then return y end
    used.blocks = used.blocks + 1
    local block = acquire(t.blocks, used.blocks, function()
        local f = CreateFrame("Frame", nil, t.content)
        E.ui:Paint(f, "surface", "divider", "B")
        f.rows = {}
        return f
    end)
    block:SetPoint("TOPLEFT", t.content, "TOPLEFT", left, -y)
    block:SetPoint("TOPRIGHT", t.content, "TOPRIGHT", -right, -y)
    local today = E:GetTodaysBossName(m.bossName)
    local by = BOSS_TOP
    local innerW = width - BOSS_LEFT - BOSS_RIGHT
    for i, boss in ipairs(bosses) do
        local b = acquire(block.rows, i, function() return newBossRow(block) end)
        b:SetFrameLevel(block:GetFrameLevel() + 1)
        b:SetPoint("TOPLEFT", block, "TOPLEFT", BOSS_LEFT, -by)
        b:SetPoint("RIGHT", block, "RIGHT", -BOSS_RIGHT, 0)
        by = by + fillBoss(t, b, boss, m.key .. "##" .. i, today ~= nil and boss.name == today, innerW)
    end
    for i = #bosses + 1, #block.rows do block.rows[i]:Hide() end
    by = by + BOSS_BOTTOM
    block:SetHeight(by)
    return y + by
end

-- Pinned rows sit above the headings, so a sort never moves them
local function layout(t, y, models, left, right, pinned)
    local width = math_max(1, (t.content:GetWidth() or 0) - left - right)
    placeColumns(t, width)
    paintHeader(t)
    local used = { rows = 0, blocks = 0 }
    local function place(m)
        used.rows = used.rows + 1
        local r = acquire(t.rows, used.rows, function() return newRow(t) end)
        r:SetPoint("TOPLEFT", t.content, "TOPLEFT", left, -y)
        r:SetPoint("TOPRIGHT", t.content, "TOPRIGHT", -right, -y)
        fillRow(t, r, m)
        y = y + r:GetHeight()
        y = layoutBosses(t, m, y, left, right, width, used)
    end
    if pinned and #pinned > 0 then
        for _, m in ipairs(pinned) do place(m) end
        y = y + PINNED_GAP
    end
    t.header:ClearAllPoints()
    t.header:SetPoint("TOPLEFT", t.content, "TOPLEFT", left, -y)
    t.header:SetPoint("TOPRIGHT", t.content, "TOPRIGHT", -right, -y)
    t.header:Show()
    y = y + HEAD
    for _, m in ipairs(models) do place(m) end
    for i = used.rows + 1, #t.rows do
        t.rows[i]:Hide()
        t.rows[i].model = nil
    end
    for i = used.blocks + 1, #t.blocks do t.blocks[i]:Hide() end
    return y
end

local function hide(t)
    t.header:Hide()
    for _, r in ipairs(t.rows) do
        r:Hide()
        r.model = nil
    end
    for _, b in ipairs(t.blocks) do b:Hide() end
end

function DL.New(content, opts)
    local t = { content = content, opts = opts, cols = opts.columns, expanded = {}, bossOpen = {},
                rows = {}, blocks = {}, sortKey = opts.sortKey, sortAsc = true }
    t.header = CreateFrame("Frame", nil, content)
    t.header:SetHeight(HEAD)
    E.ui:Paint(t.header, nil, "divider", "B")
    t.headerCells = { headerCell(t, { label = opts.nameLabel, sort = opts.nameSort, width = 0 }) }
    for _, col in ipairs(opts.columns) do
        t.headerCells[#t.headerCells + 1] = headerCell(t, col)
    end
    t.Layout, t.Hide = layout, hide
    return t
end

DL.GRADE_ORDER = { S = 1, A = 2, B = 3, C = 4, D = 5, F = 6 }

function DL.GradeCell(letter, muted)
    if not letter then return { text = "--", muted = true } end
    if muted then return { text = letter, muted = true } end
    return { text = letter, color = E.GRADE_COLORS[letter] }
end

function DL.Labyrinth()
    local LAB = E.Labyrinth
    local open = E.IsLabyrinthUnlocked()
    local hist = E:GetDelveHistory(LAB.name)
    local runs = hist and hist.lifetime and hist.lifetime.totalRuns
    local v = {
        key = LAB.name, name = E.LabyrinthDisplayName(), zone = E.LabyrinthZoneName(), open = open,
        entrance = E.LabyrinthEntrance(), runs = (runs and runs > 0) and runs or nil,
        coffers = L["A full run opens %d coffers."]:format(math_floor(LAB.chambers / LAB.checkpointEvery)),
    }
    if not open then v.locked = L["Unlocks with the quest \"%s\"."]:format(E.LabyrinthIntroQuestTitle()) end
    v.tip = { v.name, L["Zone:"] .. " " .. v.zone .. "\n\n" .. (v.locked or (L["Always bountiful"] .. "\n" .. v.coffers)) }
    return v
end

