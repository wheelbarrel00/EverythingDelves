local E = EverythingDelves
local L = E.L

local EUI = LibStub("EverythingUI-1.0")

E.ui = EUI:NewContext({
    id      = "ED",
    title   = "Everything Delves",
    version = E.version,
    accent  = EUI.tokens.accents.ED.accent,
    L       = L,
    tooltip = function() return GameTooltip end,
    discord = function() E:ShowDiscord() end,
    -- Looked up here, not in the library, because the locale scanner skips Libs/ and would drop these keys
    labels  = {
        discord         = L["Join our Discord!"],
        discordTipTitle = L["Join our Discord"],
        discordTip      = L["Click to copy the invite link."],
    },
    getLastTab     = function() return E.db and E.db.lastOptionsTab end,
    setLastTab     = function(id) if E.db then E.db.lastOptionsTab = id end end,
    getWindowScale = function() return E.db and E.db.uiScale end,
    -- Not saved: UI Scale also sets the main window's scale, which takes the whole range, so the
    -- settings window's cap to the screen must not lower it
    setWindowScale = function() end,
})

-- Field by field, because the library raises on a field it does not know
function E:ShowDialog(opts)
    self.ui:ShowDialog({
        title            = "Everything Delves",
        text             = opts.text,
        button1          = opts.button1,
        button2          = opts.button2,
        onAccept         = opts.onAccept,
        onCancel         = opts.onCancel,
        hasEditBox       = opts.hasEditBox and true or nil,
        maxLetters       = opts.maxLetters,
        editBoxText      = opts.editBoxText,
        highlightEditBox = opts.highlightEditBox and true or nil,
        danger           = opts.danger and true or nil,
    })
end

function E.ClassRGB(ui, class)
    local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    if not c and class and C_ClassColor and C_ClassColor.GetClassColor then c = C_ClassColor.GetClassColor(class) end
    if c then return c.r, c.g, c.b end
    return ui:Color("text")
end

-- A name or realm can be in any alphabet, so each has a second string in the client's own font
function E.NamePair(ui, parent, style)
    local plain = ui:CreateText(parent, "", style)
    plain:SetWordWrap(false)
    local data = parent:CreateFontString(nil, "OVERLAY")
    data:SetFontObject(GameFontHighlight)
    data:SetJustifyH("LEFT")
    data:SetWordWrap(false)
    return { plain = plain, data = data }
end

function E.ShowNamePair(ui, pair, text, r, g, b)
    local useData = ui:NeedsClientFont(text)
    for _, fs in ipairs({ pair.plain, pair.data }) do
        fs:SetText(text)
        fs:SetTextColor(r, g, b)
    end
    pair.plain:SetShown(not useData)
    pair.data:SetShown(useData)
    return useData and pair.data or pair.plain
end

function E.CardStack(ui)
    local prev
    return function(card)
        if prev then
            card:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -ui:Spacing("groupGap"))
            card:SetPoint("TOPRIGHT", prev, "BOTTOMRIGHT", 0, -ui:Spacing("groupGap"))
        else
            card:SetPoint("TOPLEFT")
            card:SetPoint("TOPRIGHT")
        end
        prev = card
        return card
    end
end
