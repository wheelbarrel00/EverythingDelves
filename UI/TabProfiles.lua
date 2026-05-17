------------------------------------------------------------------------
-- UI/TabProfiles.lua — Tab 7: Profiles
--
-- Delve history / completion marks / mid-run state are per-character
-- (stored in EverythingDelvesDB.profiles, see InitDB). This tab lets a
-- player view the active profile, switch to another, create a fresh
-- one, duplicate the current one, or delete an unused one. Every
-- operation here is non-destructive to other profiles — switching
-- never erases data, it just changes which profile this character
-- reads/writes.
------------------------------------------------------------------------
local E = EverythingDelves

local math_max, math_min = math.max, math.min

E:RegisterModule(function()
    local frame = CreateFrame("Frame", "EverythingDelvesTabProfilesContent")

    --------------------------------------------------------------------
    -- Scroll scaffolding (matches the other tabs)
    --------------------------------------------------------------------
    local scrollFrame = CreateFrame("ScrollFrame", nil, frame)
    scrollFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -18, 4)
    scrollFrame:EnableMouseWheel(true)

    local content = CreateFrame("Frame")
    content:SetWidth(scrollFrame:GetWidth() or 580)
    scrollFrame:SetScrollChild(content)
    scrollFrame:SetScript("OnSizeChanged", function(_, w) content:SetWidth(w) end)

    local sb = CreateFrame("Slider", nil, scrollFrame, "BackdropTemplate")
    sb:SetWidth(14)
    sb:SetPoint("TOPRIGHT", scrollFrame, "TOPRIGHT", 16, 0)
    sb:SetPoint("BOTTOMRIGHT", scrollFrame, "BOTTOMRIGHT", 16, 0)
    sb:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    sb:SetBackdropColor(0.08, 0.08, 0.08, 0.90)
    sb:SetBackdropBorderColor(0.25, 0.25, 0.25, 0.50)
    local thumb = sb:CreateTexture(nil, "OVERLAY")
    thumb:SetSize(12, 40)
    E:StyleAccentThumb(thumb)
    sb:SetThumbTexture(thumb)
    sb:SetOrientation("VERTICAL")
    sb:SetMinMaxValues(0, 1)
    sb:SetValue(0)
    sb:SetValueStep(1)
    sb:SetObeyStepOnDrag(true)
    sb:SetScript("OnValueChanged", function(_, v) scrollFrame:SetVerticalScroll(v) end)
    scrollFrame:SetScript("OnMouseWheel", function(self, delta)
        local maxS = math_max(0, content:GetHeight() - self:GetHeight())
        local nv = math_max(0, math_min(self:GetVerticalScroll() - delta * 30, maxS))
        self:SetVerticalScroll(nv)
        sb:SetValue(nv)
    end)
    local function UpdateScrollRange()
        local maxS = math_max(0, content:GetHeight() - scrollFrame:GetHeight())
        sb:SetMinMaxValues(0, maxS)
        if maxS <= 0 then sb:Hide() else sb:Show() end
    end

    local SECT_X = 8

    --------------------------------------------------------------------
    -- Header + readouts
    --------------------------------------------------------------------
    local header = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    header:SetPoint("TOPLEFT", content, "TOPLEFT", SECT_X, -6)
    header:SetFont(header:GetFont(), E.HEADER_FONT_SIZE, "OUTLINE")
    E:StyleAccentHeader(header, "Profiles")

    local charFS = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    charFS:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -8)
    charFS:SetFont(charFS:GetFont(), 11)

    local activeFS = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    activeFS:SetPoint("TOPLEFT", charFS, "BOTTOMLEFT", 0, -4)
    activeFS:SetFont(activeFS:GetFont(), 12)

    local div1 = content:CreateTexture(nil, "ARTWORK")
    div1:SetHeight(1)
    div1:SetPoint("TOPLEFT", activeFS, "BOTTOMLEFT", 0, -10)
    div1:SetPoint("RIGHT", content, "RIGHT", -8, 0)
    E:StyleAccentDivider(div1)

    --------------------------------------------------------------------
    -- Dynamic profile-row pool
    --------------------------------------------------------------------
    local ROW_H = 26
    local rowPool = {}

    local function AcquireRow(i)
        local row = rowPool[i]
        if row then return row end
        row = CreateFrame("Frame", nil, content)
        row:SetHeight(ROW_H)

        row.nameFS = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        row.nameFS:SetPoint("LEFT", row, "LEFT", 4, 0)
        row.nameFS:SetFont(row.nameFS:GetFont(), 12)
        row.nameFS:SetJustifyH("LEFT")

        row.useBtn = E:CreateButton(row, 70, 20, "Switch")
        row.useBtn:SetPoint("RIGHT", row, "RIGHT", -4, 0)

        row.delBtn = E:CreateButton(row, 70, 20, "Delete")
        row.delBtn:SetPoint("RIGHT", row.useBtn, "LEFT", -6, 0)

        rowPool[i] = row
        return row
    end

    -- Forward declaration so popups can request a rebuild.
    local Rebuild

    --------------------------------------------------------------------
    -- Confirmation / input popups
    --
    -- WoW's GameDialog StaticPopup exposes the edit box as `.EditBox`
    -- (capitalised) in modern clients; older clients used `.editBox`.
    -- Resolve defensively so this works regardless of client version
    -- and isn't broken by UI replacers (ElvUI/Eltruism etc.).
    --------------------------------------------------------------------
    local function PopupEditBox(dialog)
        if not dialog then return nil end
        return dialog.EditBox or dialog.editBox
            or (dialog.GetName and dialog:GetName()
                and _G[dialog:GetName() .. "EditBox"])
    end

    local function ReadName(dialog)
        local eb = PopupEditBox(dialog)
        return eb and strtrim(eb:GetText() or "") or ""
    end

    StaticPopupDialogs["EVERYTHINGDELVES_NEWPROFILE"] = {
        text = "Name for the new (empty) profile:",
        button1 = "Create",
        button2 = "Cancel",
        hasEditBox = true,
        maxLetters = 32,
        OnShow = function(self)
            local eb = PopupEditBox(self)
            if eb then eb:SetText(""); eb:SetFocus() end
        end,
        OnAccept = function(self)
            local name = ReadName(self)
            local ok, err = E:CreateProfile(name)
            if not ok then
                print(E.CC.header .. "Everything Delves|r: " .. (err or "Could not create profile."))
            else
                print(E.CC.header .. "Everything Delves|r: Now using profile '" .. name .. "'.")
            end
            if Rebuild then Rebuild() end
        end,
        EditBoxOnEnterPressed = function(editBox)
            local dialog = editBox:GetParent()
            local name = strtrim(editBox:GetText() or "")
            local ok, err = E:CreateProfile(name)
            if not ok then
                print(E.CC.header .. "Everything Delves|r: " .. (err or "Could not create profile."))
            end
            if Rebuild then Rebuild() end
            if dialog and dialog.Hide then dialog:Hide() end
        end,
        EditBoxOnEscapePressed = function(editBox)
            local d = editBox:GetParent()
            if d and d.Hide then d:Hide() end
        end,
        timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
    }

    StaticPopupDialogs["EVERYTHINGDELVES_COPYPROFILE"] = {
        text = "Name for the copy of the current profile:",
        button1 = "Duplicate",
        button2 = "Cancel",
        hasEditBox = true,
        maxLetters = 32,
        OnShow = function(self)
            local eb = PopupEditBox(self)
            if eb then eb:SetText(""); eb:SetFocus() end
        end,
        OnAccept = function(self)
            local name = ReadName(self)
            local ok, err = E:CopyProfile(E.activeProfileName, name)
            if not ok then
                print(E.CC.header .. "Everything Delves|r: " .. (err or "Could not duplicate profile."))
            else
                print(E.CC.header .. "Everything Delves|r: Duplicated into '" .. name .. "' and switched to it.")
            end
            if Rebuild then Rebuild() end
        end,
        EditBoxOnEnterPressed = function(editBox)
            local dialog = editBox:GetParent()
            local name = strtrim(editBox:GetText() or "")
            E:CopyProfile(E.activeProfileName, name)
            if Rebuild then Rebuild() end
            if dialog and dialog.Hide then dialog:Hide() end
        end,
        EditBoxOnEscapePressed = function(editBox)
            local d = editBox:GetParent()
            if d and d.Hide then d:Hide() end
        end,
        timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
    }

    StaticPopupDialogs["EVERYTHINGDELVES_DELETEPROFILE"] = {
        text = "Permanently delete profile '%s'?\n\n"
            .. "This erases that profile's delve history and completion "
            .. "marks. This cannot be undone.",
        button1 = "Delete",
        button2 = "Cancel",
        OnAccept = function(_, data)
            local ok, err = E:DeleteProfile(data)
            if not ok then
                print(E.CC.header .. "Everything Delves|r: " .. (err or "Could not delete profile."))
            else
                print(E.CC.header .. "Everything Delves|r: Deleted profile '" .. tostring(data) .. "'.")
            end
            if Rebuild then Rebuild() end
        end,
        timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
    }

    --------------------------------------------------------------------
    -- Action buttons
    --------------------------------------------------------------------
    local newBtn = E:CreateButton(content, 130, 24, "New Profile")
    newBtn:SetScript("OnClick", function()
        StaticPopup_Show("EVERYTHINGDELVES_NEWPROFILE")
    end)

    local copyBtn = E:CreateButton(content, 160, 24, "Duplicate Current")
    copyBtn:SetScript("OnClick", function()
        StaticPopup_Show("EVERYTHINGDELVES_COPYPROFILE")
    end)

    local noteFS = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    noteFS:SetFont(noteFS:GetFont(), 10)
    noteFS:SetJustifyH("LEFT")
    noteFS:SetText(
        E.CC.muted
        .. "Profiles are per-character. Delve history, completion marks, "
        .. "and Gilded Stash progress live in the active profile. UI "
        .. "settings (colors, scale, alerts) stay account-wide.\n"
        .. "Switching profiles never deletes data — it only changes "
        .. "which profile this character uses."
        .. E.CC.close
    )

    --------------------------------------------------------------------
    -- Rebuild: redraw the profile list from current data
    --------------------------------------------------------------------
    function Rebuild()
        charFS:SetText(
            E.CC.muted .. "This character: " .. E.CC.close
            .. E.CC.body .. (E.CharKey and E:CharKey() or "?") .. E.CC.close
        )
        activeFS:SetText(
            E.CC.muted .. "Active profile: " .. E.CC.close
            .. E.CC.gold .. (E.activeProfileName or "?") .. E.CC.close
        )

        -- Count how many character keys point at each profile.
        local usage = {}
        local sv = EverythingDelvesDB
        if sv and sv.profileKeys then
            for _, pk in pairs(sv.profileKeys) do
                usage[pk] = (usage[pk] or 0) + 1
            end
        end

        local names = E:GetProfileNames()
        local anchor = div1
        for i, name in ipairs(names) do
            local row = AcquireRow(i)
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0,
                (anchor == div1) and -10 or -4)
            row:SetPoint("RIGHT", content, "RIGHT", -8, 0)
            row:Show()

            local isActive = (name == E.activeProfileName)
            local count = usage[name] or 0
            -- Active profile gets WoW's built-in green ready-check
            -- texture (font-independent, always renders) instead of a
            -- Unicode glyph that shows as a missing-character box.
            local marker = isActive
                and ("|TInterface\\RaidFrame\\ReadyCheck-Ready:14:14|t " .. E.CC.gold)
                or E.CC.body
            local label = marker
                .. name .. E.CC.close
                .. E.CC.muted .. "  (" .. count .. " char"
                .. (count == 1 and "" or "s") .. ")" .. E.CC.close
            row.nameFS:SetText(label)

            if isActive then
                row.useBtn:Hide()
                row.delBtn:Hide()
            else
                row.useBtn:Show()
                row.useBtn:SetScript("OnClick", function()
                    E:SwitchProfile(name)
                    Rebuild()
                end)
                row.delBtn:Show()
                row.delBtn:SetScript("OnClick", function()
                    local dlg = StaticPopup_Show("EVERYTHINGDELVES_DELETEPROFILE", name)
                    if dlg then dlg.data = name end
                end)
            end
            anchor = row
        end

        -- Hide unused pooled rows.
        for i = #names + 1, #rowPool do
            if rowPool[i] then rowPool[i]:Hide() end
        end

        -- Action buttons + note below the list.
        newBtn:ClearAllPoints()
        newBtn:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -16)
        copyBtn:ClearAllPoints()
        copyBtn:SetPoint("LEFT", newBtn, "RIGHT", 10, 0)
        noteFS:ClearAllPoints()
        noteFS:SetPoint("TOPLEFT", newBtn, "BOTTOMLEFT", 0, -16)
        noteFS:SetPoint("RIGHT", content, "RIGHT", -8, 0)

        -- Total content height for scrolling.
        local rows = #names
        local h = 6 + 20    -- header
            + 18 + 18       -- char + active readouts
            + 12            -- divider gap
            + rows * (ROW_H + 4)
            + 16 + 24       -- buttons
            + 16 + 60       -- note
        content:SetHeight(h)
        UpdateScrollRange()
    end

    frame:SetScript("OnShow", function()
        scrollFrame:SetVerticalScroll(0)
        sb:SetValue(0)
        Rebuild()
    end)

    E:RegisterTab(7, frame)
end)
