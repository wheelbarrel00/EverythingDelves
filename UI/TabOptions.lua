------------------------------------------------------------------------
-- UI/TabOptions.lua — Tab 5: Options
-- All user-configurable settings. Writes to EverythingDelvesDB (the
-- SavedVariables table aliased as E.db).
--
-- Display-only addon — no gameplay automation. Settings here control
-- the addon's own UI behaviour.
------------------------------------------------------------------------
local E = EverythingDelves

------------------------------------------------------------------------
-- Local references for frequently accessed globals
------------------------------------------------------------------------
local math_floor, math_max, math_min = math.floor, math.max, math.min

------------------------------------------------------------------------
-- Widget factories (local to this file)
------------------------------------------------------------------------

--- Create a themed checkbox with a label.
--- @param parent     Frame
--- @param x          number  X offset from parent TOPLEFT
--- @param y          number  Y offset from parent TOPLEFT
--- @param labelText  string
--- @param dbKey      string?  Key in E.db (nil when overridden manually)
--- @param onChange   function? Optional callback(newValue)
--- @return CheckButton
local function CreateCheckbox(parent, x, y, labelText, dbKey, onChange)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    cb:SetSize(24, 24)
    cb:SetChecked(E.db[dbKey] == true)

    -- Label sits to the right of the check box
    local label = cb:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("LEFT", cb, "RIGHT", 4, 0)
    label:SetFont(label:GetFont(), 11)
    label:SetText(E.CC.body .. labelText .. E.CC.close)
    cb.labelFS = label

    cb:SetScript("OnClick", function(self)
        local checked = self:GetChecked()
        if dbKey then E.db[dbKey] = checked end
        if onChange then onChange(checked) end
    end)

    return cb
end

--- Create a themed slider with min/max/step and a value readout.
--- @param parent    Frame
--- @param x         number
--- @param y         number
--- @param labelText string
--- @param minVal    number
--- @param maxVal    number
--- @param step      number
--- @param dbKey     string
--- @param formatter function?  Optional display formatter (value)->string
--- @param onChange  function?  Optional callback(value)
--- @return Slider
local function CreateSlider(parent, x, y, labelText, minVal, maxVal, step, dbKey, formatter, onChange)
    -- Label
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    label:SetFont(label:GetFont(), 11)
    label:SetText(E.CC.body .. labelText .. E.CC.close)

    local slider = CreateFrame("Slider", nil, parent, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -4)
    slider:SetSize(200, 16)
    slider:SetMinMaxValues(minVal, maxVal)
    slider:SetValueStep(step)
    slider:SetObeyStepOnDrag(true)
    slider:SetValue(E.db[dbKey] or minVal)

    -- Hide the default min/max labels — they're ugly
    if slider.Low  then slider.Low:SetText("")  end
    if slider.High then slider.High:SetText("") end

    -- Value readout
    local valFS = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    valFS:SetPoint("LEFT", slider, "RIGHT", 8, 0)
    valFS:SetFont(valFS:GetFont(), 11)
    slider.valFS = valFS

    local function UpdateText(val)
        if formatter then
            valFS:SetText(E.CC.gold .. formatter(val) .. E.CC.close)
        else
            valFS:SetText(E.CC.gold .. val .. E.CC.close)
        end
    end
    UpdateText(slider:GetValue())

    slider:SetScript("OnValueChanged", function(self, val)
        val = math_floor(val / step + 0.5) * step  -- snap to step
        E.db[dbKey] = val
        UpdateText(val)
        if onChange then onChange(val) end
    end)

    return slider
end

--- Create a radio-button-style selector from a list of options.
--- @param parent    Frame
--- @param x         number
--- @param y         number
--- @param labelText string
--- @param dbKey     string
--- @param options   table   { { value=string, label=string }, ... }
--- @param onChange  function? Optional callback(value)
--- @return table    Array of CheckButtons (so caller can position them)
local function CreateRadioGroup(parent, x, y, labelText, dbKey, options, onChange)
    local header = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    header:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    header:SetFont(header:GetFont(), 11)
    header:SetText(E.CC.body .. labelText .. E.CC.close)

    local buttons = {}
    for i, opt in ipairs(options) do
        local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
        cb:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -4 - ((i - 1) * 24))
        cb:SetSize(24, 24)
        cb:SetChecked(E.db[dbKey] == opt.value)

        local lbl = cb:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        lbl:SetPoint("LEFT", cb, "RIGHT", 4, 0)
        lbl:SetFont(lbl:GetFont(), 11)
        lbl:SetText(E.CC.body .. opt.label .. E.CC.close)
        cb.labelFS = lbl

        cb:SetScript("OnClick", function()
            E.db[dbKey] = opt.value
            -- Uncheck siblings
            for _, b in ipairs(buttons) do
                b:SetChecked(E.db[dbKey] == b.optValue)
            end
            if onChange then onChange(opt.value) end
        end)
        cb.optValue = opt.value
        buttons[i] = cb
    end

    return buttons
