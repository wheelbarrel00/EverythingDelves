local E = EverythingDelves
local L = E.L

local ED_TEXTURES = "Interface\\AddOns\\EverythingDelves\\Media\\Textures\\"
local LETTERS = { "S", "A", "B", "C", "D", "F" }
local ROW, HEAD, BUTTON_W, BUTTON_H, BUTTON_GAP, WONT_GAP = 40, 22, 30, 26, 4, 6
local COMP_W, CLEAR, COL_GAP, WONT_ICON = 96, 24, 12, 14

local WONT_X = CLEAR + COL_GAP
local F_X = WONT_X + BUTTON_W + WONT_GAP
local LETTERS_LEFT = F_X + #LETTERS * BUTTON_W + (#LETTERS - 1) * BUTTON_GAP
local COMP_X = LETTERS_LEFT + COL_GAP

local rows = {}

local function sortName(name)
    return (name:gsub("^The ", "")):lower()
end

local function paintRow(ui, row)
    local _, comp, mine = E:StoryGrade(row.id)
    for value, b in pairs(row.buttons) do
        local on = mine == value
        b.edge:SetColorTexture(ui:Color(on and "accentHi" or "inputBorder"))
        b.tint:SetShown(on)
        b.glyph:SetAlpha(on and 1 or 0.5)
    end
    local c = not mine and E.GRADE_COLORS[comp]
    if c then
        row.comp:SetTextColor(c[1], c[2], c[3])
    else
        row.comp:SetTextColor(ui:Color("muted"))
    end
    row.clear:SetShown(mine ~= nil)
end

local function repaint()
    for _, row in ipairs(rows) do paintRow(E.ui, row) end
end

local function gradeButton(ui, row, value)
    local b = CreateFrame("Button", nil, row)
    b:SetSize(BUTTON_W, BUTTON_H)
    b.edge = b:CreateTexture(nil, "BACKGROUND")
    b.edge:SetAllPoints()
    local fill = b:CreateTexture(nil, "BORDER")
    fill:SetPoint("TOPLEFT", 1, -1)
    fill:SetPoint("BOTTOMRIGHT", -1, 1)
    fill:SetColorTexture(ui:Color("input"))
    b.tint = b:CreateTexture(nil, "ARTWORK", nil, -1)
    b.tint:SetAllPoints(fill)
    b.tint:SetColorTexture(ui:Color("accentSoft"))
    if value == "x" then
        b.glyph = b:CreateTexture(nil, "ARTWORK")
        b.glyph:SetSize(WONT_ICON, WONT_ICON)
        b.glyph:SetTexture(ED_TEXTURES .. "icon-wont")
        b.glyph:SetVertexColor(ui:Color("label"))
    else
        b.glyph = ui:CreateText(b, value, "navActive")
        local c = E.GRADE_COLORS[value]
        b.glyph:SetTextColor(c[1], c[2], c[3])
    end
    b.glyph:SetPoint("CENTER")
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints(fill)
    hl:SetColorTexture(ui:Color("hover"))
    b:SetScript("OnClick", function()
        local _, _, mine = E:StoryGrade(row.id)
        E:SetStoryGrade(row.id, mine ~= value and value or nil)
    end)
    b:SetScript("OnEnter", function(self)
        ui:ShowTooltip(self, value == "x" and L["Won't run"] or L["%s Tier"]:format(value))
    end)
    b:SetScript("OnLeave", function() ui:HideTooltip() end)
    return b
end

