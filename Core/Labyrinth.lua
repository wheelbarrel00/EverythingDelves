local E = EverythingDelves
local L = E.L
local LAB = E.Labyrinth

local ipairs, type, time = ipairs, type, time
local math_floor, math_max, math_min = math.floor, math.max, math.min
local WEEK = 7 * 24 * 3600

local function Round(n) return math_floor(n + 0.5) end

-- One Labyrinth visit. Every time in it is seconds since the run began, so it survives a /reload or relog.
E.LabRun = {}

function E.LabRun.New()
    return { ch = 0, at = {}, rooms = {}, keys = 0 }
end

-- A finished chamber still reads as current for a moment after SCENARIO_COMPLETED, so it cannot open again
-- until the path choice has come between.
function E.LabRun.OnScenario(lab, scenarioID, title, now)
    if type(scenarioID) ~= "number" or scenarioID == lab.scen or scenarioID == lab.closed
            or scenarioID == LAB.treasureScenario then
        return
    end
    if LAB.betweenScenarios[scenarioID] then
        lab.closed = nil
        return
    end
    lab.scen, lab.title, lab.since, lab.enc, lab.boss = scenarioID, title, now, nil, nil
end

function E.LabRun.OnEncounterStart(lab, encounterID, now)
    if encounterID == LAB.kindojanEncounter then lab.kindoFrom = now end
end

function E.LabRun.OnEncounterEnd(lab, encounterID, name, success, now, when)
    if success ~= 1 and success ~= true then return end
    if encounterID == LAB.kindojanEncounter then
        lab.kindo = lab.kindoFrom and Round(now - lab.kindoFrom) or nil
        lab.kindoAt, lab.kindoWhen, lab.last = now, when, now
    else
        lab.enc, lab.boss = encounterID, name
    end
end

-- Kindo'jan's chamber completes its scenario too, but it is not one of the nine.
function E.LabRun.OnCompleted(lab, now)
    if lab.scen == LAB.heartScenario or (lab.kindoAt and now - lab.kindoAt < 15) then return false end
    local n = lab.ch + 1
    lab.ch = n
    lab.at[n] = Round(now)
    lab.rooms[n] = { s = lab.scen, t = lab.title, e = lab.enc, b = lab.boss, d = lab.since and Round(now - lab.since) or nil }
    lab.last, lab.closed = now, lab.scen
    lab.scen, lab.title, lab.since, lab.enc, lab.boss = nil, nil, nil, nil, nil
    return true
end

-- shown is the game's count for the whole run, so anything above ours happened before this visit began.
function E.LabRun.Reconcile(lab, shown)
    if type(shown) == "number" and shown > lab.ch + (lab.prior or 0) then
        lab.prior = shown - lab.ch
    end
end

function E.LabRun.Total(lab)
    return lab.ch + (lab.prior or 0)
end

function E.LabRun.Coffers(lab)
    return math_floor(E.LabRun.Total(lab) / LAB.checkpointEvery)
end

function E.LabRun.Duration(lab)
    return lab.last and Round(lab.last) or 0
end

function E.LabRun.Record(lab, left)
    local at, rooms = {}, {}
    for i, v in ipairs(lab.at) do at[i] = v end
    for i, r in ipairs(lab.rooms) do rooms[i] = { s = r.s, t = r.t, e = r.e, b = r.b, d = r.d } end
    return { ch = lab.ch, at = at, rooms = rooms, kindo = lab.kindo, kindoWhen = lab.kindoWhen, keys = lab.keys,
             left = left or nil, prior = lab.prior }
end

-- mark is a chamber count, or "kindo" for the fight alone
function E:GetLabyrinthBest(tier, mark)
    local hist = self.db and self.db.delveHistory and self.db.delveHistory[LAB.name]
    local best
    for _, r in ipairs(hist and hist.recentRuns or {}) do
        local t
        if mark == "kindo" then t = r.kindo else t = type(r.at) == "table" and r.at[mark] end
        if type(t) == "number" and t > 0 and not r.prior and (r.tier or 0) == tier and (not best or t < best) then
            best = t
        end
    end
    return best
end

function E.KindojanKills()
    -- Read alone: GetStatistic returns more than its value, a string that reads "--" until the first kill
    local stat = GetStatistic and GetStatistic(LAB.kindojanStatistic)
    return tonumber((tostring(stat or ""):gsub("%D", ""))) or 0
end

