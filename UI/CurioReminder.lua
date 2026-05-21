------------------------------------------------------------------------
-- UI/CurioReminder.lua — Companion Curio Reminder
-- Displays Combat and Utility curio requirements for Brann or Valeera
-- when the Companion Configuration frame is opened. Highlights the
-- player's current role. Updates bag counts on BAG_UPDATE_DELAYED.
------------------------------------------------------------------------
local E = EverythingDelves

------------------------------------------------------------------------
-- Curio data by companion and role
------------------------------------------------------------------------
local CURIO_DATA = {
    Brann = {
        { role = "Tank",   combat = { name = "Mana-Tinted Glasses",   id = 239576 }, utility = { name = "Tailwind Conduit",        id = 239567 } },
        { role = "Healer", combat = { name = "Nether Overlay Matrix", id = 239580 }, utility = { name = "Tailwind Conduit",        id = 239567 } },
        { role = "Damage", combat = { name = "Quizzical Device",      id = 239578 }, utility = { name = "Tailwind Conduit",        id = 239567 } },
    },
    Valeera = {
        { role = "Tank",   combat = { name = "Porcelain Blade Tip",   id = 257683 }, utility = { name = "Mandate of Sacred Death", id = 249225 } },
        { role = "Healer", combat = { name = "Porcelain Blade Tip",   id = 257683 }, utility = { name = "Mandate of Sacred Death", id = 249225 } },
        { role = "Damage", combat = { name = "Porcelain Blade Tip",   id = 257683 }, utility = { name = "Mandate of Sacred Death", id = 249225 } },
    },
}

local ROLE_NORM = { TANK = "Tank", HEALER = "Healer", DAMAGER = "Damage", NONE = "" }

------------------------------------------------------------------------
-- Detect which companion is shown in the configuration frame by
-- scanning its FontStrings for the companion's name.
------------------------------------------------------------------------
local function GetActiveCompanionName()
    if not DelvesCompanionConfigurationFrame then return nil end
    local infoFrame = DelvesCompanionConfigurationFrame.CompanionInfoFrame
    if not infoFrame then return nil end
    for _, region in ipairs({ infoFrame:GetRegions() }) do
        if region:IsObjectType("FontString") then
            local txt = region:GetText()
            if txt then
                if txt:find("Brann")   then return "Brann"   end
                if txt:find("Valeera") then return "Valeera" end
            end
        end
    end
    return nil
end

