------------------------------------------------------------------------
-- UI/TabTierGuide.lua — Tab 3: Tier Guide
-- Tier iLvl reference table, player recommendation, Seasonal Nemesis,
-- Trovehunter's Bounty, and Beacon of Hope sections.
--
-- Display-only: reads GetAverageItemLevel(), currency data, and quest
-- completion status. No gameplay automation.
------------------------------------------------------------------------
local E = EverythingDelves

------------------------------------------------------------------------
-- Local references for frequently accessed globals
------------------------------------------------------------------------
local math_floor, math_max, math_min = math.floor, math.max, math.min
local table_insert = table.insert

------------------------------------------------------------------------
-- Local helpers
------------------------------------------------------------------------

--- GetAverageItemLevel() returns two values: overall and equipped.
--- We use equipped iLvl for the recommendation since that's what
--- matters inside a delve.
local function GetPlayerIlvl()
    local equipped, overall = GetAverageItemLevel()
    local ilvl = math_floor(equipped or overall or 0)
    return ilvl
end

--- Determine the best tier for the player based on equipped iLvl.
--- Returns the highest tier whose recGear requirement the player meets.
local function GetRecommendedTier(ilvl)
    local best = 1
    for _, t in ipairs(E.TierData) do
        if ilvl >= t.recGear then
            best = t.tier
        end
    end
    return best
end


