------------------------------------------------------------------------
-- UI/TabNullaeus.lua - Tab 4: Nullaeus
-- The Nemesis Delve: weekly quest tracker, Beacon of Hope inventory,
-- boss mechanics reference, phase transitions, and reward list.
------------------------------------------------------------------------
local E = EverythingDelves

local math_floor, math_max, math_min = math.floor, math.max, math.min

--- Resolve an item's icon texture from its ID. GetItemInfoInstant /
--- GetItemIconByID return immediately (no server round-trip) so this is
--- safe to call during layout.
local function GetRewardIcon(itemID)
    if not itemID then return nil end
    if C_Item and C_Item.GetItemIconByID then
        local icon = C_Item.GetItemIconByID(itemID)
        if icon then return icon end
    end
    if C_Item and C_Item.GetItemInfoInstant then
        local _, _, _, _, icon = C_Item.GetItemInfoInstant(itemID)
        return icon
    end
    return nil
end

------------------------------------------------------------------------
-- MODULE INIT
------------------------------------------------------------------------
E:RegisterModule(function()
    local frame = CreateFrame("Frame", "EverythingDelvesTabNullaeusContent")

    --------------------------------------------------------------------
    -- SCROLLABLE AREA
    --------------------------------------------------------------------
    local scrollFrame = CreateFrame("ScrollFrame", nil, frame)
    scrollFrame:SetPoint("TOPLEFT",     frame, "TOPLEFT",     0,   0)
    scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -18, 0)
    scrollFrame:EnableMouseWheel(true)

    local sc = CreateFrame("Frame")
    sc:SetSize(1, 1)
    scrollFrame:SetScrollChild(sc)

    scrollFrame:SetScript("OnSizeChanged", function(self, w)
        sc:SetWidth(w)
    end)
    sc:SetHeight(1400)

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
        if maxScroll <= 0 then
            tabScrollBar:Hide()
        else
            tabScrollBar:Show()
        end
    end

    local GRID_X = 8

    --------------------------------------------------------------------
    -- HEADER + QUEST STATUS
    --------------------------------------------------------------------
    local NEMESIS_MAP   = 2405
    local NEMESIS_X     = 61.17
    local NEMESIS_Y     = 71.37
    local NEMESIS_QUEST = 93525
    local NEMESIS_ICON  = "Interface\\Icons\\Inv_120_raid_voidspire_hostgeneral"
    local PORTRAIT_MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"

    local mainHeader = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    mainHeader:SetPoint("TOPLEFT", sc, "TOPLEFT", GRID_X, -4)
    mainHeader:SetFont(mainHeader:GetFont(), E.HEADER_FONT_SIZE, "OUTLINE")
    E:StyleAccentHeader(mainHeader, "The Nemesis Delve")

    local nemIcon = sc:CreateTexture(nil, "ARTWORK")
    nemIcon:SetPoint("TOPLEFT", mainHeader, "BOTTOMLEFT", 0, -6)
    nemIcon:SetSize(40, 40)
    nemIcon:SetTexture(NEMESIS_ICON)
    if nemIcon.SetMask then
        pcall(nemIcon.SetMask, nemIcon, PORTRAIT_MASK)
    end

    local nemNameFS = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    nemNameFS:SetPoint("LEFT", nemIcon, "RIGHT", 8, 8)
    nemNameFS:SetFont(nemNameFS:GetFont(), 14)
    nemNameFS:SetText(
        E.CC.gold .. "Nullaeus" .. E.CC.close
        .. E.CC.muted .. "  \226\128\148  Voidstorm  \226\128\148  Torment's Rise" .. E.CC.close
    )

    local nemSubFS = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    nemSubFS:SetPoint("LEFT", nemIcon, "RIGHT", 8, -8)
    nemSubFS:SetFont(nemSubFS:GetFont(), 10)
    nemSubFS:SetText(
        E.CC.muted
        .. "Weekly Nemesis Delve  \226\128\148  Defeat at 50% HP to complete the weekly bounty"
        .. E.CC.close
    )

    local nemWpBtn = E:CreateButton(sc, 32, 20, "Pin")
    nemWpBtn.label:SetFont(nemWpBtn.label:GetFont(), 10)
    nemWpBtn:SetPoint("TOPLEFT", nemIcon, "TOPRIGHT", 380, -10)
    nemWpBtn:SetScript("OnClick", function()
        E:SetWaypoint(NEMESIS_MAP, NEMESIS_X, NEMESIS_Y)
        E:FlashButtonConfirm(nemWpBtn)
    end)
    nemWpBtn:SetScript("OnEnter", function(self)
        local hc = E.Colors.buttonHover
        self:SetBackdropColor(hc.r, hc.g, hc.b, hc.a)
        E:ShowTooltip(self, "Set Waypoint", "Pin Nullaeus on your map.")
    end)
    nemWpBtn:SetScript("OnLeave", function(self)
        local bc = E.Colors.buttonBg
        self:SetBackdropColor(bc.r, bc.g, bc.b, bc.a)
        E:HideTooltip()
    end)

    local nemTTBtn = E:CreateButton(sc, 50, 20, "TomTom")
    nemTTBtn.label:SetFont(nemTTBtn.label:GetFont(), 10)
    nemTTBtn:SetPoint("LEFT", nemWpBtn, "RIGHT", 4, 0)
    nemTTBtn:SetScript("OnClick", function()
        E:AddTomTomWaypoint(NEMESIS_MAP, NEMESIS_X, NEMESIS_Y, "Nullaeus")
        E:FlashButtonConfirm(nemTTBtn)
    end)
    nemTTBtn:SetScript("OnEnter", function(self)
        local hc = E.Colors.buttonHover
        self:SetBackdropColor(hc.r, hc.g, hc.b, hc.a)
        if E:IsTomTomLoaded() then
            E:ShowTooltip(self, "TomTom Waypoint", "Add a TomTom arrow to Nullaeus.")
        else
            E:ShowTooltip(self, "TomTom Not Installed",
                          "Install the TomTom addon to use arrow waypoints.")
        end
    end)
    nemTTBtn:SetScript("OnLeave", function(self)
        local bc = E.Colors.buttonBg
        self:SetBackdropColor(bc.r, bc.g, bc.b, bc.a)
        E:HideTooltip()
    end)

    local nemStatusFS = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    nemStatusFS:SetPoint("TOPLEFT", nemIcon, "BOTTOMLEFT", 0, -6)
    nemStatusFS:SetFont(nemStatusFS:GetFont(), 11)

    local div1 = sc:CreateTexture(nil, "ARTWORK")
    div1:SetHeight(1)
    div1:SetPoint("TOPLEFT", nemStatusFS, "BOTTOMLEFT", 0, -16)
    div1:SetPoint("RIGHT", sc, "RIGHT", -8, 0)
    E:StyleAccentDivider(div1)

    --------------------------------------------------------------------
    -- BEACON OF HOPE
    --------------------------------------------------------------------
    local BEACON_ITEM_ID = 253342
    local UNDERCOIN_ID   = 2803
    local BEACON_PRICE   = 5000

    local beaconHeader = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    beaconHeader:SetPoint("TOPLEFT", div1, "BOTTOMLEFT", 0, -24)
    beaconHeader:SetFont(beaconHeader:GetFont(), E.HEADER_FONT_SIZE, "OUTLINE")
    E:StyleAccentHeader(beaconHeader, "Beacon of Hope")

    local beaconStatusFS = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    beaconStatusFS:SetPoint("TOPLEFT", beaconHeader, "BOTTOMLEFT", 0, -4)
    beaconStatusFS:SetFont(beaconStatusFS:GetFont(), 11)

    local beaconBar = E:CreateProgressBar(sc, 0, 14)
    beaconBar:SetPoint("TOPLEFT", beaconStatusFS, "BOTTOMLEFT", 0, -6)
    beaconBar:SetPoint("RIGHT", sc, "RIGHT", -20, 0)

    local beaconNoteFS = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    beaconNoteFS:SetPoint("TOPLEFT", beaconBar, "BOTTOMLEFT", 0, -4)
    beaconNoteFS:SetFont(beaconNoteFS:GetFont(), 10)

    local beaconHintFS = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    beaconHintFS:SetPoint("TOPLEFT", beaconNoteFS, "BOTTOMLEFT", 0, -6)
    beaconHintFS:SetFont(beaconHintFS:GetFont(), 10)
    beaconHintFS:SetText(
        E.CC.muted
        .. "Enter a T7+ delve, reach the first checkpoint, then use the Beacon of Hope"
        .. " to summon Nullaeus. You only need to defeat him to 50% HP." .. E.CC.close
    )

    local div2 = sc:CreateTexture(nil, "ARTWORK")
    div2:SetHeight(1)
    div2:SetPoint("TOPLEFT", beaconHintFS, "BOTTOMLEFT", 0, -20)
    div2:SetPoint("RIGHT", sc, "RIGHT", -8, 0)
    E:StyleAccentDivider(div2)

    --------------------------------------------------------------------
    -- BOSS MECHANICS
    --------------------------------------------------------------------
    local mechHeader = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    mechHeader:SetPoint("TOPLEFT", div2, "BOTTOMLEFT", 0, -24)
    mechHeader:SetFont(mechHeader:GetFont(), E.HEADER_FONT_SIZE, "OUTLINE")
    E:StyleAccentHeader(mechHeader, "Boss Mechanics")

    local MECHANICS = {
        {
            name     = "Emptiness of the Void",
            tag      = "Interruptible AoE",
            tagColor = E.CC.red,
            desc     = "A cast that hits the whole group with shadow damage. Interrupt it whenever you can; otherwise pop a defensive — there's no dodging it.",
        },
        {
            name     = "Devouring Essence",
            tag      = "DoT — Kick / Dispel",
            tagColor = E.CC.yellow,
            desc     = "A targeted damage-over-time channel. It's both interruptible and dispellable — kick the cast, dispel the debuff, or ride it out with a cooldown.",
        },
        {
            name     = "Imploding Strike",
            tag      = "Tank Hit",
            tagColor = "|cFFFF8800",
            desc     = "A heavy physical strike on whoever holds threat. Solo players should rotate defensives or kite between casts; pre-mitigate it if you can.",
        },
    }

    local mechAnchor = mechHeader
    for i, m in ipairs(MECHANICS) do
        local nameLine = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        -- i>1 anchors to the previous description line (indented +12), so pull
        -- back -12 to keep every name line on the same left baseline.
        nameLine:SetPoint("TOPLEFT", mechAnchor, "BOTTOMLEFT", (i == 1) and 0 or -12, (i == 1) and -8 or -14)
        nameLine:SetFont(nameLine:GetFont(), 11)
        nameLine:SetText(
            E.CC.gold .. m.name .. E.CC.close
            .. E.CC.muted .. "  [" .. E.CC.close
            .. m.tagColor .. m.tag .. E.CC.close
            .. E.CC.muted .. "]" .. E.CC.close
        )
        local descLine = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        descLine:SetPoint("TOPLEFT", nameLine, "BOTTOMLEFT", 12, -2)
        descLine:SetPoint("RIGHT", sc, "RIGHT", -20, 0)
        descLine:SetFont(descLine:GetFont(), 10)
        descLine:SetJustifyH("LEFT")
        descLine:SetText(E.CC.body .. m.desc .. E.CC.close)
        mechAnchor = descLine
    end

    local div3 = sc:CreateTexture(nil, "ARTWORK")
    div3:SetHeight(1)
    div3:SetPoint("TOPLEFT", mechAnchor, "BOTTOMLEFT", 0, -20)
    div3:SetPoint("RIGHT", sc, "RIGHT", -8, 0)
    E:StyleAccentDivider(div3)

    --------------------------------------------------------------------
    -- PHASE TRANSITIONS
    --------------------------------------------------------------------
    local phaseHeader = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    phaseHeader:SetPoint("TOPLEFT", div3, "BOTTOMLEFT", 0, -24)
    phaseHeader:SetFont(phaseHeader:GetFont(), E.HEADER_FONT_SIZE, "OUTLINE")
    E:StyleAccentHeader(phaseHeader, "Phase Transitions")

    -- Each HP threshold triggers a ~30-second intermission with its own
    -- signature hazard.
    local PHASES = {
        {
            pct  = "75%",
            name = "Null Zone",
            desc = "First intermission. Void energy pools spread across the floor — keep moving and stay clear of the Null Zones until the phase ends.",
        },
        {
            pct  = "50%",
            name = "Gravity Well",
            desc = "Second intermission. A Gravity Well orb drags you toward it — run against the pull and use mobility to avoid being pulled into hazards.",
        },
        {
            pct  = "25%",
            name = "Umbral Rage",
            desc = "Final intermission and soft enrage. Umbral Rage stacks keep ramping his damage the longer he lives — burn him down fast before it overwhelms you.",
        },
    }

    local phaseAnchor = phaseHeader
    for i, ph in ipairs(PHASES) do
        local pctLine = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        -- i>1 anchors to the previous description line (indented +12), so pull
        -- back -12 to keep every percentage line on the same left baseline.
        pctLine:SetPoint("TOPLEFT", phaseAnchor, "BOTTOMLEFT", (i == 1) and 0 or -12, (i == 1) and -8 or -14)
        pctLine:SetFont(pctLine:GetFont(), 11)
        pctLine:SetText(
            E.CC.red .. ph.pct .. " HP" .. E.CC.close
            .. E.CC.muted .. "  \226\128\148  " .. E.CC.close
            .. E.CC.gold .. ph.name .. E.CC.close
        )
        local descLine = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        descLine:SetPoint("TOPLEFT", pctLine, "BOTTOMLEFT", 12, -2)
        descLine:SetPoint("RIGHT", sc, "RIGHT", -20, 0)
        descLine:SetFont(descLine:GetFont(), 10)
        descLine:SetJustifyH("LEFT")
        descLine:SetText(E.CC.body .. ph.desc .. E.CC.close)
        phaseAnchor = descLine
    end

    local div4 = sc:CreateTexture(nil, "ARTWORK")
    div4:SetHeight(1)
    div4:SetPoint("TOPLEFT", phaseAnchor, "BOTTOMLEFT", 0, -20)
    div4:SetPoint("RIGHT", sc, "RIGHT", -8, 0)
    E:StyleAccentDivider(div4)

    --------------------------------------------------------------------
    -- REWARDS
    --------------------------------------------------------------------
    local rewardHeader = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    rewardHeader:SetPoint("TOPLEFT", div4, "BOTTOMLEFT", 0, -24)
    rewardHeader:SetFont(rewardHeader:GetFont(), E.HEADER_FONT_SIZE, "OUTLINE")
    E:StyleAccentHeader(rewardHeader, "Rewards")

    local rewardNoteFS = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    rewardNoteFS:SetPoint("TOPLEFT", rewardHeader, "BOTTOMLEFT", 0, -4)
    rewardNoteFS:SetFont(rewardNoteFS:GetFont(), 10)
    rewardNoteFS:SetText(
        E.CC.muted .. "Collectibles for defeating Nullaeus this season "
        .. "(hover an item for its tooltip):" .. E.CC.close
    )

    -- Item rewards carry a verified itemID so we can show the real game
    -- icon and a live item tooltip. Title rewards have no item and fall
    -- back to a coloured bullet + custom tooltip.
    local REWARDS = {
        { name = "Nullaeus Domaneye",            kind = "Cosmetic Helm", itemID = 263413, color = E.CC.purple,
          cond = "Defeat Nullaeus on any difficulty this season.", extra = "Also grants 30 Hero Dawncrests." },
        { name = "Dominating Victory",           kind = "Toy",           itemID = 264413, color = E.CC.green,
          cond = "Reward from the Nulling Nullaeus quest." },
        { name = "Arcanovoid Construct",         kind = "Mount",         itemID = 263222, color = E.CC.purple,
          cond = "Defeat Nullaeus solo (Let Me Solo Him: Nullaeus)." },
        { name = "The Ominous",                  kind = "Title",                          color = E.CC.gold,
          cond = "Defeat Nullaeus at Tier 11 (Lighting the Dark)." },
        { name = "Fabled Vanquisher of Nullaeus", kind = "Title",                         color = E.CC.yellow,
          cond = "Be among the first 4,000 in your region to solo him." },
    }

    local rewardAnchor = rewardNoteFS
    for i, r in ipairs(REWARDS) do
        local row = CreateFrame("Frame", nil, sc)
        row:SetHeight(30)
        row:SetPoint("TOPLEFT", rewardAnchor, "BOTTOMLEFT", (i == 1) and 8 or 0, -8)
        row:SetPoint("RIGHT", sc, "RIGHT", -20, 0)
        row:EnableMouse(true)

        -- Icon (item rewards) or coloured bullet (title rewards).
        if r.itemID then
            local icon = row:CreateTexture(nil, "ARTWORK")
            icon:SetSize(20, 20)
            icon:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
            icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            local tex = GetRewardIcon(r.itemID)
            if tex then icon:SetTexture(tex) end
        else
            local bullet = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            bullet:SetPoint("TOPLEFT", row, "TOPLEFT", 5, -2)
            bullet:SetFont(bullet:GetFont(), 12)
            bullet:SetText(r.color .. "\226\128\162" .. E.CC.close)
        end

        local nameFS = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        nameFS:SetPoint("TOPLEFT", row, "TOPLEFT", 26, -1)
        nameFS:SetFont(nameFS:GetFont(), 11)
        nameFS:SetText(
            r.color .. r.name .. E.CC.close
            .. E.CC.muted .. "  \226\128\162  " .. r.kind .. E.CC.close
        )

        local condFS = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        condFS:SetPoint("TOPLEFT", nameFS, "BOTTOMLEFT", 0, -2)
        condFS:SetPoint("RIGHT", row, "RIGHT", 0, 0)
        condFS:SetFont(condFS:GetFont(), 10)
        condFS:SetJustifyH("LEFT")
        condFS:SetText(E.CC.body .. r.cond .. E.CC.close)

        -- Hover: live item tooltip for items, custom tooltip for titles.
        row.itemID = r.itemID
        row.rName  = r.name
        row.rCond  = r.extra and (r.cond .. "  " .. r.extra) or r.cond
        row:SetScript("OnEnter", function(self)
            if self.itemID then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetItemByID(self.itemID)
                GameTooltip:Show()
            else
                E:ShowTooltip(self, self.rName, self.rCond)
            end
        end)
        row:SetScript("OnLeave", function()
            GameTooltip:Hide()
            E:HideTooltip()
        end)

        rewardAnchor = row
    end

    --------------------------------------------------------------------
    -- REFRESH FUNCTIONS
    --------------------------------------------------------------------
    local function RefreshNemesis()
        local completed, inProgress = false, false
        if C_QuestLog then
            if C_QuestLog.IsQuestFlaggedCompleted then
                completed = C_QuestLog.IsQuestFlaggedCompleted(NEMESIS_QUEST)
            end
            if (not completed) and C_QuestLog.IsOnQuest then
                inProgress = C_QuestLog.IsOnQuest(NEMESIS_QUEST)
            end
        end

        if completed then
            nemStatusFS:SetText(
                E.CC.green .. "[Done] Weekly Nemesis quest complete this week." .. E.CC.close
            )
        elseif inProgress then
            nemStatusFS:SetText(
                E.CC.yellow .. "In progress \226\128\148 check your quest log." .. E.CC.close
            )
        else
            nemStatusFS:SetText(
                E.CC.btnText .. "Quest available" .. E.CC.close
                .. E.CC.muted
                .. " \226\128\148 pick up at Delvers HQ in Silvermoon (if eligible)"
                .. E.CC.close
            )
        end
    end

    local function RefreshBeacon()
        local inBags = 0
        if C_Item and C_Item.GetItemCount then
            inBags = C_Item.GetItemCount(BEACON_ITEM_ID, true)
        end

        if inBags > 0 then
            beaconStatusFS:SetText(
                E.CC.green .. "[Ready] Beacon of Hope in inventory (" .. inBags .. ")"
                .. E.CC.close
                .. E.CC.muted .. " \226\128\148 go get that Nemesis!" .. E.CC.close
            )
        else
            beaconStatusFS:SetText(
                E.CC.btnText .. "No Beacon of Hope in bags or bank." .. E.CC.close
            )
        end

        local undercoins = 0
        if C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo then
            local info = C_CurrencyInfo.GetCurrencyInfo(UNDERCOIN_ID)
            if info then undercoins = info.quantity or 0 end
        end

        beaconBar:SetProgress(undercoins, BEACON_PRICE)

        if undercoins < BEACON_PRICE then
            beaconNoteFS:SetText(
                E.CC.btnText .. "Insufficient Undercoins. " .. E.CC.close
                .. E.CC.muted .. "(" .. E.CC.close
                .. E.CC.btnText .. undercoins .. E.CC.close
                .. E.CC.muted .. " of " .. E.CC.close
                .. E.CC.white .. BEACON_PRICE .. E.CC.close
                .. E.CC.muted .. ")" .. E.CC.close
            )
        else
            beaconNoteFS:SetText(
                E.CC.green .. "You have enough Undercoins to purchase a Beacon!"
                .. E.CC.close
                .. E.CC.muted .. " (" .. undercoins .. " / " .. BEACON_PRICE .. ")"
                .. E.CC.close
            )
        end
    end

    --------------------------------------------------------------------
    -- CONTENT HEIGHT
    --------------------------------------------------------------------
    local function UpdateContentHeight()
        local scTop   = sc:GetTop()
        local lastBot = rewardAnchor:GetBottom()
        if scTop and lastBot and scTop > lastBot then
            sc:SetHeight((scTop - lastBot) + 20)
        end
        UpdateScrollRange()
    end

    frame:SetScript("OnShow", function()
        RefreshNemesis()
        RefreshBeacon()
        C_Timer.After(0, UpdateContentHeight)
        UpdateScrollRange()
        scrollFrame:SetVerticalScroll(0)
        tabScrollBar:SetValue(0)
    end)

    E:RegisterCallback("QuestLogUpdate", function()
        if frame:IsShown() then RefreshNemesis() end
    end)

    E:RegisterCallback("BagUpdate", function()
        if frame:IsShown() then RefreshBeacon() end
    end)

    --------------------------------------------------------------------
    -- Register with the main frame tab system
    --------------------------------------------------------------------
    E:RegisterTab(4, frame)
end)
