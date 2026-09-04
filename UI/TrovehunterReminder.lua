local E = EverythingDelves
local L = E.L

local TROVE_ICON     = 1064187

local frame

local function LatchShown()
    local rs = E.delveRunState
    if rs then rs.trovehunterPopupShown = true end
    if E.db and E.db.activeRun then
        E.db.activeRun.trovehunterPopupShown = true
    end
end

local function CreateReminderFrame()
    local f = CreateFrame(
        "Frame", "EverythingDelvesTrovehunterReminder",
        UIParent, "BackdropTemplate"
    )
    f:SetSize(360, 188)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 100)
    f:SetFrameStrata("DIALOG")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    -- Secure Use button makes this frame Protected, so guard moves against combat taint.
    f:SetScript("OnDragStart", function(self)
        if not InCombatLockdown() then self:StartMoving() end
    end)
    f:SetScript("OnDragStop", function(self)
        if not InCombatLockdown() then self:StopMovingOrSizing() end
    end)
    f:SetClampedToScreen(true)

    -- Protected frame can't be Shown or Hidden in combat, so defer either to combat end.
    local function RequestHide()
        if InCombatLockdown() then
            f._pendingHide = true
            f:RegisterEvent("PLAYER_REGEN_ENABLED")
        else
            f:Hide()
        end
    end
    f:SetScript("OnEvent", function(self, event)
        if event == "PLAYER_REGEN_ENABLED" then
            self:UnregisterEvent("PLAYER_REGEN_ENABLED")
            local wantHide, wantShow = self._pendingHide, self._pendingShow
            self._pendingHide, self._pendingShow = nil, nil
            if wantHide then
                self:Hide()
            elseif wantShow then
                local rs = E.delveRunState
                local auraUp = E:GetTrovehunterAura()
                if rs and rs.inDelve and not rs.trovehunterPopupShown and not auraUp then
                    E:PointUseButtonAtHeldBounty()
                    self:Show()
                    LatchShown()
                end
            end
        end
    end)

    f:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    local bg = E.Colors.background
    f:SetBackdropColor(bg.r, bg.g, bg.b, bg.a)

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", f, "TOP", 0, -10)
    title:SetFont(title:GetFont(), 14, "OUTLINE")

    local div = f:CreateTexture(nil, "ARTWORK")
    div:SetHeight(1)
    div:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -32)
    div:SetPoint("TOPRIGHT", f, "TOPRIGHT", -8, -32)

    E:RegisterThemed(function(p)
        f:SetBackdropBorderColor(p.border.r, p.border.g, p.border.b, p.border.a)
        div:SetColorTexture(p.divider.r, p.divider.g, p.divider.b, p.divider.a)
        title:SetText(p.headerCC
            .. L["Trovehunter's Bounty Reminder"]
            .. E.CC.close)
    end)

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
        .. L["Don't forget to use your Trovehunter's Bounty before completing this Delve!"]
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
        .. L["Don't show this reminder again"]
        .. E.CC.close
    )
    cb:SetScript("OnClick", function(self)
        if self:GetChecked() then
            E.db.showTrovehunterReminder = false
            RequestHide()
        else
            E.db.showTrovehunterReminder = true
        end
        if E.RefreshOptionsWidgets then E:RefreshOptionsWidgets() end
    end)
    f.dontShowCB = cb

    local dismissBtn = E:CreateButton(f, 80, 22, L["Dismiss"])
    dismissBtn:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -12, 10)
    dismissBtn:SetScript("OnClick", RequestHide)

    -- Not UISpecialFrames: its ESC path calls Hide() directly, which combat blocks once useBtn exists.
    f:EnableKeyboard(true)
    -- SetPropagateKeyboardInput is itself blocked in combat, so only toggle it out of combat.
    f:SetScript("OnKeyDown", function(self, key)
        if InCombatLockdown() then
            if key == "ESCAPE" then RequestHide() end
            return
        end
        self:SetPropagateKeyboardInput(key ~= "ESCAPE")
        if key == "ESCAPE" then RequestHide() end
    end)
    f:SetScript("OnShow", function(self)
        if not InCombatLockdown() then self:SetPropagateKeyboardInput(true) end
    end)

    f:Hide()

    -- Create after f:Hide(): a SecureActionButton child makes f Protected (unhideable in combat).
    local useBtn = E:CreateButton(f, 200, 24, L["Use Trovehunter's Bounty"],
        "SecureActionButtonTemplate")
    local function ConfigureUseButton()
        useBtn:SetSize(200, 24)
        useBtn:SetPoint("TOP", f, "TOP", 0, -104)
        -- Register both edges: SecureActionButton_OnClick only acts on the one matching the ActionButtonUseKeyDown CVar.
        useBtn:RegisterForClicks("AnyUp", "AnyDown")
        useBtn:SetAttribute("type", "macro")
        E:PointUseButtonAtHeldBounty(useBtn)
    end
    if InCombatLockdown() then
        local waiter = CreateFrame("Frame")
        waiter:RegisterEvent("PLAYER_REGEN_ENABLED")
        waiter:SetScript("OnEvent", function(self)
            self:UnregisterAllEvents()
            ConfigureUseButton()
        end)
    else
        ConfigureUseButton()
    end
    -- Hide on the up edge only, so the frame stays shown until the use fires (on either edge).
    useBtn:HookScript("PostClick", function(_, _, down)
        if not down then RequestHide() end
    end)
    f.useBtn = useBtn

    return f
end

function E:InitTrovehunterReminder()
    if not frame then frame = CreateReminderFrame() end
end

