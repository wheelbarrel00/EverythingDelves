local E = EverythingDelves

local ipairs = ipairs
local math_max, math_min = math.max, math.min

local COMMANDS = {
    { cmd = "/ed",          desc = "Open or close the main window" },
    { cmd = "/ed obj",      desc = "Toggle the Bonus Spoils tracker (also /ed spoils)" },
    { cmd = "/ed curios",   desc = "Toggle the curio reminder popup" },
    { cmd = "/ed whatsnew", desc = "Show the What's New popup again" },
    { cmd = "/ed about",    desc = "Open this About tab" },
    { cmd = "/ed reset",    desc = "Reset all settings to defaults" },
}

local CURSEFORGE_URL = "https://www.curseforge.com/wow/addons/everything-delves"
local GITHUB_URL     = "https://github.com/wheelbarrel00/EverythingDelves"
local BUG_URL        = "https://github.com/wheelbarrel00/EverythingDelves/issues"

local OTHER_ADDONS = {
    { name = "Everything Quests",
      cf   = "https://www.curseforge.com/wow/addons/everything-quests",
      gh   = "https://github.com/wheelbarrel00/EverythingQuests" },
    { name = "Loot Pro",
      cf   = "https://www.curseforge.com/wow/addons/loot-pro",
      gh   = "https://github.com/wheelbarrel00/LootPro" },
}

local THANKS = "BanditC64, Puzzleheaded-Pie-506, 8six753o9, herky4life"

