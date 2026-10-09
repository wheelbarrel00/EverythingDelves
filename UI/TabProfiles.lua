local E = EverythingDelves
local L = E.L

local ED_TEXTURES = "Interface\\AddOns\\EverythingDelves\\Media\\Textures\\"
local CHECK_SIZE = 14
local NAME_GAP = 10

local refreshList

local function say(msg)
    print(E.CC.header .. "Everything Delves|r: " .. msg)
end

local function promptNewProfile()
    E:ShowDialog({
        text = L["Name for the new (empty) profile:"],
        button1 = L["Create"], button2 = L["Cancel"],
        hasEditBox = true, maxLetters = 32,
        onAccept = function(text)
            local name = strtrim(text or "")
            local ok, err = E:CreateProfile(name)
            if not ok then
                say(err or L["Could not create profile."])
            else
                say(L["Now using profile '%s'."]:format(name))
            end
            refreshList()
        end,
    })
end

local function promptDuplicate()
    E:ShowDialog({
        text = L["Name for the copy of the current profile:"],
        button1 = L["Duplicate"], button2 = L["Cancel"],
        hasEditBox = true, maxLetters = 32,
        onAccept = function(text)
            local name = strtrim(text or "")
            local ok, err = E:CopyProfile(E.activeProfileName, name)
            if not ok then
                say(err or L["Could not duplicate profile."])
            else
                say(L["Duplicated into '%s' and switched to it."]:format(name))
            end
            refreshList()
        end,
    })
end

local function confirmDelete(name)
    E:ShowDialog({
        text = L["Permanently delete profile '%s'?\n\nThis erases that profile's delve history. This cannot be undone."]:format(name),
        button1 = L["Delete"], button2 = L["Cancel"], danger = true,
        onAccept = function()
            local ok, err = E:DeleteProfile(name)
            if not ok then
                say(err or L["Could not delete profile."])
            else
                say(L["Deleted profile '%s'."]:format(tostring(name)))
            end
            refreshList()
        end,
    })
end

-- A profile name can be typed in any alphabet, so a second string in the client's own font object
-- draws what the UI font cannot. A SetFont on that string would drop the font object.
local function nameStrings(ui, parent)
    local plain = ui:CreateText(parent, "", "value")
    local data = parent:CreateFontString(nil, "OVERLAY")
    data:SetFontObject(GameFontHighlight)
    data:SetTextColor(ui:Color("text"))
    return plain, data
end

local function showName(ui, plain, data, name)
    local useData = ui:NeedsClientFont(name)
    plain:SetText(name)
    data:SetText(name)
    plain:SetShown(not useData)
    data:SetShown(useData)
    return useData and data or plain
end

local function infoCard(self, content, stack)
    local card = stack(self:CreateGroup(content, nil))
    local rows = {}
    for i, label in ipairs({ L["This character:"], L["Active profile:"] }) do
        local row = self:CreateTextRow(content, label, "")
        row.text:Hide()
        row.plain, row.data = nameStrings(self, row)
        row.plain:SetPoint("LEFT", row.text, "LEFT")
        row.data:SetPoint("LEFT", row.text, "LEFT")
        card:Add(row)
        rows[i] = row
    end
    return rows
end