-- macrotext is a secure attribute, so this no-ops in combat. The deferred
-- show re-points it on PLAYER_REGEN_ENABLED, before the frame is shown.
function E:PointUseButtonAtHeldBounty(btn)
    btn = btn or (frame and frame.useBtn)
    if not btn or InCombatLockdown() then return end
    local id = self:GetHeldTrovehunterItemID() or self.TROVE_MAP_ITEM_IDS[1]
    btn:SetAttribute("macrotext", "/use item:" .. id)
end

function E:ShowTrovehunterReminder()
    if not frame then frame = CreateReminderFrame() end
    frame.dontShowCB:SetChecked(false)
    E:PointUseButtonAtHeldBounty()
    if InCombatLockdown() then
        frame._pendingShow = true
        frame:RegisterEvent("PLAYER_REGEN_ENABLED")
        return
    end
    frame:Show()
    LatchShown()
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

    if E:GetTrovehunterAura() then return end

    -- Latch only when the frame actually shows, so an in-combat defer keeps retrying.
    if E._trovehunterDeferPending then return end
    E._trovehunterDeferPending = true

    C_Timer.After(2, function()
        E._trovehunterDeferPending = false
        local rs2 = E.delveRunState
        if not rs2 or not rs2.inDelve then return end
        if rs2.trovehunterPopupShown then return end
        -- IsInInstance() gives only (isInstance, instanceType), so read diffID from GetInstanceInfo().
        local _, instanceType = IsInInstance()
        local _, _, diffID = GetInstanceInfo()
        if instanceType ~= "scenario" and diffID ~= 208 then return end
        if E:GetTrovehunterAura() then return end
        E:ShowTrovehunterReminder()
    end)
end

local function DiagLine(fmt, ...)
    print("  " .. string.format(fmt, ...))
end

-- Deliberately English: this is a bug-report dump, not UI.
function E:DumpTrovehunterState()
    print("|cFFFF2222Everything Delves|r: Trovehunter reminder state")

    local setting = not (self.db and self.db.showTrovehunterReminder == false)
    DiagLine("setting enabled: %s", tostring(setting))

    for _, id in ipairs(self.TROVE_MAP_ITEM_IDS) do
        local name = C_Item and C_Item.GetItemInfo and C_Item.GetItemInfo(id)
        local n = C_Item and C_Item.GetItemCount and C_Item.GetItemCount(id)
        DiagLine("known item %d: name=%s count=%s",
            id, tostring(name), tostring(n))
    end

    local found, scanned = 0, 0
    if C_Container and C_Container.GetContainerNumSlots then
        for bag = 0, 5 do
            for slot = 1, (C_Container.GetContainerNumSlots(bag) or 0) do
                scanned = scanned + 1
                local id = C_Container.GetContainerItemID(bag, slot)
                local name = id and C_Item and C_Item.GetItemInfo
                    and C_Item.GetItemInfo(id)
                if name and name:lower():find("trovehunter") then
                    found = found + 1
                    DiagLine("bag match: %s (id %d) in bag %d slot %d",
                        name, id, bag, slot)
                end
            end
        end
    end
    if found == 0 then
        DiagLine("bag match: none of %d bag slots named Trovehunter"
            .. " (English name match - a miss proves nothing on a"
            .. " translated client)", scanned)
    end

    local _, auraID = self:GetTrovehunterAura()
    DiagLine("known aura active: %s (blocks the popup)", tostring(auraID or false))

    if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
        local auraFound = 0
        for i = 1, 40 do
            local a = C_UnitAuras.GetAuraDataByIndex("player", i, "HELPFUL")
            if not a then break end
            if a.name and a.name:lower():find("trove") then
                auraFound = auraFound + 1
                DiagLine("aura match: %s (spellId %s)",
                    a.name, tostring(a.spellId))
            end
        end
        if auraFound == 0 then
            DiagLine("aura match: no buff named Trove"
                .. " (English name match, same caveat)")
        end
    end

    if C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted then
        DiagLine("quest 86371 looted=%s  quest 92887 used=%s",
            tostring(C_QuestLog.IsQuestFlaggedCompleted(86371)),
            tostring(C_QuestLog.IsQuestFlaggedCompleted(92887)))
    end

    local rs = self.delveRunState
    if not rs then
        DiagLine("run state: nil")
    else
        local ws = rs.popupWindowStart or rs.startTime or 0
        DiagLine("inDelve=%s name=%s bountiful=%s alreadyShown=%s",
            tostring(rs.inDelve), tostring(rs.delveName),
            tostring(rs.wasBountiful), tostring(rs.trovehunterPopupShown))
        DiagLine("window elapsed: %.0fs of 60 allowed",
            ws > 0 and (GetTime() - ws) or -1)
    end

    local _, instanceType = IsInInstance()
    local _, _, diffID = GetInstanceInfo()
    DiagLine("instanceType=%s difficultyID=%s (needs scenario or 208)",
        tostring(instanceType), tostring(diffID))

    print("  screenshot or paste the lines above.")
end

local function AddBountyTooltipLine(tooltip, data)
    if not (tooltip and data and data.id) then return end
    local match = false
    for _, mapID in ipairs(E.TROVE_MAP_ITEM_IDS) do
        if data.id == mapID then match = true break end
    end
    if not match then return end

    local auraActive = E:GetTrovehunterAura() ~= nil

    tooltip:AddLine(" ")
    if auraActive then
        tooltip:AddLine(E.CC.green
            .. L["Bounty active this week - happy looting!"] .. E.CC.close)
    else
        tooltip:AddLine(E.CC.yellow
            .. L["Not used yet - use it inside a Bountiful Delve."] .. E.CC.close)
    end
end

if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall
        and Enum and Enum.TooltipDataType then
    TooltipDataProcessor.AddTooltipPostCall(
        Enum.TooltipDataType.Item, AddBountyTooltipLine)
end
