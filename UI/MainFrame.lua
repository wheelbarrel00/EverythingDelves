local E = EverythingDelves
local L = E.L

local pairs, ipairs, tostring, tonumber = pairs, ipairs, tostring, tonumber
local math_floor, math_max = math.floor, math.max
local string_format = string.format

local DELVE_ICON_ATLAS = "delves-bountiful"
local DELVE_ICON_TRIM  = 0.15
local FALLBACK_ICON    = "Interface\\Icons\\INV_Misc_Key_15"
local ED_TEXTURES      = "Interface\\AddOns\\EverythingDelves\\Media\\Textures\\"

-- MIN_HEIGHT keeps all ten pages above the at-a-glance block in the sidebar
local WIDTH, HEIGHT, MIN_WIDTH, MIN_HEIGHT = 1000, 660, 900, 540
local GLANCE_TOP, GLANCE_SIDE, GLANCE_BOTTOM, GLANCE_ROW, GLANCE_GAP = 10, 12, 12, 22, 8
local GLANCE_TICK = 60
local HINT_GAP = 4

local PAGE_ICONS = {
    E.ui:Texture("icon-map"),
    ED_TEXTURES .. "icon-key",
    E.ui:Texture("icon-stats"),
    ED_TEXTURES .. "icon-nemesis",
    ED_TEXTURES .. "icon-shard",
    E.ui:Texture("icon-history"),
    E.ui:Texture("icon-globe"),
    ED_TEXTURES .. "icon-trophy",
    ED_TEXTURES .. "icon-people",
    ED_TEXTURES .. "icon-podium",
}

-- LibDBIcon needs a file, not an atlas; resolve + inset to trim the frame.
local function GetDelveIcon()
    if C_Texture and C_Texture.GetAtlasInfo then
        local a = C_Texture.GetAtlasInfo(DELVE_ICON_ATLAS)
        if a and a.file then
            local dx = (a.rightTexCoord - a.leftTexCoord) * DELVE_ICON_TRIM
            local dy = (a.bottomTexCoord - a.topTexCoord) * DELVE_ICON_TRIM
            return a.file,
                { a.leftTexCoord + dx, a.rightTexCoord - dx,
                  a.topTexCoord + dy, a.bottomTexCoord - dy }
        end
    end
    return FALLBACK_ICON, nil
end

local function GetCurrencyQty(id)
    if C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo then
        local info = C_CurrencyInfo.GetCurrencyInfo(id)
        if info then return info.quantity end
    end
    return 0
end

local function ResetText()
    if C_DateAndTime and C_DateAndTime.GetSecondsUntilWeeklyReset then
        local secs = C_DateAndTime.GetSecondsUntilWeeklyReset()
        if secs and secs > 0 then
            return string_format(L["%dd %dh"], math_floor(secs / 86400), math_floor((secs % 86400) / 3600))
        end
    end
    return "?"
end

local function WindowDB()
    return E.db and E.db.mainWindow
end

local function HideResizeHint(f)
    local w = WindowDB()
    if w then w.resizeHintSeen = true end
    f.resizeHint:Hide()
end

local function RefreshGlance()
    local f = E.MainFrame
    if not (f and f:IsShown()) then return end
    local values = f.glance.values
    values[1]:SetText(tostring(GetCurrencyQty(E.CurrencyIDs.bountifulKeys)))
    values[2]:SetText(tostring(GetCurrencyQty(E.CurrencyIDs.cofferKeyShards)))
    values[3]:SetText(ResetText())
end

local function BuildGlance(f)
    local ui = E.ui
    local g = CreateFrame("Frame", nil, f.sidebar)
    g:SetPoint("BOTTOMLEFT")
    g:SetPoint("BOTTOMRIGHT")
    g:SetHeight(GLANCE_TOP + 3 * GLANCE_ROW + GLANCE_BOTTOM)
    ui:Paint(g, nil, "divider", "T")
    g.values = {}
    for i, label in ipairs({ L["Bountiful Keys:"], L["Coffer Key Shards:"], L["Weekly Reset:"] }) do
        local y = -(GLANCE_TOP + (i - 0.5) * GLANCE_ROW)
        local value = ui:CreateText(g, "", "value")
        value:SetPoint("RIGHT", g, "TOPRIGHT", -GLANCE_SIDE, y)
        local key = ui:CreateText(g, label, "hint")
        key:SetPoint("LEFT", g, "TOPLEFT", GLANCE_SIDE, y)
        key:SetPoint("RIGHT", value, "LEFT", -GLANCE_GAP, 0)
        key:SetWordWrap(false)
        g.values[i] = value
    end
    f.glance = g
end