-- The game's weekly counter (widget 8350) returns nil before a kill, so this week's Tier 8+ kill is worked out here
function E:KindojanRewardThisWeek()
    local secs = C_DateAndTime and C_DateAndTime.GetSecondsUntilWeeklyReset and C_DateAndTime.GetSecondsUntilWeeklyReset()
    if not secs or secs <= 0 then return nil end
    local now = time()
    local weekEnd = now + secs
    local weekStart = weekEnd - WEEK
    local me = self.CharKey()

    local rs = self.delveRunState
    local lab = rs and rs.lab
    if lab and lab.kindoAt and (rs.tier or 0) >= LAB.kindojanMinTier and (lab.kindoWhen or now) >= weekStart then
        return true
    end

    local everKilled = false
    local hist = self.db and self.db.delveHistory and self.db.delveHistory[LAB.name]
    for _, r in ipairs(hist and hist.recentRuns or {}) do
        if (r.kindo or r.kindoWhen) and (r.tier or 0) >= LAB.kindojanMinTier and (r.char == nil or r.char == me) then
            if (r.kindoWhen or r.timestamp or 0) >= weekStart then return true end
            everKilled = true
        end
    end

    local store = self.db and self.db.kindojanWeekByChar
    if not store then return false end
    local kills = E.KindojanKills()
    local entry = store[me]
    if not entry or now >= (entry.weekEnd or 0) then
        -- The statistic never falls, so a zero beside a logged kill or a read below last week's is one not loaded yet
        if (kills == 0 and everKilled) or (entry and kills < (entry.kills or 0)) then return false end
        store[me] = { weekEnd = weekEnd, kills = kills }
        return false
    end
    return kills > (entry.kills or 0)
end

function E.LabyrinthBoardKey(mark)
    return LAB.name .. "#" .. mark
end

local function MapName(mapID, fallback)
    local info = C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(mapID)
    local name = type(info) == "table" and info.name
    return (type(name) == "string" and name ~= "") and name or fallback
end

-- The game's own name in the client's language. LAB.name stays English because History is keyed by it.
function E.LabyrinthDisplayName()
    return MapName(LAB.uiMapID, LAB.name)
end

function E.LabyrinthZoneName()
    return MapName(LAB.mapID, "Eversong Woods")
end

-- The intro quest is account-wide, and the live entrance pin covers a cold quest cache
function E.IsLabyrinthUnlocked()
    local QL = C_QuestLog
    if QL and QL.IsQuestFlaggedCompletedOnAccount and QL.IsQuestFlaggedCompletedOnAccount(LAB.introQuest) then
        return true
    end
    if QL and QL.IsQuestFlaggedCompleted and QL.IsQuestFlaggedCompleted(LAB.introQuest) then return true end
    return E:GetActiveDelvePOI(LAB) ~= nil
end

local titleAsked = false
function E.LabyrinthIntroQuestTitle()
    local QL = C_QuestLog
    local title = QL and QL.GetTitleForQuestID and QL.GetTitleForQuestID(LAB.introQuest)
    if type(title) == "string" and title ~= "" then return title end
    if not titleAsked and QL and QL.RequestLoadQuestByID then
        titleAsked = true
        local watch = CreateFrame("Frame")
        watch:RegisterEvent("QUEST_DATA_LOAD_RESULT")
        watch:SetScript("OnEvent", function(self, _, questID, ok)
            if questID ~= LAB.introQuest then return end
            self:UnregisterAllEvents()
            if not ok then return end
            if E.RefreshDelveLocations then E:RefreshDelveLocations() end
            if E.RefreshBountifulData then E:RefreshBountifulData() end
        end)
        QL.RequestLoadQuestByID(LAB.introQuest)
    end
    return "The Labyrinth"
end

local journeyFaction
-- No season API points to the Labyrinth Journey, so it is found by its texture kit, the ID a fallback
function E.LabyrinthJourneyFaction()
    if journeyFaction then return journeyFaction end
    local MF = C_MajorFactions
    if MF and MF.GetMajorFactionIDs and MF.GetMajorFactionData then
        local ok, ids = pcall(MF.GetMajorFactionIDs, LE_EXPANSION_LEVEL_CURRENT)
        for _, id in ipairs(ok and type(ids) == "table" and ids or {}) do
            local data = MF.GetMajorFactionData(id)
            if type(data) == "table" and data.textureKit == LAB.journeyKit then
                journeyFaction = id
                return id
            end
        end
    end
    return LAB.journeyFaction
end

function E.GetLabyrinthJourney()
    local MF = C_MajorFactions
    local id = E.LabyrinthJourneyFaction()
    local info = MF and MF.GetMajorFactionRenownInfo and MF.GetMajorFactionRenownInfo(id)
    if type(info) ~= "table" then return nil end
    return { factionID = id, level = info.renownLevel or 0, cur = math_floor(info.renownReputationEarned or 0),
             threshold = math_floor(info.renownLevelThreshold or 1) }
end

