local E = EverythingDelves
local L = E.L

local ipairs, tostring = ipairs, tostring

-- Spell, item, achievement and place names are read by ID, with English fallbacks
local ERUPTION, HEADHUNTERS, AXES, CRUSHING = 1301288, 1298647, 1300768, 1299117
local ERRATIC_MOJO, AXE_BARRAGE, DISGRACE, PHALANX, AEGIS = 1300767, 1298765, 1303494, 1298834, 1301380
local STORM, GAMBIT, RAMPAGE, CLEANSING = 1300374, 1300064, 1300045, 1299249
local TOAD_TOXIN = 1305904
local BLOODLUST, HEROISM = 2825, 32182
-- Sub-zones of the Labyrinth (AreaTable)
local ROOST, RITES, LAIR, TOWERS = 17031, 17025, 17029, 17033
local BILESPEAR, OUROBORIC, DREAMCATCHER = 249223, 249219, 249228
-- The First Hash'ey's own icon, for a client that has not sent the achievement yet
local PORTRAIT_ICON = 3601564

local TAG_COLORS = { red = "FF3333", yellow = "FFD100", orange = "FF8800", grey = "999999" }

local PHASE_ONE = {
    { id = ERUPTION, en = "Eruption of Mojo", tag = L["Dodge"], color = "orange" },
    { id = HEADHUNTERS, en = "Hash'ey's Command", tag = L["Adds"], color = "grey" },
    { id = AXES, en = "Whirling Axes", tag = L["Dodge"], color = "orange" },
    { id = CRUSHING, en = "Crushing Blow", tag = L["Kill first"], color = "red" },
}

local INTERMISSION = {
    { id = STORM, en = "De Rising Storm", loa = L["Akil'zon"], tag = L["Find the gap"], color = "orange",
      text = L["Wind pulses out from the middle in wide slices that kill outright. Stand in one of the small gaps between them."] },
    { id = GAMBIT, en = "Gambit in de Shadows", loa = L["Halazzi"], tag = L["Protect Valeera"], color = "yellow",
      text = L["Four Shadows of Halazzi circle Valeera. Stand in the line between her and the true one, the Shadow carrying her target marker, or she is stunned."] },
    { id = RAMPAGE, en = "Ursine Rampage", loa = L["Nalorakk"], tag = L["Find the gap"], color = "orange",
      text = L["Lines of bears charge in from the edges. Go through the gaps, or you are knocked off the platform."] },
    { id = CLEANSING, en = "Cleansing Flame", loa = L["Jan'alai"], tag = L["Soak"], color = "yellow",
      text = L["Two sigils land. Valeera marks the one she takes, so stand in the other. A sigil nobody stands in burns the whole platform."] },
}

local function SpellName(id, fallback)
    local name = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(id)
    return (type(name) == "string" and name ~= "") and name or fallback
end

local function AreaName(id, fallback)
    local name = C_Map and C_Map.GetAreaInfo and C_Map.GetAreaInfo(id)
    return (type(name) == "string" and name ~= "") and name or fallback
end

local function ItemName(id, fallback)
    local name = C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(id)
    if name and name ~= "" then return name end
    if C_Item and C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(id) end
    return fallback
end

local function ItemIcon(id)
    return C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(id) or nil
end

local function Achievement(id)
    if not GetAchievementInfo then return nil end
    local ok, _, name, _, done, _, _, _, _, _, icon, reward = pcall(GetAchievementInfo, id)
    if not (ok and name) then return nil end
    return name, done and true or false, icon, reward
end

