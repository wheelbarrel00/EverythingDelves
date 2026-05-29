------------------------------------------------------------------------
-- UI/TabCurrentBountiful.lua - Tab 2: Current Bountiful Delves
-- Tracks the player's live bountiful delve status (bountiful rerolls
-- daily): currency stats, weekly reset timer, quick-action buttons, and
-- a scrollable list of today's bountiful delves.
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
-- Story tier data (Midnight Season 1)
-- Maps story variant name → { tier, note }. Used to sort the bountiful
-- list, badge each row, and populate hover tooltips.
------------------------------------------------------------------------
local TIER_ORDER = { S=1, A=2, B=3, C=4, D=5, F=6 }
local TIER_COLORS = {
    S = {1.00, 0.84, 0.00},
    A = {0.20, 0.85, 0.20},
    B = {0.10, 0.80, 0.90},
    C = {0.85, 0.75, 0.10},
    D = {0.55, 0.55, 0.55},
    F = {0.45, 0.20, 0.20},
}
local function TierCC(tier)
    local tc = TIER_COLORS[tier]
    if not tc then return "|cFFAAAAAA" end
    return string_format("|cFF%02X%02X%02X",
        math_floor(tc[1]*255), math_floor(tc[2]*255), math_floor(tc[3]*255))
end

local STORY_TIERS = {
    -- S Tier
    ["Invasive Glow"]               = { tier="S", note="Bomb DoT scales with tier — keep it rolling and the clear is trivial." },
    -- A Tier
    ["Ogre Powered"]                = { tier="A", note="Straight shot to boss. Kill Unstable Aberrations before moving on." },
    ["Sporasaur Special"]           = { tier="A", note="Kite dinos and kick spores back to break their shields for bonus damage." },
    ["Sporasaurus Surprise"]        = { tier="A", note="Kite dinos and kick spores back to break their shields for bonus damage." },
    ["Holding the Line"]            = { tier="A", note="Head down the staircase; kill enemies (not heal allies) for the fastest route." },
    ["Academy Under Siege"]         = { tier="A", note="Scattered powerful items help, but it can't match Invasive Glow." },
    -- B Tier
    ["Core of the Problem"]         = { tier="B", note="Use portals to shortcut around the map. Kill enemies and collect orbs." },
    ["Faculty of Fear"]             = { tier="B", note="Revelation mechanic requires revealing many NPCs, adding significant time." },
    ["Party Crasher"]               = { tier="B", note="Hit levers to disable traps while defeating 4 Twilight Summoners." },
    ["Focusers Under Pressure"]     = { tier="B", note="Large crystal collection loop adds time compared to Ogre Powered." },
    ["Toadly Unbecoming"]           = { tier="B", note="Decurse frogs to spawn the boss. Open layout adds traverse time even when mounted." },
    -- C Tier
    ["Alnmoth Munchies"]            = { tier="C", note="Same quick route as Sporasaur Special but extra objectives slow it down." },
    ["Not What I Expected"]         = { tier="C", note="Click Lightbloom crates and activate security. Displacement Portal clones help in combat." },
    ["Trapped"]                     = { tier="C", note="Teleported inside — must rescue hostages on the way back to the entrance." },
    ["Totem Annihilation"]          = { tier="C", note="Take the bird north. Avoid the captured loa's lightning — it hits hard." },
    ["Traitor's Due"]               = { tier="C", note="Large unwalkable map. Defeat void foci and elites with the Eye of Antenorian buff." },
    -- D Tier
    ["Leyline Technician"]          = { tier="D", note="Inspecting every leyline adds a lot of time." },
    ["Descent of the Haranir"]      = { tier="D", note="Same quick pathing as Sporasaur but extra objectives add considerable time." },
    ["The Gravitational Effect"]    = { tier="D", note="Flying to collect Singularity Coils breaks the route significantly." },
    ["Loosed Loa"]                  = { tier="D", note="Use Evasive Elixir before the patrolling loa attacks to avoid a big stun." },
    ["Loose Loa"]                   = { tier="D", note="Use Evasive Elixir before the patrolling loa attacks to avoid a big stun." },
    ["Ritual Interrupted"]          = { tier="D", note="Navigate south freeing furbolgs. Haunted weapons deal decent bonus damage." },
    ["Calamitous"]                  = { tier="D", note="Enormous mountable map with required secondary objectives in all three variants." },
    ["Arena Champion"]              = { tier="D", note="Defeat two named enemies then collect mold samples from Moldering Fighters." },
    -- F Tier
    ["March of the Arcane Brigade"] = { tier="F", note="Activating sentinels is slow with no direct path to the boss." },
    ["Bombing Run"]                 = { tier="F", note="Destroying void portals makes for one of the slowest clears." },
    ["Mirror Shine"]                = { tier="F", note="Repositioning mirrors to reflect light is tedious. Mind positioning to avoid debuffs." },
    ["Shadowy Supplies"]            = { tier="F", note="Collecting 30 supplies from enemies and the floor is very slow." },
    ["Captured Wild"]               = { tier="F", note="Free caged wildlife; use worm bait on Void Researchers to spawn the boss." },
    ["Captured Wildlife"]           = { tier="F", note="Free caged wildlife; use worm bait on Void Researchers to spawn the boss." },
    ["Captured Widlife"]            = { tier="F", note="Free caged wildlife; use worm bait on Void Researchers to spawn the boss." },
    ["Stolen Mana"]                 = { tier="F", note="Use the Galvanic Rifle on mana barrels and free 8 prisoners from Mana Siphoners." },
    ["Lightbloom Invasion"]         = { tier="F", note="Free fighters and defend barricades against Thornmaws using nearby barrels." },
    ["Dastardly Rotstalk"]          = { tier="F", note="Taunt the crowd, click dirt piles, defeat spawns carefully to avoid being overwhelmed." },
    ["Dastardly Rootstalks"]        = { tier="F", note="Taunt the crowd, click dirt piles, defeat spawns carefully to avoid being overwhelmed." },
}

