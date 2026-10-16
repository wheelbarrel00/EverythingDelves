local E = EverythingDelves

local MAX_LINES = 8000
local TRIM_TO = 7000
local LABYRINTH_INSTANCE = E.Labyrinth.instanceID
local EVERSONG_MAP = 2395
local ENTRANCE_WIDGET_SET = 2316

local WATCH_CURRENCIES = { 3028, 3310, 3536, 3537, 3592, 3606, 3464, 3483, 3442, 3443, 3444, 3445, 3446 }
local WATCH_ITEMS = { 285801, 285807, 285065, 285044, 283388, 280562, 285875, 286643, 282402, 273000, 271156, 286558 }
local WATCH_SPELLS = {
    [1285472] = true, [1285473] = true, [1314979] = true, [1315026] = true,
    [1314984] = true, [1320854] = true, [1314915] = true,
}
local WATCH_AURAS = { 1308804, 1309122, 1308968, 1248935 }
local WATCH_QUESTS = { 98831, 98832, 98833, 98834, 98836, 98951, 98963, 98962, 98961, 98960, 98959 }
local WATCH_POIS = { 9035, 9036, 9037 }
local WATCH_WIDGETS = {
    7591, 8101, 8183, 8314, 8345, 8346, 8348, 8349, 8350, 8374, 8376, 8377, 8378, 8379,
    8401, 8405, 8406, 8407, 8408, 8409, 8410, 8411, 8415, 8455,
}
local RENOWN_FACTIONS = { 2836, 2796 }
local STAT_IDS = { 63730, 63731 }
local PROGRESS_ACHIEVEMENTS = { 63723, 63717, 63719, 63728 }
local LAB_ACHIEVEMENTS = {
    63724, 63721, 63722, 63723, 63717, 63718, 63719, 63720, 63727, 63728, 64186,
    63716, 63715, 64039, 64118,
    63863, 63864, 63865, 63846, 63847, 63848, 63849, 63850, 63851, 63852, 63853,
}
local SPELL_DESCS = { 1320600, 1319790, 1318830, 1314915, 1319741 }
local QUESTLINES = { 6385, 6301 }

local IsSecret = issecretvalue

local function KeyLess(a, b)
    local ta, tb = type(a), type(b)
    if ta == "number" and tb == "number" then return a < b end
    if ta ~= tb then return ta == "number" end
    return tostring(a) < tostring(b)
end

