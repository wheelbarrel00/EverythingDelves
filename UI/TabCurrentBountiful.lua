local E = EverythingDelves
local L = E.L

local pairs, ipairs = pairs, ipairs
local math_floor, math_max = math.floor, math.max
local string_format = string.format
local table_insert, table_sort, wipe = table.insert, table.sort, wipe
local strtrim = strtrim

-- Several Blizzard UI frames live in load-on-demand addons not in memory
-- until first opened; ElvUI preloads them, masking the issue. Force-load here.
local function EnsureBlizzardAddon(addonName)
    ---@diagnostic disable-next-line: undefined-global
    local loader = (C_AddOns and C_AddOns.LoadAddOn) or LoadAddOn
    if not loader then return false end
    local ok, loaded = pcall(loader, addonName)
    return ok and (loaded ~= false)
end

local TIER_ORDER = E.DelveList.GRADE_ORDER

local STORY_TIERS = {
    -- Grades from Moleman's Delve Compendium (Midnight S2), best Tier 1 times:
    -- S under 1:00, then one grade per 15 seconds, F over 2:00.
    ["Sporasaur Special"]             = { tier="S", note=L["Kite dinos and kick spores back to break their shields for bonus damage."] },
    ["Sporasaurus Surprise"]          = { tier="S", note=L["Kite dinos and kick spores back to break their shields for bonus damage."] },
    ["Ogre Powered"]                  = { tier="A", note=L["Straight shot to boss. Kill Unstable Aberrations before moving on."] },
    ["Adopt-a-thon"]                  = { tier="A", note=L["Rescue the small animals caught in the middle of the gladiator fights."] },
    ["Holding the Line"]              = { tier="A", note=L["Head down the staircase; kill enemies (not heal allies) for the fastest route."] },
    ["Invasive Glow"]                 = { tier="A", note=L["Bomb DoT scales with tier — keep it rolling and the clear is trivial."] },
    ["Party Crasher"]                 = { tier="B", note=L["Hit levers to disable traps while defeating 4 Twilight Summoners."] },
    ["Eggsplosive Growth"]            = { tier="B", note=L["Destroy the Children of Ula'tek eggs nesting in the tunnels using the Venom-Clogged Leyline pylons."] },
    ["Academy Under Siege"]           = { tier="B", note=L["Scattered powerful items help, but it can't match Invasive Glow."] },
    ["Core of the Problem"]           = { tier="B", note=L["Use portals to shortcut around the map. Kill enemies and collect orbs."] },
    ["Toadly Unbecoming"]             = { tier="C", note=L["Decurse frogs to spawn the boss. Open layout adds traverse time even when mounted."] },
    ["Traitor's Due"]                 = { tier="C", note=L["Large unwalkable map. Defeat void foci and elites with the Eye of Antenorian buff."] },
    ["Game Day"]                      = { tier="C", note=L["Ghostly Headball - collect skulls from your kills and kick them at the pillars to score."] },
    ["Open Night"]                    = { tier="C", note=L["An arena gauntlet - clear the floor, then the champions, then Drakta."] },
    ["Trapped"]                       = { tier="C", note=L["Teleported inside — must rescue hostages on the way back to the entrance."] },
    ["Focusers Under Pressure"]       = { tier="C", note=L["Large crystal collection loop adds time compared to Ogre Powered."] },
    ["Calamitous"]                    = { tier="C", note=L["Enormous mountable map with required secondary objectives in all three variants."] },
    ["Venomous Vapors"]               = { tier="D", note=L["Escort Marla and clear the Children of Ula'tek poison contamination. Ends on Disciple of Vash'nik."] },
    ["Totem Annihilation"]            = { tier="D", note=L["Take the bird north. Avoid the captured loa's lightning — it hits hard."] },
    ["Arena Champion"]                = { tier="D", note=L["Defeat two named enemies then collect mold samples from Moldering Fighters."] },
    ["Faculty of Fear"]               = { tier="D", note=L["Revelation mechanic requires revealing many NPCs, adding significant time."] },
    ["Not What I Expected"]           = { tier="D", note=L["Click Lightbloom crates and activate security. Displacement Portal clones help in combat."] },
    ["Alnmoth Munchies"]              = { tier="D", note=L["Same quick route as Sporasaur Special but extra objectives slow it down."] },
    ["Academic Antitoxin"]            = { tier="D", note=L["Brew an antidote with Sir Finley - cleanse poison patches and heal students. No final boss."] },
    ["An Elementary Antidote"]        = { tier="D", note=L["Brew an antidote with Sir Finley - cleanse poison patches and heal students. No final boss."] },
    ["Ritual Interrupted"]            = { tier="D", note=L["Navigate south freeing furbolgs. Haunted weapons deal decent bonus damage."] },
    ["Basilisk Blitz"]                = { tier="D", note=L["Divert the shields, then kill the basilisks channeling energy to the boss."] },
    ["Basalisk Blitz"]                = { tier="D", note=L["Divert the shields, then kill the basilisks channeling energy to the boss."] },
    ["Loosed Loa"]                    = { tier="D", note=L["Use Evasive Elixir before the patrolling loa attacks to avoid a big stun."] },
    ["Loose Loa"]                     = { tier="D", note=L["Use Evasive Elixir before the patrolling loa attacks to avoid a big stun."] },
    ["Mirror Shine"]                  = { tier="F", note=L["Repositioning mirrors to reflect light is tedious. Mind positioning to avoid debuffs."] },
    ["Leyline Technician"]            = { tier="F", note=L["Inspecting every leyline adds a lot of time."] },
    ["Caustic Crush"]                 = { tier="F", note=L["Stop the Children of Ula'tek summoning slimes, using Fungal Pharmacon and dodging the caustic waves."] },
    ["Shadowy Supplies"]              = { tier="F", note=L["Collecting 30 supplies from enemies and the floor is very slow."] },
    ["Why Did it Have to Be Snakes?"] = { tier="F", note=L["Hunt snake relics through the crypts, clearing poison patches with Fungal Pharmacon."] },
    ["Why'd It Have to Be Snakes?"]   = { tier="F", note=L["Hunt snake relics through the crypts, clearing poison patches with Fungal Pharmacon."] },
    ["Descent of the Haranir"]        = { tier="F", note=L["Same quick pathing as Sporasaur but extra objectives add considerable time."] },
    ["Captured Wildlife"]             = { tier="F", note=L["Free caged wildlife; use worm bait on Void Researchers to spawn the boss."] },
    ["Captured Wild"]                 = { tier="F", note=L["Free caged wildlife; use worm bait on Void Researchers to spawn the boss."] },
    ["Captured Widlife"]              = { tier="F", note=L["Free caged wildlife; use worm bait on Void Researchers to spawn the boss."] },
    ["Dastardly Rotstalk"]            = { tier="F", note=L["Taunt the crowd, click dirt piles, defeat spawns carefully to avoid being overwhelmed."] },
    ["Dastardly Rootstalks"]          = { tier="F", note=L["Taunt the crowd, click dirt piles, defeat spawns carefully to avoid being overwhelmed."] },
    ["Speaking Their Language"]       = { tier="F", note=L["Rescue the turtles and the supplies the Djaradin stole, then send the siege-trained turtles in as tanks."] },
    ["Lightbloom Invasion"]           = { tier="F", note=L["Free fighters and defend barricades against Thornmaws using nearby barrels."] },
    ["The Gravitational Effect"]      = { tier="F", note=L["Flying to collect Singularity Coils breaks the route significantly."] },
    ["Olds and Ends"]                 = { tier="F", note=L["Ally with the Tortollan Tormunda to rescue the elders the Djaradin captured, and recover their relics."] },
    ["Infiltrate and Ameliorate"]     = { tier="F", note=L["Sabotage the summoning - kick summoners into the abyss and spike the cauldrons with the wrong ingredients."] },
    ["Minchi's Osseous Adventure"]    = { tier="F", note=L["Search the bone piles and take hearts from the Gnarldor Djaradin to summon the Osseous Amalgamation."] },
    ["Minchi's Osseous Adventurer"]   = { tier="F", note=L["Search the bone piles and take hearts from the Gnarldor Djaradin to summon the Osseous Amalgamation."] },
    ["March of the Arcane Brigade"]   = { tier="F", note=L["Activating sentinels is slow with no direct path to the boss."] },
    ["March of the Arcane Parade"]    = { tier="F", note=L["Activating sentinels is slow with no direct path to the boss."] },
    ["Bombing Run"]                   = { tier="F", note=L["Destroying void portals makes for one of the slowest clears."] },
    ["Stolen Mana"]                   = { tier="F", note=L["Use the Galvanic Rifle on mana barrels and free 8 prisoners from Mana Siphoners."] },
    ["Fungal Pharmacon"]              = { tier="F", note=L["Loot Fungal Pharmacon from around the pit and break the four pillars the Children of Ula'tek burrow through."] },
}

