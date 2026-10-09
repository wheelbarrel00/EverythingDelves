local E = EverythingDelves
local L = E.L

local ipairs, tonumber = ipairs, tonumber
local math_abs, math_ceil, math_max, math_min = math.abs, math.ceil, math.max, math.min

local PAD_TOP, PAD_LEFT, PAD_RIGHT, PAD_BOTTOM, GROUP_GAP = 20, 24, 14, 28, 22
local ROW, PORTRAIT, HERO_PAD, BUTTON_GAP, ITEM_GAP = 44, 40, 12, 10, 12
local PARA_GAP, SUB_INDENT, NAME_LINE, NAME_GAP, TAG_GAP = 8, 14, 17, 3, 8
local REWARD_ICON, REWARD_GAP, STATUS_GAP, STATUS_LINE = 28, 10, 4, 15
local CHECK, CHECK_GAP, BAR_MIN, DIM = 14, 6, 60, 0.4
local BULLET = "\226\128\162"
local ED_TEXTURES = "Interface\\AddOns\\EverythingDelves\\Media\\Textures\\"

local NEMESIS_MAP, NEMESIS_X, NEMESIS_Y = 2512, 51.22, 30.27
local NEMESIS_QUEST = 97482
local NEMESIS_ICON  = "Interface\\Icons\\Ability_Creature_Poison_06"
local PORTRAIT_MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
local BEACON_ITEM_ID, UNDERCOIN_ID, BEACON_PRICE = 253342, 2803, 5000

local MECHANICS = {
    { name = "Soul Extinction", tag = L["Interrupt - Top Priority"], color = "FF3333",
      desc = L["An interruptible cast that deals lethal damage if it completes. Kick it every single time. Valeera interrupts it for you when her role is set to DPS, which is the reason a healer should run her that way."] },
    { name = "Void Toxin", tag = L["Dispel"], color = "FFD100",
      desc = L["A dispellable magic debuff that ticks for heavy damage and cuts the damage you deal by 40 percent. Remove it as soon as it lands. Valeera dispels it for you when her role is set to Healer."] },
    { name = "Noxious Bile", tag = L["Frontal"], color = "FF8800",
      desc = L["A frontal cone that hits hard if you stay in it, and it leaves venom puddles behind on the floor. Aim it toward the outside of the room and step out once he has aimed it, so the middle of the arena stays clean for the intermission."] },
    { name = "Venom Storm", tag = L["Keep Moving"], color = "FF8800",
      desc = L["Summons venom waves that crawl slowly across the arena and deal heavy damage to anyone they catch. They are slow enough to walk away from, so keep moving rather than reacting late."] },
    { name = "Serpent's Strike", tag = L["Tank Hit"], color = "999999",
      desc = L["Only used while you are in a tank specialization, and only a small amount of physical damage. Nothing to plan around."] },
}

local PHASES = {
    {
        pct   = L["90 / 60 / 30 percent HP"],
        name  = "Sermon of Ula'tek",
        intro = L["The same intermission runs at all three health thresholds, one step longer each time."],
        adds  = {
            { n = L["Shown pattern"], d = L["He marks one safe quarter and covers the other three, with an animation showing which is which. You get a few seconds to run to the safe quarter. Stand close to him so every quarter is within reach."] },
            { n = L["Repeated pattern"], d = L["He then replays the same sequence with no animation at all. You have to remember the order the safe zones came in - this is what kills people, not the damage."] },
            { n = L["Length"], d = L["On Tier \"?\" the sequence runs 3 times, then 4, then 5 across the three intermissions. On Tier \"??\" it runs 5, then 6, then 7."] },
            { n = L["Lingering venom"], d = L["Keep the middle of the room clear of Noxious Bile puddles during the main phase, or you will be dodging your own leftovers while running the pattern."] },
        },
    },
    {
        pct   = L["Tier \"??\" only"],
        name  = "Echo of Azta'rec",
        intro = L["On the harder difficulty he also summons an Echo of himself during the intermission."],
        adds  = {
            { n = "Echo of Azta'rec", d = L["It does not have much health, but it uses every ability from his main phase - including Soul Extinction, which will one-shot you if it lands. Crowd control it and kill it fast; leaving it up makes the whole intermission far harder."] },
            { n = L["Cover the Echo's casts"], d = L["If Valeera is set to Healer, you must interrupt the Echo yourself. If she is set to DPS she covers the interrupt, but then you have to dispel Void Toxin."] },
            { n = L["Extra venom sets"], d = L["Two additional venom coverings are added, so the pattern you must memorise reaches five safe zones."] },
        },
    },
}

