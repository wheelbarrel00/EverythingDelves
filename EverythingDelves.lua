------------------------------------------------------------------------
-- EverythingDelves.lua
-- Addon bootstrap: global namespace, SavedVariables, events, slash cmds
--
-- Midnight 12.0 API compliance: This addon is display/tracking only.
-- We read currencies, quest logs, map data, and item levels but never
-- inject gameplay logic or automate player actions.
------------------------------------------------------------------------

-- Global addon namespace â€” every other file references this table
EverythingDelves = {}
local E = EverythingDelves

E.name = "EverythingDelves"

-- C_AddOns.GetAddOnMetadata reads the ## Version field from the .toc
-- at load time (no event required).
E.version = C_AddOns.GetAddOnMetadata("EverythingDelves", "Version") or "1.0.0"

------------------------------------------------------------------------
-- Module registration
-- Tab files call RegisterModule() at load time to queue an init callback.
-- All callbacks run inside InitMainFrame() after the main window exists.
------------------------------------------------------------------------
E.modules = {}

function E:RegisterModule(callback)
    table.insert(self.modules, callback)
end

------------------------------------------------------------------------
-- Default SavedVariables structure
------------------------------------------------------------------------
-- Account-wide settings only. Per-character gameplay data
-- (delveHistory, manualComplete, activeRun) is NOT here — it lives in
-- per-character profiles, resolved in InitDB and reached transparently
-- through the E.db proxy. lastKnownBountifulIDs / lastKnownActiveSAs
-- stay account-wide because the bountiful / Special Assignment rotation
-- is region-wide and identical for every character on the account.
local DEFAULTS = {
    minimapButton = {
        show  = true,
        angle = 220, -- degrees around the minimap edge
    },
    framePosition    = nil,       -- { point, relPoint, x, y }
    defaultTab       = 1,
    completedDisplay = "dim",     -- "hide" | "dim" | "bottom"
    uiScale          = 1.0,
    accentColor      = "gold",    -- "red" | "gold" | "purple" | "green" | "darkblue"
    showWeeklyResetAlert   = true,
    sessionTracking        = true,
    showCompletedItems     = true,
    lowShardWarning        = true,
    lowShardThreshold      = 100,
    alertNewBountiful      = false,
    alertSpecialAssignment = false,
    showTrovehunterReminder = true,
    lastKnownBountifulIDs  = {},   -- list of POI IDs from last bountiful scan
    lastKnownActiveSAs     = {},   -- list of active SA quest IDs from last scan
}

-- Keys that are profile-scoped rather than account-wide. The E.db
-- proxy redirects reads/writes of these to the active profile.
local PROFILE_KEYS = {
    delveHistory   = true,
    manualComplete = true,
    activeRun      = true,
}

--- "Name - Realm" key identifying the current character.
local function CharKey()
    local name  = UnitName("player")  or "Unknown"
    local realm = GetRealmName()      or "Unknown"
    return name .. " - " .. realm
end
E.CharKey = CharKey

------------------------------------------------------------------------
-- SavedVariables helpers
------------------------------------------------------------------------
--- Ensure a profile table has all required sub-tables.
local function NormalizeProfile(p)
    p.delveHistory   = p.delveHistory   or {}
    p.manualComplete = p.manualComplete or {}
    -- activeRun intentionally left nil when absent.
    return p
end

--- Build the E.db proxy. Profile-scoped keys redirect to the active
--- profile (E.profile); everything else to the account-wide table.
--- Reading E.profile dynamically means a runtime profile switch is
--- reflected immediately with no re-proxy needed.
local function BuildDBProxy(sv)
    E.db = setmetatable({}, {
        __index = function(_, k)
            if PROFILE_KEYS[k] then
                return E.profile and E.profile[k]
            end
            return sv[k]
        end,
        __newindex = function(_, k, val)
            if PROFILE_KEYS[k] then
                if E.profile then E.profile[k] = val end
            else
                sv[k] = val
            end
        end,
    })
end

