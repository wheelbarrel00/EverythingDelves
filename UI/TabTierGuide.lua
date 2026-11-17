local E = EverythingDelves
local L = E.L

local math_floor, math_max, math_min, math_ceil, math_abs = math.floor, math.max, math.min, math.ceil, math.abs
local table_concat = table.concat

local PAD_TOP, PAD_LEFT, PAD_RIGHT, PAD_BOTTOM = 20, 24, 14, 28
local BAR_H, HINT_GAP, HINT_H, CARDS_GAP, GROUP_GAP = 32, 8, 16, 16, 22
local GRID_ROW, GRID_LABEL, GRID_SIDE = 32, 150, 14
local ROW, HINT_ROW, ITEM_GAP, BAR_MIN = 44, 36, 12, 80
local VAULT_LABEL, VAULT_SUMMARY, SLOT_H, SLOT_GAP, CHECK = 160, 120, 40, 8, 14
local MILE, MILE_GAP, MILE_POOL, MILE_ROW, MILE_TOP, LOCKED_ALPHA = 32, 14, 12, 93, 33, 0.3
local PORTRAIT, TROVE_ROW, TROVE_ICON_SIZE, VENOM_ICON = 32, 52, 32, 28
local RENOWN_NAME, RENOWN_STATUS = 150, 110
local STEP_ROW, STEP_BOX, STEP_GAP, STEP_CHECK, STEP_VALUE, FRAG_ICON, LOCKED_STEP_ALPHA = 52, 28, 4, 10, 48, 20, 0.55
local FACTION_RENOWN_MAX = 20
local GILDED_MAX = 4   -- 4x T11 Bountiful Delves per week

local TROVE_QUEST_ID = E.TROVE_LOOTED_QUEST_ID
local TROVE_ICON     = 1064187
local VALEERA_ICON   = "Interface\\Icons\\Achievement_Character_BloodElf_Female"
local PORTRAIT_MASK  = "Interface\\CharacterFrame\\TempPortraitAlphaMask"

-- English only while the game has not sent a faction's data yet
local MIDNIGHT_FACTIONS = {
    { id = 2710, name = "Silvermoon Court" },
    { id = 2696, name = "Amani Tribe" },
    { id = 2704, name = "Hara'ti" },
    { id = 2699, name = "The Singularity" },
}

-- Reset weekday differs by region, so render the remaining time instead of naming a day.
local function WeeklyResetIn()
    if not (C_DateAndTime and C_DateAndTime.GetSecondsUntilWeeklyReset) then return nil end
    local secs = C_DateAndTime.GetSecondsUntilWeeklyReset()
    if not secs or secs <= 0 then return nil end
    return L["%dd %dh %dm"]:format(math_floor(secs / 86400), math_floor((secs % 86400) / 3600),
        math_floor((secs % 3600) / 60))
end

-- Delver's Journey is the renown of the faction C_DelvesUI.GetDelvesFactionForSeason names
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
    -- ok=false: the card shows its "not available yet" line (renown not loaded yet).
    return 0, 0, 1, nil, false
end

local function IsJourneyMaxed(factionID)
    if factionID and C_MajorFactions and C_MajorFactions.HasMaximumRenown then
        local ok, maxed = pcall(C_MajorFactions.HasMaximumRenown, factionID)
        if ok then return maxed and true or false end
    end
    return false
end

local maxLevels, nodeIcons = {}, {}

-- Highest level the track defines, so we never request art past its end.
local function GetJourneyMaxLevel(factionID)
    if maxLevels[factionID] then return maxLevels[factionID] end
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
    if maxLevel <= 0 then return nil end
    maxLevels[factionID] = maxLevel
    return maxLevel
end

-- Milestone art is the level reward's own icon, else its item, spell or mount icon
local function ReadJourneyNodeIcon(factionID, level)
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

local function GetJourneyNodeIcon(factionID, level)
    local byLevel = nodeIcons[factionID]
    local hit = byLevel and byLevel[level]
    if hit then return hit.icon, hit.name end
    local icon, name = ReadJourneyNodeIcon(factionID, level)
    if icon and name then
        if not byLevel then
            byLevel = {}
            nodeIcons[factionID] = byLevel
        end
        byLevel[level] = { icon = icon, name = name }
    end
    return icon, name
end

local function TierTip(td)
    local desc
    if td.tier <= 4 then
        desc = L["Entry-level delves. Good for gearing up alts."]
    elseif td.tier <= 8 then
        desc = L["Mid-tier delves. Solid upgrades for mains early in the season."]
    else
        desc = L["Endgame delves. Best loot, toughest challenge."]
    end
    local bN = E:GetLootTrack(td.bountifulLoot, td.bountifulTrack)
    local vN = E:GetLootTrack(td.greatVault, td.vaultTrack)
    return table_concat({
        desc, "",
        L["Recommended iLvl:"] .. " " .. td.recGear .. "+",
        L["Bountiful Loot:"] .. " " .. td.bountifulLoot .. " (" .. bN .. ")",
        L["Great Vault:"] .. " " .. td.greatVault .. " (" .. vN .. ")",
    }, "\n")
end

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

