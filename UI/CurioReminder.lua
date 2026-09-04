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

-- Season 2 poisons are a companion choice node, not items, so they carry no bag
-- count and their icon comes from the spell rather than an item.
-- The spellIDs are seasonal. Re-derive at a season flip from the Poisons choice
-- node, whose id C_DelvesUI.GetFlavorNodeForCompanion returns live (110784 in
-- Midnight season 2), through TraitNodeXTraitNodeEntry, TraitNodeEntry and
-- TraitDefinition. Never by spell name: 1305912 and 1305914 are both named
-- "Frostheart Venom" and 1305914 carries Soulthirst Venom's icon.
local POISON_DATA = {
    { name = "Frostheart Venom", fromQuest = true, spellID = 1305912,
      note = L["Slows enemies by 30 percent and cuts their attack and cast speed by 20 percent for 10 seconds. The safest all-round pick, and the strongest one against caster packs and on Nemesis fights."] },
    { name = "Bloodcrypt Toxin", spellID = 1251120,
      note = L["Cuts enemy damage and Haste by 10 percent for 20 seconds. The pick for a blind first run, or for a boss that keeps killing you."] },
    { name = "Poison of the Forgotten Master", spellID = 1249934,
      note = L["Builds 5 percent damage every 3 seconds in combat, up to 25 percent. The highest ceiling of the six, but the stacks fall off when you take damage, so it wants a fight you already know."] },
    { name = "Soulthirst Venom", spellID = 1250826,
      note = L["Grants 10 percent Leech, Avoidance and Speed. Steady survivability that does not rely on a proc going off."] },
    { name = "Bursting Toad Toxin", fromQuest = true, spellID = 1305904,
      note = L["Struck enemies burst for Nature damage every second for 8 seconds. Best on packed trash around one tanky target."] },
    { name = "Phantasmal Spore Toxin", fromQuest = true, spellID = 1305924,
      note = L["Interrupts and fears struck enemies for 1 second."] },
}

-- Falls back to "" so an unknown or rotated id renders the line exactly as it
-- did before the icons existed.
function E.GetPoisonIconMarkup(poison, size)
    local sid = type(poison) == "table" and poison.spellID
    if not (sid and C_Spell and C_Spell.GetSpellTexture) then return "" end
    local ok, tex = pcall(C_Spell.GetSpellTexture, sid)
    if not ok or not tex then return "" end
    size = size or 12
    return "|T" .. tex .. ":" .. size .. ":" .. size .. ":0:0|t "
end

local RECOMMENDED_POISON = "Frostheart Venom"
local POISON_QUEST       = "Slithering Spoils"

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

-- Brann predates the poison slot, so nil hides the line for him.
function E:GetRecommendedPoison(companion)
    companion = companion or self.lastKnownCompanion or DEFAULT_COMPANION
    if companion ~= "Valeera" then return nil end
    for _, p in ipairs(POISON_DATA) do
        if p.name == RECOMMENDED_POISON then return p end
    end
    return POISON_DATA[1]
end

function E:GetPlayerCurioRole()
    local r = ROLE_NORM[(UnitGroupRolesAssigned
        and UnitGroupRolesAssigned("player")) or "NONE"]
    if r and r ~= "" then return r end
    local spec = GetSpecialization and GetSpecialization()
    local specRole = spec and GetSpecializationRole and GetSpecializationRole(spec)
    return ROLE_NORM[specRole or "NONE"] or "Damage"
end

local function GetCompanionTreeID()
    local D = C_DelvesUI
    if not (D and D.GetTraitTreeForCompanion) then return nil end
    local ok, treeID = pcall(D.GetTraitTreeForCompanion, nil)
    if ok and treeID and treeID ~= 0 then return treeID end
    return nil
end

-- Needs the companion panel open, and misses on any client that transliterates
-- the name. A learning source for the tree-ID map, never the sole route.
local function ScanCompanionNameText()
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

-- Caches a tree ID the table does not carry, so a rotated season stays on the
-- fast path for the session.
local learnedByTreeID = {}

-- Read live, per character. E:GetCompanionFactionID caches account-wide, so a
-- Brann-only alt would answer for a Midnight character.
local function ResolveByFaction()
    local G = C_GossipInfo
    if not (G and G.GetFriendshipReputation) then return nil end
    for _, c in ipairs(E.CompanionFactions) do
        local ok, d = pcall(G.GetFriendshipReputation, c.id)
        if ok and d and (d.friendshipFactionID or 0) > 0 then
            return c.companion
        end
    end
    return nil
end

