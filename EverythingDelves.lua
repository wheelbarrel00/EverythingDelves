------------------------------------------------------------------------
-- EverythingDelves.lua
-- Addon bootstrap: global namespace, SavedVariables, events, slash cmds
--
-- Midnight 12.0 API compliance: This addon is display/tracking only.
-- We read currencies, quest logs, map data, and item levels but never
-- inject gameplay logic or automate player actions.
------------------------------------------------------------------------

-- Global addon namespace — every other file references this table
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
local DEFAULTS = {
    minimapButton = {
        show  = true,
        angle = 220, -- degrees around the minimap edge
    },
    framePosition    = nil,       -- { point, relPoint, x, y }
    defaultTab       = 1,
    completedDisplay = "dim",     -- "hide" | "dim" | "bottom"
    uiScale          = 1.0,
    accentColor      = "red",     -- "red" | "gold" | "purple"
    showWeeklyResetAlert   = true,
    sessionTracking        = true,
    showCompletedItems     = true,
    lowShardWarning        = true,
    lowShardThreshold      = 100,
    alertNewBountiful      = false,
    alertSpecialAssignment = false,
    manualComplete         = {},   -- [delveName] = timestamp for manually-marked completes (auto-expires on weekly reset)
    lastKnownBountifulIDs  = {},   -- list of POI IDs from last bountiful scan
    lastKnownActiveSAs     = {},   -- list of active SA quest IDs from last scan
    delveHistory           = {},   -- [delveName] = { completions = { {date, week}, ... }, totalRuns = 0 }
}

------------------------------------------------------------------------
-- SavedVariables helpers
------------------------------------------------------------------------
function E:InitDB()
    if not EverythingDelvesDB then
        EverythingDelvesDB = {}
    end
    -- Shallow-merge defaults into the saved table without overwriting
    -- existing values so player settings survive addon updates.
    for k, v in pairs(DEFAULTS) do
        if EverythingDelvesDB[k] == nil then
            if type(v) == "table" then
                EverythingDelvesDB[k] = CopyTable(v) -- deep copy
            else
                EverythingDelvesDB[k] = v
            end
        end
    end
    E.db = EverythingDelvesDB
end

function E:ResetDB()
    EverythingDelvesDB = CopyTable(DEFAULTS)
    E.db = EverythingDelvesDB
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

-- Data-tracking events — uses a callback list so multiple modules
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
-- each event triggers a full tab refresh — tens of SetText calls and
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
