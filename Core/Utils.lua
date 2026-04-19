------------------------------------------------------------------------
-- Core/Utils.lua
-- Shared utility functions used across multiple tabs
------------------------------------------------------------------------
---@diagnostic disable: undefined-global, undefined-field
local E = EverythingDelves

------------------------------------------------------------------------
-- Local references for frequently accessed globals
------------------------------------------------------------------------
local math_floor, math_max, math_min = math.floor, math.max, math.min
local string_format = string.format
local table_insert, table_remove = table.insert, table.remove
local tostring = tostring

------------------------------------------------------------------------
-- UI factory: flat dark-red button with hover highlight
------------------------------------------------------------------------
--- Create a styled button that matches the addon's visual theme.
--- @param parent Frame   Parent frame
--- @param width  number  Button width
--- @param height number  Button height
--- @param label  string  Display text
--- @return Button
function E:CreateButton(parent, width, height, label)
    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetSize(width, height)
    btn:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    local bg = E.Colors.buttonBg
    btn:SetBackdropColor(bg.r, bg.g, bg.b, bg.a)
    btn:SetBackdropBorderColor(0.55, 0, 0, 1)

    local text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetPoint("CENTER")
    text:SetFont(text:GetFont(), 11)
    text:SetText(E.CC.white .. label .. E.CC.close)
    btn.label = text

    btn:SetScript("OnEnter", function(self)
        local hc = E.Colors.buttonHover
        self:SetBackdropColor(hc.r, hc.g, hc.b, hc.a)
    end)
    btn:SetScript("OnLeave", function(self)
        local bc = E.Colors.buttonBg
        self:SetBackdropColor(bc.r, bc.g, bc.b, bc.a)
    end)

    return btn
end

------------------------------------------------------------------------
-- TomTom integration helpers
------------------------------------------------------------------------
--- Check whether the TomTom addon is available and functional.
function E:IsTomTomLoaded()
    return (TomTom and TomTom.AddWaypoint) and true or false
end

--- Add a TomTom waypoint. Returns false and prints a warning if TomTom
--- is not loaded. Coordinates are in percentage form (e.g. 45.4).
--- @param mapID number  uiMapID
--- @param x     number  percentage (0-100)
--- @param y     number  percentage (0-100)
--- @param title string  Waypoint label
function E:AddTomTomWaypoint(mapID, x, y, title)
    if not self:IsTomTomLoaded() then
        print(E.CC.header .. "Everything Delves|r: TomTom is not installed.")
        return false
    end
    TomTom:AddWaypoint(mapID, x / 100, y / 100, { title = title })
    return true
end

------------------------------------------------------------------------
-- Blizzard map waypoint helper
------------------------------------------------------------------------
--- Set a Blizzard user waypoint (the built-in map pin).
--- C_Map.SetUserWaypoint() takes a UiMapPoint table:
---   { uiMapID = number, position = { x, y } }
--- C_SuperTrack.SetSuperTrackedUserWaypoint(true) makes the waypoint
--- show as the golden navigation arrow on-screen.
--- Set a Blizzard user waypoint (the built-in map pin).
--- Coordinates are in percentage form (e.g. 45.4 means 45.4% of the map).
--- C_Map.SetUserWaypoint() expects 0-1 range, so we divide by 100.
--- @param mapID number
--- @param x     number  percentage (0-100)
--- @param y     number  percentage (0-100)
function E:SetWaypoint(mapID, x, y)
    -- C_Map.SetUserWaypoint is confirmed available in Midnight 12.0.
    if C_Map and C_Map.SetUserWaypoint then
        local ok, err = pcall(function()
            local point = UiMapPoint.CreateFromCoordinates(mapID, x / 100, y / 100)
            C_Map.SetUserWaypoint(point)
            -- Make the waypoint the actively-tracked objective
            if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then
                C_SuperTrack.SetSuperTrackedUserWaypoint(true)
            end
        end)
        if not ok then
            print("|cFFFF2222[Everything Delves]|r Could not set waypoint: " .. tostring(err))
        end
    else
        print(E.CC.header .. "Everything Delves|r: Waypoint API unavailable.")
    end
