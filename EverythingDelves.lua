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
-- Community Discord
-- WoW can't open a web browser, so the "Join our Discord!" links (main
-- window title bar + What's New popup) pop a copyable invite instead. The
-- edit box is pre-selected so the player just presses Ctrl+C.
------------------------------------------------------------------------
E.DISCORD_URL = "https://discord.gg/vm8K2WfQUE"

StaticPopupDialogs["EVERYTHINGDELVES_DISCORD"] = {
    text = "Join the Everything Delves community for help, feedback, and updates.\n\nCopy the invite below (it's pre-selected — just press Ctrl+C):",
    button1 = "Close",
    hasEditBox = true,
    editBoxWidth = 220,
    OnShow = function(self)
        local eb = self.editBox or (self.EditBox)
        if eb then
            eb:SetText(E.DISCORD_URL)
            eb:HighlightText()
            eb:SetFocus()
            eb:SetScript("OnEscapePressed", function(box) box:GetParent():Hide() end)
            -- Keep the link intact: re-fill + re-select if the player edits it.
            eb:SetScript("OnTextChanged", function(box)
                if box:GetText() ~= E.DISCORD_URL then
                    box:SetText(E.DISCORD_URL)
                    box:HighlightText()
                end
            end)
        end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

function E:ShowDiscord()
    StaticPopup_Show("EVERYTHINGDELVES_DISCORD")
end

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
-- (delveHistory, activeRun) is NOT here — it lives in
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
    historyCap       = 20,        -- recentRuns kept per delve (History tab slider)
    uiScale          = 1.0,
    accentColor      = "gold",    -- "red" | "gold" | "purple" | "green" | "darkblue"
    -- (completedDisplay / showCompletedItems / showWeeklyResetAlert /
    --  sessionTracking removed — their Options controls were non-functional;
    --  re-add here when the backing behavior is actually implemented.)
    lowShardWarning        = true,
    lowShardThreshold      = 100,
    alertNewBountiful      = false,
    alertSpecialAssignment = false,
    showTrovehunterReminder = true,
    muteValeera            = false,
    muteValeeraBubbles     = false,
    muteDundun             = false,
    seenWhatsNewVersion    = "",
    lastKnownBountifulIDs  = {},   -- list of POI IDs from last bountiful scan
    lastKnownActiveSAs     = {},   -- list of active SA quest IDs from last scan
    -- Account-wide Delver's Call roster: charKey → { name, realm, class,
    -- states = { [delve] = state }, updated }. Account-wide (NOT a profile
    -- key) so the alt rollup can see every character at once — you can't
    -- read an alt's quest log, so each character snapshots its own state.
    delversCallRoster      = {},
    -- Account-wide learned boss map: delveName → { [storyVariant] = bossName }.
    -- Populated live from ENCOUNTER_END as delves are completed, so the
    -- "today's boss" highlight knows which boss a multi-boss delve fields
    -- for the current story variant. Account-wide because the variant→boss
    -- pairing is region-wide and identical for every character.
    delveBossMap           = {},
}

