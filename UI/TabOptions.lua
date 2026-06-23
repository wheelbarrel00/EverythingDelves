local E = EverythingDelves

local math_floor, math_max, math_min = math.floor, math.max, math.min

local function CreateCheckbox(parent, x, y, labelText, dbKey, onChange)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    cb:SetSize(24, 24)
    cb:SetChecked(E.db[dbKey] == true)

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

local function CreateSlider(parent, x, y, labelText, minVal, maxVal, step, dbKey, formatter, onChange)
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

    if slider.Low  then slider.Low:SetText("")  end
    if slider.High then slider.High:SetText("") end

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
        val = math_floor(val / step + 0.5) * step
        E.db[dbKey] = val
        UpdateText(val)
        if onChange then onChange(val) end
    end)

    return slider
end

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

E:RegisterModule(function()
    local frame = CreateFrame("Frame", "EverythingDelvesTabOptionsContent")

    local scrollFrame = CreateFrame("ScrollFrame", nil, frame)
    scrollFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -18, 4)
    scrollFrame:EnableMouseWheel(true)

    local scrollChild = CreateFrame("Frame")
    scrollChild:SetWidth(scrollFrame:GetWidth() or 580)
    scrollFrame:SetScrollChild(scrollChild)

    scrollFrame:SetScript("OnSizeChanged", function(self, w, h)
        scrollChild:SetWidth(w)
    end)

    local tabScrollBar = CreateFrame("Slider", nil, scrollFrame, "BackdropTemplate")
    tabScrollBar:SetWidth(14)
    tabScrollBar:SetPoint("TOPRIGHT", scrollFrame, "TOPRIGHT", 16, 0)
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
        local maxScroll = math_max(0, scrollChild:GetHeight() - self:GetHeight())
        local newVal = math_max(0, math_min(
            self:GetVerticalScroll() - delta * 30, maxScroll))
        self:SetVerticalScroll(newVal)
        tabScrollBar:SetValue(newVal)
    end)

    local function UpdateScrollRange()
        local maxScroll = math_max(0, scrollChild:GetHeight() - scrollFrame:GetHeight())
        tabScrollBar:SetMinMaxValues(0, maxScroll)
        if maxScroll <= 0 then
            tabScrollBar:Hide()
        else
            tabScrollBar:Show()
        end
    end

    local content = scrollChild

    local SECT_X = 8
    local Y = -6

    -- General
    local genHeader = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    genHeader:SetPoint("TOPLEFT", content, "TOPLEFT", SECT_X, Y)
    genHeader:SetFont(genHeader:GetFont(), E.HEADER_FONT_SIZE, "OUTLINE")
    E:StyleAccentHeader(genHeader, "General")
    Y = Y - 20

    local defaultTabSlider = CreateSlider(
        content, SECT_X, Y,
        "Default Tab (opens to this tab)",
        1, E.NUM_TABS, 1,
        "defaultTab",
        function(v) return E.TAB_NAMES[v] or v end
    )
    Y = Y - 50

    -- Scale stored as integer 80-150 to avoid float step issues
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

    local function ApplyFromInput()
        local raw = scaleInput:GetNumber()
        local pct = math_max(80, math_min(150, raw))
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

    local minimapCB = CreateCheckbox(
        content, SECT_X, Y,
        "Show Minimap / Broker Button",
        nil
    )
    -- minimapButton.show lives in a sub-table, handled manually
    minimapCB:SetChecked(E.db.minimapButton and E.db.minimapButton.show)
    minimapCB:SetScript("OnClick", function(self)
        local checked = self:GetChecked()
        E:SetMinimapButtonVisible(checked)
    end)
    Y = Y - 28

    -- Anchored beside the Default Tab slider so it doesn't consume a Y row
    local troveCB = CreateCheckbox(
        content, SECT_X, Y,
        "Show Trovehunter's Bounty reminder on Delve entry",
        "showTrovehunterReminder"
    )
    troveCB:ClearAllPoints()
    troveCB:SetPoint("LEFT", defaultTabSlider, "RIGHT", 200, 0)
    local troveIcon = content:CreateTexture(nil, "OVERLAY")
    troveIcon:SetSize(20, 20)
    troveIcon:SetPoint("LEFT", troveCB, "RIGHT", 4, 0)
    troveIcon:SetTexture(1064187)
    troveCB.labelFS:ClearAllPoints()
    troveCB.labelFS:SetPoint("LEFT", troveIcon, "RIGHT", 6, 0)

    Y = Y - 28

    local div1 = content:CreateTexture(nil, "ARTWORK")
    div1:SetHeight(1)
    div1:SetPoint("TOPLEFT", content, "TOPLEFT", SECT_X, Y)
    div1:SetPoint("RIGHT", content, "RIGHT", -8, 0)
    E:StyleAccentDivider(div1)
    Y = Y - 34

    -- Display
    local dispHeader = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    dispHeader:SetPoint("TOPLEFT", content, "TOPLEFT", SECT_X, Y)
    dispHeader:SetFont(dispHeader:GetFont(), E.HEADER_FONT_SIZE, "OUTLINE")
    E:StyleAccentHeader(dispHeader, "Display")
    Y = Y - 20

    local accentOptions = {
        { value = "gold",     label = "|cFFFFD100Gold|r (default)" },
        { value = "red",      label = "|cFFFF2222Red|r" },
        { value = "purple",   label = "|cFFB280FFPurple|r" },
        { value = "green",    label = "|cFF4CD94CDark Green|r" },
        { value = "darkblue", label = "|cFF3388FFDark Blue|r" },
    }
    local accentRadios = CreateRadioGroup(
        content, SECT_X, Y,
        "Accent Color",
        "accentColor",
        accentOptions,
        function(value)
            if E.ApplyAccentColor then
                E:ApplyAccentColor(value)
            end
        end
    )
    Y = Y - 20 - (#accentOptions * 24) - 4
    Y = Y - 12

    local achTipOptions = {
        { value = "summary", label = "Summary line — hold Shift for details (default)" },
        { value = "full",    label = "Always show full details" },
        { value = "off",     label = "Off" },
    }
    CreateRadioGroup(
        content, SECT_X, Y,
        "Delve Achievements on Map Tooltips",
        "achievementTooltip",
        achTipOptions
    )
    Y = Y - 20 - (#achTipOptions * 24) - 4
    Y = Y - 8

    local objCB = CreateCheckbox(
        content, SECT_X, Y,
        "Show Bonus Spoils Tracker",
        "showDelveObjectives",
        function()
            if E.UpdateDelveObjectivesWindow then
                E:UpdateDelveObjectivesWindow()
            end
        end
    )
    objCB:SetScript("OnEnter", function(self)
        E:ShowTooltip(self, "Bonus Spoils Tracker",
            "While inside a delve, tracks the two bonus-chest",
            "objectives - Nemesis Strongbox packs and the",
            "Sanctified Banner - so you know you've grabbed the",
            "extra loot before pulling the boss.",
            " ",
            "Drag the tracker to move it.")
    end)
    objCB:SetScript("OnLeave", function() E:HideTooltip() end)
    Y = Y - 30

    Y = Y - 28

    local div2 = content:CreateTexture(nil, "ARTWORK")
    div2:SetHeight(1)
    div2:SetPoint("TOPLEFT", content, "TOPLEFT", SECT_X, Y)
    div2:SetPoint("RIGHT", content, "RIGHT", -8, 0)
    E:StyleAccentDivider(div2)
    Y = Y - 34

    -- Alerts & Tracking
    local alertHeader = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    alertHeader:SetPoint("TOPLEFT", content, "TOPLEFT", SECT_X, Y)
    alertHeader:SetFont(alertHeader:GetFont(), E.HEADER_FONT_SIZE, "OUTLINE")
    E:StyleAccentHeader(alertHeader, "Alerts & Tracking")
    Y = Y - 20


    local lowWarnCB = CreateCheckbox(
        content, SECT_X, Y,
        "Low Shard Warning",
        "lowShardWarning"
    )
    Y = Y - 30

    local threshSlider = CreateSlider(
        content, SECT_X + 28, Y,
        "Warning Threshold",
        50, 1000, 50,
        "lowShardThreshold",
        function(v) return v .. " shards" end
    )
    Y = Y - 50

    local bountAlertCB = CreateCheckbox(
        content, SECT_X, Y,
        "Chat Alert When New Bountiful Delves Rotate In",
        "alertNewBountiful"
    )
    Y = Y - 26

    local specAlertCB = CreateCheckbox(
        content, SECT_X, Y,
        "Chat Alert for Special Assignments",
        "alertSpecialAssignment"
    )
    Y = Y - 30

    Y = Y - 28

    local div3 = content:CreateTexture(nil, "ARTWORK")
    div3:SetHeight(1)
    div3:SetPoint("TOPLEFT", content, "TOPLEFT", SECT_X, Y)
    div3:SetPoint("RIGHT", content, "RIGHT", -8, 0)
    E:StyleAccentDivider(div3)
    Y = Y - 34

    -- Companion Audio
    local audioHeader = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    audioHeader:SetPoint("TOPLEFT", content, "TOPLEFT", SECT_X, Y)
    audioHeader:SetFont(audioHeader:GetFont(), E.HEADER_FONT_SIZE, "OUTLINE")
    E:StyleAccentHeader(audioHeader, "Companion Audio")
    Y = Y - 20

    local muteValeeraCB = CreateCheckbox(
        content, SECT_X, Y,
        "Mute Valeera voice lines",
        "muteValeera",
        function() if E.ApplyCompanionAudio then E:ApplyCompanionAudio() end end
    )
    Y = Y - 26

    local muteBubblesCB = CreateCheckbox(
        content, SECT_X, Y,
        "Suppress Valeera speech bubbles",
        "muteValeeraBubbles",
        function() if E.ApplyCompanionAudio then E:ApplyCompanionAudio() end end
    )
    Y = Y - 26

    local muteDundunCB = CreateCheckbox(
        content, SECT_X, Y,
        "Mute Dundun (Abundance event rat) voice lines",
        "muteDundun",
        function() if E.ApplyCompanionAudio then E:ApplyCompanionAudio() end end
    )
    muteDundunCB:SetScript("OnEnter", function(self)
        E:ShowTooltip(self, "Who is Dundun?",
            "Dundun is the rat loa who hosts the Abundance",
            "cave events and repeats his voice lines endlessly.",
            "Muting only silences his audio - the event",
            "itself is unaffected.")
    end)
    muteDundunCB:SetScript("OnLeave", function() E:HideTooltip() end)
    Y = Y - 30

    Y = Y - 28

    local div4 = content:CreateTexture(nil, "ARTWORK")
    div4:SetHeight(1)
    div4:SetPoint("TOPLEFT", content, "TOPLEFT", SECT_X, Y)
    div4:SetPoint("RIGHT", content, "RIGHT", -8, 0)
    E:StyleAccentDivider(div4)
    Y = Y - 34

    StaticPopupDialogs["EVERYTHINGDELVES_RESET"] = {
        text = "Reset all Everything Delves settings to defaults?",
        button1 = "Yes",
        button2 = "Cancel",
        OnAccept = function()
            E:ResetDB()
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

    StaticPopupDialogs["EVERYTHINGDELVES_CLEAR_HISTORY"] = {
        text = "Are you sure you want to clear all Delve History?\n\n"
            .. "This will permanently erase all lifetime stats, run "
            .. "history, and personal bests for every delve on this "
            .. "character. This cannot be undone.",
        button1 = "Yes, Erase Everything",
        button2 = "Cancel",
        OnAccept = function()
            E:ClearDelveHistory()
            print(E.CC.header .. "Everything Delves|r: Delve history cleared.")
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

    local clearHistBtn = E:CreateButton(content, 150, 24, "Clear Delve History")
    clearHistBtn:SetPoint("LEFT", resetBtn, "RIGHT", 10, 0)
    clearHistBtn:SetScript("OnClick", function()
        StaticPopup_Show("EVERYTHINGDELVES_CLEAR_HISTORY")
    end)
    clearHistBtn:SetScript("OnEnter", function(self)
        local hc = E.Colors.buttonHover
        self:SetBackdropColor(hc.r, hc.g, hc.b, hc.a)
        E:ShowTooltip(self, "Clear Delve History",
            "Erase all recorded delve runs and lifetime stats",
            "for this character.",
            "",
            E.CC.red .. "This cannot be undone." .. E.CC.close)
    end)
    clearHistBtn:SetScript("OnLeave", function(self)
        local bc = E.Colors.buttonBg
        self:SetBackdropColor(bc.r, bc.g, bc.b, bc.a)
        E:HideTooltip()
    end)
    Y = Y - 34

    scrollChild:SetHeight(math.abs(Y) + 10)
    UpdateScrollRange()

    -- Re-sync widgets with E.db on show, in case /ed reset was used externally
    frame:SetScript("OnShow", function()
        scrollFrame:SetVerticalScroll(0)
        tabScrollBar:SetValue(0)
        UpdateScrollRange()

        defaultTabSlider:SetValue(E.db.defaultTab or 1)
        scaleSlider:SetValue((E.db.uiScale or 1.0) * 100)
        minimapCB:SetChecked(E.db.minimapButton and E.db.minimapButton.show)
        troveCB:SetChecked(E.db.showTrovehunterReminder ~= false)

        for _, cb in ipairs(accentRadios) do
            cb:SetChecked(E.db.accentColor == cb.optValue)
        end

        lowWarnCB:SetChecked(E.db.lowShardWarning)
        threshSlider:SetValue(E.db.lowShardThreshold or 100)
        bountAlertCB:SetChecked(E.db.alertNewBountiful)
        specAlertCB:SetChecked(E.db.alertSpecialAssignment)

        muteValeeraCB:SetChecked(E.db.muteValeera == true)
        muteBubblesCB:SetChecked(E.db.muteValeeraBubbles == true)
        muteDundunCB:SetChecked(E.db.muteDundun == true)
    end)

    E:RegisterTab(9, frame)
end)
