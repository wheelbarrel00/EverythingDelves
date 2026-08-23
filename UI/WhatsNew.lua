local E = EverythingDelves
local L = E.L

local WHATS_NEW_VERSION = "1.30.0"

local ENTRIES = {
    {
        title = "The Nemesis Strongbox tracker has been blank since Season 2 began",
        desc  = "The HUD counts the enemy packs by watching their marker on the map, and Season 2 renamed that marker. The addon was still looking for Season 1's, so the pack line never appeared once, on any character, in any Tier 4 or higher delve. It now knows both seasons.",
    },
    {
        title = "\"Grand Spoils earned!\" could appear with the Rager still alive",
        desc  = "Clicking the Sanctified Banner, spawning the Voidfused Rager and then dying to it made the HUD call the Grand Spoils earned the moment you loaded back in, and it stayed wrong for the rest of the run. The Rager now has to be genuinely gone, and loading screens no longer count.",
    },
    {
        title = "A death could bank the wrong pack count for the rest of the run",
        desc  = "The loading screen after a death counted every pack seen so far as killed. It looked right until you reloaded, when the objective could read something like 3/5 packs with two packs still alive.",
    },
    {
        title = "This window can be moved, and told not to come back",
        desc  = "Drag it anywhere and it remembers the spot. The new \"Don't show this again\" box stops it returning after future updates, and Options has a matching setting if you change your mind. You can always reopen it from the About tab or with /ed whatsnew.",
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
