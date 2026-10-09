local E = EverythingDelves
local L = E.L

local CURSEFORGE_URL = "https://www.curseforge.com/wow/addons/everything-delves"
local GITHUB_URL     = "https://github.com/wheelbarrel00/EverythingDelves"
local BUG_URL        = "https://github.com/wheelbarrel00/EverythingDelves/issues"

local COMMANDS = {
    { cmd = "/ed",          desc = L["Open or close the main window"] },
    { cmd = "/ed obj",      desc = L["Toggle the Bonus Spoils tracker (also /ed spoils)"] },
    { cmd = "/ed curios",   desc = L["Toggle the curio reminder popup"] },
    { cmd = "/ed whatsnew", desc = L["Show the What's New popup again"] },
    { cmd = "/ed about",    desc = L["Open this About tab"] },
    { cmd = "/ed reset",    desc = L["Reset all settings to defaults"] },
}

-- Names are drawn raw, not through L[], so a row costs no locale key
local OTHER_ADDONS = {
    { name = "Everything Quests",
      cf   = "https://www.curseforge.com/wow/addons/everything-quests",
      gh   = "https://github.com/wheelbarrel00/EverythingQuests" },
    { name = "EQ Objective Tracker",
      cf   = "https://www.curseforge.com/wow/addons/eq-objective-tracker",
      gh   = "https://github.com/wheelbarrel00/EQObjectiveTracker" },
    { name = "Cooldown Master",
      cf   = "https://www.curseforge.com/wow/addons/cooldown-master",
      gh   = "https://github.com/wheelbarrel00/CooldownMaster" },
    { name = "Loot Pro",
      cf   = "https://www.curseforge.com/wow/addons/loot-pro",
      gh   = "https://github.com/wheelbarrel00/LootPro" },
}

local COMMUNITY = "BanditC64, Puzzleheaded-Pie-506, 8six753o9, herky4life"

-- One key per credit rather than a shared prefix plus a tail, so the name is a %s a
-- translator can move. Korean puts it elsewhere in the sentence and a concatenation cannot.
local TRANSLATORS = {
    { name = "Zox",        line = L["Special thanks to %s for the many hours spent translating Everything Delves into French."] },
    { name = "Malevi4",    line = L["Special thanks to %s for the many hours spent translating Everything Delves into Russian."] },
    { name = "labrie75",   line = L["Special thanks to %s for the many hours spent translating Everything Delves into Korean."] },
    { name = "Keriaovo",   line = L["Special thanks to %s for the many hours spent translating Everything Delves into Simplified Chinese."] },
    { name = "BNS333",     line = L["Special thanks to %s for the many hours spent translating Everything Delves into Traditional Chinese."] },
    { name = "Stonetwist", line = L["Special thanks to %s for the many hours spent translating Everything Delves into German."] },
}

local function colorCode(ui, name)
    local r, g, b = ui:Color(name)
    return ("|cff%02x%02x%02x"):format(math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5),
                                       math.floor(b * 255 + 0.5))
end

local function introCard(self, content, stack)
    local card = stack(self:CreateGroup(content, nil))

    local clientVer = "?"
    if type(GetBuildInfo) == "function" then
        local ok, v = pcall(GetBuildInfo)
        if ok and type(v) == "string" and v ~= "" then clientVer = v end
    end

    local blurb = self:CreateTextBlock(content)
    blurb:AddLine((E.version or "?") .. "   " .. colorCode(self, "muted")
        .. L["by Wheelbarrel00    -    for WoW Midnight (%s)"]:format(clientVer) .. "|r", "value")
    blurb:AddLine(L["A complete Delves companion: track delve locations, bountiful status, coffer key shards, tiers, your run history, and more - all in one window."])
    card:Add(blurb, { fitHeight = true })

    local links = CreateFrame("Frame", nil, content)
    links:SetHeight(self:Spacing("buttonHeight"))
    local list = {
        { label = L["Join our Discord"], onClick = function() E:ShowDiscord() end },
        { label = "CurseForge",          onClick = function() E:ShowURL(CURSEFORGE_URL) end },
        { label = "GitHub",              onClick = function() E:ShowURL(GITHUB_URL) end },
        { label = L["Report a Bug"],     onClick = function() E:ShowURL(BUG_URL) end },
        { label = L["What's New"],       onClick = function() if E.ShowWhatsNew then E:ShowWhatsNew() end end },
    }
    local prev
    for _, lk in ipairs(list) do
        local b = self:CreateButton(content, lk.label, nil, lk.onClick)
        if prev then
            b:SetPoint("LEFT", prev, "RIGHT", self:Spacing("buttonGap"), 0)
        else
            b:SetPoint("LEFT", links, "LEFT")
        end
        prev = b
    end
    card:Add(links, { fill = true })
