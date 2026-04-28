------------------------------------------------------------------------
-- UI/TabCurrentBountiful.lua - Tab 2: Current Bountiful Delves
-- Tracks the player's live bountiful delve status for the week:
-- currency stats, weekly reset timer, quick-action buttons, and a
-- scrollable list of this week's bountiful delves.
------------------------------------------------------------------------
local E = EverythingDelves

------------------------------------------------------------------------
-- Local references for frequently accessed globals
------------------------------------------------------------------------
local pairs, ipairs = pairs, ipairs
local math_floor, math_max = math.floor, math.max
local string_format = string.format
local table_insert, table_sort, wipe = table.insert, table.sort, wipe
local strtrim = strtrim

------------------------------------------------------------------------
-- Load-on-demand helper
-- Several Blizzard UI frames live inside load-on-demand addons that
-- aren't in memory until the player opens them for the first time.
-- ElvUI preloads them, masking the issue. We force-load here.
------------------------------------------------------------------------
local function EnsureBlizzardAddon(addonName)
    ---@diagnostic disable-next-line: undefined-global
    local loader = (C_AddOns and C_AddOns.LoadAddOn) or LoadAddOn
    if not loader then return false end
    local ok, loaded = pcall(loader, addonName)
    return ok and (loaded ~= false)
end

------------------------------------------------------------------------
-- Local state
------------------------------------------------------------------------
local ROW_HEIGHT     = 36   -- taller rows to fit story variant sub-text
local VISIBLE_ROWS   = 10
local rows           = {}
local bountifulList  = {}   -- current week's bountiful delves (reused)
-- Bountiful count is derived dynamically from #bountifulList (no hardcoded constant)

-- Entry pool: recycled delve entry tables to avoid allocating 6-8
-- fresh tables every time the bountiful list is rebuilt (on OnShow,
-- area POI updates, and refresh button clicks).
local bountifulEntryPool = {}

local function AcquireBountifulEntry()
    local n = #bountifulEntryPool
    if n == 0 then return {} end
    local e = bountifulEntryPool[n]
    bountifulEntryPool[n] = nil
    return e
end

