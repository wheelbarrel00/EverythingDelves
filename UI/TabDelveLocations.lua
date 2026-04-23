------------------------------------------------------------------------
-- UI/TabDelveLocations.lua â€” Tab 1: Delve Locations
-- Complete directory of all Midnight delves with filtering, sorting,
-- waypoints, and TomTom integration.
------------------------------------------------------------------------
local E = EverythingDelves

------------------------------------------------------------------------
-- Local references for frequently accessed globals
------------------------------------------------------------------------
local math_floor, math_max, math_min = math.floor, math.max, math.min
local table_insert, table_sort = table.insert, table.sort

------------------------------------------------------------------------
-- Local state
------------------------------------------------------------------------
local filteredData   = {}  -- currently visible rows after filter/sort
local currentZone    = nil -- nil = "All Zones"
local currentSearch  = ""
local sortField      = "name"  -- "name" | "zone"
local sortAscending  = true
local ROW_HEIGHT     = 28
local VISIBLE_ROWS   = 13
local scrollOffset   = 0
local scrollBar      = nil  -- forward ref, set during init
local rows           = {}  -- recycled row frames

------------------------------------------------------------------------
-- Filtering & sorting
------------------------------------------------------------------------
local function MatchesFilter(delve)
    -- Zone filter
    if currentZone and delve.zone ~= currentZone then
        return false
    end
    -- Search filter (case-insensitive substring match on delve name)
    if currentSearch ~= "" then
        if not delve.name:lower():find(currentSearch, 1, true) then
            return false
        end
    end
    return true
end

local function RefreshFilteredData()
    wipe(filteredData)
    for _, delve in ipairs(E.DelveData) do
        if MatchesFilter(delve) then
            table_insert(filteredData, delve)
        end
    end

    -- Sort
    table_sort(filteredData, function(a, b)
        local va, vb
        if sortField == "name" then
            va, vb = a.name:lower(), b.name:lower()
        elseif sortField == "zone" then
            va, vb = a.zone:lower(), b.zone:lower()
        end
        if sortAscending then
            return va < vb
        else
            return va > vb
        end
    end)
end

------------------------------------------------------------------------
-- Row rendering
------------------------------------------------------------------------
local function UpdateRows(scrollFrame)
    local totalRows = #filteredData
    for i = 1, VISIBLE_ROWS do
        local row = rows[i]
        local dataIndex = i + scrollOffset
        if dataIndex <= totalRows then
            local delve = filteredData[dataIndex]
            row.delve = delve

            -- Delve name â€” gold star prefix if bountiful this week
            local isBountiful = false
            if E.currentBountifulNames then
                -- Try exact name, then normalized name, then POI ID fallback
                isBountiful = E.currentBountifulNames[delve.name]
                    or E.currentBountifulNames[strtrim(delve.name):lower()]
                    or (E.currentBountifulPOIs and delve.poiID
                        and E.currentBountifulPOIs[delve.poiID])
                    or false
            end
            local hist = E:GetDelveHistory(delve.name)
            local runSuffix = ""
            if hist and hist.totalRuns and hist.totalRuns > 0 then
                runSuffix = E.CC.muted .. " (" .. hist.totalRuns .. "x)" .. E.CC.close
            end
            if isBountiful then
                row.nameText:SetText(E.CC.gold .. "* " .. delve.name .. E.CC.close .. runSuffix)
            else
                row.nameText:SetText(E.CC.body .. delve.name .. E.CC.close .. runSuffix)
            end
            row.isBountiful = isBountiful
            -- Zone (off-white)
            row.zoneText:SetText(E.CC.body .. delve.zone .. E.CC.close)

            row:Show()
        else
            row:Hide()
        end
    end

    -- Update row count label
    if scrollFrame.countLabel then
        scrollFrame.countLabel:SetText(
            E.CC.muted .. "Showing " .. totalRows .. " of "
            .. E.TOTAL_DELVES .. " delves" .. E.CC.close
        )
    end