end

local function commandsCard(self, content, stack)
    local card = stack(self:CreateGroup(content, L["Commands"]))
    for _, c in ipairs(COMMANDS) do
        local row = self:CreateTextRow(content, c.cmd, c.desc)
        row.label:SetTextColor(self:Color("text"))
        card:Add(row, { height = self:Spacing("listRowHeight") })
    end
    local tip = self:CreateTextBlock(content)
    tip:AddLine(L["Tip: right-click the minimap button to open Options."], "hint")
    card:Add(tip, { fitHeight = true })
end

local function tutorialsCard(self, content, stack)
    local card = stack(self:CreateGroup(content, L["Tutorials"]))
    local note = self:CreateTextBlock(content)
    note:AddLine(L["Video tutorials are coming soon - watch this space."], "hint")
    card:Add(note, { fitHeight = true })
end

local function addonsCard(self, content, stack)
    local card = stack(self:CreateGroup(content, L["More Add-ons by Wheelbarrel00"]))
    for _, a in ipairs(OTHER_ADDONS) do
        local row = self:CreateTextRow(content, a.name, "")
        row.label:SetTextColor(self:Color("text"))
        card:Add(row)
        -- On the row's text column, which the card moves past its widest name
        local cf = self:CreateButton(content, "CurseForge", nil, function() E:ShowURL(a.cf) end, nil, "ghost")
        cf:SetPoint("LEFT", row.text, "LEFT", 0, 0)
        local gh = self:CreateButton(content, "GitHub", nil, function() E:ShowURL(a.gh) end, nil, "ghost")
        gh:SetPoint("LEFT", cf, "RIGHT", self:Spacing("buttonGap"), 0)
    end
end

local function thanksCard(self, content, stack)
    local card = stack(self:CreateGroup(content, L["Thanks"]))
    local bright = colorCode(self, "text")
    -- |r falls back to the line's own color, so only the names need an escape
    local block = self:CreateTextBlock(content)
    block:AddLine(L["Built with feedback, reports, and ideas from the community - especially %s. Thank you!"]
        :format(bright .. COMMUNITY .. "|r"))
    for _, t in ipairs(TRANSLATORS) do
        block:AddLine(t.line:format(bright .. t.name .. "|r"))
    end
    card:Add(block, { fitHeight = true })
end

local function changelogCard(self, content, stack)
    local card = stack(self:CreateGroup(content, L["Changelog"]))
    local muted = colorCode(self, "muted")
    -- A raise here leaves the library's SelectTab with every tab hidden, so a version-less entry is skipped
    for _, entry in ipairs(E.Changelog or {}) do
        if entry.version then
            local block = self:CreateTextBlock(content)
            block:AddLine(entry.version .. "   " .. muted .. (entry.date or "") .. "|r", "value")
            for _, sec in ipairs(entry.sections or {}) do
                block:AddLine(sec.head or "", "groupLabel", { gap = 10 })
                for _, item in ipairs(sec.items or {}) do
                    block:AddLine(item, "label", { bullet = "-" })
                end
            end
            card:Add(block, { fitHeight = true })
        end
    end
    card:Add(self:CreateButton(content, L["Older versions are on CurseForge"], nil,
        function() E:ShowURL(CURSEFORGE_URL) end))
end

E.ui:RegisterTab({
    id = "about", title = L["About"], order = 50, icon = E.ui:Texture("icon-about"),
    build = function(self, content)
        local stack = E.CardStack(self)
        introCard(self, content, stack)
        commandsCard(self, content, stack)
        tutorialsCard(self, content, stack)
        addonsCard(self, content, stack)
        thanksCard(self, content, stack)
        changelogCard(self, content, stack)
    end,
})