local function StripStoryPrefix(s)
    if not s or s == "" then return "" end
    local plain = E.StripColorEscapes(s)
    return plain:match("[Vv]ariant:%s*(.-)%s*$") or plain:match("^%s*(.-)%s*$") or plain
end

local function GetStoryTier(storyVariant)
    if not storyVariant or storyVariant == "" then return nil end
    if STORY_TIERS[storyVariant] then return STORY_TIERS[storyVariant] end
    local plain = E.StripColorEscapes(storyVariant)
    if STORY_TIERS[plain] then return STORY_TIERS[plain] end
    local name = plain:match("[Vv]ariant:%s*(.-)%s*$")
    if name and STORY_TIERS[name] then return STORY_TIERS[name] end
    local lower = plain:lower()
    for key, data in pairs(STORY_TIERS) do
        if lower:find(key:lower(), 1, true) then return data end
    end
    return nil
end

function E:GetStoryTier(storyVariant)
    return GetStoryTier(storyVariant)
end

local bountifulList  = {}
local reAddSeen      = {}

-- Recycled delve-entry tables: the bountiful list is rebuilt on every
-- OnShow / area-POI update / refresh click, so pool to avoid churn.
local bountifulEntryPool = {}

local sawLivePOI = false

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

-- A delve POI with atlasName "delves-bountiful" is bountiful today;
-- two icon widgets in its iconWidgetSet means "overcharged".

