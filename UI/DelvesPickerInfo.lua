local E = EverythingDelves

local math_floor = math.floor

E:RegisterModule(function()
    local PANEL_W   = 232
    local ROW_H     = 13
    local NUM_TIERS = #E.TierData
    local TIER_X, LOOT_X, VAULT_X = 8, 70, 132

    local panel = CreateFrame("Frame", "EverythingDelvesPickerInfo", UIParent, "BackdropTemplate")
    panel:SetSize(PANEL_W, 280)
    panel:SetFrameStrata("HIGH")
    panel:SetClampedToScreen(true)
    panel:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    local bg = E.Colors.background
    panel:SetBackdropColor(bg.r, bg.g, bg.b, 1.0)
    E:RegisterThemed(function(p)
        panel:SetBackdropBorderColor(p.border.r, p.border.g, p.border.b, p.border.a)
    end)
    panel:Hide()

    local titleFS = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    titleFS:SetPoint("TOPLEFT",  panel, "TOPLEFT",  8, -8)
    titleFS:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -8, -8)
    titleFS:SetJustifyH("LEFT")
    titleFS:SetWordWrap(false)
    titleFS:SetFont(titleFS:GetFont(), E.HEADER_FONT_SIZE, "OUTLINE")

    local titleDiv = panel:CreateTexture(nil, "ARTWORK")
    titleDiv:SetHeight(1)
    titleDiv:SetPoint("TOPLEFT",  panel, "TOPLEFT",  1, -26)
    titleDiv:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -1, -26)
    E:StyleAccentDivider(titleDiv)

    local achHeader = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    achHeader:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, -32)
    achHeader:SetFont(achHeader:GetFont(), 10, "OUTLINE")
    achHeader:SetText(E.CC.gold .. "Achievements" .. E.CC.close)

    local storyFS = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    storyFS:SetPoint("TOPLEFT",  achHeader, "BOTTOMLEFT", 0, -3)
    storyFS:SetPoint("RIGHT",    panel, "RIGHT", -8, 0)
    storyFS:SetJustifyH("LEFT")
    storyFS:SetWordWrap(false)
    storyFS:SetFont(storyFS:GetFont(), 10)

    local chestFS = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    chestFS:SetPoint("TOPLEFT", storyFS, "BOTTOMLEFT", 0, -2)
    chestFS:SetFont(chestFS:GetFont(), 10)

    local depthFS = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    depthFS:SetPoint("TOPLEFT", chestFS, "BOTTOMLEFT", 0, -2)
    depthFS:SetFont(depthFS:GetFont(), 10)

    local lootDiv = panel:CreateTexture(nil, "ARTWORK")
    lootDiv:SetHeight(1)
    lootDiv:SetPoint("TOPLEFT",  depthFS, "BOTTOMLEFT", -7, -6)
    lootDiv:SetPoint("RIGHT",    panel, "RIGHT", -1, 0)
    E:StyleAccentDivider(lootDiv)

    local lootHeader = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    lootHeader:SetPoint("TOPLEFT", lootDiv, "BOTTOMLEFT", 7, -5)
    lootHeader:SetFont(lootHeader:GetFont(), 10, "OUTLINE")

    local hdrRow = CreateFrame("Frame", nil, panel)
    hdrRow:SetSize(PANEL_W - 8, ROW_H)
    hdrRow:SetPoint("TOPLEFT", lootHeader, "BOTTOMLEFT", 0, -4)
    local function HdrCol(x, txt)
        local fs = hdrRow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        fs:SetPoint("LEFT", hdrRow, "LEFT", x, 0)
        fs:SetFont(fs:GetFont(), 9)
        fs:SetText(E.CC.muted .. txt .. E.CC.close)
    end
    HdrCol(TIER_X, "Tier")
    HdrCol(LOOT_X, "Loot")
    HdrCol(VAULT_X, "Vault")

    local rows = {}
    local prev = hdrRow
    for i = 1, NUM_TIERS do
        local row = CreateFrame("Frame", nil, panel)
        row:SetSize(PANEL_W - 8, ROW_H)
        row:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -1)

        local hl = row:CreateTexture(nil, "BACKGROUND")
        hl:SetPoint("TOPLEFT",  row, "TOPLEFT",  -4, 1)
        hl:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -2, -1)
        hl:SetColorTexture(1, 0.84, 0, 0.13)
        hl:Hide()
        row.hl = hl

        local function Col(x, outline)
            local fs = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            fs:SetPoint("LEFT", row, "LEFT", x, 0)
            fs:SetFont(fs:GetFont(), 10, outline and "OUTLINE" or nil)
            return fs
        end
        row.tier  = Col(TIER_X, true)
        row.loot  = Col(LOOT_X, false)
        row.vault = Col(VAULT_X, false)

        local td = E.TierData[i]
        row.tier:SetText(E:GetTierCC(td.tier) .. "T" .. td.tier .. E.CC.close)
        local _, lc = E:GetLootTrack(td.bountifulLoot)
        local _, vc = E:GetLootTrack(td.greatVault)
        row.loot:SetText(lc .. td.bountifulLoot .. E.CC.close)
        row.vault:SetText(vc .. td.greatVault .. E.CC.close)

        rows[i] = row
        prev = row
    end

    local legendFS = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    legendFS:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -5)
    legendFS:SetFont(legendFS:GetFont(), 9)
    legendFS:SetText(E.CC.muted .. "Highlighted = your gear tier" .. E.CC.close)

    local function PlayerRecTier()
        local overall, equipped
        if GetAverageItemLevel then overall, equipped = GetAverageItemLevel() end
        local ilvl = math_floor(equipped or overall or 0)
        local rec = 1
        for _, t in ipairs(E.TierData) do
            if ilvl >= t.recGear then rec = t.tier end
        end
        return rec
    end

    local function ResolveEntranceDelve()
        local header = C_DelvesUI and C_DelvesUI.GetDelveEntranceHeaderString
            and C_DelvesUI.GetDelveEntranceHeaderString()
        if type(header) ~= "string" or header == "" then return nil end
        for _, d in ipairs(E.DelveData or {}) do
            if d.name == header
                    or (E.DelveNamesMatch and E.DelveNamesMatch(header, d.name)) then
                return d
            end
        end
        return nil
    end

    local function Refresh(delve)
        titleFS:SetText(E.CC.gold .. delve.name .. E.CC.close)

        local st = E:GetDelveAchievementStatus(delve.name)
        if not st then
            storyFS:SetText(E.CC.muted .. "Achievement data unavailable" .. E.CC.close)
            chestFS:SetText("")
            depthFS:SetText("")
        elseif st.allDone then
            storyFS:SetText(E.CC.green .. "All achievements complete" .. E.CC.close)
            chestFS:SetText("")
            depthFS:SetText("")
        else
            if st.stories then
                local base = st.stories.done
                    and (E.CC.green .. "Complete" .. E.CC.close)
                    or  (E.CC.red .. "Incomplete" .. E.CC.close)
                local credit = (not st.stories.done)
                    and E:GetTodaysStoryCredit(delve.name, st)
                local extra = credit
                    and (E.CC.gold .. "  (today counts!)" .. E.CC.close) or ""
                storyFS:SetText(E.CC.muted .. "Story: " .. E.CC.close .. base .. extra)
            else
                storyFS:SetText("")
            end

            if st.discoveries then
                local d = st.discoveries
                local cc = d.done and E.CC.green or E.CC.body
                chestFS:SetText(E.CC.muted .. "Chests: " .. E.CC.close
                    .. cc .. d.found .. "/" .. d.total .. E.CC.close)
            else
                chestFS:SetText("")
            end

            if st.depths and #st.depths > 0 then
                local miss = #(st.depthsMissing or {})
                if miss == 0 then
                    depthFS:SetText(E.CC.muted .. "Tier goals: " .. E.CC.close
                        .. E.CC.green .. "Done" .. E.CC.close)
                else
                    depthFS:SetText(E.CC.muted .. "Tier goals: " .. E.CC.close
                        .. E.CC.red .. miss .. " to go" .. E.CC.close)
                end
            else
                depthFS:SetText("")
            end
        end

        local recTier = PlayerRecTier()
        lootHeader:SetText(E.CC.gold .. "Rewards by Tier" .. E.CC.close
            .. E.CC.muted .. "   you: ~T" .. recTier .. E.CC.close)
        for i, row in ipairs(rows) do
            if i == recTier then row.hl:Show() else row.hl:Hide() end
        end
    end

    local function FitHeight()
        local top = panel:GetTop()
        local bottom = legendFS:GetBottom()
        if top and bottom and top > bottom then
            panel:SetHeight((top - bottom) + 8)
        end
    end

    local function AnchorPanel(picker)
        panel:ClearAllPoints()
        local left
        if picker and picker.GetLeft and picker:IsShown() then
            local ok, l = pcall(picker.GetLeft, picker)
            if ok then left = l end
        end
        if left and left >= PANEL_W + 8 then
            panel:SetPoint("TOPRIGHT", picker, "TOPLEFT", -8, 0)
        elseif left then
            panel:SetPoint("TOPLEFT", picker, "TOPRIGHT", 8, 0)
        else
            panel:SetPoint("CENTER", UIParent, "CENTER", 340, 0)
        end
    end

    local function Show()
        if E.db and E.db.showPickerInfo == false then panel:Hide(); return end
        local delve = ResolveEntranceDelve()
        if not delve then panel:Hide(); return end
        Refresh(delve)
        AnchorPanel(_G.DelvesDifficultyPickerFrame)
        panel:Show()
        C_Timer.After(0, FitHeight)
    end

    -- Additive only: HookScript the secure picker; never modify or move it.
    local hooked = false
    local function TryHookPicker()
        if hooked then return end
        local picker = _G.DelvesDifficultyPickerFrame
        if not (picker and picker.HookScript) then return end
        local ok = pcall(function()
            picker:HookScript("OnShow", Show)
            picker:HookScript("OnHide", function() panel:Hide() end)
        end)
        if not ok then return end
        hooked = true
        if picker:IsShown() then Show() end
    end

    local ef = CreateFrame("Frame")
    ef:RegisterEvent("ADDON_LOADED")
    ef:SetScript("OnEvent", function() TryHookPicker() end)
    TryHookPicker()
end)
