-- Appends a delve's incomplete achievements to its world-map POI tooltip.
-- Hooks GameTooltip's OnShow, not a pin mixin: Blizzard derives pin types by
-- copying mixin functions at its own load, so a mixin hook installed at addon
-- load never reaches pins that copied earlier (confirmed live). A tooltip is
-- treated as a delve POI when its owner carries one of our areaPoiIDs, or it's
-- a WorldMapFrame descendant whose title is a delve name.
local E = EverythingDelves

local GameTooltip, IsShiftKeyDown = GameTooltip, IsShiftKeyDown

-- BATTLE_PET_SOURCE_6 = "Achievement", PVP_PROGRESS_REWARDS_HEADER = "Progress";
-- fallbacks cover the rare case a standard global is absent.
local GREEN_C        = GREEN_FONT_COLOR or CreateColor(0.12, 1.00, 0.12)
local RED_C          = RED_FONT_COLOR   or CreateColor(1.00, 0.24, 0.24)
local ACH_LABEL      = _G.BATTLE_PET_SOURCE_6      or "Achievement"
local PROGRESS_LABEL = _G.PVP_PROGRESS_REWARDS_HEADER or "Progress"

local poiToDelve = {}
for _, d in ipairs(E.DelveData or {}) do
    if d.poiID       then poiToDelve[d.poiID]       = d.name end
    if d.normalPoiID then poiToDelve[d.normalPoiID] = d.name end
end

local HEADER_TEXT = "Delve Achievements"

-- Hidden /ed achtip diagnostic: logs each detection and why it did/didn't append.
local function DebugTip(msg)
    if E.db and E.db.debugAchTip then
        print("|cFFFFD700[ED achtip]|r " .. msg)
    end
end

local function GetPinPoiID(pin)
    if type(pin) ~= "table" then return nil end
    if pin.areaPoiID then return pin.areaPoiID end
    local info = pin.poiInfo
    if type(info) == "table" and info.areaPoiID then return info.areaPoiID end
    if type(pin.GetPoiID) == "function" then
        local ok, id = pcall(pin.GetPoiID, pin)
        if ok then return id end
    end
    return nil
end

local function IsWorldMapDescendant(frame)
    local worldMap = _G.WorldMapFrame
    if not (frame and worldMap and type(frame.GetParent) == "function") then
        return false
    end
    local f, hops = frame, 0
    while f and hops < 12 do
        if f == worldMap then return true end
        f = f:GetParent()
        hops = hops + 1
    end
    return false
end

local function TooltipTitle()
    local fs = _G.GameTooltipTextLeft1
    return fs and fs:GetText()
end

local function AlreadyAppended()
    for i = 1, GameTooltip:NumLines() do
        local fs = _G["GameTooltipTextLeft" .. i]
        local text = fs and fs:GetText()
        if text and text:find(HEADER_TEXT, 1, true) then return true end
    end
    return false
end

-- Current section state; cleared when the tooltip hides or is repurposed.
local current

-- Kept outside `current` and detached from the tooltip lifecycle: modifier
-- presses make the map hide/re-show tooltips and can briefly swap in a
-- different POI's tooltip (confirmed live). Cleared only by the collapse
-- toggle, expanding a different delve, or closing the world map.
local expandedDelve

-- Collapsing re-shows the tooltip while Shift is still held, which would
-- immediately re-expand; ignore the held key as an expand request for a beat.
local suppressShiftUntil = 0

local function AddCriterion(c)
    local cr, cg, cb = (c.completed and GREEN_C or RED_C):GetRGB()
    if (c.reqQuantity or 0) > 1 then
        local label = (c.name and c.name ~= "") and c.name or PROGRESS_LABEL
        GameTooltip:AddDoubleLine(
            label, ("%d / %d"):format(c.quantity or 0, c.reqQuantity),
            cr, cg, cb, cr, cg, cb)
    else
        GameTooltip:AddDoubleLine(" ", c.name or "?", nil, nil, nil, cr, cg, cb)
    end
