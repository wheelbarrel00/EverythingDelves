local E = EverythingDelves
local L = E.L

local WHATS_NEW_VERSION = "2.1.0"

local ENTRIES = {
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
}

local WIDTH, HEIGHT = 600, 560
local PAD_TOP, PAD_SIDE, PAD_BOTTOM = 20, 24, 24
local HEAD_GAP, SECTION_GAP = 4, 16
local FOOTER_H, BAR_ROOM = 56, 10

local frame

local function markSeen()
    if E.db then E.db.seenWhatsNewVersion = WHATS_NEW_VERSION end
end

local function build()
    if frame then return frame end
    local ui = E.ui

    local f = ui:CreateWindow({ name = "EverythingDelvesWhatsNew", title = L["What's New"], width = WIDTH, height = HEIGHT })
    f:SetSection("Everything Delves " .. WHATS_NEW_VERSION)
    f:AddHeaderButton("icon-discord", L["Join our Discord"], L["Click to copy the invite link."],
        function() E:ShowDiscord() end)
    -- Closing it any way at all, Escape included, counts as having seen it
    f:HookScript("OnHide", markSeen)

    local area = ui:CreateScrollArea(f.body, {})
    area:SetPoint("TOPLEFT", f.body, "TOPLEFT")
    area:SetPoint("BOTTOMRIGHT", f.body, "BOTTOMRIGHT", 0, FOOTER_H)
    local notes = ui:CreateTextBlock(area.content)
    notes:SetPoint("TOPLEFT", area.content, "TOPLEFT", PAD_SIDE, -PAD_TOP)
    notes:SetPoint("TOPRIGHT", area.content, "TOPRIGHT", -PAD_SIDE, -PAD_TOP)
    for i, entry in ipairs(ENTRIES) do
        notes:AddLine(entry.title, "title", { gap = (i > 1) and SECTION_GAP or nil })
        notes:AddLine(entry.desc, "label", { gap = HEAD_GAP })
    end

    local footer = CreateFrame("Frame", nil, f.body)
    footer:SetPoint("BOTTOMLEFT")
    footer:SetPoint("BOTTOMRIGHT")
    footer:SetHeight(FOOTER_H)
    footer._controls = {}
    ui:Paint(footer, "chrome", "divider", "T")

    f.dontShow = ui:CreateCheckbox(footer, L["Don't show this again"],
        function() return E.db and E.db.showWhatsNew == false end,
        function(on)
            if E.db then E.db.showWhatsNew = not on end
            E:RefreshOptionsWidgets()
        end)
    f.dontShow:SetPoint("LEFT", footer, "LEFT", PAD_SIDE, 0)

    f.gotIt = ui:CreateButton(footer, L["Got it"], nil, function() f:Hide() end, nil, "primary")
    f.gotIt:SetPoint("RIGHT", footer, "RIGHT", -PAD_SIDE, 0)

    -- Text measured while hidden can be short of the text as drawn, so it is measured again once shown
    local function layout()
        local h = PAD_TOP + notes:Measure() + PAD_BOTTOM
        -- The scroll frame's own width, which leaves room for the bars, so the notes never scroll sideways
        local w = area.scroll:GetWidth() or 0
        if w <= 0 then w = WIDTH - BAR_ROOM end
        area:SetContentSize(w, h)
        f.gotIt:Fit()
    end
    layout()
    -- The settings window and /ed reset write showWhatsNew too, so the box is read again on every open
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

E:RegisterModule(function()
    if E.db.showWhatsNew == false then return end
    if (E.db.seenWhatsNewVersion or "") ~= WHATS_NEW_VERSION then
        E:ShowWhatsNew()
    end
end)