local function storyRow(ui, list, id, i)
    local pad = ui:Spacing("rowPadding")
    -- Out past the card's inset to its edges, so the line between rows spans it
    local row = CreateFrame("Frame", nil, list)
    row:SetHeight(ROW)
    row:SetPoint("TOPLEFT", list, "TOPLEFT", -pad, -(i - 1) * ROW)
    row:SetPoint("TOPRIGHT", list, "TOPRIGHT", pad, -(i - 1) * ROW)
    if i > 1 then ui:Paint(row, nil, "divider", "T") end
    row.id = id

    row.clear = ui:CreateIconButton(row, "close", CLEAR)
    row.clear:SetPoint("RIGHT", row, "RIGHT", -pad, 0)
    row.clear:SetScript("OnClick", function() E:SetStoryGrade(id, nil) end)
    row.clear:SetScript("OnEnter", function(self)
        local _, comp = E:StoryGrade(id)
        ui:ShowTooltip(self, L["Use the compendium grade (%s)"]:format(comp or "--"))
    end)
    row.clear:SetScript("OnLeave", function() ui:HideTooltip() end)

    row.buttons = {}
    local wont = gradeButton(ui, row, "x")
    wont:SetPoint("RIGHT", row, "RIGHT", -(pad + WONT_X), 0)
    row.buttons.x = wont
    for n, value in ipairs(LETTERS) do
        local b = gradeButton(ui, row, value)
        b:SetPoint("RIGHT", row, "RIGHT", -(pad + F_X + (#LETTERS - n) * (BUTTON_W + BUTTON_GAP)), 0)
        row.buttons[value] = b
    end

    row.comp = ui:CreateText(row, E.Stories[id].grade or "--", "navActive")
    row.comp:SetJustifyH("LEFT")
    row.comp:SetWidth(COMP_W)
    row.comp:SetPoint("RIGHT", row, "RIGHT", -(pad + COMP_X), 0)

    row.name = ui:CreateText(row, E:StoryName(id), "label")
    row.name:SetWordWrap(false)
    row.name:SetJustifyH("LEFT")
    row.name:SetPoint("LEFT", row, "LEFT", pad, 0)
    row.name:SetPoint("RIGHT", row.comp, "LEFT", -COL_GAP, 0)
    return row
end

local function introCard(self, content, stack)
    local card = stack(self:CreateGroup(content, nil))
    local note = self:CreateTextBlock(content)
    note:AddLine(L["Grades come from Moleman's Delve Compendium and measure speed alone. Give any story your own grade, or mark one you won't run, and Best Pick, Delve Locations, Current Bountiful and the delve HUD follow your grades on every character."], "hint")
    card:Add(note, { fitHeight = true })

    local head = CreateFrame("Frame", nil, content)
    head:SetHeight(HEAD)
    head._euiFill = true
    local function label(text)
        local fs = self:CreateText(head, text, "groupLabel")
        fs:SetWordWrap(false)
        return fs
    end
    label(L["Story Variant"]):SetPoint("LEFT", head, "LEFT", 0, 0)
    local comp = label(L["Compendium"])
    comp:SetJustifyH("LEFT")
    comp:SetWidth(COMP_W)
    comp:SetPoint("RIGHT", head, "RIGHT", -COMP_X, 0)
    label(L["Your grade"]):SetPoint("LEFT", head, "RIGHT", -LETTERS_LEFT, 0)
    card:Add(head, { height = HEAD, fill = true })
end

local function delveCards(self, content, stack)
    local byDelve, order, zones = {}, {}, {}
    for id, st in pairs(E.Stories) do
        if not byDelve[st.delve] then
            byDelve[st.delve] = {}
            order[#order + 1] = st.delve
        end
        table.insert(byDelve[st.delve], id)
    end
    for _, d in ipairs(E.DelveData or {}) do zones[d.name] = d.zone end
    table.sort(order, function(a, b) return sortName(a) < sortName(b) end)

    local GRADE_ORDER = E.DelveList.GRADE_ORDER
    for _, delve in ipairs(order) do
        local ids = byDelve[delve]
        table.sort(ids, function(a, b)
            local ga, gb = GRADE_ORDER[E.Stories[a].grade or ""] or 7, GRADE_ORDER[E.Stories[b].grade or ""] or 7
            if ga ~= gb then return ga < gb end
            return E:StoryName(a) < E:StoryName(b)
        end)
        local title = E.DelveList.cc("label") .. delve .. "|r" .. (zones[delve] and ("   " .. zones[delve]) or "")
        local card = stack(self:CreateGroup(content, title))
        local list = CreateFrame("Frame", nil, content)
        list._euiFill = true
        list:SetHeight(#ids * ROW)
        for i, id in ipairs(ids) do rows[#rows + 1] = storyRow(self, list, id, i) end
        card:Add(list, { height = #ids * ROW, fill = true })
    end
end

local function footer(self, bar)
    local reset = self:CreateButton(bar, L["Reset all to the compendium"], nil, function()
        E:ShowDialog({
            text = L["Reset every story to its compendium grade?"],
            button1 = L["Yes"], button2 = L["Cancel"], danger = true,
            onAccept = function() E:ResetStoryGrades() end,
        })
    end, nil, "danger")
    reset:SetPoint("RIGHT")
end

E.ui:RegisterTab({
    id = "grades", title = L["Story Grades"], order = 35, icon = E.ui:Texture("icon-stats"), footer = footer,
    build = function(self, content)
        local stack = E.CardStack(self)
        introCard(self, content, stack)
        delveCards(self, content, stack)
        repaint()
        self:MeasureContent(content)
    end,
    refresh = function() repaint() end,
})

E:RegisterCallback("StoryGradesChanged", repaint)
