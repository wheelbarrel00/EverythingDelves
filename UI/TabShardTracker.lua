local E = EverythingDelves
local L = E.L

local ipairs, type, time = ipairs, type, time
local math_floor, math_max, math_min, math_ceil, math_abs = math.floor, math.max, math.min, math.ceil, math.abs
local string_format = string.format
local table_insert, table_sort, wipe = table.insert, table.sort, wipe

local PAD_TOP, PAD_LEFT, PAD_RIGHT, PAD_BOTTOM, GROUP_GAP = 20, 24, 14, 28, 22
local ROW, LIST_ROW, HINT_ROW, ITEM_GAP, COL_GAP, PAIR_GAP = 44, 28, 36, 12, 12, 24
local BAR_LABEL, ICON, CHECK, BUTTON, BUTTON_GAP, DIM = 160, 16, 14, 24, 10, 0.4
local WARN_PAD, WARN_LINE, EMPTY_ROW, SIDE_GAP = 10, 18, 52, 10
local CREST_COLS, SOURCE_COLS = { 90, 100, 110 }, { 70, 100, 110 }
local WQ_ZONE, WQ_SHARDS = 150, 70
local ED_TEXTURES = "Interface\\AddOns\\EverythingDelves\\Media\\Textures\\"

local WQ_CURRENCY = E.CurrencyIDs.cofferKeyShards
local MAX_WQ_ROWS = 12

-- The titles are English fallbacks for QuestTitle
local SPECIAL_ASSIGNMENTS = {
    { questID = 93013, unlockID = 94391, title = "Push back the Light" },
    { questID = 92063, unlockID = 94390, title = "A Hunter's Regret" },
    { questID = 92145, unlockID = 92848, title = "The Grand Magister's Drink" },
    { questID = 91796, unlockID = 94866, title = "Ours Once More!" },
    { questID = 93244, unlockID = 94795, title = "Agents of the Shield" },
    { questID = 92139, unlockID = 95435, title = "Shade and Claw" },
    { questID = 91390, unlockID = 94865, title = "What Remains of a Temple Broken" },
    { questID = 93438, unlockID = 94743, title = "Precision Excision" },
}
local SA_WEEKLY_MAX = 3

local WEEKLY_DELVE_QUESTS = {
    { questID = E.WEEKLY_DELVE_QUEST_ID, title = "Midnight: Delves" },
}

local function GetCurrencyFull(currencyID)
    if C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo then
        local info = C_CurrencyInfo.GetCurrencyInfo(currencyID)
        if info then
            return info.quantity or 0,
                   info.maxWeeklyQuantity or 0,
                   info.quantityEarnedThisWeek or 0
        end
    end
    return 0, 0, 0
end

local function GetCurrency(currencyID)
    return (GetCurrencyFull(currencyID))
end

local function FormatNumber(n)
    if n < 1000 then return tostring(n) end
    local s = tostring(n)
    local pos = #s % 3
    if pos == 0 then pos = 3 end
    local formatted = s:sub(1, pos)
    for i = pos + 1, #s, 3 do
        formatted = formatted .. "," .. s:sub(i, i + 2)
    end
    return formatted
end

