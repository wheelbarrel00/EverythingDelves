local E = EverythingDelves
local L = E.L

local WHATS_NEW_VERSION = "1.33.0"

local ENTRIES = {
    {
        title = "The tracker no longer asks you to find the Sanctified Banner",
        desc  = "Blizzard retired the Sanctified Banner when Midnight Season 1 ended, but the Bonus Spoils tracker still listed it on every bountiful run as loot you had not collected yet. It was asking for something nobody could find. The tracker now follows the Nemesis Strongbox packs alone. Thanks to LightsBeacon for the report.",
    },
    {
        title = "The tracker could tell you the bonus loot was done when it was not",
        desc  = "Two ways. Entering a Tier 4 or higher delve showed a green \"All bonus loot accounted for.\" before the first pack appeared. And any loading screen mid-run, a death and release included, briefly empties the vignette list, which read as every remaining pack being killed. Both now wait until they know.",
    },
    {
        title = "The Season Max tooltip explained the wrong rule",
        desc  = "It said Season Max is the most of a crest you can earn all season. For some crests the number caps how many you can hold at once instead, and spending frees room again. The tooltip now covers both.",
    },
    {
        title = "The last English buttons are translated",
        desc  = "The Pin buttons on Delve Locations, Current Bountiful and the Shard Tracker, and the Dismiss button on the Trovehunter reminder, stayed English on translated clients even though the headers beside them were translated.",
    },
    {
        title = "The Poison row finally has an icon",
        desc  = "Combat and Utility have always shown their item art, but the poisons are a choice node rather than items, so the row beneath sat bare. All six now show their own spell art, in the delve HUD and the curio popup. The IDs came from the trait data, not a name lookup: two spells are both named \"Frostheart Venom\" with different icons.",
    },
}

