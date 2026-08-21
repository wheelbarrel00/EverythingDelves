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
    ["Invasive Glow"]               = { tier="S", note=L["Bomb DoT scales with tier — keep it rolling and the clear is trivial."] },
    ["Ogre Powered"]                = { tier="A", note=L["Straight shot to boss. Kill Unstable Aberrations before moving on."] },
    ["Sporasaur Special"]           = { tier="A", note=L["Kite dinos and kick spores back to break their shields for bonus damage."] },
    ["Sporasaurus Surprise"]        = { tier="A", note=L["Kite dinos and kick spores back to break their shields for bonus damage."] },
    ["Holding the Line"]            = { tier="A", note=L["Head down the staircase; kill enemies (not heal allies) for the fastest route."] },
    ["Academy Under Siege"]         = { tier="A", note=L["Scattered powerful items help, but it can't match Invasive Glow."] },
    ["Core of the Problem"]         = { tier="B", note=L["Use portals to shortcut around the map. Kill enemies and collect orbs."] },
    ["Faculty of Fear"]             = { tier="B", note=L["Revelation mechanic requires revealing many NPCs, adding significant time."] },
    ["Party Crasher"]               = { tier="B", note=L["Hit levers to disable traps while defeating 4 Twilight Summoners."] },
    ["Focusers Under Pressure"]     = { tier="B", note=L["Large crystal collection loop adds time compared to Ogre Powered."] },
    ["Toadly Unbecoming"]           = { tier="B", note=L["Decurse frogs to spawn the boss. Open layout adds traverse time even when mounted."] },
    ["Alnmoth Munchies"]            = { tier="C", note=L["Same quick route as Sporasaur Special but extra objectives slow it down."] },
    ["Not What I Expected"]         = { tier="C", note=L["Click Lightbloom crates and activate security. Displacement Portal clones help in combat."] },
    ["Trapped"]                     = { tier="C", note=L["Teleported inside — must rescue hostages on the way back to the entrance."] },
    ["Totem Annihilation"]          = { tier="C", note=L["Take the bird north. Avoid the captured loa's lightning — it hits hard."] },
    ["Traitor's Due"]               = { tier="C", note=L["Large unwalkable map. Defeat void foci and elites with the Eye of Antenorian buff."] },
    ["Leyline Technician"]          = { tier="D", note=L["Inspecting every leyline adds a lot of time."] },
    ["Descent of the Haranir"]      = { tier="D", note=L["Same quick pathing as Sporasaur but extra objectives add considerable time."] },
    ["The Gravitational Effect"]    = { tier="D", note=L["Flying to collect Singularity Coils breaks the route significantly."] },
    ["Loosed Loa"]                  = { tier="D", note=L["Use Evasive Elixir before the patrolling loa attacks to avoid a big stun."] },
    ["Loose Loa"]                   = { tier="D", note=L["Use Evasive Elixir before the patrolling loa attacks to avoid a big stun."] },
    ["Ritual Interrupted"]          = { tier="D", note=L["Navigate south freeing furbolgs. Haunted weapons deal decent bonus damage."] },
    ["Calamitous"]                  = { tier="D", note=L["Enormous mountable map with required secondary objectives in all three variants."] },
    ["Arena Champion"]              = { tier="D", note=L["Defeat two named enemies then collect mold samples from Moldering Fighters."] },
    ["March of the Arcane Brigade"] = { tier="F", note=L["Activating sentinels is slow with no direct path to the boss."] },
    ["March of the Arcane Parade"]  = { tier="F", note=L["Activating sentinels is slow with no direct path to the boss."] },
    ["Bombing Run"]                 = { tier="F", note=L["Destroying void portals makes for one of the slowest clears."] },
    ["Mirror Shine"]                = { tier="F", note=L["Repositioning mirrors to reflect light is tedious. Mind positioning to avoid debuffs."] },
    ["Shadowy Supplies"]            = { tier="F", note=L["Collecting 30 supplies from enemies and the floor is very slow."] },
    ["Captured Wild"]               = { tier="F", note=L["Free caged wildlife; use worm bait on Void Researchers to spawn the boss."] },
    ["Captured Wildlife"]           = { tier="F", note=L["Free caged wildlife; use worm bait on Void Researchers to spawn the boss."] },
    ["Captured Widlife"]            = { tier="F", note=L["Free caged wildlife; use worm bait on Void Researchers to spawn the boss."] },
    ["Stolen Mana"]                 = { tier="F", note=L["Use the Galvanic Rifle on mana barrels and free 8 prisoners from Mana Siphoners."] },
    ["Lightbloom Invasion"]         = { tier="F", note=L["Free fighters and defend barricades against Thornmaws using nearby barrels."] },
    ["Dastardly Rotstalk"]          = { tier="F", note=L["Taunt the crowd, click dirt piles, defeat spawns carefully to avoid being overwhelmed."] },
    ["Dastardly Rootstalks"]        = { tier="F", note=L["Taunt the crowd, click dirt piles, defeat spawns carefully to avoid being overwhelmed."] },

    -- No source rates the 12.1 variants below, so a tier can only come from a
    -- measured run.
    ["Olds and Ends"]               = { note=L["Ally with the Tortollan Tormunda to rescue the elders the Djaradin captured, and recover their relics."] },
    ["Minchi's Osseous Adventure"]  = { note=L["Search the bone piles and take hearts from the Gnarldor Djaradin to summon the Osseous Amalgamation."] },
    ["Minchi's Osseous Adventurer"] = { note=L["Search the bone piles and take hearts from the Gnarldor Djaradin to summon the Osseous Amalgamation."] },
    ["Speaking Their Language"]     = { tier="D", note=L["Rescue the turtles and the supplies the Djaradin stole, then send the siege-trained turtles in as tanks."] },
    ["Open Night"]                  = { note=L["An arena gauntlet - clear the floor, then the champions, then Drakta."] },
    ["Game Day"]                    = { note=L["Ghostly Headball - collect skulls from your kills and kick them at the pillars to score."] },
    ["Adopt-a-thon"]                = { note=L["Rescue the small animals caught in the middle of the gladiator fights."] },

    ["Venomous Vapors"]             = { note=L["Escort Marla and clear the Children of Ula'tek poison contamination. Ends on Disciple of Vash'nik."] },
    ["Basilisk Blitz"]              = { note=L["Divert the shields, then kill the basilisks channeling energy to the boss."] },
    ["Basalisk Blitz"]              = { note=L["Divert the shields, then kill the basilisks channeling energy to the boss."] },
    ["Academic Antitoxin"]          = { note=L["Brew an antidote with Sir Finley - cleanse poison patches and heal students. No final boss."] },
    ["An Elementary Antidote"]      = { note=L["Brew an antidote with Sir Finley - cleanse poison patches and heal students. No final boss."] },
    ["Fungal Pharmacon"]            = { note=L["Loot Fungal Pharmacon from around the pit and break the four pillars the Children of Ula'tek burrow through."] },
    ["Caustic Crush"]               = { note=L["Stop the Children of Ula'tek summoning slimes, using Fungal Pharmacon and dodging the caustic waves."] },
    ["Why'd It Have to Be Snakes?"] = { note=L["Hunt snake relics through the crypts, clearing poison patches with Fungal Pharmacon."] },
    ["Infiltrate and Ameliorate"]   = { note=L["Sabotage the summoning - kick summoners into the abyss and spike the cauldrons with the wrong ingredients."] },
    ["Eggsplosive Growth"]          = { note=L["Destroy the Children of Ula'tek eggs nesting in the tunnels using the Venom-Clogged Leyline pylons."] },
}

