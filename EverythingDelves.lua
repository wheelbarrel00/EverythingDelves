-- EverythingDelves.lua — addon bootstrap: namespace, SavedVariables, events, slash commands.
EverythingDelves = {}
local E = EverythingDelves

E.name = "EverythingDelves"

E.version = C_AddOns.GetAddOnMetadata("EverythingDelves", "Version") or "1.0.0"

-- WoW can't open a browser, so external links are shown in a copyable popup.
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

StaticPopupDialogs["EVERYTHINGDELVES_URL"] = {
    text = "Copy the link below (it's pre-selected - just press Ctrl+C):",
    button1 = "Close",
    hasEditBox = true,
    editBoxWidth = 260,
    OnShow = function(self)
        local url = E._pendingURL or ""
        local eb = self.editBox or self.EditBox
        if eb then
            eb:SetText(url)
            eb:HighlightText()
            eb:SetFocus()
            eb:SetScript("OnEscapePressed", function(box) box:GetParent():Hide() end)
            eb:SetScript("OnTextChanged", function(box)
                if box:GetText() ~= url then
                    box:SetText(url)
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

function E:ShowURL(url)
    if not url or url == "" then return end
    E._pendingURL = url
    StaticPopup_Show("EVERYTHINGDELVES_URL")
end

-- Tab files queue init callbacks here; all run inside InitMainFrame().
E.modules = {}

function E:RegisterModule(callback)
    table.insert(self.modules, callback)
end

-- Account-wide settings only. Per-character gameplay data (delveHistory,
-- activeRun) lives in profiles instead, reached through the E.db proxy. The
-- *ByChar / roster / boss-map tables stay account-wide because their data is
-- region-wide (and an alt's quest log can't be read remotely).
local DEFAULTS = {
    minimapButton = {
        show  = true,
        angle = 220,
    },
    framePosition    = nil,
    defaultTab       = 1,
    historyCap       = 20,
    uiScale          = 1.0,
    accentColor      = "gold",    -- "red" | "gold" | "purple" | "green" | "darkblue"
    lowShardWarning        = true,
    lowShardThreshold      = 100,
    alertNewBountiful      = false,
    alertSpecialAssignment = false,
    showTrovehunterReminder = true,
    muteValeera            = false,
    muteValeeraBubbles     = false,
    muteDundun             = false,
    achievementTooltip     = "summary",  -- "summary" | "full" | "off"
    showDelveObjectives    = false,
    showRunTimer           = true,
    showDelveHUD           = true,
    showRunResult          = true,
    showPickerInfo         = true,
    showShardWeekly        = false,
    delveObjectivesPos     = nil,
    seenWhatsNewVersion    = "",
    lastKnownBountifulIDs  = {},
    lastKnownActiveSAs     = {},
    delversCallRoster      = {},
    delveBossMap           = {},
    gildedStashByChar      = {},
    roster                 = {},
}

-- Profile-scoped keys: the E.db proxy redirects these to the active profile.
local PROFILE_KEYS = {
    delveHistory   = true,
    activeRun      = true,
}

local function CharKey()
    local name  = UnitName("player")  or "Unknown"
    local realm = GetRealmName()      or "Unknown"
    return name .. " - " .. realm
end
E.CharKey = CharKey

local function NormalizeProfile(p)
    p.delveHistory   = p.delveHistory   or {}
    return p
end

-- Reads E.profile dynamically so a runtime profile switch is reflected
-- immediately with no re-proxy.
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

    -- Merge defaults without overwriting existing values (settings survive updates).
    for k, v in pairs(DEFAULTS) do
        if sv[k] == nil then
            if type(v) == "table" then
                sv[k] = CopyTable(v)
            else
                sv[k] = v
            end
        end
    end

    sv.profiles    = sv.profiles    or {}
    sv.profileKeys = sv.profileKeys or {}

    -- Roster inserted at tab 8 shifted Options/Profiles/About down one.
    if not sv._rosterTabMigrated then
        if type(sv.defaultTab) == "number" and sv.defaultTab >= 8 then
            sv.defaultTab = sv.defaultTab + 1
        end
        sv._rosterTabMigrated = true
    end

    local charKey = CharKey()

    -- One-time migration (pre-1.5.0 → profiles): old account-wide gameplay
    -- tables are moved into an "Original" profile claimed by the first
    -- character to log in, so a main keeps its history; alts get a fresh one.
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

-- Resets account-wide settings only; profiles (delve history, mid-run
-- state) are deliberately preserved.
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
    E:InitDB()
end

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

function E:CreateProfile(name)
    local sv = EverythingDelvesDB
    if not sv or not name or name == "" then return false, "Invalid name." end
    if sv.profiles[name] then return false, "A profile with that name already exists." end
    sv.profiles[name] = NormalizeProfile({})
    return E:SwitchProfile(name)
end

function E:CopyProfile(sourceName, newName)
    local sv = EverythingDelvesDB
    if not sv or not sv.profiles[sourceName] then return false, "Source profile missing." end
    if not newName or newName == "" then return false, "Invalid name." end
    if sv.profiles[newName] then return false, "A profile with that name already exists." end
    sv.profiles[newName] = NormalizeProfile(CopyTable(sv.profiles[sourceName]))
    return E:SwitchProfile(newName)
end

-- The active profile can't be deleted; characters that pointed at a deleted
-- profile fall back to a fresh per-character one on next login.
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

function E:ToggleMainFrame()
    if E.MainFrame then
        if E.MainFrame:IsShown() then
            E.MainFrame:Hide()
        else
            E.MainFrame:Show()
        end
    end
end

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
    elseif msg == "crest" then
        if not (C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo) then
            print("|cFFFF2222Everything Delves|r: currency API unavailable.")
            return
        end
        print("|cFFFF2222Everything Delves|r: Dawncrest currency fields")
        for _, crest in ipairs(E.Dawncrests or {}) do
            local ok, info = pcall(C_CurrencyInfo.GetCurrencyInfo, crest.id)
            if ok and info then
                print(("  %d %s: qty=%s totalEarned=%s maxQty=%s"
                        .. " maxWeekly=%s earnedThisWeek=%s useTotalForMax=%s"
                        .. " capped=%s"):format(
                    crest.id,
                    tostring(info.name),
                    tostring(info.quantity),
                    tostring(info.totalEarned),
                    tostring(info.maxQuantity),
                    tostring(info.maxWeeklyQuantity),
                    tostring(info.quantityEarnedThisWeek),
                    tostring(info.useTotalEarnedForMaxQty),
                    tostring(info.isCapped)))
            else
                print(("  %d %s: no data"):format(crest.id, crest.label))
            end
        end
    elseif msg == "achtip" then
        if E.db then
            E.db.debugAchTip = not E.db.debugAchTip
            print("|cFFFF2222Everything Delves|r: achievement-tooltip debug "
                .. (E.db.debugAchTip and "|cFF22FF22ON|r" or "|cFFFF2222OFF|r")
                .. ". Hover delve map pins and send me every"
                .. " |cFFFFD700[ED achtip]|r line.")
        end
    elseif msg == "ach" then
        if E.DebugPrintAchievements then
            E:DebugPrintAchievements()
        end
    elseif msg == "debug" then
        if E.db then
            E.db.debugTier = not E.db.debugTier
            print("|cFFFF2222Everything Delves|r: tier debug "
                .. (E.db.debugTier and "|cFF22FF22ON|r" or "|cFFFF2222OFF|r")
                .. ". Run two delves back-to-back, then send me every line"
                .. " that starts with |cFFFFD700[ED tier]|r.")
        end
    elseif msg == "obj" or msg == "objectives" or msg == "spoils" then
        if E.db then
            E.db.showDelveObjectives = not E.db.showDelveObjectives
            if E.UpdateDelveObjectivesWindow then
                E:UpdateDelveObjectivesWindow()
            end
            print("|cFFFF2222Everything Delves|r: Bonus Spoils tracker "
                .. (E.db.showDelveObjectives and "|cFF22FF22ON|r" or "|cFFFF2222OFF|r")
                .. (E.db.showDelveObjectives
                    and " - it appears while you're inside a delve." or ""))
        end
    elseif msg == "objdump" then
        if E.DumpDelveObjectiveData then
            E:DumpDelveObjectiveData()
        else
            print("|cFFFF2222Everything Delves|r: objectives module"
                .. " not loaded.")
        end
    elseif msg == "gilded" then
        if not (C_UIWidgetManager
                and C_UIWidgetManager.GetSpellDisplayVisualizationInfo) then
            print("|cFFFF2222Everything Delves|r: widget API unavailable"
                .. " on this client.")
            return
        end
        local GILDED_WIDGET = 7591
        local function ReadWidget(id)
            local ok, info = pcall(
                C_UIWidgetManager.GetSpellDisplayVisualizationInfo, id)
            if not ok or not info then return nil end
            return info, info.spellInfo and info.spellInfo.tooltip
        end
        local info, tip = ReadWidget(GILDED_WIDGET)
        if info then
            ---@diagnostic disable-next-line: undefined-field
            print(string.format(
                "|cFFFF2222Everything Delves|r: widget %d shownState=%s",
                GILDED_WIDGET, tostring(info.shownState)))
            print("  tooltip: " .. tostring(tip))
        else
            print(string.format(
                "|cFFFF2222Everything Delves|r: widget %d returned nil.",
                GILDED_WIDGET))
        end
        -- Sweep nearby widgets for a fraction tooltip in case the ID moved in a patch.
        local hits = 0
        for id = 7400, 7800 do
            if id ~= GILDED_WIDGET then
                local _, t2 = ReadWidget(id)
                if t2 and t2:match("%d+%s*/%s*%d+") then
                    hits = hits + 1
                    print(string.format("  candidate widget %d: %s",
                        id, t2:sub(1, 120)))
                end
            end
        end
        print(string.format(
            "|cFFFF2222Everything Delves|r: sweep done - %d candidate(s)"
            .. " in 7400-7800. Screenshot/paste me the output.", hits))
        if E.GetLiveGildedStash then
            local col, tot = E:GetLiveGildedStash()
            print("  saved this week: " .. (col
                and (col .. " / " .. tostring(tot))
                or "none"))
        end
    elseif msg == "about" then
        E:ToggleMainFrame()
        if E.MainFrame and E.MainFrame:IsShown() then
            E:SelectTab(E.NUM_TABS)
        end
    else
        E:ToggleMainFrame()
    end
end

-- PLAYER_LOGIN fires once after addons load and the player object exists —
-- the first safe point to touch SavedVariables and build the UI.
E:RegisterEvent("PLAYER_LOGIN", function(self)
    self:InitDB()

    self:RepairAbsurdDurations()

    if self.InitMainFrame then
        self:InitMainFrame()
    end

    if self.ApplyAccentColor then
        self:ApplyAccentColor(self.db.accentColor)
    end

    -- Pre-warm the AreaPOI cache so teleporting straight into a delve from an
    -- unrelated zone doesn't get GetAreaPOIInfo nil → wasBountiful stamped false.
    if C_AreaPoiInfo and C_AreaPoiInfo.GetAreaPOIForMap and self.DelveData then
        local seenMaps = {}
        for _, delve in ipairs(self.DelveData) do
            if delve.mapID and not seenMaps[delve.mapID] then
                seenMaps[delve.mapID] = true
                pcall(C_AreaPoiInfo.GetAreaPOIForMap, delve.mapID)
            end
        end
    end

    self._autoRepairPending = true

    -- Force a refresh shortly after login so auto-repair fires without
    -- waiting for the user to open the Bountiful tab.
    C_Timer.After(3, function()
        if self.RefreshBountifulData then
            self:RefreshBountifulData(true)
        end
    end)

    print("|cFFFF2222Everything Delves|r v" .. self.version
        .. " loaded. Type |cFFFFD700/ed|r to open.")
end)

-- Fires on login, reload, and every zone change; seeds session counters.
E:RegisterEvent("PLAYER_ENTERING_WORLD", function(self, _, isLogin, isReload)
    if isLogin or isReload then
        self.sessionData = {
            bountifulCompleted = 0,
            loginTime          = time(),
        }
    end
end)

-- Callback list so multiple modules can register for the same logical event.
E.eventCallbacks = {}

function E:RegisterCallback(eventName, fn)
    if not self.eventCallbacks[eventName] then
        self.eventCallbacks[eventName] = {}
    end
    table.insert(self.eventCallbacks[eventName], fn)
end

local function FireCallbacks(eventName)
    local cbs = E.eventCallbacks[eventName]
    if cbs then
        for _, fn in ipairs(cbs) do
            fn(E)
        end
    end
end

-- QUEST_LOG_UPDATE / CURRENCY_DISPLAY_UPDATE can fire dozens of times per
-- second; coalesce on a trailing-edge timer to avoid a full refresh per fire.
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

-- pcall-wrapped in case the event is renamed in a future patch.
pcall(function()
    E:RegisterEvent("WORLD_QUEST_COMPLETED", fireWorldQuestDone)
end)

-- DELVE HISTORY TRACKER. Uses its own frame so it doesn't conflict with the
-- single-handler-per-event dispatcher above.

-- Restored Coffer Key currency. Must match E.CurrencyIDs.bountifulKeys (3028)
-- in Core/Constants.lua; repeated as a literal because this file loads first.
local COFFER_KEY_CURRENCY = 3028
-- On some builds the key is a bag ITEM, not a currency, so key-usage detection
-- watches both 3028 and this item (matches E.ItemIcons.cofferKey).
local COFFER_KEY_ITEM     = 224172
E.HISTORY_CAP_MIN = 20
E.HISTORY_CAP_MAX = 100
local MAX_RECENT_RUNS     = E.HISTORY_CAP_MIN
-- GetTime() is SYSTEM uptime (resets only on reboot, not client restart), so a
-- "startTime <= GetTime()" check alone resumed a run saved in a prior session
-- and logged it as 26h+. Gate resume on this wall-clock (time()) age instead.
local MAX_RESUME_AGE      = 6 * 3600

E.delveRunState = {
    inDelve        = false,
    delveName      = nil,
    delveKind      = nil,   -- "regular" | "nemesis"
    startTime      = 0,
    deaths         = 0,
    startKeyCount  = 0,
    startKeyItems  = 0,
    keyUsed        = false,
    tier           = 0,
    wasBountiful   = false,
    story          = nil,
    boss           = nil,
    trovehunterPopupShown = false,
    -- GetTime() at THIS world-entry. The popup's 60s late-firing window keys
    -- off this (not startTime) so a /reload deep into a run still gets a fresh
    -- window and the popup can fire.
    popupWindowStart = 0,
}

local runState = E.delveRunState

-- The bountiful coffer is looted (key spent) AFTER SCENARIO_COMPLETED, so this
-- watcher keeps flagging the just-logged run when the key drops. See CheckKeySpend.
local keyWatch = nil

local function GetCurrencyQty(id)
    if C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo then
        local info = C_CurrencyInfo.GetCurrencyInfo(id)
        if info then return info.quantity or 0 end
    end
    return 0
end

local function GetKeyItemCount()
    if C_Item and C_Item.GetItemCount then
        local ok, n = pcall(C_Item.GetItemCount, COFFER_KEY_ITEM)
        if ok and type(n) == "number" then return n end
    end
    return 0
end

-- Verbose tier-tracker logging, toggled by "/ed debug"; no-op when off.
local function DebugTier(fmt, ...)
    if not (E.db and E.db.debugTier) then return end
    -- pcall so a malformed debug line can't throw inside an event handler.
    local ok, msg = pcall(string.format, fmt, ...)
    if ok then
        print("|cFFFFD700[ED tier]|r " .. msg)
    end
end

-- Auto-detect the current delve tier (1-11), or nil. Tries difficulty name,
-- then scenario/step name, then scraping the ObjectiveTracker UI.
local function AutoDetectDelveTier()
    local _, _, _, difficultyName = GetInstanceInfo()
    if difficultyName and difficultyName ~= "" then
        local m = difficultyName:match("(%d+)")
        local n = m and tonumber(m)
        if n and n >= 1 and n <= 11 then
            DebugTier("m1 difficultyName=%q -> %d", difficultyName, n)
            return n
        end
    end

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

    -- Scrape the ObjectiveTracker for tier text. Limitation: if a lives
    -- counter is the first standalone digit, a T11 can mis-record as a lower
    -- tier — but recording something beats logging tier=0 everywhere.
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

-- Returns (canonicalName, kind) on match, or nil. Tries exact, then
-- case-insensitive, then substring so "The Grudge Pit" ↔ "Grudge Pit" works.
local function MatchDelveName(scenarioName)
    if not scenarioName or scenarioName == "" then return nil end
    local nameMap = E.LoggableDelveNames
    if not nameMap then return nil end

    local kind = nameMap[scenarioName]
    if kind then return scenarioName, kind end

    local lowered = scenarioName:lower()
    for k, v in pairs(nameMap) do
        if k:lower() == lowered then return k, v end
    end

    for k, v in pairs(nameMap) do
        local kl = k:lower()
        if lowered:find(kl, 1, true) or kl:find(lowered, 1, true) then
            return k, v
        end
    end
    return nil
end

-- No-op if already captured. Retried on every SCENARIO_UPDATE because the
-- ObjectiveTracker UI may not populate on the first fire.
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
        -- Persist so a /reload mid-delve doesn't lose the value.
        if E.db and E.db.activeRun then
            E.db.activeRun.tier = t
        end
        if E.MaybeShowTrovehunterReminder then
            E:MaybeShowTrovehunterReminder()
        end
    end
end

-- After entry or a /reload-resume the ObjectiveTracker can briefly still show
-- the PREVIOUS run's tier, so TryCaptureTier's latch may be stale. Re-detect
-- on a short ticker and overwrite with the live value (a run's tier never
-- changes), then lock once it agrees twice or the window ends.
local function SettleTier()
    if E._tierSettle then E._tierSettle:Cancel(); E._tierSettle = nil end
    local ticks, stable = 0, 0
    E._tierSettle = C_Timer.NewTicker(2, function(self)
        ticks = ticks + 1
        if not runState.inDelve then
            self:Cancel(); E._tierSettle = nil
            return
        end
        local detected = AutoDetectDelveTier()
        if detected and detected > 0 then
            if detected ~= (runState.tier or 0) then
                DebugTier("settle: tier %d -> %d", runState.tier or 0, detected)
                runState.tier = detected
                if E.db and E.db.activeRun then
                    E.db.activeRun.tier = detected
                end
                stable = 0
            else
                stable = stable + 1
            end
        end
        if stable >= 2 or ticks >= 8 then
            DebugTier("settle: locked tier=%d (ticks=%d)", runState.tier or 0, ticks)
            self:Cancel(); E._tierSettle = nil
        end
    end)
end

-- Flips runState.wasBountiful to true (never back) if the current delve is on
-- the live bountiful list, letting a cold-cache entry recover on a later retry.
local function RefreshBountifulSnapshot()
    if runState.wasBountiful then return end
    if not runState.inDelve or not runState.delveName then return end
    if not E.RefreshBountifulData then return end

    E:RefreshBountifulData(true)

    -- Match by name OR POI id: the POI label can drift from the canonical name
    -- (e.g. "Twilight Crypts" vs "Twilight Crypt"), so the id leg is the stable one.
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

-- The story sits at orderIndex 0 of the POI tooltip's TextWithState widget
-- set; present for normal (non-bountiful) POIs too and readable from inside.
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

local function CleanStoryName(s)
    if not s or s == "" then return nil end
    local plain = s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    local name = plain:match("[Vv]ariant:%s*(.-)%s*$") or plain:match("^%s*(.-)%s*$")
    if not name or name == "" then return nil end
    return name
end

-- Reads the delve's POI tooltip, trying the bountiful POI then the normal one
-- (only one is active at a time). Returns nil for delves with no POI story.
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

-- The in-delve scenario UI exposes the weekly Gilded Stash counter as
-- spell-display widget 7591 (tooltip ends "Gilded Stash looted: x/4").
-- Confirmed in-game 2026-06-10: data inside a delve, nil outside. Each read
-- is persisted per CharKey and expires at the weekly reset.
local GILDED_WIDGET_ID = 7591

-- Returns collected, total from the widget, or nil outside a delve.
local function ReadGildedWidget()
    if not (C_UIWidgetManager
            and C_UIWidgetManager.GetSpellDisplayVisualizationInfo) then
        return nil
    end
    local ok, info = pcall(
        C_UIWidgetManager.GetSpellDisplayVisualizationInfo, GILDED_WIDGET_ID)
    if not ok or not info or not info.spellInfo then return nil end
    local tip = info.spellInfo.tooltip
    if type(tip) ~= "string" then return nil end
    local col, tot = tip:match("(%d+)%s*/%s*(%d+)")
    if not col then return nil end
    return tonumber(col), tonumber(tot)
end

-- Safe to call any time; silently no-ops outside a delve.
function E:CaptureGildedStash()
    local col, tot = ReadGildedWidget()
    if not col then return end
    local secs = C_DateAndTime and C_DateAndTime.GetSecondsUntilWeeklyReset
        and C_DateAndTime.GetSecondsUntilWeeklyReset()
    if not secs or secs <= 0 then return end
    local store = self.db and self.db.gildedStashByChar
    if not store then return end
    local key = CharKey()
    local entry = store[key]
    if not entry then
        entry = {}
        store[key] = entry
    end
    entry.collected  = col
    entry.total      = tot
    entry.validUntil = time() + secs
end

function E:GetLiveGildedStash()
    local store = self.db and self.db.gildedStashByChar
    local entry = store and store[CharKey()]
    if not entry then return nil end
    if not entry.validUntil or time() >= entry.validUntil then return nil end
    return entry.collected, entry.total
end

local ROSTER_WEEKLY_QUEST = 93909

function E:CaptureRosterSnapshot()
    local sv = EverythingDelvesDB
    if not sv then return end
    sv.roster = sv.roster or {}
    local key = CharKey()
    local rec = sv.roster[key] or {}

    rec.name    = UnitName("player")             or rec.name
    rec.realm   = GetRealmName()                 or rec.realm
    rec.class   = select(2, UnitClass("player")) or rec.class
    rec.faction = UnitFactionGroup("player")     or rec.faction
    rec.level   = UnitLevel("player")            or rec.level

    local _, equipped = GetAverageItemLevel()
    if equipped and equipped > 0 then rec.ilvl = math.floor(equipped + 0.5) end

    local function CurrencyQty(id)
        local info = C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo
            and C_CurrencyInfo.GetCurrencyInfo(id)
        return (info and info.quantity) or 0
    end
    rec.keys   = CurrencyQty(self.CurrencyIDs.bountifulKeys)
    rec.shards = CurrencyQty(self.CurrencyIDs.cofferKeyShards)

    rec.bountyMaps = self:GetTrovehunterMapCount()

    rec.weeklyQuestDone = (C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted
        and C_QuestLog.IsQuestFlaggedCompleted(ROSTER_WEEKLY_QUEST)) or false

    local prog, total, slots = 0, 0, 0
    local ok, acts = pcall(function()
        return C_WeeklyRewards and C_WeeklyRewards.GetActivities
            and C_WeeklyRewards.GetActivities() or nil
    end)
    if ok and acts and Enum and Enum.WeeklyRewardChestThresholdType then
        for _, a in ipairs(acts) do
            if a.type == Enum.WeeklyRewardChestThresholdType.World then
                prog  = math.max(prog,  a.progress  or 0)
                total = math.max(total, a.threshold or 0)
                if (a.threshold or 0) > 0 and (a.progress or 0) >= a.threshold then
                    slots = slots + 1
                end
            end
        end
    end
    rec.vaultProgress = prog
    rec.vaultTotal    = total
    rec.vaultSlots    = slots

    rec.gildedCollected, rec.gildedTotal = self:GetLiveGildedStash()

    local secs = C_DateAndTime and C_DateAndTime.GetSecondsUntilWeeklyReset
        and C_DateAndTime.GetSecondsUntilWeeklyReset()
    if secs and secs > 0 then rec.weekEnd = time() + secs end

    rec.updated = time()
    sv.roster[key] = rec
end

-- widgetID guard keeps this cheap despite UPDATE_UI_WIDGET's high fire rate.
E:RegisterEvent("UPDATE_UI_WIDGET", function(self, _, widgetInfo)
    if widgetInfo and widgetInfo.widgetID == GILDED_WIDGET_ID then
        self:CaptureGildedStash()
    end
end)

local function BeginDelveRun(name, kind)
    runState.inDelve       = true
    runState.delveName     = name
    runState.delveKind     = kind
    runState.startTime     = GetTime()
    runState.popupWindowStart = GetTime()
    runState.deaths        = 0
    runState.startKeyCount = GetCurrencyQty(COFFER_KEY_CURRENCY)
    runState.startKeyItems = GetKeyItemCount()
    runState.keyUsed       = false
    keyWatch               = nil  -- a new run supersedes any pending key watch
    runState.tier          = 0
    runState.wasBountiful  = false
    runState.story         = E:GetDelveStoryVariant(name)
    runState.boss          = nil
    runState.lastResult    = nil
    runState.trovehunterPopupShown = false
    -- Persist run start so duration survives /reload (GetTime() is continuous
    -- across /reload; startedAt is wall-clock for the staleness check).
    if E.db then
        E.db.activeRun = {
            name          = name,
            kind          = kind,
            startTime     = runState.startTime,
            startedAt     = time(),
            deaths        = 0,
            startKeyCount = runState.startKeyCount,
            startKeyItems = runState.startKeyItems,
            keyUsed       = false,
            tier          = 0,
            wasBountiful  = false,
            story         = runState.story,
            trovehunterPopupShown = false,
        }
    end
    RefreshBountifulSnapshot()
    TryCaptureTier("BeginDelveRun")
    SettleTier()

    -- The widget needs a moment to exist after the loading screen, and its
    -- creation UPDATE_UI_WIDGET may predate this run.
    C_Timer.After(2, function() E:CaptureGildedStash() end)

    -- SCENARIO_UPDATE only fires on objective changes (sparse after a /reload
    -- or in a quiet delve), so a 1Hz heartbeat gives the reminder popup
    -- multiple shots while tier/POI/aura state stabilizes.
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
    runState.startKeyItems = 0
    runState.keyUsed       = false
    runState.tier          = 0
    runState.wasBountiful  = false
    runState.story         = nil
    runState.boss          = nil
    runState.trovehunterPopupShown = false
    if E._popupHeartbeat then
        E._popupHeartbeat:Cancel()
        E._popupHeartbeat = nil
    end
    if E.db then
        E.db.activeRun = nil
    end
end

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
    -- Clamp to [MIN, MAX] so a bad saved value can't shrink below the floor.
    local cap = MAX_RECENT_RUNS
    local hc  = E.db and E.db.historyCap
    if type(hc) == "number" then
        cap = math.max(E.HISTORY_CAP_MIN, math.min(hc, E.HISTORY_CAP_MAX))
    end
    while #recent > cap do
        recent[#recent] = nil
    end
end

function E:GetBestRunTime(name, tier)
    local hist = self.db and self.db.delveHistory and self.db.delveHistory[name]
    if not hist or not hist.recentRuns then return nil end
    local best, bestTier
    for _, r in ipairs(hist.recentRuns) do
        local d = r.duration or 0
        if d > 0 and (not tier or (r.tier or 0) == tier)
                and (not best or d < best) then
            best, bestTier = d, r.tier or 0
        end
    end
    return best, bestTier
end

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

-- Removes a logged run and subtracts it from lifetime totals. highestTier /
-- fastestTime are recomputed from the remaining runs only when the deleted run
-- held the record. Drops the delve entry when nothing remains.
function E:DeleteRun(delveName, timestamp)
    if not (delveName and timestamp and self.db and self.db.delveHistory) then
        return false
    end
    local entry  = self.db.delveHistory[delveName]
    local recent = entry and entry.recentRuns
    if not recent then return false end

    local run, idx
    for i, r in ipairs(recent) do
        if r.timestamp == timestamp then
            run, idx = r, i
            break
        end
    end
    if not run then return false end
    table.remove(recent, idx)

    local life = entry.lifetime
    if life then
        -- totalRuns counts runs trimmed past the cap too, so keep it >= the
        -- rows on display; the History tab hides a delve once totalRuns hits 0.
        life.totalRuns     = math.max(#recent, (life.totalRuns or 1) - 1)
        life.totalDeaths   = math.max(0,
            (life.totalDeaths or 0) - (run.deaths or 0))
        life.totalDuration = math.max(0,
            (life.totalDuration or 0) - (run.duration or 0))
        if run.keyUsed then
            life.totalKeysUsed = math.max(0, (life.totalKeysUsed or 0) - 1)
        end
        if (run.tier or 0) >= (life.highestTier or 0) then
            local best = 0
            for _, r in ipairs(recent) do
                if (r.tier or 0) > best then best = r.tier end
            end
            life.highestTier = best
        end
        if run.duration and run.duration > 0
                and run.duration == life.fastestTime then
            local fastest = 0
            for _, r in ipairs(recent) do
                if (r.duration or 0) > 0
                        and (fastest == 0 or r.duration < fastest) then
                    fastest = r.duration
                end
            end
            life.fastestTime = fastest
        end
    end

    if #recent == 0 and (not life or (life.totalRuns or 0) <= 0) then
        self.db.delveHistory[delveName] = nil
    end
    return true
end

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

function E:GetRecordedBoss(delveName, variant)
    if not (delveName and variant and variant ~= "") then return nil end
    local map = self.db and self.db.delveBossMap
    local byVariant = map and map[delveName]
    local learned = byVariant and byVariant[variant] or nil
    -- Correct a value learned under its live encounter name (e.g. "Spinshroom"
    -- -> "Gyrospore") to the boss the player actually fights.
    return learned and self:NormalizeLiveBoss(delveName, learned) or nil
end

function E:GetTodaysBossName(delveName)
    if not delveName then return nil end
    local bosses = self.GetDelveBosses and self:GetDelveBosses(delveName)
    if not bosses then return nil end
    if #bosses == 1 then
        return bosses[1].name
    end
    local variant = self.GetDelveStoryVariant and self:GetDelveStoryVariant(delveName)
    if not variant or variant == "" then return nil end
    -- Live-learned mapping wins (auto-corrects the static table); fall back to
    -- the static variant->boss table for day-one coverage.
    local live = self:GetRecordedBoss(delveName, variant)
    if live then return live end
    return self.GetStaticBoss and self:GetStaticBoss(delveName, variant) or nil
end

-- Cleanup for the old GetTime() staleness bug: any run longer than
-- MAX_RESUME_AGE is capped to 0 (unknown) and its excess removed from the
-- lifetime total. Idempotent.
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
                    -- Do NOT decrement totalRuns: a delve renders only while
                    -- totalRuns > 0, so decrementing could hide a delve whose
                    -- only run was corrupted but still has a row. A scrubbed run
                    -- is treated as a 0s run, matching the live path.
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

function E:ClearDelveHistory()
    if not self.db then return end
    if self.db.delveHistory then
        wipe(self.db.delveHistory)
    end
    if self.RefreshDelveHistoryTab then
        self:RefreshDelveHistoryTab()
    end
end

-- One-time auto-repair of stale wasBountiful flags (cold POI cache at entry).
-- Only TODAY's runs are repaired: bountiful rotates on the DAILY reset, so a
-- run from before today can't be validated against today's live list (doing so
-- would inflate the Gilded Stash counter). Triggered once per session via
-- _autoRepairPending, cleared by the next successful RefreshBountifulData.
function E:AutoRepairBountifulHistory()
    if not self._autoRepairPending then return end
    if not self.db or not self.db.delveHistory then return end
    if not self.currentBountifulNames then return end
    -- Empty lookup means POI data hasn't loaded; wait rather than burn the pass.
    if not next(self.currentBountifulNames) then return end

    -- Daily boundary, computed in the same time() base run.timestamp uses.
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

-- Own frame so the single-handler-per-event contract of the shared dispatcher
-- is preserved.
local delveFrame = CreateFrame("Frame")
delveFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
delveFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
delveFrame:RegisterEvent("SCENARIO_UPDATE")
delveFrame:RegisterEvent("SCENARIO_COMPLETED")
delveFrame:RegisterEvent("PLAYER_DEAD")
delveFrame:RegisterEvent("ENCOUNTER_END")
delveFrame:RegisterEvent("CURRENCY_DISPLAY_UPDATE")

-- Gate the activeRun restore so a stale saved run never resumes onto a new
-- entry. A server disconnect fires PEW with isInitialLogin (not isReloadingUi),
-- so resuming on enteredViaLogin too lets a run survive a mid-delve reconnect
-- instead of restarting the clock. Plain zone-in sets neither flag → fresh run.
local enteredViaReload = false
local enteredViaLogin  = false

-- Latches so a run's clock is stamped only at its own genuine entry, never
-- inherited from a prior run ("each run used the previous run's start time").
--   entryArmed   — a genuine loading-screen entry (PEW that is NOT /reload or
--                  relog) armed the next detection to stamp a FRESH start.
--   runCompleted — a run was just logged for the instance we're still standing
--                  in; suppresses begin/resume through the post-completion loot
--                  window. Cleared when the player leaves or on the next entry.
-- Both reset on /reload + relog, correctly: those paths resume via E.db.activeRun.
local entryArmed   = false
local runCompleted = false

local function TryBeginFromCurrentZone(source)
    local _, _, instanceType = IsInInstance(), nil, select(2, IsInInstance())
    local _, zoneInstName, diffID = GetInstanceInfo()

    -- Delve difficulty (208) or any scenario instance.
    local inScenario = (instanceType == "scenario")
    local isDelve    = (diffID == 208) or inScenario

    if not isDelve then
        if runState.inDelve then
            EndDelveRun()
        end
        runCompleted = false
        keyWatch     = nil
        -- Consume the login/reload flags now that we're in the open world. A delve
        -- entry can be a seamless transition that fires no fresh PEW, so a flag left
        -- latched from the session's first PEW would otherwise bleed onto that entry
        -- and dead-lock it: resume finds no saved run and a fresh begin is gated off
        -- on login/reload, so the run never starts. Clearing here is safe -- a real
        -- logged-out-in-delve resume happens in-delve, where this branch never runs.
        enteredViaReload = false
        enteredViaLogin  = false
        return
    end

    -- Post-completion looting window. A stray SCENARIO_UPDATE/ZONE_CHANGED here
    -- would fire a phantom BeginDelveRun whose startTime leaks into the NEXT
    -- run's duration. The window INCLUDES the post-boss treasure room, which is
    -- still difficulty 208 yet can read as "in progress" — so a scenario-
    -- freshness heuristic CANNOT release the latch (it would start a phantom run
    -- mid-loot and steal the coffer-key spend). Released only when the player
    -- leaves (isDelve false, above) or on the next loading-screen PEW.
    if runCompleted then
        return
    end

    local resolvedName = ResolveDelveName()
    local candidate    = resolvedName or zoneInstName
    local matchedName, kind = MatchDelveName(candidate or "")

    -- The clock is (re)stamped only on a genuine signal: a fresh entry
    -- (entryArmed) or a /reload/reconnect resume. A non-PEW retry only refines.
    local genuineStart = entryArmed or enteredViaReload or enteredViaLogin

    -- Already mid-run and still inside the delve (leaving sets inDelve=false, so
    -- inDelve true here means we never left). A loading screen in this state is a
    -- death/respawn teleport, NOT a new entry: route it to the refine branches so
    -- a re-begin can't reset the timer, deaths, and bonus-spoils pack tally.
    local continuing = runState.inDelve and runState.startTime > 0
    if continuing then entryArmed = false end

    if matchedName then
        -- The "not inDelve" recovery leg covers a transient isDelve flicker
        -- that cleared inDelve after entryArmed was consumed; without it the
        -- run could be dropped. Every path here either begins fresh or resumes.
        if (genuineStart or not runState.inDelve) and not continuing then
            entryArmed = false
            -- Resume only a genuinely current run: a /reload or reconnect, same
            -- delve, startTime not in the future (a reboot DOES reset GetTime()
            -- so a "future" start means stale), and a recent wall-clock start
            -- (GetTime() alone can't catch a run saved in a prior session,
            -- since it survives a client restart). On a plain zone-in we start
            -- fresh even if a stale activeRun for the same delve is saved —
            -- else its old start/tier restore onto the new run.
            local saved = E.db and E.db.activeRun
            if (enteredViaReload or enteredViaLogin)
                    and saved and saved.name == matchedName
                    and saved.startTime
                    and saved.startTime <= GetTime()
                    and saved.startedAt
                    and (time() - saved.startedAt) < MAX_RESUME_AGE then
                runState.inDelve       = true
                runState.delveName     = matchedName
                runState.delveKind     = saved.kind
                runState.startTime     = saved.startTime
                -- Fresh popup window from THIS entry: reusing saved.startTime
                -- would trip the 60s late-firing guard immediately and suppress
                -- the reminder after a mid-run reload (GetTime() is continuous).
                runState.popupWindowStart = GetTime()
                runState.deaths        = saved.deaths or 0
                runState.startKeyCount = saved.startKeyCount or 0
                runState.startKeyItems = saved.startKeyItems or 0
                runState.keyUsed       = saved.keyUsed or false
                runState.tier          = saved.tier or 0
                runState.wasBountiful  = saved.wasBountiful or false
                runState.story         = saved.story
                runState.lastResult    = nil
                runState.trovehunterPopupShown = saved.trovehunterPopupShown or false
                TryCaptureTier("restored")
                -- TryCaptureTier short-circuits if tier was already captured;
                -- run the reminder check explicitly so a never-shown popup fires.
                if E.MaybeShowTrovehunterReminder then
                    E:MaybeShowTrovehunterReminder()
                end
                -- A resumed run has no heartbeat and a possibly-stale saved.tier;
                -- settle it against the live tracker.
                SettleTier()
            elseif not (enteredViaReload or enteredViaLogin) then
                -- A /reload or relog is NOT a new entry, so it NEVER begins a
                -- fresh run here -- it can only resume above. If nothing resumed,
                -- the run already ended (e.g. reloading while looting after the
                -- boss clears activeRun); beginning would show a phantom 0:00 run.
                -- Only a genuine entry (entryArmed) or untracked recovery begins.
                if E.db then E.db.activeRun = nil end
                BeginDelveRun(matchedName, kind)
            elseif saved and saved.name == matchedName
                    and saved.startedAt
                    and (time() - saved.startedAt) < MAX_RESUME_AGE then
                -- Couldn't resume above (typically a client restart reset GetTime()
                -- so saved.startTime now reads in the future), but a saved activeRun
                -- proves a genuine, wall-clock-recent run was in progress -- begin a
                -- fresh clock so the HUD/timer/objectives aren't left dead instead of
                -- dead-locking. A COMPLETED run clears activeRun, so requiring `saved`
                -- here means this can never start a phantom in the post-boss window.
                if E.db then E.db.activeRun = nil end
                BeginDelveRun(matchedName, kind)
            end
        elseif runState.delveName ~= matchedName then
            -- Canonical name resolved on the SAME in-progress run: upgrade in
            -- place and keep the existing startTime — never restart the clock.
            runState.delveName = matchedName
            runState.delveKind = kind
            if E.db and E.db.activeRun then
                E.db.activeRun.name = matchedName
                E.db.activeRun.kind = kind
            end
            TryCaptureTier(source or "retry")
        else
            TryCaptureTier(source or "retry")
        end
    else
        -- Name unresolved (cold POI cache): start a provisional run to still
        -- track timing/deaths, but only on a genuine entry or an untracked
        -- recovery — a /reload/reconnect instead waits to resume the saved run.
        if (entryArmed or (not runState.inDelve
                and not enteredViaReload and not enteredViaLogin)) and not continuing then
            entryArmed = false
            runState.inDelve       = true
            runState.delveName     = candidate
            runState.delveKind     = nil
            runState.startTime     = GetTime()
            runState.popupWindowStart = GetTime()
            runState.deaths        = 0
            runState.startKeyCount = GetCurrencyQty(COFFER_KEY_CURRENCY)
            runState.startKeyItems = GetKeyItemCount()
            runState.keyUsed       = false
            runState.tier          = 0
            runState.wasBountiful  = false
            runState.story         = nil
            runState.boss          = nil
            runState.lastResult    = nil
            -- Persist so a /reload during the unresolved-name window resumes.
            if E.db then
                E.db.activeRun = {
                    name          = candidate,
                    kind          = nil,
                    startTime     = runState.startTime,
                    startedAt     = time(),
                    deaths        = 0,
                    startKeyCount = runState.startKeyCount,
                    startKeyItems = runState.startKeyItems,
                    keyUsed       = false,
                    tier          = 0,
                    wasBountiful  = false,
                    story         = nil,
                    trovehunterPopupShown = false,
                }
            end
            TryCaptureTier("provisional")
            SettleTier()   -- cold-cache entry: settle the tier as the UI populates
        else
            TryCaptureTier(source or "retry")
        end
    end
end

-- Detect the Restored Coffer Key (currency 3028) being spent. The only reliable
-- signal is the SIGNED quantityChange in CURRENCY_DISPLAY_UPDATE (11.0.2+): a
-- negative delta = spent. A snapshot compare was removed because delve entry
-- auto-converts 100 shards into a key and a mid-run /reload restored a stale
-- baseline, both producing false positives. A gain (entry conversion) is a
-- positive delta and ignored. The coffer is usually looted AFTER
-- SCENARIO_COMPLETED, so detection runs in-delve and via post-completion keyWatch.
local function CheckKeySpend(currencyType, quantityChange, destroyReason)
    if currencyType ~= COFFER_KEY_CURRENCY then return end
    if type(quantityChange) ~= "number" then return end

    DebugTier("key currency(3028): delta=%d qty=%d reason=%s inDelve=%s keyWatch=%s",
        quantityChange, GetCurrencyQty(COFFER_KEY_CURRENCY),
        tostring(destroyReason), tostring(runState.inDelve),
        tostring(keyWatch ~= nil))

    if quantityChange >= 0 then return end   -- a gain (e.g. the entry conversion)

    -- A key was spent. Attribute to the live run, else the just-completed one.
    if runState.inDelve then
        if not runState.keyUsed then
            runState.keyUsed = true
            if E.db and E.db.activeRun then E.db.activeRun.keyUsed = true end
            DebugTier("coffer key spend detected mid-run (delta=%d, reason=%s)",
                quantityChange, tostring(destroyReason))
        end
    elseif keyWatch then
        local r = keyWatch.run
        if r and not r.keyUsed then
            r.keyUsed = true
            local hist = E.db and E.db.delveHistory
                and E.db.delveHistory[keyWatch.name]
            if hist and hist.lifetime then
                hist.lifetime.totalKeysUsed =
                    (hist.lifetime.totalKeysUsed or 0) + 1
            end
            if E.RefreshDelveHistoryTab then E:RefreshDelveHistoryTab() end
            DebugTier("coffer key spend detected post-completion -> %s (delta=%d)",
                tostring(keyWatch.name), quantityChange)
        end
        keyWatch = nil
    end
end

delveFrame:SetScript("OnEvent", function(_, event, ...)
    if event == "CURRENCY_DISPLAY_UPDATE" then
        local currencyType, _, quantityChange, _, destroyReason = ...
        CheckKeySpend(currencyType, quantityChange, destroyReason)
        return
    end
    -- Record how this world-entry happened before any delve detection. Re-set
    -- on every PEW so a plain zone-in clears a leftover reload/login flag.
    if event == "PLAYER_ENTERING_WORLD" then
        local isInitialLogin, isReloadingUi = ...
        enteredViaReload = isReloadingUi and true or false
        enteredViaLogin  = isInitialLogin and true or false
        -- A real loading screen is a transition OUT of the just-completed
        -- instance, so always release the latch. The stray events it guards
        -- against (SCENARIO_UPDATE/ZONE_CHANGED during looting) never carry a
        -- PEW, so suppression is preserved.
        runCompleted = false
        -- Only a GENUINE new world-entry (NOT a /reload or relog/reconnect) arms
        -- the next delve detection to stamp a FRESH run start. /reload and relog
        -- are deliberately NOT armed so the resume path restores the saved run's
        -- original start instead of restarting its clock.
        if not isReloadingUi and not isInitialLogin then
            entryArmed = true
        end
    end

    if event == "PLAYER_ENTERING_WORLD"
            or event == "ZONE_CHANGED_NEW_AREA"
            or event == "SCENARIO_UPDATE" then
        -- SCENARIO_UPDATE fires 5-10x during entry. Once in a delve with the
        -- tier captured, skip the expensive ObjectiveTracker scrape but still
        -- retry the bountiful snapshot and the trovehunter popup.
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
            -- Mirror into the persisted run so a mid-run /reload restores the
            -- real death total, not the deaths=0 written at BeginDelveRun.
            if E.db and E.db.activeRun then
                E.db.activeRun.deaths = runState.deaths
            end
        end

    elseif event == "ENCOUNTER_END" then
        -- If more than one encounter fires, the last (the end boss) wins.
        if runState.inDelve then
            local _, encounterName = ...
            if encounterName and encounterName ~= "" then
                runState.boss = encounterName
            end
        end

    elseif event == "SCENARIO_COMPLETED" then
        local candidate = ResolveDelveName()
        if not candidate or candidate == "" then
            candidate = runState.delveName
        end
        local matchedName = MatchDelveName(candidate or "")

        -- Recover the start when the live tracker lost it (e.g. a cold-cache /
        -- reconnect entry that never re-stamped runState): fall back to the
        -- persisted activeRun, but only for THIS delve and recent (resume guard).
        local saved = E.db and E.db.activeRun
        if (not runState.inDelve
                or not (runState.startTime and runState.startTime > 0))
                and saved and saved.name == matchedName
                and saved.startTime and saved.startTime > 0
                and saved.startTime <= GetTime()
                and saved.startedAt
                and (time() - saved.startedAt) < MAX_RESUME_AGE then
            runState.inDelve       = true
            runState.delveName     = matchedName
            runState.startTime     = saved.startTime
            runState.deaths        = saved.deaths or runState.deaths or 0
            runState.tier          = saved.tier or runState.tier or 0
            runState.keyUsed       = saved.keyUsed or runState.keyUsed or false
            runState.wasBountiful  = saved.wasBountiful or runState.wasBountiful or false
            runState.story         = runState.story or saved.story
            runState.startKeyCount = saved.startKeyCount or runState.startKeyCount or 0
            runState.startKeyItems = saved.startKeyItems or runState.startKeyItems or 0
            DebugTier("completion: recovered start from activeRun (start=%.0f)",
                saved.startTime)
        end

        -- A completion with no tracked run and no recoverable start is a PHANTOM
        -- (stray/duplicate SCENARIO_COMPLETED, or a begin that was latch-
        -- suppressed). Logging it appends a bogus 0-duration row. Don't log;
        -- clean up and re-latch the post-loot window.
        if not (matchedName and runState.inDelve
                and runState.startTime and runState.startTime > 0) then
            DebugTier("completion ignored (no tracked run): matched=%s inDelve=%s start=%.0f",
                tostring(matchedName), tostring(runState.inDelve),
                runState.startTime or 0)
            EndDelveRun()
            runCompleted = true
            return
        end

        local duration = math.max(0, math.floor(GetTime() - runState.startTime))
        -- No real run is longer than MAX_RESUME_AGE, so an absurd duration means
        -- a stale start slipped the resume guard; log it as unknown (0).
        if duration > MAX_RESUME_AGE then
            duration = 0
        end

        -- Re-read the tier and prefer it. The value captured at ENTRY reads the
        -- PREVIOUS run's tier (the tracker still shows the delve we left); by
        -- completion the tracker reliably shows THIS run. Fall back to
        -- runState.tier only if the re-read is empty (tracker torn down).
        local latched   = runState.tier or 0
        local confirmed = AutoDetectDelveTier()
        local tier      = (confirmed and confirmed > 0) and confirmed or latched
        runState.tier   = tier
        DebugTier("completion: latched=%d reread=%s -> logging T%d",
            latched, tostring(confirmed), tier)
        RefreshBountifulSnapshot()

        -- The coffer's key is usually spent AFTER this event, so an unflagged
        -- run arms a post-completion keyWatch (below) that flags it on the drop.
        local keyUsed = runState.keyUsed or false

        if matchedName then
            -- Re-read the story as a fallback if entry capture missed (cold cache).
            local story = runState.story
            if not story or story == "" then
                story = E:GetDelveStoryVariant(matchedName)
            end
            -- Correct the live boss name to the unit actually fought (e.g.
            -- "Spinshroom" reports but "Gyrospore" is shown). Scoped in Data.lua.
            if runState.boss then
                runState.boss = E:NormalizeLiveBoss(matchedName, runState.boss)
            end
            -- Read before LogDelveRun folds this run into the history.
            local priorBest = E:GetBestRunTime(matchedName, tier)
                or E:GetBestRunTime(matchedName)
            E:LogDelveRun(
                matchedName, tier, duration, runState.deaths,
                keyUsed, runState.wasBountiful, story, runState.boss
            )
            if duration > 0 then
                runState.lastResult = {
                    duration = duration,
                    beat     = (not priorBest) or duration <= priorBest,
                }
            end
            if runState.boss and story and story ~= "" then
                E:RecordDelveBoss(matchedName, story, runState.boss)
            end
            if E.RefreshDelveHistoryTab then
                E:RefreshDelveHistoryTab()
            end
        end

        -- Arm a key watch on every logged run whose key isn't already flagged;
        -- CheckKeySpend flags it when the key drops during looting, else the
        -- watch is cleared on delve exit.
        keyWatch = nil
        if matchedName and not keyUsed then
            local hist = E.db and E.db.delveHistory
                and E.db.delveHistory[matchedName]
            local loggedRun = hist and hist.recentRuns and hist.recentRuns[1]
            if loggedRun then
                keyWatch = { run = loggedRun, name = matchedName }
            end
        end

        EndDelveRun()
        -- Still physically inside the finished instance (looting): block
        -- begin/resume until the player leaves so a trailing event can't spawn
        -- a phantom run.
        runCompleted = true

        if E._gildedRecapture then E._gildedRecapture:Cancel() end
        local gildedTicks = 0
        E._gildedRecapture = C_Timer.NewTicker(3, function(ticker)
            gildedTicks = gildedTicks + 1
            E:CaptureGildedStash()
            local _, _, diffID = GetInstanceInfo()
            if diffID ~= 208 or gildedTicks >= 20 then
                ticker:Cancel()
                E._gildedRecapture = nil
            end
        end)
    end
end)