local function PhaseOneText(id)
    if id == ERUPTION then
        return L["Circles erupt around you. Step out of them. The big one roots you for 5 seconds, and each eruption leaves a %s puddle, so drop them near the edge."]
            :format(SpellName(ERRATIC_MOJO, "Erratic Mojo"))
    elseif id == HEADHUNTERS then
        return L["Four headhunters throw %s circles at you. These do not add %s stacks. Kill them if your health is running low."]
            :format(SpellName(AXE_BARRAGE, "Axe Barrage"), SpellName(DISGRACE, "Disgraceful Display"))
    elseif id == AXES then
        return L["Four rings of spinning axes sweep in arcs around the platform. Watch where each one starts and step aside."]
    end
    return L["A heavy slam in front of him, then a juggernaut that cannot be crowd controlled. It charges you toward the edge with %s and shields its allies with %s. Stand near the middle, kill it first, and interrupt the shield when you can."]
        :format(SpellName(PHALANX, "Phalanx Charge"), SpellName(AEGIS, "Amani Aegis"))
end

local function BuildHero(ui, content, kit, k)
    local LAB = E.Labyrinth
    local card = ui:CreateGroup(content, nil)
    local hero = kit.Row(content, kit.PORTRAIT)
    hero.portrait = hero:CreateTexture(nil, "ARTWORK")
    hero.portrait:SetSize(kit.PORTRAIT, kit.PORTRAIT)
    hero.portrait:SetPoint("LEFT")
    if hero.portrait.SetMask then pcall(hero.portrait.SetMask, hero.portrait, kit.PORTRAIT_MASK) end

    hero.tt = E.DelveList.IconButton(hero, kit.ED_TEXTURES .. "icon-tomtom")
    hero.tt:SetPoint("RIGHT")
    hero.pin = E.DelveList.IconButton(hero, ui:Texture("icon-map"))
    hero.pin:SetPoint("RIGHT", hero.tt, "LEFT", -kit.BUTTON_GAP, 0)

    hero.name = ui:CreateText(hero, L["Kindo'jan"], "title")
    hero.name:SetPoint("TOPLEFT", hero.portrait, "TOPRIGHT", kit.ITEM_GAP, -2)
    hero.place = ui:CreateText(hero, "", "label")
    hero.place:SetTextColor(ui:Color("muted"))
    hero.place:SetWordWrap(false)
    hero.place:SetPoint("BOTTOMLEFT", hero.name, "BOTTOMRIGHT", 6, 0)
    hero.place:SetPoint("RIGHT", hero.pin, "LEFT", -kit.ITEM_GAP, 0)
    hero.sub = ui:CreateText(hero, "", "hint")
    hero.sub:SetWordWrap(false)
    hero.sub:SetPoint("TOPLEFT", hero.name, "BOTTOMLEFT", 0, -2)
    hero.sub:SetPoint("RIGHT", hero.pin, "LEFT", -kit.ITEM_GAP, 0)

    hero.pin:SetScript("OnClick", function(self)
        if E:SetWaypoint(LAB.mapID, LAB.x, LAB.y) then E.DelveList.Flash(self) end
    end)
    hero.pin:SetScript("OnEnter", function(self)
        ui:ShowTooltip(self, L["Set Waypoint"], L["Pin the Labyrinth's entrance on your map."])
    end)
    hero.pin:SetScript("OnLeave", function() ui:HideTooltip() end)
    hero.tt:SetScript("OnClick", function(self)
        if E:IsTomTomLoaded() and E:AddTomTomWaypoint(LAB.mapID, LAB.x, LAB.y, E.LabyrinthDisplayName()) then
            E.DelveList.Flash(self)
        end
    end)
    hero.tt:SetScript("OnEnter", function(self)
        if E:IsTomTomLoaded() then
            ui:ShowTooltip(self, L["TomTom Waypoint"], L["Add a TomTom arrow to the Labyrinth's entrance."])
        else
            ui:ShowTooltip(self, L["TomTom Not Installed"], L["Install the TomTom addon to use arrow waypoints."])
        end
    end)
    hero.tt:SetScript("OnLeave", function() ui:HideTooltip() end)

    card:Add(hero, { height = kit.PORTRAIT + kit.HERO_PAD * 2, fill = true })
    k.hero = hero
    return card
end