function E:InitMainFrame()
    if self.MainFrame then return end
    local ui = self.ui

    local f = ui:CreateWindow({
        name = "EverythingDelvesFrame", title = "Everything Delves",
        width = WIDTH, height = HEIGHT, minWidth = MIN_WIDTH, minHeight = MIN_HEIGHT,
        sidebarWidth = ui:Spacing("sidebarWidth"), gripTip = L["Drag to resize"],
        getSize = function()
            local w = WindowDB()
            if w then return w.width, w.height end
        end,
        setSize = function(width, height)
            local w = WindowDB()
            if w then w.width, w.height = width, height end
        end,
        getMaximized = function()
            local w = WindowDB()
            return w and w.maximized or false
        end,
        setMaximized = function(on)
            local w = WindowDB()
            if w then w.maximized = on or nil end
        end,
        onResize = function(win) HideResizeHint(win) end,
    })
    self.MainFrame = f
    f:SetScale(self.db.uiScale or 1)

    f:AddHeaderButton("icon-settings", L["Options"], nil, function() E:ShowOptions() end)
    f:AddHeaderButton("icon-discord", L["Join our Discord"], L["Click to copy the invite link."],
        function() E:ShowDiscord() end)

    f.resizeHint = ui:CreateText(f.grip, L["Drag to resize"], "hint")
    f.resizeHint:SetPoint("RIGHT", f.grip, "LEFT", -HINT_GAP, 0)
    local saved = WindowDB()
    if saved and saved.resizeHintSeen then f.resizeHint:Hide() end

    local pages = {}
    for i, title in ipairs(E.TAB_NAMES) do
        pages[i] = { id = tostring(i), title = title, icon = PAGE_ICONS[i] }
    end
    f.nav = ui:CreateNav(f.sidebar, pages, function(id) E:SelectTab(tonumber(id)) end)
    BuildGlance(f)

    self.tabFrames = {}
    self.contentFrame = f.body

    f:HookScript("OnShow", function()
        E:SelectTab(E.db.defaultTab or 1)
        RefreshGlance()
        if not f.glanceTicker and C_Timer.NewTicker then
            f.glanceTicker = C_Timer.NewTicker(GLANCE_TICK, RefreshGlance)
        end
        f:Raise()
    end)
    f:HookScript("OnHide", function()
        if f.glanceTicker then
            f.glanceTicker:Cancel()
            f.glanceTicker = nil
        end
    end)
    self:RegisterCallback("CurrencyUpdate", RefreshGlance)

    self:CreateBrokerObject()
    self:CreateMinimapButton()

    for _, callback in ipairs(self.modules) do
        callback()
    end

    self:SelectTab(self.db.defaultTab or 1)
end

function E:RegisterTab(index, frame)
    self.tabFrames[index] = frame
    frame:SetParent(self.contentFrame)
    frame:SetAllPoints(self.contentFrame)
    frame:Hide()
end

function E:SelectTab(index)
    local f = self.MainFrame
    if not f then return end
    -- The page list raises on a page it lacks
    if type(index) ~= "number" or index < 1 or index > E.NUM_TABS or index % 1 ~= 0 then
        index = 1
    end
    self.activeTab = index
    f.nav:Select(tostring(index))
    f:SetSection(E.TAB_NAMES[index])
    for i, page in pairs(self.tabFrames) do
        page:SetShown(i == index)
    end
end

local function AddLiveStats(tip)
    tip:AddLine(" ")
    local shards = GetCurrencyQty(E.CurrencyIDs.cofferKeyShards)
    local keys   = GetCurrencyQty(E.CurrencyIDs.bountifulKeys)
    local uc     = GetCurrencyQty(E.CurrencyIDs.undercoins)

    local shardVal = E.CC.white .. shards .. E.CC.close
    local shardNote = false
    if E.db and E.db.showShardWeekly
            and C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo then
        local info = C_CurrencyInfo.GetCurrencyInfo(E.CurrencyIDs.cofferKeyShards)
        local cap  = (info and info.maxWeeklyQuantity) or 0
        if cap > 0 then
            local remaining = math_max(0, cap - ((info and info.quantityEarnedThisWeek) or 0))
            shardVal = shardVal .. E.CC.muted .. "/" .. remaining .. E.CC.close
            shardNote = true
        end
    end
    tip:AddDoubleLine(E.CC.white .. L["Coffer Key Shards:"] .. E.CC.close, shardVal)
    if shardNote then
        tip:AddLine(E.CC.muted .. L["owned / earnable this week"] .. E.CC.close)
    end
    tip:AddDoubleLine(E.CC.white .. L["Bountiful Keys:"] .. E.CC.close,
                      E.CC.white .. keys .. E.CC.close)
    tip:AddDoubleLine(E.CC.white .. L["Undercoins:"] .. E.CC.close,
                      E.CC.white .. uc .. E.CC.close)

    if E.currentBountifulCount and E.currentBountifulCount > 0 then
        tip:AddLine(" ")
        tip:AddDoubleLine(E.CC.white .. L["Active Bountiful:"] .. E.CC.close,
                          E.CC.white .. E.currentBountifulCount .. E.CC.close)
    end

    if C_DateAndTime and C_DateAndTime.GetSecondsUntilWeeklyReset then
        local secs = C_DateAndTime.GetSecondsUntilWeeklyReset()
        if secs and secs > 0 then
            local d = math_floor(secs / 86400)
            local h = math_floor((secs % 86400) / 3600)
            local m = math_floor((secs % 3600) / 60)
            tip:AddLine(" ")
            tip:AddDoubleLine(E.CC.white .. L["Weekly Reset:"] .. E.CC.close,
                              E.CC.white .. string_format(L["%dd %dh %dm"], d, h, m)
                              .. E.CC.close)
        end
    end