-- GetAllWidgetsBySetID() allocates a fresh table per call, and AREA_POIS_UPDATED
-- bursts during zone transitions (twice per POI: icon + tooltip set). Cache by TTL.
local widgetSetCache = {}        -- [setID] = { widgets, expires }
local WIDGET_CACHE_TTL = 5

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
                                    storyVariant = E.StripColorEscapes(viz.text or "")
                                    break
                                end
                            end
                        end
                    end
                end

                local entry        = AcquireBountifulEntry()
                entry.name         = poi.name or delve.name
                -- Live POI name can differ from the canonical DelveData name
                -- (POI "Twilight Crypts" vs canonical "Twilight Crypt"); lookups
                -- elsewhere use the canonical name, so keep both.
                entry.canonicalName = delve.name
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
    if #out > 0 then sawLivePOI = true end
end

local function GetCurrencyAmount(currencyID)
    -- C_CurrencyInfo.GetCurrencyInfo is display-only, permitted in 12.0.
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

-- maxQuantity is a static 0 for this currency, so the ceiling that means
-- anything is the weekly earn cap.
local function GetCofferShards()
    if C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo then
        local info = C_CurrencyInfo.GetCurrencyInfo(E.CurrencyIDs.cofferKeyShards)
        if info then
            return info.quantity or 0,
                   info.quantityEarnedThisWeek or 0,
                   info.maxWeeklyQuantity or 0
        end
    end
    return 0, 0, 0
end

local function KeysFromShards(shards)
    return math_floor(shards / E.SHARDS_PER_KEY)
end

-- Bountiful delves + story variants reroll on the DAILY reset (vault /
-- Gilded Stash / bounties are weekly), so this tab shows the daily countdown.
local function GetResetTimeString()
    if C_DateAndTime and C_DateAndTime.GetSecondsUntilDailyReset then
        local secs = C_DateAndTime.GetSecondsUntilDailyReset()
        if secs and secs > 0 then
            local hours = math_floor(secs / 3600)
            local mins  = math_floor((secs % 3600) / 60)
            return string_format(L["Resets in %dh %dm"], hours, mins)
        end
    end
    return L["Reset timer unavailable"]
end

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
    return 0, 0, 1
end

-- Incomplete first, then by tier, then alphabetical.
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

