------------------------------------------------------------------------
-- UI/CompanionAudio.lua — Companion Voice & Bubble Settings
-- Applies MuteSoundFile/UnmuteSoundFile for Valeera and Dundun based
-- on E.db settings. Also handles Valeera speech bubble suppression via
-- selective C_ChatBubbles polling with a CVar fallback while in delves.
------------------------------------------------------------------------
local E = EverythingDelves

------------------------------------------------------------------------
-- Valeera companion voice line sound IDs — Midnight 12.0 Season 1
------------------------------------------------------------------------
local VALEERA_SOUNDS = {
    7243762, 7243934, 7329273, 7430043, 7430047, 7430050, 7430053, 7430056, 7430059, 7430063,
    7430066, 7430069, 7430072, 7430075, 7430078, 7430082, 7430086, 7430089, 7430092, 7430095,
    7430098, 7430101, 7430104, 7430107, 7430110, 7430113, 7430116, 7430119, 7430122, 7430125,
    7430156, 7430159, 7430162, 7430165, 7430168, 7430171, 7430174, 7430177, 7430180, 7430183,
    7430186, 7430189, 7430192, 7430196, 7430199, 7430202, 7430205, 7430208, 7430211, 7430230,
    7430233, 7430237, 7430257, 7430268, 7430275, 7430283, 7430294, 7430314, 7430324, 7430333,
    7430336, 7430339, 7430342, 7430345, 7430348, 7430351, 7430354, 7430357, 7430360, 7430363,
    7430366, 7430369, 7430372, 7430375, 7430378, 7430381, 7430384, 7430388, 7430391, 7430394,
    7430397, 7430400, 7430405, 7430416, 7430423, 7430428, 7430431, 7430434, 7430437, 7430440,
    7430443, 7430446, 7430449, 7430452, 7430456, 7430459, 7430462, 7430465, 7430468, 7430471,
    7430474, 7430477, 7430480, 7430483, 7430486, 7430489, 7430492, 7430498, 7430506, 7430512,
    7430516, 7430519, 7430538, 7430547, 7430550, 7430555, 7430561, 7430565, 7430733, 7430740,
    7430751, 7430754, 7430778, 7430781, 7430784, 7430787, 7430790, 7430793, 7430796, 7430799,
    7430864, 7430867, 7430870, 7430881, 7430973, 7430985, 7430989, 7431077, 7431084, 7431087,
    7431093, 7431103, 7431106, 7431109, 7431112, 7431115, 7431119, 7431123, 7440991, 7461759,
}

------------------------------------------------------------------------
-- Dundun (rat companion) voice line sound IDs — Midnight 12.0 Season 1
------------------------------------------------------------------------
local DUNDUN_SOUNDS = {
    7249707, 7251759, 7251762, 7251765, 7251768, 7251771, 7251774, 7251777,
    7251784, 7251787, 7251790, 7251793, 7251796, 7251799,
    7251805, 7251808, 7251811, 7251814, 7251817, 7251820, 7251823, 7251826,
    7251829, 7251836, 7251839, 7251842,
    7251845, 7261433, 7273124, 7273905, 7273906, 7273907, 7273908, 7273909,
    7273910, 7273911,
    7609114, 7609115, 7609116,
}

local COMPANION_TOKENS  = { "companion", "delvecompanion", "follower" }
local CHAT_BUBBLE_CVAR  = "chatBubbles"
local BUBBLE_GUID_METHODS  = { "GetSourceGUID",  "GetGUID" }
local BUBBLE_TOKEN_METHODS = { "GetSourceUnit",  "GetSourceUnitToken", "GetUnitToken" }

local bubbleTicker      = nil
local bubbleCVarBackup  = nil
local isInDelve         = false
local suppressCVarEvent = false
local selectiveOK       = nil   -- nil=untested, true=works, false=unsupported on this client

------------------------------------------------------------------------
-- Delve detection
------------------------------------------------------------------------
local function CheckInDelve()
    local _, instType, diffID = GetInstanceInfo()
    if diffID == 208 then return true end
    if instType == "scenario" then
        if C_ScenarioInfo and C_ScenarioInfo.GetScenarioInfo then
            local ok, info = pcall(C_ScenarioInfo.GetScenarioInfo)
            if ok and info then
                if info.isDelve then return true end
                if Enum and Enum.ScenarioType
                        and info.scenarioType == Enum.ScenarioType.Delve then
                    return true
                end
            end
        end
        return true  -- treat all scenarios as potential delves for fallback
    end
    return false
end

------------------------------------------------------------------------
-- Sound list toggling
------------------------------------------------------------------------
local function ToggleSoundList(list, mute)
    if not MuteSoundFile or not UnmuteSoundFile then return end
    local fn = mute and MuteSoundFile or UnmuteSoundFile
    for _, id in ipairs(list) do fn(id) end
end

------------------------------------------------------------------------
-- Speech bubble suppression
------------------------------------------------------------------------
local function GetCompanionIdentity()
    for _, token in ipairs(COMPANION_TOKENS) do
        if UnitExists and UnitExists(token) then
            return UnitGUID and UnitGUID(token), token
        end
    end
    return nil, nil
end

local function IsBubbleFromCompanion(bubble, guid, token)
    for _, m in ipairs(BUBBLE_GUID_METHODS) do
        local fn = bubble[m]
        if type(fn) == "function" then
            local ok, val = pcall(fn, bubble)
            if ok and guid and val == guid then return true end
        end
    end
    for _, m in ipairs(BUBBLE_TOKEN_METHODS) do
        local fn = bubble[m]
        if type(fn) == "function" then
            local ok, val = pcall(fn, bubble)
            if ok and type(val) == "string" and val:lower() == token then return true end
        end
    end
    return false