local function StatusRow(ui, content, kit, label, style)
    local row = kit.Row(content, kit.ROW)
    row.label = ui:CreateText(row, label, "label")
    row.label:SetPoint("LEFT")
    row.label:SetWordWrap(false)
    row.value = ui:CreateText(row, "", style or "value")
    row.value:SetWordWrap(false)
    row.value:SetJustifyH("RIGHT")
    row.value:SetPoint("LEFT", row.label, "RIGHT", kit.ITEM_GAP, 0)
    row.value:SetPoint("RIGHT")
    return row
end

local function BuildStatus(ui, content, kit, k)
    local card = ui:CreateGroup(content, nil)
    k.kills = StatusRow(ui, content, kit, L["Kills"])
    k.first = StatusRow(ui, content, kit, "")
    k.first.check = kit.Check(ui, k.first)
    k.first.check:SetPoint("RIGHT")
    k.first.value:SetTextColor(ui:Color("muted"))
    k.weekly = StatusRow(ui, content, kit, L["This week's reward"], "hint")
    k.weekly.check = kit.Check(ui, k.weekly)
    k.weekly.check:SetPoint("RIGHT")
    for _, row in ipairs({ k.kills, k.first, k.weekly }) do card:Add(row, { height = kit.ROW, fill = true }) end
    return card
end

local function BuildOverview(ui, content, kit)
    local card = ui:CreateGroup(content, L["Overview"])
    local b = ui:CreateTextBlock(content)
    b:AddLine(kit.Lead(L["Reach him"]) .. "  "
        .. L["Clear all nine chambers in one run on Tier 8 or higher. His chamber in the far north of %s then stays open, so later runs need only %s, %s or %s, and %s."]
            :format(AreaName(ROOST, "Akil'zon's Roost"), AreaName(RITES, "Chamber of Rites"), AreaName(LAIR, "Halazzi's Lair"),
                AreaName(TOWERS, "The Cave Towers"), AreaName(ROOST, "Akil'zon's Roost")),
        "label", { bullet = kit.BULLET })
    kit.Bullet(b, L["Den'Zara first"], L["The Vilebranch necromancer guards his chamber. Defeat her and Kindo'jan steps in."])
    b:AddLine(L["Ten-minute enrage."], "label", { gap = kit.PARA_GAP, bullet = kit.BULLET })
    kit.Bullet(b, SpellName(DISGRACE, "Disgraceful Display"),
        L["Every avoidable mechanic that hits you adds a stack. At three stacks the loa end your fight, whatever your health."])
    b:AddLine(L["Below Tier 8 he never appears."], "label", { gap = kit.PARA_GAP, bullet = kit.BULLET })
    card:Add(b, { fitHeight = true })
    return card
end

local function MechanicRow(ui, content, kit, m, text)
    local name = SpellName(m.id, m.en)
    if m.loa then name = name .. "  " .. E.DelveList.cc("muted") .. m.loa .. "|r" end
    local row = kit.HeadedRow(ui, content, name, 0)
    row.tag = ui:CreateText(row, m.tag, "groupLabel")
    row.tag:SetTextColor(kit.rgb(TAG_COLORS[m.color]))
    row.tag:SetPoint("LEFT", row.name, "RIGHT", kit.TAG_GAP, 0)
    row.text:AddLine(text, "label")
    row.Measure = kit.MeasureHeaded
    return row
end

local function BuildTactics(ui, content, kit, label, intro, list, textOf)
    local card = ui:CreateGroup(content, label)
    local b = ui:CreateTextBlock(content)
    b:AddLine(intro, "hint")
    card:Add(b, { fitHeight = true })
    for _, m in ipairs(list) do
        card:Add(MechanicRow(ui, content, kit, m, textOf(m)), { fitHeight = true, fill = true })
    end
    return card
end

