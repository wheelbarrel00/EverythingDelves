local E = EverythingDelves

local TROVE_ICON     = 1064187
local TROVE_AURA     = 1254631 -- buff spell id, active once the bounty is consumed

local frame

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

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", f, "TOP", 0, -10)
    title:SetFont(title:GetFont(), 14, "OUTLINE")
    title:SetText(
        E.CC.header
        .. "Trovehunter's Bounty Reminder"
        .. E.CC.close
    )

    local div = f:CreateTexture(nil, "ARTWORK")
    div:SetHeight(1)
    div:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -32)
    div:SetPoint("TOPRIGHT", f, "TOPRIGHT", -8, -32)
    local dc = E.Colors.divider
    div:SetColorTexture(dc.r, dc.g, dc.b, dc.a)

    local icon = f:CreateTexture(nil, "ARTWORK")
    icon:SetSize(48, 48)
    icon:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -44)
    icon:SetTexture(TROVE_ICON)

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

    local dismissBtn = E:CreateButton(f, 80, 22, "Dismiss")
    dismissBtn:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -12, 10)
    dismissBtn:SetScript("OnClick", function() f:Hide() end)

    tinsert(UISpecialFrames, "EverythingDelvesTrovehunterReminder") -- ESC closes the frame

    f:Hide()
    return f
end

function E:ShowTrovehunterReminder()
    if not frame then frame = CreateReminderFrame() end
    frame.dontShowCB:SetChecked(false)
    frame:Show()
end

function E:MaybeShowTrovehunterReminder()
    if not E.db or E.db.showTrovehunterReminder == false then return end
    local rs = E.delveRunState
    if not rs or not rs.inDelve then return end
    if rs.trovehunterPopupShown then return end
    if not rs.wasBountiful then return end

    -- Skip if >60s into the run (reminder is meant to fire early). Key off
    -- popupWindowStart (reset per world-entry), not startTime: GetTime() is
    -- continuous across /reload, so startTime would trip this on any reload.
    local windowStart = rs.popupWindowStart or rs.startTime
    if windowStart and windowStart > 0
            and (GetTime() - windowStart) > 60 then
        return
    end

    local count = E:GetTrovehunterMapCount()
    if not count or count <= 0 then return end

    local aura = C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID
        and C_UnitAuras.GetPlayerAuraBySpellID(TROVE_AURA)
    if aura then return end

    -- Defer Show by 2s so it doesn't race the loading-screen-clear / UI-settle
    -- on entry (else the frame shows then gets covered). popupShown is set only
    -- when Show actually fires, so a /reload mid-deferral doesn't strand the run.
    if E._trovehunterDeferPending then return end
    E._trovehunterDeferPending = true

    C_Timer.After(2, function()
        E._trovehunterDeferPending = false
        local rs2 = E.delveRunState
        if not rs2 or not rs2.inDelve then return end
        if rs2.trovehunterPopupShown then return end
        -- IsInInstance() returns only (isInstance, instanceType); read diffID
        -- from GetInstanceInfo() instead, or non-208 scenario delves get suppressed.
        local _, instanceType = IsInInstance()
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

local function AddBountyTooltipLine(tooltip, data)
    if not (tooltip and data and data.id) then return end
    local match = false
    for _, mapID in ipairs(E.TROVE_MAP_ITEM_IDS) do
        if data.id == mapID then match = true break end
    end
    if not match then return end

    local auraActive = C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID
        and C_UnitAuras.GetPlayerAuraBySpellID(TROVE_AURA) ~= nil

    tooltip:AddLine(" ")
    if auraActive then
        tooltip:AddLine(E.CC.green
            .. "Bounty active this week - happy looting!" .. E.CC.close)
    else
        tooltip:AddLine(E.CC.yellow
            .. "Not used yet - use it inside a Bountiful Delve." .. E.CC.close)
    end
end

if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall
        and Enum and Enum.TooltipDataType then
    TooltipDataProcessor.AddTooltipPostCall(
        Enum.TooltipDataType.Item, AddBountyTooltipLine)
end