end

------------------------------------------------------------------------
-- Tooltip helpers
------------------------------------------------------------------------

--- Flash a button's label to "Done!" in green, then restore after 1.5s.
--- @param btn Button  Must have a .label FontString
function E:FlashButtonConfirm(btn)
    if not btn or not btn.label then return end
    local original = btn.label:GetText()
    btn.label:SetText("|cFF00FF00Set!|r")
    C_Timer.After(1.5, function()
        if btn.label then
            btn.label:SetText(original)
        end
    end)
end

--- Show a simple tooltip anchored to a frame.
--- @param owner    Frame
--- @param title    string
--- @param ...      string  Additional lines
function E:ShowTooltip(owner, title, ...)
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:AddLine(title, 1, 0.84, 0, true) -- gold
    for i = 1, select("#", ...) do
        local line = select(i, ...)
        if line and line ~= "" then
            GameTooltip:AddLine(line, 0.88, 0.88, 0.88, true) -- off-white, wrap
        end
    end
    GameTooltip:Show()
end

function E:HideTooltip()
    GameTooltip:Hide()
end

------------------------------------------------------------------------
-- Progress bar factory (shared by multiple tabs)
------------------------------------------------------------------------
--- Create a themed progress bar with a fill texture and centered label.
--- The returned frame has a :SetProgress(current, max) method.
--- @param parent Frame
--- @param width  number  Bar width in pixels, or 0 for anchor-based sizing
--- @param height number
--- @return Frame
function E:CreateProgressBar(parent, width, height)
    local bar = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    if width and width > 0 then
        bar:SetSize(width, height)
    else
        bar:SetHeight(height)
    end
    bar:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    bar:SetBackdropColor(0.10, 0.10, 0.10, 1)
    bar:SetBackdropBorderColor(0.30, 0.30, 0.30, 0.60)

    local fill = bar:CreateTexture(nil, "ARTWORK")
    fill:SetPoint("TOPLEFT", bar, "TOPLEFT", 1, -1)
    fill:SetHeight(height - 2)
    fill:SetColorTexture(0.55, 0, 0, 0.90)
    bar.fill = fill

    local label = bar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("CENTER")
    label:SetFont(label:GetFont(), 10, "OUTLINE")
    bar.label = label

    --- Update the bar to show current / max progress.
    function bar:SetProgress(current, max)
        local pct = (max > 0) and (current / max) or 0
        pct = math_min(pct, 1)
        self.fill:SetWidth(math_max(1, (self:GetWidth() - 2) * pct))
        self.label:SetText(
            string_format("|cFFFFFFFF%d / %d  (%d%%)|r", current, max, math_floor(pct * 100))
        )
    end

    return bar
end

------------------------------------------------------------------------
-- Sort helpers
------------------------------------------------------------------------
--- Case-insensitive string comparison for table.sort.
function E.CompareAlpha(a, b)
    return (a or ""):lower() < (b or ""):lower()
end

------------------------------------------------------------------------
-- Delve history helpers
------------------------------------------------------------------------
--- Record a delve completion in E.db.delveHistory.
--- @param delveName string
function E:RecordDelveCompletion(delveName)
    if not delveName or delveName == "" then return end
    if not self.db.delveHistory then self.db.delveHistory = {} end

    local entry = self.db.delveHistory[delveName]
    if not entry then
        entry = { completions = {}, totalRuns = 0 }
        self.db.delveHistory[delveName] = entry
    end

    local today = date("%Y-%m-%d")
    local weekNum = tonumber(date("%W")) or 0
    table_insert(entry.completions, { date = today, week = weekNum })
    entry.totalRuns = entry.totalRuns + 1

    -- Cap history to 50 most recent entries per delve
    while #entry.completions > 50 do
        table_remove(entry.completions, 1)
    end
end

--- Get history for a delve. Returns entry or nil.
--- @param delveName string
--- @return table|nil
function E:GetDelveHistory(delveName)
    if not self.db or not self.db.delveHistory then return nil end
    return self.db.delveHistory[delveName]
end
