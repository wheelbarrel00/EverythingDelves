-- Main window: tab buttons, tab switching, broker, and minimap button.
local E = EverythingDelves

local pairs, ipairs = pairs, ipairs
local math_floor = math.floor
local string_format = string.format

function E:InitMainFrame()
    if self.MainFrame then return end

    local frame = CreateFrame("Frame", "EverythingDelvesFrame", UIParent,
                              "BackdropTemplate")
    self.MainFrame = frame

    local scale = self.db.uiScale or 1.0
    frame:SetSize(900, 650)
    frame:SetScale(scale)
    frame:SetFrameStrata("HIGH")
    frame:SetFrameLevel(100)
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:SetToplevel(true)

    frame:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    local bg = E.Colors.background
    frame:SetBackdropColor(bg.r, bg.g, bg.b, bg.a)
    E:RegisterThemed(function(p)
        frame:SetBackdropBorderColor(p.border.r, p.border.g, p.border.b, p.border.a)
    end)

    if self.db.framePosition then
        local p = self.db.framePosition
        frame:SetPoint(p.point, UIParent, p.relPoint, p.x, p.y)
    else
        frame:SetPoint("CENTER")
    end

    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(f) f:StartMoving() end)
    frame:SetScript("OnDragStop", function(f)
        f:StopMovingOrSizing()
        local point, _, relPoint, x, y = f:GetPoint()
        E.db.framePosition = {
            point    = point,
            relPoint = relPoint,
            x        = x,
            y        = y,
        }
    end)

    -- Window is built once and reused; re-apply default tab on every Show so it
    -- doesn't stick on the last-viewed tab. (Broker right-click SelectTab(8)
    -- runs after Show returns, so it still wins.)
    frame:SetScript("OnShow", function()
        E:SelectTab(E.db.defaultTab or 1)
    end)

    -- Frames in UISpecialFrames auto-hide on Escape without tainting.
    table.insert(UISpecialFrames, "EverythingDelvesFrame")

    frame:Hide()

    self:CreateTitleBar(frame)
    self:CreateCloseButton(frame)
    self:CreateTabButtons(frame)
    self:CreateContentArea(frame)
    self:CreateBrokerObject()
    self:CreateMinimapButton()

    for _, callback in ipairs(self.modules) do
        callback()
    end

    self:SelectTab(self.db.defaultTab or 1)
end

function E:CreateTitleBar(parent)
    local title = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", parent, "TOP", 0, -18)
    title:SetFont(title:GetFont(), 25, "OUTLINE")
    self:StyleAccentHeader(title, "Everything Delves")
    parent.titleText = title

    -- High-strata frame so scrollbars never cover the version label.
    local verFrame = CreateFrame("Frame", nil, parent)
    verFrame:SetSize(80, 16)
    verFrame:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -28, -6)
    verFrame:SetFrameStrata("HIGH")
    local ver = verFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    ver:SetPoint("RIGHT")
    ver:SetText(E.CC.muted .. "v" .. E.version .. E.CC.close)
    parent.versionText = ver

    -- Click pops a copyable invite (E:ShowDiscord) — WoW can't open a browser.
    local discord = CreateFrame("Button", nil, parent)
    discord:SetFrameStrata("HIGH")
    discord.icon = discord:CreateTexture(nil, "OVERLAY")
    discord.icon:SetSize(16, 16)
    discord.icon:SetPoint("LEFT", 0, 0)
    discord.icon:SetTexture("Interface\\AddOns\\EverythingDelves\\Media\\Textures\\discord.tga")
    discord.text = discord:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    discord.text:SetPoint("LEFT", discord.icon, "RIGHT", 5, 0)
    discord.text:SetText("Join our Discord!")
    discord:SetSize(16 + 5 + discord.text:GetStringWidth() + 4, 18)
    discord:SetPoint("TOPLEFT", parent, "TOPLEFT", 14, -12)
    discord:SetScript("OnClick", function() E:ShowDiscord() end)
    discord:SetScript("OnEnter", function(self)
        self.text:SetTextColor(1, 1, 1)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        local ac = E:GetAccentPreset().header
        GameTooltip:SetText("Join our Discord", ac.r, ac.g, ac.b)
        GameTooltip:AddLine("Click to copy the invite link.", 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)
    discord:SetScript("OnLeave", function(self)
        local ac = E:GetAccentPreset().header
        self.text:SetTextColor(ac.r, ac.g, ac.b)
        GameTooltip:Hide()
    end)
    E:RegisterThemed(function()
        local ac = E:GetAccentPreset().header
        discord.text:SetTextColor(ac.r, ac.g, ac.b)
    end)
    parent.discordButton = discord
end

function E:CreateCloseButton(parent)
    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetSize(20, 20)
    btn:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -6, -6)
    btn:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })

    local label = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("CENTER", 0, 1)
    label:SetFont(label:GetFont(), 12, "OUTLINE")
    label:SetText("|cFFFFFFFFX|r")

    btn:SetScript("OnEnter", function(self)
        local p = E:GetAccentPreset()
        self:SetBackdropColor(p.closeHover.r, p.closeHover.g,
                              p.closeHover.b, p.closeHover.a)
    end)
    btn:SetScript("OnLeave", function(self)
        local p = E:GetAccentPreset()
        self:SetBackdropColor(p.closeBg.r, p.closeBg.g,
                              p.closeBg.b, p.closeBg.a)
    end)
    btn:SetScript("OnClick", function() parent:Hide() end)

    E:RegisterThemed(function(p)
        btn:SetBackdropColor(p.closeBg.r, p.closeBg.g, p.closeBg.b, p.closeBg.a)
        btn:SetBackdropBorderColor(p.border.r, p.border.g, p.border.b, p.border.a)
    end)
