------------------------------------------------------------------------
-- UI/MainFrame.lua
-- Main window, tab buttons, tab switching, minimap button
------------------------------------------------------------------------
local E = EverythingDelves

------------------------------------------------------------------------
-- Local references for frequently accessed globals
------------------------------------------------------------------------
local pairs, ipairs = pairs, ipairs
local math_floor = math.floor
local string_format = string.format

------------------------------------------------------------------------
-- MAIN FRAME
------------------------------------------------------------------------
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

    -- BackdropTemplate: flat near-black background, thin red 1px border
    frame:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    local bg = E.Colors.background
    local bd = E.Colors.border
    frame:SetBackdropColor(bg.r, bg.g, bg.b, bg.a)
    frame:SetBackdropBorderColor(bd.r, bd.g, bd.b, bd.a)

    -- Restore saved position or default to screen center
    if self.db.framePosition then
        local p = self.db.framePosition
        frame:SetPoint(p.point, UIParent, p.relPoint, p.x, p.y)
    else
        frame:SetPoint("CENTER")
    end

    -- Drag to move
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(f) f:StartMoving() end)
    frame:SetScript("OnDragStop", function(f)
        f:StopMovingOrSizing()
        -- Persist position so it survives /reload
        local point, _, relPoint, x, y = f:GetPoint()
        E.db.framePosition = {
            point    = point,
            relPoint = relPoint,
            x        = x,
            y        = y,
        }
    end)

    -- Let the Escape key close the window without tainting
    -- UISpecialFrames is a Blizzard global table; frames listed here
    -- automatically hide when the player presses Escape.
    table.insert(UISpecialFrames, "EverythingDelvesFrame")

    -- Hidden by default — player toggles with /ed or minimap button
    frame:Hide()

    -- Build child components
    self:CreateTitleBar(frame)
    self:CreateCloseButton(frame)
    self:CreateTabButtons(frame)
    self:CreateContentArea(frame)
    self:CreateBrokerObject()
    self:CreateMinimapButton()

    -- Run every tab module's init callback (registered via RegisterModule)
    for _, callback in ipairs(self.modules) do
        callback()
    end

    -- Open to the player's preferred default tab
    self:SelectTab(self.db.defaultTab or 1)
end

------------------------------------------------------------------------
-- TITLE BAR
------------------------------------------------------------------------
function E:CreateTitleBar(parent)
    local title = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, -10)
    title:SetFont(title:GetFont(), 16, "OUTLINE")
    title:SetText(E.CC.header .. "Everything Delves" .. E.CC.close)
    parent.titleText = title

    -- Version label in its own high-strata frame so scrollbars never cover it
    local verFrame = CreateFrame("Frame", nil, parent)
    verFrame:SetSize(80, 16)
    verFrame:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -28, -6)
    verFrame:SetFrameStrata("HIGH")
    local ver = verFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    ver:SetPoint("RIGHT")
    ver:SetText(E.CC.muted .. "v" .. E.version .. E.CC.close)
    parent.versionText = ver
end

------------------------------------------------------------------------
-- CLOSE BUTTON (custom flat "X" — no Blizzard chrome)
------------------------------------------------------------------------
function E:CreateCloseButton(parent)
    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetSize(20, 20)
    btn:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -6, -6)
    btn:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    btn:SetBackdropColor(0.30, 0, 0, 0.80)
    btn:SetBackdropBorderColor(0.55, 0, 0, 1)

    local label = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("CENTER", 0, 1)
    label:SetFont(label:GetFont(), 12, "OUTLINE")
    label:SetText("|cFFFFFFFFX|r")

    btn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(0.55, 0.05, 0.05, 1)
    end)
    btn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(0.30, 0, 0, 0.80)
    end)
    btn:SetScript("OnClick", function() parent:Hide() end)
end