local REWARDS = {
    { name = "Apophic Patagia", kind = L["Cloak Transmog"], itemID = 276163,
      cond = L["Defeat Azta'rec on either difficulty during Season 2 (My Venomous Nemesis, a Feat of Strength)."],
      extra = L["Your first kill also grants 30 Hero Mistcrests, which do not count toward the season maximum."] },
    { name = "Corrosive Victory", kind = L["Toy"], itemID = 275988, quest = true,
      cond = L["Reward from the Fangs for the Memories quest."] },
    { name = "Apophic Soul Crusher", kind = L["Mount"], itemID = 275657,
      cond = L["Solo Azta'rec (Let Me Solo Him: Azta'rec)."] },
    { name = "the Poisonous", kind = L["Title"],
      cond = L["Defeat Azta'rec on Tier \"??\" (Purging the Poison)."] },
    { name = "Fabled Vanquisher of Azta'rec", kind = L["Title"],
      cond = L["Defeat him in his lair on Tier \"??\" with no other players in your party, within the first week of Season 2 (Fabled Let Me Solo Him: Azta'rec)."] },
}

local function rgb(hex)
    return tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255, tonumber(hex:sub(5, 6), 16) / 255
end

local function GetRewardIcon(itemID)
    if not itemID then return nil end
    if C_Item and C_Item.GetItemIconByID then
        local icon = C_Item.GetItemIconByID(itemID)
        if icon then return icon end
    end
    if C_Item and C_Item.GetItemInfoInstant then
        local _, _, _, _, icon = C_Item.GetItemInfoInstant(itemID)
        return icon
    end
    return nil
end

-- A string cannot change weight partway through a wrapped line, so a lead-in stands out by color alone
local function Lead(text)
    return E.DelveList.cc("text") .. text .. "|r"
end

local function LeadLine(block, lead, text)
    block:AddLine(Lead(lead) .. "  " .. text, "label", { gap = PARA_GAP })
end

local function Bullet(block, lead, text, indent)
    block:AddLine(Lead(lead) .. "  " .. text, "label", { gap = PARA_GAP, bullet = BULLET, indent = indent })
end

-- A card centers a control in its row but never sizes it, and a row frame left with no height came up blank
-- after a cold login
local function Row(content, height)
    local f = CreateFrame("Frame", nil, content)
    if height then f:SetHeight(height) end
    return f
end

local function Check(ui, parent)
    local t = parent:CreateTexture(nil, "ARTWORK")
    t:SetSize(CHECK, CHECK)
    t:SetTexture(ui:Texture("check"))
    t:SetVertexColor(ui:Color("label"))
    return t
end

-- Tags hang off the name's drawn edge, since a width read while the page is built can be short of the font as drawn
local function HeadedRow(ui, content, name, x)
    local row = Row(content)
    row.name = ui:CreateText(row, name, "value")
    row.name:SetWordWrap(false)
    row.name:SetPoint("TOPLEFT", row, "TOPLEFT", x, 0)
    row.text = ui:CreateTextBlock(row)
    row.text:SetPoint("TOPLEFT", row, "TOPLEFT", x, -(NAME_LINE + NAME_GAP))
    row.text:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, -(NAME_LINE + NAME_GAP))
    return row
end

local function MeasureHeaded(row)
    local h = NAME_LINE + NAME_GAP + row.text:Measure()
    if row.status then h = h + STATUS_GAP + STATUS_LINE end
    if row.icon then h = math_max(REWARD_ICON, h) end
    row:SetHeight(h)
    return h
end