-- Ordered most authoritative first. The panel text outranks the faction because
-- it reads the live panel, while a reputation only proves the player HAS that
-- companion. Only the panel answer is worth learning.
local function GetActiveCompanionName()
    local treeID = GetCompanionTreeID()
    if treeID then
        local byTree = E.CompanionByTraitTree[treeID] or learnedByTreeID[treeID]
        if byTree then return byTree end
    end

    local byText = ScanCompanionNameText()
    if byText then
        if treeID then learnedByTreeID[treeID] = byText end
        return byText
    end
    return ResolveByFaction()
end

-- Confirms each stored spellID still resolves to the poison it is filed under.
function E:DumpPoisonState()
    local function line(s) print("|cFFFFD700[ED poison]|r " .. s) end
    print(self.CC.header .. "Everything Delves" .. self.CC.close .. ": poison slot")
    local enUS = (GetLocale and GetLocale()) == "enUS"
    line("locale: " .. tostring(GetLocale and GetLocale()))
    line("recommended: " .. tostring(RECOMMENDED_POISON))
    for _, pd in ipairs(POISON_DATA) do
        local liveName, tex
        if C_Spell then
            if C_Spell.GetSpellName then
                local ok, n = pcall(C_Spell.GetSpellName, pd.spellID)
                liveName = ok and n or nil
            end
            if C_Spell.GetSpellTexture then
                local ok, t = pcall(C_Spell.GetSpellTexture, pd.spellID)
                tex = ok and t or nil
            end
        end
        local verdict = ""
        if enUS then
            verdict = (liveName == pd.name) and "  |cFF22FF22ok|r"
                or "  |cFFFF2222MISMATCH|r"
        end
        line(("  %d  %s"):format(pd.spellID, pd.name))
        line(("      live name: %s%s   icon: %s")
            :format(tostring(liveName), verdict, tostring(tex)))
    end
    if not enUS then
        line("names are localized off enUS, so compare the icons, not the names.")
    end
    line("a nil icon means the id is unknown here, and renders no icon.")
end

-- /ed companion - an unrecognized tree ID after a season flip names itself
-- instead of failing silently.
function E:DumpCompanionState()
    local function line(s) print("|cFFFFD700[ED companion]|r " .. s) end
    print(self.CC.header .. "Everything Delves" .. self.CC.close .. ": companion state")
    line("locale: " .. tostring(GetLocale and GetLocale()))
    local treeID = GetCompanionTreeID()
    line("treeID: " .. tostring(treeID)
        .. " -> " .. tostring(treeID and (self.CompanionByTraitTree[treeID]
            or learnedByTreeID[treeID])))
    line("by faction: " .. tostring(ResolveByFaction()))
    line("name by panel text: " .. tostring(ScanCompanionNameText()))
    line("name resolved: " .. tostring(GetActiveCompanionName()))
    line("lastKnownCompanion: " .. tostring(self.lastKnownCompanion))
    local frame = DelvesCompanionConfigurationFrame
    local infoFrame = frame and frame.CompanionInfoFrame
    if not infoFrame then
        line("companion panel not loaded - open it and run this again")
        return
    end
    for _, region in ipairs({ infoFrame:GetRegions() }) do
        if region:IsObjectType("FontString") then
            local txt = region:GetText()
            if txt and txt ~= "" then line("  panel text: " .. txt) end
        end
    end
end

