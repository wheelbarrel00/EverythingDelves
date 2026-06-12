------------------------------------------------------------------------
-- UI/PinAchievements.lua
-- Appends this delve's incomplete achievements to the world-map POI
-- tooltip (bountiful and normal pins alike).
--
-- Display modes (Options → Display → achievementTooltip):
--   "summary" (default) — one line with the count; hold Shift to expand
--   "full"              — always expanded
--   "off"               — never append
--
-- When today's story variant is still needed for the delve's Stories
-- achievement, a highlight line is shown in every mode — that's the
-- "run it today and it counts" signal.
--
-- Detection hooks GameTooltip's OnShow rather than any map-pin mixin.
-- Pin mixins are a moving target: Blizzard derives pin types by COPYING
-- mixin functions at its own file load, so a mixin-table hook installed
-- at addon load never reaches pin types that took their copy earlier
-- (confirmed live: the mixin hook fired for some pins and not others).
-- The tooltip is the one funnel every pin path goes through. A tooltip
-- counts as a delve POI tooltip when:
--   (a) its owner frame carries one of our delve areaPoiIDs, or
--   (b) it is owned by a WorldMapFrame descendant (pins often anchor
--       the tooltip to the map canvas) AND its title is a delve name.
--
-- Persistence: timed POI tooltips (the bountiful "Time Left" countdown)
-- REBUILD themselves every refresh tick — ClearLines + re-add — which
-- wipes appended lines without ever hiding the tooltip (so OnShow does
-- not re-fire). OnTooltipCleared + a next-frame re-append keeps our
-- section alive through those rebuilds (confirmed live: lines appended
-- on hover were visibly gone by the first countdown tick).
------------------------------------------------------------------------
local E = EverythingDelves

local GameTooltip, IsShiftKeyDown = GameTooltip, IsShiftKeyDown

------------------------------------------------------------------------
-- areaPoiID → canonical delve name (both bountiful and normal POIs)
------------------------------------------------------------------------
local poiToDelve = {}
for _, d in ipairs(E.DelveData or {}) do
    if d.poiID       then poiToDelve[d.poiID]       = d.name end
    if d.normalPoiID then poiToDelve[d.normalPoiID] = d.name end
end

local HEADER_TEXT = "Delve Achievements"

-- Hidden diagnostic (/ed achtip): one line per delve-tooltip detection
-- explaining what was resolved and why the append did or didn't happen.
local function DebugTip(msg)
    if E.db and E.db.debugAchTip then
        print("|cFFFFD700[ED achtip]|r " .. msg)
    end
end

--- The owner's area POI id, wherever this client build keeps it.
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

--- True when the frame sits inside the world map (pins anchor their
--- tooltip to the map canvas as often as to themselves).
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

--- The tooltip's current title line, or nil.
local function TooltipTitle()
    local fs = _G.GameTooltipTextLeft1
    return fs and fs:GetText()
end

--- True if the tooltip already carries our section (idempotence guard).
local function AlreadyAppended()
    for i = 1, GameTooltip:NumLines() do
        local fs = _G["GameTooltipTextLeft" .. i]
        local text = fs and fs:GetText()
        if text and text:find(HEADER_TEXT, 1, true) then return true end
    end
    return false
end

------------------------------------------------------------------------
-- Tooltip content
------------------------------------------------------------------------
-- What our section currently shows: { delve, status, credit, expanded,
-- loggedRebuild }. Cleared when the tooltip hides or is repurposed for
-- something else; read by the rebuild re-append and the Shift expand.
local current

