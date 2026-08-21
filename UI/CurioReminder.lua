local E = EverythingDelves
local L = E.L

local CURIO_DATA = {
    Brann = {
        { role = "Tank",   combat = { name = "Mana-Tinted Glasses",   id = 239576 }, utility = { name = "Tailwind Conduit",        id = 239567 } },
        { role = "Healer", combat = { name = "Nether Overlay Matrix", id = 239580 }, utility = { name = "Tailwind Conduit",        id = 239567 } },
        { role = "Damage", combat = { name = "Quizzical Device",      id = 239578 }, utility = { name = "Tailwind Conduit",        id = 239567 } },
    },
    -- Season 2 and Season 1 curio IDs interleave, so never infer one from a neighbour.
    Valeera = {
        { role = "Tank",   combat = { name = "Corrosive Bilespear", id = 249223 }, utility = { name = "Soul-Cracking Dreamcatcher", id = 249228 } },
        { role = "Healer", combat = { name = "Corrosive Bilespear", id = 249223 }, utility = { name = "Soul-Cracking Dreamcatcher", id = 249228 } },
        { role = "Damage", combat = { name = "Corrosive Bilespear", id = 249223 }, utility = { name = "Soul-Cracking Dreamcatcher", id = 249228 } },
    },
}

local DEFAULT_COMPANION = "Valeera"

local ROLE_NORM = { TANK = "Tank", HEALER = "Healer", DAMAGER = "Damage", NONE = "" }

-- CURIO_DATA rows stay keyed on the English role. ROLE_LABEL is only what gets drawn.
local ROLE_LABEL = { Tank = L["Tank"], Healer = L["Healer"], Damage = L["Damage"] }

-- roleType -> ED role (0 = Damage, 1 = Healer, 2 = Tank), verified live.
local COMPANION_ROLE_BY_TYPE = { [0] = "Damage", [1] = "Healer", [2] = "Tank" }

-- Read via trait data, not the secure companion frame, to avoid taint.
function E:GetCompanionAssignedRole()
    local D, T = C_DelvesUI, C_Traits
    if not (D and T and D.GetTraitTreeForCompanion and D.GetRoleSubtreeForCompanion
        and T.GetConfigIDByTreeID and T.GetSubTreeInfo) then
        return nil, false
    end
    local treeID = D.GetTraitTreeForCompanion(nil)
    if not treeID or treeID == 0 then return nil, false end
    local configID = T.GetConfigIDByTreeID(treeID)
    if not configID or configID == 0 then return nil, false end

    local sawSubtree = false
    for roleType, edRole in pairs(COMPANION_ROLE_BY_TYPE) do
        local subID = D.GetRoleSubtreeForCompanion(roleType, nil)
        if subID and subID ~= 0 then
            local info = T.GetSubTreeInfo(configID, subID)
            if info then
                sawSubtree = true
                if info.isActive then return edRole, true end
            end
        end
    end
    return nil, sawSubtree
end

function E:GetRecommendedCurios(companion, role)
    local rows = CURIO_DATA[companion] or CURIO_DATA.Valeera
    if not rows then return nil end
    for _, row in ipairs(rows) do
        if row.role == role then return row.combat, row.utility end
    end
    return nil
end

function E:GetPlayerCurioRole()
    local r = ROLE_NORM[(UnitGroupRolesAssigned
        and UnitGroupRolesAssigned("player")) or "NONE"]
    if r and r ~= "" then return r end
    local spec = GetSpecialization and GetSpecialization()
    local specRole = spec and GetSpecializationRole and GetSpecializationRole(spec)
    return ROLE_NORM[specRole or "NONE"] or "Damage"