end

function E:CreateTabButtons(parent)
    self.tabButtons = {}
    self.tabFrames  = {}

    local TAB_HEIGHT  = 28
    local TAB_Y       = -54
    local TAB_PADDING = 4
    local TAB_START_X = 10

    local rowContentWidth = 0

    local measure = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    measure:Hide()

    for i, name in ipairs(E.TAB_NAMES) do
        local tab = CreateFrame("Button", "EverythingDelvesTab" .. i,
                                parent, "BackdropTemplate")
        tab:SetHeight(TAB_HEIGHT)

        measure:SetText(name)
        local tabWidth = measure:GetStringWidth() + 24
        tab:SetWidth(tabWidth)
        rowContentWidth = rowContentWidth + tabWidth
        if i > 1 then
            rowContentWidth = rowContentWidth + TAB_PADDING
        end

        if i == 1 then
            tab:SetPoint("TOPLEFT", parent, "TOPLEFT", TAB_START_X, TAB_Y)
        else
            tab:SetPoint("LEFT", self.tabButtons[i - 1], "RIGHT", TAB_PADDING, 0)
        end

        tab:SetBackdrop({
            bgFile   = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
        })

        local label = tab:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        label:SetPoint("CENTER")
        label:SetFont(label:GetFont(), 11)
        label:SetText(E.CC.body .. name .. E.CC.close)
        tab.label = label

        local ic = E.Colors.tabInactive
        tab:SetBackdropColor(ic.r, ic.g, ic.b, ic.a)
        tab:SetBackdropBorderColor(0.25, 0.25, 0.25, 0.50)

        tab.tabIndex = i

        tab:SetScript("OnClick", function(self)
            E:SelectTab(self.tabIndex)
        end)
        tab:SetScript("OnEnter", function(self)
            if E.activeTab ~= self.tabIndex then
                local p = E:GetAccentPreset()
                self:SetBackdropColor(p.tabHover.r, p.tabHover.g,
                                      p.tabHover.b, p.tabHover.a)
            end
        end)
        tab:SetScript("OnLeave", function(self)
            if E.activeTab ~= self.tabIndex then
                local c = E.Colors.tabInactive
                self:SetBackdropColor(c.r, c.g, c.b, c.a)
            end
        end)

        self.tabButtons[i] = tab
    end

    -- Tab row can outgrow the default 900px frame width on the stock UI font;
    -- widen so the whole row fits plus a matching right margin.
    local neededWidth = TAB_START_X + rowContentWidth + TAB_START_X
    if parent:GetWidth() < neededWidth then
        parent:SetWidth(neededWidth)
    end

    local divider = parent:CreateTexture(nil, "ARTWORK")
    divider:SetHeight(1)
    divider:SetPoint("TOPLEFT",  parent, "TOPLEFT",  6, TAB_Y - TAB_HEIGHT - 4)
    divider:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -6, TAB_Y - TAB_HEIGHT - 4)
    self:StyleAccentDivider(divider)
    parent.divider = divider

    E:RegisterThemed(function(_)
        if E.activeTab then E:SelectTab(E.activeTab) end
    end)
end

function E:CreateContentArea(parent)
    local content = CreateFrame("Frame", "EverythingDelvesContent", parent)
    content:SetPoint("TOPLEFT",     parent, "TOPLEFT",      6, -90)
    content:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT",  -6,   6)
    self.contentFrame = content
end

function E:RegisterTab(index, frame)
    self.tabFrames[index] = frame
    frame:SetParent(self.contentFrame)
    frame:SetAllPoints(self.contentFrame)
    frame:Hide()
end