local function BuildPhaseTwo(ui, content, kit)
    local card = ui:CreateGroup(content, L["Phase 2"])
    local b = ui:CreateTextBlock(content)
    b:AddLine(L["He returns and uses everything above in random order, the four loa included. Watch for overlaps: %s with %s means taking the knockback and running straight to the sigil."]
        :format(kit.Lead(SpellName(CRUSHING, "Crushing Blow")), kit.Lead(SpellName(CLEANSING, "Cleansing Flame"))), "label")
    b:AddLine(L["Use %s or %s here, so this phase is as short as possible."]
        :format(SpellName(BLOODLUST, "Bloodlust"), SpellName(HEROISM, "Heroism")), "label", { gap = kit.PARA_GAP })
    card:Add(b, { fitHeight = true })
    return card
end

local function BuildCompanion(ui, content, kit, k)
    local card = ui:CreateGroup(content, L["Companion & Loadout"])
    local b = ui:CreateTextBlock(content)
    b:AddLine(kit.Lead(L["Role"]) .. "  "
        .. L["Either works. Nothing in this fight needs Valeera's interrupt or dispel, so pick the role you prefer."],
        "label", { bullet = kit.BULLET })
    kit.Bullet(b, L["Poison"], L["%s, by far the strongest poison here."]:format(SpellName(TOAD_TOXIN, "Bursting Toad Toxin")))
    -- Item names can reach the client after the page is built, so these two are filled in when it is drawn
    k.combat = b:AddLine("", "label", { gap = kit.PARA_GAP, bullet = kit.BULLET })
    k.utility = b:AddLine("", "label", { gap = kit.PARA_GAP, bullet = kit.BULLET })
    card:Add(b, { fitHeight = true })
    return card
end

local function RewardTooltip(self)
    local r = self.reward
    if r.itemID then
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetItemByID(r.itemID)
        GameTooltip:Show()
    else
        E.ui:ShowTooltip(self, self.name:GetText(), r.condText)
    end
end

local function RewardRow(ui, content, kit, r)
    local row = kit.HeadedRow(ui, content, r.en or "", kit.REWARD_ICON + kit.REWARD_GAP)
    row.reward = r
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(kit.REWARD_ICON, kit.REWARD_ICON)
    row.icon:SetPoint("TOPLEFT")
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    row.tag = ui:CreateTag(row, r.kind, "outline")
    row.tag:SetPoint("LEFT", row.name, "RIGHT", kit.TAG_GAP, 0)
    row.done = kit.Check(ui, row)
    row.done:SetPoint("LEFT", row.tag, "RIGHT", kit.TAG_GAP, 0)
    row.cond = row.text:AddLine("", "hint")
    row.Measure = kit.MeasureHeaded
    row:EnableMouse(true)
    row:SetScript("OnEnter", RewardTooltip)
    row:SetScript("OnLeave", function()
        GameTooltip:Hide()
        ui:HideTooltip()
    end)
    return row
end

local function BuildRewards(ui, content, kit, k)
    local LAB = E.Labyrinth
    local card = ui:CreateGroup(content, L["Rewards"])
    k.rewards = {
        { itemID = LAB.kindojanToy, toy = true, kind = L["Toy"], en = "Loa-Blessed Victory" },
        { itemID = LAB.kindojanWeeklyItem, spell = LAB.kindojanWeeklySpell, kind = L["Weekly"], en = "Kindo'jan's Reward" },
        { achievement = LAB.kindojanAchievement, kind = L["Title"], en = "The First Hash'ey" },
        { achievement = LAB.kindojanSoloAchievement, itemID = LAB.kindojanMount, kind = L["Mount"], en = "Let Me Solo Him: Kindo'jan" },
        { achievement = LAB.kindojanArmyAchievement, kind = L["Title"], en = "The Labyrinth of Kindo'jan: One-Champion Army" },
        { achievement = LAB.kindojanFabledAchievement, kind = L["Title"], en = "Fabled Let Me Solo Him: Kindo'jan" },
    }
    k.rewardRows = {}
    for i, r in ipairs(k.rewards) do
        k.rewardRows[i] = RewardRow(ui, content, kit, r)
        card:Add(k.rewardRows[i], { fitHeight = true, fill = true })
    end
    return card
end

