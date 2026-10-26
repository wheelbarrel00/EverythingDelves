local E = EverythingDelves
local L = E.L

-- One per release. A release marked fixesOnly announces nothing and is listed with the next feature release.
local RELEASES = {
    { version = "2.4.1", fixesOnly = true, entries = {
        {
            title = "Korean reviewed",
            desc  = "The Korean text was reviewed throughout, and the delve notes name each story as the game's map does. Thanks to labrie75.",
        },
        {
            title = "Less work in the background",
            desc  = "The Roster, the Tier Guide and the delve lists read the game less often.",
        },
    } },
    { version = "2.4.0", entries = {
        {
            title = "What's New catches you up",
            desc  = "After an update with new features, this window lists every release you missed, each under its version and date. A fresh install opens nothing.",
        },
        {
            title = "Or a chat link instead",
            desc  = "In the settings window's General tab, After an update chooses a popup, a quiet clickable link in your chat, or off.",
        },
        {
            title = "Today's boss in every language",
            desc  = "Delves with two bosses now mark today's boss on German, French, Russian, Korean and Chinese clients.",
        },
        {
            title = "The bounty reminder closes itself",
            desc  = "Use your Trovehunter's Bounty from your bags and its reminder goes away on its own.",
        },
        {
            title = "Fixes all over",
            desc  = "Each character keeps its own run in progress, chat messages follow your accent color, renown uses each faction's real cap, and tooltips update after a click. The full list is in the About tab's changelog.",
        },
    } },
    { version = "2.3.0", entries = {
        {
            title = "Your own story grades",
            desc  = "A Story Grades tab in the settings: give any story your own grade, or mark one you won't run. Best Pick, the delve lists and the HUD follow your grades. Thanks to user_vsza93iuemi45toc for the request.",
        },
        {
            title = "Grade today's story with a right-click",
            desc  = "Right-click a delve on Delve Locations or Current Bountiful Delves to grade the story it has today.",
        },
        {
            title = "Story grades in every language",
            desc  = "Grades now show on German, French, Russian, Korean and Chinese clients, with the story names in your language.",
        },
        {
            title = "A Trovehunter's Bounty fix",
            desc  = "No more reminder to use a second bounty in the same week. The Tier Guide and the bounty's tooltip tell you to keep it for next week.",
        },
    } },
    { version = "2.2.0", entries = {
        {
            title = "The Labyrinth of Kindo'jan",
            desc  = "Every Labyrinth run is logged: chambers, checkpoint times and Kindo'jan's fight time on the delve HUD, in Delve History and on the Leaderboard.",
        },
        {
            title = "Kindo'jan on the Nemesis page",
            desc  = "A switch between Kindo'jan and Azta'rec. Kindo'jan's side covers how to reach him, each phase of the fight, Valeera's setup and his rewards.",
        },
        {
            title = "Labyrinth achievements",
            desc  = "Its tier goals, every Labyrinth achievement with your progress, and its Feats of Strength, on the Achievements page and the Labyrinth's map pin.",
        },
        {
            title = "The Labyrinth everywhere else",
            desc  = "Delve Locations, Current Bountiful Delves, the difficulty picker panel, the Tier Guide and the Roster all include it now.",
        },
        {
            title = "A Dundun reminder fix",
            desc  = "Coffer keys spent in the Labyrinth no longer stop the reminder to keep a key for Dundun's extra chest.",
        },
    } },
    { version = "2.1.0", entries = {
        {
            title = "A Leaderboard page",
            desc  = "Every delve on one board: the fastest clear your characters have at the tier you pick, who set it, and where the character you are playing stands. Click a delve for the full ranking, and filter by class and spec. Thanks to MattBravehearts for the idea.",
        },
        {
            title = "A grade for every story",
            desc  = "All 44 story grades, including the stories patch 12.1 added, now come from Moleman's Delve Compendium, which times the best clear of every story. Thanks to Moleman for the compendium.",
        },
        {
            title = "The Ring of Glory panel works",
            desc  = "The delve information panel now recognizes every delve by the game's own ID, in every language. Thanks to NoNe10 for the report.",
        },
        {
            title = "The Dundun reminder is fixed",
            desc  = "It now shows only in Bountiful Delves, and stays through combat and after the boss.",
        },
    } },
    { version = "2.0.0", entries = {
        {
            title = "A whole new look",
            desc  = "The nine pages sit in a sidebar, laid out in cards, in the same style as Everything Quests and EQ Objective Tracker. The window resizes from its corner, maximizes from its header and remembers its size.",
        },
        {
            title = "Settings have their own window",
            desc  = "Options, Profiles and About open from the cog in the header, a right-click on the minimap button, or /ed about. Opening them closes the main window, and /ed brings it back. Every setting keeps its saved value.",
        },
        {
            title = "Nothing else has changed",
            desc  = "Only the windows are new. Delve logging, the delve HUD, the reminders and the map tooltips work exactly as before. If anything looks wrong, please tell me in the CurseForge comments, on Discord, or in a GitHub issue.",
        },
        {
            title = "Some sections fill in a moment after login",
            desc  = "A few figures come from the game shortly after you log in. The Delver's Journey needs the Journeys panel opened once, and world quests need each zone's map opened. The page says when it is waiting.",
        },
    } },
}

