---@diagnostic disable: undefined-global, undefined-field
local E = EverythingDelves
local L = E.L

local string_format = string.format
local tostring = tostring

-- Blizzard also emits a named escape, |cnWHITE_FONT_COLOR:, which is not 8 hex
-- digits and survives a |c%x{8} strip as an invisible prefix that breaks every
-- string comparison.
function E.StripColorEscapes(s)
    if type(s) ~= "string" then return s end
    return (s:gsub("|cn[%w_]+:", "")
             :gsub("|c%x%x%x%x%x%x%x%x", "")
             :gsub("|r", ""))
end

function E:CreateButton(parent, width, height, label, extraTemplate)
    local template = extraTemplate and ("BackdropTemplate, " .. extraTemplate) or "BackdropTemplate"
    local btn = CreateFrame("Button", nil, parent, template)
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
        print(E.CC.header .. "Everything Delves|r: " .. L["TomTom is not installed."])
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
            print(E.CC.header .. "[Everything Delves]|r "
                .. string_format(L["Could not set waypoint: %s"], tostring(err)))
        end
        return ok
    end
    print(E.CC.header .. "Everything Delves|r: " .. L["Waypoint API unavailable."])
    return false
end

local AREA_POI_PIN = Enum.SuperTrackingMapPinType and Enum.SuperTrackingMapPinType.AreaPOI

-- Bountiful and normal entrances are separate map POIs, and only the one live today resolves
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
    if self:SetWaypoint(delve.mapID, delve.x, delve.y) then return "waypoint" end
    return nil
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

-- A new item id is issued each season, so watching only Season 1's meant the
-- reminder never fired in Season 2. Append, never replace, and keep it newest
-- first: [1] is the fallback when nothing is being carried.
E.TROVE_MAP_ITEM_IDS = { 274374, 252415 }

-- Rotates each season exactly like the item id. 1293799 is Midnight Season 2,
-- confirmed live off the buff; 1254631 was Season 1.
E.TROVE_AURA_IDS = { 1293799, 1254631 }

function E:GetTrovehunterAura()
    if not (C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID) then return nil end
    for _, id in ipairs(self.TROVE_AURA_IDS) do
        local ok, aura = pcall(C_UnitAuras.GetPlayerAuraBySpellID, id)
        if ok and aura then return aura, id end
    end
    return nil
end

function E:GetHeldTrovehunterItemID()
    if not (C_Item and C_Item.GetItemCount) then return nil end
    for _, id in ipairs(self.TROVE_MAP_ITEM_IDS) do
        ---@diagnostic disable-next-line: deprecated
        if (C_Item.GetItemCount(id) or 0) > 0 then return id end
    end
    return nil
end

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

-- Flagged when a bounty is used, until the weekly reset. The buff cannot tell: it drops once the next Tier 4+ Delve ends.
E.TROVE_USED_QUEST_ID = 92887
E.TROVE_LOOTED_QUEST_ID = 86371

function E:TrovehunterUsedThisWeek()
    if not (C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted) then return false end
    return C_QuestLog.IsQuestFlaggedCompleted(self.TROVE_USED_QUEST_ID) == true
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

-- Read live per character, newest companion first
function E:GetCompanionFactionID()
    local G = C_GossipInfo
    if not (G and G.GetFriendshipReputation) then return nil end
    for _, c in ipairs(self.CompanionFactions) do
        local ok, d = pcall(G.GetFriendshipReputation, c.id)
        if ok and d and (d.friendshipFactionID or 0) > 0 then return c.id, c.companion end
    end
    return nil
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

function E:GetDelveHistory(delveName)
    if not self.db or not self.db.delveHistory then return nil end
    return self.db.delveHistory[delveName]
end

-- nil means "not readable yet", which callers must not treat as rank 0.
function E.GetDelverJourneyRank()
    if not (C_DelvesUI and C_DelvesUI.GetDelvesFactionForSeason
            and C_MajorFactions and C_MajorFactions.GetMajorFactionRenownInfo) then
        return nil
    end
    local ok, factionID = pcall(C_DelvesUI.GetDelvesFactionForSeason)
    if not ok or not factionID or factionID <= 0 then return nil end
    local ok2, info = pcall(C_MajorFactions.GetMajorFactionRenownInfo, factionID)
    if not ok2 or not info then return nil end
    return info.renownLevel or 0
end

-- nil, not 0, when the read fails: 0 drives a red "chest stays locked" line.
function E.GetCurrencyQuantity(id)
    if not (id and C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo) then
        return nil
    end
    local ok, info = pcall(C_CurrencyInfo.GetCurrencyInfo, id)
    if not ok or not info then return nil end
    return info.quantity or 0
end

function E:GetCofferKeyCount()
    return E.GetCurrencyQuantity(
        self.CurrencyIDs and self.CurrencyIDs.bountifulKeys)
end

-- Four key shapes because the POI label and our own name disagree for
-- several delves.
function E:IsDelveBountifulByName(name, canonicalName)
    local cbn = self.currentBountifulNames
    if not (cbn and name) then return false end
    if cbn[name] or cbn[strtrim(name):lower()] then return true end
    if canonicalName and (cbn[canonicalName]
            or cbn[strtrim(canonicalName):lower()]) then
        return true
    end
    return false
end