local function ReleaseBountifulList(list)
    for i = #list, 1, -1 do
        local e = list[i]
        list[i] = nil
        wipe(e)
        bountifulEntryPool[#bountifulEntryPool + 1] = e
    end
end

------------------------------------------------------------------------
-- Bountiful delve live detection
-- Uses C_AreaPoiInfo.GetAreaPOIInfo() to check each known delve's POI.
-- If atlasName == "delves-bountiful", the delve is bountiful this week.
-- Also detects "overcharged" bountiful via iconWidgetSet widget count.
-- Populates `out` in place (reusing entries from the pool) so this
-- function allocates nothing on the steady path.
------------------------------------------------------------------------

-- C_UIWidgetManager.GetAllWidgetsBySetID() returns a fresh table on
-- every call. AREA_POIS_UPDATED fires several times during zone
-- transitions, and each fire calls this twice per bountiful POI
-- (icon set + tooltip set). Cache the results with a short TTL so
-- bursty events coalesce into a single API allocation per set.
local widgetSetCache = {}        -- [setID] = { table, expires }
local WIDGET_CACHE_TTL = 5       -- seconds

local function GetCachedWidgetsBySetID(setID)
    if not (setID and C_UIWidgetManager
            and C_UIWidgetManager.GetAllWidgetsBySetID) then
        return nil
    end
    local now = GetTime()
    local entry = widgetSetCache[setID]
    if entry and entry.expires > now then
        return entry.widgets
    end
    local widgets = C_UIWidgetManager.GetAllWidgetsBySetID(setID)
    if not entry then
        entry = {}
        widgetSetCache[setID] = entry
    end
    entry.widgets = widgets
    entry.expires = now + WIDGET_CACHE_TTL
    return widgets
end

local function PopulateBountifulDelvesLive(out)
    ReleaseBountifulList(out)
    if not (C_AreaPoiInfo and C_AreaPoiInfo.GetAreaPOIInfo) then
        return
    end

    for _, delve in ipairs(E.DelveData) do
        if delve.poiID and delve.mapID then
            local poi = C_AreaPoiInfo.GetAreaPOIInfo(delve.mapID, delve.poiID)
            if poi and poi.atlasName == "delves-bountiful" then
                local isOvercharged = false
                if poi.iconWidgetSet then
                    local widgets = GetCachedWidgetsBySetID(poi.iconWidgetSet)
                    if widgets and #widgets == 2 then
                        isOvercharged = true
                    end
                end

                -- Get story variant from tooltip widget
                local storyVariant = ""
                if poi.tooltipWidgetSet then
                    local tWidgets = GetCachedWidgetsBySetID(poi.tooltipWidgetSet)
                    if tWidgets then
                        for _, info in ipairs(tWidgets) do
                            if info.widgetType == Enum.UIWidgetVisualizationType.TextWithState then
                                local viz = C_UIWidgetManager
                                    .GetTextWithStateWidgetVisualizationInfo(
                                        info.widgetID)
                                if viz and viz.orderIndex == 0 then
                                    storyVariant = viz.text or ""
                                    break
                                end
                            end
                        end
                    end
                end

                local entry        = AcquireBountifulEntry()
                entry.name         = poi.name or delve.name
                entry.zone         = delve.zone
                entry.x            = delve.x
                entry.y            = delve.y
                entry.mapID        = delve.mapID
                entry.poiID        = delve.poiID
                entry.normalPoiID  = delve.normalPoiID
                entry.storyVariant = storyVariant
                entry.overcharged  = isOvercharged
                entry.completed    = false
                table_insert(out, entry)
            end
        end
    end
end

------------------------------------------------------------------------
-- Currency / stat queries
------------------------------------------------------------------------

--- Query a currency amount by ID. C_CurrencyInfo.GetCurrencyInfo returns
--- a table with .quantity (current amount) and .maxQuantity.
--- @return number current, number max
local function GetCurrencyAmount(currencyID)
    -- C_CurrencyInfo.GetCurrencyInfo is confirmed in 12.0 (display-only, permitted).
    if C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo then
        local info = C_CurrencyInfo.GetCurrencyInfo(currencyID)
        if info then
            return info.quantity or 0, info.maxQuantity or 0
        end
    end
    return 0, 0
end

local function GetBountifulKeys()
    return GetCurrencyAmount(E.CurrencyIDs.bountifulKeys)
end

local function GetCofferShards()
    return GetCurrencyAmount(E.CurrencyIDs.cofferKeyShards)
end

--- Compute how many full keys can be crafted from current shards.
local function KeysFromShards(shards)
    return math_floor(shards / E.SHARDS_PER_KEY)
end

------------------------------------------------------------------------
-- Weekly reset timer
-- C_DateAndTime.GetSecondsUntilWeeklyReset() returns the number of
-- seconds until the next weekly reset (Tuesday NA / Wednesday EU).
------------------------------------------------------------------------

--- Returns the epoch timestamp of the most recent weekly reset.
--- Used to invalidate manual completion marks from previous weeks.
local function GetLastWeeklyResetTime()
    if C_DateAndTime and C_DateAndTime.GetSecondsUntilWeeklyReset then
        local secsUntilReset = C_DateAndTime.GetSecondsUntilWeeklyReset()
        if secsUntilReset and secsUntilReset > 0 then
            local now = GetServerTime and GetServerTime() or time()
            -- The reset cycle is 7 days (604800 seconds).
            -- Last reset = next reset - 604800.
            return now + secsUntilReset - 604800
        end
    end
    return 0  -- fallback: treat all marks as valid
end

local function GetResetTimeString()
    -- C_DateAndTime.GetSecondsUntilWeeklyReset is confirmed in 12.0.
    if C_DateAndTime and C_DateAndTime.GetSecondsUntilWeeklyReset then
        local secs = C_DateAndTime.GetSecondsUntilWeeklyReset()
        if secs and secs > 0 then
            local days  = math_floor(secs / 86400)
            local hours = math_floor((secs % 86400) / 3600)
            local mins  = math_floor((secs % 3600) / 60)
            return string_format("Resets in %dd %dh %dm", days, hours, mins)
        end
    end
    return "Reset timer unavailable"
end

------------------------------------------------------------------------
-- Journey stage (Delver's Journey / Renown)
-- Uses C_DelvesUI.GetDelvesFactionForSeason() to get the faction ID,
-- then C_MajorFactions.GetMajorFactionRenownInfo() for progress.
------------------------------------------------------------------------
local function GetJourneyProgress()
    if C_DelvesUI and C_DelvesUI.GetDelvesFactionForSeason
            and C_MajorFactions and C_MajorFactions.GetMajorFactionRenownInfo then
        local factionID = C_DelvesUI.GetDelvesFactionForSeason()
        if factionID and factionID > 0 then
            local info = C_MajorFactions.GetMajorFactionRenownInfo(factionID)
            if info then
                return info.renownLevel or 0,
                       info.renownReputationEarned or 0,
                       info.renownLevelThreshold or 1
            end
        end
    end
    -- Fallback if APIs unavailable
    return 0, 0, 1
end

------------------------------------------------------------------------
-- Sort bountiful list: completed at bottom, then alphabetical
------------------------------------------------------------------------
local function SortBountifulList()
    table_sort(bountifulList, function(a, b)
        if a.completed ~= b.completed then
            return not a.completed  -- false (incomplete) sorts first
        end
        return a.name:lower() < b.name:lower()
    end)
end

------------------------------------------------------------------------
-- Refresh bountiful data from API (or fallback)
------------------------------------------------------------------------
local lastBountifulRefresh = 0
local function RefreshBountifulData(force)
    -- Debounce: skip if called again within 2 seconds (unless forced)
    local now = GetTime()
    if not force and (now - lastBountifulRefresh < 2) then return end
    lastBountifulRefresh = now

    -- Live detection via C_AreaPoiInfo (populates bountifulList in-place
    -- using the entry pool - no table churn on the hot path).
    PopulateBountifulDelvesLive(bountifulList)

    -- Merge manual completions from SavedVariables
    -- Only honour marks from the current weekly reset period
    if E.db and E.db.manualComplete then
        local lastReset = GetLastWeeklyResetTime()
        -- Sweep: drop every stale entry (any delve, not just ones in
        -- this week's bountiful list) so the table never grows
        -- unbounded across seasons.
        for name, stamp in pairs(E.db.manualComplete) do
            if type(stamp) ~= "number" or stamp < lastReset then
                E.db.manualComplete[name] = nil
            end
        end
        for _, delve in ipairs(bountifulList) do
            if E.db.manualComplete[delve.name] then
                delve.completed = true
            end
        end
    end
    -- Build lookup tables so other tabs can check bountiful status
    if not E.currentBountifulNames then E.currentBountifulNames = {} end
    if not E.currentBountifulPOIs  then E.currentBountifulPOIs  = {} end
    wipe(E.currentBountifulNames)
    wipe(E.currentBountifulPOIs)
    E.currentBountifulCount = #bountifulList  -- actual count (not doubled)
    for _, delve in ipairs(bountifulList) do
        E.currentBountifulNames[delve.name] = true
        -- Also store normalized name for fuzzy matching
        local norm = strtrim(delve.name):lower()
        E.currentBountifulNames[norm] = true
        if delve.poiID then
            E.currentBountifulPOIs[delve.poiID] = true
        end
    end

    -- Bountiful rotation change alert (F6)
    if #bountifulList > 0 and E.db and E.db.alertNewBountiful then
        -- Reusable scratch buffer - avoids allocating a fresh table
        -- every refresh just to detect a once-per-week rotation change.
        if not E._bountifulIDBuf then E._bountifulIDBuf = {} end
        local currentIDs = E._bountifulIDBuf
        wipe(currentIDs)
        for _, delve in ipairs(bountifulList) do
            table_insert(currentIDs, delve.poiID)
        end
        table_sort(currentIDs)

        local storedIDs = E.db.lastKnownBountifulIDs or {}
        local changed = (#currentIDs ~= #storedIDs)
        if not changed then
            for i, id in ipairs(currentIDs) do
                if id ~= storedIDs[i] then
                    changed = true
                    break
                end
            end
        end

        if changed and #storedIDs > 0 then
            print("|cFFFF2222[Everything Delves]|r New Bountiful Delves are available this week! Open Everything Delves to see them.")
        end
        -- Mutate the SavedVariables table in place instead of replacing
        -- the reference each refresh (keeps the DB table stable).
        if not E.db.lastKnownBountifulIDs then E.db.lastKnownBountifulIDs = {} end
        wipe(E.db.lastKnownBountifulIDs)
        for i = 1, #currentIDs do
            E.db.lastKnownBountifulIDs[i] = currentIDs[i]
        end
    end

    SortBountifulList()
end


------------------------------------------------------------------------
-- Stat label factory (left label + right value)
------------------------------------------------------------------------
local function CreateStatRow(parent, labelText, yOffset, xOffset, itemIconID)
    xOffset = xOffset or 0
    local anchorX = 8 + xOffset

    -- Optional item icon before the label
    local icon
    if itemIconID then
        icon = parent:CreateTexture(nil, "ARTWORK")
        icon:SetPoint("TOPLEFT", parent, "TOPLEFT", anchorX, yOffset + 2)
        icon:SetSize(14, 14)
        anchorX = 0  -- label will anchor to icon instead
    end

    local lbl = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    if icon then
        lbl:SetPoint("LEFT", icon, "RIGHT", 3, 0)
    else
        lbl:SetPoint("TOPLEFT", parent, "TOPLEFT", anchorX, yOffset)
    end
    lbl:SetFont(lbl:GetFont(), 11)
    lbl:SetText(E.CC.muted .. labelText .. E.CC.close)

    local val = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    val:SetPoint("LEFT", lbl, "RIGHT", 6, 0)
    val:SetFont(val:GetFont(), 11)

    return val, icon  -- caller sets text on val; icon needs SetTexture at runtime
end

------------------------------------------------------------------------
-- Row rendering
------------------------------------------------------------------------
local function UpdateRows(container)
    local total = #bountifulList
    for i = 1, VISIBLE_ROWS do
        local row = rows[i]
        local idx = i
        if idx <= total then
            local delve = bountifulList[idx]
            row.delve = delve

            if delve.completed then
                -- Completed: dimmed with checkmark prefix
                row.nameText:SetText(
                    E.CC.muted .. "\226\156\147 " .. delve.name .. E.CC.close
                )
                row.zoneText:SetText(E.CC.muted .. delve.zone .. E.CC.close)
                row.variantText:SetText(
                    E.CC.muted .. delve.storyVariant .. E.CC.close
                )
                row:SetBackdropColor(0.05, 0.05, 0.05, 0.30)
            else
                row.nameText:SetText(E.CC.gold .. delve.name .. E.CC.close)
                row.zoneText:SetText(E.CC.body .. delve.zone .. E.CC.close)

                -- Check if normal (non-bountiful) version is also active
                local normalNote = ""
                if delve.normalPoiID and delve.mapID
                        and C_AreaPoiInfo and C_AreaPoiInfo.GetAreaPOIInfo then
                    local nPoi = C_AreaPoiInfo.GetAreaPOIInfo(
                                     delve.mapID, delve.normalPoiID)
                    if nPoi then
                        normalNote = E.CC.muted
                            .. " (Normal version available)" .. E.CC.close
                    end
                end

                row.variantText:SetText(
                    E.CC.muted .. delve.storyVariant .. E.CC.close
                    .. normalNote
                )
                -- Neutral row tint (matches Delve Locations tab).
                row:SetBackdropColor(0.05, 0.05, 0.05, 0.20)
            end
            row:Show()
        else
            row:Hide()
        end
    end
end

------------------------------------------------------------------------
-- Create a single bountiful delve row
------------------------------------------------------------------------
local function CreateRow(parent, index)
    local row = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    row:SetHeight(ROW_HEIGHT)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -((index - 1) * ROW_HEIGHT))
    row:SetPoint("RIGHT", parent, "RIGHT", 0, 0)
    row:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
    row:SetBackdropColor(0.05, 0.05, 0.05, 0.20)
    row:EnableMouse(true)
    -- RegisterForClicks on a non-Button frame isn't needed - we use
    -- OnMouseUp to detect right-clicks for manual-complete.

    -- Delve name (top line)
    local nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    nameText:SetPoint("TOPLEFT", row, "TOPLEFT", 4, -3)
    nameText:SetFont(nameText:GetFont(), 11)
    nameText:SetWidth(220)
    nameText:SetJustifyH("LEFT")
    nameText:SetWordWrap(false)
    row.nameText = nameText

    -- Story variant (second line, smaller muted text)
    local variantText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    variantText:SetPoint("TOPLEFT", nameText, "BOTTOMLEFT", 0, -1)
    variantText:SetFont(variantText:GetFont(), 9)
    variantText:SetWidth(220)
    variantText:SetJustifyH("LEFT")
    variantText:SetWordWrap(false)
    row.variantText = variantText

    -- Zone
    local zoneText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    zoneText:SetPoint("LEFT", row, "LEFT", 230, 0)
    zoneText:SetFont(zoneText:GetFont(), 11)
    zoneText:SetWidth(130)
    zoneText:SetJustifyH("LEFT")
    zoneText:SetWordWrap(false)
    row.zoneText = zoneText

    -- [Waypoint] button
    local wpBtn = E:CreateButton(row, 32, 20, "Pin")
    wpBtn.label:SetFont(wpBtn.label:GetFont(), 10)
    wpBtn:SetPoint("LEFT", row, "LEFT", 370, 0)
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
                      "Places a Blizzard map pin on this delve.")
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
    ttBtn:SetPoint("LEFT", row, "LEFT", 408, 0)
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

    -- Hover highlight + tooltip
    row:SetScript("OnEnter", function(self)
        if not (self.delve and self.delve.completed) then
            self:SetBackdropColor(0.20, 0, 0, 0.50)
        end
        if self.delve then
            E:ShowTooltip(self, self.delve.name,
                          E.CC.muted .. "Story: " .. E.CC.close
                              .. self.delve.storyVariant,
                          "",
                          E.CC.muted .. "Right-click to toggle manual completion."
                              .. E.CC.close)
        end
    end)
    row:SetScript("OnLeave", function(self)
        if self.delve and self.delve.completed then
            self:SetBackdropColor(0.05, 0.05, 0.05, 0.30)
        else
            self:SetBackdropColor(0.05, 0.05, 0.05, 0.20)
        end
        E:HideTooltip()
    end)

    -- Right-click: toggle manual completion
    row:SetScript("OnMouseUp", function(self, button)
        if button == "RightButton" and self.delve then
            self.delve.completed = not self.delve.completed
            -- Persist in SavedVariables with current timestamp
            if self.delve.completed then
                E.db.manualComplete[self.delve.name] = GetServerTime and GetServerTime() or time()
                E:RecordDelveCompletion(self.delve.name)
            else
                E.db.manualComplete[self.delve.name] = nil
            end
            SortBountifulList()
            UpdateRows(parent)
            -- Update the weekly progress bar if it exists
            if parent.progressBar then
                local done = 0
                for _, d in ipairs(bountifulList) do
                    if d.completed then done = done + 1 end
                end
                parent.progressBar:SetProgress(done, math_max(1, #bountifulList))
            end
        end
    end)

    return row
end

------------------------------------------------------------------------
-- MODULE INIT
------------------------------------------------------------------------
E:RegisterModule(function()
    local frame = CreateFrame("Frame", "EverythingDelvesTab2Content")

    -- Keep references for the OnUpdate timer and data refresh
    local statValues = {}

    --------------------------------------------------------------------
    -- HEADER STATS BLOCK (2-column grid)
    --------------------------------------------------------------------
    local STAT_Y = -4
    local COL2_X = 310  -- second column x-offset

    -- Left column
    local keyIconTex, cofferShardIconTex
    statValues.bountifulKeys, keyIconTex   = CreateStatRow(frame, "Bountiful Keys:", STAT_Y, nil, E.ItemIcons.cofferKey)
    statValues.cofferShards, cofferShardIconTex = CreateStatRow(frame, "Coffer Key Shards:", STAT_Y - 18, nil, E.ItemIcons.cofferShard)
    statValues.keysFromShards= CreateStatRow(frame, "Keys from Shards:", STAT_Y - 36)

    -- Right column
    statValues.journey       = CreateStatRow(frame, "Journey:", STAT_Y, COL2_X)
    statValues.resetTimer    = CreateStatRow(frame, "Weekly Reset:", STAT_Y - 18, COL2_X)
    statValues.sessionCount  = CreateStatRow(frame, "Session Completions:", STAT_Y - 36, COL2_X)

    -- Function to refresh all stat display values
    local function RefreshStats()
        local keys  = GetBountifulKeys()
        local shards, maxShards = GetCofferShards()
        local stage, cur, stageMax = GetJourneyProgress()
        local sessionDone = (E.sessionData and E.sessionData.bountifulCompleted) or 0

        -- Set currency icons via modern API
        if keyIconTex then keyIconTex:SetTexture(E.CachedIcons.cofferKey or C_Item.GetItemIconByID(E.ItemIcons.cofferKey)) end
        if cofferShardIconTex then cofferShardIconTex:SetTexture(E.CachedIcons.cofferShard or C_Item.GetItemIconByID(E.ItemIcons.cofferShard)) end

        statValues.bountifulKeys:SetText(E.CC.gold .. keys .. E.CC.close)
        statValues.cofferShards:SetText(
            E.CC.gold .. shards .. E.CC.close
            .. E.CC.muted .. " / " .. maxShards .. E.CC.close
        )
        statValues.keysFromShards:SetText(
            E.CC.gold .. KeysFromShards(shards) .. E.CC.close
            .. E.CC.muted .. "  (" .. shards .. " / "
            .. E.SHARDS_PER_KEY .. ")" .. E.CC.close
        )
        statValues.journey:SetText(
            E.CC.gold .. "Stage " .. stage .. E.CC.close
            .. E.CC.muted .. " - " .. cur .. " / " .. stageMax .. E.CC.close
        )
        statValues.resetTimer:SetText(E.CC.gold .. GetResetTimeString() .. E.CC.close)
        statValues.sessionCount:SetText(E.CC.gold .. sessionDone .. E.CC.close)
    end

    --------------------------------------------------------------------
    -- WEEKLY BOUNTIFUL PROGRESS BAR
    --------------------------------------------------------------------
    local progressBar = E:CreateProgressBar(frame, 0, 14)
    progressBar:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, STAT_Y - 60)
    progressBar:SetPoint("RIGHT", frame, "RIGHT", -20, 0)
    frame.progressBar = progressBar   -- ref for row right-click updates

    --------------------------------------------------------------------
    -- QUICK ACTION BUTTONS ROW
    --------------------------------------------------------------------
    local ACTIONS_Y = STAT_Y - 84

    -- [Great Vault] - ToggleGreatVaultUI() opens the Great Vault panel.
    -- This is a protected function that Blizzard exposes specifically for
    -- addon use; it is NOT tainted.
    local gvBtn = E:CreateButton(frame, 90, 24, "Great Vault")
    gvBtn:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, ACTIONS_Y)
    gvBtn:SetScript("OnClick", function()
        -- Blizzard_WeeklyRewards is load-on-demand; force-load before use.
        if not WeeklyRewardsFrame then
            EnsureBlizzardAddon("Blizzard_WeeklyRewards")
        end
        if WeeklyRewardsFrame then
            if WeeklyRewardsFrame:IsShown() then
                HideUIPanel(WeeklyRewardsFrame)
            else
                ShowUIPanel(WeeklyRewardsFrame)
            end
        ---@diagnostic disable-next-line: undefined-global
        elseif ToggleGreatVaultUI then
            ---@diagnostic disable-next-line: undefined-global
            ToggleGreatVaultUI()
        else
            print(E.CC.header .. "Everything Delves|r: Great Vault UI could not be loaded.")
        end
    end)
    gvBtn:SetScript("OnEnter", function(self)
        local hc = E.Colors.buttonHover
        self:SetBackdropColor(hc.r, hc.g, hc.b, hc.a)
        E:ShowTooltip(self, "Great Vault", "Open the Great Vault reward panel.")
    end)
    gvBtn:SetScript("OnLeave", function(self)
        local bc = E.Colors.buttonBg
        self:SetBackdropColor(bc.r, bc.g, bc.b, bc.a)
        E:HideTooltip()
    end)

    -- [Start LFG] - Opens the Group Finder directly to the Delves
    -- category (121) and clicks "Start Group".
    local lfgStartBtn = E:CreateButton(frame, 90, 24, "Start LFG")
    lfgStartBtn:SetPoint("LEFT", gvBtn, "RIGHT", 12, 0)

    -- Shared LFG launcher used by both the initial OnClick and the
    -- enabled-state refresher below.
    local function OpenDelveLFG()
        -- Blizzard_GroupFinder / Blizzard_PVPUI are load-on-demand.
        if not PVEFrame or not LFGListFrame then
            EnsureBlizzardAddon("Blizzard_GroupFinder")
            EnsureBlizzardAddon("Blizzard_PVPUI")
        end
        if not PVEFrame then
            print(E.CC.header .. "Everything Delves|r: LFG UI could not be loaded.")
            return
        end
        if not PVEFrame:IsShown() then
            PVEFrame_ToggleFrame()
        end
        -- Select the Group Finder tab
        if GroupFinderFrameGroupButton3 then
            GroupFinderFrameGroupButton3:Click()
        end
        -- Select Delves category (121) and click Start Group
        if LFGListFrame and LFGListFrame.CategorySelection
                and LFGListCategorySelection_SelectCategory then
            LFGListCategorySelection_SelectCategory(
                LFGListFrame.CategorySelection, 121, 0)
            if LFGListFrame.CategorySelection.StartGroupButton then
                LFGListFrame.CategorySelection.StartGroupButton:Click()
            end
        end
        -- Open the group type dropdown for convenience
        if LFGListFrame and LFGListFrame.EntryCreation
                and LFGListFrame.EntryCreation.GroupDropdown
                and LFGListFrame.EntryCreation.GroupDropdown.OpenMenu then
            LFGListFrame.EntryCreation.GroupDropdown:OpenMenu()
        end
    end

    lfgStartBtn:SetScript("OnClick", OpenDelveLFG)
    lfgStartBtn:SetScript("OnEnter", function(self)
        local hc = E.Colors.buttonHover
        self:SetBackdropColor(hc.r, hc.g, hc.b, hc.a)
        if IsInRaid() then
            E:ShowTooltip(self, "Start LFG",
                          E.CC.red .. "Cannot list while in a raid group." .. E.CC.close)
        elseif IsInGroup() and not UnitIsGroupLeader("player") then
            E:ShowTooltip(self, "Start LFG",
                          E.CC.red .. "Only the group leader can list." .. E.CC.close)
        else
            E:ShowTooltip(self, "Start LFG",
                          "Open the Group Finder to list a Delve group.")
        end
    end)
    lfgStartBtn:SetScript("OnLeave", function(self)
        local bc = E.Colors.buttonBg
        self:SetBackdropColor(bc.r, bc.g, bc.b, bc.a)
        E:HideTooltip()
    end)

    -- Helper to update LFG button enabled/disabled state
    local function RefreshLFGButton()
        if IsInRaid() or (IsInGroup() and not UnitIsGroupLeader("player")) then
            lfgStartBtn:SetAlpha(0.40)
            lfgStartBtn:SetScript("OnClick", function() end)
            lfgStartBtn.disabled = true
        else
            lfgStartBtn:SetAlpha(1.0)
            lfgStartBtn:SetScript("OnClick", OpenDelveLFG)
            lfgStartBtn.disabled = false
        end
    end

    --------------------------------------------------------------------
    -- BOUNTIFUL DELVES LIST
    --------------------------------------------------------------------
    -- Pushed down further from the action button row for breathing room.
    local LIST_Y = ACTIONS_Y - 70

    -- Accent-colour divider under the Great Vault / Start LFG buttons,
    -- spanning the full UI width (matches the divider directly below
    -- the tab row).
    local actionDiv = frame:CreateTexture(nil, "ARTWORK")
    actionDiv:SetHeight(1)
    actionDiv:SetPoint("TOPLEFT",  frame, "TOPLEFT",   8, ACTIONS_Y - 30)
    actionDiv:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -8, ACTIONS_Y - 30)
    E:StyleAccentDivider(actionDiv)

    -- Permanent grey line ABOVE the section header (#4A4A4A,
    -- not affected by accent colour). Stops at the right edge of TomTom.
    local headerLineTop = frame:CreateTexture(nil, "ARTWORK")
    headerLineTop:SetHeight(1)
    headerLineTop:SetPoint("TOPLEFT",  frame, "TOPLEFT",  8,   LIST_Y + 8)
    headerLineTop:SetPoint("TOPRIGHT", frame, "TOPLEFT", 462,  LIST_Y + 8)
    E:StyleGreyLine(headerLineTop)

    -- Section header
    local listHeader = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    listHeader:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, LIST_Y)
    listHeader:SetFont(listHeader:GetFont(), E.HEADER_FONT_SIZE, "OUTLINE")
    E:StyleAccentHeader(listHeader, "This Week's Bountiful Delves")

    -- Permanent grey line directly under the section header.
    local headerLineBot = frame:CreateTexture(nil, "ARTWORK")
    headerLineBot:SetHeight(1)
    headerLineBot:SetPoint("TOPLEFT",  frame, "TOPLEFT",  8,   LIST_Y - 26)
    headerLineBot:SetPoint("TOPRIGHT", frame, "TOPLEFT", 462,  LIST_Y - 26)
    E:StyleGreyLine(headerLineBot)

    -- Level 68 unlock warning (shown when player is too low level)
    local unlockWarning = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    unlockWarning:SetPoint("TOPLEFT", listHeader, "BOTTOMLEFT", 0, -8)
    unlockWarning:SetFont(unlockWarning:GetFont(), 12)
    unlockWarning:SetText(E.CC.red .. "Delves unlock at Level 68" .. E.CC.close)
    unlockWarning:Hide()

    -- [Refresh] button
    local refreshBtn = E:CreateButton(frame, 70, 22, "Refresh")
    refreshBtn.label:SetFont(refreshBtn.label:GetFont(), 10)
    refreshBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -22, LIST_Y + 2)
    refreshBtn:SetScript("OnClick", function()
        RefreshBountifulData(true)
        UpdateRows(frame.listFrame)
        RefreshStats()
        -- Update progress bar
        local done = 0
        for _, d in ipairs(bountifulList) do
            if d.completed then done = done + 1 end
        end
        progressBar:SetProgress(done, math_max(1, #bountifulList))
    end)
    refreshBtn:SetScript("OnEnter", function(self)
        local hc = E.Colors.buttonHover
        self:SetBackdropColor(hc.r, hc.g, hc.b, hc.a)
        E:ShowTooltip(self, "Refresh",
                      "Re-query bountiful delve data and currency values.")
    end)
    refreshBtn:SetScript("OnLeave", function(self)
        local bc = E.Colors.buttonBg
        self:SetBackdropColor(bc.r, bc.g, bc.b, bc.a)
        E:HideTooltip()
    end)

    -- Column headers
    local COL_Y = LIST_Y - 32
    for _, col in ipairs({
        { label = "Delve Name",  x = 8   },
        { label = "Zone",        x = 234 },
        { label = "Pin",         x = 374 },
        { label = "TomTom",      x = 412 },
    }) do
        local fs = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        fs:SetPoint("TOPLEFT", frame, "TOPLEFT", col.x, COL_Y)
        fs:SetFont(fs:GetFont(), 10, "OUTLINE")
        E:StyleAccentHeader(fs, col.label)
    end

    -- List frame (static - no scroll needed for live bountiful list)
    local listFrame = CreateFrame("Frame", nil, frame)
    listFrame:SetPoint("TOPLEFT",  frame, "TOPLEFT",  4, COL_Y - 16)
    listFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -4, 4)
    frame.listFrame = listFrame

    -- Create recycled rows
    for i = 1, VISIBLE_ROWS do
        rows[i] = CreateRow(listFrame, i)
    end

    -- Store progressBar reference on listFrame for row right-click access
    listFrame.progressBar = progressBar

    --------------------------------------------------------------------
    -- OnShow: refresh everything when the tab becomes visible
    --------------------------------------------------------------------
    frame:SetScript("OnShow", function(self)
        -- Level 68 unlock gate
        if UnitLevel("player") < 68 then
            unlockWarning:Show()
            listFrame:Hide()
            refreshBtn:Hide()
            progressBar:Hide()
            return
        else
            unlockWarning:Hide()
            listFrame:Show()
            refreshBtn:Show()
            progressBar:Show()
        end

        RefreshBountifulData(true)
        RefreshStats()
        RefreshLFGButton()

        -- Update progress bar
        local done = 0
        for _, d in ipairs(bountifulList) do
            if d.completed then done = done + 1 end
        end
        progressBar:SetProgress(done, math_max(1, #bountifulList))

        UpdateRows(listFrame)
    end)

    --------------------------------------------------------------------
    -- Live-updating reset timer (runs while tab is visible)
    -- OnUpdate fires every frame; we throttle to once per second.
    --------------------------------------------------------------------
    local elapsed = 0
    frame:SetScript("OnUpdate", function(self, dt)
        elapsed = elapsed + dt
        if elapsed >= 1 then
            elapsed = 0
            if self:IsShown() then
                statValues.resetTimer:SetText(
                    E.CC.gold .. GetResetTimeString() .. E.CC.close
                )
            end
        end
    end)

    --------------------------------------------------------------------
    -- Register for currency update events so stats refresh automatically
    --------------------------------------------------------------------
    E:RegisterCallback("CurrencyUpdate", function()
        if frame:IsShown() then
            RefreshStats()
        end
    end)

    --------------------------------------------------------------------
    -- Register for area POI updates so bountiful list refreshes live
    --------------------------------------------------------------------
    E:RegisterCallback("AreaPoisUpdated", function()
        if frame:IsShown() then
            RefreshBountifulData()
            RefreshStats()
            local done = 0
            for _, d in ipairs(bountifulList) do
                if d.completed then done = done + 1 end
            end
            progressBar:SetProgress(done, math_max(1, #bountifulList))
            UpdateRows(listFrame)
        end
    end)

    --------------------------------------------------------------------
    -- Register with the main frame tab system
    --------------------------------------------------------------------
    E:RegisterTab(2, frame)

    -- Seed initial data
    RefreshBountifulData(true)
end)
