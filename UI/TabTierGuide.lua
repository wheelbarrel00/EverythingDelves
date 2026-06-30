local E = EverythingDelves

local math_floor, math_max, math_min = math.floor, math.max, math.min
local table_insert = table.insert

-- Equipped iLvl is what matters inside a delve, not overall.
local function GetPlayerIlvl()
    local equipped, overall = GetAverageItemLevel()
    local ilvl = math_floor(equipped or overall or 0)
    return ilvl
end

local function GetRecommendedTier(ilvl)
    local best = 1
    for _, t in ipairs(E.TierData) do
        if ilvl >= t.recGear then
            best = t.tier
        end
    end
    return best
end

-- Delver's Journey is the season Delves faction's renown under the hood:
-- C_DelvesUI.GetDelvesFactionForSeason() -> faction ID, then
-- C_MajorFactions.GetMajorFactionRenownInfo / GetRenownRewardsForLevel.
local function GetDelverJourney()
    if C_DelvesUI and C_DelvesUI.GetDelvesFactionForSeason
            and C_MajorFactions and C_MajorFactions.GetMajorFactionRenownInfo then
        local factionID = C_DelvesUI.GetDelvesFactionForSeason()
        if factionID and factionID > 0 then
            local info = C_MajorFactions.GetMajorFactionRenownInfo(factionID)
            if info then
                return info.renownLevel or 0,
                       math_floor(info.renownReputationEarned or 0),
                       math_floor(info.renownLevelThreshold or 1),
                       factionID, true
            end
        end
    end
    -- ok=false -> RefreshJourney hides the section (renown not loaded yet).
    return 0, 0, 1, nil, false
end

local function IsJourneyMaxed(factionID)
    if factionID and C_MajorFactions and C_MajorFactions.HasMaximumRenown then
        local ok, maxed = pcall(C_MajorFactions.HasMaximumRenown, factionID)
        if ok then return maxed and true or false end
    end
    return false
end

-- Highest level the track defines, so we never request art past its end.
local function GetJourneyMaxLevel(factionID)
    if not (factionID and C_MajorFactions and C_MajorFactions.GetRenownLevels) then
        return nil
    end
    local ok, levels = pcall(C_MajorFactions.GetRenownLevels, factionID)
    if not ok or type(levels) ~= "table" then return nil end
    local maxLevel = 0
    for _, lv in ipairs(levels) do
        if type(lv) == "table" and (lv.level or 0) > maxLevel then
            maxLevel = lv.level
        end
    end
    return (maxLevel > 0) and maxLevel or nil
end

-- Milestone art is the level's renown reward .icon; fall back to the
-- reward's item / spell / mount icon. pcall-guarded so the row can hide.
local function GetJourneyNodeIcon(factionID, level)
    if not (factionID and C_MajorFactions
            and C_MajorFactions.GetRenownRewardsForLevel) then
        return nil
    end
    local ok, rewards = pcall(C_MajorFactions.GetRenownRewardsForLevel, factionID, level)
    if not ok or type(rewards) ~= "table" then return nil end
    local r = rewards[1]
    if type(r) ~= "table" then return nil end

    local icon = r.icon
    if not icon and r.itemID and C_Item and C_Item.GetItemIconByID then
        icon = C_Item.GetItemIconByID(r.itemID)
    end
    if not icon and r.spellID and C_Spell and C_Spell.GetSpellTexture then
        icon = C_Spell.GetSpellTexture(r.spellID)
    end
    if not icon and r.mountID and C_MountJournal
            and C_MountJournal.GetMountInfoByID then
        local ok2, _, _, mIcon = pcall(C_MountJournal.GetMountInfoByID, r.mountID)
        if ok2 and mIcon then icon = mIcon end
    end
    return icon, r.name
end