E:RegisterModule(function()
    local frame = CreateFrame("Frame", "EverythingDelvesTab10Content")

    local scrollFrame = CreateFrame("ScrollFrame", nil, frame)
    scrollFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -18, 0)
    scrollFrame:EnableMouseWheel(true)

    local sc = CreateFrame("Frame")
    sc:SetSize(1, 1)
    scrollFrame:SetScrollChild(sc)
    scrollFrame:SetScript("OnSizeChanged", function(_, w)
        sc:SetWidth(w)
    end)
    sc:SetHeight(1)

    local tabScrollBar = CreateFrame("Slider", nil, scrollFrame, "BackdropTemplate")
    tabScrollBar:SetWidth(14)
    tabScrollBar:SetPoint("TOPRIGHT", scrollFrame, "TOPRIGHT", 16, 0)
    tabScrollBar:SetPoint("BOTTOMRIGHT", scrollFrame, "BOTTOMRIGHT", 16, 0)
    tabScrollBar:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    tabScrollBar:SetBackdropColor(0.08, 0.08, 0.08, 0.90)
    tabScrollBar:SetBackdropBorderColor(0.25, 0.25, 0.25, 0.50)
    local sbThumb = tabScrollBar:CreateTexture(nil, "OVERLAY")
    sbThumb:SetSize(12, 40)
    E:StyleAccentThumb(sbThumb)
    tabScrollBar:SetThumbTexture(sbThumb)
    tabScrollBar:SetOrientation("VERTICAL")
    tabScrollBar:SetMinMaxValues(0, 1)
    tabScrollBar:SetValue(0)
    tabScrollBar:SetValueStep(1)
    tabScrollBar:SetObeyStepOnDrag(true)
    tabScrollBar:SetScript("OnValueChanged", function(_, value)
        scrollFrame:SetVerticalScroll(value)
    end)
    scrollFrame:SetScript("OnMouseWheel", function(self, delta)
        local maxScroll = math_max(0, sc:GetHeight() - self:GetHeight())
        local newVal = math_max(0, math_min(
            self:GetVerticalScroll() - delta * 30, maxScroll))
        self:SetVerticalScroll(newVal)
        tabScrollBar:SetValue(newVal)
    end)
    local function UpdateScrollRange()
        local maxScroll = math_max(0, sc:GetHeight() - scrollFrame:GetHeight())
        tabScrollBar:SetMinMaxValues(0, maxScroll)
        if maxScroll <= 0 then tabScrollBar:Hide() else tabScrollBar:Show() end
    end
    scrollFrame:SetScript("OnShow", UpdateScrollRange)

    local LEFT = 10
    local WRAP = 540          -- fixed wrap width (sc width isn't resolved at init)
    local Y    = -8

    local function header(text)
        local fs = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        fs:SetPoint("TOPLEFT", sc, "TOPLEFT", LEFT, Y)
        fs:SetFont(fs:GetFont(), E.HEADER_FONT_SIZE, "OUTLINE")
        E:StyleAccentHeader(fs, text)
        local line = sc:CreateTexture(nil, "ARTWORK")
        line:SetHeight(1)
        line:SetPoint("TOPLEFT",  fs, "BOTTOMLEFT", 0,   -2)
        line:SetPoint("TOPRIGHT", fs, "BOTTOMLEFT", 545, -2)
        E:StyleGreyLine(line)
        Y = Y - 24
    end

    local function body(text, indent, size)
        local fs = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        fs:SetPoint("TOPLEFT", sc, "TOPLEFT", LEFT + (indent or 0), Y)
        fs:SetFont(fs:GetFont(), size or 11)
        fs:SetWidth(WRAP - (indent or 0))
        fs:SetJustifyH("LEFT")
        fs:SetWordWrap(true)
        fs:SetText(text)
        local h = fs:GetStringHeight() or (size or 11)
        if h < (size or 11) then h = (size or 11) end
        Y = Y - h - 3
    end

    local function gap(px) Y = Y - (px or 8) end

    local function makeLink(label, onClick)
        local b = CreateFrame("Button", nil, sc)
        b:SetHeight(16)
        local t = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        t:SetPoint("LEFT", b, "LEFT", 0, 0)
        t:SetFont(t:GetFont(), 11)
        t:SetText(label)
        b.text = t
        b:SetWidth((t:GetStringWidth() or 40) + 2)
        b:SetScript("OnClick", onClick)
        b:SetScript("OnEnter", function(self) self.text:SetTextColor(1, 1, 1) end)
        b:SetScript("OnLeave", function(self)
            local ac = E:GetAccentColor()
            self.text:SetTextColor(ac.r, ac.g, ac.b)
        end)
        local ac = E:GetAccentColor()
        t:SetTextColor(ac.r, ac.g, ac.b)
        E:RegisterThemed(function()
            local a = E:GetAccentColor()
            t:SetTextColor(a.r, a.g, a.b)
        end)
        return b
    end

    local function linkRow(links)
        local prev
        for i, lk in ipairs(links) do
            local b = makeLink(lk.label, lk.onClick)
            if i == 1 then
                b:SetPoint("TOPLEFT", sc, "TOPLEFT", LEFT, Y)
            else
                local sep = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                sep:SetFont(sep:GetFont(), 11)
                sep:SetText(E.CC.muted .. "  |  " .. E.CC.close)
                sep:SetPoint("LEFT", prev, "RIGHT", 2, 0)
                b:SetPoint("LEFT", sep, "RIGHT", 2, 0)
            end
            prev = b
        end
        Y = Y - 24
    end

    local title = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", sc, "TOPLEFT", LEFT, Y)
    title:SetFont(title:GetFont(), 22, "OUTLINE")
    E:StyleAccentHeader(title, "Everything Delves")
    Y = Y - 26

    local sub = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    sub:SetPoint("TOPLEFT", sc, "TOPLEFT", LEFT, Y)
    sub:SetFont(sub:GetFont(), 11)
    sub:SetText(
        E.CC.gold .. "v" .. (E.version or "?") .. E.CC.close
        .. E.CC.muted .. "    by Wheelbarrel00    -    for WoW Midnight (12.0.x)"
        .. E.CC.close)
    Y = Y - 22

    body(E.CC.body .. "A complete Delves companion: track delve locations,"
        .. " bountiful status, coffer key shards, tiers, your run history,"
        .. " and more - all in one window." .. E.CC.close)
    gap(10)

    linkRow({
        { label = "Join our Discord", onClick = function() E:ShowDiscord() end },
        { label = "CurseForge",       onClick = function() E:ShowURL(CURSEFORGE_URL) end },
        { label = "GitHub",           onClick = function() E:ShowURL(GITHUB_URL) end },
        { label = "Report a Bug",     onClick = function() E:ShowURL(BUG_URL) end },
        { label = "What's New",       onClick = function() if E.ShowWhatsNew then E:ShowWhatsNew() end end },
    })
    gap(8)

    header("Commands")
    gap(2)
    for _, c in ipairs(COMMANDS) do
        local cmd = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        cmd:SetPoint("TOPLEFT", sc, "TOPLEFT", LEFT, Y)
        cmd:SetFont(cmd:GetFont(), 11)
        cmd:SetText(E.CC.gold .. c.cmd .. E.CC.close)
        local d = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        d:SetPoint("TOPLEFT", sc, "TOPLEFT", LEFT + 110, Y)
        d:SetFont(d:GetFont(), 11)
        d:SetText(E.CC.body .. c.desc .. E.CC.close)
        Y = Y - 18
    end
    gap(2)
    body(E.CC.muted .. "Tip: right-click the minimap button to jump to Options."
        .. " For support, the author may ask you to run a debug command."
        .. E.CC.close, 0, 10)
    gap(10)

    header("Tutorials")
    gap(2)
    body(E.CC.muted .. "Video tutorials are coming soon - watch this space."
        .. E.CC.close)
    gap(10)

    header("More Add-ons by Wheelbarrel00")
    gap(2)
    for _, a in ipairs(OTHER_ADDONS) do
        local n = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        n:SetPoint("TOPLEFT", sc, "TOPLEFT", LEFT, Y)
        n:SetFont(n:GetFont(), 11)
        n:SetText(E.CC.body .. a.name .. E.CC.close)
        local cfLink = makeLink("CurseForge", function() E:ShowURL(a.cf) end)
        cfLink:SetPoint("LEFT", n, "LEFT", 160, 0)
        local sep = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        sep:SetFont(sep:GetFont(), 11)
        sep:SetText(E.CC.muted .. "  |  " .. E.CC.close)
        sep:SetPoint("LEFT", cfLink, "RIGHT", 2, 0)
        local ghLink = makeLink("GitHub", function() E:ShowURL(a.gh) end)
        ghLink:SetPoint("LEFT", sep, "RIGHT", 2, 0)
        Y = Y - 20
    end
    gap(10)

    header("Thanks")
    gap(2)
    body(E.CC.body .. "Built with feedback, reports, and ideas from the"
        .. " community - especially " .. E.CC.gold .. THANKS .. E.CC.close
        .. E.CC.body .. ". Thank you!" .. E.CC.close)
    gap(10)

    header("Changelog")
    gap(2)
    for _, entry in ipairs(E.Changelog or {}) do
        local vh = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        vh:SetPoint("TOPLEFT", sc, "TOPLEFT", LEFT, Y)
        vh:SetFont(vh:GetFont(), 12, "OUTLINE")
        vh:SetText(E.CC.gold .. "v" .. entry.version .. E.CC.close
            .. E.CC.muted .. "    " .. (entry.date or "") .. E.CC.close)
        Y = Y - 18
        for _, sec in ipairs(entry.sections or {}) do
            local sh = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            sh:SetPoint("TOPLEFT", sc, "TOPLEFT", LEFT + 8, Y)
            sh:SetFont(sh:GetFont(), 10, "OUTLINE")
            sh:SetText(E.CC.header .. sec.head .. E.CC.close)
            Y = Y - 15
            for _, item in ipairs(sec.items or {}) do
                body(E.CC.body .. "- " .. item .. E.CC.close, 16, 10)
            end
            gap(2)
        end
        gap(8)
    end

    local older = makeLink("Older versions are on CurseForge", function()
        E:ShowURL(CURSEFORGE_URL)
    end)
    older:SetPoint("TOPLEFT", sc, "TOPLEFT", LEFT, Y)
    Y = Y - 28

    sc:SetHeight(math_max(1, -Y + 10))
    UpdateScrollRange()

    E:RegisterTab(10, frame)
end)