local POPUP_W  = 460
local PAD      = 12
local ENTRY_H  = 74
local HEADER_H = 40
local FOOTER_H = 74
local popupH   = HEADER_H + (#ENTRIES * ENTRY_H) + FOOTER_H

E:RegisterModule(function()
    local popup = CreateFrame("Frame", "EverythingDelvesWhatsNewPopup", UIParent, "BackdropTemplate")
    popup:SetSize(POPUP_W, popupH)
    popup:SetFrameStrata("DIALOG")
    popup:SetClampedToScreen(true)
    popup:SetMovable(true)
    popup:EnableMouse(true)
    popup:RegisterForDrag("LeftButton")

    local pos = E.db and E.db.whatsNewPos
    if pos and pos.point then
        popup:SetPoint(pos.point, UIParent, pos.relPoint or pos.point,
            pos.x or 0, pos.y or 0)
    else
        popup:SetPoint("CENTER", UIParent, "CENTER", 0, 60)
    end

    popup:SetScript("OnDragStart", popup.StartMoving)
    popup:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relPoint, x, y = self:GetPoint(1)
        if E.db then
            E.db.whatsNewPos = { point = point, relPoint = relPoint, x = x, y = y }
        end
    end)
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
    titleFS:SetPoint("TOPLEFT", popup, "TOPLEFT", PAD, -8)
    titleFS:SetFont(titleFS:GetFont(), E.HEADER_FONT_SIZE, "OUTLINE")
    titleFS:SetText(
        E.CC.header .. L["What's New"] .. E.CC.close
        .. E.CC.muted .. "  \226\128\148  v" .. WHATS_NEW_VERSION .. E.CC.close
    )

    local titleDiv = popup:CreateTexture(nil, "ARTWORK")
    titleDiv:SetHeight(1)
    titleDiv:SetPoint("TOPLEFT",  popup, "TOPLEFT",  1, -26)
    titleDiv:SetPoint("TOPRIGHT", popup, "TOPRIGHT", -1, -26)
    E:StyleAccentDivider(titleDiv)

    local Y = -(HEADER_H - 2)
    for _, entry in ipairs(ENTRIES) do
        local tf = popup:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        tf:SetPoint("TOPLEFT", popup, "TOPLEFT", PAD, Y)
        tf:SetWidth(POPUP_W - PAD * 2)
        tf:SetFont(tf:GetFont(), 11, "OUTLINE")
        tf:SetJustifyH("LEFT")
        tf:SetText(E.CC.gold .. entry.title .. E.CC.close)

        local df = popup:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        df:SetPoint("TOPLEFT", popup, "TOPLEFT", PAD, Y - 17)
        df:SetWidth(POPUP_W - PAD * 2)
        df:SetFont(df:GetFont(), 10)
        df:SetJustifyH("LEFT")
        df:SetWordWrap(true)
        df:SetText(E.CC.body .. entry.desc .. E.CC.close)

        Y = Y - ENTRY_H
    end

    local neverCB = CreateFrame("CheckButton", nil, popup, "UICheckButtonTemplate")
    neverCB:SetSize(22, 22)
    neverCB:SetPoint("BOTTOMLEFT", popup, "BOTTOMLEFT", PAD, 44)
    neverCB:SetChecked(E.db and E.db.showWhatsNew == false)
    local neverFS = neverCB:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    neverFS:SetPoint("LEFT", neverCB, "RIGHT", 4, 0)
    neverFS:SetFont(neverFS:GetFont(), 11)
    neverFS:SetText(E.CC.body .. L["Don't show this again"] .. E.CC.close)
    neverCB:SetScript("OnClick", function(self)
        if E.db then E.db.showWhatsNew = not self:GetChecked() end
        if E.RefreshOptionsWidgets then E:RefreshOptionsWidgets() end
    end)

    local btn = E:CreateButton(popup, 100, 24, L["Got it"])
    btn:SetPoint("BOTTOM", popup, "BOTTOM", 60, 16)
    btn:SetScript("OnClick", function()
        E.db.seenWhatsNewVersion = WHATS_NEW_VERSION
        popup:Hide()
    end)

    -- Intentionally does NOT mark the popup seen, so the player can grab the invite and keep reading.
    local discordBtn = CreateFrame("Button", nil, popup, "BackdropTemplate")
    discordBtn:SetHeight(24)
    local dBg = discordBtn:CreateTexture(nil, "BACKGROUND")
    dBg:SetAllPoints()
    dBg:SetColorTexture(0.10, 0.10, 0.10, 0.95)
    discordBtn.icon = discordBtn:CreateTexture(nil, "OVERLAY")
    discordBtn.icon:SetSize(16, 16)
    discordBtn.icon:SetPoint("LEFT", 10, 0)
    discordBtn.icon:SetTexture("Interface\\AddOns\\EverythingDelves\\Media\\Textures\\discord.tga")
    discordBtn.text = discordBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    discordBtn.text:SetPoint("LEFT", discordBtn.icon, "RIGHT", 6, 0)
    discordBtn.text:SetText(L["Join our Discord!"])
    discordBtn:SetWidth(10 + 16 + 6 + discordBtn.text:GetStringWidth() + 12)
    discordBtn:SetPoint("RIGHT", btn, "LEFT", -10, 0)
    discordBtn:SetScript("OnClick", function() E:ShowDiscord() end)
    discordBtn:SetScript("OnEnter", function(self)
        self.text:SetTextColor(1, 1, 1)
    end)
    discordBtn:SetScript("OnLeave", function(self)
        local ac = E:GetAccentColor()
        self.text:SetTextColor(ac.r, ac.g, ac.b)
    end)
    E:RegisterThemed(function()
        local ac = E:GetAccentColor()
        discordBtn.text:SetTextColor(ac.r, ac.g, ac.b)
    end)
    btn:SetScript("OnEnter", function(self)
        local hc = E.Colors.buttonHover
        self:SetBackdropColor(hc.r, hc.g, hc.b, hc.a)
    end)
    btn:SetScript("OnLeave", function(self)
        local bc = E.Colors.buttonBg
        self:SetBackdropColor(bc.r, bc.g, bc.b, bc.a)
    end)

    local function MaybeShow()
        if E.db.showWhatsNew == false then return end
        if (E.db.seenWhatsNewVersion or "") ~= WHATS_NEW_VERSION then
            popup:Show()
        end
    end

    MaybeShow()

    -- The Options tab and /ed reset write showWhatsNew too, so resync on every open.
    function E:ShowWhatsNew()
        neverCB:SetChecked(E.db and E.db.showWhatsNew == false)
        popup:Show()
    end
end)
