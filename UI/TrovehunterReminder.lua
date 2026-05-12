------------------------------------------------------------------------
-- UI/TrovehunterReminder.lua
-- Floating reminder popup shown on entry to a Bountiful Delve when the
-- player has an unused Trovehunter's Bounty Map in bags and the
-- consumed-bounty aura is not active. The original spec gated this on
-- "tier 8+" but reliable tier detection inside a delve is fragile, and
-- in practice nobody who has a map is running sub-T8 delves anyway, so
-- the tier requirement was dropped in favour of the simpler rule.
------------------------------------------------------------------------
local E = EverythingDelves

local TROVE_MAP_ITEM = 252415  -- map item id (bag check)
local TROVE_ICON     = 1064187 -- texture id
local TROVE_AURA     = 1254631 -- buff spell id (active when consumed)

local frame  -- created lazily on first show

local function CreateReminderFrame()
    local f = CreateFrame(
        "Frame", "EverythingDelvesTrovehunterReminder",
        UIParent, "BackdropTemplate"
    )
    f:SetSize(360, 170)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 100)
    f:SetFrameStrata("DIALOG")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetClampedToScreen(true)

    f:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    local bg = E.Colors.background
    f:SetBackdropColor(bg.r, bg.g, bg.b, bg.a)
    local bd = E.Colors.border
    f:SetBackdropBorderColor(bd.r, bd.g, bd.b, bd.a)

    -- Title
    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", f, "TOP", 0, -10)
    title:SetFont(title:GetFont(), 14, "OUTLINE")
    title:SetText(
        E.CC.header
        .. "Trovehunter's Bounty Reminder"
        .. E.CC.close
    )

    -- Divider under title
    local div = f:CreateTexture(nil, "ARTWORK")
    div:SetHeight(1)
    div:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -32)
    div:SetPoint("TOPRIGHT", f, "TOPRIGHT", -8, -32)
    local dc = E.Colors.divider
    div:SetColorTexture(dc.r, dc.g, dc.b, dc.a)

    -- Item icon
    local icon = f:CreateTexture(nil, "ARTWORK")
    icon:SetSize(48, 48)
    icon:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -44)
    icon:SetTexture(TROVE_ICON)

    -- Body text (right of icon)
    local body = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    body:SetPoint("TOPLEFT", icon, "TOPRIGHT", 12, 0)
    body:SetPoint("RIGHT", f, "RIGHT", -16, 0)
    body:SetHeight(48)
    body:SetJustifyH("LEFT")
    body:SetJustifyV("TOP")
    body:SetFont(body:GetFont(), 12)
    body:SetText(
        E.CC.body
        .. "Don't forget to use your Trovehunter's Bounty before completing this Delve!"
        .. E.CC.close
    )
    body:SetWordWrap(true)

    -- "Don't show this reminder again" checkbox (bottom-left)
    local cb = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
    cb:SetSize(20, 20)
    cb:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 12, 12)
    local cbLabel = cb:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    cbLabel:SetPoint("LEFT", cb, "RIGHT", 4, 0)
    cbLabel:SetFont(cbLabel:GetFont(), 11)
    cbLabel:SetText(
        E.CC.muted
        .. "Don't show this reminder again"
        .. E.CC.close
    )
    cb:SetScript("OnClick", function(self)
        if self:GetChecked() then
            E.db.showTrovehunterReminder = false
            f:Hide()
        else
            E.db.showTrovehunterReminder = true
        end
    end)
    f.dontShowCB = cb

    -- Dismiss button (bottom-right)
    local dismissBtn = E:CreateButton(f, 80, 22, "Dismiss")
    dismissBtn:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -12, 10)
    dismissBtn:SetScript("OnClick", function() f:Hide() end)

    -- ESC closes the frame
    tinsert(UISpecialFrames, "EverythingDelvesTrovehunterReminder")

    f:Hide()
    return f
end

--- Show the trovehunter reminder popup unconditionally. Used by the
--- Maybe* gate below and available for manual testing.
function E:ShowTrovehunterReminder()
    if not frame then frame = CreateReminderFrame() end
    frame.dontShowCB:SetChecked(false)
    frame:Show()
end

--- Evaluate every condition and show the popup only if all pass.
--- Called after delve tier is captured. Idempotent within a single
--- run via runState.trovehunterPopupShown (also persisted to
--- E.db.activeRun so /reload mid-delve does not re-trigger it).
function E:MaybeShowTrovehunterReminder()
    if not E.db or E.db.showTrovehunterReminder == false then return end
    local rs = E.delveRunState
    if not rs or not rs.inDelve then return end
    if rs.trovehunterPopupShown then return end
    if not rs.wasBountiful then return end

    -- Late-firing guard: if more than 60 seconds have elapsed since
    -- entry, the player is already deep into the run and the reminder
    -- is no longer useful (would just feel like a popup-on-exit bug).
    -- Skip it. The popup is meant to fire early.
    if rs.startTime and rs.startTime > 0
            and (GetTime() - rs.startTime) > 60 then
        return
    end

    local count = C_Item.GetItemCount(TROVE_MAP_ITEM)
    if not count or count <= 0 then return end

    local aura = C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID
        and C_UnitAuras.GetPlayerAuraBySpellID(TROVE_AURA)
    if aura then return end

    -- All conditions met. Defer the actual Show by 2 seconds so the
    -- popup doesn't race the loading-screen-clear / UI-settle period
    -- on delve entry. Previously the Show was called fast enough that
    -- the frame appeared (and immediately got covered) before the
    -- player's UI was visible, leading to "popup never appears even
    -- though popupShown=true is set" reports. The deferred design
    -- also delays setting popupShown until the Show actually fires,
    -- so a /reload mid-deferral doesn't strand the run with a stuck
    -- flag and no popup.
    if E._trovehunterDeferPending then return end
    E._trovehunterDeferPending = true

    C_Timer.After(2, function()
        E._trovehunterDeferPending = false
        local rs2 = E.delveRunState
        if not rs2 or not rs2.inDelve then return end
        if rs2.trovehunterPopupShown then return end
        local _, _, instanceType = IsInInstance()
        local _, _, diffID = GetInstanceInfo()
        if instanceType ~= "scenario" and diffID ~= 208 then return end
        local nowAura = C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID
            and C_UnitAuras.GetPlayerAuraBySpellID(TROVE_AURA)
        if nowAura then return end
        rs2.trovehunterPopupShown = true
        if E.db and E.db.activeRun then
            E.db.activeRun.trovehunterPopupShown = true
        end
        E:ShowTrovehunterReminder()
    end)
end