------------------------------------------------------------------------
-- TAB BUTTONS
------------------------------------------------------------------------
function E:CreateTabButtons(parent)
    self.tabButtons = {}
    self.tabFrames  = {}

    local TAB_HEIGHT  = 28
    local TAB_Y       = -32   -- distance from top of the frame
    local TAB_PADDING = 4     -- gap between tabs

    -- Reusable measurement FontString for tab width calculation
    local measure = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    measure:Hide()

    for i, name in ipairs(E.TAB_NAMES) do
        local tab = CreateFrame("Button", "EverythingDelvesTab" .. i,
                                parent, "BackdropTemplate")
        tab:SetHeight(TAB_HEIGHT)

        -- Size each tab to fit its label with some horizontal padding
        measure:SetText(name)
        local textWidth = measure:GetStringWidth()
        tab:SetWidth(textWidth + 24)

        -- Anchor: first tab to frame corner, rest chain left-to-right
        if i == 1 then
            tab:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, TAB_Y)
        else
            tab:SetPoint("LEFT", self.tabButtons[i - 1], "RIGHT", TAB_PADDING, 0)
        end

        tab:SetBackdrop({
            bgFile   = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
        })

        -- Label
        local label = tab:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        label:SetPoint("CENTER")
        label:SetFont(label:GetFont(), 11)
        label:SetText(E.CC.body .. name .. E.CC.close)
        tab.label = label

        -- Default to inactive look
        local ic = E.Colors.tabInactive
        tab:SetBackdropColor(ic.r, ic.g, ic.b, ic.a)
        tab:SetBackdropBorderColor(0.25, 0.25, 0.25, 0.50)

        tab.tabIndex = i

        tab:SetScript("OnClick", function(self)
            E:SelectTab(self.tabIndex)
        end)
        tab:SetScript("OnEnter", function(self)
            if E.activeTab ~= self.tabIndex then
                self:SetBackdropColor(0.30, 0, 0, 0.80)
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

    -- Thin red horizontal divider between tab row and content
    local divider = parent:CreateTexture(nil, "ARTWORK")
    divider:SetHeight(1)
    divider:SetPoint("TOPLEFT",  parent, "TOPLEFT",  6, TAB_Y - TAB_HEIGHT - 4)
    divider:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -6, TAB_Y - TAB_HEIGHT - 4)
    local dc = E.Colors.divider
    divider:SetColorTexture(dc.r, dc.g, dc.b, dc.a)
    parent.divider = divider
end

------------------------------------------------------------------------
-- CONTENT AREA  (child frame that tab content frames anchor to)
------------------------------------------------------------------------
function E:CreateContentArea(parent)
    local content = CreateFrame("Frame", "EverythingDelvesContent", parent)
    -- Sits below the divider line, inside the main frame padding
    content:SetPoint("TOPLEFT",     parent, "TOPLEFT",      6, -68)
    content:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT",  -6,   6)
    self.contentFrame = content
end

------------------------------------------------------------------------
-- TAB REGISTRATION & SWITCHING
------------------------------------------------------------------------

--- Called by each tab module to hand its content frame to the main frame.
--- @param index number  Tab number (1-5, matching E.TAB_NAMES order)
--- @param frame Frame   The content frame for that tab
function E:RegisterTab(index, frame)
    self.tabFrames[index] = frame
    frame:SetParent(self.contentFrame)
    frame:SetAllPoints(self.contentFrame)
    frame:Hide()
end

--- Show tab `index`, hide all others, update button highlights.
function E:SelectTab(index)
    if not self.tabButtons then return end
    self.activeTab = index

    -- Update button visuals
    for i, btn in ipairs(self.tabButtons) do
        if i == index then
            local ac = E.Colors.tabActive
            btn:SetBackdropColor(ac.r, ac.g, ac.b, ac.a)
            btn:SetBackdropBorderColor(0.70, 0, 0, 1)
            btn.label:SetText(E.CC.white .. E.TAB_NAMES[i] .. E.CC.close)
        else
            local ic = E.Colors.tabInactive
            btn:SetBackdropColor(ic.r, ic.g, ic.b, ic.a)
            btn:SetBackdropBorderColor(0.25, 0.25, 0.25, 0.50)
            btn.label:SetText(E.CC.body .. E.TAB_NAMES[i] .. E.CC.close)
        end
    end

    -- Show / hide content frames
    for i, f in pairs(self.tabFrames) do
        if i == index then
            f:Show()
        else
            f:Hide()
        end
    end
end

------------------------------------------------------------------------
-- MINIMAP BUTTON — LibDBIcon (preferred) or manual fallback
------------------------------------------------------------------------

------------------------------------------------------------------------
-- Live tooltip stats (shared by broker + manual button)
------------------------------------------------------------------------
local function GetCurrencyQty(id)
    if C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo then
        local info = C_CurrencyInfo.GetCurrencyInfo(id)
        if info then return info.quantity end
    end
    return 0
end