local function RenderRewards(k)
    for i, r in ipairs(k.rewards) do
        local row = k.rewardRows[i]
        local name, done, icon, cond
        if r.achievement then
            local n, d, _, reward = Achievement(r.achievement)
            name, done, cond = n, d, reward
            -- A title has no item to show, as on Azta'rec's page
            icon = r.itemID and ItemIcon(r.itemID)
        else
            name, icon = ItemName(r.itemID, r.en), ItemIcon(r.itemID)
            if r.toy then
                cond = L["Defeat %s for the first time."]:format(L["Kindo'jan"])
                done = PlayerHasToy and PlayerHasToy(r.itemID) or false
            else
                cond = C_Spell and C_Spell.GetSpellDescription and C_Spell.GetSpellDescription(r.spell)
                -- Asked once, so a description that stays empty cannot keep the page redrawing
                if (cond == nil or cond == "") and not k.spellAsked and C_Spell and C_Spell.RequestLoadSpellData then
                    k.spellAsked = true
                    C_Spell.RequestLoadSpellData(r.spell)
                end
            end
        end
        row.name:SetText(name or r.en)
        row.icon:SetTexture(icon)
        row.icon:SetShown(icon ~= nil)
        r.condText = cond
        row.cond:SetText(cond or "")
        row.done:SetShown(done == true)
        row.tag:Fit()
    end
end

function E.BuildKindojanView(ui, content, kit)
    local k = {}
    k.cards = {
        BuildHero(ui, content, kit, k),
        BuildStatus(ui, content, kit, k),
        BuildOverview(ui, content, kit),
        BuildTactics(ui, content, kit, L["Phase 1"], L["For the first minute and a half, in this order:"], PHASE_ONE,
            function(m) return PhaseOneText(m.id) end),
        BuildTactics(ui, content, kit, L["Intermission"],
            L["At 1:30 he steps back and four loa speakers take turns. No damage phase: just survive each one."],
            INTERMISSION, function(m) return m.text end),
        BuildPhaseTwo(ui, content, kit),
        BuildCompanion(ui, content, kit, k),
        BuildRewards(ui, content, kit, k),
    }

    local LAB = E.Labyrinth
    k.spells = { [LAB.kindojanWeeklySpell] = true }
    k.items = {
        [BILESPEAR] = true, [OUROBORIC] = true, [DREAMCATCHER] = true,
        [LAB.kindojanToy] = true, [LAB.kindojanWeeklyItem] = true, [LAB.kindojanMount] = true,
    }

    function k.Refresh()
        local firstName, firstDone, firstIcon = Achievement(LAB.kindojanAchievement)
        k.hero.portrait:SetTexture(firstIcon or PORTRAIT_ICON)
        k.hero.place:SetText("- " .. E.LabyrinthZoneName() .. " - " .. E.LabyrinthDisplayName())
        k.hero.sub:SetText(L["%s, master of the Labyrinth."]:format(firstName or "The First Hash'ey"))
        k.hero.tt:SetAlpha(E:IsTomTomLoaded() and 1 or kit.DIM)

        k.kills.value:SetText(tostring(E.KindojanKills()))
        k.first.label:SetText(firstName or "The First Hash'ey")
        k.first.check:SetShown(firstDone == true)
        k.first.value:SetText(firstDone and "" or "--")
        local reward = E:KindojanRewardThisWeek()
        k.weekly.check:SetShown(reward == true)
        k.weekly.value:SetText((reward == true and "") or (reward == false and L["Not yet - a kill on Tier 8 or higher earns it"]) or "--")

        k.combat:SetText(kit.Lead(L["Combat"]) .. "  "
            .. L["%s, or %s."]:format(ItemName(BILESPEAR, "Corrosive Bilespear"), ItemName(OUROBORIC, "Ouroboric Curse")))
        k.utility:SetText(kit.Lead(L["Utility"]) .. "  " .. ItemName(DREAMCATCHER, "Soul-Cracking Dreamcatcher"))
        RenderRewards(k)
    end
    return k
end
