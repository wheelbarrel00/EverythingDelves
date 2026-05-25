------------------------------------------------------------------------
-- UI/WhatsNew.lua — What's New popup
-- Shows once per feature release. Update WHATS_NEW_VERSION and the
-- ENTRIES table each release; everything else is automatic.
------------------------------------------------------------------------
local E = EverythingDelves

local WHATS_NEW_VERSION = "1.9.0"

local ENTRIES = {
    {
        title = "Story Variants \226\128\148 Now for Every Delve",
        desc  = "Delve History now records the actual story variant for every run, not just Bountiful ones. The Delve Locations tab also gained a \"This Week's Story\" column showing each delve's current variant at a glance. Thanks to BanditC64 for the idea!",
    },
    {
        title = "Window Fits Every Tab",
        desc  = "The main window now sizes itself to fit the full row of tabs, so the Profiles tab no longer spills off the right edge in the default UI font.",
    },
}

local POPUP_W  = 460
local PAD      = 12
local ENTRY_H  = 62
local HEADER_H = 40
local FOOTER_H = 50
local popupH   = HEADER_H + (#ENTRIES * ENTRY_H) + FOOTER_H

E:RegisterModule(function()
    local popup = CreateFrame("Frame", "EverythingDelvesWhatsNewPopup", UIParent, "BackdropTemplate")
    popup:SetSize(POPUP_W, popupH)
    popup:SetFrameStrata("DIALOG")
    popup:SetClampedToScreen(true)
    popup:SetPoint("CENTER", UIParent, "CENTER", 0, 60)
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
    titleFS:SetPoint("TOPLEFT", popup, "TOPLEFT", PAD, -8)
    titleFS:SetFont(titleFS:GetFont(), E.HEADER_FONT_SIZE, "OUTLINE")
    titleFS:SetText(
        E.CC.header .. "What's New" .. E.CC.close
        .. E.CC.muted .. "  \226\128\148  v" .. WHATS_NEW_VERSION .. E.CC.close
    )

    local titleDiv = popup:CreateTexture(nil, "ARTWORK")
    titleDiv:SetHeight(1)
    titleDiv:SetPoint("TOPLEFT",  popup, "TOPLEFT",  1, -26)
    titleDiv:SetPoint("TOPRIGHT", popup, "TOPRIGHT", -1, -26)
    E:StyleAccentDivider(titleDiv)

    -- Feature rows
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

    -- Dismiss button
    local btn = E:CreateButton(popup, 100, 24, "Got it")
    btn:SetPoint("BOTTOM", popup, "BOTTOM", 0, 16)
    btn:SetScript("OnClick", function()
        E.db.seenWhatsNewVersion = WHATS_NEW_VERSION
        popup:Hide()
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
        if (E.db.seenWhatsNewVersion or "") ~= WHATS_NEW_VERSION then
            popup:Show()
        end
    end

    -- Show on first login after this release
    MaybeShow()

    -- Public accessor for /ed whatsnew preview
    function E:ShowWhatsNew()
        popup:Show()
    end
end)