local function profileRow(self, content, list, i)
    local pad, height = self:Spacing("rowPadding"), self:Spacing("rowHeight")
    -- Out past the card's inset to its edges, so the tint and the line between rows span it
    local row = CreateFrame("Frame", nil, list)
    row:SetHeight(height)
    row:SetPoint("TOPLEFT", list, "TOPLEFT", -pad, -(i - 1) * height)
    row:SetPoint("TOPRIGHT", list, "TOPRIGHT", pad, -(i - 1) * height)
    row.tint = row:CreateTexture(nil, "BACKGROUND")
    row.tint:SetAllPoints()
    row.tint:SetColorTexture(self:Color("accentSoft"))
    if i > 1 then self:Paint(row, nil, "divider", "T") end
    row.check = row:CreateTexture(nil, "ARTWORK")
    row.check:SetSize(CHECK_SIZE, CHECK_SIZE)
    row.check:SetPoint("LEFT", pad, 0)
    row.check:SetTexture(self:Texture("check"))
    row.check:SetVertexColor(self:Color("accentHi"))
    row.plain, row.data = nameStrings(self, row)
    row.plain:SetPoint("LEFT", row.check, "RIGHT", NAME_GAP, 0)
    row.data:SetPoint("LEFT", row.check, "RIGHT", NAME_GAP, 0)
    row.count = self:CreateText(row, "", "label")
    row.count:SetTextColor(self:Color("muted"))
    -- On the content rather than the row, so the window sizes them to their labels once on screen
    row.delete = self:CreateButton(content, L["Delete"], nil, function() confirmDelete(row.profile) end)
    row.switch = self:CreateButton(content, L["Switch"], nil, function()
        E:SwitchProfile(row.profile)
        refreshList()
    end)
    row.delete:SetPoint("RIGHT", row, "RIGHT", -pad, 0)
    row.switch:SetPoint("RIGHT", row.delete, "LEFT", -self:Spacing("buttonGap"), 0)
    row.delete:SetFrameLevel(row:GetFrameLevel() + 1)
    row.switch:SetFrameLevel(row:GetFrameLevel() + 1)
    return row
end

local function listCard(self, content, stack, info)
    local card = stack(self:CreateGroup(content, L["Profiles"]))
    local height = self:Spacing("rowHeight")
    local rows = {}

    local list = CreateFrame("Frame", nil, content)
    list._euiFill = true
    local slot = card:Add(list)

    local actions = CreateFrame("Frame", nil, content)
    actions:SetHeight(self:Spacing("buttonHeight"))
    actions._euiFill = true
    local newBtn = self:CreateButton(content, L["New Profile"], nil, promptNewProfile)
    newBtn:SetPoint("LEFT", actions, "LEFT")
    local copyBtn = self:CreateButton(content, L["Duplicate Current"], nil, promptDuplicate)
    copyBtn:SetPoint("LEFT", newBtn, "RIGHT", self:Spacing("buttonGap"), 0)
    card:Add(actions)

    local note = self:CreateTextBlock(content)
    local text = L["Profiles are per-character. Your delve history lives in the active profile; UI settings (colors, scale, alerts) stay account-wide.\nSwitching profiles never deletes data — it only changes which profile this character uses."]
    for line in (text .. "\n"):gmatch("([^\n]*)\n") do note:AddLine(line, "hint") end
    card:Add(note, { fitHeight = true })

    function refreshList()
        showName(self, info[1].plain, info[1].data, E.CharKey and E:CharKey() or "?")
        showName(self, info[2].plain, info[2].data, E.activeProfileName or "?")

        local usage = {}
        local sv = EverythingDelvesDB
        for _, pk in pairs(sv and sv.profileKeys or {}) do usage[pk] = (usage[pk] or 0) + 1 end

        local names = E:GetProfileNames()
        for i = #rows + 1, #names do rows[i] = profileRow(self, content, list, i) end
        for i, row in ipairs(rows) do
            local name = names[i]
            local active = name ~= nil and name == E.activeProfileName
            row:SetShown(name ~= nil)
            if name then
                row.profile = name
                local shown = showName(self, row.plain, row.data, name)
                local count = usage[name] or 0
                row.count:SetText((count == 1 and L["(%d char)"] or L["(%d chars)"]):format(count))
                row.count:ClearAllPoints()
                row.count:SetPoint("LEFT", shown, "RIGHT", NAME_GAP, 0)
            end
            row.check:SetShown(active)
            row.tint:SetShown(active)
            row.switch:SetShown(name ~= nil and not active)
            row.delete:SetShown(name ~= nil and not active)
        end
        local h = math.max(1, #names * height)
        list:SetHeight(h)
        slot:SetHeight(h)
        card:Layout()
        self:MeasureContent(content)
    end
end

E.ui:RegisterTab({
    id = "profiles", title = L["Profiles"], order = 40, icon = ED_TEXTURES .. "icon-person",
    build = function(self, content)
        local stack = E.CardStack(self)
        listCard(self, content, stack, infoCard(self, content, stack))
    end,
    refresh = function() refreshList() end,
})