end

local function AddGroup(name, done, criteria)
    local hr, hg, hb = (done and GREEN_C or RED_C):GetRGB()
    GameTooltip:AddDoubleLine(ACH_LABEL, name or "?", nil, nil, nil, hr, hg, hb)
    for _, c in ipairs(criteria or {}) do
        if (c.name and c.name ~= "") or (c.reqQuantity or 0) > 1 then
            AddCriterion(c)
        end
    end
end

-- Shows every group complete or not, so the whole picture is visible at once.
local function AddDetailLines(status)
    if status.stories then
        AddGroup(status.stories.name, status.stories.done, status.stories.criteria)
    end

    if status.discoveries then
        AddGroup(status.discoveries.name, status.discoveries.done,
            status.discoveries.criteria)
    end

    if status.depths and #status.depths > 0 then
        -- Delver of the Depths is a series; present this delve's tier brackets as one group.
        local crit = {}
        for _, t in ipairs(status.depths) do
            crit[#crit + 1] = { name = t.label, completed = t.completed }
        end
        local allDone = (status.depthsMissing and #status.depthsMissing == 0)
        AddGroup("Delver of the Depths", allDone, crit)
    end
end

local function RenderSection(cur)
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(E.CC.gold .. HEADER_TEXT .. E.CC.close)

    if cur.expanded then
        AddDetailLines(cur.status)
    else
        GameTooltip:AddLine(
            E.CC.body .. ("%d to earn here"):format(cur.status.summaryCount)
                .. E.CC.close
                .. E.CC.muted .. "  (press Shift for details)" .. E.CC.close)
    end

    if cur.credit then
        GameTooltip:AddLine(
            E.CC.green .. "Today's story (" .. cur.credit
                .. ") still counts — run it today!" .. E.CC.close,
            nil, nil, nil, true)
    end

    GameTooltip:Show()  -- re-measure after appending
end

local function BuildSection(delveName, mode)
    if AlreadyAppended() then
        DebugTip("skip: section already present")
        return
    end

    local status = E:GetDelveAchievementStatus(delveName)
    if not status or status.allDone then
        DebugTip(status and "skip: all achievements complete"
            or "skip: no achievement data")
        return
    end
    local credit = E:GetTodaysStoryCredit(delveName, status)

    if expandedDelve and expandedDelve ~= delveName then
        expandedDelve = nil
    end
    local shiftHeld = IsShiftKeyDown() and GetTime() > suppressShiftUntil
    local expanded = (mode == "full") or shiftHeld
        or expandedDelve == delveName
    if expanded and mode ~= "full" then
        expandedDelve = delveName  -- survive the modifier-driven re-shows
    end

    current = {
        delve    = delveName,
        status   = status,
        credit   = credit,
        expanded = expanded,
    }
    DebugTip(("appending: %d group(s)%s, %s"):format(
        status.summaryCount, credit and ", today-credit" or "",
        current.expanded and "expanded" or "summary"))
    RenderSection(current)
end

local function OnTooltipShow()
    local mode = (E.db and E.db.achievementTooltip) or "summary"
    if mode == "off" then return end

    local owner = GameTooltip:GetOwner()
    local delveName = poiToDelve[GetPinPoiID(owner)]

    if not delveName then
        -- Map-canvas-owned tooltips: identify the delve by title.
        if not IsWorldMapDescendant(owner) then return end
        local title = TooltipTitle()
        if title and E.DelveNamesMatch then
            for name in pairs(E.DelveAchievements or {}) do
                if E.DelveNamesMatch(title, name) then
                    delveName = name
                    break
                end
            end
        end
        if not delveName then
            DebugTip("map tooltip ignored: title "
                .. (title and ('"' .. title .. '"') or "nil"))
            return
        end
    end

    DebugTip("delve tooltip: " .. delveName)
    -- pcall: an error escaping a tooltip hook is invisible and looks like a silent death.
    local ok, err = pcall(BuildSection, delveName, mode)
    if not ok then
        DebugTip("ERROR: " .. tostring(err))
    end
end

-- Re-append after the tooltip's own refresh rebuilds: timed POI countdowns do
-- ClearLines + re-add each tick without ever hiding (so OnShow doesn't re-fire).
-- Re-append from the Show post-hook (same frame as the rebuild); a C_Timer-
-- delayed re-append made the section blink at ~5 Hz each countdown tick.
local wiped = false
local rendering = false       -- inside RenderSection's own :Show()
local pendingReappend = false

local function TryReappend()
    if rendering then return end
    local cur = current
    if not (cur and wiped) then return end

    -- The rebuild may have repurposed the tooltip (mousing pin -> bag item never hides it).
    local title = TooltipTitle()
    if not (title and E.DelveNamesMatch and E.DelveNamesMatch(title, cur.delve)) then
        current, wiped = nil, false
        return
    end
    if AlreadyAppended() then
        wiped = false
        return
    end

    if not cur.loggedRebuild then
        cur.loggedRebuild = true
        DebugTip("tooltip rebuilds itself (timed POI) — re-appending"
            .. " each refresh")
    end
    rendering = true
    local ok, err = pcall(RenderSection, cur)
    rendering = false
    wiped = false
    if not ok then
        DebugTip("ERROR: " .. tostring(err))
    end
end

local function OnTooltipCleared()
    if not current then return end
    wiped = true
    -- Backstop for rebuild paths that never call :Show().
    if not pendingReappend then
        pendingReappend = true
        C_Timer.After(0, function()
            pendingReappend = false
            TryReappend()
        end)
    end
end

GameTooltip:HookScript("OnShow", OnTooltipShow)
GameTooltip:HookScript("OnTooltipCleared", OnTooltipCleared)
hooksecurefunc(GameTooltip, "Show", TryReappend)
GameTooltip:HookScript("OnHide", function()
    current = nil
    wiped = false
end)

-- Closing the map is the one safe "done here" signal for the sticky expansion.
if _G.WorldMapFrame then
    _G.WorldMapFrame:HookScript("OnHide", function()
        if expandedDelve then
            expandedDelve = nil
            DebugTip("sticky expansion cleared (map closed)")
        end
    end)
end

-- Shift toggles the cached expanded state; timed tooltips redraw on the next
-- refresh tick, static ones get details appended immediately.
local modWatcher = CreateFrame("Frame")
modWatcher:RegisterEvent("MODIFIER_STATE_CHANGED")
local shiftWasDown = false
modWatcher:SetScript("OnEvent", function(_, _, key)
    -- Read live key state, not the event arg: key name and pressed/released format vary across client builds.
    if type(key) ~= "string" or not key:find("SHIFT", 1, true) then return end
    -- A held shift delivers key-repeat echoes; only a real state edge may act.
    local down = IsShiftKeyDown()
    if down == shiftWasDown then return end  -- repeat echo, not an edge
    shiftWasDown = down
    if not down then return end
    if not current then return end
    if not GameTooltip:IsShown() then
        DebugTip("shift: tooltip not shown")
        return
    end
    if current.expanded then
        -- Toggle off; lines can't be removed in place, so static tooltips keep them until re-hovered.
        current.expanded = false
        expandedDelve = nil
        suppressShiftUntil = GetTime() + 0.5
        DebugTip("shift: collapsing on next refresh")
        return
    end
    current.expanded = true
    expandedDelve = current.delve
    if AlreadyAppended() then
        DebugTip("shift: expanding in place")
        local ok, err = pcall(AddDetailLines, current.status)
        if ok then
            GameTooltip:Show()
        else
            DebugTip("ERROR: " .. tostring(err))
        end
    else
        DebugTip("shift: expanding on next refresh")
    end
end)