local function VaultState(rows)
    local ok, activities = pcall(function()
        if C_WeeklyRewards and C_WeeklyRewards.GetActivities then
            return C_WeeklyRewards.GetActivities()
        end
        return nil
    end)
    if not ok or not activities or #activities == 0 then return nil end

    local byType = {}
    for _, act in ipairs(activities) do
        byType[act.type] = byType[act.type] or {}
        table.insert(byType[act.type], act)
    end
    for _, list in pairs(byType) do
        table.sort(list, function(a, b) return (a.threshold or 0) < (b.threshold or 0) end)
    end

    local out = {}
    for i, cfg in ipairs(rows) do
        local list = byType[cfg.type]
        local state = { slots = {}, empty = not list or #list == 0 }
        for s = 1, 3 do
            local act = list and list[s]
            if act then
                local threshold = act.threshold or 0
                local prog = math_min(act.progress or 0, threshold)
                local unlocked = (act.progress or 0) >= threshold
                state.slots[s] = { prog = prog, threshold = threshold, unlocked = unlocked, ilvl = GVRewardILvl(act.id) }
                if not unlocked and not state.nextRemaining then
                    state.nextRemaining = threshold - prog
                end
            end
        end
        out[i] = state
    end
    return out
end

local function TroveText()
    local weeklyDone = false
    if C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted then
        weeklyDone = C_QuestLog.IsQuestFlaggedCompleted(TROVE_QUEST_ID)
    end
    local bountyUsed = E:TrovehunterUsedThisWeek()
    local inBag = E:GetTrovehunterMapCount()
    local auraActive = E:GetTrovehunterAura() ~= nil

    local status, done
    if weeklyDone then
        if bountyUsed then
            status, done = L["Bounty looted and used this week."], true
        else
            status = L["Bounty looted - not yet used this week."]
        end
    else
        status = L["You can still get a Trovehunter's Bounty this week!"]
    end

    local detail
    if inBag > 0 and bountyUsed then
        detail = L["You already used a bounty this week - keep this one for next week."]
    elseif auraActive then
        detail = L["Your Trovehunter's Bounty is active. Happy looting!"]
    elseif inBag > 0 then
        detail = L["You have a Trovehunter's Bounty in your bag - don't forget to use it!"]
    end
    return status, detail, done
end

-- One stash per three chambers. Assumed paid in the treasure room with the coffers, so a run left before it counts none.
local function StashesFor(name, run)
    local LAB = E.Labyrinth
    if not (LAB and name == LAB.name) then return 1 end
    if run.left then return 0 end
    return math_floor(((run.ch or 0) + (run.prior or 0)) / LAB.checkpointEvery)
end

local function GildedState()
    local liveCol, liveTot
    if E.GetLiveGildedStash then
        liveCol, liveTot = E:GetLiveGildedStash()
    end
    local isLive   = liveCol ~= nil
    local maxCount = (isLive and liveTot and liveTot > 0) and liveTot or GILDED_MAX

    -- Weekly boundary in the SAME clock as run.timestamp (time()), so a
    -- skewed local-vs-server clock can't mis-bucket runs near the reset.
    local lastReset, haveReset = 0, false
    if C_DateAndTime and C_DateAndTime.GetSecondsUntilWeeklyReset then
        local secs = C_DateAndTime.GetSecondsUntilWeeklyReset()
        if secs and secs > 0 then
            lastReset = time() + secs - 604800
            haveReset = true
        end
    end

    -- Estimated from history only when the reset is known. Without it, all-time runs would count
    -- and show a false done.
    local estimate = 0
    local history = E.db and E.db.delveHistory
    -- Runs logged before the char stamp count for whoever is logged in.
    local charKey = E.CharKey and E.CharKey()
    if haveReset and history then
        for name, entry in pairs(history) do
            if entry.recentRuns then
                for _, run in ipairs(entry.recentRuns) do
                    if (run.tier or 0) >= 11
                            and run.wasBountiful
                            and (run.timestamp or 0) >= lastReset
                            and (run.char == nil or run.char == charKey) then
                        estimate = estimate + StashesFor(name, run)
                    end
                end
            end
        end
    end

    local progress = math_max(liveCol or 0, estimate)
    if progress > maxCount then progress = maxCount end
    return progress, maxCount, isLive and (liveCol or 0) >= estimate
end

local function GildedText(progress, maxCount, fromLive)
    if progress >= maxCount then
        return L["Gilded Stash earned! (%d / %d)"]:format(progress, maxCount),
            fromLive and L["All Gilded Stashes looted this week."] or L["All T11 Bountiful Delve runs complete this week."]
    elseif progress > 0 then
        return (fromLive and L["%d / %d Gilded Stashes looted this week"] or L["%d / %d T11 runs this week"])
                :format(progress, maxCount),
            L["%d more to go."]:format(maxCount - progress) .. "  "
                .. (fromLive and L["Exact count, synced in-delve."] or L["Estimate - enter a delve to sync the exact count."])
    end
    return (fromLive and L["0 / %d - no Gilded Stashes looted yet this week"] or L["0 / %d - no T11 runs yet this week"])
            :format(maxCount),
        L["Run 4 Tier 11 Bountiful Delves for the Gilded Stash."]
end

local function FactionRenown(fac)
    local data = C_MajorFactions and C_MajorFactions.GetMajorFactionData and C_MajorFactions.GetMajorFactionData(fac.id)
    local name = (data and data.name and data.name ~= "") and data.name or fac.name
    return name, (data and data.renownLevel) or 0
end

local function OpenCompanion()
    if not C_AddOns.IsAddOnLoaded("Blizzard_DelvesCompanionConfiguration") then
        C_AddOns.LoadAddOn("Blizzard_DelvesCompanionConfiguration")
    end
    if DelvesCompanionConfigurationFrame then
        ToggleFrame(DelvesCompanionConfigurationFrame)
    else
        print(E.CC.header .. "Everything Delves|r: " .. L["Companion UI not available - visit Valeera at Delvers HQ."])
    end
end

local function FitText(fs, text, room)
    fs:SetWidth(0)
    fs:SetText(text)
    fs:SetWidth(math_max(1, math_min(math_ceil(fs:GetStringWidth() or 0) + 1, room)))
end

-- A card centers a control in its row but never sizes it, and a row frame left with no height came up blank
-- after a cold login
local function Row(content, height)
    local f = CreateFrame("Frame", nil, content)
    if height then f:SetHeight(height) end
    return f
end

local function Bar(ui, row, left, right)
    local bar = ui:CreateProgressBar(row)
    bar:SetPoint("LEFT", left, "RIGHT", ITEM_GAP, 0)
    bar:SetPoint("RIGHT", right, "LEFT", -ITEM_GAP, 0)
    return bar
end

local function BuildGrid(ui, content, v)
    local card = ui:CreateGroup(content, nil)
    local grid = Row(content)
    local row = card:Add(grid, { height = GRID_ROW * 4, fill = true })
    grid:ClearAllPoints()
    grid:SetPoint("TOPLEFT", row, "TOPLEFT")
    grid:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT")
    for r, text in ipairs({ L["Tier"], L["Rec. Gear iLvl"], L["Bountiful Loot"], L["Great Vault"] }) do
        local fs = ui:CreateText(grid, text, r == 1 and "groupLabel" or "label")
        fs:SetPoint("LEFT", grid, "TOPLEFT", GRID_SIDE, -(r - 0.5) * GRID_ROW)
        fs:SetWidth(GRID_LABEL - GRID_SIDE - 4)
        fs:SetWordWrap(false)
        if r < 4 then
            local line = Row(grid)
            line:SetPoint("TOPLEFT", grid, "TOPLEFT", 0, -(r - 1) * GRID_ROW)
            line:SetPoint("TOPRIGHT", grid, "TOPRIGHT", 0, -(r - 1) * GRID_ROW)
            line:SetHeight(GRID_ROW)
            ui:Paint(line, nil, "divider", "B")
        end
    end
    v.cells = {}
    for i in ipairs(E.TierData) do
        local c = {}
        c.tint = grid:CreateTexture(nil, "BACKGROUND")
        c.tint:SetColorTexture(ui:Color("accentSoft"))
        c.head = ui:CreateText(grid, "", "groupLabel")
        c.gear = ui:CreateText(grid, "", "label")
        c.loot = ui:CreateText(grid, "", "label")
        c.vault = ui:CreateText(grid, "", "label")
        c.hit = CreateFrame("Frame", nil, grid)
        c.hit:EnableMouse(true)
        c.hit:SetScript("OnEnter", function(self)
            local td = E.TierData[i]
            if td then ui:ShowTooltip(self, L["Tier %d"]:format(td.tier), TierTip(td)) end
        end)
        c.hit:SetScript("OnLeave", function() ui:HideTooltip() end)
        v.cells[i] = c
    end
    local venom = Row(content, ROW)
    venom.icon = venom:CreateTexture(nil, "ARTWORK")
    venom.icon:SetSize(VENOM_ICON, VENOM_ICON)
    venom.icon:SetPoint("LEFT")
    venom.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    venom.name = ui:CreateText(venom, "", "value")
    venom.name:SetPoint("LEFT", venom.icon, "RIGHT", ITEM_GAP, 0)
    venom.count = ui:CreateText(venom, "", "value")
    venom.count:SetPoint("RIGHT")
    venom:EnableMouse(true)
    venom:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetItemByID(E.Labyrinth.venomstoneItem)
        GameTooltip:Show()
    end)
    venom:SetScript("OnLeave", function() GameTooltip:Hide() end)
    card:Add(venom, { height = ROW, fill = true })
    v.grid, v.gridCard, v.venom = grid, card, venom
    return card