local function BuildHero(ui, content, v)
    local card = ui:CreateGroup(content, nil)
    local hero = Row(content)
    hero:SetHeight(PORTRAIT)

    local portrait = hero:CreateTexture(nil, "ARTWORK")
    portrait:SetSize(PORTRAIT, PORTRAIT)
    portrait:SetPoint("LEFT")
    portrait:SetTexture(NEMESIS_ICON)
    if portrait.SetMask then pcall(portrait.SetMask, portrait, PORTRAIT_MASK) end

    hero.tt = E.DelveList.IconButton(hero, ED_TEXTURES .. "icon-tomtom")
    hero.tt:SetPoint("RIGHT")
    hero.pin = E.DelveList.IconButton(hero, ui:Texture("icon-map"))
    hero.pin:SetPoint("RIGHT", hero.tt, "LEFT", -BUTTON_GAP, 0)

    hero.name = ui:CreateText(hero, "Azta'rec", "title")
    hero.name:SetPoint("TOPLEFT", portrait, "TOPRIGHT", ITEM_GAP, -2)
    hero.place = ui:CreateText(hero, "- The Coiled Isle - Venomfall Deeps", "label")
    hero.place:SetTextColor(ui:Color("muted"))
    hero.place:SetWordWrap(false)
    hero.place:SetPoint("BOTTOMLEFT", hero.name, "BOTTOMRIGHT", 6, 0)
    hero.place:SetPoint("RIGHT", hero.pin, "LEFT", -ITEM_GAP, 0)
    hero.sub = ui:CreateText(hero, L["Season 2 Nemesis  \226\128\148  two difficulties, Tier \"?\" and Tier \"??\""], "hint")
    hero.sub:SetWordWrap(false)
    hero.sub:SetPoint("TOPLEFT", hero.name, "BOTTOMLEFT", 0, -2)
    hero.sub:SetPoint("RIGHT", hero.pin, "LEFT", -ITEM_GAP, 0)

    hero.pin:SetScript("OnClick", function(self)
        if E:SetWaypoint(NEMESIS_MAP, NEMESIS_X, NEMESIS_Y) then E.DelveList.Flash(self) end
    end)
    hero.pin:SetScript("OnEnter", function(self)
        ui:ShowTooltip(self, L["Set Waypoint"], L["Pin Venomfall Deeps on your map."])
    end)
    hero.pin:SetScript("OnLeave", function() ui:HideTooltip() end)
    hero.tt:SetScript("OnClick", function(self)
        if E:IsTomTomLoaded() and E:AddTomTomWaypoint(NEMESIS_MAP, NEMESIS_X, NEMESIS_Y, "Venomfall Deeps") then
            E.DelveList.Flash(self)
        end
    end)
    hero.tt:SetScript("OnEnter", function(self)
        if E:IsTomTomLoaded() then
            ui:ShowTooltip(self, L["TomTom Waypoint"], L["Add a TomTom arrow to Venomfall Deeps."])
        else
            ui:ShowTooltip(self, L["TomTom Not Installed"], L["Install the TomTom addon to use arrow waypoints."])
        end
    end)
    hero.tt:SetScript("OnLeave", function() ui:HideTooltip() end)

    card:Add(hero, { height = PORTRAIT + HERO_PAD * 2, fill = true })
    v.hero = hero
    return card
end

local function BuildOverview(ui, content)
    local card = ui:CreateGroup(content, L["Overview"])
    local b = ui:CreateTextBlock(content)
    b:AddLine(Lead(L["Venomfall Deeps is open, but his lair has to be unlocked first."]) .. " "
        .. L["Clear a Tier 7 delve with at least one life left to unlock the lower difficulty, or a Tier 10 clear for the harder one. The clear does not have to be in Venomfall Deeps. Azta'rec can also be met the other way listed below."])
    b:AddLine(L["Azta'rec is the Midnight Season 2 Nemesis, and you can meet him two separate ways:"], "label", { gap = PARA_GAP })
    Bullet(b, L["Inside any delve"], L["he can appear at random in any Tier 8 or higher delve, and can also be summoned on the spot with a Scalebound Herald's Flute."])
    Bullet(b, "Venomfall Deeps", L["the dedicated Nemesis delve on The Coiled Isle. This is the full fight \226\128\148 the mechanics and intermissions below cover it, and it is what awards the achievements, mount, and titles."])
    Bullet(b, L["Tier \"?\""], L["the easier of the two. Recommended item level 290."])
    Bullet(b, L["Tier \"??\""], L["everything hits far harder, and he summons an Echo of himself during every intermission. This is the one the title and the Fabled title require."])
    b:AddLine(L["The entrance is on the north side of The Coiled Isle, inside one of the snake buildings (use Pin or TomTom above). Your first kill awards a bonus 30 Hero Mistcrests, which do not count toward the season maximum."], "hint", { gap = PARA_GAP })
    b:AddLine(L["The encounter is deliberately punishing and expects deaths while you learn it, especially at lower item levels."], "hint", { gap = PARA_GAP })
    card:Add(b, { fitHeight = true })
    return card
end