function E.LabyrinthJourneyName()
    local CI = C_CurrencyInfo
    local info = CI and CI.GetCurrencyInfo and CI.GetCurrencyInfo(LAB.journeyCurrency)
    local name = type(info) == "table" and info.name
    if type(name) == "string" and name ~= "" then return name end
    local MF = C_MajorFactions
    local data = MF and MF.GetMajorFactionData and MF.GetMajorFactionData(E.LabyrinthJourneyFaction())
    return (type(data) == "table" and data.name) or "Labyrinth Journey"
end

-- One criterion with a quantity (My Labyrinth's chambers, the chests), or several counted ones
function E.LabyrinthAchievement(id)
    if not (GetAchievementInfo and GetAchievementNumCriteria and GetAchievementCriteriaInfo) then return nil end
    local ok, _, name, _, completed, _, _, _, description, _, _, reward = pcall(GetAchievementInfo, id)
    if not (ok and name) then return nil end
    local n = GetAchievementNumCriteria(id) or 0
    local cur, total = 0, 0
    if n == 1 then
        local _, _, done, qty, req = GetAchievementCriteriaInfo(id, 1)
        if (req or 0) > 1 then cur, total = qty or 0, req else cur, total = done and 1 or 0, 1 end
    else
        for i = 1, n do
            local _, _, done = GetAchievementCriteriaInfo(id, i)
            total = total + 1
            if done then cur = cur + 1 end
        end
    end
    if completed then cur = total end
    return { id = id, name = name, done = completed and true or false, cur = cur, total = total,
             description = description ~= "" and description or nil, reward = reward ~= "" and reward or nil }
end

local function ChainStep(entry)
    if type(entry) ~= "table" then return E.LabyrinthAchievement(entry) end
    local last
    for _, id in ipairs(entry) do
        local a = E.LabyrinthAchievement(id)
        if a then
            if not a.done then return a end
            last = a
        end
    end
    return last
end

-- For the Achievements card and the map pin. tiers is nil while any tier goal cannot be read, and the whole answer
-- is nil while the game has sent none of it.
function E.LabyrinthAchievementStatus()
    local st = { tiers = {}, tiersDone = 0, list = {}, feats = {}, summaryCount = 0 }
    for i, id in ipairs(LAB.tierAchievements) do
        local a = E.LabyrinthAchievement(id)
        if not a then
            st.tiers = nil
            break
        end
        st.tiers[i] = a
        if a.done then st.tiersDone = st.tiersDone + 1 end
    end
    for _, entry in ipairs(LAB.achievementList) do
        st.list[#st.list + 1] = ChainStep(entry)
    end
    for _, id in ipairs(LAB.featAchievements) do
        st.feats[#st.feats + 1] = E.LabyrinthAchievement(id)
    end
    if not st.tiers and #st.list == 0 and #st.feats == 0 then return nil end

    st.chests = E.LabyrinthAchievement(LAB.chestAchievement)
    st.chambers = E.LabyrinthAchievement(LAB.chamberAchievement)
    if st.tiers and st.tiersDone < #st.tiers then st.summaryCount = st.summaryCount + 1 end
    if st.chests and not st.chests.done then st.summaryCount = st.summaryCount + 1 end
    if st.chambers and not st.chambers.done then st.summaryCount = st.summaryCount + 1 end
    return st
end

local SEAL_NAMES = { [3] = "Akil'zon's Favor", [5] = "Jan'alai's Favor", [7] = "Nalorakk's Favor", [9] = "Halazzi's Favor" }

-- A seal is opened by the Journey's own rank reward, so the reward names it
function E.LabyrinthSealName(rank)
    local MF = C_MajorFactions
    if MF and MF.GetRenownRewardsForLevel then
        local ok, rewards = pcall(MF.GetRenownRewardsForLevel, E.LabyrinthJourneyFaction(), rank)
        local r = ok and type(rewards) == "table" and rewards[1]
        if type(r) == "table" and type(r.name) == "string" and r.name ~= "" then return r.name end
    end
    return SEAL_NAMES[rank] or tostring(rank)
end

local function ChestFound(QL, q)
    if QL.IsQuestFlaggedCompletedOnAccount and QL.IsQuestFlaggedCompletedOnAccount(q) then return true end
    return (QL.IsQuestFlaggedCompleted and QL.IsQuestFlaggedCompleted(q)) and true or false
end

-- Account-wide, as the achievement is: each chest has a warbound tracking quest. With the Journey unread, every
-- seal counts as closed.
function E.LabyrinthChests()
    local QL = C_QuestLog
    if not (QL and (QL.IsQuestFlaggedCompletedOnAccount or QL.IsQuestFlaggedCompleted)) then return nil end
    local j = E.GetLabyrinthJourney()
    local rank = j and j.level or 0
    local st = { rank = rank, found = 0, reach = 0, sealed = 0, total = 0, chambers = {} }
    local function add(ch, c, fall)
        local chest = { quest = c[1], x = c[2], y = c[3], seal = c[4] or 0, fall = fall }
        if ChestFound(QL, chest.quest) then
            chest.state, ch.found, st.found = "found", ch.found + 1, st.found + 1
        elseif chest.seal > rank then
            chest.state, st.sealed = "sealed", st.sealed + 1
        else
            chest.state, st.reach = "missing", st.reach + 1
        end
        ch.total, st.total = ch.total + 1, st.total + 1
        ch.chests[#ch.chests + 1] = chest
    end
    for _, c in ipairs(LAB.sturdyChests) do
        local ch = { area = c.area, found = 0, total = 0, chests = {} }
        for _, chest in ipairs(c.chests) do add(ch, chest, false) end
        for _, chest in ipairs(c.fall or {}) do add(ch, chest, true) end
        st.chambers[#st.chambers + 1] = ch
    end
    return st
end

-- nil while any of them cannot be read, so a cold client never reads as "8 to go"
function E.LabyrinthTiersLeft()
    local left = 0
    for _, id in ipairs(LAB.tierAchievements) do
        local a = E.LabyrinthAchievement(id)
        if not a then return nil end
        if not a.done then left = left + 1 end
    end
    return left
end

-- A step is named by its quest's title, and the chamber stands in until the client has the quest
function E.WahduStepName(i)
    local QL = C_QuestLog
    local q = LAB.wahduQuests[i]
    local title = q and QL and QL.GetTitleForQuestID and QL.GetTitleForQuestID(q)
    if type(title) == "string" and title ~= "" then return title end
    local area = LAB.wahduAreas[i]
    local name = area and C_Map and C_Map.GetAreaInfo and C_Map.GetAreaInfo(area)
    if type(name) == "string" and name ~= "" then return name end
    return L["Kindo'jan"]
end

local wahduTitlesAsked = false
function E.RequestWahduTitles()
    local QL = C_QuestLog
    if wahduTitlesAsked or not (QL and QL.RequestLoadQuestByID) then return end
    wahduTitlesAsked = true
    for _, q in ipairs(LAB.wahduQuests) do QL.RequestLoadQuestByID(q) end
end

-- Steps unlock for every character at the weekly reset, so this reads no level
function E.WahduUnlocked()
    local CI = C_CurrencyInfo
    local info = CI and CI.GetCurrencyInfo and CI.GetCurrencyInfo(LAB.wahduUnlockCurrency)
    local max = type(info) == "table" and info.maxQuantity
    if type(max) == "number" and max > 0 then return math_min(#LAB.wahduQuests, max) end
    return nil
end

function E.BelowLevelCap(level)
    local cap = GetMaxLevelForPlayerExpansion and GetMaxLevelForPlayerExpansion()
    return type(cap) == "number" and type(level) == "number" and level < cap
end

-- Steps are per character. The fragment's only source is a step, so the pieces bought are the steps turned in
-- that are no longer in the bags or bank.
function E.WahduStatus()
    local QL = C_QuestLog
    if not (QL and QL.IsQuestFlaggedCompleted) then return nil end
    if E.BelowLevelCap(UnitLevel and UnitLevel("player")) then return nil end
    local st = { done = 0, total = #LAB.wahduQuests }
    for i, q in ipairs(LAB.wahduQuests) do
        if QL.IsQuestFlaggedCompleted(q) then
            st.done = st.done + 1
        elseif not st.inLog and QL.GetLogIndexForQuestID and QL.GetLogIndexForQuestID(q) then
            st.step, st.inLog = i, true
            st.complete = (QL.IsComplete and QL.IsComplete(q)) and true or false
        elseif not st.step then
            st.step = i
        end
    end
    local max = E.WahduUnlocked()
    if max then
        st.unlocked = math_max(max, st.done + (st.inLog and 1 or 0))
        st.ready = st.unlocked - st.done
    end
    local cost = LAB.wahduPieceCost
    st.fragments = (C_Item and C_Item.GetItemCount and C_Item.GetItemCount(LAB.wahduFragment, true)) or 0
    st.pieces = math_max(0, math_floor((st.done - st.fragments) / cost))
    st.maxPieces = math_floor(st.total / cost)
    return st
end

function E.LabyrinthEntrance()
    return { name = E.LabyrinthDisplayName(), mapID = LAB.mapID, x = LAB.x, y = LAB.y,
             poiID = LAB.poiID, normalPoiID = LAB.normalPoiID }
end