------------------------------------------------------------------------
-- MODULE INIT
------------------------------------------------------------------------
E:RegisterModule(function()
    local frame = CreateFrame("Frame", "EverythingDelvesTab3Content")

    --------------------------------------------------------------------
    -- TIER TABLE (top section)
    --
    -- Grid layout: row 0 = tier number headers,
    --              row 1 = Recommended Gear iLvl,
    --              row 2 = Bountiful Loot iLvl,
    --              row 3 = Great Vault iLvl
    --------------------------------------------------------------------
    local GRID_X       = 8
    local GRID_Y       = -6
    local COL_WIDTH    = 44
    local ROW_HEIGHT   = 20
    local LABEL_WIDTH  = 110  -- width of the left-side row labels

    -- Row labels
    local rowLabels = {
        { text = "Tier",           cc = E.CC.header },
        { text = "Rec. Gear iLvl", cc = E.CC.muted  },
        { text = "Bountiful Loot", cc = E.CC.gold   },
        { text = "Great Vault",    cc = E.CC.purple  },
    }

    for rowIdx, info in ipairs(rowLabels) do
        local fs = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        fs:SetPoint("TOPLEFT", frame, "TOPLEFT",
                    GRID_X, GRID_Y - ((rowIdx - 1) * ROW_HEIGHT))
        fs:SetFont(fs:GetFont(), 10, "OUTLINE")
        fs:SetText(info.cc .. info.text .. E.CC.close)
    end

    -- Column data cells — one per tier (1-11)
    local tierCells = {}  -- [tier] = { tierFS, gearFS, bountFS, vaultFS, bgTexture }

    for _, td in ipairs(E.TierData) do
        local colX = GRID_X + LABEL_WIDTH + ((td.tier - 1) * COL_WIDTH)
        local cell = {}

        -- Background highlight texture (hidden by default, shown for recommended tier)
        local bg = frame:CreateTexture(nil, "BACKGROUND")
        bg:SetPoint("TOPLEFT", frame, "TOPLEFT", colX - 2, GRID_Y + 2)
        bg:SetSize(COL_WIDTH, ROW_HEIGHT * 4)
        bg:SetColorTexture(0.55, 0, 0, 0.20)
        bg:Hide()
        cell.bg = bg

        -- Row 0: Tier number
        local tierFS = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        tierFS:SetPoint("TOPLEFT", frame, "TOPLEFT", colX, GRID_Y)
        tierFS:SetFont(tierFS:GetFont(), 10, "OUTLINE")
        local tc = E:GetTierCC(td.tier)
        tierFS:SetText(tc .. "T" .. td.tier .. E.CC.close)
        cell.tierFS = tierFS

        -- Row 1: Rec Gear
        local gearFS = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        gearFS:SetPoint("TOPLEFT", frame, "TOPLEFT", colX, GRID_Y - ROW_HEIGHT)
        gearFS:SetFont(gearFS:GetFont(), 10)
        gearFS:SetText(E.CC.body .. td.recGear .. E.CC.close)
        cell.gearFS = gearFS

        -- Row 2: Bountiful Loot
        local bountFS = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        bountFS:SetPoint("TOPLEFT", frame, "TOPLEFT", colX, GRID_Y - ROW_HEIGHT * 2)
        bountFS:SetFont(bountFS:GetFont(), 10)
        bountFS:SetText(E.CC.gold .. td.bountifulLoot .. E.CC.close)
        cell.bountFS = bountFS

        -- Row 3: Great Vault
        local vaultFS = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        vaultFS:SetPoint("TOPLEFT", frame, "TOPLEFT", colX, GRID_Y - ROW_HEIGHT * 3)
        vaultFS:SetFont(vaultFS:GetFont(), 10)
        vaultFS:SetText(E.CC.purple .. td.greatVault .. E.CC.close)
        cell.vaultFS = vaultFS

        -- Tooltip on the tier number
        local hitBox = CreateFrame("Frame", nil, frame)
        hitBox:SetPoint("TOPLEFT", frame, "TOPLEFT", colX - 2, GRID_Y + 2)
        hitBox:SetSize(COL_WIDTH, ROW_HEIGHT)
        hitBox:EnableMouse(true)
        hitBox:SetScript("OnEnter", function(self)
            local tipLines = {}
            if td.tier <= 4 then
                table_insert(tipLines, "Entry-level delves. Good for gearing up alts.")
            elseif td.tier <= 8 then
                table_insert(tipLines, "Mid-tier delves. Solid upgrades for mains early in the season.")
            else
                table_insert(tipLines, "Endgame delves. Best loot, toughest challenge.")
            end
            table_insert(tipLines, "")
            table_insert(tipLines, E.CC.muted .. "Recommended iLvl: " .. E.CC.close
                .. E.CC.gold .. td.recGear .. "+" .. E.CC.close)
            E:ShowTooltip(self, "Tier " .. td.tier, unpack(tipLines))
        end)
        hitBox:SetScript("OnLeave", function() E:HideTooltip() end)

        tierCells[td.tier] = cell
    end

    --------------------------------------------------------------------
    -- RECOMMENDATION BOX
    --------------------------------------------------------------------
    local REC_Y = GRID_Y - (ROW_HEIGHT * 4) - 14

    local recBox = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    recBox:SetHeight(44)
    recBox:SetPoint("TOPLEFT", frame, "TOPLEFT", GRID_X, REC_Y)
    recBox:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -8, REC_Y)
    recBox:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    recBox:SetBackdropColor(0.08, 0.08, 0.08, 0.90)
    recBox:SetBackdropBorderColor(0.55, 0, 0, 0.60)

    local ilvlLabel = recBox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    ilvlLabel:SetPoint("TOPLEFT", recBox, "TOPLEFT", 8, -6)
    ilvlLabel:SetFont(ilvlLabel:GetFont(), 11)

    local recLabel = recBox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    recLabel:SetPoint("TOPLEFT", ilvlLabel, "BOTTOMLEFT", 0, -3)
    recLabel:SetFont(recLabel:GetFont(), 11)

    --- Refresh the recommendation text and highlight the correct tier column.
    local function RefreshRecommendation()
        local ilvl = GetPlayerIlvl()
        local recTier = GetRecommendedTier(ilvl)

        ilvlLabel:SetText(
            E.CC.muted .. "Your Equipped iLvl: " .. E.CC.close
            .. E.CC.gold .. ilvl .. E.CC.close
        )
        recLabel:SetText(
            E.CC.muted .. "Recommended Tier: " .. E.CC.close
            .. E:GetTierCC(recTier) .. "T" .. recTier .. E.CC.close
            .. E.CC.body .. " — running this tier gives you the best gear upgrade chance" .. E.CC.close
        )

        -- Highlight only the recommended tier column
        for tier, cell in pairs(tierCells) do
            if tier == recTier then
                cell.bg:Show()
            else
                cell.bg:Hide()
            end
        end
    end

    --------------------------------------------------------------------
    -- Thin red divider
    --------------------------------------------------------------------
    local div1 = frame:CreateTexture(nil, "ARTWORK")
    div1:SetHeight(1)
    div1:SetPoint("TOPLEFT", recBox, "BOTTOMLEFT", 0, -8)
    div1:SetPoint("TOPRIGHT", recBox, "BOTTOMRIGHT", 0, -8)
    local dc = E.Colors.divider
    div1:SetColorTexture(dc.r, dc.g, dc.b, dc.a)
    --------------------------------------------------------------------
    -- SCROLLABLE AREA
    --------------------------------------------------------------------
    local scrollFrame = CreateFrame("ScrollFrame", nil, frame)
    scrollFrame:SetPoint("TOPLEFT", div1, "BOTTOMLEFT", -4, -2)
    scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -18, 4)
    scrollFrame:EnableMouseWheel(true)

    local sc = CreateFrame("Frame")
    sc:SetSize(1, 1)
    scrollFrame:SetScrollChild(sc)

    scrollFrame:SetScript("OnSizeChanged", function(self, w)
        sc:SetWidth(w)
    end)
    sc:SetHeight(550)

    -- Themed scrollbar: dark track, red thumb
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
    sbThumb:SetColorTexture(0.55, 0, 0, 0.80)
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


    --------------------------------------------------------------------
    -- GREAT VAULT PROGRESS
    -- Shows Delves / Dungeons / Raids progress toward weekly vault
    --------------------------------------------------------------------
    local gvHeader = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    gvHeader:SetPoint("TOPLEFT", sc, "TOPLEFT", GRID_X, -4)
    gvHeader:SetFont(gvHeader:GetFont(), 12, "OUTLINE")
    gvHeader:SetText(E.CC.header .. "Great Vault Progress" .. E.CC.close)

    local gvFallbackFS = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    gvFallbackFS:SetPoint("TOPLEFT", gvHeader, "BOTTOMLEFT", 0, -4)
    gvFallbackFS:SetFont(gvFallbackFS:GetFont(), 10)
    gvFallbackFS:Hide()

    -- Activity type → display config
    -- Enum.WeeklyRewardChestThresholdType: World = 1, Activities = 2, RankedPvP = 3
    local GV_ROWS = {
        { type = Enum.WeeklyRewardChestThresholdType.Activities, label = "Delves / Dungeons", max = 8 },
        { type = Enum.WeeklyRewardChestThresholdType.World,      label = "World Content",     max = 3 },
        { type = Enum.WeeklyRewardChestThresholdType.RankedPvP,  label = "PvP",               max = 3 },
    }

    local gvBars = {}
    local gvLastAnchor = gvHeader
    for i, cfg in ipairs(GV_ROWS) do
        local rowLabel = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        rowLabel:SetPoint("TOPLEFT", gvLastAnchor, "BOTTOMLEFT", 0, (i == 1) and -6 or -4)
        rowLabel:SetFont(rowLabel:GetFont(), 10)
        rowLabel:SetText(E.CC.muted .. cfg.label .. ":" .. E.CC.close)

        local bar = E:CreateProgressBar(sc, 0, 12)
        bar:SetPoint("TOPLEFT", rowLabel, "BOTTOMLEFT", 0, -2)
        bar:SetPoint("RIGHT", sc, "RIGHT", -20, 0)

        gvBars[cfg.type] = bar
        gvLastAnchor = bar
    end

    local gvNoteFS = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    gvNoteFS:SetPoint("TOPLEFT", gvLastAnchor, "BOTTOMLEFT", 0, -4)
    gvNoteFS:SetFont(gvNoteFS:GetFont(), 9)
    gvNoteFS:SetText(E.CC.muted .. "Complete activities to unlock Great Vault reward slots on Tuesday" .. E.CC.close)

    -- Divider after Great Vault
    local gvDiv = sc:CreateTexture(nil, "ARTWORK")
    gvDiv:SetHeight(1)
    gvDiv:SetPoint("TOPLEFT", gvNoteFS, "BOTTOMLEFT", 0, -6)
    gvDiv:SetPoint("RIGHT", sc, "RIGHT", -8, 0)
    gvDiv:SetColorTexture(dc.r, dc.g, dc.b, dc.a)

    --------------------------------------------------------------------
    -- SEASONAL NEMESIS
    -- Quest 93525 "Nulling Nullaeus" — boss Nullaeus in Voidstorm
    -- at Torment's Rise (61.2, 71.6). Percentage-based coordinates.
    --------------------------------------------------------------------

    local nemHeader = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    nemHeader:SetPoint("TOPLEFT", gvDiv, "BOTTOMLEFT", 0, -6)
    nemHeader:SetFont(nemHeader:GetFont(), 12, "OUTLINE")
    nemHeader:SetText(E.CC.header .. "Seasonal Nemesis" .. E.CC.close)

    local NEMESIS_NAME  = "Nullaeus"
    local NEMESIS_ZONE  = "Voidstorm"
    local NEMESIS_QUEST = 93525
    local NEMESIS_X, NEMESIS_Y_COORD = 61.2, 71.6
    local NEMESIS_MAP   = 2405
    local NEMESIS_LOC   = "Torment's Rise"
    local NEMESIS_ICON  = "Interface\\Icons\\Inv_120_raid_voidspire_hostgeneral"

    -- Nemesis icon
    local nemIcon = sc:CreateTexture(nil, "ARTWORK")
    nemIcon:SetPoint("TOPLEFT", nemHeader, "BOTTOMLEFT", 0, -4)
    nemIcon:SetSize(32, 32)
    nemIcon:SetTexture(NEMESIS_ICON)

    local nemNameFS = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    nemNameFS:SetPoint("LEFT", nemIcon, "RIGHT", 6, 6)
    nemNameFS:SetFont(nemNameFS:GetFont(), 11)
    nemNameFS:SetText(
        E.CC.gold .. NEMESIS_NAME .. E.CC.close
        .. E.CC.muted .. "  (" .. NEMESIS_ZONE
        .. " — " .. NEMESIS_LOC .. ")" .. E.CC.close
    )

    local nemStatusFS = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    nemStatusFS:SetPoint("TOPLEFT", nemIcon, "BOTTOMLEFT", 0, -2)
    nemStatusFS:SetFont(nemStatusFS:GetFont(), 11)

    -- Waypoint / TomTom buttons for nemesis
    local nemWpBtn = E:CreateButton(sc, 32, 20, "Pin")
    nemWpBtn.label:SetFont(nemWpBtn.label:GetFont(), 10)
    nemWpBtn:SetPoint("LEFT", nemIcon, "RIGHT", 240, 0)
    nemWpBtn:SetScript("OnClick", function()
        E:SetWaypoint(NEMESIS_MAP, NEMESIS_X, NEMESIS_Y_COORD)
        E:FlashButtonConfirm(nemWpBtn)
    end)
    nemWpBtn:SetScript("OnEnter", function(self)
        local hc = E.Colors.buttonHover
        self:SetBackdropColor(hc.r, hc.g, hc.b, hc.a)
        E:ShowTooltip(self, "Set Waypoint", "Pin the Nemesis location on your map.")
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
        E:AddTomTomWaypoint(NEMESIS_MAP, NEMESIS_X, NEMESIS_Y_COORD, NEMESIS_NAME)
        E:FlashButtonConfirm(nemTTBtn)
    end)
    nemTTBtn:SetScript("OnEnter", function(self)
        local hc = E.Colors.buttonHover
        self:SetBackdropColor(hc.r, hc.g, hc.b, hc.a)
        if E:IsTomTomLoaded() then
            E:ShowTooltip(self, "TomTom Waypoint", "Add a TomTom arrow to the Nemesis.")
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

    local function RefreshGreatVault()
        local ok, activities = pcall(function()
            if C_WeeklyRewards and C_WeeklyRewards.GetActivities then
                return C_WeeklyRewards.GetActivities()
            end
            return nil
        end)

        if not ok or not activities or #activities == 0 then
            gvFallbackFS:SetText(
                E.CC.muted .. "Great Vault data not available yet — enter a dungeon, raid or delve first" .. E.CC.close)
            gvFallbackFS:Show()
            gvNoteFS:Hide()
            for _, bar in pairs(gvBars) do bar:Hide() end
            return
        end

        gvFallbackFS:Hide()
        gvNoteFS:Show()

        -- Aggregate progress per threshold type
        local progress = {}
        for _, act in ipairs(activities) do
            if not progress[act.type] then
                progress[act.type] = { completed = 0, total = 0 }
            end
            progress[act.type].total = math_max(progress[act.type].total, act.threshold or 0)
            progress[act.type].completed = math_max(progress[act.type].completed, act.progress or 0)
        end

        for _, cfg in ipairs(GV_ROWS) do
            local bar = gvBars[cfg.type]
            if bar then
                local data = progress[cfg.type]
                if data then
                    local current = math_min(data.completed, data.total)
                    bar:SetProgress(current, data.total)
                    -- Gold for complete, red for incomplete
                    if current >= data.total then
                        bar.fill:SetColorTexture(0.78, 0.61, 0.04, 0.90)
                    else
                        bar.fill:SetColorTexture(0.55, 0, 0, 0.90)
                    end
                else
                    bar:SetProgress(0, cfg.max)
                end
                bar:Show()
            end
        end
    end

    local function RefreshNemesis()
        local completed  = false
        local inProgress = false
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
                E.CC.green .. "[Done] \"Nulling Nullaeus\" complete this week" .. E.CC.close
            )
        elseif inProgress then
            nemStatusFS:SetText(
                E.CC.yellow .. "\"Nulling Nullaeus\" in progress — check your quest log" .. E.CC.close
            )
        else
            nemStatusFS:SetText(
                E.CC.red .. "Quest available" .. E.CC.close
                .. E.CC.muted .. " — pick up at Delvers HQ in Silvermoon"
                .. " (if eligible)" .. E.CC.close
            )
        end
    end

    --------------------------------------------------------------------
    -- VALEERA — COMPANION BUTTON
    -- Opens the Delve Companion UI (Blizzard_DelvesCompanionConfiguration).
    -- The companion config is a load-on-demand Blizzard addon that provides
    -- DelvesCompanionConfigurationFrame once loaded.
    --------------------------------------------------------------------
    local valeeraBtn = E:CreateButton(sc, 160, 24, "Valeera \226\128\148 Companion")
    valeeraBtn.label:SetFont(valeeraBtn.label:GetFont(), 11)
    valeeraBtn:SetPoint("TOPLEFT", nemStatusFS, "BOTTOMLEFT", 0, -10)
    valeeraBtn:SetScript("OnClick", function()
        -- Load the Blizzard companion config addon if not already loaded
        if not C_AddOns.IsAddOnLoaded("Blizzard_DelvesCompanionConfiguration") then
            C_AddOns.LoadAddOn("Blizzard_DelvesCompanionConfiguration")
        end
        if DelvesCompanionConfigurationFrame then
            ToggleFrame(DelvesCompanionConfigurationFrame)
        else
            print(E.CC.header .. "Everything Delves|r: "
                .. "Companion UI not available — visit Valeera at Delvers HQ.")
        end
    end)
    valeeraBtn:SetScript("OnEnter", function(self)
        local hc = E.Colors.buttonHover
        self:SetBackdropColor(hc.r, hc.g, hc.b, hc.a)
        E:ShowTooltip(self, "Valeera — Companion",
                      "Open Valeera's companion menu to manage",
                      "her role and curios.")
    end)
    valeeraBtn:SetScript("OnLeave", function(self)
        local bc = E.Colors.buttonBg
        self:SetBackdropColor(bc.r, bc.g, bc.b, bc.a)
        E:HideTooltip()
    end)

    --------------------------------------------------------------------
    -- Thin red divider
    --------------------------------------------------------------------
    local div2 = sc:CreateTexture(nil, "ARTWORK")
    div2:SetHeight(1)
    div2:SetPoint("TOPLEFT", valeeraBtn, "BOTTOMLEFT", 0, -8)
    div2:SetPoint("RIGHT", sc, "RIGHT", -8, 0)
    div2:SetColorTexture(dc.r, dc.g, dc.b, dc.a)

    --------------------------------------------------------------------
    -- TROVEHUNTER'S BOUNTY
    -- Weekly quest 86371 tracks if player has looted one this week.
    -- Map item 252415 / item ID 265714, icon 1064187, aura 1254631.
    -- Check bag via C_Item.GetItemCount(252415)
    -- Check active aura via C_UnitAuras.GetPlayerAuraBySpellID(1254631)
    --------------------------------------------------------------------

    local troveHeader = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    troveHeader:SetPoint("TOPLEFT", div2, "BOTTOMLEFT", 0, -8)
    troveHeader:SetFont(troveHeader:GetFont(), 12, "OUTLINE")
    troveHeader:SetText(E.CC.header .. "Trovehunter's Bounty" .. E.CC.close)

    local TROVE_QUEST_ID = 86371   -- weekly loot check quest
    local TROVE_USED_ID  = 92887   -- bounty consumed quest
    local TROVE_MAP_ITEM = 252415  -- map item (bag check)
    local TROVE_ITEM_ID  = 265714  -- actual item ID
    local TROVE_ICON     = 1064187 -- texture ID
    local TROVE_AURA     = 1254631 -- buff spell ID

    -- Trovehunter icon
    local troveIcon = sc:CreateTexture(nil, "ARTWORK")
    troveIcon:SetPoint("TOPLEFT", troveHeader, "BOTTOMLEFT", 0, -4)
    troveIcon:SetSize(32, 32)
    troveIcon:SetTexture(TROVE_ICON)

    local troveStatusFS = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    troveStatusFS:SetPoint("LEFT", troveIcon, "RIGHT", 6, 6)
    troveStatusFS:SetFont(troveStatusFS:GetFont(), 11)

    local troveDetailFS = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    troveDetailFS:SetPoint("TOPLEFT", troveStatusFS, "BOTTOMLEFT", 0, -2)
    troveDetailFS:SetFont(troveDetailFS:GetFont(), 10)

    local function RefreshTrovehunter()
        local weeklyDone = false
        local bountyUsed = false
        if C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted then
            weeklyDone = C_QuestLog.IsQuestFlaggedCompleted(TROVE_QUEST_ID)
            bountyUsed = C_QuestLog.IsQuestFlaggedCompleted(TROVE_USED_ID)
        end

        local inBag = 0
        if C_Item and C_Item.GetItemCount then
            inBag = C_Item.GetItemCount(TROVE_MAP_ITEM)
        end

        local auraActive = false
        if C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID then
            auraActive = C_UnitAuras.GetPlayerAuraBySpellID(TROVE_AURA) ~= nil
        end

        if weeklyDone then
            if bountyUsed then
                troveStatusFS:SetText(
                    E.CC.muted .. "Bounty looted and used this week. [Done]"
                    .. E.CC.close
                )
            else
                troveStatusFS:SetText(
                    E.CC.yellow .. "Bounty looted — not yet used this week."
                    .. E.CC.close
                )
            end
        else
            troveStatusFS:SetText(
                E.CC.green .. "You can still get a Trovehunter's Bounty this week!"
                .. E.CC.close
            )
        end

        -- Secondary detail line
        if inBag > 0 and not auraActive then
            troveDetailFS:SetText(
                E.CC.yellow .. "You have a Trovehunter's Bounty in your bag — "
                .. "don't forget to use it!" .. E.CC.close
            )
            troveDetailFS:Show()
        elseif auraActive then
            troveDetailFS:SetText(
                E.CC.green .. "Your Trovehunter's Bounty is active. Happy looting!"
                .. E.CC.close
            )
            troveDetailFS:Show()
        else
            troveDetailFS:Hide()
        end
    end

    --------------------------------------------------------------------
    -- Thin red divider
    --------------------------------------------------------------------
    local div3 = sc:CreateTexture(nil, "ARTWORK")
    div3:SetHeight(1)
    div3:SetPoint("TOPLEFT", troveIcon, "BOTTOMLEFT", 0, -24)
    div3:SetPoint("RIGHT", sc, "RIGHT", -8, 0)
    div3:SetColorTexture(dc.r, dc.g, dc.b, dc.a)

    --------------------------------------------------------------------
    -- BEACON OF HOPE
    -- Checks bags/bank for the item and shows Undercoin progress.
    -- C_Item.GetItemCount(itemID, includeBank) returns the count.
    -- Undercoin currency 2803 is used to purchase from vendor (5000).
    --------------------------------------------------------------------

    local beaconHeader = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    beaconHeader:SetPoint("TOPLEFT", div3, "BOTTOMLEFT", 0, -8)
    beaconHeader:SetFont(beaconHeader:GetFont(), 12, "OUTLINE")
    beaconHeader:SetText(E.CC.header .. "Beacon of Hope" .. E.CC.close)

    local beaconStatusFS = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    beaconStatusFS:SetPoint("TOPLEFT", beaconHeader, "BOTTOMLEFT", 0, -4)
    beaconStatusFS:SetFont(beaconStatusFS:GetFont(), 11)

    local BEACON_ITEM_ID    = 253342  -- Beacon of Hope item
    local UNDERCOIN_ID      = 2803    -- Undercoin currency
    local BEACON_PRICE      = 5000    -- cost in Undercoins

    -- Currency progress bar toward buying a Beacon
    local beaconBar = E:CreateProgressBar(sc, 0, 14)
    beaconBar:SetPoint("TOPLEFT", beaconStatusFS, "BOTTOMLEFT", 0, -6)
    beaconBar:SetPoint("RIGHT", sc, "RIGHT", -20, 0)

    local beaconNoteFS = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    beaconNoteFS:SetPoint("TOPLEFT", beaconBar, "BOTTOMLEFT", 0, -4)
    beaconNoteFS:SetFont(beaconNoteFS:GetFont(), 10)

    local function RefreshBeacon()
        -- C_Item.GetItemCount counts items in bags; second arg = include bank
        local inBags = 0
        if C_Item and C_Item.GetItemCount then
            inBags = C_Item.GetItemCount(BEACON_ITEM_ID, true)
        end

        if inBags > 0 then
            beaconStatusFS:SetText(
                E.CC.green .. "[Done] Beacon of Hope in inventory ("
                .. inBags .. ")" .. E.CC.close
                .. E.CC.muted .. " — go get that Nemesis!" .. E.CC.close
            )
        else
            beaconStatusFS:SetText(
                E.CC.red .. "No Beacon of Hope in bags or bank" .. E.CC.close
            )
        end

        -- Undercoin progress toward purchasing one
        local undercoins = 0
        if C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo then
            local info = C_CurrencyInfo.GetCurrencyInfo(UNDERCOIN_ID)
            if info then
                undercoins = info.quantity or 0
            end
        end

        beaconBar:SetProgress(undercoins, BEACON_PRICE)

        if undercoins < BEACON_PRICE then
            beaconNoteFS:SetText(
                E.CC.red .. "Insufficient Undercoins. " .. E.CC.close
                .. E.CC.muted .. "(" .. E.CC.close
                .. E.CC.red .. undercoins .. E.CC.close
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
    -- GILDED STASH PROGRESS
    -- Widget spell 7591 tracks Gilded Stash (4x T11 Bountiful Delves).
    -- Uses C_UIWidgetManager.GetSpellDisplayVisualizationInfo(7591).
    --------------------------------------------------------------------
    local GILDED_WIDGET  = 7591
    local GILDED_MAX     = 4

    -- Thin red divider
    local div4 = sc:CreateTexture(nil, "ARTWORK")
    div4:SetHeight(1)
    div4:SetPoint("TOPLEFT", beaconNoteFS, "BOTTOMLEFT", 0, -8)
    div4:SetPoint("RIGHT", sc, "RIGHT", -8, 0)
    div4:SetColorTexture(dc.r, dc.g, dc.b, dc.a)

    local gildedHeader = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    gildedHeader:SetPoint("TOPLEFT", div4, "BOTTOMLEFT", 0, -8)
    gildedHeader:SetFont(gildedHeader:GetFont(), 12, "OUTLINE")
    gildedHeader:SetText(E.CC.header .. "Gilded Stash Progress" .. E.CC.close)

    local gildedStatusFS = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    gildedStatusFS:SetPoint("TOPLEFT", gildedHeader, "BOTTOMLEFT", 0, -4)
    gildedStatusFS:SetFont(gildedStatusFS:GetFont(), 11)

    local gildedBar = E:CreateProgressBar(sc, 0, 14)
    gildedBar:SetPoint("TOPLEFT", gildedStatusFS, "BOTTOMLEFT", 0, -6)
    gildedBar:SetPoint("RIGHT", sc, "RIGHT", -20, 0)

    local gildedNoteFS = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    gildedNoteFS:SetPoint("TOPLEFT", gildedBar, "BOTTOMLEFT", 0, -4)
    gildedNoteFS:SetFont(gildedNoteFS:GetFont(), 10)

    -- Tooltip on header hover
    gildedHeader:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOPRIGHT")
        GameTooltip:AddLine("Gilded Stash", 1, 0.84, 0)
        GameTooltip:AddLine(
            "Complete 4 Tier 11 Bountiful Delves this week\n"
            .. "to earn a Gilded Stash reward.",
            1, 1, 1, true
        )
        GameTooltip:Show()
    end)
    gildedHeader:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    local function RefreshGildedStash()
        local progress = 0
        if C_UIWidgetManager
                and C_UIWidgetManager.GetSpellDisplayVisualizationInfo then
            local info = C_UIWidgetManager
                .GetSpellDisplayVisualizationInfo(GILDED_WIDGET)
            ---@diagnostic disable-next-line: undefined-field
            if info and info.shownState == 1 then
                progress = info.spellInfo
                        and info.spellInfo.tooltip
                        and tonumber(
                            info.spellInfo.tooltip:match("(%d+)")
                        ) or 0
            end
        end

        -- Clamp
        if progress > GILDED_MAX then progress = GILDED_MAX end

        gildedBar:SetProgress(progress, GILDED_MAX)

        if progress >= GILDED_MAX then
            gildedStatusFS:SetText(
                E.CC.gold .. "[Done] Gilded Stash earned! ("
                .. progress .. " / " .. GILDED_MAX .. ")" .. E.CC.close
            )
            gildedNoteFS:SetText(
                E.CC.muted .. "All T11 Bountiful Delve runs complete this week."
                .. E.CC.close
            )
        elseif progress > 0 then
            gildedStatusFS:SetText(
                E.CC.yellow .. progress .. " / " .. GILDED_MAX
                .. " T11 runs this week" .. E.CC.close
            )
            gildedNoteFS:SetText(
                E.CC.body .. (GILDED_MAX - progress)
                .. " more T11 Bountiful Delve runs needed." .. E.CC.close
            )
        else
            gildedStatusFS:SetText(
                E.CC.red .. "0 / " .. GILDED_MAX
                .. " — no T11 runs yet this week" .. E.CC.close
            )
            gildedNoteFS:SetText(
                E.CC.muted
                .. "Run 4 Tier 11 Bountiful Delves for the Gilded Stash."
                .. E.CC.close
            )
        end
    end

    --------------------------------------------------------------------
    -- MIDNIGHT FACTION RENOWN
    -- Shows renown progress for all 4 Midnight factions.
    -- Uses C_MajorFactions.GetMajorFactionData(factionID).
    --------------------------------------------------------------------
    local MIDNIGHT_FACTIONS = {
        { id = 2710, name = "Silvermoon Court" },
        { id = 2696, name = "Amani Tribe" },
        { id = 2704, name = "Hara'ti" },
        { id = 2699, name = "The Singularity" },
    }
    local FACTION_RENOWN_MAX = 20

    -- Thin red divider
    local div5 = sc:CreateTexture(nil, "ARTWORK")
    div5:SetHeight(1)
    div5:SetPoint("TOPLEFT", gildedNoteFS, "BOTTOMLEFT", 0, -8)
    div5:SetPoint("RIGHT", sc, "RIGHT", -8, 0)
    div5:SetColorTexture(dc.r, dc.g, dc.b, dc.a)

    local renownHeader = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    renownHeader:SetPoint("TOPLEFT", div5, "BOTTOMLEFT", 0, -8)
    renownHeader:SetFont(renownHeader:GetFont(), 12, "OUTLINE")
    renownHeader:SetText(E.CC.header .. "Midnight Faction Renown" .. E.CC.close)

    -- Create faction rows: label + progress bar + status text
    local factionRows = {}
    for i, fac in ipairs(MIDNIGHT_FACTIONS) do
        local rowY = -4 - ((i - 1) * 28)

        local nameFS = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        nameFS:SetPoint("TOPLEFT", renownHeader, "BOTTOMLEFT", 0, rowY)
        nameFS:SetFont(nameFS:GetFont(), 11)
        nameFS:SetWidth(160)
        nameFS:SetJustifyH("LEFT")

        local bar = E:CreateProgressBar(sc, 350, 12)
        bar:SetPoint("LEFT", nameFS, "RIGHT", 4, 0)

        local statusFS = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        statusFS:SetPoint("LEFT", bar, "RIGHT", 8, 0)
        statusFS:SetFont(statusFS:GetFont(), 10)

        factionRows[i] = {
            factionID = fac.id,
            name      = fac.name,
            nameFS    = nameFS,
            bar       = bar,
            statusFS  = statusFS,
        }
    end

    local function RefreshRenown()
        for _, row in ipairs(factionRows) do
            row.nameFS:SetText(E.CC.body .. row.name .. E.CC.close)

            local renown = 0
            if C_MajorFactions and C_MajorFactions.GetMajorFactionData then
                local data = C_MajorFactions.GetMajorFactionData(row.factionID)
                if data then
                    renown = data.renownLevel or 0
                end
            end

            row.bar:SetProgress(renown, FACTION_RENOWN_MAX)

            if renown >= FACTION_RENOWN_MAX then
                row.statusFS:SetText(
                    E.CC.gold .. "Max (" .. renown .. " / "
                    .. FACTION_RENOWN_MAX .. ")" .. E.CC.close
                )
            elseif renown > 0 then
                row.statusFS:SetText(
                    E.CC.yellow .. renown .. " / "
                    .. FACTION_RENOWN_MAX .. E.CC.close
                )
            else
                row.statusFS:SetText(
                    E.CC.muted .. "0 / "
                    .. FACTION_RENOWN_MAX .. E.CC.close
                )
            end
        end
    end

    --------------------------------------------------------------------
    -- OnShow: refresh all sections when the tab becomes visible
    --------------------------------------------------------------------
    frame:SetScript("OnShow", function()
        RefreshRecommendation()
        RefreshGreatVault()
        RefreshNemesis()
        RefreshTrovehunter()
        RefreshBeacon()
        RefreshGildedStash()
        RefreshRenown()
        UpdateScrollRange()
        scrollFrame:SetVerticalScroll(0)
        tabScrollBar:SetValue(0)
    end)

    --------------------------------------------------------------------
    -- Register for inventory/quest events for live updates
    --------------------------------------------------------------------
    E:RegisterCallback("InventoryChanged", function()
        if frame:IsShown() then
            RefreshRecommendation()
        end
    end)

    E:RegisterCallback("QuestLogUpdate", function()
        if frame:IsShown() then
            RefreshNemesis()
            RefreshTrovehunter()
        end
    end)

    E:RegisterCallback("BagUpdate", function()
        if frame:IsShown() then
            RefreshBeacon()
        end
    end)

    --------------------------------------------------------------------
    -- Register with the main frame tab system
    --------------------------------------------------------------------
    E:RegisterTab(3, frame)
end)