local function BuildBeacon(ui, content, v)
    local card = ui:CreateGroup(content, L["Beacon of Hope"])
    local row = Row(content, ROW)
    row.check = Check(ui, row)
    row.check:SetPoint("LEFT")
    row.status = ui:CreateText(row, "", "label")
    row.status:SetWordWrap(false)
    row.value = ui:CreateText(row, "", "value")
    row.value:SetPoint("RIGHT")
    row.bar = ui:CreateProgressBar(row)
    row.bar:SetPoint("LEFT", row.status, "RIGHT", ITEM_GAP, 0)
    row.bar:SetPoint("RIGHT", row.value, "LEFT", -ITEM_GAP, 0)
    card:Add(row, { height = ROW, fill = true })

    local hint = ui:CreateTextBlock(content)
    hint:AddLine(L["Use a Beacon of Hope inside a delve to call the Nemesis rather than waiting on his random spawn. Season 2 also introduces the Scalebound Herald's Flute, which summons Azta'rec inside the delve \226\128\148 its cost and vendor are not tracked here yet. The Undercoin bar tracks the Beacon, not the Flute."], "hint")
    card:Add(hint, { fitHeight = true })
    v.beacon = row
    return card
end

local function BuildMechanics(ui, content)
    local card = ui:CreateGroup(content, L["Boss Mechanics"])
    local intro = ui:CreateTextBlock(content)
    intro:AddLine(L["The fight splits into a main phase and an intermission at 90, 60 and 30 percent health. Two casts decide whether you live:"] .. " "
        .. L["%s (interrupt) and %s (dispel). Pull him to the edge of the room so the Noxious Bile puddles land away from the middle."]
            :format(Lead("Soul Extinction"), Lead("Void Toxin")))
    intro:AddLine(L["Companion: as DPS or tank, set Valeera to Healer and she dispels Void Toxin while you cover the interrupt; as a healer, set her to DPS so she interrupts Soul Extinction and you dispel instead."], "hint", { gap = PARA_GAP })
    card:Add(intro, { fitHeight = true })

    for _, m in ipairs(MECHANICS) do
        local row = HeadedRow(ui, content, m.name, 0)
        row.tag = ui:CreateText(row, m.tag, "groupLabel")
        row.tag:SetTextColor(rgb(m.color))
        row.tag:SetPoint("LEFT", row.name, "RIGHT", TAG_GAP, 0)
        row.text:AddLine(m.desc, "label")
        row.Measure = MeasureHeaded
        card:Add(row, { fitHeight = true, fill = true })
    end
    return card
end

local function BuildIntermissions(ui, content)
    local card = ui:CreateGroup(content, L["Intermissions"])
    local b = ui:CreateTextBlock(content)
    b:AddLine(L["At 90, 60 and 30 percent health Azta'rec walks to the centre and channels Sermon of Ula'tek, taking 99 percent reduced damage for the whole intermission. The room splits into quarters: three flood with venom and one is safe. It is a memory test, not a damage test \226\128\148 place four world markers on the quadrants before you pull and call the safe spot by marker."], "hint")
    local dash = "  " .. E.DelveList.cc("muted") .. "-|r  "
    for _, ph in ipairs(PHASES) do
        b:AddLine(Lead(ph.pct) .. dash .. Lead(ph.name), "label", { gap = PARA_GAP })
        b:AddLine(ph.intro, "label", { gap = PARA_GAP, indent = SUB_INDENT })
        for _, a in ipairs(ph.adds) do Bullet(b, a.n, a.d, SUB_INDENT) end
    end
    LeadLine(b, L["Final push"], L["After the 30 percent intermission there are no more, and the main phase runs until he dies. Save Bloodlust or Heroism for after the last intermission on Tier \"?\", or during the last intermission on Tier \"??\" to kill the Echo faster."])
    LeadLine(b, L["Before you pull"], L["Drop a world marker on each of the four quadrants, then call the safe zones by marker during the Sermon. Remembering \"blue, yellow, purple\" is far easier than remembering positions on a venom-covered floor."])
    card:Add(b, { fitHeight = true })
    return card
end