end

------------------------------------------------------------------------
-- Scroll handling
------------------------------------------------------------------------
local function OnMouseWheel(self, delta)
    local maxOffset = math_max(0, #filteredData - VISIBLE_ROWS)
    scrollOffset = math_max(0, math_min(scrollOffset - delta, maxOffset))
    -- Move the scroll bar thumb to match
    if self.scrollBar then
        self.scrollBar:SetValue(scrollOffset)
    end
    UpdateRows(self)
end

------------------------------------------------------------------------
-- Zone dropdown (custom, no UIDropDownMenu to avoid taint)
------------------------------------------------------------------------
local dropdownMenu = nil  -- forward ref

local function CreateZoneDropdown(parent)
    -- The button that shows the current filter value
    local btn = E:CreateButton(parent, 170, 24, "All Zones")
    btn.label:SetFont(btn.label:GetFont(), 11)

    -- Dropdown list (hidden by default)
    local menu = CreateFrame("Frame", "EverythingDelvesZoneMenu",
                             btn, "BackdropTemplate")
    menu:SetFrameStrata("TOOLTIP")
    menu:SetFrameLevel(100)
    menu:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    menu:SetBackdropColor(0.05, 0.05, 0.05, 0.98)
    menu:SetBackdropBorderColor(0.55, 0, 0, 1)
    menu:Hide()
    dropdownMenu = menu

    -- Build option list: "All Zones" + each zone
    local options = { { name = "All Zones", value = nil } }
    for _, z in ipairs(E.Zones) do
        table_insert(options, { name = z.name, value = z.name })
    end

    local optionButtons = {}
    local function UpdateOptionHighlights()
        for _, ob in ipairs(optionButtons) do
            if ob.zoneValue == currentZone then
                ob.label:SetText(E.CC.gold .. ob.zoneName .. E.CC.close)
                ob:SetBackdropColor(0.20, 0, 0, 0.50)
            else
                ob.label:SetText(E.CC.white .. ob.zoneName .. E.CC.close)
                ob:SetBackdropColor(0.05, 0.05, 0.05, 1)
            end
        end
    end

    for idx, opt in ipairs(options) do
        local ob = CreateFrame("Button", nil, menu, "BackdropTemplate")
        ob:SetHeight(20)
        ob:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
        })
        ob:SetBackdropColor(0.05, 0.05, 0.05, 1)
        if idx == 1 then
            ob:SetPoint("TOPLEFT", menu, "TOPLEFT", 2, -2)
            ob:SetPoint("TOPRIGHT", menu, "TOPRIGHT", -2, -2)
        else
            ob:SetPoint("TOPLEFT", optionButtons[idx - 1], "BOTTOMLEFT", 0, 0)
            ob:SetPoint("TOPRIGHT", optionButtons[idx - 1], "BOTTOMRIGHT", 0, 0)
        end

        local label = ob:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        label:SetPoint("LEFT", 6, 0)
        label:SetFont(label:GetFont(), 11)
        label:SetText(E.CC.white .. opt.name .. E.CC.close)
        ob.label = label
        ob.zoneName = opt.name
        ob.zoneValue = opt.value

        ob:SetScript("OnEnter", function(self)
            self:SetBackdropColor(0.40, 0, 0, 0.70)
        end)
        ob:SetScript("OnLeave", function(self)
            if self.zoneValue == currentZone then
                self:SetBackdropColor(0.20, 0, 0, 0.50)
            else
                self:SetBackdropColor(0.05, 0.05, 0.05, 1)
            end
        end)
        ob:SetScript("OnClick", function()
            currentZone = opt.value
            btn.label:SetText(E.CC.white .. opt.name .. E.CC.close)
            menu:Hide()
            scrollOffset = 0
            if scrollBar then scrollBar:SetValue(0) end
            RefreshFilteredData()
            UpdateRows(parent)
            UpdateOptionHighlights()
        end)

        optionButtons[idx] = ob
    end

    local totalHeight = #options * 20 + 4
    menu:SetSize(170, totalHeight)
    menu:SetPoint("TOPLEFT", btn, "BOTTOMLEFT", 0, -2)

    -- Fullscreen invisible overlay â€” click-outside-to-close behavior
    local overlay = CreateFrame("Button", nil, UIParent)
    overlay:SetAllPoints(UIParent)
    overlay:SetFrameStrata("TOOLTIP")
    overlay:SetFrameLevel(99)  -- just below the menu (level 100)
    overlay:Hide()
    overlay:SetScript("OnClick", function()
        menu:Hide()
    end)

    btn:SetScript("OnClick", function()
        if menu:IsShown() then
            menu:Hide()
        else
            menu:Show()
        end
    end)

    -- Show/hide overlay with the menu
    menu:SetScript("OnShow", function(self)
        overlay:Show()
        self:SetPropagateKeyboardInput(false)
    end)
    menu:SetScript("OnHide", function()
        overlay:Hide()
    end)

    return btn