end

function E:UpdateBrokerText()
    if not self.brokerObj then return end

    local keys = GetCurrencyQty(self.CurrencyIDs.bountifulKeys)

    local shardStr = "0"
    if C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo then
        local info   = C_CurrencyInfo.GetCurrencyInfo(self.CurrencyIDs.cofferKeyShards)
        local cap    = (info and info.maxWeeklyQuantity) or 0
        local earned = (info and info.quantityEarnedThisWeek) or 0
        if cap > 0 then
            shardStr = earned .. "/" .. cap
        else
            shardStr = tostring((info and info.quantity) or 0)
        end
    end

    self.brokerObj.text = string_format(
        L["Keys: %s%d|r  Shards: %s%s|r  Reset: %s%s|r"],
        E.CC.gold, keys, E.CC.gold, shardStr, E.CC.gold, ResetText())
end

function E:CreateBrokerObject()
    local LDB = LibStub and LibStub("LibDataBroker-1.1", true)
    if not LDB then return end

    local iconTex, iconCoords = GetDelveIcon()
    self.brokerObj = LDB:NewDataObject("Everything Delves", {
        type  = "launcher",
        icon  = iconTex,
        iconCoords = iconCoords,
        label = "Everything Delves",
        OnClick = function(_, btn)
            if btn == "LeftButton" then
                E:ToggleMainFrame()
            elseif btn == "RightButton" then
                E:ToggleOptions("general")
            end
        end,
        OnTooltipShow = function(tip)
            tip:AddLine(E.CC.header .. "Everything Delves" .. E.CC.close)
            tip:AddLine(E.CC.muted .. L["Left-click: Toggle window"] .. E.CC.close)
            tip:AddLine(E.CC.muted .. L["Right-click: Options"]      .. E.CC.close)
            tip:AddLine(E.CC.muted .. L["Drag: Reposition"]          .. E.CC.close)
            AddLiveStats(tip)
        end,
    })

    self.brokerObj.text = self.brokerObj.label
    E:RegisterCallback("CurrencyUpdate", function() E:UpdateBrokerText() end)
    C_Timer.After(3, function() E:UpdateBrokerText() end)
    if C_Timer.NewTicker then
        C_Timer.NewTicker(60, function() E:UpdateBrokerText() end)
    end
end

function E:TryRegisterLibDBIcon()
    local LDBIcon = LibStub and LibStub("LibDBIcon-1.0", true)
    if LDBIcon and self.brokerObj then
        self.usingLibDBIcon = true
        if not self.db.minimapButton.LibDBIcon then
            self.db.minimapButton.LibDBIcon = {}
        end
        LDBIcon:Register("EverythingDelves", self.brokerObj, self.db.minimapButton.LibDBIcon)
        self:HardenMinimapIcon()
        return true
    end
    return false
end

local iconGuards = setmetatable({}, { __mode = "k" })

function E:HardenMinimapIcon()
    local iconTex, iconCoords = GetDelveIcon()
    if not iconCoords then return end

    local LDBIcon = LibStub and LibStub("LibDBIcon-1.0", true)
    local button = LDBIcon and LDBIcon:GetMinimapButton("EverythingDelves")
    local tex = button and button.icon
    if not tex then return end

    local reassert = iconGuards[tex]
    if not reassert then
        local left, right, top, bottom =
            iconCoords[1], iconCoords[2], iconCoords[3], iconCoords[4]
        local fixing = false
        reassert = function()
            if fixing then return end
            fixing = true
            tex:SetTexture(iconTex)
            tex:SetTexCoord(left, right, top, bottom)
            fixing = false
        end
        iconGuards[tex] = reassert
        hooksecurefunc(tex, "SetTexCoord", function(_, l, r, t, b)
            if fixing then return end
            -- LibDBIcon's own 5% mouseover inset stays inside our crop; only a
            -- collector reset wider than it (the full sheet) needs correcting.
            if not (l and r and t and b)
                    or l < left or r > right or t < top or b > bottom then
                reassert()
            end
        end)
        hooksecurefunc(tex, "SetTexture", function()
            if not fixing then reassert() end
        end)
    end
    reassert()

    if not self.iconHealFrame then
        local f = CreateFrame("Frame")
        f:RegisterEvent("PLAYER_ENTERING_WORLD")
        f:SetScript("OnEvent", function()
            C_Timer.After(0, function() E:HardenMinimapIcon() end)
        end)
        self.iconHealFrame = f
    end