local function StripStoryPrefix(s)
    if not s or s == "" then return "" end
    local plain = s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    return plain:match("[Vv]ariant:%s*(.-)%s*$") or plain:match("^%s*(.-)%s*$") or plain
end

local function GetStoryTier(storyVariant)
    if not storyVariant or storyVariant == "" then return nil end
    if STORY_TIERS[storyVariant] then return STORY_TIERS[storyVariant] end
    local plain = storyVariant:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
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

local bestPickFS = nil

local ROW_HEIGHT     = 36
local bountifulList  = {}
local reAddSeen      = {}

-- Recycled delve-entry tables: the bountiful list is rebuilt on every
-- OnShow / area-POI update / refresh click, so pool to avoid churn.
local bountifulEntryPool = {}

-- Expansion state for boss tactics, keyed by delve name / "name##idx".
local expandedDelve = {}
local expandedBoss  = {}

local delveRowPool = {}
local bossRowPool  = {}
local noteLinePool = {}
local sc, scrollFrame, scrollBar
local emptyStateFS
local sawLivePOI = false
local UpdateScrollRange

local function RoleCC(role)
    local m = E.BossRoleMeta and E.BossRoleMeta[role]
    local rgb = m and m.rgb or {0.80, 0.80, 0.85}
    return string_format("|cFF%02X%02X%02X",
        math_floor(rgb[1]*255), math_floor(rgb[2]*255), math_floor(rgb[3]*255))