local WIDTH, HEIGHT = 600, 560
local PAD_TOP, PAD_SIDE, PAD_BOTTOM = 20, 24, 24
local HEAD_GAP, SECTION_GAP = 4, 16
local VERSION_GAP, RELEASE_GAP = 8, 24
local FOOTER_H, BAR_ROOM = 56, 10

local function parts(version)
    local out = {}
    for n in tostring(version or ""):gmatch("%d+") do out[#out + 1] = tonumber(n) end
    return out
end

local function newer(a, b)
    local x, y = parts(a), parts(b)
    for i = 1, math.max(#x, #y) do
        local p, q = x[i] or 0, y[i] or 0
        if p ~= q then return p > q end
    end
    return false
end

table.sort(RELEASES, function(a, b) return newer(a.version, b.version) end)

local frame, pending, restoreMode

local function saved(key)
    return (E.db and E.db[key]) or ""
end

local function mode()
    return (E.db and E.db.whatsNewMode) or "popup"
end

local function markSeen()
    if E.db then E.db.seenWhatsNewVersion = RELEASES[1].version end
end

local function markAnnounced()
    if E.db then E.db.whatsNewAnnounced = RELEASES[1].version end
end

-- A release either notice has covered counts as told, so a switch between popup and chat never repeats or skips one
local function missed()
    local seen, announced = saved("seenWhatsNewVersion"), saved("whatsNewAnnounced")
    local told = newer(announced, seen) and announced or seen
    -- An install with no marker (an old /ed reset, or a popup never closed) is owed the newest release, as it always was
    if told == "" then return { RELEASES[1] } end
    local out = {}
    for _, release in ipairs(RELEASES) do
        if not newer(release.version, told) then break end
        out[#out + 1] = release
    end
    return out
end

local function hasFeatures(list)
    for _, release in ipairs(list) do
        if not release.fixesOnly then return true end
    end
    return false
end

local function dateOf(version)
    for _, entry in ipairs(E.Changelog or {}) do
        if entry.version == version then return entry.date or "" end
    end
    return ""
end

-- A block per release, because a block measures all its lines again for every line added
local function fill(ui, content, releases)
    local several = #releases > 1
    local muted = E.DelveList.cc("muted")
    local blocks = {}
    for _, release in ipairs(releases) do
        local block = ui:CreateTextBlock(content)
        local prev = blocks[#blocks]
        if prev then
            block:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -RELEASE_GAP)
            block:SetPoint("TOPRIGHT", prev, "BOTTOMRIGHT", 0, -RELEASE_GAP)
        else
            block:SetPoint("TOPLEFT", content, "TOPLEFT", PAD_SIDE, -PAD_TOP)
            block:SetPoint("TOPRIGHT", content, "TOPRIGHT", -PAD_SIDE, -PAD_TOP)
        end
        if several then
            block:AddLine(release.version .. "   " .. muted .. dateOf(release.version) .. "|r", "value")
        end
        for i, entry in ipairs(release.entries) do
            block:AddLine(entry.title, "title", { gap = (i > 1) and SECTION_GAP or (several and VERSION_GAP) or nil })
            block:AddLine(entry.desc, "label", { gap = HEAD_GAP })
        end
        blocks[#blocks + 1] = block
    end
    return blocks
end

local function build()
    if frame then return frame end
    local ui = E.ui
    -- Decided once, because a text block cannot be emptied, so a reopen in the same session shows the same notes
    local releases = pending or missed()
    if #releases == 0 then releases = { RELEASES[1] } end

    local f = ui:CreateWindow({ name = "EverythingDelvesWhatsNew", title = L["What's New"], width = WIDTH, height = HEIGHT })
    f:SetSection("Everything Delves" .. (#releases == 1 and (" " .. releases[1].version) or ""))
    f:AddHeaderButton("icon-discord", L["Join our Discord"], L["Click to copy the invite link."],
        function() E:ShowDiscord() end)
    -- An ancestor hide (Alt-Z) leaves IsShown true, so it does not count as seen
    f:HookScript("OnHide", function(self)
        if not self:IsShown() then markSeen() end
    end)

    local area = ui:CreateScrollArea(f.body, {})
    area:SetPoint("TOPLEFT", f.body, "TOPLEFT")
    area:SetPoint("BOTTOMRIGHT", f.body, "BOTTOMRIGHT", 0, FOOTER_H)
    local blocks = fill(ui, area.content, releases)

    local footer = CreateFrame("Frame", nil, f.body)
    footer:SetPoint("BOTTOMLEFT")
    footer:SetPoint("BOTTOMRIGHT")
    footer:SetHeight(FOOTER_H)
    footer._controls = {}
    ui:Paint(footer, "chrome", "divider", "T")

    f.dontShow = ui:CreateCheckbox(footer, L["Don't show these again"],
        function() return mode() == "none" end,
        function(on)
            if not E.db then return end
            -- Unticking puts back the mode the player had this session, so a chat link player is not moved to the popup
            local m = mode()
            if on and m ~= "none" then restoreMode = m end
            E.db.whatsNewMode = on and "none" or restoreMode or "popup"
            E:RefreshOptionsWidgets()
        end)
    f.dontShow:SetPoint("LEFT", footer, "LEFT", PAD_SIDE, 0)

    f.gotIt = ui:CreateButton(footer, L["Got it"], nil, function() f:Hide() end, nil, "primary")
    f.gotIt:SetPoint("RIGHT", footer, "RIGHT", -PAD_SIDE, 0)

    -- Text measured while hidden can be short of the text as drawn, so it is measured again once shown
    local function layout()
        local h = PAD_TOP + PAD_BOTTOM + RELEASE_GAP * (#blocks - 1)
        for _, block in ipairs(blocks) do h = h + block:Measure() end
        -- The scroll frame's own width, which leaves room for the bars, so the notes never scroll sideways
        local w = area.scroll:GetWidth() or 0
        if w <= 0 then w = WIDTH - BAR_ROOM end
        area:SetContentSize(w, h)
        f.gotIt:Fit()
    end
    layout()
    -- The settings window and /ed reset write the mode too, so the box is read again on every open
    f:HookScript("OnShow", function()
        f.dontShow:Refresh()
        C_Timer.After(0, layout)
    end)

    frame = f
    return f
end

function E.ShowWhatsNew()
    local f = build()
    f:Show()
    -- Over the settings window, whose About tab opens it
    f:Raise()
end

function E.RefreshWhatsNew()
    if frame and frame:IsShown() then frame.dontShow:Refresh() end
end

function E:SetWhatsNewMode(m)
    if not self.db then return end
    if m ~= "none" then restoreMode = m end
    self.db.whatsNewMode = m
    self:RefreshWhatsNew()
end

local LINK = "addon:EverythingDelves:whatsnew"

-- The game hands an addon link to SetItemRef and draws nothing for it, so a click on ours opens the notes here
hooksecurefunc("SetItemRef", function(link)
    if link == LINK then E:ShowWhatsNew() end
end)

local function announce(list)
    pending = list
    local cc = E.CC.header
    local link = "|H" .. LINK .. "|h" .. cc .. L["[See what's new]"] .. "|r|h"
    DEFAULT_CHAT_FRAME:AddMessage(L["%1$s updated to %2$s - %3$s"]:format(cc .. "Everything Delves|r", E.version, link))
    markAnnounced()
end

E:RegisterModule(function()
    -- A first install has nothing to catch up on
    if E.firstInstall then
        markSeen()
        markAnnounced()
        return
    end
    if not hasFeatures(missed()) then return end
    if mode() == "popup" then
        E:ShowWhatsNew()
    elseif mode() == "chat" then
        -- After the login lines, which would bury it
        C_Timer.After(3, function()
            local list = missed()
            if mode() == "chat" and hasFeatures(list) then announce(list) end
        end)
    end
end)