function E:InitDB()
    if not EverythingDelvesDB then
        EverythingDelvesDB = {}
    end
    local sv = EverythingDelvesDB

    -- Shallow-merge account-wide setting defaults without overwriting
    -- existing values so player settings survive addon updates.
    for k, v in pairs(DEFAULTS) do
        if sv[k] == nil then
            if type(v) == "table" then
                sv[k] = CopyTable(v)
            else
                sv[k] = v
            end
        end
    end

    -- Profile containers.
    sv.profiles    = sv.profiles    or {}
    sv.profileKeys = sv.profileKeys or {}

    local charKey = CharKey()

    -- One-time migration (pre-1.5.0 → profiles). The old account-wide
    -- gameplay tables are MOVED into an "Original" profile — never
    -- deleted. The first character to log in after the update claims
    -- "Original", so a main keeps its full history with zero user
    -- action; alts get their own fresh profile.
    if not sv._profileMigrated then
        local hadData =
            (type(sv.delveHistory)   == "table" and next(sv.delveHistory))
            or (type(sv.manualComplete) == "table" and next(sv.manualComplete))
        if hadData then
            sv.profiles["Original"] = NormalizeProfile({
                delveHistory   = sv.delveHistory,
                manualComplete = sv.manualComplete,
                activeRun      = sv.activeRun,
            })
            sv.profileKeys[charKey] = "Original"
        end
        sv.delveHistory     = nil
        sv.manualComplete   = nil
        sv.activeRun        = nil
        sv._profileMigrated = true
    end

    -- Resolve this character's profile (fresh per character by default).
    local profName = sv.profileKeys[charKey]
    if not profName or not sv.profiles[profName] then
        profName = charKey
        sv.profileKeys[charKey] = profName
    end
    if not sv.profiles[profName] then
        sv.profiles[profName] = NormalizeProfile({})
    end

    E.activeProfileName = profName
    E.profile = NormalizeProfile(sv.profiles[profName])

    BuildDBProxy(sv)
end

--- Reset ONLY account-wide settings. Profiles (delve history,
--- completion marks, mid-run state) are deliberately preserved —
--- wiping every character's history on a settings reset would be
--- catastrophic for the userbase.
function E:ResetDB()
    local sv = EverythingDelvesDB
    if not sv then return end
    for k, v in pairs(DEFAULTS) do
        if type(v) == "table" then
            sv[k] = CopyTable(v)
        else
            sv[k] = v
        end
    end
    -- Re-resolve profile / rebuild proxy (profiles untouched).
    E:InitDB()
end

------------------------------------------------------------------------
-- Profile management API (used by UI/TabProfiles.lua)
------------------------------------------------------------------------