end

local function StopBubbleTicker()
    if bubbleTicker then bubbleTicker:Cancel(); bubbleTicker = nil end
end

local function RestoreBubbleCVar()
    if bubbleCVarBackup and SetCVar then
        suppressCVarEvent = true
        pcall(SetCVar, CHAT_BUBBLE_CVAR, bubbleCVarBackup)
        suppressCVarEvent = false
        bubbleCVarBackup = nil
    end
end

local function ApplyBubbleCVar()
    if not (GetCVar and SetCVar) then return false end
    if not bubbleCVarBackup then
        bubbleCVarBackup = GetCVar(CHAT_BUBBLE_CVAR)
    end
    suppressCVarEvent = true
    local ok = pcall(SetCVar, CHAT_BUBBLE_CVAR, "0")
    suppressCVarEvent = false
    return ok
end

-- Run one selective-hide tick. Returns false if the API can't identify bubble owners.
local function TickSelectiveBubbles()
    if not (C_ChatBubbles and C_ChatBubbles.GetAllChatBubbles) then return false end
    local guid, token = GetCompanionIdentity()
    if not guid and not token then return true end  -- no companion, nothing to do

    local ok, bubbles = pcall(C_ChatBubbles.GetAllChatBubbles)
    if not ok or type(bubbles) ~= "table" then return false end

    if #bubbles == 0 then return true end  -- no bubbles at all, no verdict yet

    -- Check whether any bubble exposes owner metadata
    local sawOwnerAPI = false
    for _, b in ipairs(bubbles) do
        for _, m in ipairs(BUBBLE_GUID_METHODS) do
            if type(b[m]) == "function" then sawOwnerAPI = true; break end
        end
        if not sawOwnerAPI then
            for _, m in ipairs(BUBBLE_TOKEN_METHODS) do
                if type(b[m]) == "function" then sawOwnerAPI = true; break end
            end
        end
        if sawOwnerAPI then break end
    end

    if not sawOwnerAPI then return false end  -- selective unsupported on this client

    -- Hide companion bubbles
    for _, b in ipairs(bubbles) do
        if IsBubbleFromCompanion(b, guid, token) then pcall(b.Hide, b) end
    end
    return true
end

local RefreshBubbleState
RefreshBubbleState = function()
    if not (E.db and E.db.muteValeeraBubbles) then
        StopBubbleTicker()
        RestoreBubbleCVar()
        return
    end

    isInDelve = CheckInDelve()

    -- Selective ticker (preferred): hides only Valeera's bubbles
    if selectiveOK ~= false
            and C_ChatBubbles and C_ChatBubbles.GetAllChatBubbles
            and C_Timer and C_Timer.NewTicker then
        if not bubbleTicker then
            bubbleTicker = C_Timer.NewTicker(0.2, function()
                local worked = TickSelectiveBubbles()
                if worked == false then
                    selectiveOK = false
                    StopBubbleTicker()
                    if CheckInDelve() then ApplyBubbleCVar() end
                else
                    selectiveOK = true
                end
            end)
        end
        return
    end

    -- Fallback: disable all chat bubbles while inside a delve
    if isInDelve then
        ApplyBubbleCVar()
    else
        RestoreBubbleCVar()
    end
end

------------------------------------------------------------------------
-- Public entry point — called on login and when checkboxes change
------------------------------------------------------------------------
function E:ApplyCompanionAudio()
    ToggleSoundList(VALEERA_SOUNDS, self.db and self.db.muteValeera)
    ToggleSoundList(DUNDUN_SOUNDS,  self.db and self.db.muteDundun)
    RefreshBubbleState()
end

------------------------------------------------------------------------
-- Module init
------------------------------------------------------------------------
E:RegisterModule(function()
    -- E.db is ready at module init time (InitDB runs before InitMainFrame)
    E:ApplyCompanionAudio()

    local ef = CreateFrame("Frame")
    ef:RegisterEvent("PLAYER_ENTERING_WORLD")
    ef:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    ef:RegisterEvent("SCENARIO_UPDATE")
    ef:RegisterEvent("SCENARIO_CRITERIA_UPDATE")
    ef:RegisterEvent("PLAYER_LOGOUT")
    ef:RegisterEvent("CVAR_UPDATE")

    ef:SetScript("OnEvent", function(_, event, arg1)
        if event == "PLAYER_ENTERING_WORLD"
                or event == "ZONE_CHANGED_NEW_AREA"
                or event == "SCENARIO_UPDATE"
                or event == "SCENARIO_CRITERIA_UPDATE" then
            isInDelve = CheckInDelve()
            RefreshBubbleState()
        elseif event == "CVAR_UPDATE" then
            local cvar = string.lower(tostring(arg1 or ""))
            -- If user manually changes chatBubbles while we've forced it off, re-apply
            if not suppressCVarEvent
                    and cvar == string.lower(CHAT_BUBBLE_CVAR)
                    and bubbleCVarBackup
                    and isInDelve
                    and E.db and E.db.muteValeeraBubbles then
                ApplyBubbleCVar()
            end
        elseif event == "PLAYER_LOGOUT" then
            StopBubbleTicker()
            RestoreBubbleCVar()
        end
    end)
end)
