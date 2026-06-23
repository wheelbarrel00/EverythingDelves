local E = EverythingDelves

local math_max, math_min, math_floor = math.max, math.min, math.floor

-- Inline textures: the default UI font lacks the triangle glyphs (render as tofu).
local ARROW_UP   = " |TInterface\\Buttons\\Arrow-Up-Up:12:12|t"
local ARROW_DOWN = " |TInterface\\Buttons\\Arrow-Down-Up:12:12|t"

local COLUMNS = {
    { key = "name",    label = "Character", x = 12,  numeric = false },
    { key = "ilvl",    label = "iLvl",      x = 206, numeric = true  },
    { key = "keys",    label = "Keys",      x = 254, numeric = true  },
    { key = "shards",  label = "Shards",    x = 302, numeric = true  },
    { key = "bounty",  label = "Bounty",    x = 366, numeric = true  },
    { key = "vault",   label = "Vault",     x = 420, numeric = true  },
    { key = "gilded",  label = "Gilded",    x = 480, numeric = true  },
    { key = "weekly",  label = "Weekly",    x = 534, numeric = true  },
    { key = "updated", label = "Updated",   x = 598, numeric = true  },
}
local DELETE_X  = 690
local ROW_W     = 712
local ROW_H     = 22

local function ClassColorOpen(class)
    local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    return "|c" .. (c and c.colorStr or "FFE0E0E0")
end

local function FormatAgo(secs)
    if not secs or secs < 0 then return "?" end
    if secs < 60    then return "just now" end
    if secs < 3600  then return math_floor(secs / 60)    .. "m ago" end
    if secs < 86400 then return math_floor(secs / 3600)  .. "h ago" end
    return math_floor(secs / 86400) .. "d ago"
end