local function AddLiveStats(tip)
    tip:AddLine(" ")
    -- Currency snapshot
    local shards = GetCurrencyQty(E.CurrencyIDs.cofferKeyShards)
    local keys   = GetCurrencyQty(E.CurrencyIDs.bountifulKeys)
    local uc     = GetCurrencyQty(E.CurrencyIDs.undercoins)
    tip:AddDoubleLine(E.CC.muted .. "Coffer Key Shards:" .. E.CC.close,
                      E.CC.gold .. shards .. E.CC.close)
    tip:AddDoubleLine(E.CC.muted .. "Bountiful Keys:" .. E.CC.close,
                      E.CC.gold .. keys .. E.CC.close)
    tip:AddDoubleLine(E.CC.muted .. "Undercoins:" .. E.CC.close,
                      E.CC.gold .. uc .. E.CC.close)

    -- Bountiful count from shared table
    if E.currentBountifulCount and E.currentBountifulCount > 0 then
        tip:AddLine(" ")
        tip:AddDoubleLine(E.CC.muted .. "Active Bountiful:" .. E.CC.close,
                          E.CC.gold .. E.currentBountifulCount .. E.CC.close)
    end

    -- Weekly reset timer
    if C_DateAndTime and C_DateAndTime.GetSecondsUntilWeeklyReset then
        local secs = C_DateAndTime.GetSecondsUntilWeeklyReset()
        if secs and secs > 0 then
            local d = math_floor(secs / 86400)
            local h = math_floor((secs % 86400) / 3600)
            local m = math_floor((secs % 3600) / 60)
            tip:AddLine(" ")
            tip:AddDoubleLine(E.CC.muted .. "Weekly Reset:" .. E.CC.close,
                              E.CC.gold .. d .. "d " .. h .. "h " .. m .. "m" .. E.CC.close)
        end
    end
end

--- Create the LibDataBroker launcher object.
--- This is always created so broker display addons (ElvUI, Titan, etc.) can use it.
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
                    E:SelectTab(5) -- Options
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

--- Attempt to register with LibDBIcon. Returns true on success.
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

--- Create the minimap button using LibDBIcon if available, otherwise fall back
--- to a manual button parented directly to the Minimap frame.
function E:CreateMinimapButton()
    if not self.db.minimapButton.show then return end

    -- Try LibDBIcon first
    if self:TryRegisterLibDBIcon() then return end

    -- Manual fallback (no LibDBIcon available)
    self.usingLibDBIcon = false

    -- Listen for LibDBIcon loading later and upgrade if possible
    local addonWatcher = CreateFrame("Frame")
    addonWatcher:RegisterEvent("ADDON_LOADED")
    addonWatcher:SetScript("OnEvent", function(watcher, event, addonName)
        if addonName == "LibDBIcon-1.0" then
            watcher:UnregisterEvent("ADDON_LOADED")
            if E:TryRegisterLibDBIcon() then
                -- Hide the manual fallback button now that LibDBIcon is active
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
    -- RegisterForClicks with the modern "Up" suffix required since 10.x
    button:RegisterForClicks("AnyUp")

    -- Main icon
    local icon = button:CreateTexture(nil, "BACKGROUND")
    icon:SetSize(20, 20)
    icon:SetPoint("CENTER")
    icon:SetTexture("Interface\\Icons\\INV_Misc_Key_15")
    button.icon = icon

    -- Circular border overlay (Blizzard tracking button asset)
    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetSize(54, 54)
    border:SetPoint("TOPLEFT")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    button.border = border

    -- Highlight on hover
    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetSize(16, 16)
    highlight:SetPoint("CENTER")
    highlight:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    button.highlight = highlight

    -- Position the button around the minimap circumference
    local function UpdateMinimapPosition(angle)
        local rad = math.rad(angle)
        local x = math.cos(rad) * 80
        local y = math.sin(rad) * 80
        button:ClearAllPoints()
        button:SetPoint("CENTER", Minimap, "CENTER", x, y)
    end

    UpdateMinimapPosition(self.db.minimapButton.angle or 220)

    -- Drag the button around the minimap edge
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

    -- Click: left = toggle window, right = open straight to Options tab
    button:SetScript("OnClick", function(self, btn)
        if btn == "LeftButton" then
            E:ToggleMainFrame()
        elseif btn == "RightButton" then
            E:ToggleMainFrame()
            if E.MainFrame:IsShown() then
                E:SelectTab(5) -- Options
            end
        end
    end)

    -- Tooltip
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

--- Show or hide the minimap button (called from Options tab).
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