-- Strip color codes and "Story Variant:" prefix for clean display.
local function StripStoryPrefix(s)
    if not s or s == "" then return "" end
    local plain = s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    return plain:match("[Vv]ariant:%s*(.-)%s*$") or plain:match("^%s*(.-)%s*$") or plain
end

-- Multi-strategy lookup: handles any prefix format, color codes, or spacing.
local function GetStoryTier(storyVariant)
    if not storyVariant or storyVariant == "" then return nil end
    -- 1) Direct exact match
    if STORY_TIERS[storyVariant] then return STORY_TIERS[storyVariant] end
    -- 2) Strip color codes, try again
    local plain = storyVariant:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    if STORY_TIERS[plain] then return STORY_TIERS[plain] end
    -- 3) Extract everything after "Variant:" (handles any prefix format/spacing)
    local name = plain:match("[Vv]ariant:%s*(.-)%s*$")
    if name and STORY_TIERS[name] then return STORY_TIERS[name] end
    -- 4) Substring scan — finds the story name anywhere in the string
    local lower = plain:lower()
    for key, data in pairs(STORY_TIERS) do
        if lower:find(key:lower(), 1, true) then return data end
    end
    return nil
end

-- Expose the variant tier+note lookup so other tabs can reuse it (the
-- Delve Locations tab shows today's variant's note on hover). Returns the
-- { tier, note } table for a story-variant string, or nil.
function E:GetStoryTier(storyVariant)
    return GetStoryTier(storyVariant)
end

-- Set during RegisterModule init; read by UpdateBestPick (defined at file
-- scope, outside the RegisterModule body).
local bestPickFS = nil

------------------------------------------------------------------------
-- Local state
------------------------------------------------------------------------
local ROW_HEIGHT     = 36   -- taller rows to fit story variant sub-text
local bountifulList  = {}   -- today's bountiful delves (reused)
-- Bountiful count is derived dynamically from #bountifulList (no hardcoded constant)
-- Scratch set (wiped per refresh) used to de-dupe the dropped-off completed
-- delve re-add against what is already in bountifulList.
local reAddSeen      = {}

-- Entry pool: recycled delve entry tables to avoid allocating 6-8
-- fresh tables every time the bountiful list is rebuilt (on OnShow,
-- area POI updates, and refresh button clicks).
local bountifulEntryPool = {}

-- Expansion state for boss tactics (keyed by delve name / "name##idx").
-- The boss data + rendering match the Delve Locations tab exactly.
local expandedDelve = {}
local expandedBoss  = {}