E:RegisterModule(function()
    local frame = CreateFrame("Frame", "EverythingDelvesTabRosterContent")

    local scrollFrame = CreateFrame("ScrollFrame", nil, frame)
    scrollFrame:SetPoint("TOPLEFT",     frame, "TOPLEFT",     0,   0)
    scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -18, 0)
    scrollFrame:EnableMouseWheel(true)

    local sc = CreateFrame("Frame")
    sc:SetSize(1, 1)
    scrollFrame:SetScrollChild(sc)
    scrollFrame:SetScript("OnSizeChanged", function(_, w) sc:SetWidth(w) end)
    sc:SetHeight(600)

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
        tabScrollBar:SetShown(maxScroll > 0)
    end

    local mainHeader = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    mainHeader:SetPoint("TOPLEFT", sc, "TOPLEFT", 8, -4)
    mainHeader:SetFont(mainHeader:GetFont(), E.HEADER_FONT_SIZE, "OUTLINE")
    E:StyleAccentHeader(mainHeader, "Roster")

    local subFS = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    subFS:SetPoint("LEFT", mainHeader, "RIGHT", 10, -1)
    subFS:SetFont(subFS:GetFont(), 11)
    subFS:SetText(E.CC.muted .. "Account-wide alt overview" .. E.CC.close)

    local summaryFS = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    summaryFS:SetPoint("TOPLEFT", mainHeader, "BOTTOMLEFT", 0, -8)
    summaryFS:SetPoint("RIGHT", sc, "RIGHT", -20, 0)
    summaryFS:SetFont(summaryFS:GetFont(), 11)
    summaryFS:SetJustifyH("LEFT")

    local hintFS = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    hintFS:SetPoint("TOPLEFT", summaryFS, "BOTTOMLEFT", 0, -4)
    hintFS:SetFont(hintFS:GetFont(), 10)
    hintFS:SetText(E.CC.muted
        .. "Log into a character to record it. Click a column to sort; hover a row for detail."
        .. E.CC.close)

    local div1 = sc:CreateTexture(nil, "ARTWORK")
    div1:SetHeight(1)
    div1:SetPoint("TOPLEFT", hintFS, "BOTTOMLEFT", 0, -8)
    div1:SetPoint("RIGHT", sc, "RIGHT", -8, 0)
    E:StyleAccentDivider(div1)

    local sortKey, sortDesc = "ilvl", true
    local RefreshAll

    local headerBtns = {}
    for _, col in ipairs(COLUMNS) do
        local btn = CreateFrame("Button", nil, sc)
        btn:SetHeight(16)
        btn:SetPoint("TOPLEFT", div1, "BOTTOMLEFT", col.x, -8)
        local fs = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        fs:SetPoint("LEFT", btn, "LEFT", 0, 0)
        fs:SetFont(fs:GetFont(), 10)
        fs:SetJustifyH("LEFT")
        btn.label = fs
        btn:SetScript("OnClick", function()
            if sortKey == col.key then
                sortDesc = not sortDesc
            else
                sortKey  = col.key
                sortDesc = col.numeric
            end
            RefreshAll()
        end)
        btn:SetScript("OnEnter", function() fs:SetTextColor(1, 1, 1) end)
        btn:SetScript("OnLeave", function()
            if sortKey ~= col.key then fs:SetTextColor(0.6, 0.6, 0.6) end
        end)
        headerBtns[col.key] = btn
    end

    local function RefreshHeaders()
        for _, col in ipairs(COLUMNS) do
            local btn = headerBtns[col.key]
            local active = (sortKey == col.key)
            local arrow  = active and (sortDesc and ARROW_DOWN or ARROW_UP) or ""
            btn.label:SetText(col.label .. arrow)
            btn.label:SetTextColor(active and 1 or 0.6,
                                   active and 1 or 0.6,
                                   active and 1 or 0.6)
            btn:SetWidth(btn.label:GetStringWidth() + 4)
        end
    end

    local rowPool = {}
    local function AcquireRow(i)
        local row = rowPool[i]
        if row then return row end
        row = CreateFrame("Button", nil, sc)
        row:SetHeight(ROW_H)
        row:SetWidth(ROW_W)

        row.bg = row:CreateTexture(nil, "BACKGROUND")
        row.bg:SetAllPoints(row)
        row.bg:Hide()

        row.cells = {}
        for _, col in ipairs(COLUMNS) do
            local fs = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            fs:SetPoint("LEFT", row, "LEFT", col.x, 0)
            fs:SetFont(fs:GetFont(), 11)
            fs:SetJustifyH("LEFT")
            if col.key == "name" then fs:SetWidth(186) end
            row.cells[col.key] = fs
        end

        row.delBtn = E:CreateButton(row, 18, 16, "x")
        row.delBtn:SetPoint("LEFT", row, "LEFT", DELETE_X, 0)

        row:SetScript("OnEnter", function(self)
            if not self.bg:IsShown() then
                self.bg:SetColorTexture(1, 1, 1, 0.05)
                self.bg:Show()
                self.hoverOnly = true
            end
            if self.tip then E:ShowTooltip(self, unpack(self.tip)) end
        end)
        row:SetScript("OnLeave", function(self)
            if self.hoverOnly then
                self.bg:Hide()
                self.hoverOnly = false
            end
            E:HideTooltip()
        end)

        rowPool[i] = row
        return row
    end

    StaticPopupDialogs["EVERYTHINGDELVES_DELETEROSTER"] = {
        text = "Remove %s from the roster?\n\n"
            .. "This only clears the saved snapshot; logging into that "
            .. "character records it again.",
        button1 = "Remove",
        button2 = "Cancel",
        OnAccept = function(_, data)
            local sv = EverythingDelvesDB
            if sv and sv.roster then sv.roster[data] = nil end
            RefreshAll()
        end,
        timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
    }

    local lastRow

    function RefreshAll()
        E:CaptureRosterSnapshot()
        RefreshHeaders()

        local sv     = EverythingDelvesDB
        local roster = (sv and sv.roster) or {}
        local curKey = E.CharKey()
        local now    = time()

        -- Wrap records (don't add transient fields to the persisted tables).
        local list = {}
        for k, rec in pairs(roster) do
            list[#list + 1] = { key = k, rec = rec, valid = rec.weekEnd and now < rec.weekEnd }
        end

        local function SortVal(e)
            local rec = e.rec
            if sortKey == "name"    then return (rec.name or e.key):lower() end
            if sortKey == "ilvl"    then return rec.ilvl or 0 end
            if sortKey == "keys"    then return rec.keys or 0 end
            if sortKey == "shards"  then return rec.shards or 0 end
            if sortKey == "bounty"  then return rec.bountyMaps or 0 end
            if sortKey == "vault"   then return e.valid and (rec.vaultSlots or 0) or -1 end
            if sortKey == "gilded"  then return e.valid and (rec.gildedCollected or 0) or -1 end
            if sortKey == "weekly"  then return e.valid and (rec.weeklyQuestDone and 1 or 0) or -1 end
            return rec.updated or 0
        end
        table.sort(list, function(a, b)
            local va, vb = SortVal(a), SortVal(b)
            if va == vb then return (a.rec.name or a.key) < (b.rec.name or b.key) end
            if sortDesc then return va > vb end
            return va < vb
        end)

        local totalKeys, totalBounty, weeklyDone = 0, 0, 0
        for _, e in ipairs(list) do
            totalKeys   = totalKeys   + (e.rec.keys or 0)
            totalBounty = totalBounty + (e.rec.bountyMaps or 0)
            if e.valid and e.rec.weeklyQuestDone then weeklyDone = weeklyDone + 1 end
        end
        summaryFS:SetText(string.format(
            "%s%d|r %scharacters|r   %s\194\183|r   %s%d|r %skeys|r   %s\194\183|r   %s%d|r %sbounty maps|r   %s\194\183|r   %s%d|r %sweekly delve quest done|r",
            E.CC.white, #list, E.CC.body,
            E.CC.muted,
            E.CC.gold, totalKeys, E.CC.body,
            E.CC.muted,
            E.CC.gold, totalBounty, E.CC.body,
            E.CC.muted,
            E.CC.green, weeklyDone, E.CC.body))

        lastRow = div1
        for i, e in ipairs(list) do
            local rec   = e.rec
            local valid = e.valid
            local row   = AcquireRow(i)
            local isCur = (e.key == curKey)
            row:ClearAllPoints()
            local anchor = (i == 1) and div1 or rowPool[i - 1]
            local yOff   = (i == 1) and -28 or -2
            row:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, yOff)

            if isCur then
                row.bg:SetColorTexture(1, 0.82, 0, 0.10)
                row.bg:Show()
                row.hoverOnly = false
            else
                row.bg:Hide()
                row.hoverOnly = false
            end

            row.cells.name:SetText(
                ClassColorOpen(rec.class) .. (rec.name or e.key) .. "|r"
                .. (rec.level and ("  " .. E.CC.muted .. rec.level .. E.CC.close) or "")
                .. (isCur and ("  " .. E.CC.muted .. "(you)" .. E.CC.close) or ""))

            row.cells.ilvl:SetText(rec.ilvl
                and (E.CC.body .. rec.ilvl .. E.CC.close)
                or  (E.CC.muted .. "\226\128\148" .. E.CC.close))

            local keys = rec.keys or 0
            row.cells.keys:SetText((keys > 0 and E.CC.gold or E.CC.muted) .. keys .. E.CC.close)

            row.cells.shards:SetText(E.CC.body .. (rec.shards or 0) .. E.CC.close)

            local bounty = rec.bountyMaps or 0
            row.cells.bounty:SetText((bounty > 0 and E.CC.gold or E.CC.muted) .. bounty .. E.CC.close)

            if valid and (rec.vaultTotal or 0) > 0 then
                local slots = rec.vaultSlots or 0
                local cc = (slots >= 3) and E.CC.green or (slots > 0 and E.CC.gold or E.CC.muted)
                row.cells.vault:SetText(cc .. slots .. "/3" .. E.CC.close)
            else
                row.cells.vault:SetText(E.CC.muted .. "\226\128\148" .. E.CC.close)
            end

            if valid and rec.gildedTotal then
                local col = rec.gildedCollected or 0
                local cc = (col >= rec.gildedTotal) and E.CC.green or E.CC.body
                row.cells.gilded:SetText(cc .. col .. "/" .. rec.gildedTotal .. E.CC.close)
            else
                row.cells.gilded:SetText(E.CC.muted .. "\226\128\148" .. E.CC.close)
            end

            if valid and rec.weeklyQuestDone then
                row.cells.weekly:SetText(E.CC.green .. "Done" .. E.CC.close)
            else
                row.cells.weekly:SetText(E.CC.muted .. "\226\128\148" .. E.CC.close)
            end

            row.cells.updated:SetText(E.CC.muted .. FormatAgo(now - (rec.updated or now)) .. E.CC.close)

            -- Built sequentially (no nil holes) so unpack() reaches every line.
            local tip = {
                (rec.name or e.key) .. " - " .. (rec.realm or "?"),
                "Item level: " .. (rec.ilvl or "?"),
                "Coffer Keys: " .. (rec.keys or 0) .. "   Shards: " .. (rec.shards or 0),
                "Bounty maps: " .. (rec.bountyMaps or 0),
            }
            if valid then
                tip[#tip + 1] = "Great Vault delves: " .. (rec.vaultProgress or 0)
                    .. "/" .. (rec.vaultTotal or 0)
                    .. "  (" .. (rec.vaultSlots or 0) .. "/3 slots)"
                if rec.gildedTotal then
                    tip[#tip + 1] = "Gilded Stash: " .. (rec.gildedCollected or 0)
                        .. "/" .. rec.gildedTotal
                end
            else
                tip[#tip + 1] = "Weekly data resets at the next reset"
            end
            tip[#tip + 1] = "Updated: " .. FormatAgo(now - (rec.updated or now))
            row.tip = tip

            if isCur then
                row.delBtn:Hide()
            else
                row.delBtn:Show()
                local delKey, delName = e.key, (rec.name or e.key)
                row.delBtn:SetScript("OnClick", function()
                    local dlg = StaticPopup_Show("EVERYTHINGDELVES_DELETEROSTER", delName)
                    if dlg then dlg.data = delKey end
                end)
            end

            row:Show()
            lastRow = row
        end

        for j = #list + 1, #rowPool do
            rowPool[j]:Hide()
        end

        if #list == 0 then
            summaryFS:SetText(E.CC.muted .. "No characters tracked yet." .. E.CC.close)
        end

        C_Timer.After(0, function()
            local scTop   = sc:GetTop()
            local lastBot = lastRow and lastRow:GetBottom()
            if scTop and lastBot and scTop > lastBot then
                sc:SetHeight((scTop - lastBot) + 24)
            end
            UpdateScrollRange()
        end)
    end

    frame:SetScript("OnShow", function()
        RefreshAll()
        UpdateScrollRange()
        scrollFrame:SetVerticalScroll(0)
        tabScrollBar:SetValue(0)
    end)

    local function OnData()
        if frame:IsShown() then RefreshAll() else E:CaptureRosterSnapshot() end
    end
    E:RegisterCallback("CurrencyUpdate",   OnData)
    E:RegisterCallback("QuestLogUpdate",   OnData)
    E:RegisterCallback("BagUpdate",        OnData)
    E:RegisterCallback("InventoryChanged", OnData)

    C_Timer.After(2, function() E:CaptureRosterSnapshot() end)

    E:RegisterTab(8, frame)
end)