end

------------------------------------------------------------------------
-- Search box
------------------------------------------------------------------------
local function CreateSearchBox(parent)
    -- BackdropTemplate frame wrapping the EditBox for visual styling
    local wrapper = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    wrapper:SetSize(180, 24)
    wrapper:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    wrapper:SetBackdropColor(0.10, 0.10, 0.10, 1)
    wrapper:SetBackdropBorderColor(0.35, 0.35, 0.35, 0.80)

    local editBox = CreateFrame("EditBox", "EverythingDelvesSearchBox",
                                wrapper)
    editBox:SetSize(168, 20)
    editBox:SetPoint("CENTER")
    editBox:SetFontObject(GameFontNormal)
    local fontPath, _, fontFlags = editBox:GetFont()
    editBox:SetFont(fontPath, 11, fontFlags or "")
    editBox:SetTextColor(0.88, 0.88, 0.88, 1)
    editBox:SetAutoFocus(false)
    editBox:SetMaxLetters(40)

    -- Placeholder text (shown when the box is empty)
    local placeholder = editBox:CreateFontString(nil, "OVERLAY",
                                                  "GameFontNormal")
    placeholder:SetPoint("LEFT", 2, 0)
    local phFont, _, phFlags = placeholder:GetFont()
    placeholder:SetFont(phFont, 11, phFlags or "")
    placeholder:SetText(E.CC.muted .. "Search delves..." .. E.CC.close)
    editBox.placeholder = placeholder

    editBox:SetScript("OnTextChanged", function(self)
        local text = self:GetText()
        if text == "" then
            placeholder:Show()
        else
            placeholder:Hide()
        end
        currentSearch = strtrim(text):lower()
        scrollOffset = 0
        if scrollBar then scrollBar:SetValue(0) end
        RefreshFilteredData()
        UpdateRows(parent)
    end)
    editBox:SetScript("OnEditFocusGained", function(self)
        if self:GetText() ~= "" then placeholder:Hide() end
    end)
    editBox:SetScript("OnEditFocusLost", function(self)
        if self:GetText() == "" then placeholder:Show() end
    end)
    editBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)

    return wrapper
end