local function BuildCompanion(ui, content)
    local card = ui:CreateGroup(content, L["Companion & Loadout"])
    local b = ui:CreateTextBlock(content)
    b:AddLine(L["Only two mechanics need covering, and Valeera can take exactly one of them. Give her whichever you cannot cover yourself:"], "hint")
    Bullet(b, L["DPS / Tank"], L["run Valeera as Healer \226\128\148 she dispels Void Toxin, and you interrupt Soul Extinction yourself."])
    Bullet(b, L["Healer"], L["run Valeera as DPS \226\128\148 she interrupts Soul Extinction, and you dispel Void Toxin yourself."])
    LeadLine(b, L["Curios"], L["Valeera has a third slot this season: Combat, Utility and a new Poisons slot. The picks do not change with your own role."])
    Bullet(b, L["Poison"], L["Frostheart Venom \226\128\148 cuts enemy attack and cast speed by 20 percent, which buys time on both Soul Extinction and the Void Toxin dispel."])
    Bullet(b, L["Combat"], L["Corrosive Bilespear for straight damage. Ouroboric Curse is the alternative, but much of this delve one-shots, so its effect is hard to keep procced."])
    Bullet(b, L["Utility"], L["Soul-Cracking Dreamcatcher \226\128\148 because you interrupt so often it is close to permanent uptime, and the debuff sits on the boss, so Valeera's own interrupts keep it up even while you play healer. 30 percent damage at Rank 3 or higher."])
    LeadLine(b, L["Consumables"], L["carry health and DPS potions, and hold Bloodlust or Heroism for after the final intermission on Tier \"?\", or for killing the Echo during the final intermission on Tier \"??\"."])
    card:Add(b, { fitHeight = true })
    return card
end

local function RewardTooltip(self)
    local r = self.reward
    if r.itemID then
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetItemByID(r.itemID)
        if r.extra then GameTooltip:AddLine(r.extra, 1, 1, 1, true) end
        GameTooltip:Show()
    else
        E.ui:ShowTooltip(self, r.name, r.cond)
    end
end

local function RewardRow(ui, content, r)
    local row = HeadedRow(ui, content, r.name, REWARD_ICON + REWARD_GAP)
    row.reward = r
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(REWARD_ICON, REWARD_ICON)
    row.icon:SetPoint("TOPLEFT")
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    local tex = GetRewardIcon(r.itemID)
    if tex then row.icon:SetTexture(tex) else row.icon:Hide() end

    row.tag = ui:CreateTag(row, r.kind, "outline")
    row.tag:SetPoint("LEFT", row.name, "RIGHT", TAG_GAP, 0)
    row.text:AddLine(r.cond, "hint")
    if r.quest then
        row.status = ui:CreateText(row, "", "hint")
        row.status:SetWordWrap(false)
        row.check = Check(ui, row)
        row.check:SetPoint("RIGHT", row.status, "LEFT", -CHECK_GAP, 0)
    end

    row.Measure = MeasureHeaded
    row:EnableMouse(true)
    row:SetScript("OnEnter", RewardTooltip)
    row:SetScript("OnLeave", function()
        GameTooltip:Hide()
        ui:HideTooltip()
    end)
    return row
end