E:RegisterModule(function()
    local frame = CreateFrame("Frame", "EverythingDelvesTab3Content")

    local GRID_X       = 8
    local GRID_Y       = -6
    local COL_WIDTH    = 44
    local ROW_HEIGHT   = 20
    local LABEL_WIDTH  = 110

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

    local tierCells = {}

    for _, td in ipairs(E.TierData) do
        local colX = GRID_X + LABEL_WIDTH + ((td.tier - 1) * COL_WIDTH)
        local cell = {}

        local bg = frame:CreateTexture(nil, "BACKGROUND")
        bg:SetPoint("TOPLEFT", frame, "TOPLEFT", colX - 2, GRID_Y + 2)
        bg:SetSize(COL_WIDTH, ROW_HEIGHT * 4)
        bg:SetColorTexture(0.55, 0, 0, 0.20)
        bg:Hide()
        cell.bg = bg

        local tierFS = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        tierFS:SetPoint("TOPLEFT", frame, "TOPLEFT", colX, GRID_Y)
        tierFS:SetFont(tierFS:GetFont(), 10, "OUTLINE")
        local tc = E:GetTierCC(td.tier)
        tierFS:SetText(tc .. "T" .. td.tier .. E.CC.close)
        cell.tierFS = tierFS

        local gearFS = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        gearFS:SetPoint("TOPLEFT", frame, "TOPLEFT", colX, GRID_Y - ROW_HEIGHT)
        gearFS:SetFont(gearFS:GetFont(), 10)
        gearFS:SetText(E.CC.body .. td.recGear .. E.CC.close)
        cell.gearFS = gearFS

        local bountFS = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        bountFS:SetPoint("TOPLEFT", frame, "TOPLEFT", colX, GRID_Y - ROW_HEIGHT * 2)
        bountFS:SetFont(bountFS:GetFont(), 10)
        local _, bountCC = E:GetLootTrack(td.bountifulLoot)
        bountFS:SetText(bountCC .. td.bountifulLoot .. E.CC.close)
        cell.bountFS = bountFS

        local vaultFS = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        vaultFS:SetPoint("TOPLEFT", frame, "TOPLEFT", colX, GRID_Y - ROW_HEIGHT * 3)
        vaultFS:SetFont(vaultFS:GetFont(), 10)
        local _, vaultCC = E:GetLootTrack(td.greatVault)
        vaultFS:SetText(vaultCC .. td.greatVault .. E.CC.close)
        cell.vaultFS = vaultFS

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
            local bN, bC = E:GetLootTrack(td.bountifulLoot)
            local vN, vC = E:GetLootTrack(td.greatVault)
            table_insert(tipLines, E.CC.muted .. "Bountiful Loot: " .. E.CC.close
                .. bC .. td.bountifulLoot .. " (" .. bN .. ")" .. E.CC.close)
            table_insert(tipLines, E.CC.muted .. "Great Vault: " .. E.CC.close
                .. vC .. td.greatVault .. " (" .. vN .. ")" .. E.CC.close)
            E:ShowTooltip(self, "Tier " .. td.tier, unpack(tipLines))
        end)
        hitBox:SetScript("OnLeave", function() E:HideTooltip() end)

        tierCells[td.tier] = cell
    end

    E:RegisterThemed(function(p)
        for _, cell in pairs(tierCells) do
            if cell.bg and cell.bg.SetColorTexture then
                cell.bg:SetColorTexture(p.progressFill.r, p.progressFill.g,
                                        p.progressFill.b, 0.20)
            end
        end
    end)

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
    E:RegisterThemed(function(p)
        recBox:SetBackdropBorderColor(p.border.r, p.border.g, p.border.b, 0.60)
    end)

    local ilvlLabel = recBox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    ilvlLabel:SetPoint("TOPLEFT", recBox, "TOPLEFT", 8, -6)
    ilvlLabel:SetFont(ilvlLabel:GetFont(), 11)

    local recLabel = recBox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    recLabel:SetPoint("TOPLEFT", ilvlLabel, "BOTTOMLEFT", 0, -3)
    recLabel:SetFont(recLabel:GetFont(), 11)

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
            .. E.CC.body .. " - running this tier gives you the best gear upgrade chance" .. E.CC.close
        )

        for tier, cell in pairs(tierCells) do
            if tier == recTier then
                cell.bg:Show()
            else
                cell.bg:Hide()
            end
        end
    end

    local scrollFrame = CreateFrame("ScrollFrame", nil, frame)
    scrollFrame:SetPoint("TOPLEFT", recBox, "BOTTOMLEFT", -4, -10)
    scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -18, 4)
    scrollFrame:EnableMouseWheel(true)

    local sc = CreateFrame("Frame")
    sc:SetSize(1, 1)
    scrollFrame:SetScrollChild(sc)

    scrollFrame:SetScript("OnSizeChanged", function(self, w)
        sc:SetWidth(w)
    end)
    -- Safe oversize; UpdateContentHeight() recomputes the exact height after layout.
    sc:SetHeight(1200)

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


    local gvHeader = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    gvHeader:SetPoint("TOPLEFT", sc, "TOPLEFT", GRID_X, -4)
    gvHeader:SetFont(gvHeader:GetFont(), E.HEADER_FONT_SIZE, "OUTLINE")
    E:StyleAccentHeader(gvHeader, "Great Vault Progress")

    local gvFallbackFS = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    gvFallbackFS:SetPoint("TOPLEFT", gvHeader, "BOTTOMLEFT", 0, -4)
    gvFallbackFS:SetFont(gvFallbackFS:GetFont(), 10)
    gvFallbackFS:Hide()

    -- No PvP row: World Content replaced the Great Vault PvP slot in TWW,
    -- so C_WeeklyRewards.GetActivities never returns a RankedPvP row.
    local GV_ROWS = {
        { type = Enum.WeeklyRewardChestThresholdType.Activities, label = "Mythic+ Dungeons",       max = 8 },
        { type = Enum.WeeklyRewardChestThresholdType.World,      label = "Delves / World Content", max = 8 },
    }

    local GV_SLOT_W, GV_SLOT_H, GV_SLOT_GAP = 92, 40, 8
    local gvSlots = {}
    local gvSummaries = {}
    local gvLastAnchor = gvHeader
    for i, cfg in ipairs(GV_ROWS) do
        local rowLabel = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        rowLabel:SetPoint("TOPLEFT", gvLastAnchor, "BOTTOMLEFT", 0, (i == 1) and -6 or -10)
        rowLabel:SetFont(rowLabel:GetFont(), 10)
        rowLabel:SetText(E.CC.muted .. cfg.label .. ":" .. E.CC.close)

        local cells = {}
        for s = 1, 3 do
            local cell = CreateFrame("Frame", nil, sc, "BackdropTemplate")
            cell:SetSize(GV_SLOT_W, GV_SLOT_H)
            cell:SetBackdrop({
                bgFile   = "Interface\\Buttons\\WHITE8x8",
                edgeFile = "Interface\\Buttons\\WHITE8x8",
                edgeSize = 1,
            })
            cell:SetBackdropColor(0.07, 0.07, 0.07, 0.85)
            cell:SetBackdropBorderColor(0.30, 0.30, 0.30, 0.60)
            if s == 1 then
                cell:SetPoint("TOPLEFT", rowLabel, "BOTTOMLEFT", 0, -3)
            else
                cell:SetPoint("LEFT", cells[s - 1], "RIGHT", GV_SLOT_GAP, 0)
            end

            local ilvlFS = cell:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            ilvlFS:SetPoint("TOP", cell, "TOP", 0, -5)
            ilvlFS:SetFont(ilvlFS:GetFont(), 14, "OUTLINE")
            cell.ilvlFS = ilvlFS

            local subFS = cell:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            subFS:SetPoint("BOTTOM", cell, "BOTTOM", 0, 4)
            subFS:SetFont(subFS:GetFont(), 9)
            cell.subFS = subFS

            cell:EnableMouse(true)
            cell:SetScript("OnEnter", function(self)
                if self.tipTitle then
                    E:ShowTooltip(self, self.tipTitle, self.tipLine1, self.tipLine2)
                end
            end)
            cell:SetScript("OnLeave", function() E:HideTooltip() end)

            cells[s] = cell
        end
        gvSlots[cfg.type] = cells

        local summary = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        summary:SetPoint("TOPLEFT", cells[1], "BOTTOMLEFT", 0, -4)
        summary:SetFont(summary:GetFont(), 9)
        gvSummaries[cfg.type] = summary

        gvLastAnchor = summary
    end

    local gvNoteFS = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    gvNoteFS:SetPoint("TOPLEFT", gvLastAnchor, "BOTTOMLEFT", 0, -4)
    gvNoteFS:SetFont(gvNoteFS:GetFont(), 9)
    gvNoteFS:SetText(E.CC.muted .. "Rewards are claimable after the weekly reset (Tuesday)" .. E.CC.close)

    local gvDiv = sc:CreateTexture(nil, "ARTWORK")
    gvDiv:SetHeight(1)
    gvDiv:SetPoint("TOPLEFT", gvNoteFS, "BOTTOMLEFT", 0, -32)
    gvDiv:SetPoint("RIGHT", sc, "RIGHT", -8, 0)
    E:StyleAccentDivider(gvDiv)

    local function GVRewardILvl(activityID)
        if not (C_WeeklyRewards and C_WeeklyRewards.GetExampleRewardItemHyperlinks) then
            return nil
        end
        local ok, link = pcall(C_WeeklyRewards.GetExampleRewardItemHyperlinks, activityID)
        if not ok or not link or link == "" then return nil end
        if not (C_Item and C_Item.GetDetailedItemLevelInfo) then return nil end
        local ok2, ilvl = pcall(C_Item.GetDetailedItemLevelInfo, link)
        if ok2 and ilvl and ilvl > 0 then return ilvl end
        return nil
    end

    local function RefreshGreatVault()
        local ok, activities = pcall(function()
            if C_WeeklyRewards and C_WeeklyRewards.GetActivities then
                return C_WeeklyRewards.GetActivities()
            end
            return nil
        end)

        if not ok or not activities or #activities == 0 then
            gvFallbackFS:SetText(
                E.CC.muted .. "Great Vault data not available yet - enter a dungeon, raid or delve first" .. E.CC.close)
            gvFallbackFS:Show()
            gvNoteFS:Hide()
            for _, cells in pairs(gvSlots) do
                for _, c in ipairs(cells) do c:Hide() end
            end
            for _, sumFS in pairs(gvSummaries) do sumFS:Hide() end
            return
        end

        gvFallbackFS:Hide()
        gvNoteFS:Show()

        local byType = {}
        for _, act in ipairs(activities) do
            byType[act.type] = byType[act.type] or {}
            table.insert(byType[act.type], act)
        end
        for _, list in pairs(byType) do
            table.sort(list, function(a, b) return (a.threshold or 0) < (b.threshold or 0) end)
        end

        for _, cfg in ipairs(GV_ROWS) do
            local cells = gvSlots[cfg.type]
            local list  = byType[cfg.type]
            local nextRemaining
            for s = 1, 3 do
                local cell = cells[s]
                local act  = list and list[s]
                if act then
                    local threshold = act.threshold or 0
                    local prog      = math_min(act.progress or 0, threshold)
                    local unlocked  = (act.progress or 0) >= threshold
                    local ilvl      = GVRewardILvl(act.id)

                    if ilvl then
                        cell.ilvlFS:SetText(tostring(ilvl))
                        if unlocked then
                            cell.ilvlFS:SetTextColor(0.40, 0.92, 0.45)
                            cell:SetBackdropColor(0.09, 0.13, 0.09, 0.85)
                            cell:SetBackdropBorderColor(0.16, 0.70, 0.30, 0.85)
                        else
                            cell.ilvlFS:SetTextColor(0.80, 0.67, 0.22)
                            cell:SetBackdropColor(0.07, 0.07, 0.07, 0.85)
                            cell:SetBackdropBorderColor(0.40, 0.32, 0.10, 0.80)
                        end
                    else
                        cell.ilvlFS:SetText("\226\128\148")
                        cell.ilvlFS:SetTextColor(0.45, 0.45, 0.45)
                        cell:SetBackdropColor(0.06, 0.06, 0.06, 0.85)
                        cell:SetBackdropBorderColor(0.30, 0.30, 0.30, 0.60)
                    end

                    cell.subFS:SetText(E.CC.muted .. prog .. "/" .. threshold .. E.CC.close)

                    if (not unlocked) and (not nextRemaining) then
                        nextRemaining = threshold - prog
                    end

                    cell.tipTitle = "Reward Slot " .. s
                    cell.tipLine1 = ilvl and ("Item level " .. ilvl) or "No reward unlocked yet"
                    if unlocked then
                        cell.tipLine2 = E.CC.muted .. "Unlocked - claim after the Tuesday reset." .. E.CC.close
                    else
                        cell.tipLine2 = E.CC.muted .. prog .. " / " .. threshold
                            .. "  (" .. (threshold - prog) .. " more)" .. E.CC.close
                    end
                    cell:Show()
                else
                    cell:Hide()
                    cell.tipTitle = nil
                end
            end

            local summary = gvSummaries[cfg.type]
            if not list or #list == 0 then
                summary:SetText("")
            elseif nextRemaining then
                summary:SetText(E.CC.muted .. "Next slot in " .. nextRemaining .. " more" .. E.CC.close)
            else
                summary:SetText(E.CC.gold .. "All slots unlocked" .. E.CC.close)
            end
            summary:Show()
        end
    end

    local DJ_NODE_POOL = 12
    local DJ_NODE_SIZE = 36

    local djHeader = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    djHeader:SetPoint("TOPLEFT", gvDiv, "BOTTOMLEFT", 0, -32)
    djHeader:SetFont(djHeader:GetFont(), E.HEADER_FONT_SIZE, "OUTLINE")
    E:StyleAccentHeader(djHeader, "Delver's Journey")

    djHeader:SetScript("OnEnter", function(self)
        E:ShowTooltip(self, "Delver's Journey",
            "Your progress through this season's Delves track.",
            "Each level unlocks a milestone reward - hover an icon to see it.")
    end)
    djHeader:SetScript("OnLeave", function() E:HideTooltip() end)

    local djLevelFS = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    djLevelFS:SetPoint("TOPLEFT", djHeader, "BOTTOMLEFT", 0, -6)
    djLevelFS:SetFont(djLevelFS:GetFont(), 12)

    local djBar = E:CreateProgressBar(sc, 0, 14)
    djBar:SetPoint("TOPLEFT", djLevelFS, "BOTTOMLEFT", 0, -4)
    djBar:SetPoint("RIGHT", sc, "RIGHT", -20, 0)

    -- Fixed height so the divider below holds position whether icons resolve or not.
    local djIconRow = CreateFrame("Frame", nil, sc)
    djIconRow:SetHeight(DJ_NODE_SIZE + 16)
    djIconRow:SetPoint("TOPLEFT", djBar, "BOTTOMLEFT", 0, -10)
    djIconRow:SetPoint("RIGHT", sc, "RIGHT", -20, 0)

    local djNodes = {}
    for i = 1, DJ_NODE_POOL do
        local card = CreateFrame("Frame", nil, djIconRow, "BackdropTemplate")
        card:SetSize(DJ_NODE_SIZE + 4, DJ_NODE_SIZE + 4)
        if i == 1 then
            card:SetPoint("LEFT", djIconRow, "LEFT", 2, 6)
        else
            card:SetPoint("LEFT", djNodes[i - 1].card, "RIGHT", 18, 0)
        end
        card:SetBackdrop({
            bgFile   = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
        })
        card:SetBackdropColor(0.10, 0.10, 0.10, 1)
        card:SetBackdropBorderColor(0.30, 0.30, 0.30, 0.60)
        card:EnableMouse(true)

        local tex = card:CreateTexture(nil, "ARTWORK")
        tex:SetPoint("CENTER")
        tex:SetSize(DJ_NODE_SIZE - 2, DJ_NODE_SIZE - 2)
        tex:SetTexCoord(0.07, 0.93, 0.07, 0.93)

        local lvlFS = djIconRow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        lvlFS:SetPoint("TOP", card, "BOTTOM", 0, -1)
        lvlFS:SetFont(lvlFS:GetFont(), 9, "OUTLINE")

        djNodes[i] = { card = card, tex = tex, lvlFS = lvlFS }
    end

    local djDiv = sc:CreateTexture(nil, "ARTWORK")
    djDiv:SetHeight(1)
    djDiv:SetPoint("TOPLEFT", djIconRow, "BOTTOMLEFT", 0, -10)
    djDiv:SetPoint("RIGHT", sc, "RIGHT", -8, 0)
    E:StyleAccentDivider(djDiv)

    local function RefreshJourney()
        local level, cur, threshold, factionID, ok = GetDelverJourney()

        if not ok then
            djLevelFS:SetText(
                E.CC.muted .. "Delver's Journey data not available yet "
                .. "- open the Journeys panel once to sync." .. E.CC.close)
            djBar:Hide()
            djIconRow:Hide()
            return
        end

        local maxed = IsJourneyMaxed(factionID)
        if maxed then
            djLevelFS:SetText(
                E.CC.gold .. "Level " .. level .. E.CC.close
                .. E.CC.green .. "   Complete - all milestones earned!" .. E.CC.close)
        else
            djLevelFS:SetText(
                E.CC.gold .. "Level " .. level .. E.CC.close
                .. E.CC.muted .. "   " .. cur .. " / " .. threshold .. E.CC.close)
        end
        -- At max renown renownReputationEarned = 0, so force the bar full.
        if maxed then
            djBar:SetProgress(threshold, threshold)
        else
            djBar:SetProgress(cur, threshold)
        end
        djBar:Show()

        -- Show every level 1..end; if the track outgrows the pool, window to the most recent.
        local maxLevel  = GetJourneyMaxLevel(factionID)
        local topLevel  = maxLevel or (maxed and level) or (level + 1)
        if topLevel < 1 then topLevel = 1 end
        local startLevel = 1
        if topLevel - startLevel + 1 > DJ_NODE_POOL then
            startLevel = topLevel - DJ_NODE_POOL + 1
        end

        local shown = 0
        for i = 1, DJ_NODE_POOL do
            local node = djNodes[i]
            local nodeLevel = startLevel + (i - 1)
            local icon, rewardName
            if nodeLevel <= topLevel then
                icon, rewardName = GetJourneyNodeIcon(factionID, nodeLevel)
            end
            if icon then
                local earned    = nodeLevel <= level
                local isCurrent = nodeLevel == level
                node.tex:SetTexture(icon)
                node.tex:SetDesaturated(not earned)
                if isCurrent then
                    node.card:SetBackdropBorderColor(1, 0.84, 0, 1)
                else
                    node.card:SetBackdropBorderColor(0.30, 0.30, 0.30, 0.60)
                end
                node.lvlFS:SetText(
                    (isCurrent and E.CC.gold or E.CC.muted)
                    .. nodeLevel .. E.CC.close)
                node.card:Show()
                node.lvlFS:Show()
                node.card:SetScript("OnEnter", function(self)
                    E:ShowTooltip(self,
                        "Level " .. nodeLevel
                        .. (earned and "  (earned)" or "  (locked)"),
                        rewardName and (E.CC.body .. rewardName .. E.CC.close) or nil)
                end)
                node.card:SetScript("OnLeave", function() E:HideTooltip() end)
                shown = shown + 1
            else
                node.card:Hide()
                node.lvlFS:Hide()
            end
        end

        if shown > 0 then djIconRow:Show() else djIconRow:Hide() end
    end

    local VALEERA_ICON  = "Interface\\Icons\\Achievement_Character_BloodElf_Female"
    local PORTRAIT_MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"

    local valeeraRow = CreateFrame("Frame", nil, sc)
    valeeraRow:SetHeight(40)
    valeeraRow:SetPoint("TOPLEFT",  djDiv, "BOTTOMLEFT", 0, -8)
    valeeraRow:SetPoint("TOPRIGHT", sc, "TOPRIGHT", -20, 4)

    local valeeraIcon = sc:CreateTexture(nil, "ARTWORK")
    valeeraIcon:SetSize(32, 32)
    valeeraIcon:SetTexture(VALEERA_ICON)
    if valeeraIcon.SetMask then
        pcall(valeeraIcon.SetMask, valeeraIcon, PORTRAIT_MASK)
    end
    valeeraIcon:SetPoint("LEFT", valeeraRow, "LEFT", 0, 0)

    local valeeraBtn = E:CreateButton(valeeraRow, 280, 40, "Valeera \226\128\148 Companion")
    valeeraBtn.label:SetFont(valeeraBtn.label:GetFont(), 14)
    valeeraBtn:SetPoint("LEFT", valeeraIcon, "RIGHT", 8, 0)

    valeeraBtn:SetScript("OnClick", function()
        if not C_AddOns.IsAddOnLoaded("Blizzard_DelvesCompanionConfiguration") then
            C_AddOns.LoadAddOn("Blizzard_DelvesCompanionConfiguration")
        end
        if DelvesCompanionConfigurationFrame then
            ToggleFrame(DelvesCompanionConfigurationFrame)
        else
            print(E.CC.header .. "Everything Delves|r: "
                .. "Companion UI not available - visit Valeera at Delvers HQ.")
        end
    end)
    valeeraBtn:SetScript("OnEnter", function(self)
        local hc = E.Colors.buttonHover
        self:SetBackdropColor(hc.r, hc.g, hc.b, hc.a)
        E:ShowTooltip(self, "Valeera - Companion",
                      "Open Valeera's companion menu to manage",
                      "her role and curios.")
    end)
    valeeraBtn:SetScript("OnLeave", function(self)
        local bc = E.Colors.buttonBg
        self:SetBackdropColor(bc.r, bc.g, bc.b, bc.a)
        E:HideTooltip()
    end)

    local compLevelFS = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    compLevelFS:SetPoint("TOPLEFT", valeeraBtn, "TOPRIGHT", 16, -4)
    compLevelFS:SetFont(compLevelFS:GetFont(), 11)
    compLevelFS:SetJustifyH("LEFT")

    local compBar = E:CreateProgressBar(sc, 0, 12)
    compBar:SetPoint("TOPLEFT", valeeraBtn, "TOPRIGHT", 16, -22)
    compBar:SetPoint("RIGHT", sc, "RIGHT", -20, 0)

    local function RefreshCompanion()
        local comp = E.GetCompanionData and E:GetCompanionData()
        if not comp then
            compLevelFS:SetText(
                E.CC.muted .. "Companion level unavailable." .. E.CC.close)
            compBar:Hide()
            return
        end
        if comp.isMaxLevel then
            compLevelFS:SetText(
                E.CC.body .. comp.name .. E.CC.close .. "   "
                .. E.CC.gold .. "Level " .. comp.level .. " - Max"
                .. E.CC.close)
            compBar:Hide()
        else
            compLevelFS:SetText(
                E.CC.body .. comp.name .. E.CC.close .. "   "
                .. E.CC.gold .. "Level " .. comp.level .. E.CC.close)
            compBar:SetProgress(comp.xpCurrent, comp.xpMax)
            compBar:Show()
        end
    end

    local div2 = sc:CreateTexture(nil, "ARTWORK")
    div2:SetHeight(1)
    div2:SetPoint("TOPLEFT", valeeraRow, "BOTTOMLEFT", 0, -8)
    div2:SetPoint("RIGHT", sc, "RIGHT", -8, 0)
    E:StyleAccentDivider(div2)

    local troveHeader = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    troveHeader:SetPoint("TOPLEFT", div2, "BOTTOMLEFT", 0, -32)
    troveHeader:SetFont(troveHeader:GetFont(), E.HEADER_FONT_SIZE, "OUTLINE")
    E:StyleAccentHeader(troveHeader, "Trovehunter's Bounty")

    local TROVE_QUEST_ID = 86371   -- weekly loot-check quest
    local TROVE_USED_ID  = 92887   -- bounty-consumed quest
    local TROVE_ICON     = 1064187 -- texture ID
    local TROVE_AURA     = 1254631 -- buff spell ID

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

        local inBag = E:GetTrovehunterMapCount()

        local auraActive = false
        if C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID then
            auraActive = C_UnitAuras.GetPlayerAuraBySpellID(TROVE_AURA) ~= nil
        end

        if weeklyDone then
            -- The "used" flag (92887) is unreliable (reads used with a map still
            -- in the bag), so bag presence wins: only "[Done]" when inBag <= 0.
            if bountyUsed and inBag <= 0 then
                troveStatusFS:SetText(
                    E.CC.muted .. "Bounty looted and used this week. [Done]"
                    .. E.CC.close
                )
            else
                troveStatusFS:SetText(
                    E.CC.yellow .. "Bounty looted - not yet used this week."
                    .. E.CC.close
                )
            end
        else
            troveStatusFS:SetText(
                E.CC.green .. "You can still get a Trovehunter's Bounty this week!"
                .. E.CC.close
            )
        end

        if inBag > 0 and not auraActive then
            troveDetailFS:SetText(
                E.CC.yellow .. "You have a Trovehunter's Bounty in your bag - "
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

    local div3 = sc:CreateTexture(nil, "ARTWORK")
    div3:SetHeight(1)
    div3:SetPoint("TOPLEFT", troveIcon, "BOTTOMLEFT", 0, -48)
    div3:SetPoint("RIGHT", sc, "RIGHT", -8, 0)
    E:StyleAccentDivider(div3)

    local GILDED_MAX     = 4   -- 4x T11 Bountiful Delves per week

    local gildedHeader = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    gildedHeader:SetPoint("TOPLEFT", div3, "BOTTOMLEFT", 0, -32)
    gildedHeader:SetFont(gildedHeader:GetFont(), E.HEADER_FONT_SIZE, "OUTLINE")
    E:StyleAccentHeader(gildedHeader, "Gilded Stash Progress")

    local gildedStatusFS = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    gildedStatusFS:SetPoint("TOPLEFT", gildedHeader, "BOTTOMLEFT", 0, -4)
    gildedStatusFS:SetFont(gildedStatusFS:GetFont(), 11)

    local gildedBar = E:CreateProgressBar(sc, 0, 14)
    gildedBar:SetPoint("TOPLEFT", gildedStatusFS, "BOTTOMLEFT", 0, -6)
    gildedBar:SetPoint("RIGHT", sc, "RIGHT", -20, 0)

    local gildedNoteFS = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    gildedNoteFS:SetPoint("TOPLEFT", gildedBar, "BOTTOMLEFT", 0, -4)
    gildedNoteFS:SetFont(gildedNoteFS:GetFont(), 10)

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
        local liveCol, liveTot
        if E.GetLiveGildedStash then
            liveCol, liveTot = E:GetLiveGildedStash()
        end
        local isLive   = liveCol ~= nil
        local maxCount = (isLive and liveTot and liveTot > 0)
            and liveTot or GILDED_MAX

        local lastReset = 0
        if C_DateAndTime and C_DateAndTime.GetSecondsUntilWeeklyReset then
            local secs = C_DateAndTime.GetSecondsUntilWeeklyReset()
            if secs and secs > 0 then
                local now = (GetServerTime and GetServerTime()) or time()
                lastReset = now + secs - 604800
            end
        end

        local estimate = 0
        local history = E.db and E.db.delveHistory
        if history then
            for _, entry in pairs(history) do
                if entry.recentRuns then
                    for _, run in ipairs(entry.recentRuns) do
                        if (run.tier or 0) >= 11
                                and run.wasBountiful
                                and (run.timestamp or 0) >= lastReset then
                            estimate = estimate + 1
                        end
                    end
                end
            end
        end

        local progress = math_max(liveCol or 0, estimate)
        if progress > maxCount then progress = maxCount end

        local fromLive = isLive and (liveCol or 0) >= estimate

        gildedBar:SetProgress(progress, maxCount)

        if progress >= maxCount then
            gildedStatusFS:SetText(
                E.CC.gold .. "[Done] Gilded Stash earned! ("
                .. progress .. " / " .. maxCount .. ")" .. E.CC.close
            )
            gildedNoteFS:SetText(
                E.CC.muted .. (fromLive
                    and "All Gilded Stashes looted this week."
                    or  "All T11 Bountiful Delve runs complete this week.")
                .. E.CC.close
            )
        elseif progress > 0 then
            gildedStatusFS:SetText(
                E.CC.yellow .. progress .. " / " .. maxCount
                .. (fromLive and " Gilded Stashes looted this week"
                            or  " T11 runs this week") .. E.CC.close
            )
            gildedNoteFS:SetText(
                E.CC.body .. (maxCount - progress) .. " more to go."
                .. E.CC.close .. "  " .. E.CC.muted
                .. (fromLive
                    and "Exact count, synced in-delve."
                    or  "Estimate - enter a delve to sync the exact count.")
                .. E.CC.close
            )
        else
            gildedStatusFS:SetText(
                E.CC.btnText .. "0 / " .. maxCount
                .. (fromLive and " - no Gilded Stashes looted yet this week"
                            or  " - no T11 runs yet this week") .. E.CC.close
            )
            gildedNoteFS:SetText(
                E.CC.muted
                .. "Run 4 Tier 11 Bountiful Delves for the Gilded Stash."
                .. E.CC.close
            )
        end
    end

    local MIDNIGHT_FACTIONS = {
        { id = 2710, name = "Silvermoon Court" },
        { id = 2696, name = "Amani Tribe" },
        { id = 2704, name = "Hara'ti" },
        { id = 2699, name = "The Singularity" },
    }
    local FACTION_RENOWN_MAX = 20

    local div5 = sc:CreateTexture(nil, "ARTWORK")
    div5:SetHeight(1)
    div5:SetPoint("TOPLEFT", gildedNoteFS, "BOTTOMLEFT", 0, -32)
    div5:SetPoint("RIGHT", sc, "RIGHT", -8, 0)
    E:StyleAccentDivider(div5)

    local renownHeader = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    renownHeader:SetPoint("TOPLEFT", div5, "BOTTOMLEFT", 0, -32)
    renownHeader:SetFont(renownHeader:GetFont(), E.HEADER_FONT_SIZE, "OUTLINE")
    E:StyleAccentHeader(renownHeader, "Midnight Faction Renown")

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

    -- Recompute scroll child height from the last rendered element; must
    -- run after layout, hence the C_Timer.After(0) defer in OnShow.
    local function UpdateContentHeight()
        local lastRow = factionRows[#factionRows]
        if not (lastRow and lastRow.bar) then return end
        local scTop   = sc:GetTop()
        local lastBot = lastRow.bar:GetBottom()
        if scTop and lastBot and scTop > lastBot then
            sc:SetHeight((scTop - lastBot) + 20)
        end
        UpdateScrollRange()
    end

    frame:SetScript("OnShow", function()
        RefreshRecommendation()
        RefreshGreatVault()
        RefreshJourney()
        RefreshTrovehunter()
        RefreshCompanion()
        RefreshGildedStash()
        RefreshRenown()
        C_Timer.After(0, UpdateContentHeight)
        UpdateScrollRange()
        scrollFrame:SetVerticalScroll(0)
        tabScrollBar:SetValue(0)
    end)

    E:RegisterCallback("InventoryChanged", function()
        if frame:IsShown() then
            RefreshRecommendation()
        end
    end)

    E:RegisterCallback("QuestLogUpdate", function()
        if frame:IsShown() then
            RefreshTrovehunter()
            -- Companion XP and Journey renown both tick up during delves.
            RefreshCompanion()
            RefreshJourney()
        end
    end)

    E:RegisterTab(3, frame)
end)