------------------------------------------------------------------------
-- Column headers (clickable to re-sort)
------------------------------------------------------------------------
local function CreateColumnHeaders(parent, yOffset)
    local headers = {}
    local cols = {
        { field = "name", label = "Delve Name",  width = 250, anchor = 0   },
        { field = "zone", label = "Zone",         width = 160, anchor = 256 },
    }

    for _, col in ipairs(cols) do
        local btn = CreateFrame("Button", nil, parent)
        btn:SetSize(col.width, 18)
        btn:SetPoint("TOPLEFT", parent, "TOPLEFT", col.anchor, yOffset)

        local text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        text:SetPoint("LEFT")
        text:SetFont(text:GetFont(), 11, "OUTLINE")
        text:SetText(E.CC.header .. col.label .. E.CC.close)
        btn.label = text

        -- Arrow indicator for active sort column
        local arrow = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        arrow:SetPoint("LEFT", text, "RIGHT", 3, 0)
        arrow:SetFont(arrow:GetFont(), 10)
        btn.arrow = arrow

        btn:SetScript("OnClick", function()
            if sortField == col.field then
                sortAscending = not sortAscending
            else
                sortField = col.field
                sortAscending = true
            end
            -- Update arrows on all headers
            for _, h in ipairs(headers) do
                if h.field == sortField then
                    h.btn.arrow:SetText(
                        E.CC.muted .. (sortAscending and "(asc)" or "(desc)") .. E.CC.close
                    )
                else
                    h.btn.arrow:SetText("")
                end
            end
            scrollOffset = 0
            if scrollBar then scrollBar:SetValue(0) end
            RefreshFilteredData()
            UpdateRows(parent)
        end)

        table_insert(headers, { field = col.field, btn = btn })
    end

    -- Static labels for the two action columns (not sortable)
    for _, info in ipairs({
        { label = "Pin",    x = 422 },
        { label = "TomTom", x = 462 },
    }) do
        local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        fs:SetPoint("TOPLEFT", parent, "TOPLEFT", info.x, yOffset)
        fs:SetFont(fs:GetFont(), 11, "OUTLINE")
        fs:SetText(E.CC.header .. info.label .. E.CC.close)
    end

    -- Set initial sort arrow
    headers[1].btn.arrow:SetText(E.CC.muted .. "(asc)" .. E.CC.close)

    return headers
end

------------------------------------------------------------------------
-- Create a single row frame (recycled â€” created once, reused on scroll)
------------------------------------------------------------------------
local function CreateRow(parent, index)
    local row = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    row:SetHeight(ROW_HEIGHT)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 0,
                 -((index - 1) * ROW_HEIGHT))
    row:SetPoint("RIGHT", parent, "RIGHT", 0, 0)
    row:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
    })
    -- Alternate row shading for readability
    if index % 2 == 0 then
        row:SetBackdropColor(0.08, 0.08, 0.08, 0.50)
    else
        row:SetBackdropColor(0.05, 0.05, 0.05, 0.20)
    end
    row:EnableMouse(true)

    -- Delve Name
    local nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    nameText:SetPoint("LEFT", row, "LEFT", 4, 0)
    nameText:SetFont(nameText:GetFont(), 11)
    nameText:SetWidth(246)
    nameText:SetJustifyH("LEFT")
    nameText:SetWordWrap(false)
    row.nameText = nameText

    -- Zone
    local zoneText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    zoneText:SetPoint("LEFT", row, "LEFT", 256, 0)
    zoneText:SetFont(zoneText:GetFont(), 11)
    zoneText:SetWidth(160)
    zoneText:SetJustifyH("LEFT")
    zoneText:SetWordWrap(false)
    row.zoneText = zoneText

    -- [Waypoint] button
    local wpBtn = E:CreateButton(row, 32, 20, "Pin")
    wpBtn.label:SetFont(wpBtn.label:GetFont(), 10)
    wpBtn:SetPoint("LEFT", row, "LEFT", 422, 0)
    wpBtn:SetScript("OnClick", function()
        if row.delve then
            E:SetWaypoint(row.delve.mapID, row.delve.x, row.delve.y)
            E:FlashButtonConfirm(wpBtn)
        end
    end)
    wpBtn:SetScript("OnEnter", function(self)
        local hc = E.Colors.buttonHover
        self:SetBackdropColor(hc.r, hc.g, hc.b, hc.a)
        E:ShowTooltip(self, "Set Waypoint",
                      "Places a Blizzard map pin on this delve's location.")
    end)
    wpBtn:SetScript("OnLeave", function(self)
        local bc = E.Colors.buttonBg
        self:SetBackdropColor(bc.r, bc.g, bc.b, bc.a)
        E:HideTooltip()
    end)
    row.wpBtn = wpBtn

    -- [TomTom] button
    local ttBtn = E:CreateButton(row, 50, 20, "TomTom")
    ttBtn.label:SetFont(ttBtn.label:GetFont(), 10)
    ttBtn:SetPoint("LEFT", row, "LEFT", 460, 0)
    ttBtn:SetScript("OnClick", function()
        if row.delve then
            E:AddTomTomWaypoint(row.delve.mapID,
                                row.delve.x, row.delve.y,
                                row.delve.name)
            E:FlashButtonConfirm(ttBtn)
        end
    end)
    ttBtn:SetScript("OnEnter", function(self)
        local hc = E.Colors.buttonHover
        self:SetBackdropColor(hc.r, hc.g, hc.b, hc.a)
        if E:IsTomTomLoaded() then
            E:ShowTooltip(self, "TomTom Waypoint",
                          "Add an arrow waypoint via TomTom.")
        else
            E:ShowTooltip(self, "TomTom Not Installed",
                          "Install the TomTom addon to use arrow waypoints.")
        end
    end)
    ttBtn:SetScript("OnLeave", function(self)
        local bc = E.Colors.buttonBg
        self:SetBackdropColor(bc.r, bc.g, bc.b, bc.a)
        E:HideTooltip()
    end)
    row.ttBtn = ttBtn

    -- Row hover highlight + tooltip
    row:SetScript("OnEnter", function(self)
        self:SetBackdropColor(0.20, 0, 0, 0.50)
        if self.delve then
            local tipLines = {}
            -- Bountiful notice at the top, in gold
            if self.isBountiful then
                table_insert(tipLines, E.CC.gold .. "* This delve is a Bountiful Delve this week!" .. E.CC.close)
                table_insert(tipLines, "")
            end
            table_insert(tipLines,
                E.CC.muted .. "Zone: " .. E.CC.close
                    .. E.CC.body .. self.delve.zone .. E.CC.close)
            E:ShowTooltip(self, self.delve.name, unpack(tipLines))
        end
    end)
    row:SetScript("OnLeave", function(self)
        if index % 2 == 0 then
            self:SetBackdropColor(0.08, 0.08, 0.08, 0.50)
        else
            self:SetBackdropColor(0.05, 0.05, 0.05, 0.20)
        end
        E:HideTooltip()
    end)

    return row