E:RegisterModule(function()
    local POPUP_W   = 330
    local ICON_SZ   = 14
    local ROLE_Y    = -34   -- y of first role header relative to popup top
    local ROLE_STEP = 50    -- pixels per role section

    local numRoles  = #CURIO_DATA.Brann
    local popupHShort = math.abs(ROLE_Y) + (numRoles - 1) * ROLE_STEP + 50

    local lastRoleY    = ROLE_Y - (numRoles - 1) * ROLE_STEP
    local POISON_DIV_Y = lastRoleY - 42
    local POISON_LBL_Y = POISON_DIV_Y - 9
    local POISON_VAL_Y = POISON_LBL_Y - 15
    local popupH       = math.abs(POISON_VAL_Y) + 26

    local popup = CreateFrame("Frame", "EverythingDelvesCurioPopup", UIParent, "BackdropTemplate")
    popup:SetSize(POPUP_W, popupH)
    popup:SetFrameStrata("DIALOG")
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

    local shownCompanion

    local titleHit = CreateFrame("Frame", nil, popup)
    titleHit:SetPoint("TOPLEFT",     popup,    "TOPLEFT",  1, -1)
    titleHit:SetPoint("BOTTOMRIGHT", titleDiv, "TOPRIGHT", 0,  0)
    titleHit:EnableMouse(true)
    titleHit:SetScript("OnEnter", function(self)
        local lines = {
            L["The Combat and Utility curios your delve companion needs, listed for each role (Tank / Healer / Damage)."],
            L["Your current role is highlighted in %s with a \"%s\"."]
                :format(E.CC.gold .. L["gold"] .. E.CC.close,
                        E.CC.gold .. ">" .. E.CC.close),
            L["Slot these curios on your companion to boost her in delves."],
        }
        if E:GetRecommendedPoison(shownCompanion) then
            lines[#lines + 1] = L["Her Season 2 Poison slot is listed below the roles."]
        end
        E:ShowTooltip(self, L["Companion Curios"], unpack(lines))
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

    local poisonDiv = popup:CreateTexture(nil, "ARTWORK")
    poisonDiv:SetHeight(1)
    poisonDiv:SetPoint("TOPLEFT",  popup, "TOPLEFT",   4, POISON_DIV_Y)
    poisonDiv:SetPoint("TOPRIGHT", popup, "TOPRIGHT", -4, POISON_DIV_Y)
    E:StyleGreyLine(poisonDiv)

    local poisonLblFS = popup:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    poisonLblFS:SetPoint("TOPLEFT", popup, "TOPLEFT", 8, POISON_LBL_Y)
    poisonLblFS:SetFont(poisonLblFS:GetFont(), 10, "OUTLINE")
    poisonLblFS:SetText(E.CC.body .. L["Poison"] .. E.CC.close)

    local poisonFS = popup:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    poisonFS:SetPoint("TOPLEFT", popup, "TOPLEFT", 14, POISON_VAL_Y)
    poisonFS:SetFont(poisonFS:GetFont(), 9)

    local poisonHit = CreateFrame("Frame", nil, popup)
    poisonHit:SetPoint("TOPLEFT",     popup, "TOPLEFT",   4, POISON_LBL_Y + 2)
    poisonHit:SetPoint("BOTTOMRIGHT", popup, "TOPRIGHT", -4, POISON_VAL_Y - 14)
    poisonHit:EnableMouse(true)
    poisonHit:SetScript("OnEnter", function(self)
        local lines = {
            L["Valeera's third Season 2 slot. It does not change with the role you give her, so one pick serves every setup."],
            " ",
        }
        for _, pd in ipairs(POISON_DATA) do
            local isPick = (pd.name == RECOMMENDED_POISON)
            lines[#lines + 1] = E.GetPoisonIconMarkup(pd)
                .. (isPick and E.CC.gold or E.CC.body)
                .. pd.name .. E.CC.close
                .. (pd.fromQuest and (" " .. E.CC.muted .. "*" .. E.CC.close) or "")
            lines[#lines + 1] = E.CC.muted .. pd.note .. E.CC.close
            lines[#lines + 1] = " "
        end
        lines[#lines + 1] = E.CC.muted
            .. L["The three marked * unlock from the quest \"%s\"."]:format(POISON_QUEST)
            .. E.CC.close
        E:ShowTooltip(self, L["Poisons"], unpack(lines))
    end)
    poisonHit:SetScript("OnLeave", function() E:HideTooltip() end)

    local function Populate(companionName, dontPin)
        local rows = CURIO_DATA[companionName]
        if not rows then popup:Hide(); return end
        shownCompanion = companionName
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

        local poison = E:GetRecommendedPoison(companionName)
        poisonDiv:SetShown(poison ~= nil)
        poisonLblFS:SetShown(poison ~= nil)
        poisonFS:SetShown(poison ~= nil)
        poisonHit:SetShown(poison ~= nil)
        popup:SetHeight(poison and popupH or popupHShort)
        if poison then
            poisonFS:SetText(
                E.CC.muted .. L["Recommended:"] .. " " .. E.CC.close
                .. E.GetPoisonIconMarkup(poison, 11)
                .. E.CC.body .. poison.name .. E.CC.close)
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
        -- The auto-open path: a nil name must fall back, not bail, or the panel
        -- opens with no popup. dontPin keeps a guess out of lastKnownCompanion.
        local name = GetActiveCompanionName()
        local fromRead = name ~= nil
        name = name or E.lastKnownCompanion or DEFAULT_COMPANION
        if not CURIO_DATA[name] then name = DEFAULT_COMPANION end
        Populate(name, not fromRead)
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
            -- Keep the companion the popup was opened with. Re-resolving would
            -- swap an explicit /ed curios brann for the live one.
            if shownCompanion then
                Populate(shownCompanion, true)
            else
                ShowForCurrentCompanion()
            end
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
            -- An explicit argument is a lookup, so it must not pin lastKnownCompanion.
            fromRead = false
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