end
local function RoleLabel(role)
    local m = E.BossRoleMeta and E.BossRoleMeta[role]
    return (m and m.label or L["Note"]) .. ":"
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
                                    storyVariant = viz.text or ""
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
        if si and si.tier then
            local cc = TierCC(si.tier)
            bestPickFS:SetText(
                E.CC.muted .. L["Best Pick:"] .. " " .. E.CC.close
                .. E.CC.gold .. best.name .. E.CC.close
                .. E.CC.muted .. "  \226\128\148  " .. E.CC.close
                .. E.CC.body .. StripStoryPrefix(best.storyVariant) .. E.CC.close
                .. E.CC.muted .. "  \226\128\148  " .. E.CC.close
                .. cc .. L["%s Tier"]:format(si.tier) .. "|r"
            )
            return
        end
    end
    bestPickFS:SetText("")
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


local function CreateStatRow(parent, labelText, yOffset, xOffset, itemIconID)
    xOffset = xOffset or 0
    local anchorX = 8 + xOffset

    local icon
    if itemIconID then
        icon = parent:CreateTexture(nil, "ARTWORK")
        icon:SetPoint("TOPLEFT", parent, "TOPLEFT", anchorX, yOffset + 2)
        icon:SetSize(14, 14)
        anchorX = 0
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

    return val, icon
end

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

