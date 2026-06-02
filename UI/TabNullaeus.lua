------------------------------------------------------------------------
-- UI/TabNullaeus.lua - Tab 4: Nullaeus
-- The Nemesis Delve (Torment's Rise): overview & unlock tiers, weekly quest
-- tracker, Beacon of Hope inventory, full boss-mechanics and intermission
-- breakdown, companion/curio loadout, and reward list.
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

    -- Flat wrapped body line: anchors under `anchor` at the same left edge,
    -- stretches to the right margin, and returns itself as the next anchor.
    -- Used by the prose sections (Overview, Companion & Loadout) so they stay
    -- allocation-light and need no per-line pull-back math.
    local function AddBodyLine(anchor, gapY, size, text)
        local fs = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        fs:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, gapY)
        fs:SetPoint("RIGHT", sc, "RIGHT", -20, 0)
        fs:SetFont(fs:GetFont(), size)
        fs:SetJustifyH("LEFT")
        fs:SetText(text)
        return fs
    end

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
        .. "Weekly bounty: beat him to 50%  \226\128\148  Torment's Rise delve: full kill"
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
    -- OVERVIEW
    --------------------------------------------------------------------
    local overviewHeader = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    overviewHeader:SetPoint("TOPLEFT", div1, "BOTTOMLEFT", 0, -24)
    overviewHeader:SetFont(overviewHeader:GetFont(), E.HEADER_FONT_SIZE, "OUTLINE")
    E:StyleAccentHeader(overviewHeader, "Overview")

    local ovAnchor = overviewHeader
    ovAnchor = AddBodyLine(ovAnchor, -6, 10,
        E.CC.body .. "Nullaeus is the Midnight Season 1 Nemesis, and you can fight him "
        .. "two separate ways:" .. E.CC.close)
    ovAnchor = AddBodyLine(ovAnchor, -6, 10,
        E.CC.muted .. "\226\128\162  " .. E.CC.close
        .. E.CC.gold .. "Weekly bounty" .. E.CC.close
        .. E.CC.body .. "  summon him with a Beacon of Hope (or catch his random spawn) "
        .. "inside any delve and beat him to 50% HP, at which point he retreats and the "
        .. "bounty completes. See the Beacon of Hope section below." .. E.CC.close)
    ovAnchor = AddBodyLine(ovAnchor, -3, 10,
        E.CC.muted .. "\226\128\162  " .. E.CC.close
        .. E.CC.gold .. "Torment's Rise" .. E.CC.close
        .. E.CC.body .. "  the dedicated single-boss Nemesis delve in The Voidstorm, run "
        .. "at Tier 8 or Tier 11. Here you must kill Nullaeus outright \226\128\148 that is "
        .. "what awards the achievements, mount, and title. The mechanics and "
        .. "intermissions below cover this full fight." .. E.CC.close)
    ovAnchor = AddBodyLine(ovAnchor, -8, 10,
        E.CC.muted .. "\226\128\162  " .. E.CC.close
        .. E.CC.gold .. "Tier 8" .. E.CC.close
        .. E.CC.body .. "  unlocks after clearing any Tier 7 delve with at least one life "
        .. "remaining. Recommended item level around 255." .. E.CC.close)
    ovAnchor = AddBodyLine(ovAnchor, -3, 10,
        E.CC.muted .. "\226\128\162  " .. E.CC.close
        .. E.CC.gold .. "Tier 11" .. E.CC.close
        .. E.CC.body .. "  unlocks after clearing any Tier 10 delve with at least one life "
        .. "remaining. Recommended item level around 274." .. E.CC.close)
    ovAnchor = AddBodyLine(ovAnchor, -6, 10,
        E.CC.muted .. "The Torment's Rise entrance is a portal in the south-east of The "
        .. "Voidstorm, just north of Obscurion Citadel (use Pin or TomTom above). Your "
        .. "first kill there awards a bonus 30 Hero Dawncrests." .. E.CC.close)

    local divO = sc:CreateTexture(nil, "ARTWORK")
    divO:SetHeight(1)
    divO:SetPoint("TOPLEFT", ovAnchor, "BOTTOMLEFT", 0, -20)
    divO:SetPoint("RIGHT", sc, "RIGHT", -8, 0)
    E:StyleAccentDivider(divO)

    --------------------------------------------------------------------
    -- BEACON OF HOPE
    --------------------------------------------------------------------
    local BEACON_ITEM_ID = 253342
    local UNDERCOIN_ID   = 2803
    local BEACON_PRICE   = 5000

    local beaconHeader = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    beaconHeader:SetPoint("TOPLEFT", divO, "BOTTOMLEFT", 0, -24)
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
        .. "The weekly bounty: enter a T7+ delve, reach the first checkpoint, then use a "
        .. "Beacon of Hope to summon Nullaeus (he can also appear as a random delve spawn). "
        .. "Beat him to 50% HP and he retreats \226\128\148 the bounty is done. Killing him all "
        .. "the way down is only for the Torment's Rise delve." .. E.CC.close
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

    -- Active during every damage phase. Nullaeus loops these three casts on a
    -- ~20s timer, always in the same order, so the interrupt plan is fixed.
    local mechIntroFS = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    mechIntroFS:SetPoint("TOPLEFT", mechHeader, "BOTTOMLEFT", 0, -6)
    mechIntroFS:SetPoint("RIGHT", sc, "RIGHT", -20, 0)
    mechIntroFS:SetFont(mechIntroFS:GetFont(), 10)
    mechIntroFS:SetJustifyH("LEFT")
    mechIntroFS:SetText(
        E.CC.muted
        .. "Between intermissions Nullaeus loops three casts about every 20 seconds, "
        .. "always in order: " .. E.CC.close
        .. E.CC.gold .. "Devouring Essence" .. E.CC.close
        .. E.CC.muted .. " (dispel) -> " .. E.CC.close
        .. E.CC.gold .. "Emptiness of the Void" .. E.CC.close
        .. E.CC.muted .. " (interrupt) -> " .. E.CC.close
        .. E.CC.gold .. "Imploding Strike" .. E.CC.close
        .. E.CC.muted .. " (tank hit). Keep your kick free for Emptiness of the Void."
        .. E.CC.close
    )

    local mechTipFS = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    mechTipFS:SetPoint("TOPLEFT", mechIntroFS, "BOTTOMLEFT", 0, -4)
    mechTipFS:SetPoint("RIGHT", sc, "RIGHT", -20, 0)
    mechTipFS:SetFont(mechTipFS:GetFont(), 10)
    mechTipFS:SetJustifyH("LEFT")
    mechTipFS:SetText(
        E.CC.muted
        .. "Companion: as melee or tank, set Valeera to Healer and she dispels "
        .. "Devouring Essence (and the Ravager bleed); as a healer, set her to DPS "
        .. "so she interrupts Emptiness of the Void for you."
        .. E.CC.close
    )

    local MECHANICS = {
        {
            name     = "Emptiness of the Void",
            tag      = "Interrupt - Top Priority",
            tagColor = E.CC.red,
            desc     = "His signature cast, roughly every 20 seconds: a massive group-wide shadow blast that can outright kill you, and almost always one-shots at higher tiers. Interrupt it every single time. If your kick is down, use an immunity, a major damage reduction, or break line of sight. Solo kick-saver: Interrupt, Immunity, Interrupt, Defensive, Interrupt.",
        },
        {
            name     = "Devouring Essence",
            tag      = "Dispel",
            tagColor = E.CC.yellow,
            desc     = "A magic shadow damage-over-time on one player: moderate damage every 2 seconds for 18 seconds. Do not waste your interrupt on it; Emptiness of the Void follows immediately and must be kicked, so dispel the magic DoT instead (Valeera as Healer does this for you) or ride it out with a personal.",
        },
        {
            name     = "Imploding Strike",
            tag      = "Tank Hit",
            tagColor = "|cFFFF8800",
            desc     = "A moderate physical hit on whoever holds threat, about every 20 seconds. It is predictable on the timer, so pre-mitigate or rotate a defensive into it; solo players can also kite between casts.",
        },
    }

    local mechAnchor = mechTipFS
    for i, m in ipairs(MECHANICS) do
        local nameLine = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        -- i==1 anchors to the companion tip line (base indent); i>1 anchors to
        -- the previous description line (indented +12), so pull back -12 to keep
        -- every name line on the same left baseline.
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

    --------------------------------------------------------------------
    -- INTERMISSIONS
    --------------------------------------------------------------------
    local phaseHeader = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    phaseHeader:SetPoint("TOPLEFT", div3, "BOTTOMLEFT", 0, -24)
    phaseHeader:SetFont(phaseHeader:GetFont(), E.HEADER_FONT_SIZE, "OUTLINE")
    E:StyleAccentHeader(phaseHeader, "Intermissions")

    local phaseIntroFS = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    phaseIntroFS:SetPoint("TOPLEFT", phaseHeader, "BOTTOMLEFT", 0, -6)
    phaseIntroFS:SetPoint("RIGHT", sc, "RIGHT", -20, 0)
    phaseIntroFS:SetFont(phaseIntroFS:GetFont(), 10)
    phaseIntroFS:SetJustifyH("LEFT")
    phaseIntroFS:SetText(
        E.CC.muted
        .. "In the Torment's Rise delve, Nullaeus becomes immune and channels a Void Orb "
        .. "for about 30 seconds at 75%, 50%, and 25% health while adds spawn. Survive the "
        .. "channel and burn the adds quickly to resume damage. Each intermission's hazard "
        .. "lingers into the next phase. (In the weekly bounty he retreats at 50%, so you "
        .. "only ever see the first intermission.)"
        .. E.CC.close
    )

    -- Each HP threshold triggers a ~30s immune intermission: specific adds plus
    -- a signature hazard. `adds` render as indented bullets under each intro.
    local PHASES = {
        {
            pct   = "75%",
            name  = "Razorshell Ravagers",
            intro = "Two Razorshell Ravagers attack while a Void Orb seeds the floor with void zones.",
            adds  = {
                { n = "Spiny Leap", d = "The Ravager marks the furthest player with a circle, then leaps onto it for heavy nature damage. Step out of the circle." },
                { n = "Jagged Rip", d = "A short cast that applies a strong bleed to its closest target. Dispellable (Valeera as Healer removes it)." },
                { n = "Void Orb / Null Zones", d = "The orb spawns expanding void zones (Null Zones) that cover about a third of the room and rotate to fresh spots, never the same place twice in a row. Keep repositioning, and park Nullaeus near a zone edge so you always have a safe pocket. These zones linger into the next phase." },
            },
        },
        {
            pct   = "50%",
            name  = "Spitting Ticks",
            intro = "Seven Spitting Ticks swarm in and a Gravity Well appears (some guides call it the Black Hole).",
            adds  = {
                { n = "Poisonous Spit", d = "Each hit is only moderate, but seven ticks stack the poison fast and can combo you down. Burst them with AoE immediately." },
                { n = "Gravity Well", d = "A roaming orb that pulls you toward it, stronger the closer you get; reaching its center (the iris) deals heavy Shadow damage, and the pull drags you into void zones. Save a movement cooldown to break free." },
            },
        },
        {
            pct   = "25%",
            name  = "Enslaved Voidcaster + Umbral Rage",
            intro = "One durable Enslaved Voidcaster joins and Nullaeus gains Umbral Rage. The earlier void zones stay active and no new Void Orb spawns, so this intermission is mechanically the simplest, but the soft enrage turns it into a race.",
            adds  = {
                { n = "Shadow Bolt", d = "Interruptible single-target shadow damage from the Voidcaster." },
                { n = "Shadow Crash", d = "Interruptible cast that drops a circle under you; step out of it." },
                { n = "Curse of Hesitation", d = "A 5-minute curse that slows your movement by 30%. Remove it if you can (Valeera as Healer can decurse)." },
                { n = "Umbral Rage", d = "A buff on Nullaeus that stacks, raising his damage by 10% per stack; it is the encounter's soft enrage, so the longer the final stretch drags, the harder he hits." },
                { n = "Interrupt plan", d = "Kick the Voidcaster's first cast, then ignore it and save your interrupt for Nullaeus's Emptiness of the Void." },
            },
        },
    }

    local phaseAnchor = phaseIntroFS
    for i, ph in ipairs(PHASES) do
        -- Percentage + intermission name. i==1 anchors to the section intro
        -- (base indent); later rows anchor to the previous phase's last bullet
        -- (indented +12), so pull back -12 to realign the baseline.
        local pctLine = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        pctLine:SetPoint("TOPLEFT", phaseAnchor, "BOTTOMLEFT", (i == 1) and 0 or -12, (i == 1) and -10 or -16)
        pctLine:SetFont(pctLine:GetFont(), 11)
        pctLine:SetText(
            E.CC.red .. ph.pct .. " HP" .. E.CC.close
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

        -- Bullets sit at a constant +12: the first steps in +12 from the pct
        -- line (or +0 if it follows the intro, already at +12); the rest chain
        -- at +0. That keeps the next pctLine's -12 pull-back correct.
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

    -- Final push + high-tier caution, pulled back to the section baseline.
    local finalLine = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    finalLine:SetPoint("TOPLEFT", phaseAnchor, "BOTTOMLEFT", -12, -16)
    finalLine:SetPoint("RIGHT", sc, "RIGHT", -20, 0)
    finalLine:SetFont(finalLine:GetFont(), 10)
    finalLine:SetJustifyH("LEFT")
    finalLine:SetText(
        E.CC.gold .. "Final push" .. E.CC.close
        .. E.CC.muted .. "  \226\128\148  " .. E.CC.close
        .. E.CC.body .. "Below 25% there are no more intermissions, but Umbral Rage "
        .. "keeps stacking (+10% damage each). Pop everything (Bloodlust/Heroism/Drums, "
        .. "potions, every cooldown) and burn him before the stacks overwhelm you."
        .. E.CC.close
    )

    local tierLine = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    tierLine:SetPoint("TOPLEFT", finalLine, "BOTTOMLEFT", 0, -8)
    tierLine:SetPoint("RIGHT", sc, "RIGHT", -20, 0)
    tierLine:SetFont(tierLine:GetFont(), 10)
    tierLine:SetJustifyH("LEFT")
    tierLine:SetText(
        "|cFFFF8800" .. "Tier 11" .. E.CC.close
        .. E.CC.muted .. "  \226\128\148  " .. E.CC.close
        .. E.CC.body .. "Everything hits far harder and mistakes stop being recoverable: "
        .. "a missed Emptiness of the Void interrupt is almost always lethal, and the "
        .. "Gravity Well's pull is stronger. Aim for roughly item level 274." .. E.CC.close
    )

    phaseAnchor = tierLine

    local div4 = sc:CreateTexture(nil, "ARTWORK")
    div4:SetHeight(1)
    div4:SetPoint("TOPLEFT", phaseAnchor, "BOTTOMLEFT", 0, -20)
    div4:SetPoint("RIGHT", sc, "RIGHT", -8, 0)
    E:StyleAccentDivider(div4)

    --------------------------------------------------------------------
    -- COMPANION & LOADOUT
    --------------------------------------------------------------------
    local compHeader = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    compHeader:SetPoint("TOPLEFT", div4, "BOTTOMLEFT", 0, -24)
    compHeader:SetFont(compHeader:GetFont(), E.HEADER_FONT_SIZE, "OUTLINE")
    E:StyleAccentHeader(compHeader, "Companion & Loadout")

    local compAnchor = compHeader
    compAnchor = AddBodyLine(compAnchor, -6, 10,
        E.CC.muted .. "Set your delve companion Valeera's role to cover whichever key "
        .. "mechanic you cannot handle yourself:" .. E.CC.close)
    compAnchor = AddBodyLine(compAnchor, -6, 10,
        E.CC.muted .. "\226\128\162  " .. E.CC.close
        .. E.CC.gold .. "Melee / Tank" .. E.CC.close
        .. E.CC.body .. "  run Valeera as Healer \226\128\148 she dispels Devouring Essence "
        .. "and removes the Razorshell bleed, and you interrupt Emptiness of the Void."
        .. E.CC.close)
    compAnchor = AddBodyLine(compAnchor, -3, 10,
        E.CC.muted .. "\226\128\162  " .. E.CC.close
        .. E.CC.gold .. "Healer" .. E.CC.close
        .. E.CC.body .. "  run Valeera as DPS \226\128\148 she interrupts Emptiness of the "
        .. "Void, and you dispel Devouring Essence yourself." .. E.CC.close)
    compAnchor = AddBodyLine(compAnchor, -3, 10,
        E.CC.muted .. "\226\128\162  " .. E.CC.close
        .. E.CC.gold .. "Ranged DPS" .. E.CC.close
        .. E.CC.body .. "  depends on your kick uptime; if you cannot cover every "
        .. "Emptiness of the Void yourself, run Valeera as DPS." .. E.CC.close)
    compAnchor = AddBodyLine(compAnchor, -8, 10,
        E.CC.gold .. "Curios" .. E.CC.close
        .. E.CC.body .. "  Combat: Porcelain Blade Tip (crit) or Sanctum's Edict (an "
        .. "absorb shield that helps survive the one-shot). Utility: Time Lost Edict "
        .. "(movement, cooldown and cast-speed boost) or Overflowing Voidspire."
        .. E.CC.close)
    compAnchor = AddBodyLine(compAnchor, -6, 10,
        E.CC.gold .. "Consumables" .. E.CC.close
        .. E.CC.body .. "  carry health and DPS potions, and save Bloodlust/Heroism/Drums "
        .. "for the sub-25% Umbral Rage push. Boss-timer addons (DBM, BigWigs) help you "
        .. "pre-empt Emptiness of the Void." .. E.CC.close)

    local divC = sc:CreateTexture(nil, "ARTWORK")
    divC:SetHeight(1)
    divC:SetPoint("TOPLEFT", compAnchor, "BOTTOMLEFT", 0, -20)
    divC:SetPoint("RIGHT", sc, "RIGHT", -8, 0)
    E:StyleAccentDivider(divC)

    --------------------------------------------------------------------
    -- REWARDS
    --------------------------------------------------------------------
    local rewardHeader = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    rewardHeader:SetPoint("TOPLEFT", divC, "BOTTOMLEFT", 0, -24)
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
          cond = "Defeat Nullaeus on either tier this season (My Shady Nemesis).", extra = "Also grants 30 Hero Dawncrests." },
        { name = "Dominating Victory",           kind = "Toy",           itemID = 264413, color = E.CC.green,
          cond = "Reward from the Nulling Nullaeus quest." },
        { name = "Arcanovoid Construct",         kind = "Mount",         itemID = 263222, color = E.CC.purple,
          cond = "Solo Nullaeus at Tier 11 (Let Me Solo Him: Nullaeus)." },
        { name = "The Ominous",                  kind = "Title",                          color = E.CC.gold,
          cond = "Defeat Nullaeus at Tier 11 (Lighting the Dark)." },
        { name = "Fabled Vanquisher of Nullaeus", kind = "Title",                         color = E.CC.yellow,
          cond = "Be among the first 4,000 in your region to solo him at Tier 11." },
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