-- Which delve the user expanded. Lives OUTSIDE `current`, detached
-- from any tooltip lifecycle, because the map yanks tooltips around on
-- every modifier press: it hides+re-shows the pin's tooltip AND can
-- briefly hand the tooltip to a different overlapping POI entirely
-- (confirmed live: a "Memorial Plaque" tooltip appeared between Shift
-- press and the delve tooltip's return). Any lifecycle-based clearing
-- gets fooled by that. Cleared ONLY by: the user's collapse toggle,
-- expanding a different delve, or closing the world map.
local expandedDelve

-- Set when the user toggles a section closed. The collapse keypress
-- itself makes the map re-show the tooltip while Shift is still held,
-- and BuildSection would read IsShiftKeyDown()==true and re-expand —
-- so the held key is ignored as an expand request for a beat.
local suppressShiftUntil = 0

local function AddDetailLines(status)
    local s = status.stories
    if s and not s.done then
        GameTooltip:AddLine(
            E.CC.body .. "Stories" .. E.CC.close
                .. E.CC.muted .. " — missing: " .. E.CC.close
                .. E.CC.white .. table.concat(s.missing, ", ") .. E.CC.close,
            nil, nil, nil, true)
    end
    local d = status.discoveries
    if d and not d.done then
        GameTooltip:AddLine(
            E.CC.body .. "Sturdy Chests" .. E.CC.close
                .. E.CC.muted .. (" — %d/%d found"):format(d.found, d.total)
                .. E.CC.close)
    end
    if #status.depthsMissing > 0 then
        GameTooltip:AddLine(
            E.CC.body .. "Delver of the Depths" .. E.CC.close
                .. E.CC.muted .. " — clear on: " .. E.CC.close
                .. E.CC.white .. table.concat(status.depthsMissing, ", ")
                .. E.CC.close,
            nil, nil, nil, true)
    end
end

--- Render the section from a prepared state table (fresh or cached).
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

--- First-time build for a freshly detected delve tooltip.
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

------------------------------------------------------------------------
-- Detection — GameTooltip OnShow
------------------------------------------------------------------------
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
    -- Contain errors: one escaping a tooltip hook is invisible when
    -- script errors are hidden and looks like the feature silently died.
    local ok, err = pcall(BuildSection, delveName, mode)
    if not ok then
        DebugTip("ERROR: " .. tostring(err))
    end
end

------------------------------------------------------------------------
-- Survival — re-append after the tooltip's own refresh rebuilds.
-- The rebuild is synchronous: ClearLines (→ OnTooltipCleared, where we
-- only flag the wipe — Blizzard hasn't re-added its lines yet, so
-- appending there would land our section above the title) … AddLine ×N
-- … :Show(). Re-appending from a Show post-hook puts our lines back in
-- the SAME frame the rebuild happened — re-appending a frame later
-- (C_Timer) made the tooltip visibly stutter at ~5 Hz as our section
-- blinked out and back each countdown tick.
------------------------------------------------------------------------
local wiped = false           -- our section was cleared by a rebuild
local rendering = false       -- inside RenderSection's own :Show()
local pendingReappend = false

local function TryReappend()
    if rendering then return end
    local cur = current
    if not (cur and wiped) then return end

    -- The rebuild may have repurposed the tooltip for something else
    -- entirely (mousing from a pin to a bag item never hides it).
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
    -- Backstop only: any rebuild path that never calls :Show() still
    -- gets the section back next frame.
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

-- Closing the map is the one safe "done here" signal for the sticky.
if _G.WorldMapFrame then
    _G.WorldMapFrame:HookScript("OnHide", function()
        if expandedDelve then
            expandedDelve = nil
            DebugTip("sticky expansion cleared (map closed)")
        end
    end)
end

------------------------------------------------------------------------
-- Shift expand — flip the cached state; the next refresh tick redraws
-- the section expanded (timed POI tooltips rebuild several times a
-- second). For static tooltips, append the details immediately.
------------------------------------------------------------------------
local modWatcher = CreateFrame("Frame")
modWatcher:RegisterEvent("MODIFIER_STATE_CHANGED")
local shiftWasDown = false
modWatcher:SetScript("OnEvent", function(_, _, key)
    -- Match any shift key by name and read the live key state rather
    -- than trusting the event's pressed/released argument — both have
    -- format variations across client builds.
    if type(key) ~= "string" or not key:find("SHIFT", 1, true) then return end
    -- A HELD shift key delivers key-repeat echoes of this event
    -- (confirmed live: one physical hold logged alternating
    -- expand/collapse toggles). Only a real state EDGE may act.
    local down = IsShiftKeyDown()
    if down == shiftWasDown then return end  -- repeat echo, not an edge
    shiftWasDown = down
    if not down then return end              -- release edge
    if not current then return end           -- no active section
    if not GameTooltip:IsShown() then
        DebugTip("shift: tooltip not shown")
        return
    end
    if current.expanded then
        -- Toggle off. Timed tooltips redraw as summary on the next
        -- refresh tick; static ones keep the lines until re-hovered
        -- (tooltip lines can't be removed in place).
        current.expanded = false
        expandedDelve = nil
        suppressShiftUntil = GetTime() + 0.5
        DebugTip("shift: collapsing on next refresh")
        return
    end
    current.expanded = true
    expandedDelve = current.delve
    if AlreadyAppended() then
        -- Expand in place by appending the detail lines now; the next
        -- refresh tick (timed tooltips) redraws the section properly.
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
