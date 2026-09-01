local E = EverythingDelves
local L = E.L

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
    E:StyleAccentHeader(genHeader, L["General"])
    Y = Y - 20

    local defaultTabSlider = CreateSlider(
        content, SECT_X, Y,
        L["Default Tab (opens to this tab)"],
        1, E.NUM_TABS, 1,
        "defaultTab",
        function(v) return E.TAB_NAMES[v] or v end
    )
    Y = Y - 50

    -- Scale stored as integer 80-150 to avoid float step issues
    local scaleLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    scaleLabel:SetPoint("TOPLEFT", content, "TOPLEFT", SECT_X, Y)
    scaleLabel:SetFont(scaleLabel:GetFont(), 11)
    scaleLabel:SetText(E.CC.body .. L["UI Scale"] .. E.CC.close)

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

    local resetBtn = E:CreateButton(content, 50, 22, L["Reset"])
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

    local function CommitScale()
        local pct = math_floor(scaleSlider:GetValue())
        local scale = pct / 100
        E.db.uiScale = scale
        scaleInput:SetNumber(pct)
        if E.MainFrame then E.MainFrame:SetScale(scale) end
    end

    -- Preview the % live while dragging but only rescale the window on release,
    -- so the UI doesn't jitter under the cursor mid-drag.
    scaleSlider:SetScript("OnValueChanged", function(_, value)
        scaleInput:SetNumber(math_floor(value))
    end)
    scaleSlider:SetScript("OnMouseUp", CommitScale)
    Y = Y - 50

    local minimapCB = CreateCheckbox(
        content, SECT_X, Y,
        L["Show Minimap / Broker Button"],
        nil
    )
    -- minimapButton.show lives in a sub-table, handled manually
    minimapCB:SetChecked(E.db.minimapButton and E.db.minimapButton.show)
    minimapCB:SetScript("OnClick", function(self)
        local checked = self:GetChecked()
        E:SetMinimapButtonVisible(checked)
    end)
    Y = Y - 28

    local shardWeeklyCB = CreateCheckbox(
        content, SECT_X, Y,
        L["Show weekly earnable shards in button tooltip"],
        "showShardWeekly"
    )
    shardWeeklyCB:SetScript("OnEnter", function(self)
        E:ShowTooltip(self, L["Weekly Shards in Tooltip"],
            L["On the minimap / broker button tooltip, shows your Coffer Key Shards as owned / still-earnable-this-week instead of just the owned count."])
    end)
    shardWeeklyCB:SetScript("OnLeave", function() E:HideTooltip() end)
    Y = Y - 28

    local whatsNewCB = CreateCheckbox(
        content, SECT_X, Y,
        L["Show What's New after an update"],
        "showWhatsNew"
    )
    whatsNewCB:SetScript("OnEnter", function(self)
        E:ShowTooltip(self, L["What's New Popup"],
            L["Shows the What's New window once after each update. You can always reopen it from the About tab or with /ed whatsnew."])
    end)
    whatsNewCB:SetScript("OnLeave", function() E:HideTooltip() end)
    Y = Y - 28

    -- Anchored beside the Default Tab slider so it doesn't consume a Y row
    local troveCB = CreateCheckbox(
        content, SECT_X, Y,
        L["Show Trovehunter's Bounty reminder on Delve entry"],
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
    E:StyleAccentHeader(dispHeader, L["Display"])
    Y = Y - 20

    local classHex = "|cFF" .. E:GetClassAccentColor().hex
    local accentOptions = {
        { value = "gold",     label = L["%s (default)"]:format("|cFFFFD100" .. L["Gold"] .. "|r") },
        { value = "red",      label = "|cFFFF2222" .. L["Red"] .. "|r" },
        { value = "purple",   label = "|cFFB280FF" .. L["Purple"] .. "|r" },
        { value = "green",    label = "|cFF4CD94C" .. L["Dark Green"] .. "|r" },
        { value = "darkblue", label = "|cFF3388FF" .. L["Dark Blue"] .. "|r" },
        { value = "class",    label = classHex .. L["Class Color"] .. "|r" },
    }
    local accentRadios = CreateRadioGroup(
        content, SECT_X, Y,
        L["Accent Color"],
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
        { value = "summary", label = L["Summary line — hold Shift for details (default)"] },
        { value = "full",    label = L["Always show full details"] },
        { value = "off",     label = L["Off"] },
    }
    local achTipRadios = CreateRadioGroup(
        content, SECT_X, Y,
        L["Delve Achievements on Map Tooltips"],
        "achievementTooltip",
        achTipOptions
    )
    Y = Y - 20 - (#achTipOptions * 24) - 4
    Y = Y - 8

    local objCB = CreateCheckbox(
        content, SECT_X, Y,
        L["Show Bonus Spoils Tracker"],
        "showDelveObjectives",
        function()
            if E.UpdateDelveObjectivesWindow then
                E:UpdateDelveObjectivesWindow()
            end
        end
    )
    objCB:SetScript("OnEnter", function(self)
        E:ShowTooltip(self, L["Bonus Spoils Tracker"],
            L["While inside a delve, tracks the two bonus-chest objectives - Nemesis Strongbox packs and the Sanctified Banner - so you know you've grabbed the extra loot before pulling the boss."],
            " ",
            L["Drag the tracker to move it."])
    end)
    objCB:SetScript("OnLeave", function() E:HideTooltip() end)
    Y = Y - 30

    local timerCB = CreateCheckbox(
        content, SECT_X, Y,
        L["Show Run Timer"],
        "showRunTimer",
        function()
            if E.UpdateDelveObjectivesWindow then
                E:UpdateDelveObjectivesWindow()
            end
        end
    )
    timerCB:SetScript("OnEnter", function(self)
        E:ShowTooltip(self, L["Run Timer"],
            L["Shows your elapsed run time on a small on-screen display while you're inside a delve. Works on its own - you don't need the Bonus Spoils tracker."],
            " ",
            L["Drag the display to move it."])
    end)
    timerCB:SetScript("OnLeave", function() E:HideTooltip() end)
    Y = Y - 30

    local hudCB = CreateCheckbox(
        content, SECT_X, Y,
        L["Show Delve HUD"],
        "showDelveHUD",
        function()
            if E.UpdateDelveObjectivesWindow then
                E:UpdateDelveObjectivesWindow()
            end
        end
    )
    hudCB:SetScript("OnEnter", function(self)
        E:ShowTooltip(self, L["Delve HUD"],
            L["An on-screen panel while inside a delve showing the story variant and its grade, the recommended curios and poison for your companion, your run timer, and your death count."],
            " ",
            L["Shares the on-screen frame with the Run Timer and Bonus Spoils tracker - drag any of them to move it."])
    end)
    hudCB:SetScript("OnLeave", function() E:HideTooltip() end)
    Y = Y - 30

    local resultCB = CreateCheckbox(
        content, SECT_X, Y,
        L["Show Best Time & keep timer after boss"],
        "showRunResult",
        function()
            if E.UpdateDelveObjectivesWindow then
                E:UpdateDelveObjectivesWindow()
            end
        end
    )
    resultCB:SetScript("OnEnter", function(self)
        E:ShowTooltip(self, L["Best Time & Run Result"],
            L["Adds your fastest time for the current delve to the on-screen panel (your best at this tier, or your overall best labelled with its tier), and keeps the run timer up after you beat the boss - green if you beat your best time at this tier, red if not. Needs one previous run logged."])
    end)
    resultCB:SetScript("OnLeave", function() E:HideTooltip() end)
    Y = Y - 30

    local pickerCB = CreateCheckbox(
        content, SECT_X, Y,
        L["Show Tier & Achievement Panel at Delve Entrance"],
        "showPickerInfo"
    )
    pickerCB:SetScript("OnEnter", function(self)
        E:ShowTooltip(self, L["Tier & Achievement Panel"],
            L["When you open a delve's difficulty picker at its entrance, shows a panel with the loot and Great Vault item levels for every tier, plus your story, chest, and tier-goal achievement progress for that delve."])
    end)
    pickerCB:SetScript("OnLeave", function() E:HideTooltip() end)
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
    E:StyleAccentHeader(alertHeader, L["Alerts & Tracking"])
    Y = Y - 20


    local lowWarnCB = CreateCheckbox(
        content, SECT_X, Y,
        L["Low Shard Warning"],
        "lowShardWarning"
    )
    Y = Y - 30

    local threshSlider = CreateSlider(
        content, SECT_X + 28, Y,
        L["Warning Threshold"],
        50, 1000, 50,
        "lowShardThreshold",
        function(v) return L["%d shards"]:format(v) end
    )
    Y = Y - 50

    local bountAlertCB = CreateCheckbox(
        content, SECT_X, Y,
        L["Chat Alert When New Bountiful Delves Rotate In"],
        "alertNewBountiful"
    )
    Y = Y - 26

    local specAlertCB = CreateCheckbox(
        content, SECT_X, Y,
        L["Chat Alert for Special Assignments"],
        "alertSpecialAssignment"
    )
    Y = Y - 26

    local roleAlertCB = CreateCheckbox(
        content, SECT_X, Y,
        L["Warn When Companion Has No Role Assigned"],
        "alertCompanionRole"
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
    E:StyleAccentHeader(audioHeader, L["Companion Audio"])
    Y = Y - 20

    local muteValeeraCB = CreateCheckbox(
        content, SECT_X, Y,
        L["Mute Valeera voice lines"],
        "muteValeera",
        function() if E.ApplyCompanionAudio then E:ApplyCompanionAudio() end end
    )
    Y = Y - 26

    local muteBubblesCB = CreateCheckbox(
        content, SECT_X, Y,
        L["Suppress Valeera speech bubbles"],
        "muteValeeraBubbles",
        function() if E.ApplyCompanionAudio then E:ApplyCompanionAudio() end end
    )
    Y = Y - 26

    local muteDundunCB = CreateCheckbox(
        content, SECT_X, Y,
        L["Mute Dundun (Abundance event rat) voice lines"],
        "muteDundun",
        function() if E.ApplyCompanionAudio then E:ApplyCompanionAudio() end end
    )
    muteDundunCB:SetScript("OnEnter", function(self)
        E:ShowTooltip(self, L["Who is Dundun?"],
            L["Dundun is the rat loa who hosts the Abundance cave events and repeats his voice lines endlessly. Muting only silences his audio - the event itself is unaffected."])
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
        text = L["Reset all Everything Delves settings to defaults?"],
        button1 = L["Yes"],
        button2 = L["Cancel"],
        OnAccept = function()
            E:ResetDB()
            if frame:IsShown() then
                frame:Hide()
                frame:Show()
            end
            print(E.CC.header .. "Everything Delves|r: " .. L["All settings reset."])
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }

    StaticPopupDialogs["EVERYTHINGDELVES_CLEAR_HISTORY"] = {
        text = L["Are you sure you want to clear all Delve History?\n\nThis will permanently erase all lifetime stats, run history, and personal bests for every delve on this character. This cannot be undone."],
        button1 = L["Yes, Erase Everything"],
        button2 = L["Cancel"],
        OnAccept = function()
            E:ClearDelveHistory()
            print(E.CC.header .. "Everything Delves|r: " .. L["Delve history cleared."])
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }

    local resetBtn = E:CreateButton(content, 130, 24, L["Reset All Settings"])
    resetBtn:SetPoint("TOPLEFT", content, "TOPLEFT", SECT_X, Y)
    resetBtn:SetScript("OnClick", function()
        StaticPopup_Show("EVERYTHINGDELVES_RESET")
    end)
    resetBtn:SetScript("OnEnter", function(self)
        local hc = E.Colors.buttonHover
        self:SetBackdropColor(hc.r, hc.g, hc.b, hc.a)
        E:ShowTooltip(self, L["Reset Settings"],
            L["Restore every option to its default value."],
            E.CC.red .. L["This cannot be undone."] .. E.CC.close)
    end)
    resetBtn:SetScript("OnLeave", function(self)
        local bc = E.Colors.buttonBg
        self:SetBackdropColor(bc.r, bc.g, bc.b, bc.a)
        E:HideTooltip()
    end)

    local clearHistBtn = E:CreateButton(content, 150, 24, L["Clear Delve History"])
    clearHistBtn:SetPoint("LEFT", resetBtn, "RIGHT", 10, 0)
    clearHistBtn:SetScript("OnClick", function()
        StaticPopup_Show("EVERYTHINGDELVES_CLEAR_HISTORY")
    end)
    clearHistBtn:SetScript("OnEnter", function(self)
        local hc = E.Colors.buttonHover
        self:SetBackdropColor(hc.r, hc.g, hc.b, hc.a)
        E:ShowTooltip(self, L["Clear Delve History"],
            L["Erase all recorded delve runs and lifetime stats for this character."],
            "",
            E.CC.red .. L["This cannot be undone."] .. E.CC.close)
    end)
    clearHistBtn:SetScript("OnLeave", function(self)
        local bc = E.Colors.buttonBg
        self:SetBackdropColor(bc.r, bc.g, bc.b, bc.a)
        E:HideTooltip()
    end)
    Y = Y - 34

    scrollChild:SetHeight(math.abs(Y) + 10)
    UpdateScrollRange()

    -- For a setting written while this tab is already open. CreateCheckbox's
    -- handler writes self:GetChecked(), so a stale box's next click writes the
    -- value the DB already holds and reads as a no-op.
    function E:RefreshOptionsWidgets()
        defaultTabSlider:SetValue(self.db.defaultTab or 1)
        scaleSlider:SetValue((self.db.uiScale or 1.0) * 100)
        minimapCB:SetChecked(self.db.minimapButton and self.db.minimapButton.show)
        troveCB:SetChecked(self.db.showTrovehunterReminder ~= false)
        shardWeeklyCB:SetChecked(self.db.showShardWeekly == true)
        whatsNewCB:SetChecked(self.db.showWhatsNew ~= false)
        resultCB:SetChecked(self.db.showRunResult ~= false)
        objCB:SetChecked(self.db.showDelveObjectives == true)
        timerCB:SetChecked(self.db.showRunTimer ~= false)
        hudCB:SetChecked(self.db.showDelveHUD ~= false)
        pickerCB:SetChecked(self.db.showPickerInfo ~= false)

        for _, cb in ipairs(accentRadios) do
            cb:SetChecked(self.db.accentColor == cb.optValue)
        end
        for _, cb in ipairs(achTipRadios) do
            cb:SetChecked(self.db.achievementTooltip == cb.optValue)
        end

        lowWarnCB:SetChecked(self.db.lowShardWarning)
        threshSlider:SetValue(self.db.lowShardThreshold or 100)
        bountAlertCB:SetChecked(self.db.alertNewBountiful)
        specAlertCB:SetChecked(self.db.alertSpecialAssignment)
        roleAlertCB:SetChecked(self.db.alertCompanionRole ~= false)

        muteValeeraCB:SetChecked(self.db.muteValeera == true)
        muteBubblesCB:SetChecked(self.db.muteValeeraBubbles == true)
        muteDundunCB:SetChecked(self.db.muteDundun == true)
    end

    frame:SetScript("OnShow", function()
        scrollFrame:SetVerticalScroll(0)
        tabScrollBar:SetValue(0)
        UpdateScrollRange()
        E:RefreshOptionsWidgets()
    end)

    E:RegisterTab(9, frame)
end)