-- Reflow pools + scroll widgets (assigned during init).
local delveRowPool = {}
local bossRowPool  = {}
local noteLinePool = {}
local sc, scrollFrame, scrollBar
local UpdateScrollRange

-- Boss-note role colouring (mirrors the Delve Locations tab).
local function RoleCC(role)
    local m = E.BossRoleMeta and E.BossRoleMeta[role]
    local rgb = m and m.rgb or {0.80, 0.80, 0.85}
    return string_format("|cFF%02X%02X%02X",
        math_floor(rgb[1]*255), math_floor(rgb[2]*255), math_floor(rgb[3]*255))
end
local function RoleLabel(role)
    local m = E.BossRoleMeta and E.BossRoleMeta[role]
    return (m and m.label or "Note") .. ":"
end

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
-- If atlasName == "delves-bountiful", the delve is bountiful today.
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
-- Reset timer
-- Bountiful delves + story variants reroll on the DAILY reset; this tab
-- tracks today's bountiful set, so it shows the daily countdown. (The
-- weekly reset still governs the vault / Gilded Stash / bounties.)
------------------------------------------------------------------------

local function GetResetTimeString()
    -- Bountiful delves reroll on the daily reset (< 24h away).
    if C_DateAndTime and C_DateAndTime.GetSecondsUntilDailyReset then
        local secs = C_DateAndTime.GetSecondsUntilDailyReset()
        if secs and secs > 0 then
            local hours = math_floor(secs / 3600)
            local mins  = math_floor((secs % 3600) / 60)
            return string_format("Resets in %dh %dm", hours, mins)
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
-- Best Pick banner: show the highest-tier non-completed bountiful
------------------------------------------------------------------------
local function UpdateBestPick()
    if not bestPickFS then return end
    local best, bestOrder = nil, 8
    for _, d in ipairs(bountifulList) do
        if not d.completed then
            local si = GetStoryTier(d.storyVariant)
            local order = si and (TIER_ORDER[si.tier] or 7) or 7
            if order < bestOrder then
                bestOrder, best = order, d
            end
        end
    end
    if best then
        local si = GetStoryTier(best.storyVariant)
        if si then
            local cc = TierCC(si.tier)
            bestPickFS:SetText(
                E.CC.muted .. "Best Pick: " .. E.CC.close
                .. E.CC.gold .. best.name .. E.CC.close
                .. E.CC.muted .. "  \226\128\148  " .. E.CC.close
                .. E.CC.body .. StripStoryPrefix(best.storyVariant) .. E.CC.close
                .. E.CC.muted .. "  \226\128\148  " .. E.CC.close
                .. cc .. si.tier .. " Tier|r"
            )
            return
        end
    end
    bestPickFS:SetText("")
end