end

function E:CreateMinimapButton()
    if not self.db.minimapButton.show then return end

    if self:TryRegisterLibDBIcon() then return end

    self.usingLibDBIcon = false

    -- Watch for LibDBIcon loading later and upgrade the manual button.
    local addonWatcher = CreateFrame("Frame")
    addonWatcher:RegisterEvent("ADDON_LOADED")
    addonWatcher:SetScript("OnEvent", function(watcher, event, addonName)
        if addonName == "LibDBIcon-1.0" then
            watcher:UnregisterEvent("ADDON_LOADED")
            if E:TryRegisterLibDBIcon() then
                if E.minimapBtn then
                    E.minimapBtn:Hide()
                    E.minimapBtn = nil
                end
            end
        end
    end)

    local button = CreateFrame("Button", "EverythingDelvesMinimapBtn", Minimap)
    self.minimapBtn = button

    button:SetSize(32, 32)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(8)
    button:SetClampedToScreen(true)
    button:SetMovable(true)
    button:RegisterForDrag("LeftButton")
    -- "Up" suffix required since 10.x.
    button:RegisterForClicks("AnyUp")

    local icon = button:CreateTexture(nil, "BACKGROUND")
    icon:SetSize(20, 20)
    icon:SetPoint("CENTER")
    local iconTex, iconCoords = GetDelveIcon()
    icon:SetTexture(iconTex)
    if iconCoords then
        icon:SetTexCoord(iconCoords[1], iconCoords[2], iconCoords[3], iconCoords[4])
    end
    button.icon = icon

    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetSize(54, 54)
    border:SetPoint("TOPLEFT")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    button.border = border

    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetSize(16, 16)
    highlight:SetPoint("CENTER")
    highlight:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    button.highlight = highlight

    local function UpdateMinimapPosition(angle)
        local rad = math.rad(angle)
        local x = math.cos(rad) * 80
        local y = math.sin(rad) * 80
        button:ClearAllPoints()
        button:SetPoint("CENTER", Minimap, "CENTER", x, y)
    end

    UpdateMinimapPosition(self.db.minimapButton.angle or 220)

    button:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", function(self)
            local mx, my = Minimap:GetCenter()
            local cx, cy = GetCursorPosition()
            local scale  = UIParent:GetEffectiveScale()
            cx, cy = cx / scale, cy / scale
            local angle = math.deg(math.atan2(cy - my, cx - mx))
            E.db.minimapButton.angle = angle
            UpdateMinimapPosition(angle)
        end)
    end)
    button:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
    end)

    button:SetScript("OnClick", function(self, btn)
        if btn == "LeftButton" then
            E:ToggleMainFrame()
        elseif btn == "RightButton" then
            E:ToggleOptions("general")
        end
    end)

    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine(E.CC.header .. "Everything Delves" .. E.CC.close)
        GameTooltip:AddLine(E.CC.muted .. L["Left-click: Toggle window"] .. E.CC.close)
        GameTooltip:AddLine(E.CC.muted .. L["Right-click: Options"]      .. E.CC.close)
        GameTooltip:AddLine(E.CC.muted .. L["Drag: Reposition"]          .. E.CC.close)
        AddLiveStats(GameTooltip)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
end

function E:SetMinimapButtonVisible(show)
    self.db.minimapButton.show = show
    if show then
        if self.usingLibDBIcon then
            local LDBIcon = LibStub and LibStub("LibDBIcon-1.0", true)
            if LDBIcon then
                LDBIcon:Show("EverythingDelves")
            end
        elseif not self.minimapBtn then
            self:CreateMinimapButton()
        else
            self.minimapBtn:Show()
        end
    else
        if self.usingLibDBIcon then
            local LDBIcon = LibStub and LibStub("LibDBIcon-1.0", true)
            if LDBIcon then
                LDBIcon:Hide("EverythingDelves")
            end
        elseif self.minimapBtn then
            self.minimapBtn:Hide()
        end
    end
end
