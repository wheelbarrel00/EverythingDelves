local E = EverythingDelves
local L = E.L

local math_floor, math_max, math_min = math.floor, math.max, math.min

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

E:RegisterModule(function()
    local frame = CreateFrame("Frame", "EverythingDelvesTabNullaeusContent")

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
    sc:SetHeight(2600)

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

    local function AddBodyLine(anchor, gapY, size, text)
        local fs = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        fs:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, gapY)
        fs:SetPoint("RIGHT", sc, "RIGHT", -20, 0)
        fs:SetFont(fs:GetFont(), size)
        fs:SetJustifyH("LEFT")
        fs:SetText(text)
        return fs
    end

    local NEMESIS_MAP   = 2512
    local NEMESIS_X     = 51.22
    local NEMESIS_Y     = 30.27
    -- "Fangs for the Memories" quest id is not known until Season 2 opens.
    local NEMESIS_QUEST = nil
    local NEMESIS_ICON  = "Interface\\Icons\\Ability_Creature_Poison_06"
    local PORTRAIT_MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"

    local mainHeader = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    mainHeader:SetPoint("TOPLEFT", sc, "TOPLEFT", GRID_X, -4)
    mainHeader:SetFont(mainHeader:GetFont(), E.HEADER_FONT_SIZE, "OUTLINE")
    E:StyleAccentHeader(mainHeader, L["The Nemesis Delve"])

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
        E.CC.gold .. "Azta'rec" .. E.CC.close
        .. E.CC.muted .. "  \226\128\148  The Coiled Isle  \226\128\148  Venomfall Deeps"
        .. E.CC.close
    )

    local nemSubFS = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    nemSubFS:SetPoint("LEFT", nemIcon, "RIGHT", 8, -8)
    nemSubFS:SetFont(nemSubFS:GetFont(), 10)
    nemSubFS:SetText(
        E.CC.muted
        .. L["Season 2 Nemesis  \226\128\148  two difficulties, Tier \"?\" and Tier \"??\""]
        .. E.CC.close
    )

    local nemWpBtn = E:CreateButton(sc, 32, 20, L["Pin"])
    nemWpBtn.label:SetFont(nemWpBtn.label:GetFont(), 10)
    nemWpBtn:SetPoint("TOPLEFT", nemIcon, "TOPRIGHT", 380, -10)
    nemWpBtn:SetScript("OnClick", function()
        E:SetWaypoint(NEMESIS_MAP, NEMESIS_X, NEMESIS_Y)
        E:FlashButtonConfirm(nemWpBtn)
    end)
    nemWpBtn:SetScript("OnEnter", function(self)
        local hc = E.Colors.buttonHover
        self:SetBackdropColor(hc.r, hc.g, hc.b, hc.a)
        E:ShowTooltip(self, L["Set Waypoint"], L["Pin Venomfall Deeps on your map."])
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
        E:AddTomTomWaypoint(NEMESIS_MAP, NEMESIS_X, NEMESIS_Y, "Venomfall Deeps")
        E:FlashButtonConfirm(nemTTBtn)
    end)
    nemTTBtn:SetScript("OnEnter", function(self)
        local hc = E.Colors.buttonHover
        self:SetBackdropColor(hc.r, hc.g, hc.b, hc.a)
        if E:IsTomTomLoaded() then
            E:ShowTooltip(self, L["TomTom Waypoint"],
                          L["Add a TomTom arrow to Venomfall Deeps."])
        else
            E:ShowTooltip(self, L["TomTom Not Installed"],
                          L["Install the TomTom addon to use arrow waypoints."])
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

    local overviewHeader = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    overviewHeader:SetPoint("TOPLEFT", div1, "BOTTOMLEFT", 0, -24)
    overviewHeader:SetFont(overviewHeader:GetFont(), E.HEADER_FONT_SIZE, "OUTLINE")
    E:StyleAccentHeader(overviewHeader, L["Overview"])

    local ovAnchor = overviewHeader
    ovAnchor = AddBodyLine(ovAnchor, -6, 10,
        E.CC.yellow .. L["Venomfall Deeps is open, but his lair has to be unlocked first."]
        .. E.CC.close
        .. E.CC.body .. " "
        .. L["Clear a Tier 7 delve with at least one life left to unlock the lower difficulty, or a Tier 10 clear for the harder one. The clear does not have to be in Venomfall Deeps. Azta'rec can also be met the other way listed below."]
        .. E.CC.close)
    ovAnchor = AddBodyLine(ovAnchor, -6, 10,
        E.CC.body
        .. L["Azta'rec is the Midnight Season 2 Nemesis, and you can meet him two separate ways:"]
        .. E.CC.close)
    ovAnchor = AddBodyLine(ovAnchor, -6, 10,
        E.CC.muted .. "\226\128\162  " .. E.CC.close
        .. E.CC.gold .. L["Inside any delve"] .. E.CC.close
        .. E.CC.body .. "  "
        .. L["he can appear at random in any Tier 8 or higher delve, and can also be summoned on the spot with a Scalebound Herald's Flute."]
        .. E.CC.close)
    ovAnchor = AddBodyLine(ovAnchor, -3, 10,
        E.CC.muted .. "\226\128\162  " .. E.CC.close
        .. E.CC.gold .. "Venomfall Deeps" .. E.CC.close
        .. E.CC.body .. "  "
        .. L["the dedicated Nemesis delve on The Coiled Isle. This is the full fight \226\128\148 the mechanics and intermissions below cover it, and it is what awards the achievements, mount, and titles."]
        .. E.CC.close)
    ovAnchor = AddBodyLine(ovAnchor, -8, 10,
        E.CC.muted .. "\226\128\162  " .. E.CC.close
        .. "|cFFFF8800" .. L["Tier \"?\""] .. E.CC.close
        .. E.CC.body .. "  " .. L["the easier of the two. Recommended item level 290."]
        .. E.CC.close)
    ovAnchor = AddBodyLine(ovAnchor, -3, 10,
        E.CC.muted .. "\226\128\162  " .. E.CC.close
        .. E.CC.red .. L["Tier \"??\""] .. E.CC.close
        .. E.CC.body .. "  "
        .. L["everything hits far harder, and he summons an Echo of himself during every intermission. This is the one the title and the Fabled title require."]
        .. E.CC.close)
    ovAnchor = AddBodyLine(ovAnchor, -6, 10,
        E.CC.muted
        .. L["The entrance is on the north side of The Coiled Isle, inside one of the snake buildings (use Pin or TomTom above). Your first kill awards a bonus 30 Hero Mistcrests, which do not count toward the season maximum."]
        .. E.CC.close)
    ovAnchor = AddBodyLine(ovAnchor, -6, 10,
        E.CC.muted
        .. L["The encounter is deliberately punishing and expects deaths while you learn it, especially at lower item levels."]
        .. E.CC.close)

    local divO = sc:CreateTexture(nil, "ARTWORK")
    divO:SetHeight(1)
    divO:SetPoint("TOPLEFT", ovAnchor, "BOTTOMLEFT", 0, -20)
    divO:SetPoint("RIGHT", sc, "RIGHT", -8, 0)
    E:StyleAccentDivider(divO)

    local BEACON_ITEM_ID = 253342
    local UNDERCOIN_ID   = 2803
    local BEACON_PRICE   = 5000

    local beaconHeader = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    beaconHeader:SetPoint("TOPLEFT", divO, "BOTTOMLEFT", 0, -24)
    beaconHeader:SetFont(beaconHeader:GetFont(), E.HEADER_FONT_SIZE, "OUTLINE")
    E:StyleAccentHeader(beaconHeader, L["Beacon of Hope"])

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
        .. L["Use a Beacon of Hope inside a delve to call the Nemesis rather than waiting on his random spawn. Season 2 also introduces the Scalebound Herald's Flute, which summons Azta'rec inside the delve \226\128\148 its cost and vendor are not tracked here yet. The Undercoin bar tracks the Beacon, not the Flute."]
        .. E.CC.close
    )

    local div2 = sc:CreateTexture(nil, "ARTWORK")
    div2:SetHeight(1)
    div2:SetPoint("TOPLEFT", beaconHintFS, "BOTTOMLEFT", 0, -20)
    div2:SetPoint("RIGHT", sc, "RIGHT", -8, 0)
    E:StyleAccentDivider(div2)

    local mechHeader = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    mechHeader:SetPoint("TOPLEFT", div2, "BOTTOMLEFT", 0, -24)
    mechHeader:SetFont(mechHeader:GetFont(), E.HEADER_FONT_SIZE, "OUTLINE")
    E:StyleAccentHeader(mechHeader, L["Boss Mechanics"])

    local mechIntroFS = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    mechIntroFS:SetPoint("TOPLEFT", mechHeader, "BOTTOMLEFT", 0, -6)
    mechIntroFS:SetPoint("RIGHT", sc, "RIGHT", -20, 0)
    mechIntroFS:SetFont(mechIntroFS:GetFont(), 10)
    mechIntroFS:SetJustifyH("LEFT")
    mechIntroFS:SetText(
        E.CC.muted
        .. L["The fight splits into a main phase and an intermission at 90%, 60% and 30% health. Two casts decide whether you live:"]
        .. " " .. E.CC.close
        .. E.CC.muted .. L["%s (interrupt) and %s (dispel). Pull him to the edge of the room so the Noxious Bile puddles land away from the middle."]
            :format(E.CC.gold .. "Soul Extinction" .. E.CC.close .. E.CC.muted,
                    E.CC.gold .. "Void Toxin" .. E.CC.close .. E.CC.muted)
        .. E.CC.close
    )

    local mechTipFS = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    mechTipFS:SetPoint("TOPLEFT", mechIntroFS, "BOTTOMLEFT", 0, -4)
    mechTipFS:SetPoint("RIGHT", sc, "RIGHT", -20, 0)
    mechTipFS:SetFont(mechTipFS:GetFont(), 10)
    mechTipFS:SetJustifyH("LEFT")
    mechTipFS:SetText(
        E.CC.muted
        .. L["Companion: as DPS or tank, set Valeera to Healer and she dispels Void Toxin while you cover the interrupt; as a healer, set her to DPS so she interrupts Soul Extinction and you dispel instead."]
        .. E.CC.close
    )

    local MECHANICS = {
        {
            name     = "Soul Extinction",
            tag      = L["Interrupt - Top Priority"],
            tagColor = E.CC.red,
            desc     = L["An interruptible cast that deals lethal damage if it completes. Kick it every single time. Valeera interrupts it for you when her role is set to DPS, which is the reason a healer should run her that way."],
        },
        {
            name     = "Void Toxin",
            tag      = L["Dispel"],
            tagColor = E.CC.yellow,
            desc     = L["A dispellable magic debuff that ticks for heavy damage and cuts the damage you deal by 40%. Remove it as soon as it lands. Valeera dispels it for you when her role is set to Healer."],
        },
        {
            name     = "Noxious Bile",
            tag      = L["Frontal"],
            tagColor = "|cFFFF8800",
            desc     = L["A frontal cone that hits hard if you stay in it, and it leaves venom puddles behind on the floor. Aim it toward the outside of the room and step out once he has aimed it, so the middle of the arena stays clean for the intermission."],
        },
        {
            name     = "Venom Storm",
            tag      = L["Keep Moving"],
            tagColor = "|cFFFF8800",
            desc     = L["Summons venom waves that crawl slowly across the arena and deal heavy damage to anyone they catch. They are slow enough to walk away from, so keep moving rather than reacting late."],
        },
        {
            name     = "Serpent's Strike",
            tag      = L["Tank Hit"],
            tagColor = E.CC.muted,
            desc     = L["Only used while you are in a tank specialization, and only a small amount of physical damage. Nothing to plan around."],
        },
    }

    local mechAnchor = mechTipFS
    for i, m in ipairs(MECHANICS) do
        local nameLine = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        nameLine:SetPoint("TOPLEFT", mechAnchor, "BOTTOMLEFT", (i == 1) and 0 or -12, (i == 1) and -10 or -14)
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

    local phaseHeader = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    phaseHeader:SetPoint("TOPLEFT", div3, "BOTTOMLEFT", 0, -24)
    phaseHeader:SetFont(phaseHeader:GetFont(), E.HEADER_FONT_SIZE, "OUTLINE")
    E:StyleAccentHeader(phaseHeader, L["Intermissions"])

    local phaseIntroFS = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    phaseIntroFS:SetPoint("TOPLEFT", phaseHeader, "BOTTOMLEFT", 0, -6)
    phaseIntroFS:SetPoint("RIGHT", sc, "RIGHT", -20, 0)
    phaseIntroFS:SetFont(phaseIntroFS:GetFont(), 10)
    phaseIntroFS:SetJustifyH("LEFT")
    phaseIntroFS:SetText(
        E.CC.muted
        .. L["At 90%, 60% and 30% health Azta'rec walks to the centre and channels Sermon of Ula'tek, taking 99% reduced damage for the whole intermission. The room splits into quarters: three flood with venom and one is safe. It is a memory test, not a damage test \226\128\148 place four world markers on the quadrants before you pull and call the safe spot by marker."]
        .. E.CC.close
    )

    local PHASES = {
        {
            pct   = L["90 / 60 / 30% HP"],
            name  = "Sermon of Ula'tek",
            intro = L["The same intermission runs at all three health thresholds, one step longer each time."],
            adds  = {
                { n = L["Shown pattern"], d = L["He marks one safe quarter and covers the other three, with an animation showing which is which. You get a few seconds to run to the safe quarter. Stand close to him so every quarter is within reach."] },
                { n = L["Repeated pattern"], d = L["He then replays the same sequence with no animation at all. You have to remember the order the safe zones came in - this is what kills people, not the damage."] },
                { n = L["Length"], d = L["On Tier \"?\" the sequence runs 3 times, then 4, then 5 across the three intermissions. On Tier \"??\" it runs 5, then 6, then 7."] },
                { n = L["Lingering venom"], d = L["Keep the middle of the room clear of Noxious Bile puddles during the main phase, or you will be dodging your own leftovers while running the pattern."] },
            },
        },
        {
            pct   = L["Tier \"??\" only"],
            name  = "Echo of Azta'rec",
            intro = L["On the harder difficulty he also summons an Echo of himself during the intermission."],
            adds  = {
                { n = "Echo of Azta'rec", d = L["It does not have much health, but it uses every ability from his main phase - including Soul Extinction, which will one-shot you if it lands. Crowd control it and kill it fast; leaving it up makes the whole intermission far harder."] },
                { n = L["Cover the Echo's casts"], d = L["If Valeera is set to Healer, you must interrupt the Echo yourself. If she is set to DPS she covers the interrupt, but then you have to dispel Void Toxin."] },
                { n = L["Extra venom sets"], d = L["Two additional venom coverings are added, so the pattern you must memorise reaches five safe zones."] },
            },
        },
    }

    local phaseAnchor = phaseIntroFS
    for i, ph in ipairs(PHASES) do
        local pctLine = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        pctLine:SetPoint("TOPLEFT", phaseAnchor, "BOTTOMLEFT", (i == 1) and 0 or -12, (i == 1) and -10 or -16)
        pctLine:SetFont(pctLine:GetFont(), 11)
        pctLine:SetText(
            E.CC.red .. ph.pct .. E.CC.close
            .. E.CC.muted .. "  \226\128\148  " .. E.CC.close
            .. E.CC.gold .. ph.name .. E.CC.close
        )

        local rowAnchor = pctLine
        if ph.intro then
            local introLine = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            introLine:SetPoint("TOPLEFT", rowAnchor, "BOTTOMLEFT", 12, -2)
            introLine:SetPoint("RIGHT", sc, "RIGHT", -20, 0)
            introLine:SetFont(introLine:GetFont(), 10)
            introLine:SetJustifyH("LEFT")
            introLine:SetText(E.CC.body .. ph.intro .. E.CC.close)
            rowAnchor = introLine
        end

        for _, a in ipairs(ph.adds or {}) do
            local addLine = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            addLine:SetPoint("TOPLEFT", rowAnchor, "BOTTOMLEFT", (rowAnchor == pctLine) and 12 or 0, -3)
            addLine:SetPoint("RIGHT", sc, "RIGHT", -20, 0)
            addLine:SetFont(addLine:GetFont(), 10)
            addLine:SetJustifyH("LEFT")
            addLine:SetText(
                E.CC.muted .. "\226\128\162  " .. E.CC.close
                .. E.CC.gold .. a.n .. E.CC.close
                .. E.CC.muted .. "  \226\128\148  " .. E.CC.close
                .. E.CC.body .. a.d .. E.CC.close
            )
            rowAnchor = addLine
        end

        phaseAnchor = rowAnchor
    end

    local finalLine = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    finalLine:SetPoint("TOPLEFT", phaseAnchor, "BOTTOMLEFT", -12, -16)
    finalLine:SetPoint("RIGHT", sc, "RIGHT", -20, 0)
    finalLine:SetFont(finalLine:GetFont(), 10)
    finalLine:SetJustifyH("LEFT")
    finalLine:SetText(
        E.CC.gold .. L["Final push"] .. E.CC.close
        .. E.CC.muted .. "  \226\128\148  " .. E.CC.close
        .. E.CC.body
        .. L["After the 30% intermission there are no more, and the main phase runs until he dies. Save Bloodlust or Heroism for after the last intermission on Tier \"?\", or during the last intermission on Tier \"??\" to kill the Echo faster."]
        .. E.CC.close
    )

    local tierLine = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    tierLine:SetPoint("TOPLEFT", finalLine, "BOTTOMLEFT", 0, -8)
    tierLine:SetPoint("RIGHT", sc, "RIGHT", -20, 0)
    tierLine:SetFont(tierLine:GetFont(), 10)
    tierLine:SetJustifyH("LEFT")
    tierLine:SetText(
        "|cFFFF8800" .. L["Before you pull"] .. E.CC.close
        .. E.CC.muted .. "  \226\128\148  " .. E.CC.close
        .. E.CC.body
        .. L["Drop a world marker on each of the four quadrants, then call the safe zones by marker during the Sermon. Remembering \"blue, yellow, purple\" is far easier than remembering positions on a venom-covered floor."]
        .. E.CC.close
    )

    phaseAnchor = tierLine

    local div4 = sc:CreateTexture(nil, "ARTWORK")
    div4:SetHeight(1)
    div4:SetPoint("TOPLEFT", phaseAnchor, "BOTTOMLEFT", 0, -20)
    div4:SetPoint("RIGHT", sc, "RIGHT", -8, 0)
    E:StyleAccentDivider(div4)

    local compHeader = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    compHeader:SetPoint("TOPLEFT", div4, "BOTTOMLEFT", 0, -24)
    compHeader:SetFont(compHeader:GetFont(), E.HEADER_FONT_SIZE, "OUTLINE")
    E:StyleAccentHeader(compHeader, L["Companion & Loadout"])

    local compAnchor = compHeader
    compAnchor = AddBodyLine(compAnchor, -6, 10,
        E.CC.muted
        .. L["Only two mechanics need covering, and Valeera can take exactly one of them. Give her whichever you cannot cover yourself:"]
        .. E.CC.close)
    compAnchor = AddBodyLine(compAnchor, -6, 10,
        E.CC.muted .. "\226\128\162  " .. E.CC.close
        .. E.CC.gold .. L["DPS / Tank"] .. E.CC.close
        .. E.CC.body .. "  "
        .. L["run Valeera as Healer \226\128\148 she dispels Void Toxin, and you interrupt Soul Extinction yourself."]
        .. E.CC.close)
    compAnchor = AddBodyLine(compAnchor, -3, 10,
        E.CC.muted .. "\226\128\162  " .. E.CC.close
        .. E.CC.gold .. L["Healer"] .. E.CC.close
        .. E.CC.body .. "  "
        .. L["run Valeera as DPS \226\128\148 she interrupts Soul Extinction, and you dispel Void Toxin yourself."]
        .. E.CC.close)
    compAnchor = AddBodyLine(compAnchor, -8, 10,
        E.CC.gold .. L["Curios"] .. E.CC.close
        .. E.CC.body .. "  "
        .. L["Valeera has a third slot this season: Combat, Utility and a new Poisons slot. The picks do not change with your own role."]
        .. E.CC.close)
    compAnchor = AddBodyLine(compAnchor, -6, 10,
        E.CC.muted .. "\226\128\162  " .. E.CC.close
        .. E.CC.gold .. L["Poison"] .. E.CC.close
        .. E.CC.body .. "  "
        .. L["Frosthearth Venom \226\128\148 cuts enemy attack and cast speed by 20%, which buys time on both Soul Extinction and the Void Toxin dispel."]
        .. E.CC.close)
    compAnchor = AddBodyLine(compAnchor, -3, 10,
        E.CC.muted .. "\226\128\162  " .. E.CC.close
        .. E.CC.gold .. L["Combat"] .. E.CC.close
        .. E.CC.body .. "  "
        .. L["Corrosive Bilespear for straight damage. Ouroboric Curse is the alternative, but much of this delve one-shots, so its effect is hard to keep procced."]
        .. E.CC.close)
    compAnchor = AddBodyLine(compAnchor, -3, 10,
        E.CC.muted .. "\226\128\162  " .. E.CC.close
        .. E.CC.gold .. L["Utility"] .. E.CC.close
        .. E.CC.body .. "  "
        .. L["Soul-Cracking Dreamcatcher \226\128\148 because you interrupt so often it is close to permanent uptime, and the debuff sits on the boss, so Valeera's own interrupts keep it up even while you play healer. 30% damage at Rank 3 or higher."]
        .. E.CC.close)
    compAnchor = AddBodyLine(compAnchor, -6, 10,
        E.CC.gold .. L["Consumables"] .. E.CC.close
        .. E.CC.body .. "  "
        .. L["carry health and DPS potions, and hold Bloodlust or Heroism for after the final intermission on Tier \"?\", or for killing the Echo during the final intermission on Tier \"??\"."]
        .. E.CC.close)

    local divC = sc:CreateTexture(nil, "ARTWORK")
    divC:SetHeight(1)
    divC:SetPoint("TOPLEFT", compAnchor, "BOTTOMLEFT", 0, -20)
    divC:SetPoint("RIGHT", sc, "RIGHT", -8, 0)
    E:StyleAccentDivider(divC)

    local rewardHeader = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    rewardHeader:SetPoint("TOPLEFT", divC, "BOTTOMLEFT", 0, -24)
    rewardHeader:SetFont(rewardHeader:GetFont(), E.HEADER_FONT_SIZE, "OUTLINE")
    E:StyleAccentHeader(rewardHeader, L["Rewards"])

    local rewardNoteFS = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    rewardNoteFS:SetPoint("TOPLEFT", rewardHeader, "BOTTOMLEFT", 0, -4)
    rewardNoteFS:SetFont(rewardNoteFS:GetFont(), 10)
    rewardNoteFS:SetText(
        E.CC.muted
        .. L["Collectibles for defeating Azta'rec this season (item icons appear once their IDs are confirmed):"]
        .. E.CC.close
    )

    local REWARDS = {
        { name = "Apophic Patagia",              kind = L["Cloak Transmog"], color = E.CC.purple,
          cond = L["Defeat Azta'rec on either difficulty during Season 2 (My Venomous Nemesis, a Feat of Strength)."],
          extra = L["Your first kill also grants 30 Hero Mistcrests, which do not count toward the season maximum."] },
        { name = "Corrosive Victory",            kind = L["Toy"],            color = E.CC.green,
          cond = L["Reward from the Fangs for the Memories quest."] },
        { name = "Apophic Soul Crusher",         kind = L["Mount"],          color = E.CC.purple,
          cond = L["Solo Azta'rec (Let Me Solo Him: Azta'rec)."] },
        { name = "the Poisonous",                kind = L["Title"],          color = E.CC.gold,
          cond = L["Defeat Azta'rec on Tier \"??\" (Purging the Poison)."] },
        { name = "Fabled Vanquisher of Azta'rec", kind = L["Title"],         color = E.CC.yellow,
          cond = L["Defeat him in his lair on Tier \"??\" with no other players in your party, within the first week of Season 2 (Fabled Let Me Solo Him: Azta'rec)."] },
    }

    local rewardAnchor = rewardNoteFS
    for i, r in ipairs(REWARDS) do
        local row = CreateFrame("Frame", nil, sc)
        row:SetHeight(30)
        row:SetPoint("TOPLEFT", rewardAnchor, "BOTTOMLEFT", (i == 1) and 8 or 0, -8)
        row:SetPoint("RIGHT", sc, "RIGHT", -20, 0)
        row:EnableMouse(true)

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

    local function RefreshNemesis()
        if not NEMESIS_QUEST then
            nemStatusFS:SetText(
                E.CC.muted
                .. L["Fangs for the Memories \226\128\148 the one-time seasonal quest that awards the Corrosive Victory toy. Live tracking starts once its quest ID is confirmed."]
                .. E.CC.close
            )
            return
        end

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
                E.CC.green
                .. L["[Done] Fangs for the Memories complete \226\128\148 Corrosive Victory earned."]
                .. E.CC.close
            )
        elseif inProgress then
            nemStatusFS:SetText(
                E.CC.yellow
                .. L["Fangs for the Memories in progress \226\128\148 check your quest log."]
                .. E.CC.close
            )
        else
            nemStatusFS:SetText(
                E.CC.btnText .. L["Fangs for the Memories available"] .. E.CC.close
                .. E.CC.muted .. " \226\128\148 "
                .. L["the one-time seasonal quest; defeat Azta'rec to earn it."]
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
                E.CC.green
                .. L["[Ready] Beacon of Hope in inventory (%d)"]:format(inBags)
                .. E.CC.close
                .. E.CC.muted .. " \226\128\148 " .. L["go get that Nemesis!"] .. E.CC.close
            )
        else
            beaconStatusFS:SetText(
                E.CC.btnText .. L["No Beacon of Hope in bags or bank."] .. E.CC.close
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
                E.CC.btnText .. L["Insufficient Undercoins."] .. " " .. E.CC.close
                .. E.CC.muted .. "(" .. E.CC.close
                .. E.CC.btnText .. undercoins .. E.CC.close
                .. E.CC.muted .. " of " .. E.CC.close
                .. E.CC.white .. BEACON_PRICE .. E.CC.close
                .. E.CC.muted .. ")" .. E.CC.close
            )
        else
            beaconNoteFS:SetText(
                E.CC.green .. L["You have enough Undercoins to purchase a Beacon!"]
                .. E.CC.close
                .. E.CC.muted .. " (" .. undercoins .. " / " .. BEACON_PRICE .. ")"
                .. E.CC.close
            )
        end
    end

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
        if frame:IsVisible() then RefreshNemesis() end
    end)

    E:RegisterCallback("BagUpdate", function()
        if frame:IsVisible() then RefreshBeacon() end
    end)

    E:RegisterTab(4, frame)
end)