------------------------------------------------------------------------
-- Sort bountiful list: incomplete first, then by tier, then alphabetical
------------------------------------------------------------------------
local function SortBountifulList()
    table_sort(bountifulList, function(a, b)
        if a.completed ~= b.completed then
            return not a.completed
        end
        local ta = GetStoryTier(a.storyVariant)
        local tb = GetStoryTier(b.storyVariant)
        local oa = ta and (TIER_ORDER[ta.tier] or 7) or 7
        local ob = tb and (TIER_ORDER[tb.tier] or 7) or 7
        if oa ~= ob then return oa < ob end
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

    -- Daily reset boundary (run.timestamp is time()-based; 0 if the API is
    -- unavailable). Shared by the in-list completion sweep below and the
    -- dropped-off re-add further down.
    local dailyResetEpoch = 0
    if C_DateAndTime and C_DateAndTime.GetSecondsUntilDailyReset then
        local secs = C_DateAndTime.GetSecondsUntilDailyReset()
        if secs and secs > 0 then
            dailyResetEpoch = time() + secs - 86400
        end
    end

    -- Completion is automatic: a bountiful delve counts as done if it has
    -- a run logged since today's daily reset, so the checklist + progress
    -- bar fill in when you finish one.
    if E.db and E.db.delveHistory and dailyResetEpoch > 0 then
        for _, delve in ipairs(bountifulList) do
            if not delve.completed then
                local hist = E.db.delveHistory[delve.name]
                local runs = hist and hist.recentRuns
                if runs then
                    for _, run in ipairs(runs) do
                        if (run.timestamp or 0) >= dailyResetEpoch then
                            delve.completed = true
                            break
                        end
                    end
                end
            end
        end
    end
    -- Build lookup tables so other tabs can check bountiful status
    if not E.currentBountifulNames     then E.currentBountifulNames     = {} end
    if not E.currentBountifulPOIs      then E.currentBountifulPOIs      = {} end
    if not E.currentBountifulStory     then E.currentBountifulStory     = {} end
    if not E.currentBountifulStoryTier then E.currentBountifulStoryTier = {} end
    wipe(E.currentBountifulNames)
    wipe(E.currentBountifulPOIs)
    wipe(E.currentBountifulStory)
    wipe(E.currentBountifulStoryTier)
    E.currentBountifulCount = #bountifulList  -- actual count (not doubled)
    for _, delve in ipairs(bountifulList) do
        E.currentBountifulNames[delve.name] = true
        -- Also store normalized name for fuzzy matching
        local norm = strtrim(delve.name):lower()
        E.currentBountifulNames[norm] = true
        if delve.poiID then
            E.currentBountifulPOIs[delve.poiID] = true
        end
        -- Story variant + tier for today's rotation (used by Delve Locations tab)
        local si = GetStoryTier(delve.storyVariant)
        E.currentBountifulStory[delve.name]     = StripStoryPrefix(delve.storyVariant)
        E.currentBountifulStoryTier[delve.name] = si and si.tier or nil
    end

    -- Bountiful rotation change alert (F6)
    if #bountifulList > 0 and E.db and E.db.alertNewBountiful then
        -- Reusable scratch buffer - avoids allocating a fresh table
        -- every refresh just to detect a daily rotation change.
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
            print("|cFFFF2222[Everything Delves]|r New Bountiful Delves are available today! Open Everything Delves to see them.")
        end
        -- Mutate the SavedVariables table in place instead of replacing
        -- the reference each refresh (keeps the DB table stable).
        if not E.db.lastKnownBountifulIDs then E.db.lastKnownBountifulIDs = {} end
        wipe(E.db.lastKnownBountifulIDs)
        for i = 1, #currentIDs do
            E.db.lastKnownBountifulIDs[i] = currentIDs[i]
        end
    end

    -- Re-add today's COMPLETED bountiful delves that have dropped off the
    -- live POI list. Completing a bountiful delve removes its
    -- "delves-bountiful" atlas, so it vanishes from PopulateBountifulDelvesLive
    -- above -- which made the checklist hide the finished delve and the
    -- progress bar SHRINK its denominator (0/4 -> 0/3) instead of counting it
    -- (1/4). We reconstruct the full daily set from delveHistory: any delve
    -- with a bountiful run since today's reset that isn't already listed is
    -- added back as a completed entry.
    --
    -- Deliberately added to bountifulList ONLY (drives the checklist + bar),
    -- and AFTER the E.currentBountifulNames build above -- so a completed
    -- delve is NOT treated as still-bountiful by the wasBountiful stamp at
    -- delve entry or by AutoRepairBountifulHistory (which would re-inflate the
    -- Gilded Stash counter). E.currentBountifulCount stays the live "active"
    -- count for the minimap tooltip.
    if E.db and E.db.delveHistory and dailyResetEpoch > 0 and E.DelveDataByName then
        wipe(reAddSeen)
        for _, d in ipairs(bountifulList) do reAddSeen[d.name] = true end
        for delveName, hist in pairs(E.db.delveHistory) do
            if not reAddSeen[delveName] then
                local meta = E.DelveDataByName[delveName]
                local runs = meta and hist.recentRuns
                if runs then
                    local runStory  -- nil unless a qualifying run is found
                    for _, run in ipairs(runs) do
                        if run.wasBountiful
                                and (run.timestamp or 0) >= dailyResetEpoch then
                            runStory = run.story or ""
                            break
                        end
                    end
                    if runStory ~= nil then
                        local entry        = AcquireBountifulEntry()
                        entry.name         = delveName
                        entry.zone         = meta.zone
                        entry.x            = meta.x
                        entry.y            = meta.y
                        entry.mapID        = meta.mapID
                        entry.poiID        = meta.poiID
                        entry.normalPoiID  = meta.normalPoiID
                        entry.storyVariant = runStory
                        entry.overcharged  = false
                        entry.completed    = true
                        table_insert(bountifulList, entry)
                        reAddSeen[delveName] = true
                    end
                end
            end
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
-- Row rendering (reflowed list with expandable boss tactics)
------------------------------------------------------------------------
-- Forward declaration so the row/boss toggle handlers can call it.
local UpdateRows

local function DelveRow_Toggle(self)
    local d = self.delve
    if not d then return end
    expandedDelve[d.name] = not expandedDelve[d.name]
    if UpdateRows then UpdateRows() end
end

local function BossRow_OnClick(self)
    if not self.bossKey then return end
    expandedBoss[self.bossKey] = not expandedBoss[self.bossKey]
    if UpdateRows then UpdateRows() end
end

--------------------------------------------------------------------
-- Delve row factory (two-line: name + variant subtext, plus columns).
--------------------------------------------------------------------
local function CreateDelveRow()
    local row = CreateFrame("Button", nil, sc, "BackdropTemplate")
    row:SetHeight(ROW_HEIGHT)
    row:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
    row:SetBackdropColor(0.05, 0.05, 0.05, 0.20)
    row:RegisterForClicks("LeftButtonUp")
    row:SetScript("OnClick", DelveRow_Toggle)

    -- Delve name (top line; caret prefix baked into the text)
    local nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    nameText:SetPoint("TOPLEFT", row, "TOPLEFT", 4, -3)
    nameText:SetFont(nameText:GetFont(), 11)
    nameText:SetWidth(220)
    nameText:SetJustifyH("LEFT")
    nameText:SetWordWrap(false)
    row.nameText = nameText

    -- Story variant (second line)
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
    zoneText:SetWidth(100)
    zoneText:SetJustifyH("LEFT")
    zoneText:SetWordWrap(false)
    row.zoneText = zoneText

    -- Tier badge
    local tierText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    tierText:SetPoint("LEFT", row, "LEFT", 335, 0)
    tierText:SetFont(tierText:GetFont(), 11, "OUTLINE")
    tierText:SetWidth(30)
    tierText:SetJustifyH("CENTER")
    row.tierText = tierText

    -- [Pin] button
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

    -- Hover tooltip (anchored to the right of the TomTom button)
    row:SetScript("OnEnter", function(self)
        if self.delve then
            local anchorTo = self.ttBtn or self
            GameTooltip:SetOwner(anchorTo, "ANCHOR_NONE")
            GameTooltip:ClearAllPoints()
            GameTooltip:SetPoint("TOPLEFT", anchorTo, "TOPRIGHT", 8, 0)
            GameTooltip:AddLine(self.delve.name, 1, 0.84, 0, true)
            local si = GetStoryTier(self.delve.storyVariant)
            if si then
                local tc = TIER_COLORS[si.tier] or {0.6, 0.6, 0.6}
                GameTooltip:AddLine(si.tier .. " Tier", tc[1], tc[2], tc[3], true)
                GameTooltip:AddLine(si.note, 0.80, 0.80, 0.80, true)
                GameTooltip:AddLine(" ")
            end
            if self.delve.overcharged then
                GameTooltip:AddLine("Overcharged", 1, 1, 0, true)
            end
            GameTooltip:AddLine(self.delve.storyVariant,
                                0.88, 0.88, 0.88, true)
            local bosses = E.GetDelveBosses and E:GetDelveBosses(self.delve.name)
            if bosses then
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine(expandedDelve[self.delve.name]
                    and "Click to hide boss tactics"
                    or  "Click to show boss tactics", 0.55, 0.55, 0.55, true)
            end
            GameTooltip:Show()
        end
    end)
    row:SetScript("OnLeave", function()
        E:HideTooltip()
    end)

    return row
end

local function AcquireDelveRow(i)
    local row = delveRowPool[i]
    if not row then
        row = CreateDelveRow()
        delveRowPool[i] = row
    end
    row:ClearAllPoints()
    return row
end

--------------------------------------------------------------------
-- Boss sub-row factory (caret + name on line 1, brief on line 2).
--------------------------------------------------------------------
local function CreateBossRow()
    local row = CreateFrame("Button", nil, sc)
    row:RegisterForClicks("LeftButtonUp")
    row:SetScript("OnClick", BossRow_OnClick)

    local caretFS = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    caretFS:SetPoint("TOPLEFT", row, "TOPLEFT", 0, -2)
    caretFS:SetFont(caretFS:GetFont(), 11, "OUTLINE")
    row.caretFS = caretFS

    local nameFS = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    nameFS:SetPoint("TOPLEFT", caretFS, "TOPRIGHT", 6, 0)
    nameFS:SetFont(nameFS:GetFont(), 11, "OUTLINE")
    nameFS:SetJustifyH("LEFT")
    row.nameFS = nameFS

    local briefFS = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    briefFS:SetPoint("TOPLEFT", row, "TOPLEFT", 18, -17)
    briefFS:SetFont(briefFS:GetFont(), 10)
    briefFS:SetJustifyH("LEFT")
    briefFS:SetSpacing(2)
    row.briefFS = briefFS

    return row
end

local function AcquireBossRow(i)
    local row = bossRowPool[i]
    if not row then
        row = CreateBossRow()
        bossRowPool[i] = row
    end
    row:ClearAllPoints()
    return row
end

local function AcquireNoteLine(i)
    local fs = noteLinePool[i]
    if not fs then
        fs = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        fs:SetFont(fs:GetFont(), 10)
        fs:SetJustifyH("LEFT")
        fs:SetSpacing(2)
        noteLinePool[i] = fs
    end
    fs:ClearAllPoints()
    return fs
end

--------------------------------------------------------------------
-- Reflow the bountiful list + any expanded boss tactics.
--------------------------------------------------------------------
function UpdateRows()
    if not sc then return end

    for _, r in ipairs(delveRowPool) do r:Hide() end
    for _, r in ipairs(bossRowPool)  do r:Hide() end
    for _, r in ipairs(noteLinePool) do r:Hide() end

    local dUsed, bUsed, nUsed = 0, 0, 0
    local yCur = 2

    local function PlaceRow(row, x, h)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", sc, "TOPLEFT", x, -yCur)
        row:SetPoint("RIGHT",   sc, "RIGHT",  -2, 0)
        row:Show()
        yCur = yCur + h
    end

    for _, delve in ipairs(bountifulList) do
        dUsed = dUsed + 1
        local row = AcquireDelveRow(dUsed)
        row:SetParent(sc)
        row.delve = delve

        local caret = (delve.completed and E.CC.muted or E.CC.gold)
            .. (expandedDelve[delve.name] and "v" or ">") .. E.CC.close

        if delve.completed then
            row.nameText:SetText(
                caret .. " "
                .. E.CC.muted .. "\226\156\147 " .. delve.name .. E.CC.close
            )
            row.zoneText:SetText(E.CC.muted .. delve.zone .. E.CC.close)
            local completedPrefix = delve.overcharged
                and (E.CC.muted .. "Overcharged" .. E.CC.close
                         .. (delve.storyVariant ~= "" and E.CC.muted .. "  " .. E.CC.close or ""))
                or ""
            row.variantText:SetText(
                completedPrefix
                .. E.CC.muted .. delve.storyVariant .. E.CC.close
            )
            row:SetBackdropColor(0.05, 0.05, 0.05, 0.30)
        else
            row.nameText:SetText(
                caret .. " " .. E.CC.gold .. delve.name .. E.CC.close
            )
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

            local overchargedPrefix = delve.overcharged
                and (E.CC.yellow .. "Overcharged" .. E.CC.close
                     .. (delve.storyVariant ~= "" and E.CC.muted .. "  " .. E.CC.close or ""))
                or ""
            row.variantText:SetText(
                overchargedPrefix
                .. E.CC.muted .. delve.storyVariant .. E.CC.close
                .. normalNote
            )
            -- Neutral row tint (matches Delve Locations tab).
            row:SetBackdropColor(0.05, 0.05, 0.05, 0.20)
        end

        local si = GetStoryTier(delve.storyVariant)
        if si then
            local tc = TIER_COLORS[si.tier]
            if delve.completed then
                row.tierText:SetTextColor(0.40, 0.40, 0.40)
            elseif tc then
                row.tierText:SetTextColor(tc[1], tc[2], tc[3])
            else
                row.tierText:SetTextColor(0.60, 0.60, 0.60)
            end
            row.tierText:SetText(si.tier)
        else
            row.tierText:SetText("")
        end

        PlaceRow(row, 0, ROW_HEIGHT)

        -- Expanded: this delve's boss tactics (rendered identically to
        -- the Delve Locations tab — brief line + expandable full notes).
        if expandedDelve[delve.name] then
            local bosses = E.GetDelveBosses and E:GetDelveBosses(delve.name)
            if bosses then
                local todaysBoss = E.GetTodaysBossName
                    and E:GetTodaysBossName(delve.name)
                for bi, boss in ipairs(bosses) do
                    bUsed = bUsed + 1
                    local brow = AcquireBossRow(bUsed)
                    brow:SetParent(sc)
                    local bossKey = delve.name .. "##" .. bi
                    brow.bossKey = bossKey

                    local bExpanded = expandedBoss[bossKey]
                    brow.caretFS:SetText(E.CC.muted
                        .. (bExpanded and "v" or ">") .. E.CC.close)
                    if todaysBoss and boss.name == todaysBoss then
                        brow.nameFS:SetText(
                            "|TInterface\\Common\\FavoritesIcon:14:14|t "
                            .. E.CC.gold .. boss.name .. E.CC.close
                            .. E.CC.muted .. "   (today's boss)" .. E.CC.close)
                    else
                        brow.nameFS:SetText(E.CC.white .. boss.name .. E.CC.close)
                    end

                    local briefW = math_max(150, (sc:GetWidth() or 600) - 18 - 16)
                    brow.briefFS:SetWidth(briefW)
                    brow.briefFS:SetText(E.CC.muted .. (boss.brief or "") .. E.CC.close)

                    local bh = 18 + (brow.briefFS:GetStringHeight() or 12) + 6
                    brow:SetHeight(bh)
                    PlaceRow(brow, 24, bh)

                    if bExpanded and boss.notes then
                        for _, note in ipairs(boss.notes) do
                            nUsed = nUsed + 1
                            local nl = AcquireNoteLine(nUsed)
                            nl:SetParent(sc)
                            local w = math_max(150, (sc:GetWidth() or 600) - 48 - 12)
                            nl:SetWidth(w)
                            nl:SetText(
                                RoleCC(note.role) .. RoleLabel(note.role) .. "|r  "
                                .. E.CC.body .. note.text .. E.CC.close)
                            local h = (nl:GetStringHeight() or 12) + 5
                            nl:SetPoint("TOPLEFT", sc, "TOPLEFT", 48, -yCur)
                            nl:Show()
                            yCur = yCur + h
                        end
                    end
                end
            end
        end
    end

    sc:SetHeight(yCur + 8)
    if UpdateScrollRange then UpdateScrollRange() end
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
    statValues.resetTimer    = CreateStatRow(frame, "Bountiful Reset:", STAT_Y - 18, COL2_X)
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
    -- DAILY BOUNTIFUL PROGRESS BAR (the bountiful set rotates daily)
    --------------------------------------------------------------------
    local progressBar = E:CreateProgressBar(frame, 0, 14, "Bountiful Delves Completed")
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
    E:StyleAccentHeader(listHeader, "Today's Bountiful Delves")

    -- Best Pick subtitle — updated by UpdateBestPick on each data refresh
    bestPickFS = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    bestPickFS:SetPoint("TOPLEFT", listHeader, "BOTTOMLEFT", 2, -2)
    bestPickFS:SetFont(bestPickFS:GetFont(), 10)
    bestPickFS:SetJustifyH("LEFT")

    -- Permanent grey line below the header + Best Pick line.
    local headerLineBot = frame:CreateTexture(nil, "ARTWORK")
    headerLineBot:SetHeight(1)
    headerLineBot:SetPoint("TOPLEFT",  frame, "TOPLEFT",  8,   LIST_Y - 44)
    headerLineBot:SetPoint("TOPRIGHT", frame, "TOPLEFT", 462,  LIST_Y - 44)
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
        UpdateRows()
        UpdateBestPick()
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
    local COL_Y = LIST_Y - 50
    for _, col in ipairs({
        { label = "Delve Name",  x = 8   },
        { label = "Zone",        x = 234 },
        { label = "Tier",        x = 338 },
        { label = "Pin",         x = 374 },
        { label = "TomTom",      x = 412 },
    }) do
        local fs = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        fs:SetPoint("TOPLEFT", frame, "TOPLEFT", col.x, COL_Y)
        fs:SetFont(fs:GetFont(), 10, "OUTLINE")
        E:StyleAccentHeader(fs, col.label)
    end

    -- Scrollable list (boss tactics expand inline, so the list can grow
    -- past the visible area).
    scrollFrame = CreateFrame("ScrollFrame", nil, frame)
    scrollFrame:SetPoint("TOPLEFT",     frame, "TOPLEFT",  4, COL_Y - 16)
    scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -22, 4)
    scrollFrame:EnableMouseWheel(true)
    frame.listFrame = scrollFrame
    local listFrame = scrollFrame

    sc = CreateFrame("Frame")
    sc:SetSize(1, 1)
    scrollFrame:SetScrollChild(sc)
    scrollFrame:SetScript("OnSizeChanged", function(_, w) sc:SetWidth(w) end)
    sc:SetHeight(1)

    scrollBar = CreateFrame("Slider", nil, scrollFrame, "BackdropTemplate")
    scrollBar:SetWidth(14)
    scrollBar:SetPoint("TOPRIGHT",    scrollFrame, "TOPRIGHT",    16, 0)
    scrollBar:SetPoint("BOTTOMRIGHT", scrollFrame, "BOTTOMRIGHT", 16, 0)
    scrollBar:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    scrollBar:SetBackdropColor(0.08, 0.08, 0.08, 0.90)
    scrollBar:SetBackdropBorderColor(0.25, 0.25, 0.25, 0.50)
    local sbThumb = scrollBar:CreateTexture(nil, "OVERLAY")
    sbThumb:SetSize(12, 40)
    E:StyleAccentThumb(sbThumb)
    scrollBar:SetThumbTexture(sbThumb)
    scrollBar:SetOrientation("VERTICAL")
    scrollBar:SetMinMaxValues(0, 1)
    scrollBar:SetValue(0)
    scrollBar:SetValueStep(1)
    scrollBar:SetObeyStepOnDrag(true)
    scrollBar:SetScript("OnValueChanged", function(_, value)
        scrollFrame:SetVerticalScroll(value)
    end)
    scrollFrame:SetScript("OnMouseWheel", function(self, delta)
        local maxScroll = math_max(0, sc:GetHeight() - self:GetHeight())
        local newVal = math_max(0, math.min(
            self:GetVerticalScroll() - delta * 30, maxScroll))
        self:SetVerticalScroll(newVal)
        scrollBar:SetValue(newVal)
    end)
    function UpdateScrollRange()
        local maxScroll = math_max(0, sc:GetHeight() - scrollFrame:GetHeight())
        scrollBar:SetMinMaxValues(0, maxScroll)
        if maxScroll <= 0 then
            scrollBar:Hide()
        else
            scrollBar:Show()
        end
    end

    -- Store progressBar reference for compatibility with existing hooks
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

        UpdateRows()
        UpdateBestPick()
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
        -- Always refresh the data so E.currentBountifulNames stays
        -- current for other systems (Gilded Stash tracking, Delve
        -- Locations gold asterisks) regardless of which tab is open.
        RefreshBountifulData()
        if frame:IsShown() then
            RefreshStats()
            local done = 0
            for _, d in ipairs(bountifulList) do
                if d.completed then done = done + 1 end
            end
            progressBar:SetProgress(done, math_max(1, #bountifulList))
            UpdateRows()
            UpdateBestPick()
        end
    end)

    --------------------------------------------------------------------
    -- Register with the main frame tab system
    --------------------------------------------------------------------
    E:RegisterTab(2, frame)

    -- Seed initial data
    RefreshBountifulData(true)
end)

------------------------------------------------------------------------
-- Public hook: let other modules force a bountiful-data refresh.
-- Used by BeginDelveRun in EverythingDelves.lua so the bountiful
-- lookup table is guaranteed current at delve entry, even if the
-- Bountiful tab has never been opened this session. Internally
-- debounced (2 s) so this is cheap to call repeatedly.
------------------------------------------------------------------------
function E:RefreshBountifulData(force)
    RefreshBountifulData(force)
    -- One-shot per session: if PLAYER_LOGIN flagged a repair, fire it
    -- now that the live bountiful names are populated. AutoRepair
    -- internally clears the flag and no-ops on subsequent calls.
    if E._autoRepairPending and E.AutoRepairBountifulHistory then
        E:AutoRepairBountifulHistory()
    end
end