function E:SelectTab(index)
    if not self.tabButtons then return end
    self.activeTab = index

    local p = E:GetAccentPreset()
    for i, btn in ipairs(self.tabButtons) do
        if i == index then
            local ac = E.Colors.tabActive
            btn:SetBackdropColor(ac.r, ac.g, ac.b, ac.a)
            btn:SetBackdropBorderColor(p.tabBorder.r, p.tabBorder.g,
                                       p.tabBorder.b, p.tabBorder.a)
            btn.label:SetText(E.CC.white .. E.TAB_NAMES[i] .. E.CC.close)
        else
            local ic = E.Colors.tabInactive
            btn:SetBackdropColor(ic.r, ic.g, ic.b, ic.a)
            btn:SetBackdropBorderColor(0.25, 0.25, 0.25, 0.50)
            btn.label:SetText(E.CC.body .. E.TAB_NAMES[i] .. E.CC.close)
        end
    end

    for i, f in pairs(self.tabFrames) do
        if i == index then
            f:Show()
        else
            f:Hide()
        end
    end
end

local function GetCurrencyQty(id)
    if C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo then
        local info = C_CurrencyInfo.GetCurrencyInfo(id)
        if info then return info.quantity end
    end
    return 0
end

local function AddLiveStats(tip)
    tip:AddLine(" ")
    local shards = GetCurrencyQty(E.CurrencyIDs.cofferKeyShards)
    local keys   = GetCurrencyQty(E.CurrencyIDs.bountifulKeys)
    local uc     = GetCurrencyQty(E.CurrencyIDs.undercoins)
    tip:AddDoubleLine(E.CC.white .. "Coffer Key Shards:" .. E.CC.close,
                      E.CC.white .. shards .. E.CC.close)
    tip:AddDoubleLine(E.CC.white .. "Bountiful Keys:" .. E.CC.close,
                      E.CC.white .. keys .. E.CC.close)
    tip:AddDoubleLine(E.CC.white .. "Undercoins:" .. E.CC.close,
                      E.CC.white .. uc .. E.CC.close)

    if E.currentBountifulCount and E.currentBountifulCount > 0 then
        tip:AddLine(" ")
        tip:AddDoubleLine(E.CC.white .. "Active Bountiful:" .. E.CC.close,
                          E.CC.white .. E.currentBountifulCount .. E.CC.close)
    end

    if C_DateAndTime and C_DateAndTime.GetSecondsUntilWeeklyReset then
        local secs = C_DateAndTime.GetSecondsUntilWeeklyReset()
        if secs and secs > 0 then
            local d = math_floor(secs / 86400)
            local h = math_floor((secs % 86400) / 3600)
            local m = math_floor((secs % 3600) / 60)
            tip:AddLine(" ")
            tip:AddDoubleLine(E.CC.white .. "Weekly Reset:" .. E.CC.close,
                              E.CC.white .. d .. "d " .. h .. "h " .. m .. "m" .. E.CC.close)
        end
    end
end

function E:CreateBrokerObject()
    local LDB = LibStub and LibStub("LibDataBroker-1.1", true)
    if not LDB then return end

    self.brokerObj = LDB:NewDataObject("Everything Delves", {
        type  = "launcher",
        icon  = "Interface\\Icons\\INV_Misc_Key_15",
        label = "Everything Delves",
        OnClick = function(_, btn)
            if btn == "LeftButton" then
                E:ToggleMainFrame()
            elseif btn == "RightButton" then
                E:ToggleMainFrame()
                if E.MainFrame:IsShown() then
                    E:SelectTab(8) -- Options
                end
            end
        end,
        OnTooltipShow = function(tip)
            tip:AddLine(E.CC.header .. "Everything Delves" .. E.CC.close)
            tip:AddLine(E.CC.muted .. "Left-click: Toggle window"  .. E.CC.close)
            tip:AddLine(E.CC.muted .. "Right-click: Options"       .. E.CC.close)
            tip:AddLine(E.CC.muted .. "Drag: Reposition"           .. E.CC.close)
            AddLiveStats(tip)
        end,
    })
end

function E:TryRegisterLibDBIcon()
    local LDBIcon = LibStub and LibStub("LibDBIcon-1.0", true)
    if LDBIcon and self.brokerObj then
        self.usingLibDBIcon = true
        if not self.db.minimapButton.LibDBIcon then
            self.db.minimapButton.LibDBIcon = {}
        end
        LDBIcon:Register("EverythingDelves", self.brokerObj, self.db.minimapButton.LibDBIcon)
        return true
    end
    return false
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
    icon:SetTexture("Interface\\Icons\\INV_Misc_Key_15")
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
            E:ToggleMainFrame()
            if E.MainFrame:IsShown() then
                E:SelectTab(8) -- Options
            end
        end
    end)

    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine(E.CC.header .. "Everything Delves" .. E.CC.close)
        GameTooltip:AddLine(E.CC.muted .. "Left-click: Toggle window"  .. E.CC.close)
        GameTooltip:AddLine(E.CC.muted .. "Right-click: Options"       .. E.CC.close)
        GameTooltip:AddLine(E.CC.muted .. "Drag: Reposition"           .. E.CC.close)
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