local function BuildRewards(ui, content, v)
    local card = ui:CreateGroup(content, L["Rewards"])
    v.rewardTags = {}
    for _, r in ipairs(REWARDS) do
        local row = RewardRow(ui, content, r)
        v.rewardTags[#v.rewardTags + 1] = row.tag
        if r.quest then v.toy = row end
        card:Add(row, { fitHeight = true, fill = true })
    end
    return card
end

local function RenderBeacon(ui, v, inner)
    local row = v.beacon
    local held = C_Item and C_Item.GetItemCount and C_Item.GetItemCount(BEACON_ITEM_ID, true) or 0
    local coins = 0
    if C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo then
        local info = C_CurrencyInfo.GetCurrencyInfo(UNDERCOIN_ID)
        if info then coins = info.quantity or 0 end
    end
    local enough = held == 0 and coins >= BEACON_PRICE

    if held > 0 then
        row.status:SetText(L["[Ready] Beacon of Hope in inventory (%d)"]:format(held) .. "  "
            .. E.DelveList.cc("muted") .. "- " .. L["go get that Nemesis!"] .. "|r")
        row.status:SetTextColor(ui:Color("text"))
    elseif enough then
        row.status:SetText(L["You have enough Undercoins to purchase a Beacon!"])
        row.status:SetTextColor(ui:Color("label"))
    else
        row.status:SetText(L["No Beacon of Hope in bags or bank."])
        row.status:SetTextColor(ui:Color("label"))
    end
    row.check:SetShown(enough)

    local x = enough and (CHECK + CHECK_GAP) or 0
    row.status:ClearAllPoints()
    row.status:SetPoint("LEFT", row, "LEFT", x, 0)
    row.status:SetWidth(0)
    local natural = math_ceil(row.status:GetStringWidth() or 0)
    row.value:SetText(("%d / %d"):format(coins, BEACON_PRICE))
    -- The status gives way first, so a long translation never squeezes the bar out of sight
    local room = inner - x - math_ceil(row.value:GetStringWidth() or 0) - ITEM_GAP * 2 - BAR_MIN
    row.status:SetWidth(math_max(1, math_min(natural, room)))
    row.bar:SetProgress(coins / BEACON_PRICE)
end

local function RenderQuest(ui, v)
    local row = v.toy
    local done = C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted
        and C_QuestLog.IsQuestFlaggedCompleted(NEMESIS_QUEST) or false
    local active = not done and C_QuestLog and C_QuestLog.IsOnQuest and C_QuestLog.IsOnQuest(NEMESIS_QUEST) or false

    row.check:SetShown(done)
    row.status:ClearAllPoints()
    row.status:SetPoint("TOPLEFT", row.text, "BOTTOMLEFT", done and (CHECK + CHECK_GAP) or 0, -STATUS_GAP)
    row.status:SetPoint("RIGHT")
    if done then
        row.status:SetText("Fangs for the Memories")
        row.status:SetTextColor(ui:Color("label"))
    elseif active then
        row.status:SetText(L["Fangs for the Memories in progress \226\128\148 check your quest log."])
        row.status:SetTextColor(ui:Color("text"))
    else
        row.status:SetText(L["Fangs for the Memories available"])
        row.status:SetTextColor(ui:Color("muted"))
    end
end

E:RegisterModule(function()
    local ui = E.ui
    local frame = CreateFrame("Frame", "EverythingDelvesTabNullaeusContent")
    local area = ui:CreateScrollArea(frame, { clearGrip = true })
    area:SetAllPoints(frame)
    local content = area.content

    local v = {}
    local cards = {
        BuildHero(ui, content, v), BuildOverview(ui, content), BuildBeacon(ui, content, v),
        BuildMechanics(ui, content), BuildIntermissions(ui, content), BuildCompanion(ui, content),
        BuildRewards(ui, content, v),
    }

    local lastWidth = 0
    local function ViewWidth()
        local w = area.scroll:GetWidth() or 0
        if w <= 0 then w = (frame:GetWidth() or 0) - 10 end
        return math_max(1, w)
    end

    local function Refresh()
        RenderBeacon(ui, v, lastWidth - PAD_LEFT - PAD_RIGHT - ui:Spacing("rowPadding") * 2)
        RenderQuest(ui, v)
        v.hero.tt:SetAlpha(E:IsTomTomLoaded() and 1 or DIM)
        -- A tag sizes itself only when its text is set, which for these was while the page was built
        for _, tag in ipairs(v.rewardTags) do tag:Fit() end
    end

    local function Render()
        local width = ViewWidth()
        lastWidth = width
        content:SetWidth(width)
        Refresh()
        local y = PAD_TOP
        for i, card in ipairs(cards) do
            if i > 1 then y = y + GROUP_GAP end
            card:ClearAllPoints()
            card:SetPoint("TOPLEFT", content, "TOPLEFT", PAD_LEFT, -y)
            card:SetPoint("TOPRIGHT", content, "TOPRIGHT", -PAD_RIGHT, -y)
            card:Layout()
            y = y + card:GetHeight()
        end
        area:SetContentSize(width, y + PAD_BOTTOM)
    end

    -- Wrapped text measured before its first draw can come up short, so the page is measured again a frame later
    local pending = false
    local function RenderSoon()
        if pending then return end
        pending = true
        C_Timer.After(0, function()
            pending = false
            if frame:IsVisible() then Render() end
        end)
    end

    area.scroll:HookScript("OnSizeChanged", function(_, w)
        if frame:IsVisible() and math_abs((w or 0) - lastWidth) >= 1 then
            Render()
            RenderSoon()
        end
    end)

    frame:SetScript("OnShow", function()
        Render()
        area:ScrollTo(0, 0)
        RenderSoon()
    end)

    local function RefreshIfShown()
        if frame:IsVisible() then Refresh() end
    end
    E:RegisterCallback("QuestLogUpdate", RefreshIfShown)
    E:RegisterCallback("BagUpdate", RefreshIfShown)
    E:RegisterCallback("CurrencyUpdate", RefreshIfShown)

    E:RegisterTab(4, frame)
end)