end

-- The item's description is the game's own tooltip, so the row reads only its name and count
local function RenderVenomstone(v)
    local id = E.Labyrinth.venomstoneItem
    local name = C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(id)
    if not name and C_Item and C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(id) end
    v.venom.icon:SetTexture(C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(id))
    v.venom.name:SetText(name or "Ascendant Venomstone")
    v.venom.count:SetText(tostring(C_Item and C_Item.GetItemCount and C_Item.GetItemCount(id, true) or 0))
end

-- Opening a delve entrance can move recGear, so the grid is filled on every render
local function RenderGrid(ui, v, width, recTier)
    local colW = (width - GRID_LABEL) / math_max(1, #E.TierData)
    for i, td in ipairs(E.TierData) do
        local c = v.cells[i]
        local x = GRID_LABEL + (i - 1) * colW
        local rec = td.tier == recTier
        c.tint:ClearAllPoints()
        c.tint:SetPoint("TOPLEFT", v.grid, "TOPLEFT", x, 0)
        c.tint:SetSize(colW, GRID_ROW * 4)
        c.tint:SetShown(rec)
        c.head:SetText("T" .. td.tier)
        c.head:SetTextColor(ui:Color(rec and "text" or "muted"))
        c.gear:SetText(tostring(td.recGear))
        local _, lootCC = E:GetLootTrack(td.bountifulLoot, td.bountifulTrack)
        local _, vaultCC = E:GetLootTrack(td.greatVault, td.vaultTrack)
        c.loot:SetText(lootCC .. td.bountifulLoot .. "|r")
        c.vault:SetText(vaultCC .. td.greatVault .. "|r")
        for r, fs in ipairs({ c.head, c.gear, c.loot, c.vault }) do
            fs:ClearAllPoints()
            fs:SetPoint("CENTER", v.grid, "TOPLEFT", x + colW / 2, -(r - 0.5) * GRID_ROW)
        end
        c.hit:ClearAllPoints()
        c.hit:SetPoint("TOPLEFT", v.grid, "TOPLEFT", x, 0)
        c.hit:SetSize(colW, GRID_ROW)
    end
end

local function BuildVault(ui, content, v)
    -- No PvP row: World Content replaced the Great Vault PvP slot in TWW,
    -- so C_WeeklyRewards.GetActivities never returns a RankedPvP row.
    v.gvRows = {
        { type = Enum.WeeklyRewardChestThresholdType.Activities, label = L["Mythic+ Dungeons"] },
        { type = Enum.WeeklyRewardChestThresholdType.World,      label = L["Delves / World Content"] },
    }
    local card = ui:CreateGroup(content, L["Great Vault Progress"])
    v.vaultRows = {}
    for i, cfg in ipairs(v.gvRows) do
        local row = Row(content, ROW)
        row.label = ui:CreateText(row, cfg.label, "label")
        row.label:SetPoint("LEFT")
        row.label:SetWidth(VAULT_LABEL)
        row.label:SetWordWrap(true)
        row.summary = ui:CreateText(row, "", "hint")
        row.summary:SetPoint("RIGHT")
        row.summary:SetWidth(VAULT_SUMMARY)
        row.summary:SetJustifyH("RIGHT")
        row.summary:SetWordWrap(true)
        row.slots = {}
        for s = 1, 3 do
            local slot = CreateFrame("Frame", nil, row)
            slot:SetHeight(SLOT_H)
            ui:Paint(slot, "input", "inputBorder")
            slot.check = slot:CreateTexture(nil, "ARTWORK")
            slot.check:SetSize(CHECK, CHECK)
            slot.check:SetTexture(ui:Texture("check"))
            slot.check:SetVertexColor(ui:Color("label"))
            slot.text = ui:CreateText(slot, "", "label")
            slot:EnableMouse(true)
            slot:SetScript("OnEnter", function(self)
                if self.tipTitle then ui:ShowTooltip(self, self.tipTitle, self.tipBody) end
            end)
            slot:SetScript("OnLeave", function() ui:HideTooltip() end)
            row.slots[s] = slot
        end
        card:Add(row, { height = ROW, fill = true })
        v.vaultRows[i] = row
    end
    v.vaultLab = ui:CreateText(content,
        L["In the Labyrinth, every third chamber counts here, and so does your first Kindo'jan kill each week on Tier 8 or higher."], "hint")
    v.vaultLab:SetWordWrap(true)
    card:Add(v.vaultLab, { height = HINT_ROW, fill = true })
    v.vaultNote = ui:CreateText(content, "", "hint")
    v.vaultNote:SetWordWrap(true)
    card:Add(v.vaultNote, { height = HINT_ROW, fill = true })
    v.vaultMissing = ui:CreateText(content, L["Great Vault data not available yet - enter a dungeon, raid or delve first"], "hint")
    v.vaultMissing:SetWordWrap(true)
    card:Add(v.vaultMissing, { height = HINT_ROW, fill = true })
    v.vaultCard = card
    return card
end

local function FillSlot(ui, slot, s, data)
    slot:SetShown(data ~= nil)
    if not data then
        slot.tipTitle = nil
        return
    end
    slot.check:SetShown(data.unlocked)
    slot.text:ClearAllPoints()
    if data.unlocked then
        slot.text:SetText(data.ilvl and tostring(data.ilvl) or "--")
        slot.text:SetTextColor(ui:Color("text"))
        slot.text:SetPoint("CENTER", slot, "CENTER", (CHECK + 6) / 2, 0)
        slot.check:ClearAllPoints()
        slot.check:SetPoint("RIGHT", slot.text, "LEFT", -6, 0)
    else
        slot.text:SetText(data.prog .. " / " .. data.threshold)
        slot.text:SetTextColor(ui:Color("muted"))
        slot.text:SetPoint("CENTER")
    end
    slot.tipTitle = L["Reward Slot %d"]:format(s)
    local first = data.ilvl and L["Item level %d"]:format(data.ilvl) or L["No reward unlocked yet"]
    local second
    if data.unlocked then
        local left = WeeklyResetIn()
        second = L["Unlocked - claim after the weekly reset"] .. (left and (" (" .. left .. ")") or "") .. "."
    else
        second = L["%d / %d  (%d more)"]:format(data.prog, data.threshold, data.threshold - data.prog)
    end
    slot.tipBody = first .. "\n" .. second
end

local function RenderVault(ui, v, width)
    local state = VaultState(v.gvRows)
    v.vaultMissing:SetShown(state == nil)
    v.vaultNote:SetShown(state ~= nil)
    v.vaultLab:SetShown(state ~= nil and E.IsLabyrinthUnlocked())
    local slotsW = width - ui:Spacing("rowPadding") * 2 - VAULT_LABEL - VAULT_SUMMARY - ITEM_GAP * 2
    local slotW = math_max(20, (slotsW - SLOT_GAP * 2) / 3)
    for i, row in ipairs(v.vaultRows) do
        row:SetShown(state ~= nil)
        local rs = state and state[i]
        if rs then
            for s, slot in ipairs(row.slots) do
                slot:ClearAllPoints()
                slot:SetPoint("LEFT", row, "LEFT", VAULT_LABEL + ITEM_GAP + (s - 1) * (slotW + SLOT_GAP), 0)
                slot:SetWidth(slotW)
                FillSlot(ui, slot, s, rs.slots[s])
            end
            if rs.empty then
                row.summary:SetText("")
            elseif rs.nextRemaining then
                row.summary:SetText(L["Next slot in %d more"]:format(rs.nextRemaining))
            else
                row.summary:SetText(L["All slots unlocked"])
            end
        end
    end
    if state then
        local left = WeeklyResetIn()
        v.vaultNote:SetText(L["Rewards are claimable after the weekly reset"] .. (left and (" (" .. left .. ")") or ""))
    end
    v.vaultCard:Layout()
end

local function BuildMiles(ui, content)
    local miles = Row(content, MILE_ROW)
    miles.hint = ui:CreateText(miles, L["Each level unlocks a milestone reward - hover an icon to see it."], "hint")
    miles.hint:SetPoint("TOPLEFT", 0, -10)
    miles.hint:SetPoint("TOPRIGHT", 0, -10)
    miles.hint:SetWordWrap(false)
    miles.nodes = {}
    for i = 1, MILE_POOL do
        local n = CreateFrame("Frame", nil, miles)
        n:SetSize(MILE, MILE)
        n:SetPoint("TOPLEFT", miles, "TOPLEFT", (i - 1) * (MILE + MILE_GAP), -MILE_TOP)
        n.tex = n:CreateTexture(nil, "ARTWORK")
        n.tex:SetAllPoints()
        n.tex:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        n.ring = CreateFrame("Frame", nil, n)
        n.ring:SetPoint("TOPLEFT", -1, 1)
        n.ring:SetPoint("BOTTOMRIGHT", 1, -1)
        ui:Paint(n.ring, nil, "accentHi")
        n.level = ui:CreateText(miles, "", "hint")
        n.level:SetPoint("TOP", n, "BOTTOM", 0, -4)
        n:EnableMouse(true)
        n:SetScript("OnEnter", function(self)
            if self.tipTitle then ui:ShowTooltip(self, self.tipTitle, self.tipBody) end
        end)
        n:SetScript("OnLeave", function() ui:HideTooltip() end)
        miles.nodes[i] = n
    end
    return miles
end

local function BuildJourney(ui, content, v)
    local card = ui:CreateGroup(content, L["Delver's Journey"])
    ui:AttachTooltip(card.label, L["Delver's Journey"], L["Your progress through this season's Delves track."])

    local level = Row(content, ROW)
    level.text = ui:CreateText(level, "", "value")
    level.text:SetPoint("LEFT")
    level.value = ui:CreateText(level, "", "value")
    level.value:SetPoint("RIGHT")
    level.bar = Bar(ui, level, level.text, level.value)
    card:Add(level, { height = ROW, fill = true })
    v.journeyLevel = level

    v.journeyMissing = ui:CreateText(content,
        L["Delver's Journey data not available yet - open the Journeys panel once to sync."], "hint")
    v.journeyMissing:SetWordWrap(true)
    card:Add(v.journeyMissing, { height = HINT_ROW, fill = true })

    local miles = BuildMiles(ui, content)
    card:Add(miles, { height = MILE_ROW, fill = true })
    v.journeyMiles = miles

    local comp = Row(content, ROW)
    comp.portrait = comp:CreateTexture(nil, "ARTWORK")
    comp.portrait:SetSize(PORTRAIT, PORTRAIT)
    comp.portrait:SetTexture(VALEERA_ICON)
    if comp.portrait.SetMask then
        pcall(comp.portrait.SetMask, comp.portrait, PORTRAIT_MASK)
    end
    comp.portrait:SetPoint("LEFT")
    comp.name = ui:CreateText(comp, "", "value")
    comp.name:SetPoint("LEFT", comp.portrait, "RIGHT", ITEM_GAP, 0)
    comp.level = ui:CreateText(comp, "", "label")
    comp.level:SetPoint("LEFT", comp.name, "RIGHT", ITEM_GAP, 0)
    comp.button = ui:CreateButton(comp, "Valeera - " .. L["Companion"], nil, OpenCompanion,
        L["Open Valeera's companion menu to manage her role and curios."])
    comp.button:SetPoint("RIGHT")
    comp.bar = Bar(ui, comp, comp.level, comp.button)
    card:Add(comp, { height = ROW, fill = true })
    v.companion = comp
    v.journeyCard = card
    return card
end

local function RenderMilestones(ui, miles, factionID, level, maxed)
    -- A track longer than the pool shows its last levels
    local maxLevel  = GetJourneyMaxLevel(factionID)
    local topLevel  = maxLevel or (maxed and level) or (level + 1)
    if topLevel < 1 then topLevel = 1 end
    local startLevel = 1
    if topLevel - startLevel + 1 > MILE_POOL then
        startLevel = topLevel - MILE_POOL + 1
    end

    local shown = 0
    for i, n in ipairs(miles.nodes) do
        local nodeLevel = startLevel + (i - 1)
        local icon, rewardName
        if nodeLevel <= topLevel then
            icon, rewardName = GetJourneyNodeIcon(factionID, nodeLevel)
        end
        n:SetShown(icon ~= nil)
        n.level:SetShown(icon ~= nil)
        if icon then
            local earned, current = nodeLevel <= level, nodeLevel == level
            n.tex:SetTexture(icon)
            n.tex:SetDesaturated(not earned)
            n.tex:SetAlpha(earned and 1 or LOCKED_ALPHA)
            n.ring:SetShown(current)
            n.level:SetText(tostring(nodeLevel))
            n.level:SetTextColor(ui:Color(current and "text" or "muted"))
            n.tipTitle = L["Level %d"]:format(nodeLevel) .. "  " .. (earned and L["(earned)"] or L["(locked)"])
            n.tipBody = rewardName
            shown = shown + 1
        end
    end
    return shown
end

local function RenderCompanion(ui, comp)
    comp.button:Fit()
    local data = E.GetCompanionData and E:GetCompanionData()
    if not data then
        comp.name:SetText(L["Companion level unavailable."])
        comp.name:SetTextColor(ui:Color("muted"))
        comp.level:SetText("")
        comp.bar:Hide()
        return
    end
    comp.name:SetText(data.name)
    comp.name:SetTextColor(ui:Color("text"))
    if data.isMaxLevel then
        comp.level:SetText(L["Level %d - Max"]:format(data.level))
        comp.bar:Hide()
    else
        comp.level:SetText(L["Level %d"]:format(data.level))
        comp.bar:SetProgress(data.xpMax > 0 and data.xpCurrent / data.xpMax or 0)
        comp.bar:Show()
    end
end

local function RenderJourney(ui, v)
    local level, cur, threshold, factionID, ok = GetDelverJourney()
    v.journeyMissing:SetShown(not ok)
    v.journeyLevel:SetShown(ok)
    if ok then
        local maxed = IsJourneyMaxed(factionID)
        v.journeyLevel.text:SetText(L["Level %d"]:format(level))
        -- At max renown renownReputationEarned = 0, so the bar is forced full.
        if maxed then
            v.journeyLevel.value:SetText(L["Complete - all milestones earned!"])
            v.journeyLevel.bar:SetProgress(1)
        else
            v.journeyLevel.value:SetText(cur .. " / " .. threshold)
            v.journeyLevel.bar:SetProgress(threshold > 0 and cur / threshold or 0)
        end
        v.journeyMiles:SetShown(RenderMilestones(ui, v.journeyMiles, factionID, level, maxed) > 0)
    else
        v.journeyMiles:Hide()
    end
    RenderCompanion(ui, v.companion)
    v.journeyCard:Layout()
end

local function BuildLabJourney(ui, content, v)
    local card = ui:CreateGroup(content, " ")
    local level = Row(content, ROW)
    level.text = ui:CreateText(level, "", "value")
    level.text:SetPoint("LEFT")
    level.value = ui:CreateText(level, "", "value")
    level.value:SetPoint("RIGHT")
    level.bar = Bar(ui, level, level.text, level.value)
    card:Add(level, { height = ROW, fill = true })
    local miles = BuildMiles(ui, content)
    card:Add(miles, { height = MILE_ROW, fill = true })
    v.labLevel, v.labMiles, v.labCard = level, miles, card
    return card
end

-- A card does not own its rows, so they are hidden by hand
local function RenderLabJourney(ui, v)
    local j = E.IsLabyrinthUnlocked() and E.GetLabyrinthJourney()
    local shown = j and true or false
    v.labCard:SetShown(shown)
    v.labLevel:SetShown(shown)
    if not j then
        v.labMiles:Hide()
        return
    end
    v.labCard.label:SetText(E.LabyrinthJourneyName())
    local maxed = IsJourneyMaxed(j.factionID)
    v.labLevel.text:SetText(L["Level %d"]:format(j.level))
    if maxed then
        v.labLevel.value:SetText(L["Complete - all milestones earned!"])
        v.labLevel.bar:SetProgress(1)
    else
        v.labLevel.value:SetText(j.cur .. " / " .. j.threshold)
        v.labLevel.bar:SetProgress(j.threshold > 0 and j.cur / j.threshold or 0)
    end
    v.labMiles:SetShown(RenderMilestones(ui, v.labMiles, j.factionID, j.level, maxed) > 0)
    v.labCard:Layout()
end

local function BuildWahdu(ui, content, v)
    local w = {}
    local card = ui:CreateGroup(content, L["Wah'du"])
    w.side = ui:CreateText(card, L["Three fragments buy a Myth 2/6 piece of your choice."], "hint")
    w.side:SetPoint("BOTTOMLEFT", card.label, "BOTTOMRIGHT", ITEM_GAP, 0)
    w.side:SetPoint("RIGHT", card, "RIGHT")
    w.side:SetWordWrap(false)

    local steps = Row(content, STEP_ROW)
    steps.label = ui:CreateText(steps, L["Weekly steps"], "label")
    steps.label:SetPoint("LEFT")
    steps.label:SetWordWrap(false)
    steps.value = ui:CreateText(steps, "", "value")
    steps.value:SetPoint("RIGHT")
    steps.value:SetWidth(STEP_VALUE)
    steps.value:SetJustifyH("RIGHT")
    steps.boxes = {}
    for i = 1, #E.Labyrinth.wahduQuests do
        local box = CreateFrame("Frame", nil, steps)
        box:SetHeight(STEP_BOX)
        box.fill, box.edge = ui:Paint(box, "input", "inputBorder")
        box.check = box:CreateTexture(nil, "ARTWORK")
        box.check:SetSize(STEP_CHECK, STEP_CHECK)
        box.check:SetTexture(ui:Texture("check"))
        box.check:SetVertexColor(ui:Color("label"))
        box.text = ui:CreateText(box, tostring(i), "label")
        box:EnableMouse(true)
        box:SetScript("OnEnter", function(self)
            if self.tipTitle then ui:ShowTooltip(self, self.tipTitle, self.tipBody) end
        end)
        box:SetScript("OnLeave", function() ui:HideTooltip() end)
        steps.boxes[i] = box
    end
    card:Add(steps, { height = STEP_ROW, fill = true })

    w.hints = ui:CreateTextBlock(content)
    w.hintLine = w.hints:AddLine("", "hint")
    card:Add(w.hints, { fitHeight = true })

    local frag = Row(content, ROW)
    frag.icon = frag:CreateTexture(nil, "ARTWORK")
    frag.icon:SetSize(FRAG_ICON, FRAG_ICON)
    frag.icon:SetPoint("LEFT")
    frag.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    frag.name = ui:CreateText(frag, "", "label")
    frag.name:SetPoint("LEFT", frag.icon, "RIGHT", ITEM_GAP, 0)
    frag.name:SetWordWrap(false)
    frag.value = ui:CreateText(frag, "", "value")
    frag.value:SetPoint("RIGHT")
    frag.bar = Bar(ui, frag, frag.name, frag.value)
    frag:EnableMouse(true)
    frag:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetItemByID(E.Labyrinth.wahduFragment)
        GameTooltip:Show()
    end)
    frag:SetScript("OnLeave", function() GameTooltip:Hide() end)
    card:Add(frag, { height = ROW, fill = true })

    w.fragHint = ui:CreateTextBlock(content)
    w.fragHintLine = w.fragHint:AddLine("", "hint")
    card:Add(w.fragHint, { fitHeight = true })

    local pieces = Row(content, ROW)
    pieces.label = ui:CreateText(pieces, L["Myth pieces claimed"], "label")
    pieces.label:SetPoint("LEFT")
    pieces.value = ui:CreateText(pieces, "", "value")
    pieces.value:SetPoint("RIGHT")
    card:Add(pieces, { height = ROW, fill = true })

    w.card, w.steps, w.frag, w.pieces = card, steps, frag, pieces
    v.wahdu = w
    return card