end

------------------------------------------------------------------------
-- MODULE INIT
------------------------------------------------------------------------
E:RegisterModule(function()
    local frame = CreateFrame("Frame", "EverythingDelvesTab5Content")

    -- Scrollable container so options aren't cut off
    local scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -26, 0)

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetWidth(scrollFrame:GetWidth() or 580)
    scrollFrame:SetScrollChild(scrollChild)

    -- Ensure scrollChild width tracks the scrollFrame on resize
    scrollFrame:SetScript("OnSizeChanged", function(self, w, h)
        scrollChild:SetWidth(w)
    end)

    -- All content is parented to scrollChild instead of frame
    local content = scrollChild

    local SECT_X = 8
    local Y = -6

    --------------------------------------------------------------------
    -- SECTION HEADER: General
    --------------------------------------------------------------------
    local genHeader = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    genHeader:SetPoint("TOPLEFT", content, "TOPLEFT", SECT_X, Y)
    genHeader:SetFont(genHeader:GetFont(), 12, "OUTLINE")
    genHeader:SetText(E.CC.header .. "General" .. E.CC.close)
    Y = Y - 20

    -- Default Tab
    local defaultTabSlider = CreateSlider(
        content, SECT_X, Y,
        "Default Tab (opens to this tab)",
        1, E.NUM_TABS, 1,
        "defaultTab",
        function(v) return E.TAB_NAMES[v] or v end
    )
    Y = Y - 50

    -- UI Scale  (integer 80-150 to avoid float step issues)
    local scaleLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    scaleLabel:SetPoint("TOPLEFT", content, "TOPLEFT", SECT_X, Y)
    scaleLabel:SetFont(scaleLabel:GetFont(), 11)
    scaleLabel:SetText(E.CC.body .. "UI Scale" .. E.CC.close)

    local scaleSlider = CreateFrame("Slider",
        "EverythingDelvesUIScaleSlider", content, "OptionsSliderTemplate")
    scaleSlider:SetPoint("TOPLEFT", scaleLabel, "BOTTOMLEFT", 0, -4)
    scaleSlider:SetWidth(200)
    scaleSlider:SetHeight(20)
    scaleSlider:SetMinMaxValues(80, 150)
    scaleSlider:SetValueStep(5)
    scaleSlider:SetObeyStepOnDrag(true)
    scaleSlider:SetValue((E.db.uiScale or 1.0) * 100)

    _G[scaleSlider:GetName() .. "Low"]:SetText("80%")
    _G[scaleSlider:GetName() .. "High"]:SetText("150%")
    _G[scaleSlider:GetName() .. "Text"]:SetText("")
    _G[scaleSlider:GetName() .. "Text"]:Hide()

    -- EditBox for precise typed input
    local scaleInput = CreateFrame("EditBox", nil, content, "InputBoxTemplate")
    scaleInput:SetPoint("LEFT", scaleSlider, "RIGHT", 12, 0)
    scaleInput:SetSize(50, 22)
    scaleInput:SetAutoFocus(false)
    scaleInput:SetMaxLetters(3)
    scaleInput:SetNumeric(true)
    scaleInput:SetNumber(math_floor((E.db.uiScale or 1.0) * 100))

    local pctLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    pctLabel:SetPoint("LEFT", scaleInput, "RIGHT", 3, 0)
    pctLabel:SetFont(pctLabel:GetFont(), 11)
    pctLabel:SetText(E.CC.body .. "%" .. E.CC.close)

    -- Reset button
    local resetBtn = E:CreateButton(content, 50, 22, "Reset")
    resetBtn:SetPoint("LEFT", pctLabel, "RIGHT", 8, 0)
    resetBtn:SetScript("OnClick", function()
        local defaultPct = 100
        local scale = defaultPct / 100
        E.db.uiScale = scale
        scaleSlider:SetValue(defaultPct)
        scaleInput:SetNumber(defaultPct)
        if E.MainFrame then E.MainFrame:SetScale(scale) end
    end)

    -- Apply scale from the input box
    local function ApplyFromInput()
        local raw = scaleInput:GetNumber()
        local pct = math_max(80, math_min(150, raw))
        -- Snap to nearest step of 5
        pct = math_floor(pct / 5 + 0.5) * 5
        local scale = pct / 100
        E.db.uiScale = scale
        scaleSlider:SetValue(pct)
        scaleInput:SetNumber(pct)
        scaleInput:ClearFocus()
        if E.MainFrame then E.MainFrame:SetScale(scale) end
    end

    scaleInput:SetScript("OnEnterPressed", ApplyFromInput)
    scaleInput:SetScript("OnTabPressed", ApplyFromInput)
    scaleInput:SetScript("OnEscapePressed", function(self)
        self:SetNumber(math_floor((E.db.uiScale or 1.0) * 100))
        self:ClearFocus()
    end)

    scaleSlider:SetScript("OnValueChanged", function(self, value)
        local pct = math_floor(value)
        local scale = pct / 100
        E.db.uiScale = scale
        scaleInput:SetNumber(pct)
        if E.MainFrame then E.MainFrame:SetScale(scale) end
    end)
    Y = Y - 50

    -- Show Minimap / Broker Button
    local minimapCB = CreateCheckbox(
        content, SECT_X, Y,
        "Show Minimap / Broker Button",
        nil  -- handled manually below
    )
    -- Override: minimap button lives in a sub-table
    minimapCB:SetChecked(E.db.minimapButton and E.db.minimapButton.show)
    minimapCB:SetScript("OnClick", function(self)
        local checked = self:GetChecked()
        E:SetMinimapButtonVisible(checked)
    end)
    Y = Y - 28

    --------------------------------------------------------------------
    -- Thin red divider
    --------------------------------------------------------------------
    local dc = E.Colors.divider
    local div1 = content:CreateTexture(nil, "ARTWORK")
    div1:SetHeight(1)
    div1:SetPoint("TOPLEFT", content, "TOPLEFT", SECT_X, Y)
    div1:SetPoint("RIGHT", content, "RIGHT", -8, 0)
    div1:SetColorTexture(dc.r, dc.g, dc.b, dc.a)
    Y = Y - 10

    --------------------------------------------------------------------
    -- SECTION HEADER: Display
    --------------------------------------------------------------------
    local dispHeader = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    dispHeader:SetPoint("TOPLEFT", content, "TOPLEFT", SECT_X, Y)
    dispHeader:SetFont(dispHeader:GetFont(), 12, "OUTLINE")
    dispHeader:SetText(E.CC.header .. "Display" .. E.CC.close)
    Y = Y - 20

    -- Accent Color (radio group)
    local accentOptions = {
        { value = "red",    label = "|cFFFF2222Red|r (default)" },
        { value = "gold",   label = "|cFFFFD700Gold|r" },
        { value = "purple", label = "|cFFB280FFPurple|r" },
    }
    local accentRadios = CreateRadioGroup(
        content, SECT_X, Y,
        "Accent Color",
        "accentColor",
        accentOptions,
        function(value)
            -- Live-apply accent color to the main frame border and header CC
            local preset = E.AccentPresets[value]
            if preset and E.MainFrame then
                local bc = preset.border
                E.MainFrame:SetBackdropBorderColor(bc.r, bc.g, bc.b, bc.a)
                E.Colors.border = preset.border
                E.Colors.header = preset.header
                E.CC.header     = preset.headerCC
            end
        end
    )
    Y = Y - 20 - (#accentOptions * 24) - 4

    -- Completed Display (radio group)
    local compOptions = {
        { value = "dim",    label = "Dim completed items" },
        { value = "hide",   label = "Hide completed items" },
        { value = "bottom", label = "Sort completed to bottom" },
    }
    local compRadios = CreateRadioGroup(
        content, SECT_X, Y,
        "Completed Delve Display",
        "completedDisplay",
        compOptions
    )
    Y = Y - 20 - (#compOptions * 24) - 4

    -- Show Completed Items
    local showCompCB = CreateCheckbox(
        content, SECT_X, Y,
        "Show Completed Items in Lists",
        "showCompletedItems"
    )
    Y = Y - 28

    --------------------------------------------------------------------
    -- Thin red divider
    --------------------------------------------------------------------
    local div2 = content:CreateTexture(nil, "ARTWORK")
    div2:SetHeight(1)
    div2:SetPoint("TOPLEFT", content, "TOPLEFT", SECT_X, Y)
    div2:SetPoint("RIGHT", content, "RIGHT", -8, 0)
    div2:SetColorTexture(dc.r, dc.g, dc.b, dc.a)
    Y = Y - 10

    --------------------------------------------------------------------
    -- SECTION HEADER: Alerts & Tracking
    --------------------------------------------------------------------
    local alertHeader = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    alertHeader:SetPoint("TOPLEFT", content, "TOPLEFT", SECT_X, Y)
    alertHeader:SetFont(alertHeader:GetFont(), 12, "OUTLINE")
    alertHeader:SetText(E.CC.header .. "Alerts & Tracking" .. E.CC.close)
    Y = Y - 20

    -- Weekly Reset Alert
    local resetCB = CreateCheckbox(
        content, SECT_X, Y,
        "Show Weekly Reset Alert on Login",
        "showWeeklyResetAlert"
    )
    Y = Y - 26

    -- Session Tracking
    local sessCB = CreateCheckbox(
        content, SECT_X, Y,
        "Enable Session Tracking (Shard Tracker tab)",
        "sessionTracking"
    )
    Y = Y - 26

    -- Low Shard Warning
    local lowWarnCB = CreateCheckbox(
        content, SECT_X, Y,
        "Low Shard Warning",
        "lowShardWarning"
    )
    Y = Y - 30

    -- Low Shard Threshold slider (only meaningful when warning is on)
    local threshSlider = CreateSlider(
        content, SECT_X + 28, Y,
        "Warning Threshold",
        50, 1000, 50,
        "lowShardThreshold",
        function(v) return v .. " shards" end
    )
    Y = Y - 50

    -- Alert: New Bountiful
    local bountAlertCB = CreateCheckbox(
        content, SECT_X, Y,
        "Chat Alert When New Bountiful Delves Rotate In",
        "alertNewBountiful"
    )
    Y = Y - 26

    -- Alert: Special Assignment
    local specAlertCB = CreateCheckbox(
        content, SECT_X, Y,
        "Chat Alert for Special Assignments",
        "alertSpecialAssignment"
    )
    Y = Y - 30

    --------------------------------------------------------------------
    -- Thin red divider
    --------------------------------------------------------------------
    local div3 = content:CreateTexture(nil, "ARTWORK")
    div3:SetHeight(1)
    div3:SetPoint("TOPLEFT", content, "TOPLEFT", SECT_X, Y)
    div3:SetPoint("RIGHT", content, "RIGHT", -8, 0)
    div3:SetColorTexture(dc.r, dc.g, dc.b, dc.a)
    Y = Y - 14

    --------------------------------------------------------------------
    -- BOTTOM BAR: Reset Defaults + Version
    --------------------------------------------------------------------
    -- Define the confirmation popup once at module init, not on every
    -- click, to avoid repeatedly rebuilding the table.
    StaticPopupDialogs["EVERYTHINGDELVES_RESET"] = {
        text = "Reset all Everything Delves settings to defaults?",
        button1 = "Yes",
        button2 = "Cancel",
        OnAccept = function()
            E:ResetDB()
            -- Reload the options tab to reflect defaults
            if frame:IsShown() then
                frame:Hide()
                frame:Show()
            end
            print(E.CC.header .. "Everything Delves|r: All settings reset.")
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }

    local resetBtn = E:CreateButton(content, 130, 24, "Reset All Settings")
    resetBtn:SetPoint("TOPLEFT", content, "TOPLEFT", SECT_X, Y)
    resetBtn:SetScript("OnClick", function()
        StaticPopup_Show("EVERYTHINGDELVES_RESET")
    end)
    resetBtn:SetScript("OnEnter", function(self)
        local hc = E.Colors.buttonHover
        self:SetBackdropColor(hc.r, hc.g, hc.b, hc.a)
        E:ShowTooltip(self, "Reset Settings",
            "Restore every option to its default value.",
            E.CC.red .. "This cannot be undone." .. E.CC.close)
    end)
    resetBtn:SetScript("OnLeave", function(self)
        local bc = E.Colors.buttonBg
        self:SetBackdropColor(bc.r, bc.g, bc.b, bc.a)
        E:HideTooltip()
    end)
    Y = Y - 34

    -- Set the scroll child height to the total content height
    scrollChild:SetHeight(math.abs(Y) + 10)

    --------------------------------------------------------------------
    -- OnShow: sync all widgets with current E.db values
    -- (handles the case where /ed reset was used externally)
    --------------------------------------------------------------------
    frame:SetScript("OnShow", function()
        -- General
        defaultTabSlider:SetValue(E.db.defaultTab or 1)
        scaleSlider:SetValue((E.db.uiScale or 1.0) * 100)
        minimapCB:SetChecked(E.db.minimapButton and E.db.minimapButton.show)

        -- Display
        for _, cb in ipairs(accentRadios) do
            cb:SetChecked(E.db.accentColor == cb.optValue)
        end
        for _, cb in ipairs(compRadios) do
            cb:SetChecked(E.db.completedDisplay == cb.optValue)
        end
        showCompCB:SetChecked(E.db.showCompletedItems)

        -- Alerts
        resetCB:SetChecked(E.db.showWeeklyResetAlert)
        sessCB:SetChecked(E.db.sessionTracking)
        lowWarnCB:SetChecked(E.db.lowShardWarning)
        threshSlider:SetValue(E.db.lowShardThreshold or 100)
        bountAlertCB:SetChecked(E.db.alertNewBountiful)
        specAlertCB:SetChecked(E.db.alertSpecialAssignment)
    end)

    --------------------------------------------------------------------
    -- Register with the main frame tab system
    --------------------------------------------------------------------
    E:RegisterTab(5, frame)
end)