end

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

    local titleFS = popup:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    titleFS:SetPoint("TOPLEFT", popup, "TOPLEFT", 8, -8)
    titleFS:SetFont(titleFS:GetFont(), E.HEADER_FONT_SIZE, "OUTLINE")

    local titleDiv = popup:CreateTexture(nil, "ARTWORK")
    titleDiv:SetHeight(1)
    titleDiv:SetPoint("TOPLEFT",  popup, "TOPLEFT",  1, -26)
    titleDiv:SetPoint("TOPRIGHT", popup, "TOPRIGHT", -1, -26)
    E:StyleAccentDivider(titleDiv)

    local titleHit = CreateFrame("Frame", nil, popup)
    titleHit:SetPoint("TOPLEFT",     popup,    "TOPLEFT",  1, -1)
    titleHit:SetPoint("BOTTOMRIGHT", titleDiv, "TOPRIGHT", 0,  0)
    titleHit:EnableMouse(true)
    titleHit:SetScript("OnEnter", function(self)
        E:ShowTooltip(self, L["Companion Curios"],
            L["The Combat and Utility curios your delve companion needs, listed for each role (Tank / Healer / Damage)."],
            L["Your current role is highlighted in %s with a \"%s\"."]
                :format(E.CC.gold .. L["gold"] .. E.CC.close,
                        E.CC.gold .. ">" .. E.CC.close),
            L["Slot these curios on your companion to boost her in delves."],
            L["Season 2 also gives her a Poison slot. This popup does not cover it yet - the Nemesis tab already recommends one for Azta'rec."])
    end)
    titleHit:SetScript("OnLeave", function() E:HideTooltip() end)

    local function ShowCountTip(self)
        E:ShowTooltip(self, L["Currently in your bags"],
            L["How many of this curio you have on you right now."],
            L["%s = you have at least one."]
                :format(E.CC.green .. L["Green"] .. E.CC.close),
            L["%s = you have none yet \226\128\148 pick one up before your next delve."]
                :format(E.CC.red .. L["Red"] .. E.CC.close))
    end

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

        -- Counts get their own FontStrings so each number has its own hover zone.
        rf.combatCountFS = popup:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        rf.combatCountFS:SetPoint("LEFT", rf.combatFS, "RIGHT", 4, 0)
        rf.combatCountFS:SetFont(rf.combatCountFS:GetFont(), 9)

        rf.utilCountFS = popup:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        rf.utilCountFS:SetPoint("LEFT", rf.utilFS, "RIGHT", 4, 0)
        rf.utilCountFS:SetFont(rf.utilCountFS:GetFont(), 9)

        for _, cfs in ipairs({ rf.combatCountFS, rf.utilCountFS }) do
            local hit = CreateFrame("Frame", nil, popup)
            hit:SetPoint("LEFT", cfs, "LEFT", -3, 0)
            hit:SetSize(30, 16)
            hit:EnableMouse(true)
            hit:SetScript("OnEnter", ShowCountTip)
            hit:SetScript("OnLeave", function() E:HideTooltip() end)
        end

        if i < 3 then
            local divLine = popup:CreateTexture(nil, "ARTWORK")
            divLine:SetHeight(1)
            divLine:SetPoint("TOPLEFT",  popup, "TOPLEFT",  4, yBase - 42)
            divLine:SetPoint("TOPRIGHT", popup, "TOPRIGHT", -4, yBase - 42)
            E:StyleGreyLine(divLine)
        end

        roleRows[i] = rf
    end

    local function Populate(companionName, dontPin)
        local rows = CURIO_DATA[companionName]
        if not rows then popup:Hide(); return end
        if not dontPin then E.lastKnownCompanion = companionName end

        local role, resolved = E:GetCompanionAssignedRole()
        local myRole, noRole
        if role then
            myRole = role
        elseif resolved then
            noRole = true
        else
            myRole = E:GetPlayerCurioRole()
        end

        titleFS:SetText(E.CC.header .. L["Curios"] .. " \226\128\148 " .. companionName
            .. E.CC.close
            .. (noRole and ("  " .. E.CC.red .. L["(no role set)"] .. E.CC.close) or ""))

        for i, row in ipairs(rows) do
            local rf    = roleRows[i]
            local isMe  = (row.role == myRole)
            local nameCC = isMe and E.CC.gold or E.CC.body

            rf.labelFS:SetText(nameCC .. (isMe and "> " or "")
                .. (ROLE_LABEL[row.role] or row.role) .. E.CC.close)

            ---@diagnostic disable-next-line: deprecated
            local cCount  = (C_Item and C_Item.GetItemCount) and C_Item.GetItemCount(row.combat.id,  false) or 0
            ---@diagnostic disable-next-line: deprecated
            local uCount  = (C_Item and C_Item.GetItemCount) and C_Item.GetItemCount(row.utility.id, false) or 0
            local cCountCC = cCount > 0 and E.CC.green or E.CC.red
            local uCountCC = uCount > 0 and E.CC.green or E.CC.red

            rf.combatFS:SetText(
                E.CC.muted .. L["Combat:"] .. " "  .. E.CC.close
                .. E.CC.body .. row.combat.name  .. E.CC.close
            )
            rf.combatCountFS:SetText(cCountCC .. cCount .. E.CC.close)
            rf.utilFS:SetText(
                E.CC.muted .. L["Utility:"] .. " " .. E.CC.close
                .. E.CC.body .. row.utility.name .. E.CC.close
            )
            rf.utilCountFS:SetText(uCountCC .. uCount .. E.CC.close)

            if C_Item and C_Item.GetItemIconByID then
                rf.combatIcon:SetTexture(C_Item.GetItemIconByID(row.combat.id))
                rf.utilIcon:SetTexture(C_Item.GetItemIconByID(row.utility.id))
            end
        end
    end

    local function AnchorPopup()
        popup:ClearAllPoints()
        local cf = DelvesCompanionConfigurationFrame
        if cf and cf:IsShown() then
            -- Prefer the left of the frame; flip right when too close to the
            -- screen edge, else the popup clamps on top of the companion UI.
            local roomLeft = cf:GetLeft() or 0
            if roomLeft >= POPUP_W + 8 then
                popup:SetPoint("TOPRIGHT", cf, "TOPLEFT", -8, 0)
            else
                popup:SetPoint("TOPLEFT", cf, "TOPRIGHT", 8, 0)
            end
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

    -- Catches the frame if it was pre-loaded; ADDON_LOADED handles on-demand load.
    HookCompanionFrame()

    function E:ToggleCurioPopup(arg)
        if popup:IsShown() then
            popup:Hide()
            return
        end
        local name, fromRead
        if arg and #arg > 0 then
            name = arg:sub(1,1):upper() .. arg:sub(2):lower()
            if not CURIO_DATA[name] then
                print(E.CC.header .. "Everything Delves|r: "
                    .. L["unknown companion \"%s\". Use |cFFFFFFFFbrann|r or |cFFFFFFFFvaleera|r."]
                        :format(arg))
                return
            end
            fromRead = true
        else
            name = GetActiveCompanionName()
            fromRead = name ~= nil
            name = name or E.lastKnownCompanion or DEFAULT_COMPANION
            if not CURIO_DATA[name] then name = DEFAULT_COMPANION end
        end
        Populate(name, not fromRead)
        AnchorPopup()
        popup:Show()
    end
end)
