---@diagnostic disable: undefined-global, undefined-field
local E = EverythingDelves

local math_floor, math_max, math_min = math.floor, math.max, math.min
local string_format = string.format
local tostring = tostring

function E:CreateButton(parent, width, height, label)
    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetSize(width, height)
    btn:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })

    -- Intentionally hardcoded; buttons do not follow the accent profile.
    local bg = E.Colors.buttonBg
    btn:SetBackdropColor(bg.r, bg.g, bg.b, bg.a)
    btn:SetBackdropBorderColor(0.10, 0.00, 0.00, 1.00)

    local text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetPoint("CENTER")
    text:SetFont(text:GetFont(), 11)
    text:SetText(label)
    -- SetTextColor (not an inline |cFF code) so dim states can override it.
    text:SetTextColor(0.922, 0.718, 0.024, 1.0)
    btn.label = text

    btn:SetScript("OnEnter", function(self)
        if self.dimmed then return end
        local hc = E.Colors.buttonHover
        self:SetBackdropColor(hc.r, hc.g, hc.b, hc.a)
    end)
    btn:SetScript("OnLeave", function(self)
        if self.dimmed then return end
        local bc = E.Colors.buttonBg
        self:SetBackdropColor(bc.r, bc.g, bc.b, bc.a)
    end)

    return btn
end

function E:IsTomTomLoaded()
    return (TomTom and TomTom.AddWaypoint) and true or false
end

-- Coords are percentages (0-100); converted to 0-1 for the API.
function E:AddTomTomWaypoint(mapID, x, y, title)
    if not self:IsTomTomLoaded() then
        print(E.CC.header .. "Everything Delves|r: TomTom is not installed.")
        return false
    end
    TomTom:AddWaypoint(mapID, x / 100, y / 100, { title = title })
    return true
end