--- Sorted array of all profile names.
function E:GetProfileNames()
    local names = {}
    local sv = EverythingDelvesDB
    if sv and sv.profiles then
        for name in pairs(sv.profiles) do
            names[#names + 1] = name
        end
        table.sort(names, function(a, b) return a:lower() < b:lower() end)
    end
    return names
end

--- Point the current character at an existing profile and make it live.
function E:SwitchProfile(name)
    local sv = EverythingDelvesDB
    if not sv or not name or not sv.profiles[name] then return false end
    sv.profileKeys[CharKey()] = name
    E.activeProfileName = name
    E.profile = NormalizeProfile(sv.profiles[name])
    if E.RefreshDelveHistoryTab then E:RefreshDelveHistoryTab() end
    if E.RefreshBountifulData    then E:RefreshBountifulData(true) end
    return true
end

--- Create a new empty profile and switch the current character to it.
function E:CreateProfile(name)
    local sv = EverythingDelvesDB
    if not sv or not name or name == "" then return false, "Invalid name." end
    if sv.profiles[name] then return false, "A profile with that name already exists." end
    sv.profiles[name] = NormalizeProfile({})
    return E:SwitchProfile(name)
end

--- Duplicate an existing profile under a new name and switch to it.
function E:CopyProfile(sourceName, newName)
    local sv = EverythingDelvesDB
    if not sv or not sv.profiles[sourceName] then return false, "Source profile missing." end
    if not newName or newName == "" then return false, "Invalid name." end
    if sv.profiles[newName] then return false, "A profile with that name already exists." end
    sv.profiles[newName] = NormalizeProfile(CopyTable(sv.profiles[sourceName]))
    return E:SwitchProfile(newName)
end

--- Delete a profile. The active profile cannot be deleted (switch away
--- first). Characters that pointed at it fall back to a fresh
--- per-character profile on their next login.
function E:DeleteProfile(name)
    local sv = EverythingDelvesDB
    if not sv or not sv.profiles[name] then return false, "Profile missing." end
    if name == E.activeProfileName then
        return false, "Can't delete the profile you're currently using."
    end
    sv.profiles[name] = nil
    for ck, pk in pairs(sv.profileKeys) do
        if pk == name then sv.profileKeys[ck] = nil end
    end
    return true
end

------------------------------------------------------------------------
-- Event dispatcher
-- Thin wrapper so each system can register/unregister independently.
------------------------------------------------------------------------
local eventFrame = CreateFrame("Frame")
E.eventFrame = eventFrame
local eventHandlers = {}

function E:RegisterEvent(event, handler)
    eventHandlers[event] = handler
    eventFrame:RegisterEvent(event)
end

function E:UnregisterEvent(event)
    eventHandlers[event] = nil
    eventFrame:UnregisterEvent(event)
end

eventFrame:SetScript("OnEvent", function(_, event, ...)
    if eventHandlers[event] then
        eventHandlers[event](E, event, ...)
    end
end)

------------------------------------------------------------------------
-- Toggle main window
------------------------------------------------------------------------
function E:ToggleMainFrame()
    if E.MainFrame then
        if E.MainFrame:IsShown() then
            E.MainFrame:Hide()
        else
            E.MainFrame:Show()
        end
    end
end

------------------------------------------------------------------------
-- Slash commands: /ed and /everythingdelves
------------------------------------------------------------------------
SLASH_EVERYTHINGDELVES1 = "/ed"
SLASH_EVERYTHINGDELVES2 = "/everythingdelves"

SlashCmdList["EVERYTHINGDELVES"] = function(msg)
    msg = strtrim(msg):lower()
    if msg == "reset" then
        E:ResetDB()
        print("|cFFFF2222Everything Delves|r: Settings reset to defaults.")
    else
        E:ToggleMainFrame()
    end
end

------------------------------------------------------------------------
-- Core events
------------------------------------------------------------------------

-- PLAYER_LOGIN: fires once after all addons are loaded and the player
-- object exists. This is the right time to touch SavedVariables and
-- build the UI.
E:RegisterEvent("PLAYER_LOGIN", function(self)
    self:InitDB()

    -- Build the main window (defined in UI/MainFrame.lua)
    if self.InitMainFrame then
        self:InitMainFrame()
    end

    -- Apply the saved accent color theme to every registered widget.
    if self.ApplyAccentColor then
        self:ApplyAccentColor(self.db.accentColor)
    end

    -- Pre-warm the AreaPOI cache for every delve zone. This eliminates
    -- the race where a player teleports straight into a delve from an
    -- unrelated zone and C_AreaPoiInfo.GetAreaPOIInfo returns nil
    -- because the zone was never loaded — causing wasBountiful=false to
    -- be stamped onto a run that was actually bountiful.
    if C_AreaPoiInfo and C_AreaPoiInfo.GetAreaPOIForMap and self.DelveData then
        local seenMaps = {}
        for _, delve in ipairs(self.DelveData) do
            if delve.mapID and not seenMaps[delve.mapID] then
                seenMaps[delve.mapID] = true
                pcall(C_AreaPoiInfo.GetAreaPOIForMap, delve.mapID)
            end
        end
    end

    -- Flag one-time auto-repair to run after the next bountiful refresh.
    self._autoRepairPending = true

    -- Force a refresh shortly after login so the auto-repair pass fires
    -- without waiting for the user to open the Bountiful tab.
    C_Timer.After(3, function()
        if self.RefreshBountifulData then
            self:RefreshBountifulData(true)
        end
    end)

    print("|cFFFF2222Everything Delves|r v" .. self.version
        .. " loaded. Type |cFFFFD700/ed|r to open.")
end)

-- PLAYER_ENTERING_WORLD: fires on login, reload, and every zone change.
-- We use it to seed session-scoped counters.
E:RegisterEvent("PLAYER_ENTERING_WORLD", function(self, _, isLogin, isReload)
    if isLogin or isReload then
        self.sessionData = {
            bountifulCompleted = 0,
            loginTime          = time(),
        }
    end
end)

-- Data-tracking events â€” uses a callback list so multiple modules
-- can safely register for the same event without wrapping.
E.eventCallbacks = {}

--- Register a callback function for a data event.
--- Multiple callbacks can be registered for the same event name.
--- @param eventName string  Logical event name (e.g. "CurrencyUpdate")
--- @param fn        function  Callback receiving (E) as first argument
function E:RegisterCallback(eventName, fn)
    if not self.eventCallbacks[eventName] then
        self.eventCallbacks[eventName] = {}
    end
    table.insert(self.eventCallbacks[eventName], fn)
end

--- Fire all registered callbacks for a logical event.
local function FireCallbacks(eventName)
    local cbs = E.eventCallbacks[eventName]
    if cbs then
        for _, fn in ipairs(cbs) do
            fn(E)
        end
    end
end

-- Debouncer: Blizzard events like QUEST_LOG_UPDATE and
-- CURRENCY_DISPLAY_UPDATE can fire dozens of times per second
-- (e.g. during zone changes or quest turn-ins). Without coalescing,
-- each event triggers a full tab refresh â€” tens of SetText calls and
-- many short-lived intermediate strings per burst. We batch via a
-- 0.25s trailing-edge timer: imperceptible to the player, but reduces
-- refresh work (and GC pressure) by orders of magnitude during bursts.
--
-- The `tick` closure is persistent (one per event), so no per-event
-- closure allocation in steady state.
local function Debounce(delay, eventName)
    local pending = false
    local function tick()
        pending = false
        FireCallbacks(eventName)
    end
    return function()
        if pending then return end
        pending = true
        C_Timer.After(delay, tick)
    end
end

local fireCurrency       = Debounce(0.25, "CurrencyUpdate")
local fireQuestLog       = Debounce(0.25, "QuestLogUpdate")
local fireAreaPois       = Debounce(0.25, "AreaPoisUpdated")
local fireBagUpdate      = Debounce(0.25, "BagUpdate")
local fireInventory      = Debounce(0.25, "InventoryChanged")
local fireWorldQuestDone = Debounce(0.25, "WorldQuestCompleted")

E:RegisterEvent("CURRENCY_DISPLAY_UPDATE", fireCurrency)
E:RegisterEvent("QUEST_LOG_UPDATE",        fireQuestLog)
E:RegisterEvent("AREA_POIS_UPDATED",       fireAreaPois)
E:RegisterEvent("BAG_UPDATE_DELAYED",      fireBagUpdate)

E:RegisterEvent("UNIT_INVENTORY_CHANGED", function(_, _, unit)
    if unit == "player" then fireInventory() end
end)

-- WORLD_QUEST_COMPLETED fires when a world quest objective is turned in.
-- Wrap in pcall in case the event is renamed in a future patch.
pcall(function()
    E:RegisterEvent("WORLD_QUEST_COMPLETED", fireWorldQuestDone)
end)

------------------------------------------------------------------------
-- DELVE HISTORY TRACKER
-- Detects completed Midnight delves (SCENARIO_COMPLETED) and appends
-- a record to EverythingDelvesDB.delveHistory.
--
-- Uses its own CreateFrame so it doesn't conflict with the single-
-- handler-per-event dispatcher above.
--
-- Memory: single persistent `runState` table wiped in-place on entry.
-- Saved recentRuns capped at 20 per delve; lifetime = fixed numbers.
------------------------------------------------------------------------

local COFFER_KEY_CURRENCY = 2915  -- Restored Coffer Key
local MAX_RECENT_RUNS     = 20

-- Single reusable scratch table for the active run â€” never replaced.
E.delveRunState = {
    inDelve        = false,
    delveName      = nil,
    delveKind      = nil,   -- "regular" | "nemesis"
    startTime      = 0,
    deaths         = 0,
    startKeyCount  = 0,
    tier           = 0,     -- captured at entry via C_DelvesUI
    wasBountiful   = false, -- snapshot at BeginDelveRun
    trovehunterPopupShown = false, -- one-shot guard for the reminder popup
}

local runState = E.delveRunState

--- Safely read the quantity of a currency.
local function GetCurrencyQty(id)
    if C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo then
        local info = C_CurrencyInfo.GetCurrencyInfo(id)
        if info then return info.quantity or 0 end
    end
    return 0
end

--- Auto-detect the current delve tier (1-11) or return nil if unknown.
--- Strategy order (most authoritative first):
---   1. Parse a number out of GetInstanceInfo()'s difficultyName
---      (typically just "Delves" in Midnight, but kept as fallback).
---   2. Parse a number out of C_Scenario.GetInfo()/GetStepInfo() names.
---   3. Scrape the ObjectiveTrackerFrame UI for "Tier N" text.
local function AutoDetectDelveTier()
    -- Method 1: difficulty name
    local _, _, _, difficultyName = GetInstanceInfo()
    if difficultyName and difficultyName ~= "" then
        local m = difficultyName:match("(%d+)")
        local n = m and tonumber(m)
        if n and n >= 1 and n <= 11 then return n end
    end

    -- Method 2: scenario / step name
    local m2
    pcall(function()
        if C_Scenario and C_Scenario.GetInfo then
            local scenarioName = C_Scenario.GetInfo() or ""
            local m = scenarioName:match("(%d+)")
            local n = m and tonumber(m)
            if n and n >= 1 and n <= 11 then m2 = n; return end
        end
        if C_Scenario and C_Scenario.GetStepInfo then
            local stepName = C_Scenario.GetStepInfo()
            if stepName and stepName ~= "" then
                local m = stepName:match("(%d+)")
                local n = m and tonumber(m)
                if n and n >= 1 and n <= 11 then m2 = n; return end
            end
        end
    end)
    if m2 then return m2 end

    -- Method 3: scrape the ObjectiveTrackerFrame for tier text.
    -- Restored to the exact 1.4.8 behaviour after attempted "fixes" in
    -- 1.4.9 / earlier 1.4.10 made the History tab worse. Known
    -- limitation: in T11 delves where the lives counter happens to be
    -- the first standalone digit encountered, this can mis-record the
    -- run as a lower tier — but at least it records *something*, which
    -- is far better than logging tier=0 across the board.
    local tracker = _G["ObjectiveTrackerFrame"] or _G["ScenarioObjectiveTracker"]
    if tracker then
        local foundDelveHeader = false
        local foundTier
        local zoneName = GetRealZoneText() or ""

        local function SearchForTier(frame)
            if foundTier then return end
            if not frame or frame:IsForbidden() then return end

            local nRegs = frame:GetNumRegions()
            for i = 1, nRegs do
                local r = select(i, frame:GetRegions())
                if r and r:GetObjectType() == "FontString" and r:IsShown() then
                    local txt = r:GetText()
                    if txt and txt ~= "" then
                        local clean = txt:gsub("|c%x%x%x%x%x%x%x%x", "")
                                         :gsub("|r", "")
                        local m = clean:match("Tier%s*:?%s*(%d+)")
                            or clean:match("Difficulty%s*:?%s*(%d+)")
                        if m then
                            local n = tonumber(m)
                            if n and n >= 1 and n <= 11 then
                                foundTier = n
                                return
                            end
                        end
                        if clean == "Delves" or clean == zoneName then
                            foundDelveHeader = true
                        elseif foundDelveHeader and clean:match("^%d+$") then
                            local n = tonumber(clean)
                            if n and n >= 1 and n <= 11 then
                                foundTier = n
                                return
                            end
                        end
                    end
                end
            end

            local nChildren = frame:GetNumChildren()
            for i = 1, nChildren do
                local child = select(i, frame:GetChildren())
                SearchForTier(child)
                if foundTier then return end
            end
        end

        pcall(SearchForTier, tracker)
        if foundTier then return foundTier end
    end

    return nil
end

--- Resolve the current delve name from the most reliable sources.
--- Priority: GetRealZoneText() â†’ C_Map map ID lookup â†’ GetInstanceInfo.
local function ResolveDelveName()
    local zoneName = GetRealZoneText()
    if zoneName and zoneName ~= "" and E.LoggableDelveNames[zoneName] then
        return zoneName
    end
    if C_Map and C_Map.GetBestMapForUnit then
        local ok, mapID = pcall(C_Map.GetBestMapForUnit, "player")
        if ok and mapID and E.DelveZoneIDs and E.DelveZoneIDs[mapID] then
            return E.DelveZoneIDs[mapID]
        end
    end
    local instName = GetInstanceInfo()
    return instName
end

--- Match a scenario name against our Midnight delve directory.
--- Returns (canonicalName, kind) on match, or nil.
--- Tries exact, then case-insensitive, then "contains" match so minor
--- variations ("The Grudge Pit" vs "Grudge Pit") still work.
local function MatchDelveName(scenarioName)
    if not scenarioName or scenarioName == "" then return nil end
    local nameMap = E.LoggableDelveNames
    if not nameMap then return nil end

    -- Exact
    local kind = nameMap[scenarioName]
    if kind then return scenarioName, kind end

    -- Case-insensitive
    local lowered = scenarioName:lower()
    for k, v in pairs(nameMap) do
        if k:lower() == lowered then return k, v end
    end

    -- Substring either direction (handles "The Grudge Pit" â†” "Grudge Pit")
    for k, v in pairs(nameMap) do
        local kl = k:lower()
        if lowered:find(kl, 1, true) or kl:find(lowered, 1, true) then
            return k, v
        end
    end
    return nil
end

--- Try to capture the active delve tier into runState.tier.
--- No-op if already captured. Called on every SCENARIO_UPDATE while
--- inside a delve â€” the ObjectiveTracker UI may not populate on the
--- first fire, so we keep retrying until we get a value.
local function TryCaptureTier(source)
    if runState.tier and runState.tier > 0 then return end
    local t = AutoDetectDelveTier()
    if t and t > 0 then
        runState.tier = t
        -- Persist captured tier to SavedVariables so /reload mid-delve
        -- doesn't lose the value. Previously saved.tier stayed at the
        -- 0 written by BeginDelveRun, forcing every post-reload run to
        -- re-detect from scratch (often failing because the UI wasn't
        -- rebuilt yet).
        if E.db and E.db.activeRun then
            E.db.activeRun.tier = t
        end
        if E.MaybeShowTrovehunterReminder then
            E:MaybeShowTrovehunterReminder()
        end
    end
end

--- Re-check bountiful status and flip runState.wasBountiful to true if
--- the current delve is on the live bountiful list. NEVER flips back
--- to false once set — once detected as bountiful, it stays locked.
--- This lets the snapshot recover from cold-cache map data at entry:
--- if C_AreaPoiInfo wasn't ready at BeginDelveRun, a later
--- SCENARIO_UPDATE retry will still catch it.
local function RefreshBountifulSnapshot()
    if runState.wasBountiful then return end  -- already locked true
    if not runState.inDelve or not runState.delveName then return end
    if not E.RefreshBountifulData then return end

    E:RefreshBountifulData(true)

    if E.currentBountifulNames
            and E.currentBountifulNames[runState.delveName] then
        runState.wasBountiful = true
        if E.db and E.db.activeRun then
            E.db.activeRun.wasBountiful = true
        end
    end
end

--- Reset the active-run state for a newly-entered delve.
local function BeginDelveRun(name, kind)
    runState.inDelve       = true
    runState.delveName     = name
    runState.delveKind     = kind
    runState.startTime     = GetTime()
    runState.deaths        = 0
    runState.startKeyCount = GetCurrencyQty(COFFER_KEY_CURRENCY)
    runState.tier          = 0
    runState.wasBountiful  = false
    runState.trovehunterPopupShown = false
    -- Persist run start to SavedVariables so duration survives /reload
    -- and brief disconnects. GetTime() is continuous across /reload.
    if E.db then
        E.db.activeRun = {
            name          = name,
            kind          = kind,
            startTime     = runState.startTime,
            deaths        = 0,
            startKeyCount = runState.startKeyCount,
            tier          = 0,
            wasBountiful  = false,
            trovehunterPopupShown = false,
        }
    end
    -- Initial bountiful snapshot. May fail at entry if the POI cache is
    -- cold; subsequent SCENARIO_UPDATE retries will flip the flag the
    -- moment the data is available.
    RefreshBountifulSnapshot()
    TryCaptureTier("BeginDelveRun")

    -- Popup heartbeat: SCENARIO_UPDATE only fires on objective changes,
    -- which can be sparse (especially right after a /reload or in a
    -- quiet delve). Run a 1Hz timer for the first 30 seconds so
    -- MaybeShowTrovehunterReminder gets multiple shots at firing as
    -- tier capture / POI cache / aura state stabilize. The popup's own
    -- one-shot guard prevents duplicate firings.
    local heartbeatTicks = 0
    if E._popupHeartbeat then E._popupHeartbeat:Cancel() end
    E._popupHeartbeat = C_Timer.NewTicker(1, function(self)
        heartbeatTicks = heartbeatTicks + 1
        if not runState.inDelve
                or runState.trovehunterPopupShown
                or heartbeatTicks > 30 then
            self:Cancel()
            E._popupHeartbeat = nil
            return
        end
        -- Cheap re-attempt of tier + bountiful in case the SCENARIO_UPDATE
        -- driven retry never fires.
        TryCaptureTier("heartbeat")
        RefreshBountifulSnapshot()
        if E.MaybeShowTrovehunterReminder then
            E:MaybeShowTrovehunterReminder()
        end
    end)
end

local function EndDelveRun()
    runState.inDelve       = false
    runState.delveName     = nil
    runState.delveKind     = nil
    runState.startTime     = 0
    runState.deaths        = 0
    runState.startKeyCount = 0
    runState.tier          = 0
    runState.wasBountiful  = false
    runState.trovehunterPopupShown = false
    -- Cancel popup heartbeat — nothing for it to do once the run ends.
    if E._popupHeartbeat then
        E._popupHeartbeat:Cancel()
        E._popupHeartbeat = nil
    end
    -- Clear the persisted run so stale state never carries over.
    if E.db then
        E.db.activeRun = nil
    end
end

--- Append a completed run to the SavedVariables history.
--- Updates lifetime counters in-place and caps recentRuns at 20.
function E:LogDelveRun(name, tier, duration, deaths, keyUsed, wasBountiful)
    if not name or not self.db then
        return
    end
    self.db.delveHistory = self.db.delveHistory or {}
    local entry = self.db.delveHistory[name]
    if not entry then
        entry = {
            lifetime = {
                totalRuns     = 0,
                highestTier   = 0,
                totalDeaths   = 0,
                totalDuration = 0,
                fastestTime   = 0,
                totalKeysUsed = 0,
                firstRun      = 0,
                lastRun       = 0,
            },
            recentRuns = {},
        }
        self.db.delveHistory[name] = entry
    end

    local now = time()
    local life = entry.lifetime
    life.totalRuns     = (life.totalRuns or 0) + 1
    life.totalDeaths   = (life.totalDeaths or 0) + (deaths or 0)
    life.totalDuration = (life.totalDuration or 0) + (duration or 0)
    life.totalKeysUsed = (life.totalKeysUsed or 0) + (keyUsed and 1 or 0)
    if tier and tier > (life.highestTier or 0) then
        life.highestTier = tier
    end
    if duration and duration > 0 then
        if not life.fastestTime or life.fastestTime == 0
                or duration < life.fastestTime then
            life.fastestTime = duration
        end
    end
    if not life.firstRun or life.firstRun == 0 then
        life.firstRun = now
    end
    life.lastRun = now

    -- Insert newest at position 1; cap at MAX_RECENT_RUNS.
    local recent = entry.recentRuns
    table.insert(recent, 1, {
        tier         = tier or 0,
        duration     = duration or 0,
        deaths       = deaths or 0,
        keyUsed      = keyUsed and true or false,
        timestamp    = now,
        wasBountiful = wasBountiful and true or false,
    })
    while #recent > MAX_RECENT_RUNS do
        recent[#recent] = nil
    end
end

--- Wipe all delve history for this character.
function E:ClearDelveHistory()
    if not self.db then return end
    if self.db.delveHistory then
        wipe(self.db.delveHistory)
    end
    if self.RefreshDelveHistoryTab then
        self:RefreshDelveHistoryTab()
    end
end

--- One-time auto-repair of stale wasBountiful flags.
--- Cross-checks this week's recorded runs against the LIVE bountiful
--- list. Any run whose delve is currently bountiful but was logged
--- with wasBountiful=false (because the POI cache was cold at delve
--- entry) gets its flag corrected. Only repairs THIS WEEK's runs —
--- past weeks' bountifuls have rotated out and are unrecoverable.
---
--- Triggered once per session: PLAYER_LOGIN sets `_autoRepairPending`,
--- then the next successful `RefreshBountifulData` calls this and
--- clears the flag.
function E:AutoRepairBountifulHistory()
    if not self._autoRepairPending then return end
    if not self.db or not self.db.delveHistory then return end
    if not self.currentBountifulNames then return end
    -- A truly empty lookup table means POI data hasn't loaded yet; wait
    -- for a later refresh rather than wasting our one-shot repair pass.
    if not next(self.currentBountifulNames) then return end

    local lastReset = 0
    if C_DateAndTime and C_DateAndTime.GetSecondsUntilWeeklyReset then
        local secs = C_DateAndTime.GetSecondsUntilWeeklyReset()
        if secs and secs > 0 then
            local now = (GetServerTime and GetServerTime()) or time()
            lastReset = now + secs - 604800
        end
    end

    local repaired = 0
    for delveName, entry in pairs(self.db.delveHistory) do
        if self.currentBountifulNames[delveName] and entry.recentRuns then
            for _, run in ipairs(entry.recentRuns) do
                if (run.timestamp or 0) >= lastReset
                        and not run.wasBountiful then
                    run.wasBountiful = true
                    repaired = repaired + 1
                end
            end
        end
    end

    self._autoRepairPending = false

    if repaired > 0 then
        print(self.CC.header .. "Everything Delves|r: Repaired "
            .. repaired .. " mis-flagged bountiful run"
            .. (repaired == 1 and "" or "s") .. " from this week.")
        if self.RefreshDelveHistoryTab then
            self:RefreshDelveHistoryTab()
        end
    end
end

------------------------------------------------------------------------
-- Delve event frame (independent of the shared dispatcher so the
-- existing single-handler-per-event contract is preserved)
------------------------------------------------------------------------
local delveFrame = CreateFrame("Frame")
delveFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
delveFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
delveFrame:RegisterEvent("SCENARIO_UPDATE")
delveFrame:RegisterEvent("SCENARIO_COMPLETED")
delveFrame:RegisterEvent("PLAYER_DEAD")

--- Try to start tracking if we're currently inside a delve.
local function TryBeginFromCurrentZone(source)
    local _, _, instanceType = IsInInstance(), nil, select(2, IsInInstance())
    local _, zoneInstName, diffID = GetInstanceInfo()

    -- Only act on delve difficulty (208) or scenario instance type.
    local inScenario = (instanceType == "scenario")
    local isDelve    = (diffID == 208) or inScenario

    if not isDelve then
        if runState.inDelve then
            EndDelveRun()
        end
        return
    end

    local resolvedName = ResolveDelveName()
    local candidate    = resolvedName or zoneInstName
    local matchedName, kind = MatchDelveName(candidate or "")

    if matchedName then
        if not runState.inDelve or runState.delveName ~= matchedName then
            -- If we have a persisted active run for this same delve
            -- (saved across /reload or a brief disconnect), restore
            -- runState from it rather than starting a fresh timer.
            -- Edge case: if the WoW client was fully restarted,
            -- GetTime() resets to near-zero. In that case the saved
            -- startTime will be greater than the current GetTime();
            -- discard the saved run and start fresh.
            local saved = E.db and E.db.activeRun
            if saved and saved.name == matchedName
                    and saved.startTime
                    and saved.startTime <= GetTime() then
                runState.inDelve       = true
                runState.delveName     = matchedName
                runState.delveKind     = saved.kind
                runState.startTime     = saved.startTime
                runState.deaths        = saved.deaths or 0
                runState.startKeyCount = saved.startKeyCount or 0
                runState.tier          = saved.tier or 0
                runState.wasBountiful  = saved.wasBountiful or false
                runState.trovehunterPopupShown = saved.trovehunterPopupShown or false
                TryCaptureTier("restored")
                -- If tier was already captured pre-/reload, TryCaptureTier
                -- short-circuits and won't trigger the reminder check.
                -- Run it explicitly so a never-shown popup can still fire.
                if E.MaybeShowTrovehunterReminder then
                    E:MaybeShowTrovehunterReminder()
                end
            else
                if E.db then E.db.activeRun = nil end
                BeginDelveRun(matchedName, kind)
            end
        else
            TryCaptureTier(source or "retry")
        end
    else
        -- Start a provisional run so we still track timing / deaths.
        if not runState.inDelve then
            runState.inDelve       = true
            runState.delveName     = candidate
            runState.delveKind     = nil
            runState.startTime     = GetTime()
            runState.deaths        = 0
            runState.startKeyCount = GetCurrencyQty(COFFER_KEY_CURRENCY)
            runState.tier          = 0
            TryCaptureTier("provisional")
        else
            TryCaptureTier(source or "retry")
        end
    end
end

delveFrame:SetScript("OnEvent", function(_, event, ...)
    if event == "PLAYER_ENTERING_WORLD"
            or event == "ZONE_CHANGED_NEW_AREA"
            or event == "SCENARIO_UPDATE" then
        -- SCENARIO_UPDATE fires 5-10x during delve entry. Once we're in
        -- a delve and have already captured the tier, skip the expensive
        -- ObjectiveTracker scrape inside TryBeginFromCurrentZone — but
        -- still re-attempt the bountiful snapshot (POI cache may have
        -- warmed since entry) and re-evaluate the trovehunter popup
        -- (bag/aura state may have changed mid-run).
        if event == "SCENARIO_UPDATE"
                and runState.inDelve
                and runState.tier and runState.tier > 0 then
            RefreshBountifulSnapshot()
            if E.MaybeShowTrovehunterReminder then
                E:MaybeShowTrovehunterReminder()
            end
            return
        end
        TryBeginFromCurrentZone(event)

    elseif event == "PLAYER_DEAD" then
        if runState.inDelve then
            runState.deaths = runState.deaths + 1
        end

    elseif event == "SCENARIO_COMPLETED" then
        -- Resolve delve name from the most reliable still-available
        -- source, then fall back to whatever we captured at entry.
        local candidate = ResolveDelveName()
        if not candidate or candidate == "" then
            candidate = runState.delveName
        end
        local matchedName = MatchDelveName(candidate or "")

        local duration = (runState.startTime > 0)
            and math.max(0, math.floor(GetTime() - runState.startTime))
            or 0

        -- Final attempts at tier and bountiful before logging. The UI
        -- may already be torn down (tier scrape can fail here) but it
        -- costs nothing to try once more, and saves the run record from
        -- being stamped with tier=0 / wasBountiful=false when the data
        -- was only a few hundred ms away from being available.
        local tier = runState.tier or 0
        if tier == 0 then
            local lastChance = AutoDetectDelveTier()
            if lastChance and lastChance > 0 then
                tier = lastChance
                runState.tier = lastChance
            end
        end
        RefreshBountifulSnapshot()

        local keyNow  = GetCurrencyQty(COFFER_KEY_CURRENCY)
        local keyUsed = (runState.startKeyCount > 0)
            and (keyNow < runState.startKeyCount)
            or false

        if matchedName then
            E:LogDelveRun(
                matchedName, tier, duration, runState.deaths,
                keyUsed, runState.wasBountiful
            )
            if E.RefreshDelveHistoryTab then
                E:RefreshDelveHistoryTab()
            end
        end

        EndDelveRun()
    end
end)