-- Keys that are profile-scoped rather than account-wide. The E.db
-- proxy redirects reads/writes of these to the active profile.
local PROFILE_KEYS = {
    delveHistory   = true,
    activeRun      = true,
    -- manualComplete retired: manual completion was replaced by daily-bounded
    -- auto-completion and nothing reads/writes it anymore. The migration below
    -- still preserves any legacy data into the "Original" profile.
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
    -- manualComplete intentionally not normalized — the feature is retired.
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
    elseif msg == "curios" or msg:sub(1, 7) == "curios " then
        local arg = msg:sub(8)
        if E.ToggleCurioPopup then
            E:ToggleCurioPopup(arg)
        end
    elseif msg == "whatsnew" then
        if E.ShowWhatsNew then
            E:ShowWhatsNew()
        end
    elseif msg == "debug" then
        -- Toggle verbose tier-tracker logging. Off by default and silent
        -- for normal players; used to diagnose how a delve's tier is
        -- captured and logged. Persisted so it survives a /reload mid-test.
        if E.db then
            E.db.debugTier = not E.db.debugTier
            print("|cFFFF2222Everything Delves|r: tier debug "
                .. (E.db.debugTier and "|cFF22FF22ON|r" or "|cFFFF2222OFF|r")
                .. ". Run two delves back-to-back, then send me every line"
                .. " that starts with |cFFFFD700[ED tier]|r.")
        end
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

    -- Clean up any runs logged with an absurd duration by the old
    -- GetTime() staleness bug (safe + idempotent).
    self:RepairAbsurdDurations()

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
-- Saved recentRuns capped per delve (configurable, default 20); lifetime = fixed numbers.
------------------------------------------------------------------------

local COFFER_KEY_CURRENCY = 2915  -- Restored Coffer Key
-- recentRuns retention per delve. User-configurable via the History tab
-- slider, clamped to [MIN, MAX]; MIN is also the default and floor. Raising
-- it keeps more runs going forward (already-trimmed runs can't be recovered).
E.HISTORY_CAP_MIN = 20
E.HISTORY_CAP_MAX = 100
local MAX_RECENT_RUNS     = E.HISTORY_CAP_MIN
-- A persisted activeRun is only resumed on /reload if it began within this
-- many seconds of wall-clock time. GetTime() is SYSTEM uptime (it does NOT
-- reset when the WoW client restarts — only on a reboot), so the old
-- "startTime <= GetTime()" check alone let a run saved in a previous
-- session look valid and get resumed, logging a fresh run as 26h+. time()
-- is real epoch seconds, so this catches a stale cross-session activeRun.
local MAX_RESUME_AGE      = 6 * 3600  -- 6 hours

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
    story          = nil,   -- story variant, read from the delve's POI tooltip
    boss           = nil,   -- end-boss name, captured live via ENCOUNTER_END
    trovehunterPopupShown = false, -- one-shot guard for the reminder popup
    popupWindowStart = 0,   -- GetTime() at THIS world-entry; the popup's
                            -- 60s late-firing window is keyed off this, NOT
                            -- startTime, so a /reload deep into a run still
                            -- gets a fresh window and the popup can fire.
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

--- Verbose tier-tracker logging, toggled by "/ed debug". A no-op (one
--- table lookup) when off, so it costs nothing for normal players. Used
--- only to diagnose how a run's tier is detected, captured, and logged.
local function DebugTier(fmt, ...)
    if not (E.db and E.db.debugTier) then return end
    -- Never let a malformed debug line throw inside an event handler and
    -- interrupt tracking/logging — format defensively, print only on success.
    local ok, msg = pcall(string.format, fmt, ...)
    if ok then
        print("|cFFFFD700[ED tier]|r " .. msg)
    end
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
        if n and n >= 1 and n <= 11 then
            DebugTier("m1 difficultyName=%q -> %d", difficultyName, n)
            return n
        end
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
    if m2 then
        DebugTier("m2 scenario/step -> %d", m2)
        return m2
    end

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
        local foundVia                       -- "explicit" | "standalone"
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
                                foundVia  = "explicit"
                                return
                            end
                        end
                        if clean == "Delves" or clean == zoneName then
                            foundDelveHeader = true
                        elseif foundDelveHeader and clean:match("^%d+$") then
                            local n = tonumber(clean)
                            if n and n >= 1 and n <= 11 then
                                foundTier = n
                                foundVia  = "standalone"
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
        if foundTier then
            DebugTier("m3 scrape -> %d (via %s)", foundTier, tostring(foundVia))
            return foundTier
        end
    end

    DebugTier("no tier detected")
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
    if runState.tier and runState.tier > 0 then
        DebugTier("capture[%s]: skip, already latched=%d",
            tostring(source), runState.tier)
        return
    end
    local t = AutoDetectDelveTier()
    DebugTier("capture[%s]: read=%s (latched startTime=%.0f, now=%.0f)",
        tostring(source), tostring(t), runState.startTime or 0, GetTime())
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

    -- Match the live bountiful set by name OR by the delve's POI id. The
    -- name lookup alone is fragile: E.currentBountifulNames is keyed off the
    -- live POI label, which can differ from runState.delveName (the canonical
    -- MatchDelveName result) -- e.g. POI "Twilight Crypts" vs canonical
    -- "Twilight Crypt" -- so a bountiful delve could silently fail the check
    -- and the reminder would never fire there. The POI-id leg is identity-
    -- stable and immune to any name-spelling drift; it mirrors the robust
    -- lookup the Delve Locations tab already uses.
    local cbn  = E.currentBountifulNames
    local cbp  = E.currentBountifulPOIs
    local meta = E.DelveDataByName and E.DelveDataByName[runState.delveName]
    local isBountiful =
        (cbn and (cbn[runState.delveName]
                  or cbn[strtrim(runState.delveName):lower()]))
        or (meta and meta.poiID and cbp and cbp[meta.poiID])

    if isBountiful then
        runState.wasBountiful = true
        if E.db and E.db.activeRun then
            E.db.activeRun.wasBountiful = true
        end
    end
end

--- Read the "Story Variant: X" text from a delve POI's tooltip widget.
--- The story sits at orderIndex 0 of the POI's tooltip TextWithState
--- widget set — the same data the Bountiful tab reads. It is present for
--- NORMAL (non-bountiful) delve POIs too, and is readable from inside the
--- instance.
local function ReadPOIStoryText(mapID, poiID)
    if not (mapID and poiID and C_AreaPoiInfo and C_AreaPoiInfo.GetAreaPOIInfo) then
        return nil
    end
    local poi = C_AreaPoiInfo.GetAreaPOIInfo(mapID, poiID)
    if not (poi and poi.tooltipWidgetSet and C_UIWidgetManager
            and C_UIWidgetManager.GetAllWidgetsBySetID) then
        return nil
    end
    local widgets = C_UIWidgetManager.GetAllWidgetsBySetID(poi.tooltipWidgetSet)
    if not widgets then return nil end
    for _, info in ipairs(widgets) do
        if info.widgetType == Enum.UIWidgetVisualizationType.TextWithState
                and C_UIWidgetManager.GetTextWithStateWidgetVisualizationInfo then
            local viz = C_UIWidgetManager
                .GetTextWithStateWidgetVisualizationInfo(info.widgetID)
            if viz and viz.orderIndex == 0 and viz.text and viz.text ~= "" then
                return viz.text
            end
        end
    end
    return nil
end

--- Strip color codes and the "Story Variant:" prefix to a clean name.
local function CleanStoryName(s)
    if not s or s == "" then return nil end
    local plain = s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    local name = plain:match("[Vv]ariant:%s*(.-)%s*$") or plain:match("^%s*(.-)%s*$")
    if not name or name == "" then return nil end
    return name
end

--- Resolve the current story variant for a delve by name (e.g. "Academy
--- Under Siege"). Reads the delve's POI tooltip, trying the bountiful POI
--- first and the normal POI second (only one is active at a time), so it
--- works for bountiful and non-bountiful delves alike. Returns nil for
--- delves with no POI story (e.g. the Nemesis delve) or if data isn't ready.
function E:GetDelveStoryVariant(delveName)
    if not (delveName and self.DelveData) then return nil end
    local entry
    for _, d in ipairs(self.DelveData) do
        if d.name == delveName then entry = d; break end
    end
    if not entry then return nil end
    local raw = ReadPOIStoryText(entry.mapID, entry.poiID)
             or ReadPOIStoryText(entry.mapID, entry.normalPoiID)
    return CleanStoryName(raw)
end

--- Reset the active-run state for a newly-entered delve.
local function BeginDelveRun(name, kind)
    runState.inDelve       = true
    runState.delveName     = name
    runState.delveKind     = kind
    runState.startTime     = GetTime()
    runState.popupWindowStart = GetTime()  -- fresh popup window on entry
    runState.deaths        = 0
    runState.startKeyCount = GetCurrencyQty(COFFER_KEY_CURRENCY)
    runState.tier          = 0
    runState.wasBountiful  = false
    -- Story variant for this run, read from the delve's POI tooltip. Works
    -- for bountiful and non-bountiful delves; the variant is stable for the
    -- day (it rotates on the daily reset), so the value read at entry matches
    -- completion. Re-read at completion too as a fallback in case the POI
    -- cache was cold here.
    runState.story         = E:GetDelveStoryVariant(name)
    runState.boss          = nil
    runState.trovehunterPopupShown = false
    -- Persist run start to SavedVariables so duration survives /reload
    -- and brief disconnects. GetTime() is continuous across /reload.
    if E.db then
        E.db.activeRun = {
            name          = name,
            kind          = kind,
            startTime     = runState.startTime,
            startedAt     = time(),  -- wall-clock; used for staleness check
            deaths        = 0,
            startKeyCount = runState.startKeyCount,
            tier          = 0,
            wasBountiful  = false,
            story         = runState.story,
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
    runState.story         = nil
    runState.boss          = nil
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
--- Updates lifetime counters in-place and caps recentRuns at the
--- user-configured retention (E.db.historyCap, default 20).
--- `story` (optional) is the detected story variant for THIS run (e.g.
--- "Invasive Glow"); stored only when non-empty so the History tab can
--- show the actual variant instead of the delve's signature story.
function E:LogDelveRun(name, tier, duration, deaths, keyUsed, wasBountiful, story, boss)
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
        story        = (story and story ~= "") and story or nil,
        boss         = (boss and boss ~= "") and boss or nil,
    })
    -- Cap retention at the user-configured limit. Clamp to [MIN, MAX] so a
    -- bad saved value can't shrink history below the floor or grow it without
    -- bound. Only inserts trigger trimming, so raising the cap keeps more from
    -- here on; lowering it trims a delve's tail the next time that delve runs.
    local cap = MAX_RECENT_RUNS
    local hc  = E.db and E.db.historyCap
    if type(hc) == "number" then
        cap = math.max(E.HISTORY_CAP_MIN, math.min(hc, E.HISTORY_CAP_MAX))
    end
    while #recent > cap do
        recent[#recent] = nil
    end
end

--- Attach (or clear) a free-form note on a single logged run, located by
--- its delve name + timestamp. Passing an empty/whitespace string removes
--- the note. Returns true if a matching run was found and updated.
function E:SetRunNote(delveName, timestamp, text)
    if not (delveName and timestamp and self.db and self.db.delveHistory) then
        return false
    end
    local entry = self.db.delveHistory[delveName]
    local recent = entry and entry.recentRuns
    if not recent then return false end
    local clean = text and strtrim(text) or ""
    for _, run in ipairs(recent) do
        if run.timestamp == timestamp then
            run.note = (clean ~= "") and clean or nil
            return true
        end
    end
    return false
end

--- Record which boss a delve fields for a given story variant. Stored
--- account-wide (the variant→boss pairing is region-wide), so the
--- "today's boss" highlight on the Delve Locations / Bountiful tabs can
--- light up the correct boss for multi-boss delves once learned.
function E:RecordDelveBoss(delveName, variant, bossName)
    if not (delveName and variant and variant ~= ""
            and bossName and bossName ~= "" and self.db) then
        return
    end
    local map = self.db.delveBossMap
    if not map then
        map = {}
        self.db.delveBossMap = map
    end
    local byVariant = map[delveName]
    if not byVariant then
        byVariant = {}
        map[delveName] = byVariant
    end
    byVariant[variant] = bossName
end

--- Return the learned boss name for a delve + story variant, or nil.
function E:GetRecordedBoss(delveName, variant)
    if not (delveName and variant and variant ~= "") then return nil end
    local map = self.db and self.db.delveBossMap
    local byVariant = map and map[delveName]
    return byVariant and byVariant[variant] or nil
end

--- Resolve today's boss for a delve. Single-boss delves always return
--- their lone boss; multi-boss delves resolve via today's live story
--- variant against the learned map (nil until that variant is recorded).
function E:GetTodaysBossName(delveName)
    if not delveName then return nil end
    local bosses = self.GetDelveBosses and self:GetDelveBosses(delveName)
    if not bosses then return nil end
    if #bosses == 1 then
        return bosses[1].name
    end
    local variant = self.GetDelveStoryVariant and self:GetDelveStoryVariant(delveName)
    if not variant or variant == "" then return nil end
    -- Live-learned mapping wins (so a real run auto-corrects the table if
    -- it ever disagrees); otherwise fall back to the verified static
    -- variant->boss table for day-one coverage.
    local live = self:GetRecordedBoss(delveName, variant)
    if live then return live end
    return self.GetStaticBoss and self:GetStaticBoss(delveName, variant) or nil
end

--- One-time-safe cleanup for the old GetTime() staleness bug, which could
--- log a run with an absurd (multi-hour) duration. Any logged run longer
--- than MAX_RESUME_AGE is capped to 0 (unknown) and its excess removed from
--- the delve's lifetime total so the average is no longer skewed. Idempotent
--- — once run, nothing exceeds the cap, so a second pass is a no-op.
function E:RepairAbsurdDurations()
    if not (self.db and self.db.delveHistory) then return 0 end
    local fixed = 0
    for _, entry in pairs(self.db.delveHistory) do
        local recent = entry.recentRuns
        local life   = entry.lifetime
        if recent then
            for _, run in ipairs(recent) do
                if (run.duration or 0) > MAX_RESUME_AGE then
                    if life and life.totalDuration then
                        life.totalDuration =
                            math.max(0, life.totalDuration - run.duration)
                    end
                    -- Deliberately do NOT decrement life.totalRuns here. The
                    -- run stays in recentRuns (we only zero its duration), and
                    -- a delve renders in the History tab / Locations badge only
                    -- while totalRuns > 0 — decrementing could silently hide a
                    -- delve whose only run was corrupted, even though its row
                    -- still exists. Keeping the count also matches the live
                    -- path (LogDelveRun counts a 0-duration run), so a scrubbed
                    -- run is treated as a 0s run in the average — the same
                    -- convention used everywhere else for unknown timers.
                    run.duration = 0
                    fixed = fixed + 1
                end
            end
        end
    end
    if fixed > 0 then
        print(self.CC.header .. "Everything Delves|r: Cleaned up "
            .. fixed .. " run" .. (fixed == 1 and "" or "s")
            .. " with an invalid timer.")
        if self.RefreshDelveHistoryTab then
            self:RefreshDelveHistoryTab()
        end
    end
    return fixed
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
--- Cross-checks TODAY's recorded runs against the LIVE bountiful list.
--- Any run whose delve is currently bountiful but was logged with
--- wasBountiful=false (because the POI cache was cold at delve entry)
--- gets its flag corrected. Only repairs TODAY's runs — the bountiful
--- set rotates DAILY, so a run logged before today's reset cannot be
--- validated against today's live list (the delve may be bountiful only
--- today, or have rotated out since the run). Repairing across a wider
--- window would corrupt history and inflate the Gilded Stash counter.
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

    -- Bountiful rotates on the DAILY reset, so only today's runs can be
    -- validated against today's live list. run.timestamp is written with
    -- time(), so compute the boundary in the same base (mirrors the daily
    -- logic in TabCurrentBountiful).
    local lastReset = 0
    if C_DateAndTime and C_DateAndTime.GetSecondsUntilDailyReset then
        local secs = C_DateAndTime.GetSecondsUntilDailyReset()
        if secs and secs > 0 then
            lastReset = time() + secs - 86400
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
            .. (repaired == 1 and "" or "s") .. " from today.")
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
delveFrame:RegisterEvent("ENCOUNTER_END")

-- True only when the most recent PLAYER_ENTERING_WORLD was a UI reload
-- (set in the event handler below). Gates the activeRun restore so a
-- stale saved run is never resumed onto a fresh delve entry — only a
-- genuine /reload mid-delve resumes the timer.
local enteredViaReload = false

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
        -- A genuine new world-entry (a PLAYER_ENTERING_WORLD that is NOT a
        -- UI reload) always means a brand-new delve instance, so it must
        -- begin a fresh run even when the delve name matches the one we
        -- were just tracking. Without this, running the SAME delve twice
        -- back-to-back left runState.inDelve true with run 1's startTime
        -- whenever EndDelveRun never fired between them — e.g. run 1's
        -- SCENARIO_COMPLETED was missed, or the player hopped delve->delve
        -- without crossing a non-delve zone. Run 2 then fell into the
        -- timing-preserving "else" branch and its duration was measured
        -- from run 1's start (an 18:57 run + a faster second run logged as
        -- 38:17). A /reload keeps enteredViaReload true and is handled by
        -- the resume branch below, so its timer is preserved; mid-run
        -- SCENARIO_UPDATE/ZONE_CHANGED retries are not PLAYER_ENTERING_WORLD
        -- and so never force a reset.
        local freshEntry = (source == "PLAYER_ENTERING_WORLD")
                and not enteredViaReload
        if not runState.inDelve or runState.delveName ~= matchedName
                or freshEntry then
            -- Resume a persisted run ONLY when this world-entry was a
            -- genuine /reload (enteredViaReload). On a fresh delve entry we
            -- must start a new run even if a stale activeRun for the same
            -- delve is still saved — otherwise its old start time and tier
            -- get restored onto the new run (the bug that logged a fresh
            -- T8 as a 1h+ T11). Extra guard: a full client restart resets
            -- GetTime() to near-zero, so a saved startTime in the "future"
            -- is treated as stale too.
            -- Resume only a genuinely current run: it must be a /reload,
            -- the same delve, its GetTime() start must not be in the future
            -- (catches a computer reboot, which DOES reset GetTime()), and
            -- its wall-clock start must be recent (catches a stale run saved
            -- in a previous client session — GetTime() alone can't, since it
            -- does not reset on a client restart, only on a reboot).
            local saved = E.db and E.db.activeRun
            if enteredViaReload and saved and saved.name == matchedName
                    and saved.startTime
                    and saved.startTime <= GetTime()
                    and saved.startedAt
                    and (time() - saved.startedAt) < MAX_RESUME_AGE then
                runState.inDelve       = true
                runState.delveName     = matchedName
                runState.delveKind     = saved.kind
                runState.startTime     = saved.startTime
                -- Fresh popup window from THIS world-entry (not the original
                -- run start): GetTime() is continuous across /reload, so
                -- reusing saved.startTime would trip the 60s late-firing guard
                -- immediately and permanently suppress the reminder after a
                -- mid-run reload.
                runState.popupWindowStart = GetTime()
                runState.deaths        = saved.deaths or 0
                runState.startKeyCount = saved.startKeyCount or 0
                runState.tier          = saved.tier or 0
                runState.wasBountiful  = saved.wasBountiful or false
                runState.story         = saved.story
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
    -- Record whether this world-entry is a UI reload before any delve
    -- detection runs. Re-set on every PLAYER_ENTERING_WORLD, so a fresh
    -- delve entry (which always fires PEW with isReloadingUi=false) clears
    -- a reload flag left over from an earlier /reload.
    if event == "PLAYER_ENTERING_WORLD" then
        local _, isReloadingUi = ...
        enteredViaReload = isReloadingUi and true or false
    end

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

    elseif event == "ENCOUNTER_END" then
        -- Capture the boss name live. Delves field a single end-boss
        -- encounter; if more than one fires, the last (the end boss)
        -- wins, which is exactly what we want recorded at completion.
        if runState.inDelve then
            local _, encounterName = ...
            if encounterName and encounterName ~= "" then
                runState.boss = encounterName
            end
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
        -- Final safety net: no real delve runs longer than MAX_RESUME_AGE,
        -- so an absurd duration means the start time was stale despite the
        -- resume guard. Log it as unknown (0) rather than e.g. "26h 8m".
        if duration > MAX_RESUME_AGE then
            duration = 0
        end

        -- Tier reconciliation before logging. The value captured at ENTRY
        -- is unreliable: at the moment we zone in, the objective tracker is
        -- still showing the delve we just left, so the tier detector reads
        -- the PREVIOUS run's tier and latches it (debug confirmed every run
        -- logging the tier of the run before it). A run's tier never changes
        -- mid-run, and by the time we complete, the tracker is reliably
        -- showing THIS run's tier — so we re-read now and PREFER that value.
        -- We fall back to the entry-latched value only if the re-read comes
        -- up empty (e.g. the tracker was already torn down), which is no
        -- worse than the old behaviour.
        local latched   = runState.tier or 0
        local confirmed = AutoDetectDelveTier()      -- current run's tier
        local tier      = (confirmed and confirmed > 0) and confirmed or latched
        runState.tier   = tier
        DebugTier("completion: latched=%d reread=%s -> logging T%d",
            latched, tostring(confirmed), tier)
        RefreshBountifulSnapshot()

        local keyNow  = GetCurrencyQty(COFFER_KEY_CURRENCY)
        local keyUsed = (runState.startKeyCount > 0)
            and (keyNow < runState.startKeyCount)
            or false

        if matchedName then
            -- Story variant for this run. Captured at entry into
            -- runState.story (and persisted across /reload); re-read here
            -- from the delve's POI tooltip as a fallback if entry capture
            -- missed (e.g. cold POI cache). Works for bountiful AND
            -- non-bountiful delves now, not just bountiful ones.
            local story = runState.story
            if not story or story == "" then
                story = E:GetDelveStoryVariant(matchedName)
            end
            E:LogDelveRun(
                matchedName, tier, duration, runState.deaths,
                keyUsed, runState.wasBountiful, story, runState.boss
            )
            -- Learn the variant→boss pairing for the "today's boss"
            -- highlight (account-wide, only when both are known).
            if runState.boss and story and story ~= "" then
                E:RecordDelveBoss(matchedName, story, runState.boss)
            end
            if E.RefreshDelveHistoryTab then
                E:RefreshDelveHistoryTab()
            end
        end

        EndDelveRun()
    end
end)