-- Coords are percentages (0-100); SetUserWaypoint expects 0-1, so we divide.
function E:SetWaypoint(mapID, x, y)
    if C_Map and C_Map.SetUserWaypoint then
        local ok, err = pcall(function()
            local point = UiMapPoint.CreateFromCoordinates(mapID, x / 100, y / 100)
            C_Map.SetUserWaypoint(point)
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

local AREA_POI_PIN = Enum.SuperTrackingMapPinType and Enum.SuperTrackingMapPinType.AreaPOI

-- Bountiful and normal entrances are separate map POIs; only the one live this
-- week resolves, so prefer the bountiful icon and fall back to the normal one.
function E:GetActiveDelvePOI(delve)
    if not (delve and C_AreaPoiInfo and C_AreaPoiInfo.GetAreaPOIInfo) then return nil end
    local function live(id)
        if not id then return false end
        local ok, info = pcall(C_AreaPoiInfo.GetAreaPOIInfo, delve.mapID, id)
        return ok and info ~= nil
    end
    if live(delve.poiID) then return delve.poiID end
    if live(delve.normalPoiID) then return delve.normalPoiID end
    return nil
end

function E:IsSuperTrackingDelve(delve)
    if not (delve and AREA_POI_PIN and C_SuperTrack and C_SuperTrack.GetSuperTrackedMapPin) then
        return false
    end
    local ok, ptype, tid = pcall(C_SuperTrack.GetSuperTrackedMapPin)
    if not ok or ptype ~= AREA_POI_PIN then return false end
    return tid == delve.poiID or tid == delve.normalPoiID
end

function E:ToggleDelveSuperTrack(delve)
    if not delve then return nil end
    if self:IsSuperTrackingDelve(delve) then
        if C_SuperTrack and C_SuperTrack.ClearSuperTrackedMapPin then
            pcall(C_SuperTrack.ClearSuperTrackedMapPin)
        end
        return "cleared"
    end
    local poi = self:GetActiveDelvePOI(delve)
    if poi and AREA_POI_PIN and C_SuperTrack and C_SuperTrack.SetSuperTrackedMapPin then
        if pcall(C_SuperTrack.SetSuperTrackedMapPin, AREA_POI_PIN, poi) then
            return "tracking"
        end
    end
    self:SetWaypoint(delve.mapID, delve.x, delve.y)
    return "waypoint"
end

E._delvePins = E._delvePins or {}

local PIN_TRACK_BORDER = { 0.16, 0.86, 0.32, 1.0 }
local PIN_TRACK_LABEL  = { 0.40, 0.92, 0.45, 1.0 }
local PIN_IDLE_BORDER  = { 0.10, 0.00, 0.00, 1.0 }
local PIN_IDLE_LABEL   = { 0.922, 0.718, 0.024, 1.0 }

function E:RefreshDelvePin(btn)
    if not (btn and btn.label) then return end
    local delve = btn._getDelve and btn._getDelve()
    if delve and self:IsSuperTrackingDelve(delve) then
        btn:SetBackdropBorderColor(unpack(PIN_TRACK_BORDER))
        btn.label:SetTextColor(unpack(PIN_TRACK_LABEL))
    else
        btn:SetBackdropBorderColor(unpack(PIN_IDLE_BORDER))
        btn.label:SetTextColor(unpack(PIN_IDLE_LABEL))
    end
end

function E:RefreshAllDelvePins()
    for btn in pairs(self._delvePins) do
        if btn:IsShown() then self:RefreshDelvePin(btn) end
    end
end

function E:WireDelvePinButton(btn, getDelve)
    btn._getDelve = getDelve
    self._delvePins[btn] = true
    btn:SetScript("OnClick", function()
        local delve = getDelve()
        if not delve then return end
        if E:ToggleDelveSuperTrack(delve) == "waypoint" then
            E:FlashButtonConfirm(btn)
        end
        E:RefreshDelvePin(btn)
    end)
    btn:SetScript("OnEnter", function(self)
        local hc = E.Colors.buttonHover
        self:SetBackdropColor(hc.r, hc.g, hc.b, hc.a)
        local delve = getDelve()
        if delve and E:IsSuperTrackingDelve(delve) then
            E:ShowTooltip(self, "Tracking This Delve",
                          "The on-screen arrow is guiding you here.",
                          E.CC.muted .. "Click to stop tracking." .. E.CC.close)
        else
            E:ShowTooltip(self, "Track This Delve",
                          "Point the on-screen arrow at this entrance.",
                          E.CC.muted .. "Click again to stop." .. E.CC.close)
        end
    end)
    btn:SetScript("OnLeave", function(self)
        local bc = E.Colors.buttonBg
        self:SetBackdropColor(bc.r, bc.g, bc.b, bc.a)
        E:HideTooltip()
    end)
    self:RefreshDelvePin(btn)
end

local superTrackFrame = CreateFrame("Frame")
superTrackFrame:RegisterEvent("SUPER_TRACKING_CHANGED")
superTrackFrame:SetScript("OnEvent", function()
    E:RefreshAllDelvePins()
end)

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

function E:ShowTooltip(owner, title, ...)
    GameTooltip:SetOwner(owner, "ANCHOR_CURSOR")
    GameTooltip:AddLine(title, 1, 0.84, 0, true)
    for i = 1, select("#", ...) do
        local line = select(i, ...)
        if line and line ~= "" then
            GameTooltip:AddLine(line, 0.88, 0.88, 0.88, true)
        end
    end
    GameTooltip:Show()
end

function E:HideTooltip()
    GameTooltip:Hide()
end

function E:CreateProgressBar(parent, width, height, caption)
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
    bar.fill = fill

    -- Accent-driven fill; a direct SetColorTexture override is repainted on the next ApplyAccentColor.
    E:RegisterThemed(function(p)
        if fill.SetColorTexture then
            fill:SetColorTexture(p.progressFill.r, p.progressFill.g,
                                 p.progressFill.b, p.progressFill.a)
        end
    end)

    local label = bar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetFont(label:GetFont(), 10, "OUTLINE")
    bar.label = label

    if caption and caption ~= "" then
        local cap = bar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        cap:SetPoint("LEFT", bar, "LEFT", 6, 0)
        cap:SetFont(cap:GetFont(), 10, "OUTLINE")
        cap:SetText("|cFFFFFFFF" .. caption .. "|r")
        bar.caption = cap

        label:SetPoint("RIGHT", bar, "RIGHT", -6, 0)
    else
        label:SetPoint("CENTER")
    end

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

-- Only 252415 is a confirmed bounty-map item; a suspected alternate (265714)
-- was ruled out by /dump. Kept as a list so a second ID can be added later.
E.TROVE_MAP_ITEM_IDS = { 252415 }

-- Bags only (not bank): the map is only usable from bags inside a delve, so a
-- banked copy must not trip the reminder.
function E:GetTrovehunterMapCount()
    if not (C_Item and C_Item.GetItemCount) then return 0 end
    local total = 0
    for _, id in ipairs(E.TROVE_MAP_ITEM_IDS) do
        ---@diagnostic disable-next-line: deprecated
        total = total + (C_Item.GetItemCount(id) or 0)
    end
    return total
end

function E:StyleAccentHeader(fs, rawText)
    if not fs or not rawText then return end
    fs:SetText(self.CC.header .. rawText .. self.CC.close)
    self:RegisterThemed(function(_)
        if fs and fs.SetText then
            fs:SetText(E.CC.header .. rawText .. E.CC.close)
        end
    end)
end

function E:StyleAccentDivider(tex)
    if not tex or not tex.SetColorTexture then return end
    local d = self.Colors.divider
    tex:SetColorTexture(d.r, d.g, d.b, d.a)
    self:RegisterThemed(function(p)
        if tex and tex.SetColorTexture then
            tex:SetColorTexture(p.divider.r, p.divider.g, p.divider.b, p.divider.a)
        end
    end)
end

-- Grey column-header separators; intentionally never themed by accent color.
function E:StyleGreyLine(tex)
    if not tex or not tex.SetColorTexture then return end
    local g = self.Colors.greyLine
    tex:SetColorTexture(g.r, g.g, g.b, g.a)
end

-- Companion progression is a friendship reputation reading "Level N". Scan the
-- friendship faction ID range and cache account-wide (invalidated on expansion
-- change) rather than hardcoding a per-expansion faction ID.
-- LIMITATION: the "Level %d" reaction match is English-only.

-- Scan descending so the newest expansion's companion wins.
local COMPANION_SCAN_FROM = 3100
local COMPANION_SCAN_TO   = 2600

local function ScanForCompanionFaction()
    if not (C_GossipInfo and C_GossipInfo.GetFriendshipReputation) then
        return nil
    end
    for id = COMPANION_SCAN_FROM, COMPANION_SCAN_TO, -1 do
        local ok, d = pcall(C_GossipInfo.GetFriendshipReputation, id)
        if ok and d and d.friendshipFactionID and d.friendshipFactionID > 0
                and type(d.reaction) == "string"
                and d.reaction:match("^Level %d+") then
            return id
        end
    end
    return nil
end

function E:GetCompanionFactionID()
    local xpac = GetAccountExpansionLevel and GetAccountExpansionLevel() or 0
    local db = self.db
    if db and db.companionFactionID and db.companionFactionXpac == xpac then
        return db.companionFactionID
    end
    local id = ScanForCompanionFaction()
    if id and db then
        db.companionFactionID   = id
        db.companionFactionXpac = xpac
    end
    return id
end

function E:GetCompanionData()
    local id = self:GetCompanionFactionID()
    if not id then return nil end
    local ok, d = pcall(C_GossipInfo.GetFriendshipReputation, id)
    if not (ok and d and d.friendshipFactionID
            and d.friendshipFactionID > 0) then
        return nil
    end

    local level = 0
    if C_GossipInfo.GetFriendshipReputationRanks then
        local ok2, ranks = pcall(
            C_GossipInfo.GetFriendshipReputationRanks, id)
        if ok2 and ranks and ranks.currentLevel then
            level = ranks.currentLevel
        end
    end
    if level == 0 and type(d.reaction) == "string" then
        level = tonumber(d.reaction:match("(%d+)")) or 0
    end

    local floor = d.reactionThreshold or 0
    local ceil  = d.nextThreshold  -- nil at max level
    return {
        name       = (d.name and d.name ~= "") and d.name or "Companion",
        level      = level,
        xpCurrent  = (d.standing or floor) - floor,
        xpMax      = ceil and math.max(1, ceil - floor) or 0,
        isMaxLevel = (ceil == nil),
    }
end

function E:StyleAccentThumb(tex)
    if not tex or not tex.SetColorTexture then return end
    self:RegisterThemed(function(p)
        if tex and tex.SetColorTexture then
            tex:SetColorTexture(p.scrollThumb.r, p.scrollThumb.g,
                                p.scrollThumb.b, p.scrollThumb.a)
        end
    end)
end

function E.CompareAlpha(a, b)
    return (a or ""):lower() < (b or ""):lower()
end

function E:GetDelveHistory(delveName)
    if not self.db or not self.db.delveHistory then return nil end
    return self.db.delveHistory[delveName]
end