local function Ser(v, depth, maxLen)
    if IsSecret and IsSecret(v) then return "<secret>" end
    local t = type(v)
    if t == "string" then
        maxLen = maxLen or 240
        if #v > maxLen then v = v:sub(1, maxLen) .. "..." end
        return v
    elseif t ~= "table" then
        return tostring(v)
    end
    depth = depth or 0
    if depth >= 2 then return "{...}" end
    local keys = {}
    for k in pairs(v) do keys[#keys + 1] = k end
    table.sort(keys, KeyLess)
    local parts = {}
    for i, k in ipairs(keys) do
        if i > 40 then
            parts[#parts + 1] = "..."
            break
        end
        parts[#parts + 1] = tostring(k) .. "=" .. Ser(v[k], depth + 1, maxLen)
    end
    return "{" .. table.concat(parts, ", ") .. "}"
end

local function Safe(v, maxLen)
    local ok, s = pcall(Ser, v, 0, maxLen)
    return ok and s or "<err>"
end

local function Args(...)
    local parts = {}
    for i = 1, select("#", ...) do
        parts[i] = Safe((select(i, ...)))
    end
    return table.concat(parts, ", ")
end

local function Rets(fn, ...)
    if type(fn) ~= "function" then return nil, "no function" end
    local res = { pcall(fn, ...) }
    if not res[1] then return nil, Safe(res[2]) end
    local n = table.maxn(res)
    if n < 2 then return "nil" end
    local parts = {}
    for i = 2, n do parts[#parts + 1] = Safe(res[i]) end
    return table.concat(parts, " | ")
end

local function NpcID(guid)
    if type(guid) ~= "string" or (IsSecret and IsSecret(guid)) then return nil end
    local ok, kind, id = pcall(function()
        local k, _, _, _, _, n = strsplit("-", guid)
        return k, n
    end)
    if ok and (kind == "Creature" or kind == "GameObject" or kind == "Vehicle") then
        return tonumber(id)
    end
    return nil
end

local function Store()
    local sv = EverythingDelvesDB
    local log = sv and sv.labLog
    return (log and log.on) and log or nil
end

local function Log(tag, text)
    local log = Store()
    if not log then return end
    local lines = log.lines
    lines[#lines + 1] = ("%s %.1f %s %s"):format(date("%H:%M:%S"), GetTime(), tag, tostring(text))
    if #lines > MAX_LINES then
        local keep = {}
        for i = #lines - TRIM_TO + 1, #lines do keep[#keep + 1] = lines[i] end
        log.lines = keep
    end
end

local last = {}
local function LogChanged(key, tag, text)
    if last[key] == text then return end
    last[key] = text
    Log(tag, text)
end

local pending = {}
local function Soon(key, delay, fn)
    if pending[key] then return end
    pending[key] = true
    C_Timer.After(delay, function()
        pending[key] = nil
        if Store() then fn() end
    end)
end

local function InDelve()
    local _, instanceType, diffID = GetInstanceInfo()
    return diffID == 208 or instanceType == "scenario"
end

local function SnapInstance(reason)
    local map = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
    Log("INST", ("%s | %s | uiMap=%s zone=%s sub=%s"):format(reason, tostring(Rets(GetInstanceInfo)),
        Safe(map), Safe(GetRealZoneText()), Safe(GetSubZoneText())))
end

local function DumpNamespace(tag, nsName)
    local ns = _G[nsName]
    if type(ns) ~= "table" then
        Log(tag, nsName .. " missing")
        return
    end
    local names = {}
    for k, v in pairs(ns) do
        if type(v) == "function" and (k:find("^Get") or k:find("^Is") or k:find("^Has") or k:find("^Can")) then
            names[#names + 1] = k
        end
    end
    table.sort(names)
    for _, k in ipairs(names) do
        local out = Rets(ns[k])
        if out and out ~= "nil" then Log(tag, nsName .. "." .. k .. "() = " .. out) end
    end
end

local function ListNamespace(nsName)
    local ns = _G[nsName]
    if type(ns) ~= "table" then return end
    local names = {}
    for k, v in pairs(ns) do
        if type(v) == "function" then names[#names + 1] = k end
    end
    table.sort(names)
    Log("API", nsName .. ": " .. table.concat(names, ", "))
end

local getterNames
local function WidgetGetterNames()
    if getterNames then return getterNames end
    getterNames = {}
    for k, v in pairs(C_UIWidgetManager or {}) do
        if type(v) == "function" and k:find("VisualizationInfo$") then getterNames[#getterNames + 1] = k end
    end
    table.sort(getterNames)
    return getterNames
end

local typeGetter
local function GetterForType(wtype)
    if not typeGetter then
        typeGetter = {}
        local W = C_UIWidgetManager or {}
        for name, value in pairs(Enum and Enum.UIWidgetVisualizationType or {}) do
            local long, short = "Get" .. name .. "WidgetVisualizationInfo", "Get" .. name .. "VisualizationInfo"
            typeGetter[value] = (W[long] and long) or (W[short] and short) or nil
        end
    end
    return typeGetter[wtype]
end

local function ReadWidget(id, wtype)
    if not C_UIWidgetManager then return nil end
    local typed = wtype and GetterForType(wtype)
    if typed then
        local ok, info = pcall(C_UIWidgetManager[typed], id)
        if ok and type(info) == "table" then return typed, info end
        return nil
    end
    local first, found, others
    for _, name in ipairs(WidgetGetterNames()) do
        local ok, info = pcall(C_UIWidgetManager[name], id)
        if ok and type(info) == "table" then
            if first then
                others = others or {}
                others[#others + 1] = (name:gsub("^Get", ""):gsub("VisualizationInfo$", ""))
            else
                first, found = name, info
            end
        end
    end
    return first, found, others
end

local WIDGET_KEYS = {
    "shownState", "widgetTag", "text", "tooltip", "tierText", "barValue", "barMin", "barMax",
    "barText", "overrideBarText", "timerValue", "timerMax", "spellInfo", "entries", "itemInfo",
    "currencies", "subText", "headerText", "title", "orderIndex",
}
local function SerWidget(getter, info)
    local parts = { (getter:gsub("^Get", ""):gsub("VisualizationInfo$", "")) }
    for _, k in ipairs(WIDGET_KEYS) do
        local v = info[k]
        if v ~= nil and v ~= "" then parts[#parts + 1] = k .. "=" .. Safe(v, 700) end
    end
    return table.concat(parts, " ")
end

local function DumpWidgetSet(tag, setID)
    if not (setID and C_UIWidgetManager and C_UIWidgetManager.GetAllWidgetsBySetID) then return end
    local ok, widgets = pcall(C_UIWidgetManager.GetAllWidgetsBySetID, setID)
    if not ok or type(widgets) ~= "table" then
        Log(tag, "set " .. tostring(setID) .. " unreadable")
        return
    end
    Log(tag, ("set %s: %d widgets"):format(tostring(setID), #widgets))
    for _, w in ipairs(widgets) do
        local g, info = ReadWidget(w.widgetID, w.widgetType)
        Log(tag, ("  w%s type=%s %s"):format(Safe(w.widgetID), Safe(w.widgetType),
            info and SerWidget(g, info) or "empty"))
    end
end

local function DumpWatchedWidgets(tag)
    for _, id in ipairs(WATCH_WIDGETS) do
        local g, info, others = ReadWidget(id)
        if info then
            Log(tag, ("w%d %s%s"):format(id, SerWidget(g, info),
                others and (" also=" .. table.concat(others, ",")) or ""))
        end
    end
end

local function DumpPOIs()
    if not (C_AreaPoiInfo and C_AreaPoiInfo.GetAreaPOIInfo) then return end
    local ok, delves = pcall(C_AreaPoiInfo.GetDelvesForMap, EVERSONG_MAP)
    Log("POI", "GetDelvesForMap(2395) = " .. (ok and Safe(delves) or "<err>"))
    local watched = {}
    for _, id in ipairs(WATCH_POIS) do watched[id] = true end
    local ids = {}
    for id in pairs(watched) do ids[#ids + 1] = id end
    if ok and type(delves) == "table" then
        for _, id in ipairs(delves) do
            if not watched[id] then ids[#ids + 1] = id end
        end
    end
    table.sort(ids)
    for _, id in ipairs(ids) do
        local ok2, poi = pcall(C_AreaPoiInfo.GetAreaPOIInfo, EVERSONG_MAP, id)
        if ok2 and type(poi) == "table" then
            Log("POI", ("%d name=%s atlas=%s desc=%s tipSet=%s iconSet=%s primary=%s"):format(id,
                Safe(poi.name), Safe(poi.atlasName), Safe(poi.description), Safe(poi.tooltipWidgetSet),
                Safe(poi.iconWidgetSet), Safe(poi.isPrimaryMapForPOI)))
            if watched[id] and poi.tooltipWidgetSet then DumpWidgetSet("POI", poi.tooltipWidgetSet) end
        else
            Log("POI", id .. " nil")
        end
    end
end

local function DumpRenown(full)
    local MF = C_MajorFactions
    if not MF then return end
    for _, fid in ipairs(RENOWN_FACTIONS) do
        LogChanged("renown" .. fid, "RENOWN", fid .. " info " .. tostring(Rets(MF.GetMajorFactionRenownInfo, fid)))
        if full then
            Log("RENOWN", fid .. " data " .. tostring(Rets(MF.GetMajorFactionData, fid)))
            Log("RENOWN", fid .. " maxed " .. tostring(Rets(MF.HasMaximumRenown, fid)))
            local ok, levels = pcall(MF.GetRenownLevels, fid)
            if ok and type(levels) == "table" then
                for _, lv in ipairs(levels) do
                    local okR, rewards = pcall(MF.GetRenownRewardsForLevel, fid, lv.level)
                    Log("RENOWN", ("  %d L%s locked=%s %s"):format(fid, Safe(lv.level), Safe(lv.locked),
                        okR and Safe(rewards) or "<err>"))
                end
            else
                Log("RENOWN", fid .. " levels <err>")
            end
        end
    end
    if full then
        Log("RENOWN", "season faction " .. tostring(Rets(C_DelvesUI and C_DelvesUI.GetDelvesFactionForSeason)))
        Log("RENOWN", "expansion 11 factions " .. tostring(Rets(MF.GetMajorFactionIDs, 11)))
    end
end

local function DumpCurrencies()
    if not (C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo) then return end
    for _, id in ipairs(WATCH_CURRENCIES) do
        local ok, info = pcall(C_CurrencyInfo.GetCurrencyInfo, id)
        local line
        if ok and type(info) == "table" then
            line = ("%d %s qty=%s max=%s total=%s week=%s/%s useTotal=%s disc=%s"):format(id, Safe(info.name),
                Safe(info.quantity), Safe(info.maxQuantity), Safe(info.totalEarned),
                Safe(info.quantityEarnedThisWeek), Safe(info.maxWeeklyQuantity),
                Safe(info.useTotalEarnedForMaxQty), Safe(info.discovered))
        else
            line = id .. " nil"
        end
        LogChanged("cur" .. id, "CUR", line)
    end
end

local function DumpItems()
    if not (C_Item and C_Item.GetItemCount) then return end
    for _, id in ipairs(WATCH_ITEMS) do
        local okN, name = pcall(C_Item.GetItemNameByID, id)
        local okC, count = pcall(C_Item.GetItemCount, id, true, false, true, true)
        LogChanged("item" .. id, "ITEM", ("%d %s n=%s"):format(id, okN and Safe(name) or "?",
            okC and Safe(count) or "?"))
    end
end

local function QuestTitle(q)
    local ok, title = pcall(C_QuestLog.GetTitleForQuestID, q)
    return ok and title or nil
end

local function DumpQuestStates()
    if not C_QuestLog then return end
    local QL = C_QuestLog
    for _, q in ipairs(WATCH_QUESTS) do
        local okD, done = pcall(QL.IsQuestFlaggedCompleted, q)
        local okA, acct = pcall(QL.IsQuestFlaggedCompletedOnAccount, q)
        local okO, onQ = pcall(QL.IsOnQuest, q)
        LogChanged("q" .. q, "QUEST", ("%d %s done=%s account=%s onQuest=%s"):format(q, Safe(QuestTitle(q)),
            okD and Safe(done) or "?", okA and Safe(acct) or "?", okO and Safe(onQ) or "?"))
    end
    if C_QuestLine and C_QuestLine.GetQuestLineQuests then
        for _, line in ipairs(QUESTLINES) do
            LogChanged("ql" .. line, "QUEST", "questline " .. line .. " = "
                .. tostring(Rets(C_QuestLine.GetQuestLineQuests, line)))
        end
    end
end

local function DumpQuestLog()
    if not (C_QuestLog and C_QuestLog.GetNumQuestLogEntries and C_QuestLog.GetInfo) then return end
    local okN, n = pcall(C_QuestLog.GetNumQuestLogEntries)
    if not okN or type(n) ~= "number" then return end
    for i = 1, n do
        local ok, info = pcall(C_QuestLog.GetInfo, i)
        if ok and info and not info.isHeader and (info.questID or 0) >= 95000 then
            LogChanged("qlog" .. info.questID, "QLOG", ("%d %s freq=%s hidden=%s task=%s"):format(info.questID,
                Safe(info.title), Safe(info.frequency), Safe(info.isHidden), Safe(info.isTask)))
        end
    end
end

local function RequestQuestData()
    if not (C_QuestLog and C_QuestLog.RequestLoadQuestByID) then return end
    for _, q in ipairs(WATCH_QUESTS) do pcall(C_QuestLog.RequestLoadQuestByID, q) end
end

local completedSet
local function CompletedSet()
    if not (C_QuestLog and C_QuestLog.GetAllCompletedQuestIDs) then return nil end
    local ok, ids = pcall(C_QuestLog.GetAllCompletedQuestIDs)
    if not ok or type(ids) ~= "table" then return nil end
    local set = {}
    for _, id in ipairs(ids) do set[id] = true end
    return set
end

local function Titled(list)
    local parts = {}
    for _, id in ipairs(list) do
        local title = QuestTitle(id)
        parts[#parts + 1] = title and (id .. ":" .. Safe(title)) or tostring(id)
    end
    return table.concat(parts, ", ")
end

-- The completed-quest set runs to tens of thousands, too much to build mid-fight. The next diff catches up.
local function QuestDiff(reason)
    if InCombatLockdown() then return end
    local now = CompletedSet()
    if not now then return end
    if completedSet then
        local added, removed = {}, {}
        for id in pairs(now) do
            if not completedSet[id] then added[#added + 1] = id end
        end
        for id in pairs(completedSet) do
            if not now[id] then removed[#removed + 1] = id end
        end
        if #added > 0 or #removed > 0 then
            table.sort(added)
            table.sort(removed)
            Log("QDIFF", ("%s +[%s] -[%s]"):format(reason, Titled(added), Titled(removed)))
        end
    else
        local n = 0
        for _ in pairs(now) do n = n + 1 end
        Log("QDIFF", reason .. " baseline " .. n .. " completed quests")
    end
    completedSet = now
end

local function DumpWeekly()
    if not (C_WeeklyRewards and C_WeeklyRewards.GetActivities) then return end
    local ok, acts = pcall(C_WeeklyRewards.GetActivities)
    if not ok or type(acts) ~= "table" then return end
    local parts = {}
    for _, a in ipairs(acts) do
        parts[#parts + 1] = ("t%s#%s %s/%s id%s lvl%s"):format(Safe(a.type), Safe(a.index), Safe(a.progress),
            Safe(a.threshold), Safe(a.id), Safe(a.level))
    end
    LogChanged("weekly", "VAULT", table.concat(parts, "  "))
end

local function DumpStats()
    local parts = {}
    for _, id in ipairs(STAT_IDS) do
        local ok, v = pcall(GetStatistic, id)
        parts[#parts + 1] = "stat" .. id .. "=" .. (ok and Safe(v) or "?")
    end
    for _, id in ipairs(PROGRESS_ACHIEVEMENTS) do
        local ok, _, _, done, qty, req = pcall(GetAchievementCriteriaInfo, id, 1)
        parts[#parts + 1] = ("ach%d=%s/%s%s"):format(id, ok and Safe(qty) or "?", ok and Safe(req) or "?",
            (ok and done) and " done" or "")
    end
    LogChanged("stats", "STAT", table.concat(parts, "  "))
    for _, sid in ipairs(SPELL_DESCS) do
        local ok, desc = pcall(C_Spell.GetSpellDescription, sid)
        if ok and desc and desc ~= "" then LogChanged("sdesc" .. sid, "SDESC", sid .. " " .. Safe(desc, 900)) end
    end
end

local function DumpAchievements()
    for _, id in ipairs(LAB_ACHIEVEMENTS) do
        local ok, _, name, _, completed = pcall(GetAchievementInfo, id)
        local okN, num = pcall(GetAchievementNumCriteria, id)
        local okC, cname, ctype, cdone, qty, req, _, _, asset, _, critID = pcall(GetAchievementCriteriaInfo, id, 1)
        Log("ACH", ("%d %s done=%s crit=%s | c1 '%s' type=%s done=%s %s/%s asset=%s id=%s"):format(id,
            ok and Safe(name) or "?", ok and Safe(completed) or "?", okN and Safe(num) or "?",
            okC and Safe(cname) or "?", okC and Safe(ctype) or "?", okC and Safe(cdone) or "?",
            okC and Safe(qty) or "?", okC and Safe(req) or "?", okC and Safe(asset) or "?",
            okC and Safe(critID) or "?"))
    end
end

local function AuraLine()
    if not (C_UnitAuras and C_UnitAuras.GetAuraDataByIndex) then return "" end
    local parts = {}
    for i = 1, 60 do
        local ok, a = pcall(C_UnitAuras.GetAuraDataByIndex, "player", i, "HELPFUL")
        if not ok or not a then break end
        parts[#parts + 1] = Safe(a.spellId) .. ":" .. Safe(a.name)
    end
    return table.concat(parts, ", ")
end

local function DumpWatchedAuras()
    if not (C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID) then return end
    local parts = {}
    for _, id in ipairs(WATCH_AURAS) do
        local ok, a = pcall(C_UnitAuras.GetPlayerAuraBySpellID, id)
        parts[#parts + 1] = id .. "=" .. ((ok and a) and "yes" or "no")
    end
    LogChanged("watchauras", "AURA", table.concat(parts, " "))
end

local function EDState()
    local rs = E.delveRunState or {}
    local ar = E.db and E.db.activeRun
    local claimed = E.HasTakenAbundantThisWeek and E:HasTakenAbundantThisWeek()
    LogChanged("ed", "ED", ("inDelve=%s name=%s kind=%s tier=%s start=%s bountiful=%s deaths=%s keyUsed=%s"
        .. " activeRun=%s dundunClaimed=%s"):format(Safe(rs.inDelve), Safe(rs.delveName), Safe(rs.delveKind),
        Safe(rs.tier), Safe(rs.startTime), Safe(rs.wasBountiful), Safe(rs.deaths), Safe(rs.keyUsed),
        ar and Safe(ar.name) or "nil", Safe(claimed)))
end

local function ScenarioSnapshot()
    local SI = C_ScenarioInfo
    if not SI then return "no C_ScenarioInfo" end
    local parts = {}
    local okI, info = pcall(SI.GetScenarioInfo)
    if okI and type(info) == "table" then
        parts[#parts + 1] = ("scen=%s '%s' stage=%s/%s complete=%s type=%s area=%s"):format(Safe(info.scenarioID),
            Safe(info.name), Safe(info.currentStage), Safe(info.numStages), Safe(info.isComplete),
            Safe(info.type), Safe(info.area))
    else
        parts[#parts + 1] = "scen=nil"
    end
    local okS, step = pcall(SI.GetScenarioStepInfo)
    if okS and type(step) == "table" then
        parts[#parts + 1] = ("step=%s '%s' crit=%s bonus=%s failed=%s wset=%s rewardQ=%s"):format(
            Safe(step.stepID), Safe(step.title), Safe(step.numCriteria), Safe(step.isBonusStep),
            Safe(step.stepFailed), Safe(step.widgetSetID), Safe(step.rewardQuestID))
        for i = 1, math.min(step.numCriteria or 0, 15) do
            local okC, c = pcall(SI.GetCriteriaInfo, i)
            if okC and type(c) == "table" then
                parts[#parts + 1] = ("c%d[id%s t%s a%s] '%s' %s/%s%s%s"):format(i, Safe(c.criteriaID),
                    Safe(c.criteriaType), Safe(c.assetID), Safe(c.description), Safe(c.quantity),
                    Safe(c.totalQuantity), c.completed and " done" or "", c.failed and " failed" or "")
            end
        end
    end
    if C_Scenario and C_Scenario.GetBonusSteps then
        local okB, bonus = pcall(C_Scenario.GetBonusSteps)
        if okB and type(bonus) == "table" and #bonus > 0 then parts[#parts + 1] = "bonusSteps=" .. Safe(bonus) end
    end
    return table.concat(parts, " ; "), okS and type(step) == "table" and step or nil
end

local lastStepID
local function ScenarioCheck(reason)
    local line, step = ScenarioSnapshot()
    LogChanged("scen", "SCEN", line)
    local stepID = step and step.stepID
    if stepID ~= lastStepID then
        lastStepID = stepID
        Log("STEP", ("%s -> step %s"):format(reason, Safe(stepID)))
        if step then
            Log("STEP", "desc " .. Safe(step.description, 600))
            DumpWidgetSet("STEPW", step.widgetSetID)
        end
        LogChanged("auras", "AURAS", AuraLine())
        DumpWatchedAuras()
        DumpStats()
        DumpWeekly()
        EDState()
        QuestDiff("step")
    end
end

local function EntranceDump()
    Log("ENTR", "picker shown")
    DumpNamespace("ENTR", "C_DelvesUI")
    DumpWidgetSet("ENTR", ENTRANCE_WIDGET_SET)
    local sets, seenSet = {}, {}
    local okB, background = pcall(C_DelvesUI.GetDelveEntranceBackgroundWidgetSetID)
    if okB and type(background) == "number" and background > 0 then sets[1], seenSet[background] = background, true end
    local okT, tiers = pcall(C_DelvesUI.GetDelveEntranceTiers)
    for _, t in ipairs(okT and type(tiers) == "table" and tiers or {}) do
        local set = type(t) == "table" and t.modifierUIWidgetSetID
        if type(set) == "number" and set > 0 and not seenSet[set] then
            seenSet[set] = true
            sets[#sets + 1] = set
        end
    end
    for _, set in ipairs(sets) do DumpWidgetSet("ENTR", set) end
    DumpWatchedWidgets("ENTR")
    DumpRenown(false)
    DumpCurrencies()
    DumpStats()
    EDState()
end

local function FullDump(reason)
    local okB, build = pcall(GetBuildInfo)
    Log("BASE", ("%s build=%s locale=%s char=%s ED=%s"):format(reason, okB and Safe(build) or "?",
        Safe(GetLocale()), Safe(E.CharKey and E.CharKey()), Safe(E.version)))
    SnapInstance("full dump")
    ListNamespace("C_DelvesUI")
    DumpNamespace("BASE", "C_DelvesUI")
    DumpPOIs()
    DumpRenown(true)
    DumpCurrencies()
    DumpItems()
    DumpQuestStates()
    DumpQuestLog()
    DumpAchievements()
    DumpWeekly()
    DumpStats()
    QuestDiff(reason)
    LogChanged("auras", "AURAS", AuraLine())
    DumpWatchedAuras()
    EDState()
    if InDelve() then
        DumpWatchedWidgets("IN")
        ScenarioCheck(reason)
    end
end

local lastInstanceID, lastWasDelve
local function CheckInstance(reason)
    local id = select(8, GetInstanceInfo())
    if id == lastInstanceID then return end
    local was = lastInstanceID
    lastInstanceID = id
    SnapInstance(("%s %s->%s"):format(reason, tostring(was), tostring(id)))
    local inDelve = InDelve()
    if inDelve then
        Log("IN", "entered " .. tostring(id) .. (id == LABYRINTH_INSTANCE and " (Labyrinth)" or ""))
        DumpNamespace("IN", "C_DelvesUI")
        DumpWatchedWidgets("IN")
        DumpCurrencies()
        DumpItems()
        DumpRenown(false)
        DumpWeekly()
        DumpStats()
        QuestDiff("enter")
        lastStepID = false
        ScenarioCheck("enter")
    elseif lastWasDelve then
        Log("IN", "left the delve")
        DumpCurrencies()
        DumpItems()
        DumpRenown(false)
        DumpWeekly()
        DumpStats()
        QuestDiff("leave")
        EDState()
    end
    lastWasDelve = inDelve
end

local lastVig = {}
local function ScanVignettes()
    if not (InDelve() and C_VignetteInfo and C_VignetteInfo.GetVignettes) then return end
    local ok, guids = pcall(C_VignetteInfo.GetVignettes)
    if not ok or type(guids) ~= "table" then return end
    local now = {}
    for _, g in ipairs(guids) do
        local ok2, v = pcall(C_VignetteInfo.GetVignetteInfo, g)
        if ok2 and type(v) == "table" then
            local key = ("%s:%s:%s"):format(Safe(v.vignetteID), Safe(v.name), Safe(NpcID(v.objectGUID)))
            now[key] = (now[key] or 0) + 1
        end
    end
    for k, n in pairs(now) do
        if lastVig[k] ~= n then Log("VIG", ("%s x%d"):format(k, n)) end
    end
    for k in pairs(lastVig) do
        if not now[k] then Log("VIG", k .. " gone") end
    end
    lastVig = now
end

local pickerOpen = false
local widgetSeenAt, widgetLogged = {}, {}
local TIMER_TYPE = Enum and Enum.UIWidgetVisualizationType and Enum.UIWidgetVisualizationType.ScenarioHeaderTimer
local lastCast, lastCastAt = nil, 0
local lastTarget

local INTERACTION_NAMES = {}
for name, value in pairs(Enum and Enum.PlayerInteractionType or {}) do INTERACTION_NAMES[value] = name end

local H = {}

H.PLAYER_ENTERING_WORLD = function(isLogin, isReload)
    Log("PEW", ("login=%s reload=%s"):format(Safe(isLogin), Safe(isReload)))
    CheckInstance("PEW")
    EDState()
end

local function ZoneEvent(event)
    CheckInstance(event)
    if InDelve() then
        local map = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
        LogChanged("zone", "ZONE", ("uiMap=%s sub=%s"):format(Safe(map), Safe(GetSubZoneText())))
    end
end
H.ZONE_CHANGED_NEW_AREA = function() ZoneEvent("ZONE_CHANGED_NEW_AREA") end
H.ZONE_CHANGED = function() ZoneEvent("ZONE_CHANGED") end
H.ZONE_CHANGED_INDOORS = function() ZoneEvent("ZONE_CHANGED_INDOORS") end

local function ScenarioEvent(event, ...)
    if event == "SCENARIO_UPDATE" or event == "SCENARIO_COMPLETED" then
        Log("SCEV", event .. " " .. Args(...))
    end
    if event == "SCENARIO_COMPLETED" then
        C_Timer.After(1, function()
            if not Store() then return end
            DumpStats()
            DumpWeekly()
            QuestDiff("scenario completed")
            EDState()
        end)
    end
    Soon("scen", 0.3, function() ScenarioCheck(event) end)
end
H.SCENARIO_UPDATE = function(...) ScenarioEvent("SCENARIO_UPDATE", ...) end
H.SCENARIO_COMPLETED = function(...) ScenarioEvent("SCENARIO_COMPLETED", ...) end
H.SCENARIO_CRITERIA_UPDATE = function(...) ScenarioEvent("SCENARIO_CRITERIA_UPDATE", ...) end
H.SCENARIO_POI_UPDATE = function(...) ScenarioEvent("SCENARIO_POI_UPDATE", ...) end
H.CRITERIA_COMPLETE = function(criteriaID)
    if InDelve() then Log("CRIT", "complete " .. Safe(criteriaID)) end
end
H.CRITERIA_UPDATE = function()
    if InDelve() then Soon("stats", 1, DumpStats) end
end
H.ACHIEVEMENT_EARNED = function(id)
    Log("ACH", "earned " .. Args(id) .. " " .. tostring(Rets(GetAchievementInfo, id)))
end

H.ENCOUNTER_START = function(...) Log("ENC", "start " .. Args(...)) end
H.ENCOUNTER_END = function(...)
    Log("ENC", "end " .. Args(...))
    C_Timer.After(1.5, function()
        if not Store() then return end
        DumpStats()
        QuestDiff("encounter end")
        DumpWeekly()
    end)
end
H.BOSS_KILL = function(...) Log("ENC", "boss kill " .. Args(...)) end

H.PLAYER_DEAD = function() if InDelve() then Log("DEATH", "dead") end end
H.PLAYER_ALIVE = function() if InDelve() then Log("DEATH", "alive") end end
H.PLAYER_UNGHOST = function() if InDelve() then Log("DEATH", "unghost") end end

local watchedCurrency = {}
for _, id in ipairs(WATCH_CURRENCIES) do watchedCurrency[id] = true end
H.CURRENCY_DISPLAY_UPDATE = function(currencyType, quantity, change, source, destroy)
    if currencyType == nil or (IsSecret and IsSecret(currencyType)) then return end
    if not (InDelve() or watchedCurrency[currencyType]) then return end
    local okI, info = pcall(C_CurrencyInfo.GetCurrencyInfo, currencyType)
    Log("CURRENCY", ("%s %s qty=%s change=%s source=%s destroy=%s"):format(Safe(currencyType),
        okI and info and Safe(info.name) or "?", Safe(quantity), Safe(change), Safe(source), Safe(destroy)))
    if currencyType == 3028 then
        C_Timer.After(0.2, function() if Store() then EDState() end end)
    end
end
H.BAG_UPDATE_DELAYED = function() Soon("items", 1, DumpItems) end

H.UNIT_SPELLCAST_SUCCEEDED = function(unit, _, spellID)
    -- A secret value used as a table key throws, so it is ruled out before the lookup.
    if unit ~= "player" or spellID == nil or (IsSecret and IsSecret(spellID)) then return end
    local watched = WATCH_SPELLS[spellID]
    -- Unwatched casts only in a delve and out of combat, or every ability would flood the log.
    if not watched and not (InDelve() and not InCombatLockdown()) then return end
    local now = GetTime()
    if spellID == lastCast and now - lastCastAt < 3 then return end
    lastCast, lastCastAt = spellID, now
    local okN, name = pcall(C_Spell.GetSpellName, spellID)
    Log("CAST", ("%s %s%s"):format(Safe(spellID), okN and Safe(name) or "?", watched and " [watched]" or ""))
end
H.UNIT_AURA = function(unit)
    if unit == "player" and InDelve() then Soon("auras", 0.5, DumpWatchedAuras) end
end

H.PLAYER_TARGET_CHANGED = function()
    if not UnitExists("target") then return end
    local okG, guid = pcall(UnitGUID, "target")
    local okN, name = pcall(UnitName, "target")
    local okF, friend = pcall(UnitIsFriend, "player", "target")
    local isPlayer = UnitIsPlayer("target")
    if isPlayer then return end
    if not (InDelve() or (okF and friend)) then return end
    local line = ("%s npc=%s guid=%s friend=%s class=%s"):format(okN and Safe(name) or "?",
        Safe(NpcID(okG and guid or nil)), okG and Safe(guid) or "?", okF and Safe(friend) or "?",
        Safe(UnitClassification("target")))
    if line ~= lastTarget then
        lastTarget = line
        Log("TARGET", line)
    end
end

H.GOSSIP_SHOW = function()
    local okG, guid = pcall(UnitGUID, "npc")
    local okN, name = pcall(UnitName, "npc")
    Log("GOSSIP", ("npc %s id=%s text=%s"):format(okN and Safe(name) or "?", Safe(NpcID(okG and guid or nil)),
        Safe(C_GossipInfo and C_GossipInfo.GetText and C_GossipInfo.GetText(), 400)))
    if not C_GossipInfo then return end
    local okO, options = pcall(C_GossipInfo.GetOptions)
    if okO and type(options) == "table" then
        for _, o in ipairs(options) do
            Log("GOSSIP", ("  option %s '%s' status=%s spell=%s"):format(Safe(o.gossipOptionID), Safe(o.name),
                Safe(o.status), Safe(o.spellID)))
        end
    end
    for _, getter in ipairs({ "GetAvailableQuests", "GetActiveQuests" }) do
        local okQ, quests = pcall(C_GossipInfo[getter])
        if okQ and type(quests) == "table" then
            for _, q in ipairs(quests) do
                Log("GOSSIP", ("  %s %s '%s' freq=%s repeat=%s"):format(getter, Safe(q.questID), Safe(q.title),
                    Safe(q.frequency), Safe(q.repeatable)))
            end
        end
    end
end
H.QUEST_DETAIL = function()
    Log("QUEST", ("detail %s %s"):format(Safe(GetQuestID and GetQuestID()), Safe(GetTitleText and GetTitleText())))
end
H.QUEST_ACCEPTED = function(questID)
    Log("QUEST", ("accepted %s %s"):format(Safe(questID), Safe(QuestTitle(questID))))
    if C_QuestLog and C_QuestLog.GetQuestObjectives then
        local ok, objectives = pcall(C_QuestLog.GetQuestObjectives, questID)
        if ok and objectives then Log("QUEST", "  objectives " .. Safe(objectives)) end
    end
    Soon("qlog", 1, DumpQuestLog)
end
H.QUEST_TURNED_IN = function(questID, xp, money)
    Log("QUEST", ("turned in %s %s xp=%s money=%s"):format(Safe(questID), Safe(QuestTitle(questID)), Safe(xp),
        Safe(money)))
    C_Timer.After(1, function() if Store() then QuestDiff("turn-in") end end)
end
H.QUEST_REMOVED = function(questID) Log("QUEST", "removed " .. Safe(questID)) end
H.QUEST_DATA_LOAD_RESULT = function(questID, success)
    for _, q in ipairs(WATCH_QUESTS) do
        if q == questID then
            Log("QUEST", ("data %s ok=%s title=%s"):format(Safe(questID), Safe(success), Safe(QuestTitle(questID))))
            Soon("qstates", 1, DumpQuestStates)
            return
        end
    end
end

H.WEEKLY_REWARDS_UPDATE = function() Soon("weekly", 1, DumpWeekly) end
H.MAJOR_FACTION_RENOWN_LEVEL_CHANGED = function(...)
    Log("RENOWN", "level changed " .. Args(...))
    DumpRenown(false)
end
H.UPDATE_FACTION = function() Soon("renown", 2, function() DumpRenown(false) end) end

H.UPDATE_UI_WIDGET = function(widgetInfo)
    if type(widgetInfo) ~= "table" or not (InDelve() or pickerOpen) then return end
    local id = widgetInfo.widgetID
    if id == nil or (IsSecret and IsSecret(id)) then return end
    local now = GetTime()
    local seen = widgetSeenAt[id]
    if seen and (now - seen < 5 or widgetInfo.widgetType == TIMER_TYPE) then return end
    widgetLogged[id] = (widgetLogged[id] or 0) + 1
    if widgetLogged[id] > 25 then return end
    widgetSeenAt[id] = now
    local g, info = ReadWidget(id, widgetInfo.widgetType)
    LogChanged("w" .. id, "WIDGET", ("w%s set=%s type=%s %s"):format(Safe(id), Safe(widgetInfo.widgetSetID),
        Safe(widgetInfo.widgetType), info and SerWidget(g, info) or "empty"))
end
H.VIGNETTES_UPDATED = function() Soon("vig", 1, ScanVignettes) end

H.LOOT_READY = function()
    if not InDelve() then return end
    local okN, n = pcall(GetNumLootItems)
    if not okN or type(n) ~= "number" then return end
    for i = 1, n do
        local link = GetLootSlotLink(i)
        local _, name, qty, currencyID = GetLootSlotInfo(i)
        local okS, src = pcall(GetLootSourceInfo, i)
        Log("LOOT", ("%d %s x%s currency=%s from=%s (%s)"):format(i, Safe(link or name), Safe(qty),
            Safe(currencyID), Safe(NpcID(okS and src or nil)), okS and Safe(src) or "?"))
    end
end

local function ChatEvent(event, text, sender)
    if not InDelve() then return end
    Log("CHAT", ("%s %s: %s"):format(event:gsub("^CHAT_MSG_", ""), Safe(sender), Safe(text, 400)))
end
for _, ev in ipairs({
    "CHAT_MSG_LOOT", "CHAT_MSG_CURRENCY", "CHAT_MSG_MONSTER_SAY", "CHAT_MSG_MONSTER_YELL",
    "CHAT_MSG_MONSTER_EMOTE", "CHAT_MSG_MONSTER_WHISPER", "CHAT_MSG_RAID_BOSS_EMOTE",
    "CHAT_MSG_RAID_BOSS_WHISPER", "CHAT_MSG_SYSTEM",
}) do
    H[ev] = function(text, sender) ChatEvent(ev, text, sender) end
end
H.UI_INFO_MESSAGE = function(_, message)
    if InDelve() then Log("CHAT", "UI_INFO " .. Safe(message)) end
end
H.PLAYER_INTERACTION_MANAGER_FRAME_SHOW = function(kind)
    Log("INTERACT", ("%s %s"):format(Safe(kind), Safe(INTERACTION_NAMES[kind])))
end

local UNIT_EVENTS = { UNIT_SPELLCAST_SUCCEEDED = true, UNIT_AURA = true }

local ef = CreateFrame("Frame")
ef:RegisterEvent("PLAYER_LOGIN")
ef:RegisterEvent("ADDON_LOADED")

local ticker
local function Enable()
    for event in pairs(H) do
        if UNIT_EVENTS[event] then
            pcall(ef.RegisterUnitEvent, ef, event, "player")
        else
            pcall(ef.RegisterEvent, ef, event)
        end
    end
    if ticker then ticker:Cancel() end
    ticker = C_Timer.NewTicker(30, function()
        if not (Store() and InDelve()) then return end
        QuestDiff("tick")
        DumpWeekly()
        DumpStats()
        DumpRenown(false)
        EDState()
    end)
end

local function Disable()
    for event in pairs(H) do pcall(ef.UnregisterEvent, ef, event) end
    if ticker then
        ticker:Cancel()
        ticker = nil
    end
end

local hooked = false
local function TryHookPicker()
    if hooked then return end
    local picker = _G.DelvesDifficultyPickerFrame
    if not (picker and picker.HookScript) then return end
    local ok = pcall(function()
        picker:HookScript("OnShow", function()
            pickerOpen = true
            if Store() then EntranceDump() end
        end)
        picker:HookScript("OnHide", function() pickerOpen = false end)
    end)
    hooked = ok
    if hooked then ef:UnregisterEvent("ADDON_LOADED") end
end

ef:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        TryHookPicker()
        return
    end
    if event == "PLAYER_LOGIN" then
        TryHookPicker()
        if Store() then
            Enable()
            C_Timer.After(5, function()
                if Store() then
                    RequestQuestData()
                    FullDump("login")
                end
            end)
        end
        return
    end
    local handler = H[event]
    if handler and Store() then
        local ok, err = pcall(handler, ...)
        if not ok then Log("ERR", event .. " " .. Safe(err)) end
    end
end)

function E.LabLogCommand(_, arg)
    local sv = EverythingDelvesDB
    if not sv then return end
    sv.labLog = sv.labLog or {}
    local log = sv.labLog
    log.lines = log.lines or {}
    arg = strtrim(arg or "")
    local function say(s) print("|cFFFFD700[ED lablog]|r " .. s) end

    if arg == "clear" then
        wipe(log.lines)
        say("cleared.")
    elseif arg:sub(1, 4) == "mark" then
        Log("MARK", strtrim(arg:sub(5)))
        say(log.on and "marked." or "the log is off - /ed lablog to turn it on.")
    elseif arg == "dump" then
        if log.on then FullDump("manual dump") end
        say(log.on and "snapshot written." or "the log is off - /ed lablog to turn it on.")
    elseif arg == "on" or (arg == "" and not log.on) then
        log.on = true
        Enable()
        RequestQuestData()
        if C_Spell and C_Spell.RequestLoadSpellData then
            for _, sid in ipairs(SPELL_DESCS) do pcall(C_Spell.RequestLoadSpellData, sid) end
        end
        if C_Item and C_Item.RequestLoadItemDataByID then
            for _, id in ipairs(WATCH_ITEMS) do pcall(C_Item.RequestLoadItemDataByID, id) end
        end
        wipe(last)
        lastInstanceID, lastWasDelve, lastStepID = nil, nil, nil
        Log("BASE", "logging on")
        FullDump("enabled")
        C_Timer.After(3, function()
            if not Store() then return end
            DumpQuestStates()
            DumpItems()
            DumpStats()
        end)
        CheckInstance("enabled")
        say(("ON (%d lines). Open the Labyrinth entrance, run it, then /reload so the log is saved."
            .. " /ed lablog mark <note> adds a note, /ed lablog dump a full snapshot."):format(#log.lines))
    elseif arg == "off" or arg == "" then
        Log("BASE", "logging off")
        log.on = false
        Disable()
        say(("OFF (%d lines kept). /reload to write them to disk."):format(#log.lines))
    else
        say("usage: /ed lablog [on | off | mark <note> | dump | clear]")
    end
end