local lastBountifulRefresh = 0
local function RefreshBountifulData(force)
    local now = GetTime()
    if not force and (now - lastBountifulRefresh < 2) then return end
    lastBountifulRefresh = now

    PopulateBountifulDelvesLive(bountifulList)

    -- Daily reset boundary (run.timestamp is time()-based; 0 if API unavailable).
    -- Shared by the completion sweep and the dropped-off re-add below.
    local dailyResetEpoch = 0
    if C_DateAndTime and C_DateAndTime.GetSecondsUntilDailyReset then
        local secs = C_DateAndTime.GetSecondsUntilDailyReset()
        if secs and secs > 0 then
            dailyResetEpoch = time() + secs - 86400
        end
    end

    -- A bountiful delve counts as done once it has a run logged since today's reset.
    if E.db and E.db.delveHistory and dailyResetEpoch > 0 then
        for _, delve in ipairs(bountifulList) do
            if not delve.completed then
                -- Runs log under the canonical name; the POI name can differ
                -- (e.g. "Twilight Crypts" vs "Twilight Crypt").
                local hist = E.db.delveHistory[delve.name]
                    or (delve.canonicalName
                        and E.db.delveHistory[delve.canonicalName])
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
    if not E.currentBountifulNames     then E.currentBountifulNames     = {} end
    if not E.currentBountifulPOIs      then E.currentBountifulPOIs      = {} end
    if not E.currentBountifulStory     then E.currentBountifulStory     = {} end
    if not E.currentBountifulStoryTier then E.currentBountifulStoryTier = {} end
    wipe(E.currentBountifulNames)
    wipe(E.currentBountifulPOIs)
    wipe(E.currentBountifulStory)
    wipe(E.currentBountifulStoryTier)
    E.currentBountifulCount = #bountifulList
    for _, delve in ipairs(bountifulList) do
        E.currentBountifulNames[delve.name] = true
        local norm = strtrim(delve.name):lower()
        E.currentBountifulNames[norm] = true
        -- Also key by canonical name: callers that look up by canonical
        -- (wasBountiful check, Delve Locations highlight, AutoRepairBountifulHistory)
        -- would otherwise miss when the POI label differs from canonical.
        if delve.canonicalName and delve.canonicalName ~= delve.name then
            E.currentBountifulNames[delve.canonicalName] = true
            E.currentBountifulNames[strtrim(delve.canonicalName):lower()] = true
        end
        if delve.poiID then
            E.currentBountifulPOIs[delve.poiID] = true
        end
        local si = GetStoryTier(delve.storyVariant)
        E.currentBountifulStory[delve.name]     = StripStoryPrefix(delve.storyVariant)
        E.currentBountifulStoryTier[delve.name] = si and si.tier or nil
    end

    -- Completing a bountiful delve removes its "delves-bountiful" atlas, so it
    -- drops out of the live list and the progress bar would shrink its
    -- denominator (0/4 -> 0/3) instead of counting it. Reconstruct the full
    -- daily set from delveHistory. Added to bountifulList ONLY (not
    -- E.currentBountifulNames) and AFTER the names build above, so a completed
    -- delve is not treated as still-bountiful by the wasBountiful stamp or
    -- AutoRepairBountifulHistory (which would re-inflate the Gilded Stash count).
    if E.db and E.db.delveHistory and dailyResetEpoch > 0 and E.DelveDataByName then
        wipe(reAddSeen)
        -- Seed both names: the loop below keys delveHistory by canonical name,
        -- so a POI-only seed would re-add a name-mismatched delve as a duplicate.
        for _, d in ipairs(bountifulList) do
            reAddSeen[d.name] = true
            if d.canonicalName then reAddSeen[d.canonicalName] = true end
        end
        for delveName, hist in pairs(E.db.delveHistory) do
            if not reAddSeen[delveName] then
                local meta = E.DelveDataByName[delveName]
                local runs = meta and hist.recentRuns
                if runs then
                    local runStory
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
                        entry.storyVariant = E.StripColorEscapes(runStory)
                        entry.overcharged  = false
                        entry.completed    = true
                        table_insert(bountifulList, entry)
                        reAddSeen[delveName] = true
                    end
                end
            end
        end
    end

    -- Must run AFTER the re-add above: a completed delve drops off the POI list,
    -- and comparing without it reads as a rotation change.
    if #bountifulList > 0 and E.db and E.db.alertNewBountiful then
        if not E._bountifulIDBuf then E._bountifulIDBuf = {} end
        local currentIDs = E._bountifulIDBuf
        wipe(currentIDs)
        for _, delve in ipairs(bountifulList) do
            if delve.poiID then table_insert(currentIDs, delve.poiID) end
        end
        table_sort(currentIDs)

        local storedIDs   = E.db.lastKnownBountifulIDs or {}
        local storedEpoch = E.db.lastKnownBountifulEpoch or 0

        -- A shorter list on the same day means POI data is incomplete, not a new rotation.
        if #currentIDs >= #storedIDs or dailyResetEpoch > storedEpoch then
            local changed = (#currentIDs ~= #storedIDs)
            if not changed then
                for i, id in ipairs(currentIDs) do
                    if id ~= storedIDs[i] then
                        changed = true
                        break
                    end
                end
            end

            -- storedEpoch 0 = a pre-upgrade baseline that may be missing completions.
            if changed and #storedIDs > 0 and storedEpoch > 0 then
                print("|cFFFF2222[Everything Delves]|r "
                    .. L["New Bountiful Delves are available today! Open Everything Delves to see them."])
            end
            if not E.db.lastKnownBountifulIDs then E.db.lastKnownBountifulIDs = {} end
            wipe(E.db.lastKnownBountifulIDs)
            for i = 1, #currentIDs do
                E.db.lastKnownBountifulIDs[i] = currentIDs[i]
            end
            E.db.lastKnownBountifulEpoch = dailyResetEpoch
        end
    end

    SortBountifulList()
end


local PAD_TOP, PAD_LEFT, PAD_RIGHT, PAD_BOTTOM = 20, 24, 14, 28
local BAR_H, HINT_GAP, HINT_H, SUMMARY_GAP, BUTTON_GAP = 32, 10, 16, 16, 10
local GROUP_GAP, CARD_ROW, CARD_PAD, PAIR_GAP, ITEM_ICON = 22, 44, 14, 10, 16
local EMPTY_H, EMPTY_INSET, UNLOCK_LEVEL, DIM = 64, 40, 68, 0.4
local SEP = "   \226\128\162   "

local COLUMNS = {
    { key = "zone", label = L["Zone"], width = 132 },
    { key = "tier", label = L["Tier"], width = 34, align = "CENTER", weight = "navActive" },
}

local pageFrame, RenderView

local function OpenGreatVault()
    -- Blizzard_WeeklyRewards is load-on-demand.
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
        print(E.CC.header .. "Everything Delves|r: " .. L["Great Vault UI could not be loaded."])
    end
end

local function OpenDelveLFG()
    -- Blizzard_GroupFinder / Blizzard_PVPUI are load-on-demand.
    if not PVEFrame or not LFGListFrame then
        EnsureBlizzardAddon("Blizzard_GroupFinder")
        EnsureBlizzardAddon("Blizzard_PVPUI")
    end
    if not PVEFrame then
        print(E.CC.header .. "Everything Delves|r: " .. L["LFG UI could not be loaded."])
        return
    end
    if not PVEFrame:IsShown() then
        PVEFrame_ToggleFrame()
    end
    if GroupFinderFrameGroupButton3 then
        GroupFinderFrameGroupButton3:Click()
    end
    -- Category 121 is the Delves LFG category.
    if LFGListFrame and LFGListFrame.CategorySelection and LFGListCategorySelection_SelectCategory then
        LFGListCategorySelection_SelectCategory(LFGListFrame.CategorySelection, 121, 0)
        if LFGListFrame.CategorySelection.StartGroupButton then
            LFGListFrame.CategorySelection.StartGroupButton:Click()
        end
    end
    if LFGListFrame and LFGListFrame.EntryCreation and LFGListFrame.EntryCreation.GroupDropdown
            and LFGListFrame.EntryCreation.GroupDropdown.OpenMenu then
        LFGListFrame.EntryCreation.GroupDropdown:OpenMenu()
    end
end

local function LFGBlocked()
    if IsInRaid() then return L["Cannot list while in a raid group."] end
    if IsInGroup() and not UnitIsGroupLeader("player") then return L["Only the group leader can list."] end
end

local function NormalAvailable(delve)
    if delve.completed or not (delve.normalPoiID and delve.mapID and C_AreaPoiInfo and C_AreaPoiInfo.GetAreaPOIInfo) then
        return false
    end
    return C_AreaPoiInfo.GetAreaPOIInfo(delve.mapID, delve.normalPoiID) ~= nil
end

local function TipBody(delve, bossName, expanded)
    local lines = {}
    local si = GetStoryTier(delve.storyVariant)
    if si then
        if si.tier then lines[#lines + 1] = L["%s Tier"]:format(si.tier) end
        if si.note then lines[#lines + 1] = si.note end
        lines[#lines + 1] = ""
    end
    if delve.overcharged then lines[#lines + 1] = L["Overcharged"] end
    lines[#lines + 1] = delve.storyVariant or ""
    if E:GetDelveBosses(bossName) then
        lines[#lines + 1] = ""
        lines[#lines + 1] = expanded and L["Click to hide boss tactics"] or L["Click to show boss tactics"]
    end
    return table.concat(lines, "\n")
end

local function BuildModels(list)
    local models = {}
    for i, delve in ipairs(bountifulList) do
        local done = delve.completed and true or nil
        local si = GetStoryTier(delve.storyVariant)
        local story = StripStoryPrefix(delve.storyVariant)
        if NormalAvailable(delve) then
            story = (story ~= "" and (story .. "  ") or "") .. L["(Normal version available)"]
        end
        local bossName = delve.canonicalName or delve.name
        models[i] = {
            key = delve.name, delve = delve, bossName = bossName, name = delve.name, done = done,
            line2 = { tag = delve.overcharged and L["Overcharged"] or nil, text = story },
            cells = {
                zone = { text = delve.zone, muted = done },
                tier = E.DelveList.GradeCell(si and si.tier, done),
            },
            tip = { delve.name, TipBody(delve, bossName, list.expanded[delve.name]) },
        }
    end
    local lab = E.DelveList.Labyrinth()
    models[#models + 1] = {
        key = lab.key, delve = lab.entrance, name = lab.name, bountiful = lab.open or nil,
        line2 = { text = lab.locked or (L["Always bountiful"] .. SEP .. lab.coffers) },
        cells = { zone = { text = lab.zone } },
        tip = lab.tip,
    }
    return models
end

local function BestPickText()
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
    local si = best and GetStoryTier(best.storyVariant)
    if not (si and si.tier) then return "" end
    local muted, label = E.DelveList.cc("muted"), E.DelveList.cc("label")
    return muted .. L["Best Pick:"] .. "|r " .. label .. best.name .. "|r"
        .. muted .. SEP .. "|r" .. label .. StripStoryPrefix(best.storyVariant) .. "|r"
        .. muted .. SEP .. "|r" .. E:GetGradeCC(si.tier) .. L["%s Tier"]:format(si.tier) .. "|r"
end

local function NewCard(content)
    local ui = E.ui
    local card = CreateFrame("Frame", nil, content)
    ui:Paint(card, "surface", "surfaceBorder")
    card:SetHeight(CARD_ROW * 4)
    local rows = {}
    for i = 1, 4 do
        local r = CreateFrame("Frame", nil, card)
        r:SetPoint("TOPLEFT", card, "TOPLEFT", 0, -(i - 1) * CARD_ROW)
        r:SetPoint("TOPRIGHT", card, "TOPRIGHT", 0, -(i - 1) * CARD_ROW)
        r:SetHeight(CARD_ROW)
        if i > 1 then ui:Paint(r, nil, "divider", "T") end
        rows[i] = r
    end

    card.doneLabel = ui:CreateText(rows[1], L["Bountiful Delves Completed"], "label")
    card.doneLabel:SetPoint("LEFT", rows[1], "LEFT", CARD_PAD, 0)
    card.doneValue = ui:CreateText(rows[1], "", "value")
    card.doneValue:SetPoint("RIGHT", rows[1], "RIGHT", -CARD_PAD, 0)
    card.bar = ui:CreateProgressBar(rows[1])
    card.bar:SetPoint("LEFT", card.doneLabel, "RIGHT", CARD_PAD, 0)
    card.bar:SetPoint("RIGHT", card.doneValue, "LEFT", -CARD_PAD, 0)

    card.values, card.icons = {}, {}
    local function pair(row, right, label, key, icon)
        local lbl = ui:CreateText(row, label, "label")
        local first = lbl
        if icon then
            first = row:CreateTexture(nil, "ARTWORK")
            first:SetSize(ITEM_ICON, ITEM_ICON)
            card.icons[key] = first
        end
        if right then
            first:SetPoint("LEFT", row, "CENTER", CARD_PAD / 2, 0)
        else
            first:SetPoint("LEFT", row, "LEFT", CARD_PAD, 0)
        end
        if icon then lbl:SetPoint("LEFT", first, "RIGHT", PAIR_GAP, 0) end
        local v = ui:CreateText(row, "", "value")
        v:SetWordWrap(false)
        v:SetPoint("LEFT", lbl, "RIGHT", PAIR_GAP, 0)
        if right then
            v:SetPoint("RIGHT", row, "RIGHT", -CARD_PAD, 0)
        else
            v:SetPoint("RIGHT", row, "CENTER", -CARD_PAD / 2, 0)
        end
        card.values[key] = v
    end
    pair(rows[2], false, L["Bountiful Keys:"], "keys", true)
    pair(rows[2], true, L["Journey:"], "journey")
    pair(rows[3], false, L["Coffer Key Shards:"], "shards", true)
    pair(rows[3], true, L["Bountiful Reset:"], "reset")
    pair(rows[4], false, L["Keys from Shards:"], "fromShards")
    pair(rows[4], true, L["Session Completions:"], "session")
    return card
end

local function RefreshStats(card)
    local keys = GetBountifulKeys()
    local shards, shardsThisWeek, weeklyCap = GetCofferShards()
    local stage, cur, stageMax = GetJourneyProgress()
    local sessionDone = (E.sessionData and E.sessionData.bountifulCompleted) or 0
    local muted = E.DelveList.cc("muted")
    local v = card.values

    card.icons.keys:SetTexture(E.CachedIcons.cofferKey or C_Item.GetItemIconByID(E.ItemIcons.cofferKey))
    card.icons.shards:SetTexture(E.CachedIcons.cofferShard or C_Item.GetItemIconByID(E.ItemIcons.cofferShard))
    v.keys:SetText(tostring(keys))
    v.shards:SetText(shards .. (weeklyCap > 0
        and ("  " .. muted .. L["(%d / %d this week)"]:format(shardsThisWeek, weeklyCap) .. "|r") or ""))
    v.fromShards:SetText(KeysFromShards(shards) .. "  " .. muted .. "(" .. shards .. " / " .. E.SHARDS_PER_KEY .. ")|r")
    v.journey:SetText(L["Stage %d"]:format(stage) .. " " .. muted .. "- " .. cur .. " / " .. stageMax .. "|r")
    v.reset:SetText(GetResetTimeString())
    v.session:SetText(tostring(sessionDone))

    local done = 0
    for _, d in ipairs(bountifulList) do
        if d.completed then done = done + 1 end
    end
    card.doneValue:SetText(done .. " / " .. #bountifulList)
    card.bar:SetProgress(#bountifulList > 0 and (done / #bountifulList) or 0)
end

E:RegisterModule(function()
    local ui = E.ui
    local frame = CreateFrame("Frame", "EverythingDelvesTab2Content")
    pageFrame = frame
    local area = ui:CreateScrollArea(frame, { clearGrip = true })
    area:SetAllPoints(frame)
    local content = area.content
    local Render

    local lfgBtn = ui:CreateButton(content, L["Start LFG"], nil, function()
        if not LFGBlocked() then OpenDelveLFG() end
    end)
    lfgBtn:SetScript("OnEnter", function(self)
        ui:ShowTooltip(self, L["Start LFG"], LFGBlocked() or L["Open the Group Finder to list a Delve group."])
    end)
    lfgBtn:SetScript("OnLeave", function() ui:HideTooltip() end)
    local vaultBtn = ui:CreateButton(content, L["Great Vault"], nil, OpenGreatVault, L["Open the Great Vault reward panel."])
    local refreshBtn = ui:CreateButton(content, L["Refresh"], nil, function()
        RefreshBountifulData(true)
        Render()
    end, L["Re-query bountiful delve data and currency values."])

    local summary = ui:CreateText(content, "", "label")
    summary:SetWordWrap(false)
    local hint = ui:CreateText(content, L["Today's Bountiful Delves"], "hint")
    hint:SetWordWrap(false)
    local message = ui:CreateEmptyState(content, "")

    local list = E.DelveList.New(content, {
        columns = COLUMNS, nameLabel = L["Delve Name"],
        onChange = function() Render() end,
    })
    local card = NewCard(content)

    local function RefreshLFGButton()
        lfgBtn:SetAlpha(LFGBlocked() and DIM or 1)
    end

    local lastWidth = 0
    local function ViewWidth()
        local w = area.scroll:GetWidth() or 0
        if w <= 0 then w = (frame:GetWidth() or 0) - 10 end
        return math_max(1, w)
    end

    local function PlaceMessage(y, text)
        message:SetText(text)
        message:ClearAllPoints()
        message:SetPoint("TOPLEFT", content, "TOPLEFT", EMPTY_INSET, -(y + EMPTY_H / 2 - 8))
        message:SetPoint("TOPRIGHT", content, "TOPRIGHT", -EMPTY_INSET, -(y + EMPTY_H / 2 - 8))
        message:Show()
        return y + EMPTY_H
    end

    function Render()
        local width = ViewWidth()
        lastWidth = width
        content:SetWidth(width)
        local low = UnitLevel("player") < UNLOCK_LEVEL

        local prev
        for _, btn in ipairs({ lfgBtn, vaultBtn, refreshBtn }) do
            btn:Fit()
            btn:ClearAllPoints()
            if prev then
                btn:SetPoint("RIGHT", prev, "LEFT", -BUTTON_GAP, 0)
            else
                btn:SetPoint("TOPRIGHT", content, "TOPRIGHT", -PAD_RIGHT, -PAD_TOP)
            end
            prev = btn
        end
        refreshBtn:SetShown(not low)
        summary:ClearAllPoints()
        summary:SetPoint("LEFT", content, "TOPLEFT", PAD_LEFT, -(PAD_TOP + BAR_H / 2))
        summary:SetPoint("RIGHT", low and vaultBtn or refreshBtn, "LEFT", -SUMMARY_GAP, 0)
        summary:SetText(low and "" or BestPickText())

        local y = PAD_TOP + BAR_H + HINT_GAP
        message:Hide()
        if low then
            hint:Hide()
            list:Hide()
            card:Hide()
            y = PlaceMessage(y, L["Delves unlock at Level 68"])
            area:SetContentSize(width, y + PAD_BOTTOM)
            return
        end
        hint:ClearAllPoints()
        hint:SetPoint("TOPLEFT", content, "TOPLEFT", PAD_LEFT, -y)
        hint:SetPoint("RIGHT", content, "RIGHT", -PAD_RIGHT, 0)
        hint:Show()
        y = y + HINT_H + HINT_GAP

        if #bountifulList == 0 then
            -- A cold POI cache returns nil for delves that really are bountiful, so
            -- an empty list only means "none today" once one has resolved.
            y = PlaceMessage(y, sawLivePOI
                and L["No bountiful delves are active right now.\nThey rotate daily - check back after reset."]
                or  L["Loading bountiful delve data...\nClick Refresh if this does not clear."])
            -- The Labyrinth needs no map pin to be bountiful, so it is listed either way
            y = list:Layout(y, BuildModels(list), PAD_LEFT, PAD_RIGHT)
        else
            y = list:Layout(y, BuildModels(list), PAD_LEFT, PAD_RIGHT)
        end

        y = y + GROUP_GAP
        card:ClearAllPoints()
        card:SetPoint("TOPLEFT", content, "TOPLEFT", PAD_LEFT, -y)
        card:SetPoint("TOPRIGHT", content, "TOPRIGHT", -PAD_RIGHT, -y)
        card:Show()
        RefreshStats(card)
        y = y + card:GetHeight()
        area:SetContentSize(width, y + PAD_BOTTOM)
    end
    RenderView = Render

    area.scroll:HookScript("OnSizeChanged", function(_, w)
        if frame:IsVisible() and math.abs((w or 0) - lastWidth) >= 1 then Render() end
    end)

    frame:SetScript("OnShow", function()
        RefreshBountifulData(true)
        RefreshLFGButton()
        Render()
        area:ScrollTo(0, 0)
    end)

    frame:RegisterEvent("GROUP_ROSTER_UPDATE")
    frame:RegisterEvent("PARTY_LEADER_CHANGED")
    frame:SetScript("OnEvent", function(self)
        if self:IsVisible() then RefreshLFGButton() end
    end)

    -- OnUpdate fires every frame; throttle the reset-timer refresh to 1/s.
    local elapsed = 0
    frame:SetScript("OnUpdate", function(self, dt)
        elapsed = elapsed + dt
        if elapsed >= 1 then
            elapsed = 0
            if self:IsVisible() and card:IsShown() then
                card.values.reset:SetText(GetResetTimeString())
            end
        end
    end)

    E:RegisterCallback("CurrencyUpdate", function()
        if frame:IsVisible() and card:IsShown() then RefreshStats(card) end
    end)

    E:RegisterCallback("AreaPoisUpdated", function()
        -- Refresh regardless of which tab is open, so E.currentBountifulNames
        -- stays current for other systems (Gilded Stash, Delve Locations).
        RefreshBountifulData()
        if frame:IsVisible() then Render() end
    end)

    E:RegisterTab(2, frame)

    RefreshBountifulData(true)
end)

-- Public hook for other modules (BeginDelveRun) to force the bountiful
-- lookup current at delve entry even if this tab was never opened.
function E:RefreshBountifulData(force)
    RefreshBountifulData(force)
    -- Public callers get no view refresh otherwise, and rows left Shown still
    -- point at entry tables the rebuild recycled. Only when it is on screen: the
    -- delve heartbeat calls this once a second with the tab closed.
    if pageFrame and pageFrame:IsVisible() and RenderView then RenderView() end
    -- Fire a PLAYER_LOGIN-flagged repair once the live names exist;
    -- AutoRepair clears the flag and no-ops on later calls.
    if E._autoRepairPending and E.AutoRepairBountifulHistory then
        E:AutoRepairBountifulHistory()
    end
end