end

------------------------------------------------------------------------
-- Scroll bar (simple vertical slider)
------------------------------------------------------------------------
local function CreateScrollBar(parent, listFrame)
    -- Slider widget acts as the scroll bar thumb
    local bar = CreateFrame("Slider", nil, parent, "BackdropTemplate")
    bar:SetWidth(14)
    bar:SetPoint("TOPRIGHT", listFrame, "TOPRIGHT", 16, 0)
    bar:SetPoint("BOTTOMRIGHT", listFrame, "BOTTOMRIGHT", 16, 0)
    bar:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    bar:SetBackdropColor(0.10, 0.10, 0.10, 0.80)
    bar:SetBackdropBorderColor(0.30, 0.30, 0.30, 0.60)

    -- Thumb texture
    local thumb = bar:CreateTexture(nil, "OVERLAY")
    thumb:SetSize(12, 40)
    thumb:SetColorTexture(0.55, 0, 0, 0.80)
    bar:SetThumbTexture(thumb)

    bar:SetOrientation("VERTICAL")
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0)
    bar:SetValueStep(1)
    bar:SetObeyStepOnDrag(true)

    bar:SetScript("OnValueChanged", function(self, value)
        scrollOffset = math_floor(value + 0.5)
        UpdateRows(parent)
    end)

    return bar
end