-- The Session Tracker's phrases carry their own colors, which the library's look drops
local function StripCodes(s)
    return (s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
end

local function Done(questID)
    return C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted and C_QuestLog.IsQuestFlaggedCompleted(questID) or false
end

-- Asked once a session, since an answer redraws the page and the redraw would ask again
local titleAsked = {}

local function QuestTitle(questID, fallback)
    local title = C_QuestLog and C_QuestLog.GetTitleForQuestID and C_QuestLog.GetTitleForQuestID(questID)
    if type(title) == "string" and title ~= "" then return title end
    if not titleAsked[questID] and C_QuestLog and C_QuestLog.RequestLoadQuestByID then
        titleAsked[questID] = true
        C_QuestLog.RequestLoadQuestByID(questID)
    end
    return fallback
end

-- Cached for RefreshSessionTimer so the per-second tick avoids API table churn.
local cachedShards = 0
local cachedKeys   = 0

local questLineCache = {}
local cachedUcIcon = nil

local saActiveBuf  = nil
local saLookupBuf  = nil

local function SourceProgress(src)
    local done, total = 0, 0
    if src.questLineID and C_QuestLine and C_QuestLine.GetQuestLineQuests then
        local quests = questLineCache[src.questLineID]
        if not quests then
            quests = C_QuestLine.GetQuestLineQuests(src.questLineID) or {}
            -- A cold read comes back empty, so only a filled list is kept
            if #quests > 0 then questLineCache[src.questLineID] = quests end
        end
        total = #quests
        for _, qid in ipairs(quests) do
            if Done(qid) then done = done + 1 end
        end
    elseif src.questIDs then
        total = #src.questIDs
        for _, qid in ipairs(src.questIDs) do
            if Done(qid) then done = done + 1 end
        end
    end
    return done, total
end

-- A card centers a control in its row but never sizes it, and a row frame left with no height came up blank
-- after a cold login
local function Row(content, height)
    local f = CreateFrame("Frame", nil, content)
    if height then f:SetHeight(height) end
    return f
end

local function Bar(ui, row, left, right)
    local bar = ui:CreateProgressBar(row)
    bar:SetPoint("LEFT", left, "RIGHT", ITEM_GAP, 0)
    bar:SetPoint("RIGHT", right, "LEFT", -ITEM_GAP, 0)
    return bar
end

local function Check(ui, row)
    local t = row:CreateTexture(nil, "ARTWORK")
    t:SetSize(CHECK, CHECK)
    t:SetTexture(ui:Texture("check"))
    t:SetVertexColor(ui:Color("label"))
    return t
end

local function PlaceCells(row, widths)
    local right = 0
    for i = #widths, 1, -1 do
        local fs = row.cells[i + 1]
        fs:ClearAllPoints()
        fs:SetPoint("RIGHT", row, "RIGHT", -right, 0)
        fs:SetWidth(widths[i])
        right = right + widths[i] + COL_GAP
    end
    local first = row.cells[1]
    first:ClearAllPoints()
    first:SetPoint("LEFT", row, "LEFT", row.firstX, 0)
    first:SetPoint("RIGHT", row, "RIGHT", -right, 0)
end

local function Cells(ui, row, widths, style, iconSize)
    row.cells = {}
    for i = #widths, 1, -1 do
        local fs = ui:CreateText(row, "", style)
        fs:SetWordWrap(false)
        fs:SetJustifyH("RIGHT")
        row.cells[i + 1] = fs
    end
    row.firstX = 0
    if iconSize then
        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(iconSize, iconSize)
        row.icon:SetPoint("LEFT")
        row.firstX = iconSize + 8
    end
    local first = ui:CreateText(row, "", style)
    first:SetWordWrap(false)
    row.cells[1] = first
    PlaceCells(row, widths)
end

local function FitColumns(head, rows, base)
    local widths = {}
    for i, w in ipairs(base) do
        local fs = head.cells[i + 1]
        fs:SetWidth(0)
        widths[i] = math_max(w, math_ceil(fs:GetStringWidth() or 0) + 1)
    end
    PlaceCells(head, widths)
    for _, row in ipairs(rows) do PlaceCells(row, widths) end
end

local function CheckBefore(check, fs, shown)
    check:SetShown(shown)
    check:ClearAllPoints()
    check:SetPoint("RIGHT", fs, "RIGHT", -(math_ceil(fs:GetStringWidth() or 0) + 6), 0)
end

local function SideText(ui, card)
    local fs = ui:CreateText(card, "", "hint")
    fs:SetPoint("LEFT", card.label, "RIGHT", SIDE_GAP, 0)
    fs:SetWordWrap(false)
    return fs
end

local function BuildWarning(ui, content, v)
    local f = CreateFrame("Frame", nil, content)
    ui:Paint(f, "surface", "danger")
    f.title = ui:CreateText(f, L["(!) Low shards!"], "navActive")
    f.title:SetTextColor(ui:Color("danger"))
    f.title:SetPoint("TOPLEFT", ui:Spacing("rowPadding"), -WARN_PAD)
    f.body = ui:CreateText(f, "", "label")
    f.body:SetPoint("TOPLEFT", ui:Spacing("rowPadding"), -(WARN_PAD + WARN_LINE))
    f.body:SetPoint("RIGHT", -ui:Spacing("rowPadding"), 0)
    f.body:SetWordWrap(false)
    f:SetHeight(WARN_PAD * 2 + WARN_LINE * 2)
    v.warning = f
    return f
end

local function BuildOverview(ui, content, v)
    local card = ui:CreateGroup(content, L["Currency Overview"])
    local top = Row(content, ROW)
    top.values, top.icons = {}, {}
    local prev
    for i, label in ipairs({ L["Coffer Key Shards:"], L["Bountiful Keys:"], L["Undercoins:"] }) do
        local icon = top:CreateTexture(nil, "ARTWORK")
        icon:SetSize(ICON, ICON)
        if prev then icon:SetPoint("LEFT", prev, "RIGHT", PAIR_GAP, 0) else icon:SetPoint("LEFT") end
        local lbl = ui:CreateText(top, label, "label")
        lbl:SetPoint("LEFT", icon, "RIGHT", 8, 0)
        local value = ui:CreateText(top, "", "value")
        value:SetPoint("LEFT", lbl, "RIGHT", 10, 0)
        top.icons[i], top.values[i] = icon, value
        prev = value
    end
    card:Add(top, { height = ROW, fill = true })

    local function barRow(label)
        local row = Row(content, ROW)
        row.label = ui:CreateText(row, label, "label")
        row.label:SetPoint("LEFT")
        row.label:SetWidth(BAR_LABEL)
        row.label:SetWordWrap(false)
        row.value = ui:CreateText(row, "", "value")
        row.value:SetPoint("RIGHT")
        row.bar = Bar(ui, row, row.label, row.value)
        card:Add(row, { height = ROW, fill = true })
        local note = ui:CreateText(content, "", "hint")
        note:SetWordWrap(true)
        card:Add(note, { height = HINT_ROW, fill = true })
        return row, note
    end
    v.nextKey, v.nextKeyNote = barRow(L["Shards to Next Key"])
    v.weeklyCap, v.weeklyCapNote = barRow(L["Weekly Shard Cap"])
    v.overviewTop, v.overviewCard = top, card
    return card
end

local function BuildCrests(ui, content, v)
    -- Always this label: a name taken from the currency only worked in English.
    local card = ui:CreateGroup(content, L["Crests"])
    local head = Row(content, LIST_ROW)
    Cells(ui, head, CREST_COLS, "groupLabel")
    head.cells[1]:SetText(L["Crest"])
    local tips = {
        { L["On Hand"], L["How many of this crest you currently have available to spend on gear upgrades."] },
        { L["Season Max"], L["The seasonal cap on this crest. For some crests it limits how many you can earn all season. For others it limits how many you can hold at once, and spending frees room again."]
            .. "\n\n" .. L["Shows \"Uncapped\" when Blizzard has lifted the cap for the rest of the season."] },
        { L["Season Total"], L["How many of this crest you've earned in total this season - including any you've already spent on upgrades."]
            .. "\n\n" .. L["Usually higher than \"On Hand\" for that reason."] },
    }
    for i, tip in ipairs(tips) do
        head.cells[i + 1]:SetText(tip[1])
        ui:AttachTooltip(head.cells[i + 1], tip[1], tip[2])
    end
    card:Add(head, { height = LIST_ROW, fill = true })
    v.crestHead, v.crestRows = head, {}
    for i, crest in ipairs(E.Crests) do
        local row = Row(content, LIST_ROW)
        Cells(ui, row, CREST_COLS, "label", CHECK)
        row.crest = crest
        card:Add(row, { height = LIST_ROW, fill = true })
        v.crestRows[i] = row
    end
    v.crestCard = card
    return card
end

local function BuildSources(ui, content, v)
    local card = ui:CreateGroup(content, L["Weekly Shard Sources"])
    v.weeklyTotal = ui:CreateText(content, "", "label")
    card:Add(v.weeklyTotal, { height = HINT_ROW, fill = true })
    local head = Row(content, LIST_ROW)
    Cells(ui, head, SOURCE_COLS, "groupLabel")
    for i, label in ipairs({ L["Source"], L["Per"], L["Weekly Cap"], L["Status"] }) do head.cells[i]:SetText(label) end
    card:Add(head, { height = LIST_ROW, fill = true })
    v.sourceHead, v.sourceRows = head, {}
    for i, src in ipairs(E.ShardSources) do
        local row = Row(content, LIST_ROW)
        Cells(ui, row, SOURCE_COLS, "label")
        row.check = Check(ui, row)
        row.src = src
        card:Add(row, { height = LIST_ROW, fill = true })
        v.sourceRows[i] = row
    end
    local foot = ui:CreateText(content, L["* Value unconfirmed - may differ in game"], "hint")
    card:Add(foot, { height = HINT_ROW, fill = true })
    v.sourcesCard = card
    return card
end

local function BuildSession(ui, content, v)
    local card = ui:CreateGroup(content, L["Session Tracker"])
    v.session = {}
    for i = 1, 4 do
        local fs = ui:CreateText(content, "", "label")
        fs:SetWordWrap(false)
        card:Add(fs, { height = LIST_ROW, fill = true })
        v.session[i] = fs
    end
    local note = ui:CreateText(content, L["Tracking starts when you first open this tab, not at login. Resets on /reload."], "hint")
    note:SetWordWrap(true)
    card:Add(note, { height = HINT_ROW, fill = true })
    v.sessionCard = card
    return card
end

local function QuestRow(ui, content, card)
    local row = Row(content, LIST_ROW)
    row.check = Check(ui, row)
    row.check:SetPoint("LEFT")
    row.text = ui:CreateText(row, "", "label")
    row.text:SetPoint("LEFT", row, "LEFT", CHECK + 8, 0)
    row.text:SetPoint("RIGHT")
    row.text:SetWordWrap(false)
    card:Add(row, { height = LIST_ROW, fill = true })
    return row
end

local function BuildAssignments(ui, content, v)
    local card = ui:CreateGroup(content, L["Special Assignments"])
    v.saSide = SideText(ui, card)
    v.saRows = {}
    for i, sa in ipairs(SPECIAL_ASSIGNMENTS) do
        local row = QuestRow(ui, content, card)
        row.sa = sa
        v.saRows[i] = row
    end
    v.saCard = card
    return card
end

local function BuildWeekly(ui, content, v)
    local card = ui:CreateGroup(content, L["Weekly Delve Quests"])
    v.weeklyRows = {}
    for i, quest in ipairs(WEEKLY_DELVE_QUESTS) do
        local row = QuestRow(ui, content, card)
        row.quest = quest
        v.weeklyRows[i] = row
    end
    v.weeklyCard = card
    return card
end

local function QuestLocation(wq)
    if wq and C_TaskQuest and C_TaskQuest.GetQuestLocation then
        return C_TaskQuest.GetQuestLocation(wq.questID, wq.zoneID)
    end
end

local function NewWQRow(ui, content)
    local row = Row(content, LIST_ROW)
    row.zone = ui:CreateText(row, "", "label")
    row.zone:SetPoint("LEFT")
    row.zone:SetWidth(WQ_ZONE)
    row.zone:SetWordWrap(false)
    row.tt = E.DelveList.IconButton(row, ED_TEXTURES .. "icon-tomtom")
    row.tt:SetPoint("RIGHT")
    row.pin = E.DelveList.IconButton(row, ui:Texture("icon-map"))
    row.pin:SetPoint("RIGHT", row.tt, "LEFT", -BUTTON_GAP, 0)
    row.amount = ui:CreateText(row, "", "label")
    row.amount:SetPoint("RIGHT", row.pin, "LEFT", -COL_GAP, 0)
    row.amount:SetWidth(WQ_SHARDS)
    row.amount:SetJustifyH("RIGHT")
    row.title = ui:CreateText(row, "", "label")
    row.title:SetPoint("LEFT", row, "LEFT", WQ_ZONE + COL_GAP, 0)
    row.title:SetPoint("RIGHT", row.amount, "LEFT", -COL_GAP, 0)
    row.title:SetWordWrap(false)

    -- Both read self.wq, which each refresh sets, so a pooled row's scripts are bound once
    row.pin:SetScript("OnClick", function(self)
        local x, y = QuestLocation(self.wq)
        if x and y and E:SetWaypoint(self.wq.zoneID, x * 100, y * 100) then
            E.DelveList.Flash(self)
        end
    end)
    row.pin:SetScript("OnEnter", function(self) ui:ShowTooltip(self, L["Pin"], nil) end)
    row.pin:SetScript("OnLeave", function() ui:HideTooltip() end)
    row.tt:SetScript("OnClick", function(self)
        if not E:IsTomTomLoaded() then return end
        local x, y = QuestLocation(self.wq)
        if x and y and E:AddTomTomWaypoint(self.wq.zoneID, x * 100, y * 100, self.wq.title) then
            E.DelveList.Flash(self)
        end
    end)
    row.tt:SetScript("OnEnter", function(self)
        if E:IsTomTomLoaded() then
            ui:ShowTooltip(self, L["TomTom Waypoint"], L["Add an arrow waypoint via TomTom."])
        else
            ui:ShowTooltip(self, L["TomTom Not Installed"], L["Install the TomTom addon to use arrow waypoints."])
        end
    end)
    row.tt:SetScript("OnLeave", function() ui:HideTooltip() end)
    return row
end

local function BuildWorldQuests(ui, content, v)
    local card = ui:CreateGroup(content, L["Coffer Shard World Quests"])
    v.wqSide = SideText(ui, card)

    local top = Row(content, ROW)
    top.refresh = ui:CreateButton(top, L["Refresh"], nil, function() if v.onWQRefresh then v.onWQRefresh() end end)
    top.refresh:SetScript("OnEnter", function(self)
        ui:ShowTooltip(self, L["Refresh WQs"], L["Force rescan all Midnight zones for\nCoffer Key Shard world quests."])
    end)
    top.refresh:SetScript("OnLeave", function() ui:HideTooltip() end)
    top.refresh:SetPoint("RIGHT")
    top.note = ui:CreateText(top, L["WQs rewarding Coffer Key Shards. Rewards rotate - click Refresh to update."], "label")
    top.note:SetPoint("LEFT")
    top.note:SetPoint("RIGHT", top.refresh, "LEFT", -ITEM_GAP, 0)
    top.note:SetWordWrap(true)
    card:Add(top, { height = ROW, fill = true })
    v.wqTop = top

    v.wqCap = ui:CreateText(content, L["Weekly shard cap reached \226\128\148 shards will not be awarded until reset."], "label")
    v.wqCap:SetWordWrap(true)
    card:Add(v.wqCap, { height = HINT_ROW, fill = true })

    local head = Row(content, LIST_ROW)
    head.zone = ui:CreateText(head, L["Zone"], "groupLabel")
    head.zone:SetPoint("LEFT")
    head.title = ui:CreateText(head, L["Quest"], "groupLabel")
    head.title:SetPoint("LEFT", head, "LEFT", WQ_ZONE + COL_GAP, 0)
    head.amount = ui:CreateText(head, L["Shards"], "groupLabel")
    head.amount:SetPoint("RIGHT", head, "RIGHT", -(BUTTON * 2 + BUTTON_GAP + COL_GAP), 0)
    head.amount:SetWidth(WQ_SHARDS)
    head.amount:SetJustifyH("RIGHT")
    card:Add(head, { height = LIST_ROW, fill = true })
    v.wqHead = head

    v.wqRows = {}
    for i = 1, MAX_WQ_ROWS do
        local row = NewWQRow(ui, content)
        card:Add(row, { height = LIST_ROW, fill = true })
        v.wqRows[i] = row
    end

    local empty = Row(content, EMPTY_ROW)
    empty.line1 = ui:CreateText(empty, L["No Coffer Key Shard WQs found. Click Refresh to rescan."], "label")
    empty.line1:SetPoint("TOPLEFT", 0, -9)
    empty.line1:SetPoint("TOPRIGHT", 0, -9)
    empty.line2 = ui:CreateText(empty, L["Tip: Open your World Map to each Midnight zone first to load quest data."], "hint")
    empty.line2:SetPoint("TOPLEFT", empty.line1, "BOTTOMLEFT", 0, -4)
    empty.line2:SetPoint("TOPRIGHT", empty.line1, "BOTTOMRIGHT", 0, -4)
    card:Add(empty, { height = EMPTY_ROW, fill = true })
    v.wqEmpty = empty

    local foot = ui:CreateText(content, L["* Tip: Visit zone maps to load WQ data before refreshing."], "hint")
    card:Add(foot, { height = HINT_ROW, fill = true })
    v.wqCard = card
    return card
end

local function RenderOverview(v, shards, keys, weeklyCap, weeklyEarned, width)
    local labelW = BAR_LABEL
    for _, row in ipairs({ v.nextKey, v.weeklyCap }) do
        row.label:SetWidth(0)
        labelW = math_max(labelW, math_ceil(row.label:GetStringWidth() or 0) + 1)
    end
    labelW = math_max(1, math_min(labelW, math_floor((width - PAD_LEFT - PAD_RIGHT) / 2)))
    v.nextKey.label:SetWidth(labelW)
    v.weeklyCap.label:SetWidth(labelW)

    local top = v.overviewTop
    top.icons[1]:SetTexture(E.CachedIcons.cofferShard or C_Item.GetItemIconByID(E.ItemIcons.cofferShard))
    top.icons[2]:SetTexture(E.CachedIcons.cofferKey or C_Item.GetItemIconByID(E.ItemIcons.cofferKey))
    if not cachedUcIcon then
        local ucInfo = C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo(E.CurrencyIDs.undercoins)
        if ucInfo and ucInfo.iconFileID then
            cachedUcIcon = ucInfo.iconFileID
        end
    end
    if cachedUcIcon then top.icons[3]:SetTexture(cachedUcIcon) end
    top.values[1]:SetText(FormatNumber(shards))
    top.values[2]:SetText(FormatNumber(keys))
    top.values[3]:SetText(FormatNumber(GetCurrency(E.CurrencyIDs.undercoins)))

    local partial = shards % E.SHARDS_PER_KEY
    if partial == 0 and shards > 0 then
        partial = E.SHARDS_PER_KEY
    end
    v.nextKey.bar:SetProgress(partial / E.SHARDS_PER_KEY)
    v.nextKey.value:SetText(partial .. " / " .. E.SHARDS_PER_KEY)
    v.nextKeyNote:SetText(L["Progress toward next key - %s shards remaining"]:format(E.SHARDS_PER_KEY - partial))

    v.weeklyCap:SetShown(weeklyCap > 0)
    if weeklyCap > 0 then
        v.weeklyCap.bar:SetProgress(weeklyEarned / weeklyCap)
        v.weeklyCap.value:SetText(weeklyEarned .. " / " .. weeklyCap)
        v.weeklyCapNote:SetText(L["Weekly shard cap - %s shards remaining this week"]:format(math_max(0, weeklyCap - weeklyEarned)))
    else
        v.weeklyCapNote:SetText(L["Weekly shard cap data unavailable"])
    end
    v.overviewCard:Layout()
end

local function RenderCrests(ui, v)
    FitColumns(v.crestHead, v.crestRows, CREST_COLS)
    for _, row in ipairs(v.crestRows) do
        local info = C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo and C_CurrencyInfo.GetCurrencyInfo(row.crest.id)
        local c = row.cells
        if info then
            if info.iconFileID then row.icon:SetTexture(info.iconFileID) end
            local qty    = info.quantity or 0
            local season = info.totalEarned or 0
            -- Zero means uncapped (a hotfix lifted the S1 caps). Read live so a
            -- reintroduced cap shows up without an addon update.
            local seasonMax = info.maxQuantity or 0
            -- maxQuantity caps totalEarned only when the currency says so,
            -- else it caps what you hold and spending frees room again.
            local capOnTotal = info.useTotalEarnedForMaxQty
            local atCap = seasonMax > 0 and ((capOnTotal and season or qty) >= seasonMax)
            c[1]:SetText((info.name and info.name ~= "") and info.name or row.crest.label)
            c[1]:SetTextColor(ui:Color("label"))
            c[2]:SetText(FormatNumber(qty))
            c[2]:SetTextColor(ui:Color((atCap and not capOnTotal) and "danger" or "text"))
            c[3]:SetText(seasonMax > 0 and FormatNumber(seasonMax) or L["Uncapped"])
            c[3]:SetTextColor(ui:Color(seasonMax > 0 and "label" or "muted"))
            c[4]:SetText(season > 0 and FormatNumber(season) or "-")
            c[4]:SetTextColor(ui:Color((atCap and capOnTotal) and "danger" or (season > 0 and "label" or "muted")))
        else
            c[1]:SetText(row.crest.label)
            for i = 1, 4 do c[i]:SetTextColor(ui:Color("muted")) end
            for i = 2, 4 do c[i]:SetText("-") end
        end
    end
    v.crestCard:Layout()
end

local function RenderSources(ui, v, weeklyCap)
    -- Live cap from the currency API (600 in S1), not a sum of rows, so it never goes stale.
    v.weeklyTotal:SetShown(weeklyCap > 0)
    v.weeklyTotal:SetText(E.DelveList.cc("muted") .. L["Weekly cap:"] .. "|r " .. L["%s shards/week"]:format(FormatNumber(weeklyCap)))
    FitColumns(v.sourceHead, v.sourceRows, SOURCE_COLS)
    for _, row in ipairs(v.sourceRows) do
        local src, c = row.src, row.cells
        c[1]:SetText(src.name .. (src.unconfirmed and " *" or ""))
        c[2]:SetText(tostring(src.shardsEach) .. (src.unconfirmed and "*" or ""))
        if src.weeklyMax then
            local maxShards = type(src.shardsEach) == "number" and src.shardsEach * src.weeklyMax or 0
            c[3]:SetText(src.weeklyMax .. "x" .. (maxShards > 0 and (" (" .. maxShards .. ")") or ""))
            c[3]:SetTextColor(ui:Color("label"))
        else
            c[3]:SetText("-")
            c[3]:SetTextColor(ui:Color("muted"))
        end
        local finished = false
        if src.trackable then
            local done, total = SourceProgress(src)
            if total > 0 then
                finished = done >= total
                c[4]:SetText(done .. " / " .. total)
            else
                c[4]:SetText(L["Trackable"])
            end
            c[4]:SetTextColor(ui:Color(finished and "text" or "label"))
        else
            c[4]:SetText(L["Manual"])
            c[4]:SetTextColor(ui:Color("muted"))
        end
        CheckBefore(row.check, c[4], finished)
    end
    v.sourcesCard:Layout()
end

local function QuestLine(ui, row, done, text, color)
    row.check:SetShown(done)
    row.text:SetText(text)
    row.text:SetTextColor(ui:Color(color))
end

local function RenderAssignments(ui, v)
    local completed, active = 0, 0
    for _, row in ipairs(v.saRows) do
        local sa = row.sa
        local title = QuestTitle(sa.questID, sa.title)
        local unlocked = not sa.unlockID or not (C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted) or Done(sa.unlockID)
        if not unlocked then
            QuestLine(ui, row, false, L["SA: %s - Locked"]:format(title), "muted")
        elseif Done(sa.questID) then
            completed = completed + 1
            QuestLine(ui, row, true, L["SA: %s"]:format(title), "label")
        elseif C_QuestLog and C_QuestLog.IsOnQuest and C_QuestLog.IsOnQuest(sa.questID) then
            active = active + 1
            QuestLine(ui, row, false, L["SA: %s - active"]:format(title), "text")
        else
            QuestLine(ui, row, false, L["SA: %s"]:format(title), "label")
        end
    end
    v.saSide:SetText(L["%s / %d completed"]:format(completed, SA_WEEKLY_MAX)
        .. (active > 0 and ("  " .. L["%d active"]:format(active)) or ""))
    for _, row in ipairs(v.weeklyRows) do
        local title = QuestTitle(row.quest.questID, row.quest.title)
        if Done(row.quest.questID) then
            QuestLine(ui, row, true, title, "label")
        else
            QuestLine(ui, row, false, L["%s - not yet done"]:format(title), "label")
        end
    end
    v.saCard:Layout()
    v.weeklyCard:Layout()
end

local function RenderWorldQuests(ui, v, wqs, isAtCap)
    v.wqSide:SetText(L["%s active"]:format(#wqs))
    v.wqTop.refresh:Fit()
    v.wqCap:SetShown(isAtCap)
    v.wqHead:SetShown(#wqs > 0)
    v.wqEmpty:SetShown(#wqs == 0)
    -- Dimmed at cap but still clickable
    local color = isAtCap and "muted" or "label"
    for i, row in ipairs(v.wqRows) do
        local wq = wqs[i]
        row:SetShown(wq ~= nil)
        if wq then
            row.zone:SetText(wq.zone)
            row.title:SetText(wq.title)
            row.amount:SetText(tostring(wq.amount))
            for _, fs in ipairs({ row.zone, row.title, row.amount }) do fs:SetTextColor(ui:Color(color)) end
            row.pin.wq, row.tt.wq = wq, wq
            row.pin:SetAlpha(isAtCap and DIM or 1)
            row.tt:SetAlpha((isAtCap or not E:IsTomTomLoaded()) and DIM or 1)
        end
    end
    v.wqCard:Layout()
end

E:RegisterModule(function()
    local ui = E.ui
    local frame = CreateFrame("Frame", "EverythingDelvesTab4Content")
    local area = ui:CreateScrollArea(frame, { clearGrip = true })
    area:SetAllPoints(frame)
    local content = area.content

    local v = {}
    local warning = BuildWarning(ui, content, v)
    local cards = {
        BuildOverview(ui, content, v), BuildCrests(ui, content, v), BuildSources(ui, content, v),
        BuildSession(ui, content, v), BuildAssignments(ui, content, v), BuildWeekly(ui, content, v),
        BuildWorldQuests(ui, content, v),
    }

    local wqCache      = {}
    local wqEntryPool  = {}
    local wqCacheTime  = 0
    local WQ_CACHE_TTL = 60
    local wqRetryPending = false
    local wqRetriesUsed  = 0
    local WQ_MAX_RETRIES = 1
    local mapsPrimed   = {}
    local zoneNameCache = {}
    local seenQuestIDs = {}

    local Render

    local function wqSortFunc(a, b)
        if a.zone == b.zone then return a.title < b.title end
        return a.zone < b.zone
    end

    local function ScanCofferShardWQs(forceRescan)
        if not forceRescan and wqCacheTime > 0
                and (time() - wqCacheTime) < WQ_CACHE_TTL then
            return wqCache
        end

        for i = #wqCache, 1, -1 do
            local e = wqCache[i]
            wqCache[i] = nil
            wipe(e)
            wqEntryPool[#wqEntryPool + 1] = e
        end
        wipe(seenQuestIDs)
        if not (C_TaskQuest and C_TaskQuest.GetQuestsOnMap
                and C_QuestLog and C_QuestLog.GetQuestRewardCurrencies) then
            return wqCache
        end

        for _, zone in ipairs(E.Zones) do
            local zoneID = zone.mapID
            -- Prime map data once per session so the client loads the zone's WQs.
            if not mapsPrimed[zoneID] then
                if C_Map and C_Map.GetMapInfo then
                    C_Map.GetMapInfo(zoneID)
                end
                if C_MapExplorationInfo
                        and C_MapExplorationInfo.GetExploredMapTextures then
                    C_MapExplorationInfo.GetExploredMapTextures(zoneID)
                end
                mapsPrimed[zoneID] = true
            end

            local quests = C_TaskQuest.GetQuestsOnMap(zoneID)

            if quests then
                for _, qData in ipairs(quests) do
                    local qid = qData.questID
                    -- GetQuestsOnMap returns subzone quests too, so dedupe across parent scans.
                    if qid and qid > 0 and not seenQuestIDs[qid]
                            and C_QuestLog.IsWorldQuest
                            and C_QuestLog.IsWorldQuest(qid)
                            and not Done(qid)
                    then
                        local currencies = C_QuestLog.GetQuestRewardCurrencies(qid)
                        if currencies then
                            for _, ci in ipairs(currencies) do
                                if ci.currencyID == WQ_CURRENCY then
                                    local title = L["Unknown Quest"]
                                    if C_TaskQuest.GetQuestInfoByQuestID then
                                        title = C_TaskQuest.GetQuestInfoByQuestID(qid) or title
                                    end
                                    -- Use the quest's own mapID (its location), not the scanned parent.
                                    local questMapID = qData.mapID or zoneID
                                    if not zoneNameCache[questMapID] then
                                        local mi = C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(questMapID)
                                        zoneNameCache[questMapID] = (mi and mi.name) or L["Zone %d"]:format(questMapID)
                                    end
                                    seenQuestIDs[qid] = true
                                    local n = #wqEntryPool
                                    local entry
                                    if n > 0 then
                                        entry = wqEntryPool[n]
                                        wqEntryPool[n] = nil
                                    else
                                        entry = {}
                                    end
                                    entry.questID = qid
                                    entry.title   = title
                                    entry.zone    = zoneNameCache[questMapID]
                                    entry.zoneID  = questMapID
                                    entry.amount  = ci.totalRewardAmount or 0
                                    table_insert(wqCache, entry)
                                    break
                                end
                            end
                        end
                    end
                end
            end
        end

        table_sort(wqCache, wqSortFunc)
        wqCacheTime = time()

        -- Empty scan: retry once after 3s (unvisited-zone map data may be unloaded).
        -- The cap stops it rescheduling forever on chars with no shard WQs.
        if #wqCache == 0
                and not wqRetryPending
                and wqRetriesUsed < WQ_MAX_RETRIES then
            wqRetryPending = true
            wqRetriesUsed  = wqRetriesUsed + 1
            C_Timer.After(3, function()
                wqRetryPending = false
                wqCacheTime = 0
                if Render and frame:IsVisible() then
                    Render(true)
                end
            end)
        elseif #wqCache > 0 then
            wqRetriesUsed = 0
        end

        return wqCache
    end

    local sessionBaseline = nil

    local function EnsureBaseline()
        if not sessionBaseline then
            sessionBaseline = {
                shards = GetCurrency(E.CurrencyIDs.cofferKeyShards),
                keys   = GetCurrency(E.CurrencyIDs.bountifulKeys),
                time   = time(),
            }
        end
    end

    -- Answers whether the rate line should show
    local function RefreshSessionTimer()
        EnsureBaseline()
        local sessShards = cachedShards - sessionBaseline.shards
        local sessKeys   = cachedKeys   - sessionBaseline.keys
        local sessTime   = time() - sessionBaseline.time

        local hours   = math_floor(sessTime / 3600)
        local minutes = math_floor((sessTime % 3600) / 60)
        local seconds = sessTime % 60
        local elapsed = string_format("%d:%02d:%02d", hours, minutes, seconds)

        local s = v.session
        s[1]:SetText(StripCodes(string_format(L["|cFF999999Session time: |r|cFFE0E0E0%s|r"], elapsed)))
        s[2]:SetText(StripCodes(sessShards >= 0
            and string_format(L["|cFF999999Shards earned: |r|cFFFFD700+%s|r"], FormatNumber(sessShards))
            or  string_format(L["|cFF999999Shards earned: |r|cFFFF3333%s|r"], FormatNumber(sessShards))))
        s[3]:SetText(StripCodes(sessKeys >= 0
            and string_format(L["|cFF999999Keys earned: |r|cFFFFD700+%d|r"], sessKeys)
            or  string_format(L["|cFF999999Keys earned: |r|cFFFF3333%d|r"], sessKeys)))
        local rate = sessTime >= 60 and sessShards > 0
        if rate then
            local perHour = math_floor(sessShards / (sessTime / 3600))
            s[4]:SetText(StripCodes(string_format(L["|cFF999999Rate: ~|r|cFFFFD700%s shards/hour|r"], FormatNumber(perHour))))
        end
        return rate
    end

    local lastWidth = 0
    local function ViewWidth()
        local w = area.scroll:GetWidth() or 0
        if w <= 0 then w = (frame:GetWidth() or 0) - 10 end
        return math_max(1, w)
    end

    Render = function(forceWQRescan)
        local width = ViewWidth()
        lastWidth = width
        content:SetWidth(width)

        local weeklyCap, weeklyEarned
        cachedShards, weeklyCap, weeklyEarned = GetCurrencyFull(E.CurrencyIDs.cofferKeyShards)
        cachedKeys = GetCurrency(E.CurrencyIDs.bountifulKeys)
        local isAtCap = weeklyCap > 0 and weeklyEarned >= weeklyCap

        local threshold = E.db and E.db.lowShardThreshold or 100
        local low = E.db and E.db.lowShardWarning and cachedShards < threshold
        warning:SetShown(low and true or false)
        if low then
            warning.body:SetText(L["You have %s shards, below your %s threshold."]:format(FormatNumber(cachedShards),
                FormatNumber(threshold)))
        end

        RenderOverview(v, cachedShards, cachedKeys, weeklyCap, weeklyEarned, width)
        RenderCrests(ui, v)
        RenderSources(ui, v, weeklyCap)
        v.session[4]:SetShown(RefreshSessionTimer())
        v.sessionCard:Layout()
        RenderAssignments(ui, v)
        RenderWorldQuests(ui, v, ScanCofferShardWQs(forceWQRescan), isAtCap)

        local y = PAD_TOP
        if low then
            warning:ClearAllPoints()
            warning:SetPoint("TOPLEFT", content, "TOPLEFT", PAD_LEFT, -y)
            warning:SetPoint("TOPRIGHT", content, "TOPRIGHT", -PAD_RIGHT, -y)
            y = y + warning:GetHeight() + GROUP_GAP
        end
        for i, card in ipairs(cards) do
            if i > 1 then y = y + GROUP_GAP end
            card:ClearAllPoints()
            card:SetPoint("TOPLEFT", content, "TOPLEFT", PAD_LEFT, -y)
            card:SetPoint("TOPRIGHT", content, "TOPRIGHT", -PAD_RIGHT, -y)
            y = y + card:GetHeight()
        end
        area:SetContentSize(width, y + PAD_BOTTOM)
    end

    v.onWQRefresh = function()
        wqCacheTime   = 0
        wqRetriesUsed = 0
        Render(true)
    end

    area.scroll:HookScript("OnSizeChanged", function(_, w)
        if frame:IsVisible() and math_abs((w or 0) - lastWidth) >= 1 then Render() end
    end)

    frame:SetScript("OnShow", function()
        EnsureBaseline()
        wqRetriesUsed = 0
        if #wqCache == 0 then wqCacheTime = 0 end
        Render()
        area:ScrollTo(0, 0)
    end)

    local timerElapsed = 0
    frame:SetScript("OnUpdate", function(_, dt)
        timerElapsed = timerElapsed + dt
        if timerElapsed >= 1 then
            timerElapsed = 0
            if frame:IsVisible() and RefreshSessionTimer() ~= (v.session[4]:IsShown() and true or false) then
                Render()
            end
        end
    end)

    -- Separate from Render so the alert fires with the page shut. It reads no page state.
    local function DetectSpecialAssignments()
        if not (E.db and E.db.alertSpecialAssignment) then return end
        if not saActiveBuf  then saActiveBuf  = {} end
        if not saLookupBuf then saLookupBuf = {} end
        wipe(saActiveBuf)
        wipe(saLookupBuf)

        for _, sa in ipairs(SPECIAL_ASSIGNMENTS) do
            local active = (not Done(sa.questID)) and C_QuestLog and C_QuestLog.IsOnQuest
                           and C_QuestLog.IsOnQuest(sa.questID)
            if active then
                table_insert(saActiveBuf, sa.questID)
            end
        end
        table_sort(saActiveBuf)

        -- SA quests are per character, so a shared baseline alerts on the wrong one.
        local store = E.db.saStateByChar
        if not store then return end
        local charKey = E.CharKey and E.CharKey() or "?"
        local saState = store[charKey]
        if not saState then
            saState = { active = {} }
            store[charKey] = saState
        end

        local storedSAs = saState.active or {}
        for _, id in ipairs(storedSAs) do saLookupBuf[id] = true end

        -- An empty baseline is ambiguous (no assignments, or never scanned). The flag lets a first scan
        -- seed silently while a later change from empty to active alerts.
        local recorded = saState.recorded or #storedSAs > 0

        local hasNew = false
        if recorded then
            for _, id in ipairs(saActiveBuf) do
                if not saLookupBuf[id] then
                    hasNew = true
                    break
                end
            end
        end

        if hasNew then
            print(E.CC.header .. "[Everything Delves]|r "
                .. L["A Special Assignment is now available! Check the Shard Tracker tab."])
        end
        saState.recorded = true
        if not saState.active then saState.active = {} end
        wipe(saState.active)
        for i = 1, #saActiveBuf do
            saState.active[i] = saActiveBuf[i]
        end
    end

    local function RefreshFromEvent()
        DetectSpecialAssignments()
        if frame:IsVisible() then Render() end
    end

    E:RegisterCallback("CurrencyUpdate", RefreshFromEvent)
    E:RegisterCallback("QuestLogUpdate", RefreshFromEvent)

    -- A title QuestTitle asked for arrives later. A failed load leaves nothing new to draw.
    local titleEvents = CreateFrame("Frame")
    pcall(titleEvents.RegisterEvent, titleEvents, "QUEST_DATA_LOAD_RESULT")
    titleEvents:SetScript("OnEvent", function(_, _, questID, success)
        if not (success and frame:IsVisible()) then return end
        for _, sa in ipairs(SPECIAL_ASSIGNMENTS) do
            if sa.questID == questID then Render() return end
        end
        for _, q in ipairs(WEEKLY_DELVE_QUESTS) do
            if q.questID == questID then Render() return end
        end
    end)

    E:RegisterTab(5, frame)
end)