------------------------------------------------------------------------
-- MODULE INIT
------------------------------------------------------------------------
E:RegisterModule(function()
    local POPUP_W   = 330
    local ICON_SZ   = 14
    local ROLE_Y    = -34   -- y of first role header relative to popup top
    local ROLE_STEP = 50    -- pixels per role section

    local numRoles  = #CURIO_DATA.Brann
    local popupH    = math.abs(ROLE_Y) + (numRoles - 1) * ROLE_STEP + 50

    local popup = CreateFrame("Frame", "EverythingDelvesCurioPopup", UIParent, "BackdropTemplate")
    popup:SetSize(POPUP_W, popupH)
    popup:SetFrameStrata("HIGH")
    popup:SetClampedToScreen(true)
    popup:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    local bg = E.Colors.background
    popup:SetBackdropColor(bg.r, bg.g, bg.b, 1.0)
    E:RegisterThemed(function(p)
        popup:SetBackdropBorderColor(p.border.r, p.border.g, p.border.b, p.border.a)
    end)
    popup:Hide()

    -- Title
    local titleFS = popup:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    titleFS:SetPoint("TOPLEFT", popup, "TOPLEFT", 8, -8)
    titleFS:SetFont(titleFS:GetFont(), E.HEADER_FONT_SIZE, "OUTLINE")

    local titleDiv = popup:CreateTexture(nil, "ARTWORK")
    titleDiv:SetHeight(1)
    titleDiv:SetPoint("TOPLEFT",  popup, "TOPLEFT",  1, -26)
    titleDiv:SetPoint("TOPRIGHT", popup, "TOPRIGHT", -1, -26)
    E:StyleAccentDivider(titleDiv)

    -- Build one set of UI rows for the 3 roles (reused for both companions)
    local roleRows = {}
    for i = 1, 3 do
        local yBase = ROLE_Y - (i - 1) * ROLE_STEP
        local rf    = {}

        rf.labelFS = popup:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        rf.labelFS:SetPoint("TOPLEFT", popup, "TOPLEFT", 8, yBase)
        rf.labelFS:SetFont(rf.labelFS:GetFont(), 10, "OUTLINE")

        rf.combatIcon = popup:CreateTexture(nil, "ARTWORK")
        rf.combatIcon:SetSize(ICON_SZ, ICON_SZ)
        rf.combatIcon:SetPoint("TOPLEFT", popup, "TOPLEFT", 14, yBase - 15)

        rf.combatFS = popup:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        rf.combatFS:SetPoint("LEFT", rf.combatIcon, "RIGHT", 3, 0)
        rf.combatFS:SetFont(rf.combatFS:GetFont(), 9)

        rf.utilIcon = popup:CreateTexture(nil, "ARTWORK")
        rf.utilIcon:SetSize(ICON_SZ, ICON_SZ)
        rf.utilIcon:SetPoint("TOPLEFT", popup, "TOPLEFT", 14, yBase - 31)

        rf.utilFS = popup:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        rf.utilFS:SetPoint("LEFT", rf.utilIcon, "RIGHT", 3, 0)
        rf.utilFS:SetFont(rf.utilFS:GetFont(), 9)

        if i < 3 then
            local divLine = popup:CreateTexture(nil, "ARTWORK")
            divLine:SetHeight(1)
            divLine:SetPoint("TOPLEFT",  popup, "TOPLEFT",  4, yBase - 42)
            divLine:SetPoint("TOPRIGHT", popup, "TOPRIGHT", -4, yBase - 42)
            E:StyleGreyLine(divLine)
        end

        roleRows[i] = rf
    end

    --------------------------------------------------------------------
    -- Fill all three role rows for the given companion
    --------------------------------------------------------------------
    local function Populate(companionName)
        local rows = CURIO_DATA[companionName]
        if not rows then popup:Hide(); return end

        titleFS:SetText(E.CC.header .. "Curios \226\128\148 " .. companionName .. E.CC.close)

        local myRole = ROLE_NORM[UnitGroupRolesAssigned and UnitGroupRolesAssigned("player") or "NONE"] or ""

        for i, row in ipairs(rows) do
            local rf    = roleRows[i]
            local isMe  = (row.role == myRole)
            local nameCC = isMe and E.CC.gold or E.CC.body

            rf.labelFS:SetText(nameCC .. (isMe and "> " or "") .. row.role .. E.CC.close)

            ---@diagnostic disable-next-line: deprecated
            local cCount  = (C_Item and C_Item.GetItemCount) and C_Item.GetItemCount(row.combat.id,  false) or 0
            ---@diagnostic disable-next-line: deprecated
            local uCount  = (C_Item and C_Item.GetItemCount) and C_Item.GetItemCount(row.utility.id, false) or 0
            local cCountCC = cCount > 0 and E.CC.green or E.CC.red
            local uCountCC = uCount > 0 and E.CC.green or E.CC.red

            rf.combatFS:SetText(
                E.CC.muted .. "Combat: "  .. E.CC.close
                .. E.CC.body .. row.combat.name  .. E.CC.close
                .. "  " .. cCountCC .. cCount .. E.CC.close
            )
            rf.utilFS:SetText(
                E.CC.muted .. "Utility: " .. E.CC.close
                .. E.CC.body .. row.utility.name .. E.CC.close
                .. "  " .. uCountCC .. uCount .. E.CC.close
            )

            if C_Item and C_Item.GetItemIconByID then
                rf.combatIcon:SetTexture(C_Item.GetItemIconByID(row.combat.id))
                rf.utilIcon:SetTexture(C_Item.GetItemIconByID(row.utility.id))
            end
        end
    end

    local function AnchorPopup()
        popup:ClearAllPoints()
        if DelvesCompanionConfigurationFrame and DelvesCompanionConfigurationFrame:IsShown() then
            popup:SetPoint("TOPRIGHT", DelvesCompanionConfigurationFrame, "TOPLEFT", -8, 0)
        else
            popup:SetPoint("CENTER", UIParent, "CENTER", -320, 0)
        end
    end

    local function ShowForCurrentCompanion()
        local name = GetActiveCompanionName()
        if not name then return end
        Populate(name)
        AnchorPopup()
        popup:Show()
    end

    local hooked = false
    local function HookCompanionFrame()
        if hooked or not DelvesCompanionConfigurationFrame then return end
        hooked = true
        DelvesCompanionConfigurationFrame:HookScript("OnShow", ShowForCurrentCompanion)
        DelvesCompanionConfigurationFrame:HookScript("OnHide", function() popup:Hide() end)
    end

    --------------------------------------------------------------------
    -- Event handling
    --------------------------------------------------------------------
    local ef = CreateFrame("Frame")
    ef:RegisterEvent("BAG_UPDATE_DELAYED")
    ef:RegisterEvent("ADDON_LOADED")
    ef:SetScript("OnEvent", function(_, event, arg1)
        if event == "ADDON_LOADED" and arg1 == "Blizzard_DelvesCompanionConfiguration" then
            HookCompanionFrame()
        elseif event == "BAG_UPDATE_DELAYED" and popup:IsShown() then
            ShowForCurrentCompanion()
        end
    end)

    -- Hook immediately — this module init runs during PLAYER_LOGIN, so
    -- DelvesCompanionConfigurationFrame exists if it was pre-loaded.
    -- ADDON_LOADED above catches it if it loads on-demand later.
    HookCompanionFrame()

    --------------------------------------------------------------------
    -- Public toggle called by the /ed curios slash handler
    -- (registered in EverythingDelves.lua)
    --------------------------------------------------------------------
    function E:ToggleCurioPopup(arg)
        if popup:IsShown() then
            popup:Hide()
            return
        end
        local name = (arg and #arg > 0)
            and (arg:sub(1,1):upper() .. arg:sub(2):lower())
            or "Brann"
        if not CURIO_DATA[name] then
            print(E.CC.header .. "Everything Delves|r: unknown companion \""
                .. arg .. "\". Use |cFFFFFFFFbrann|r or |cFFFFFFFFvaleera|r.")
            return
        end
        Populate(name)
        AnchorPopup()
        popup:Show()
    end
end)