------------------------------------------------------------------------
-- MODULE INIT â€” called via RegisterModule after the main frame exists
------------------------------------------------------------------------
E:RegisterModule(function()
    local frame = CreateFrame("Frame", "EverythingDelvesTab1Content")
    local TOOLBAR_Y = -4
    local LIST_Y    = -58  -- below toolbar + column headers

    --------------------------------------------------------------------
    -- Toolbar row: zone dropdown, search box, [Set All Waypoints], count
    --------------------------------------------------------------------
    local zoneDrop = CreateZoneDropdown(frame)
    zoneDrop:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, TOOLBAR_Y)

    local searchBox = CreateSearchBox(frame)
    searchBox:SetPoint("LEFT", zoneDrop, "RIGHT", 10, 0)

    -- [Set All Waypoints] button
    local setAllBtn = E:CreateButton(frame, 130, 24, "Set All Waypoints")
    setAllBtn.label:SetFont(setAllBtn.label:GetFont(), 10)
    setAllBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -22, TOOLBAR_Y)
    setAllBtn:SetScript("OnClick", function()
        if not E:IsTomTomLoaded() then
            print(E.CC.header .. "Everything Delves|r: "
                .. "TomTom is required for bulk waypoints.")
            return
        end
        for _, delve in ipairs(filteredData) do
            E:AddTomTomWaypoint(delve.mapID, delve.x, delve.y, delve.name)
        end
        print(E.CC.header .. "Everything Delves|r: Added "
            .. #filteredData .. " TomTom waypoints.")
    end)
    setAllBtn:SetScript("OnEnter", function(self)
        local hc = E.Colors.buttonHover
        self:SetBackdropColor(hc.r, hc.g, hc.b, hc.a)
        E:ShowTooltip(self, "Set All Waypoints",
                      "Adds TomTom waypoints for every delve",
                      "currently visible in the filtered list.",
                      "",
                      E.CC.muted .. "Requires TomTom addon." .. E.CC.close)
    end)
    setAllBtn:SetScript("OnLeave", function(self)
        local bc = E.Colors.buttonBg
        self:SetBackdropColor(bc.r, bc.g, bc.b, bc.a)
        E:HideTooltip()
    end)

    -- Row count label
    local countLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    countLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, TOOLBAR_Y - 28)
    countLabel:SetFont(countLabel:GetFont(), 10)
    frame.countLabel = countLabel

    --------------------------------------------------------------------
    -- Column headers
    --------------------------------------------------------------------
    CreateColumnHeaders(frame, LIST_Y + 16)

    --------------------------------------------------------------------
    -- Scrollable list area
    --------------------------------------------------------------------
    local listFrame = CreateFrame("Frame", nil, frame)
    listFrame:SetPoint("TOPLEFT",  frame, "TOPLEFT",  4,  LIST_Y)
    listFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -22, 4)
    listFrame:EnableMouseWheel(true)
    listFrame.countLabel = countLabel   -- ref for UpdateRows

    -- Create recycled rows
    for i = 1, VISIBLE_ROWS do
        rows[i] = CreateRow(listFrame, i)
    end

    -- Scroll bar
    scrollBar = CreateScrollBar(frame, listFrame)
    listFrame.scrollBar = scrollBar

    listFrame:SetScript("OnMouseWheel", function(self, delta)
        OnMouseWheel(self, delta)
    end)

    -- Whenever the list frame shows, refresh data and recalc scrollbar
    listFrame:SetScript("OnShow", function(self)
        RefreshFilteredData()
        local maxOffset = math_max(0, #filteredData - VISIBLE_ROWS)
        scrollBar:SetMinMaxValues(0, maxOffset)
        scrollBar:SetValue(scrollOffset)
        UpdateRows(self)
    end)

    -- Store a reference so other functions can trigger refreshes
    frame.listFrame = listFrame

    -- Close the zone dropdown when clicking anywhere else on the tab
    frame:EnableMouse(true)
    frame:SetScript("OnMouseDown", function()
        if dropdownMenu and dropdownMenu:IsShown() then
            dropdownMenu:Hide()
        end
    end)

    --------------------------------------------------------------------
    -- Register with the main frame tab system
    --------------------------------------------------------------------
    E:RegisterTab(1, frame)

    -- Seed the initial data set
    RefreshFilteredData()
end)