local function CreateDelveRow()
    local row = CreateFrame("Button", nil, sc, "BackdropTemplate")
    row:SetHeight(ROW_HEIGHT)
    row:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
    row:SetBackdropColor(0.05, 0.05, 0.05, 0.20)
    row:RegisterForClicks("LeftButtonUp")
    row:SetScript("OnClick", DelveRow_Toggle)

    local nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    nameText:SetPoint("TOPLEFT", row, "TOPLEFT", 4, -3)
    nameText:SetFont(nameText:GetFont(), 11)
    nameText:SetWidth(220)
    nameText:SetJustifyH("LEFT")
    nameText:SetWordWrap(false)
    row.nameText = nameText

    local variantText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    variantText:SetPoint("TOPLEFT", nameText, "BOTTOMLEFT", 0, -1)
    variantText:SetFont(variantText:GetFont(), 9)
    variantText:SetWidth(220)
    variantText:SetJustifyH("LEFT")
    variantText:SetWordWrap(false)
    row.variantText = variantText

    local zoneText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    zoneText:SetPoint("LEFT", row, "LEFT", 230, 0)
    zoneText:SetFont(zoneText:GetFont(), 11)
    zoneText:SetWidth(100)
    zoneText:SetJustifyH("LEFT")
    zoneText:SetWordWrap(false)
    row.zoneText = zoneText

    local tierText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    tierText:SetPoint("LEFT", row, "LEFT", 335, 0)
    tierText:SetFont(tierText:GetFont(), 11, "OUTLINE")
    tierText:SetWidth(30)
    tierText:SetJustifyH("CENTER")
    row.tierText = tierText

    local wpBtn = E:CreateButton(row, 32, 20, "Pin")
    wpBtn.label:SetFont(wpBtn.label:GetFont(), 10)
    wpBtn:SetPoint("LEFT", row, "LEFT", 370, 0)
    E:WireDelvePinButton(wpBtn, function() return row.delve end)
    row.wpBtn = wpBtn

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
            E:ShowTooltip(self, L["TomTom Waypoint"],
                          L["Add an arrow waypoint via TomTom."])
        else
            E:ShowTooltip(self, L["TomTom Not Installed"],
                          L["Install the TomTom addon to use arrow waypoints."])
        end
    end)
    ttBtn:SetScript("OnLeave", function(self)
        local bc = E.Colors.buttonBg
        self:SetBackdropColor(bc.r, bc.g, bc.b, bc.a)
        E:HideTooltip()
    end)
    row.ttBtn = ttBtn

    row:SetScript("OnEnter", function(self)
        if self.delve then
            local anchorTo = self.ttBtn or self
            GameTooltip:SetOwner(anchorTo, "ANCHOR_NONE")
            GameTooltip:ClearAllPoints()
            GameTooltip:SetPoint("TOPLEFT", anchorTo, "TOPRIGHT", 8, 0)
            GameTooltip:AddLine(self.delve.name, 1, 0.84, 0, true)
            local si = GetStoryTier(self.delve.storyVariant)
            if si then
                if si.tier then
                    local tc = TIER_COLORS[si.tier] or {0.6, 0.6, 0.6}
                    GameTooltip:AddLine(L["%s Tier"]:format(si.tier),
                                        tc[1], tc[2], tc[3], true)
                end
                GameTooltip:AddLine(si.note, 0.80, 0.80, 0.80, true)
                GameTooltip:AddLine(" ")
            end
            if self.delve.overcharged then
                GameTooltip:AddLine(L["Overcharged"], 1, 1, 0, true)
            end
            GameTooltip:AddLine(self.delve.storyVariant,
                                0.88, 0.88, 0.88, true)
            local bosses = E.GetDelveBosses and E:GetDelveBosses(self.delve.name)
            if bosses then
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine(expandedDelve[self.delve.name]
                    and L["Click to hide boss tactics"]
                    or  L["Click to show boss tactics"], 0.55, 0.55, 0.55, true)
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
        E:RefreshDelvePin(row.wpBtn)

        local caret = (delve.completed and E.CC.muted or E.CC.gold)
            .. (expandedDelve[delve.name] and "v" or ">") .. E.CC.close

        if delve.completed then
            -- Use a ready-check |T...|t texture, not a Unicode check (U+2713):
            -- the default game font has no glyph and renders a missing-glyph box.
            row.nameText:SetText(
                caret .. " "
                .. "|TInterface\\RaidFrame\\ReadyCheck-Ready:14:14|t "
                .. E.CC.muted .. delve.name .. E.CC.close
            )
            row.zoneText:SetText(E.CC.muted .. delve.zone .. E.CC.close)
            local completedPrefix = delve.overcharged
                and (E.CC.muted .. L["Overcharged"] .. E.CC.close
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

            local normalNote = ""
            if delve.normalPoiID and delve.mapID
                    and C_AreaPoiInfo and C_AreaPoiInfo.GetAreaPOIInfo then
                local nPoi = C_AreaPoiInfo.GetAreaPOIInfo(
                                 delve.mapID, delve.normalPoiID)
                if nPoi then
                    normalNote = E.CC.muted
                        .. " " .. L["(Normal version available)"] .. E.CC.close
                end
            end

            local overchargedPrefix = delve.overcharged
                and (E.CC.yellow .. L["Overcharged"] .. E.CC.close
                     .. (delve.storyVariant ~= "" and E.CC.muted .. "  " .. E.CC.close or ""))
                or ""
            row.variantText:SetText(
                overchargedPrefix
                .. E.CC.muted .. delve.storyVariant .. E.CC.close
                .. normalNote
            )
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
            row.tierText:SetText(si.tier or "")
        else
            row.tierText:SetText("")
        end

        PlaceRow(row, 0, ROW_HEIGHT)

        if expandedDelve[delve.name] then
            local bosses = E.GetDelveBosses and E:GetDelveBosses(delve.name)
            if bosses then
                local todaysBoss = E.GetTodaysBossName
                    and E:GetTodaysBossName(delve.canonicalName or delve.name)
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
                            .. E.CC.muted .. "   " .. L["(today's boss)"] .. E.CC.close)
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

    if #bountifulList == 0 then
        if not emptyStateFS then
            emptyStateFS = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            emptyStateFS:SetPoint("TOPLEFT", sc, "TOPLEFT", 8, -12)
            emptyStateFS:SetPoint("RIGHT", sc, "RIGHT", -8, 0)
            emptyStateFS:SetJustifyH("LEFT")
            emptyStateFS:SetFont(emptyStateFS:GetFont(), 12)
        end
        -- A cold POI cache returns nil for delves that really are bountiful, so
        -- an empty list only means "none today" once one has resolved.
        emptyStateFS:SetText(E.CC.muted .. (sawLivePOI
            and L["No bountiful delves are active right now.\nThey rotate daily - check back after reset."]
            or  L["Loading bountiful delve data...\nClick Refresh if this does not clear."]) .. E.CC.close)
        emptyStateFS:Show()
        yCur = yCur + 48
    elseif emptyStateFS then
        emptyStateFS:Hide()
    end

    sc:SetHeight(yCur + 8)
    if UpdateScrollRange then UpdateScrollRange() end
end

E:RegisterModule(function()
    local frame = CreateFrame("Frame", "EverythingDelvesTab2Content")

    local statValues = {}

    local STAT_Y = -4
    local COL2_X = 310

    local keyIconTex, cofferShardIconTex
    statValues.bountifulKeys, keyIconTex   = CreateStatRow(frame, L["Bountiful Keys:"], STAT_Y, nil, E.ItemIcons.cofferKey)
    statValues.cofferShards, cofferShardIconTex = CreateStatRow(frame, L["Coffer Key Shards:"], STAT_Y - 18, nil, E.ItemIcons.cofferShard)
    statValues.keysFromShards= CreateStatRow(frame, L["Keys from Shards:"], STAT_Y - 36)

    statValues.journey       = CreateStatRow(frame, L["Journey:"], STAT_Y, COL2_X)
    statValues.resetTimer    = CreateStatRow(frame, L["Bountiful Reset:"], STAT_Y - 18, COL2_X)
    statValues.sessionCount  = CreateStatRow(frame, L["Session Completions:"], STAT_Y - 36, COL2_X)

    local function RefreshStats()
        local keys  = GetBountifulKeys()
        local shards, shardsThisWeek, weeklyCap = GetCofferShards()
        local stage, cur, stageMax = GetJourneyProgress()
        local sessionDone = (E.sessionData and E.sessionData.bountifulCompleted) or 0

        if keyIconTex then keyIconTex:SetTexture(E.CachedIcons.cofferKey or C_Item.GetItemIconByID(E.ItemIcons.cofferKey)) end
        if cofferShardIconTex then cofferShardIconTex:SetTexture(E.CachedIcons.cofferShard or C_Item.GetItemIconByID(E.ItemIcons.cofferShard)) end

        statValues.bountifulKeys:SetText(E.CC.gold .. keys .. E.CC.close)
        statValues.cofferShards:SetText(
            E.CC.gold .. shards .. E.CC.close
            .. (weeklyCap > 0
                and (E.CC.muted .. "  "
                     .. L["(%d / %d this week)"]:format(shardsThisWeek, weeklyCap)
                     .. E.CC.close)
                or "")
        )
        statValues.keysFromShards:SetText(
            E.CC.gold .. KeysFromShards(shards) .. E.CC.close
            .. E.CC.muted .. "  (" .. shards .. " / "
            .. E.SHARDS_PER_KEY .. ")" .. E.CC.close
        )
        statValues.journey:SetText(
            E.CC.gold .. L["Stage %d"]:format(stage) .. E.CC.close
            .. E.CC.muted .. " - " .. cur .. " / " .. stageMax .. E.CC.close
        )
        statValues.resetTimer:SetText(E.CC.gold .. GetResetTimeString() .. E.CC.close)
        statValues.sessionCount:SetText(E.CC.gold .. sessionDone .. E.CC.close)
    end

    local progressBar = E:CreateProgressBar(frame, 0, 14, L["Bountiful Delves Completed"])
    progressBar:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, STAT_Y - 60)
    progressBar:SetPoint("RIGHT", frame, "RIGHT", -20, 0)
    frame.progressBar = progressBar

    local ACTIONS_Y = STAT_Y - 84

    local gvBtn = E:CreateButton(frame, 90, 24, L["Great Vault"])
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
            print(E.CC.header .. "Everything Delves|r: "
                .. L["Great Vault UI could not be loaded."])
        end
    end)
    gvBtn:SetScript("OnEnter", function(self)
        local hc = E.Colors.buttonHover
        self:SetBackdropColor(hc.r, hc.g, hc.b, hc.a)
        E:ShowTooltip(self, L["Great Vault"], L["Open the Great Vault reward panel."])
    end)
    gvBtn:SetScript("OnLeave", function(self)
        local bc = E.Colors.buttonBg
        self:SetBackdropColor(bc.r, bc.g, bc.b, bc.a)
        E:HideTooltip()
    end)

    local lfgStartBtn = E:CreateButton(frame, 90, 24, L["Start LFG"])
    lfgStartBtn:SetPoint("LEFT", gvBtn, "RIGHT", 12, 0)

    local function OpenDelveLFG()
        -- Blizzard_GroupFinder / Blizzard_PVPUI are load-on-demand.
        if not PVEFrame or not LFGListFrame then
            EnsureBlizzardAddon("Blizzard_GroupFinder")
            EnsureBlizzardAddon("Blizzard_PVPUI")
        end
        if not PVEFrame then
            print(E.CC.header .. "Everything Delves|r: "
                .. L["LFG UI could not be loaded."])
            return
        end
        if not PVEFrame:IsShown() then
            PVEFrame_ToggleFrame()
        end
        if GroupFinderFrameGroupButton3 then
            GroupFinderFrameGroupButton3:Click()
        end
        -- Category 121 is the Delves LFG category.
        if LFGListFrame and LFGListFrame.CategorySelection
                and LFGListCategorySelection_SelectCategory then
            LFGListCategorySelection_SelectCategory(
                LFGListFrame.CategorySelection, 121, 0)
            if LFGListFrame.CategorySelection.StartGroupButton then
                LFGListFrame.CategorySelection.StartGroupButton:Click()
            end
        end
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
            E:ShowTooltip(self, L["Start LFG"],
                          E.CC.red .. L["Cannot list while in a raid group."] .. E.CC.close)
        elseif IsInGroup() and not UnitIsGroupLeader("player") then
            E:ShowTooltip(self, L["Start LFG"],
                          E.CC.red .. L["Only the group leader can list."] .. E.CC.close)
        else
            E:ShowTooltip(self, L["Start LFG"],
                          L["Open the Group Finder to list a Delve group."])
        end
    end)
    lfgStartBtn:SetScript("OnLeave", function(self)
        local bc = E.Colors.buttonBg
        self:SetBackdropColor(bc.r, bc.g, bc.b, bc.a)
        E:HideTooltip()
    end)

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

    local LIST_Y = ACTIONS_Y - 70

    local actionDiv = frame:CreateTexture(nil, "ARTWORK")
    actionDiv:SetHeight(1)
    actionDiv:SetPoint("TOPLEFT",  frame, "TOPLEFT",   8, ACTIONS_Y - 30)
    actionDiv:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -8, ACTIONS_Y - 30)
    E:StyleAccentDivider(actionDiv)

    local headerLineTop = frame:CreateTexture(nil, "ARTWORK")
    headerLineTop:SetHeight(1)
    headerLineTop:SetPoint("TOPLEFT",  frame, "TOPLEFT",  8,   LIST_Y + 8)
    headerLineTop:SetPoint("TOPRIGHT", frame, "TOPLEFT", 462,  LIST_Y + 8)
    E:StyleGreyLine(headerLineTop)

    local listHeader = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    listHeader:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, LIST_Y)
    listHeader:SetFont(listHeader:GetFont(), E.HEADER_FONT_SIZE, "OUTLINE")
    E:StyleAccentHeader(listHeader, L["Today's Bountiful Delves"])

    bestPickFS = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    bestPickFS:SetPoint("TOPLEFT", listHeader, "BOTTOMLEFT", 2, -2)
    bestPickFS:SetFont(bestPickFS:GetFont(), 10)
    bestPickFS:SetJustifyH("LEFT")

    local headerLineBot = frame:CreateTexture(nil, "ARTWORK")
    headerLineBot:SetHeight(1)
    headerLineBot:SetPoint("TOPLEFT",  frame, "TOPLEFT",  8,   LIST_Y - 44)
    headerLineBot:SetPoint("TOPRIGHT", frame, "TOPLEFT", 462,  LIST_Y - 44)
    E:StyleGreyLine(headerLineBot)

    local unlockWarning = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    unlockWarning:SetPoint("TOPLEFT", listHeader, "BOTTOMLEFT", 0, -8)
    unlockWarning:SetFont(unlockWarning:GetFont(), 12)
    unlockWarning:SetText(E.CC.red .. L["Delves unlock at Level 68"] .. E.CC.close)
    unlockWarning:Hide()

    local refreshBtn = E:CreateButton(frame, 70, 22, L["Refresh"])
    refreshBtn.label:SetFont(refreshBtn.label:GetFont(), 10)
    refreshBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -22, LIST_Y + 2)
    refreshBtn:SetScript("OnClick", function()
        RefreshBountifulData(true)
        UpdateRows()
        UpdateBestPick()
        RefreshStats()
        local done = 0
        for _, d in ipairs(bountifulList) do
            if d.completed then done = done + 1 end
        end
        progressBar:SetProgress(done, #bountifulList)
    end)
    refreshBtn:SetScript("OnEnter", function(self)
        local hc = E.Colors.buttonHover
        self:SetBackdropColor(hc.r, hc.g, hc.b, hc.a)
        E:ShowTooltip(self, L["Refresh"],
                      L["Re-query bountiful delve data and currency values."])
    end)
    refreshBtn:SetScript("OnLeave", function(self)
        local bc = E.Colors.buttonBg
        self:SetBackdropColor(bc.r, bc.g, bc.b, bc.a)
        E:HideTooltip()
    end)

    local COL_Y = LIST_Y - 50
    for _, col in ipairs({
        { label = L["Delve Name"], x = 8   },
        { label = L["Zone"],       x = 234 },
        { label = L["Tier"],       x = 338 },
        { label = L["Pin"],        x = 374 },
        { label = "TomTom",        x = 412 },
    }) do
        local fs = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        fs:SetPoint("TOPLEFT", frame, "TOPLEFT", col.x, COL_Y)
        fs:SetFont(fs:GetFont(), 10, "OUTLINE")
        E:StyleAccentHeader(fs, col.label)
    end

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

    listFrame.progressBar = progressBar

    frame:SetScript("OnShow", function(self)
        -- Delves unlock at level 68.
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

        local done = 0
        for _, d in ipairs(bountifulList) do
            if d.completed then done = done + 1 end
        end
        progressBar:SetProgress(done, #bountifulList)

        UpdateRows()
        UpdateBestPick()
    end)

    -- OnUpdate fires every frame; throttle the reset-timer refresh to 1/s.
    local elapsed = 0
    frame:SetScript("OnUpdate", function(self, dt)
        elapsed = elapsed + dt
        if elapsed >= 1 then
            elapsed = 0
            if self:IsVisible() then
                statValues.resetTimer:SetText(
                    E.CC.gold .. GetResetTimeString() .. E.CC.close
                )
            end
        end
    end)

    E:RegisterCallback("CurrencyUpdate", function()
        if frame:IsVisible() then
            RefreshStats()
        end
    end)

    E:RegisterCallback("AreaPoisUpdated", function()
        -- Refresh regardless of which tab is open, so E.currentBountifulNames
        -- stays current for other systems (Gilded Stash, Delve Locations).
        RefreshBountifulData()
        if frame:IsVisible() then
            RefreshStats()
            local done = 0
            for _, d in ipairs(bountifulList) do
                if d.completed then done = done + 1 end
            end
            progressBar:SetProgress(done, #bountifulList)
            UpdateRows()
            UpdateBestPick()
        end
    end)

    E:RegisterTab(2, frame)

    RefreshBountifulData(true)
end)

-- Public hook for other modules (BeginDelveRun) to force the bountiful
-- lookup current at delve entry even if this tab was never opened.
-- Debounced (2 s) internally, so cheap to call repeatedly.
function E:RefreshBountifulData(force)
    RefreshBountifulData(force)
    -- Fire a PLAYER_LOGIN-flagged repair once the live names exist;
    -- AutoRepair clears the flag and no-ops on later calls.
    if E._autoRepairPending and E.AutoRepairBountifulHistory then
        E:AutoRepairBountifulHistory()
    end
end