end

local function StepState(st, i)
    if i <= st.done then return "done" end
    if i == st.step and (st.inLog or st.ready ~= 0) then return "cur" end
    if st.unlocked and i <= st.unlocked then return "ready" end
    return "lock"
end

local STEP_LOOK = {
    done  = { fill = "input",      edge = "inputBorder", text = "text" },
    cur   = { fill = "accentSoft", edge = "accentHi",    text = "text" },
    ready = { fill = "input",      edge = "accentHi",    text = "text" },
    lock  = { fill = "input",      edge = "inputBorder", text = "muted" },
}

local function StepTip(st, state)
    if state == "done" then return L["Turned in"] end
    if state == "cur" and st.inLog then return L["In your quest log"] end
    if state == "lock" then return L["Unlocks with a later weekly reset"] end
    return L["Ready to take"]
end

local function WahduHints(st)
    if st.done >= st.total then return L["All six steps are done on this character."] end
    local out = {}
    if st.inLog and st.complete then
        out[#out + 1] = L["Next: %s is done. Turn it in to %s at the Labyrinth's entrance."]
            :format(E.WahduStepName(st.step), L["Wah'du"])
    elseif st.inLog then
        out[#out + 1] = L["Next: %s, in your quest log. Clear it on Tier 8 or higher and turn it in."]
            :format(E.WahduStepName(st.step))
    elseif st.ready ~= 0 then
        out[#out + 1] = L["Next: %s. Talk to %s at the Labyrinth's entrance to take it."]
            :format(E.WahduStepName(st.step), L["Wah'du"])
    end
    -- The step in the log is among the ready ones, but only the rest wait at the entrance
    local waiting = (st.ready or 0) - (st.inLog and 1 or 0)
    if waiting > 0 then
        out[#out + 1] = L["Ready now: %d. %s gives you the next step each time you turn one in."]
            :format(waiting, L["Wah'du"])
    end
    local left = st.unlocked and st.unlocked < st.total and WeeklyResetIn()
    if left then
        out[#out + 1] = L["Step %d unlocks with the weekly reset in %s."]:format(st.unlocked + 1, left)
    end
    return table_concat(out, "\n")
end

local function RenderSteps(ui, steps, st, width)
    steps.value:SetText(st.done .. " / " .. (st.unlocked or st.total))
    local n = #steps.boxes
    local room = width - ui:Spacing("rowPadding") * 2 - math_ceil(steps.label:GetStringWidth() or 0)
        - STEP_VALUE - ITEM_GAP * 2
    local boxW = math_max(STEP_BOX, (room - STEP_GAP * (n - 1)) / n)
    for i, box in ipairs(steps.boxes) do
        local state = StepState(st, i)
        local look = STEP_LOOK[state]
        box:ClearAllPoints()
        box:SetPoint("LEFT", steps.label, "RIGHT", ITEM_GAP + (i - 1) * (boxW + STEP_GAP), 0)
        box:SetWidth(boxW)
        box:SetAlpha(state == "lock" and LOCKED_STEP_ALPHA or 1)
        box.fill:SetColorTexture(ui:Color(look.fill))
        for _, line in ipairs(box.edge) do line:SetColorTexture(ui:Color(look.edge)) end
        box.text:SetTextColor(ui:Color(look.text))
        box.text:ClearAllPoints()
        box.check:SetShown(state == "done")
        if state == "done" then
            box.text:SetPoint("CENTER", box, "CENTER", (STEP_CHECK + STEP_GAP) / 2, 0)
            box.check:ClearAllPoints()
            box.check:SetPoint("RIGHT", box.text, "LEFT", -STEP_GAP, 0)
        else
            box.text:SetPoint("CENTER")
        end
        box.tipTitle = i .. ". " .. E.WahduStepName(i)
        box.tipBody = StepTip(st, state)
    end
end

local function RenderWahdu(ui, v, width)
    local w = v.wahdu
    local st = E.IsLabyrinthUnlocked() and E.WahduStatus()
    local shown = st and true or false
    for _, f in ipairs({ w.card, w.steps, w.hints, w.frag, w.pieces }) do f:SetShown(shown) end
    if not st then
        w.fragHint:Hide()
        return
    end
    RenderSteps(ui, w.steps, st, width)
    w.hintLine:SetText(WahduHints(st))

    local LAB, cost = E.Labyrinth, E.Labyrinth.wahduPieceCost
    local name = C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(LAB.wahduFragment)
    if not name and C_Item and C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(LAB.wahduFragment) end
    w.frag.icon:SetTexture(C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(LAB.wahduFragment))
    w.frag.name:SetText(name or "Mythical Soul Fragment")
    local held = math_min(st.fragments, cost)
    w.frag.value:SetText(held .. " / " .. cost)
    w.frag.bar:SetProgress(held / cost)
    local hint
    if st.fragments >= cost then
        hint = L["You have enough for a Myth piece. Trade them to %s at the Labyrinth's entrance."]:format(L["Wah'du"])
    elseif st.done < st.total then
        hint = L["%d more for a Myth piece. Counted in your bags and bank."]:format(cost - st.fragments)
    end
    w.fragHint:SetShown(hint ~= nil)
    w.fragHintLine:SetText(hint or "")
    w.pieces.value:SetText(st.pieces .. " / " .. st.maxPieces)
    w.card:Layout()
end

local function BuildTrove(ui, content, v)
    local card = ui:CreateGroup(content, L["Trovehunter's Bounty"])
    local row = Row(content, TROVE_ROW)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(TROVE_ICON_SIZE, TROVE_ICON_SIZE)
    row.icon:SetTexture(TROVE_ICON)
    row.icon:SetPoint("LEFT")
    row.check = row:CreateTexture(nil, "ARTWORK")
    row.check:SetSize(CHECK, CHECK)
    row.check:SetTexture(ui:Texture("check"))
    row.check:SetVertexColor(ui:Color("label"))
    row.check:SetPoint("LEFT", row.icon, "RIGHT", ITEM_GAP, 0)
    row.status = ui:CreateText(row, "", "label")
    row.status:SetWordWrap(false)
    row.detail = ui:CreateText(row, "", "hint")
    row.detail:SetWordWrap(false)
    card:Add(row, { height = TROVE_ROW, fill = true })
    v.trove, v.troveCard = row, card
    return card
end

local function RenderTrove(ui, v)
    local row = v.trove
    local status, detail, done = TroveText()
    row.status:SetText(status)
    row.status:SetTextColor(ui:Color(done and "muted" or "label"))
    row.check:SetShown(done and true or false)
    row.status:ClearAllPoints()
    row.status:SetPoint("LEFT", row.icon, "RIGHT", ITEM_GAP + (done and CHECK + 6 or 0), detail and 8 or 0)
    row.status:SetPoint("RIGHT", row, "RIGHT", 0, detail and 8 or 0)
    row.detail:SetShown(detail ~= nil)
    row.detail:SetText(detail or "")
    row.detail:ClearAllPoints()
    row.detail:SetPoint("LEFT", row.icon, "RIGHT", ITEM_GAP, -9)
    row.detail:SetPoint("RIGHT", row, "RIGHT", 0, -9)
    v.troveCard:Layout()
end

local function BuildGilded(ui, content, v)
    local card = ui:CreateGroup(content, L["Gilded Stash Progress"])
    ui:AttachTooltip(card.label, L["Gilded Stash"],
        L["Complete 4 Tier 11 Bountiful Delves this week\nto earn a Gilded Stash reward."])
    local row = Row(content, ROW)
    row.check = row:CreateTexture(nil, "ARTWORK")
    row.check:SetSize(CHECK, CHECK)
    row.check:SetTexture(ui:Texture("check"))
    row.check:SetVertexColor(ui:Color("label"))
    row.check:SetPoint("LEFT")
    row.status = ui:CreateText(row, "", "label")
    row.status:SetPoint("LEFT")
    row.status:SetWordWrap(false)
    row.value = ui:CreateText(row, "", "value")
    row.value:SetPoint("RIGHT")
    row.bar = Bar(ui, row, row.status, row.value)
    card:Add(row, { height = ROW, fill = true })
    v.gildedNote = ui:CreateText(content, "", "hint")
    v.gildedNote:SetWordWrap(true)
    card:Add(v.gildedNote, { height = HINT_ROW, fill = true })
    v.gildedLab = ui:CreateText(content, L["A Tier 11 Labyrinth run counts once for every third chamber."], "hint")
    v.gildedLab:SetWordWrap(true)
    card:Add(v.gildedLab, { height = HINT_ROW, fill = true })
    v.gilded, v.gildedCard = row, card
    return card
end

local function RenderGilded(ui, v, width)
    local progress, maxCount, fromLive = GildedState()
    local status, note = GildedText(progress, maxCount, fromLive)
    local row = v.gilded
    local done = progress >= maxCount
    local x = done and (CHECK + 6) or 0
    row.check:SetShown(done)
    row.status:ClearAllPoints()
    row.status:SetPoint("LEFT", row, "LEFT", x, 0)
    row.value:SetText(progress .. " / " .. maxCount)
    local room = width - ui:Spacing("rowPadding") * 2 - (row.value:GetStringWidth() or 0) - ITEM_GAP * 2 - BAR_MIN - x
    FitText(row.status, status, room)
    row.bar:SetProgress(maxCount > 0 and progress / maxCount or 0)
    v.gildedNote:SetText(note)
    v.gildedLab:SetShown(E.IsLabyrinthUnlocked())
    v.gildedCard:Layout()
end

local function BuildRenown(ui, content, v)
    local card = ui:CreateGroup(content, L["Midnight Faction Renown"])
    v.renownRows = {}
    for i in ipairs(MIDNIGHT_FACTIONS) do
        local row = Row(content, ROW)
        row.name = ui:CreateText(row, "", "label")
        row.name:SetPoint("LEFT")
        row.name:SetWidth(RENOWN_NAME)
        row.name:SetWordWrap(false)
        row.status = ui:CreateText(row, "", "value")
        row.status:SetPoint("RIGHT")
        row.status:SetWidth(RENOWN_STATUS)
        row.status:SetJustifyH("RIGHT")
        row.check = row:CreateTexture(nil, "ARTWORK")
        row.check:SetSize(CHECK, CHECK)
        row.check:SetTexture(ui:Texture("check"))
        row.check:SetVertexColor(ui:Color("label"))
        row.bar = Bar(ui, row, row.name, row.status)
        card:Add(row, { height = ROW, fill = true })
        v.renownRows[i] = row
    end
    v.renownCard = card
    return card
end

local function RenownCap(factionID)
    return GetJourneyMaxLevel(factionID) or FACTION_RENOWN_MAX
end

local function RenderRenown(ui, v)
    for i, fac in ipairs(MIDNIGHT_FACTIONS) do
        local row = v.renownRows[i]
        local name, renown = FactionRenown(fac)
        local cap = RenownCap(fac.id)
        -- The game's maxed flag wins, as the level list may hold levels not open yet
        if renown > 0 and IsJourneyMaxed(fac.id) then cap = renown end
        row.name:SetText(name)
        row.bar:SetProgress(math_min(1, renown / cap))
        local maxed = renown >= cap
        if maxed then
            row.status:SetText(L["Max (%d / %d)"]:format(renown, cap))
        else
            row.status:SetText(renown .. " / " .. cap)
        end
        row.status:SetTextColor(ui:Color(renown > 0 and "text" or "muted"))
        row.check:SetShown(maxed)
        row.check:ClearAllPoints()
        row.check:SetPoint("RIGHT", row.status, "RIGHT", -(math_ceil(row.status:GetStringWidth() or 0) + 6), 0)
    end
end

E:RegisterModule(function()
    local ui = E.ui
    local frame = CreateFrame("Frame", "EverythingDelvesTab3Content")
    local area = ui:CreateScrollArea(frame, { clearGrip = true })
    area:SetAllPoints(frame)
    local content = area.content

    local v = {}
    local summary = ui:CreateText(content, "", "label")
    summary:SetWordWrap(false)
    local hint = ui:CreateText(content, "", "hint")
    hint:SetWordWrap(false)
    v.cards = {
        BuildGrid(ui, content, v), BuildVault(ui, content, v), BuildJourney(ui, content, v),
        BuildLabJourney(ui, content, v), BuildWahdu(ui, content, v), BuildTrove(ui, content, v),
        BuildGilded(ui, content, v), BuildRenown(ui, content, v),
    }

    local lastWidth = 0
    local function ViewWidth()
        local w = area.scroll:GetWidth() or 0
        if w <= 0 then w = (frame:GetWidth() or 0) - 10 end
        return math_max(1, w)
    end

    local function Render()
        local width = ViewWidth()
        lastWidth = width
        content:SetWidth(width)
        local inner = width - PAD_LEFT - PAD_RIGHT

        local ilvl = E.PlayerItemLevel()
        local recTier = E.RecommendedTier(ilvl)
        summary:ClearAllPoints()
        summary:SetPoint("LEFT", content, "TOPLEFT", PAD_LEFT, -(PAD_TOP + BAR_H / 2))
        summary:SetPoint("RIGHT", content, "TOPRIGHT", -PAD_RIGHT, -(PAD_TOP + BAR_H / 2))
        summary:SetText(E.DelveList.cc("muted") .. L["Your Equipped iLvl:"] .. "|r " .. E.DelveList.cc("text") .. ilvl .. "|r")
        local y = PAD_TOP + BAR_H + HINT_GAP
        hint:ClearAllPoints()
        hint:SetPoint("TOPLEFT", content, "TOPLEFT", PAD_LEFT, -y)
        hint:SetPoint("RIGHT", content, "RIGHT", -PAD_RIGHT, 0)
        hint:SetText(L["Recommended Tier: %s - running this tier gives you the best gear upgrade chance"]:format("T" .. recTier))
        y = y + HINT_H + CARDS_GAP

        RenderGrid(ui, v, inner, recTier)
        RenderVenomstone(v)
        RenderVault(ui, v, inner)
        RenderJourney(ui, v)
        RenderLabJourney(ui, v)
        RenderWahdu(ui, v, inner)
        RenderTrove(ui, v)
        RenderGilded(ui, v, inner)
        RenderRenown(ui, v)
        local first = true
        for _, card in ipairs(v.cards) do
            if card:IsShown() then
                if not first then y = y + GROUP_GAP end
                first = false
                card:ClearAllPoints()
                card:SetPoint("TOPLEFT", content, "TOPLEFT", PAD_LEFT, -y)
                card:SetPoint("TOPRIGHT", content, "TOPRIGHT", -PAD_RIGHT, -y)
                y = y + card:GetHeight()
            end
        end
        area:SetContentSize(width, y + PAD_BOTTOM)
    end

    local function RenderIfShown()
        if frame:IsVisible() then Render() end
    end

    -- Wrapped text measured before its first draw can come up short, so the page is measured again a frame later
    local pending = false
    local function RenderSoon()
        if pending then return end
        pending = true
        C_Timer.After(0, function()
            pending = false
            RenderIfShown()
        end)
    end

    area.scroll:HookScript("OnSizeChanged", function(_, w)
        if frame:IsVisible() and math_abs((w or 0) - lastWidth) >= 1 then
            Render()
            RenderSoon()
        end
    end)

    -- Item names and quest titles can reach the client after the page is drawn
    local LAB = E.Labyrinth
    local wahduQuest = {}
    for _, q in ipairs(LAB.wahduQuests) do wahduQuest[q] = true end
    local itemWatch = CreateFrame("Frame")
    itemWatch:SetScript("OnEvent", function(_, event, id, success)
        if success == false then return end
        if event == "QUEST_DATA_LOAD_RESULT" then
            if wahduQuest[id] then RenderIfShown() end
        elseif id == LAB.venomstoneItem or id == LAB.wahduFragment then
            RenderIfShown()
        end
    end)

    -- UNIT_AURA fires constantly in combat, so only a change in the buff redraws
    local troveUp
    local auraWatch = CreateFrame("Frame")
    auraWatch:SetScript("OnEvent", function()
        local up = E:GetTrovehunterAura() ~= nil
        if up ~= troveUp then
            troveUp = up
            RenderIfShown()
        end
    end)

    frame:SetScript("OnShow", function()
        itemWatch:RegisterEvent("GET_ITEM_INFO_RECEIVED")
        itemWatch:RegisterEvent("QUEST_DATA_LOAD_RESULT")
        E.RequestWahduTitles()
        troveUp = E:GetTrovehunterAura() ~= nil
        auraWatch:RegisterUnitEvent("UNIT_AURA", "player")
        Render()
        area:ScrollTo(0, 0)
        RenderSoon()
    end)
    frame:SetScript("OnHide", function()
        itemWatch:UnregisterEvent("GET_ITEM_INFO_RECEIVED")
        itemWatch:UnregisterEvent("QUEST_DATA_LOAD_RESULT")
        auraWatch:UnregisterEvent("UNIT_AURA")
    end)

    E:RegisterCallback("InventoryChanged", RenderIfShown)
    E:RegisterCallback("BagUpdate", RenderIfShown)
    E:RegisterCallback("TierDataChanged", RenderIfShown)
    -- Companion XP and Journey renown both tick up during delves.
    E:RegisterCallback("QuestLogUpdate", RenderIfShown)
    -- Gilded Stash / Great Vault / Renown update from their own events, not the
    -- quest/inventory ticks above, so an open tab would otherwise go stale.
    E:RegisterCallback("GildedStashChanged", RenderIfShown)
    local liveEvents = CreateFrame("Frame")
    for _, ev in ipairs({ "WEEKLY_REWARDS_UPDATE", "MAJOR_FACTION_RENOWN_LEVEL_CHANGED", "UPDATE_FACTION" }) do
        pcall(liveEvents.RegisterEvent, liveEvents, ev)
    end
    liveEvents:SetScript("OnEvent", RenderIfShown)

    E:RegisterTab(3, frame)
end)
