local E = EverythingDelves
---@diagnostic disable: need-check-nil

local pairs, ipairs              = pairs, ipairs
local math_floor, math_max       = math.floor, math.max
local string_format              = string.format
local table_sort, table_insert   = table.sort, table.insert
local date, time                 = date, time

local function FormatDuration(sec)
    sec = sec or 0
    if sec <= 0 then return "--" end
    if sec < 60 then
        return string_format("%ds", sec)
    end
    if sec < 3600 then
        local m = math_floor(sec / 60)
        local s = sec - m * 60
        return string_format("%dm %02ds", m, s)
    end
    local h = math_floor(sec / 3600)
    local m = math_floor((sec % 3600) / 60)
    local s = sec % 60
    return string_format("%dh %dm %02ds", h, m, s)
end

local function FormatDate(ts)
    if not ts or ts == 0 then return "" end
    return date("%b %d, %Y", ts)
end

local function FormatDateTime(ts)
    if not ts or ts == 0 then return "" end
    return date("%b %d, %Y at %H:%M", ts)
end

-- Prefer the live variant captured at log time; fall back to the delve's
-- signature story. nil when neither is known (e.g. Nemesis has no signature).
local function ResolveRunStory(run, delveKey)
    if run and run.story and run.story ~= "" then
        return run.story
    end
    return E.DelveStories and E.DelveStories[delveKey] or nil
end

E:RegisterModule(function()
    local frame = CreateFrame("Frame", "EverythingDelvesTabHistoryContent")

    local HDR_X = 8
    local HDR_Y = -6

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", frame, "TOPLEFT", HDR_X, HDR_Y)
    title:SetFont(title:GetFont(), E.HEADER_FONT_SIZE, "OUTLINE")
    E:StyleAccentHeader(title, "Delve History")

    local summaryFS = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    summaryFS:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    summaryFS:SetFont(summaryFS:GetFont(), 11)

    local footerDiv = frame:CreateTexture(nil, "ARTWORK")
    footerDiv:SetHeight(1)
    footerDiv:SetPoint("BOTTOMLEFT",  frame, "BOTTOMLEFT",  8, 22)
    footerDiv:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -8, 22)
    E:StyleGreyLine(footerDiv)

    local noteFS = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    noteFS:SetPoint("BOTTOM", frame, "BOTTOM", 0, 7)
    local nf, _, nflags = noteFS:GetFont()
    noteFS:SetFont(nf, 10, nflags)
    noteFS:SetJustifyH("CENTER")
    noteFS:SetText(
        E.CC.muted
        .. "Note: Closing the WoW client during a delve will reset that run's timer. /reload is fine."
        .. E.CC.close
    )

    local dc = E.Colors.divider
    local headerDiv = frame:CreateTexture(nil, "ARTWORK")
    headerDiv:SetHeight(1)
    headerDiv:SetPoint("TOPLEFT",  summaryFS, "BOTTOMLEFT", 0, -6)
    headerDiv:SetPoint("RIGHT",    frame, "RIGHT", -8, 0)
    E:StyleAccentDivider(headerDiv)

    local clearBtn = E:CreateButton(frame, 100, 20, "Clear History")
    clearBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -8, -6)
    if clearBtn.Text then
        clearBtn.Text:SetFont(clearBtn.Text:GetFont(), 10)
    end
    clearBtn:SetScript("OnClick", function()
        StaticPopup_Show("EVERYTHINGDELVES_CLEAR_HISTORY")
    end)
    clearBtn:SetScript("OnEnter", function(self)
        local hc = E.Colors.buttonHover
        self:SetBackdropColor(hc.r, hc.g, hc.b, hc.a)
        E:ShowTooltip(self, "Clear Delve History",
            "Erase all recorded delve runs and lifetime stats",
            E.CC.red .. "This cannot be undone." .. E.CC.close)
    end)
    clearBtn:SetScript("OnLeave", function(self)
        local bc = E.Colors.buttonBg
        self:SetBackdropColor(bc.r, bc.g, bc.b, bc.a)
        E:HideTooltip()
    end)

    -- In the fixed header, not the scrolling content, so it never scrolls out of reach.
    local CAP_MIN  = E.HISTORY_CAP_MIN or 20
    local CAP_MAX  = E.HISTORY_CAP_MAX or 100
    local CAP_STEP = 10

    local function ClampCap(v)
        v = math_floor((v / CAP_STEP) + 0.5) * CAP_STEP
        if v < CAP_MIN then v = CAP_MIN elseif v > CAP_MAX then v = CAP_MAX end
        return v
    end

    local capValFS = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    capValFS:SetPoint("RIGHT", clearBtn, "LEFT", -14, 0)
    capValFS:SetFont(capValFS:GetFont(), 11)

    local capSlider = CreateFrame("Slider", nil, frame, "OptionsSliderTemplate")
    capSlider:SetSize(110, 16)
    capSlider:SetPoint("RIGHT", capValFS, "LEFT", -8, 0)
    capSlider:SetMinMaxValues(CAP_MIN, CAP_MAX)
    capSlider:SetValueStep(CAP_STEP)
    capSlider:SetObeyStepOnDrag(true)
    if capSlider.Low  then capSlider.Low:SetText("")  end
    if capSlider.High then capSlider.High:SetText("") end
    if capSlider.Text then capSlider.Text:SetText("") end

    local capLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    capLabel:SetPoint("RIGHT", capSlider, "LEFT", -8, 0)
    capLabel:SetFont(capLabel:GetFont(), 11)
    capLabel:SetText(E.CC.body .. "Runs kept per delve:" .. E.CC.close)

    capSlider:SetScript("OnValueChanged", function(_, val)
        val = ClampCap(val)
        if E.db then E.db.historyCap = val end
        capValFS:SetText(E.CC.gold .. val .. E.CC.close)
    end)

    local function CapTooltip(self)
        E:ShowTooltip(self, "History kept per delve",
            "How many recent runs to store for each delve (newest first).",
            E.CC.muted .. "Default 20, up to " .. CAP_MAX
            .. ". Raising it keeps more history from now on; runs already "
            .. "trimmed can't be recovered. Lowering it trims a delve's "
            .. "oldest runs the next time you run it." .. E.CC.close)
    end
    capSlider:SetScript("OnEnter", CapTooltip)
    capSlider:SetScript("OnLeave", function() E:HideTooltip() end)

    -- Set the readout explicitly: when the saved value equals the slider's
    -- current value, SetValue won't fire OnValueChanged and it'd stay blank.
    local function SyncHistoryCap()
        local v = ClampCap((E.db and E.db.historyCap) or CAP_MIN)
        capSlider:SetValue(v)
        capValFS:SetText(E.CC.gold .. v .. E.CC.close)
    end
    SyncHistoryCap()
    frame.SyncHistoryCap = SyncHistoryCap

    local scrollFrame = CreateFrame("ScrollFrame", nil, frame)
    scrollFrame:SetPoint("TOPLEFT",     headerDiv, "BOTTOMLEFT", 0, -4)
    scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -18, 30)
    scrollFrame:EnableMouseWheel(true)

    local sc = CreateFrame("Frame")
    sc:SetSize(1, 1)
    scrollFrame:SetScrollChild(sc)
    scrollFrame:SetScript("OnSizeChanged", function(_, w) sc:SetWidth(w) end)
    sc:SetHeight(400)

    local tabScrollBar = CreateFrame("Slider", nil, scrollFrame, "BackdropTemplate")
    tabScrollBar:SetWidth(14)
    tabScrollBar:SetPoint("TOPRIGHT",    scrollFrame, "TOPRIGHT",    16, 0)
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
        local newVal = math_max(0, math.min(
            self:GetVerticalScroll() - delta * 30, maxScroll))
        self:SetVerticalScroll(newVal)
        tabScrollBar:SetValue(newVal)
    end)

    local function UpdateScrollRange()
        local maxScroll = math_max(0, sc:GetHeight() - scrollFrame:GetHeight())
        tabScrollBar:SetMinMaxValues(0, maxScroll)
        if maxScroll <= 0 then
            tabScrollBar:Hide()
        else
            tabScrollBar:Show()
        end
    end

    local nemesisHeader = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    nemesisHeader:SetFont(nemesisHeader:GetFont(), E.HEADER_FONT_SIZE, "OUTLINE")
    E:StyleAccentHeader(nemesisHeader, "Seasonal Nemesis")

    local nemesisEmptyFS = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    nemesisEmptyFS:SetFont(nemesisEmptyFS:GetFont(), 10)
    nemesisEmptyFS:SetText(E.CC.muted
        .. "No nemesis delve runs recorded yet." .. E.CC.close)

    local midnightHeader = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    midnightHeader:SetFont(midnightHeader:GetFont(), E.HEADER_FONT_SIZE, "OUTLINE")
    E:StyleAccentHeader(midnightHeader, "Midnight Delves")

    local midnightEmptyFS = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    midnightEmptyFS:SetFont(midnightEmptyFS:GetFont(), 10)
    midnightEmptyFS:SetText(E.CC.muted
        .. "No Midnight delve runs recorded yet. Complete a delve to "
        .. "start tracking!" .. E.CC.close)

    -- Parented to sc (not frame) so they scroll with the content; children of
    -- frame stay pinned to the viewport and float over rows as you scroll.
    local nemesisDivider = sc:CreateTexture(nil, "ARTWORK")
    nemesisDivider:SetHeight(1)
    E:StyleAccentDivider(nemesisDivider)
    nemesisDivider:Hide()

    local midnightDivider = sc:CreateTexture(nil, "ARTWORK")
    midnightDivider:SetHeight(1)
    E:StyleAccentDivider(midnightDivider)
    midnightDivider:Hide()

    local HEADER_ROW_HEIGHT = 22
    local RUN_ROW_HEIGHT    = 16

    local headerRowPool = {}
    local runRowPool    = {}
    local noteLinePool  = {}

    -- Expanded state keyed by delve name — survives refresh.
    local expandedByKey = {}

    local Refresh
    local OpenNoteEditor

    local function HeaderRow_OnClick(self)
        local key = self.delveKey
        if not key then return end
        expandedByKey[key] = not expandedByKey[key]
        if Refresh then Refresh() end
    end

    -- A run is identified by delve name + timestamp, so its note survives
    -- refresh and re-sorting.
    local noteEditor = CreateFrame("Frame", "EverythingDelvesRunNoteEditor",
                                   UIParent, "BackdropTemplate")
    noteEditor:SetSize(440, 230)
    noteEditor:SetPoint("CENTER")
    noteEditor:SetFrameStrata("DIALOG")
    noteEditor:SetToplevel(true)
    noteEditor:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    noteEditor:SetBackdropColor(0.04, 0.04, 0.05, 0.98)
    E:RegisterThemed(function(p)
        noteEditor:SetBackdropBorderColor(p.border.r, p.border.g,
                                          p.border.b, p.border.a)
    end)
    noteEditor:EnableMouse(true)
    noteEditor:Hide()

    local neTitle = noteEditor:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    neTitle:SetPoint("TOPLEFT", noteEditor, "TOPLEFT", 14, -12)
    neTitle:SetFont(neTitle:GetFont(), E.HEADER_FONT_SIZE, "OUTLINE")
    E:StyleAccentHeader(neTitle, "Run Note")

    local neContext = noteEditor:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    neContext:SetPoint("TOPLEFT", neTitle, "BOTTOMLEFT", 0, -4)
    neContext:SetFont(neContext:GetFont(), 11)
    neContext:SetJustifyH("LEFT")

    local neBox = CreateFrame("Frame", nil, noteEditor, "BackdropTemplate")
    neBox:SetPoint("TOPLEFT",  noteEditor, "TOPLEFT",  14, -60)
    neBox:SetPoint("TOPRIGHT", noteEditor, "TOPRIGHT", -14, -60)
    neBox:SetHeight(118)
    neBox:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    neBox:SetBackdropColor(0.10, 0.10, 0.10, 1)
    neBox:SetBackdropBorderColor(0.35, 0.35, 0.35, 0.80)

    local neEdit = CreateFrame("EditBox", nil, neBox)
    neEdit:SetMultiLine(true)
    neEdit:SetAutoFocus(false)
    neEdit:SetMaxLetters(280)
    neEdit:SetFontObject(GameFontNormal)
    do
        local fp, _, ff = neEdit:GetFont()
        neEdit:SetFont(fp, 12, ff or "")
    end
    neEdit:SetTextColor(0.92, 0.92, 0.92, 1)
    neEdit:SetPoint("TOPLEFT", neBox, "TOPLEFT", 6, -6)
    neEdit:SetPoint("BOTTOMRIGHT", neBox, "BOTTOMRIGHT", -6, 6)
    neEdit:SetScript("OnEscapePressed", function() noteEditor:Hide() end)

    local neCount = noteEditor:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    neCount:SetPoint("TOPRIGHT", neBox, "BOTTOMRIGHT", 0, -4)
    neCount:SetFont(neCount:GetFont(), 9)
    neEdit:SetScript("OnTextChanged", function(self)
        neCount:SetText(E.CC.muted .. self:GetNumLetters() .. " / 280" .. E.CC.close)
    end)

    local function CloseNoteEditor()
        neEdit:ClearFocus()
        noteEditor:Hide()
    end

    local function SaveNoteEditor()
        if noteEditor.delveKey and noteEditor.timestamp then
            E:SetRunNote(noteEditor.delveKey, noteEditor.timestamp,
                         neEdit:GetText())
        end
        CloseNoteEditor()
        if Refresh then Refresh() end
    end

    local neSave = E:CreateButton(noteEditor, 90, 24, "Save")
    neSave:SetPoint("BOTTOMRIGHT", noteEditor, "BOTTOMRIGHT", -14, 14)
    neSave:SetScript("OnClick", SaveNoteEditor)
    neSave:SetScript("OnEnter", function(self)
        local hc = E.Colors.buttonHover
        self:SetBackdropColor(hc.r, hc.g, hc.b, hc.a)
    end)
    neSave:SetScript("OnLeave", function(self)
        local bc = E.Colors.buttonBg
        self:SetBackdropColor(bc.r, bc.g, bc.b, bc.a)
    end)

    local neCancel = E:CreateButton(noteEditor, 90, 24, "Cancel")
    neCancel:SetPoint("RIGHT", neSave, "LEFT", -10, 0)
    neCancel:SetScript("OnClick", CloseNoteEditor)
    neCancel:SetScript("OnEnter", function(self)
        local hc = E.Colors.buttonHover
        self:SetBackdropColor(hc.r, hc.g, hc.b, hc.a)
    end)
    neCancel:SetScript("OnLeave", function(self)
        local bc = E.Colors.buttonBg
        self:SetBackdropColor(bc.r, bc.g, bc.b, bc.a)
    end)

    local neDelete = E:CreateButton(noteEditor, 90, 24, "Delete")
    neDelete:SetPoint("BOTTOMLEFT", noteEditor, "BOTTOMLEFT", 14, 14)
    neDelete:SetScript("OnClick", function()
        if noteEditor.delveKey and noteEditor.timestamp then
            E:SetRunNote(noteEditor.delveKey, noteEditor.timestamp, "")
        end
        CloseNoteEditor()
        if Refresh then Refresh() end
    end)
    neDelete:SetScript("OnEnter", function(self)
        self:SetBackdropColor(0.45, 0.12, 0.12, 0.90)
        E:ShowTooltip(self, "Delete Note",
            E.CC.red .. "Removes this run's note." .. E.CC.close)
    end)
    neDelete:SetScript("OnLeave", function(self)
        local bc = E.Colors.buttonBg
        self:SetBackdropColor(bc.r, bc.g, bc.b, bc.a)
        E:HideTooltip()
    end)

    function OpenNoteEditor(delveKey, run, niceName)
        if not (delveKey and run) then return end
        noteEditor.delveKey  = delveKey
        noteEditor.timestamp = run.timestamp
        neContext:SetText(
            E.CC.gold .. (niceName or delveKey) .. E.CC.close
            .. E.CC.muted .. "   \226\128\148   T" .. (run.tier or 0)
            .. "   \226\128\148   " .. FormatDate(run.timestamp) .. E.CC.close
        )
        neEdit:SetText(run.note or "")
        neEdit:SetCursorPosition(#(run.note or ""))
        if run.note and run.note ~= "" then
            neDelete:Show()
        else
            neDelete:Hide()
        end
        noteEditor:Show()
        neEdit:SetFocus()
    end

    -- Shared across all note buttons (no per-row closures); read state off self.row.
    local function NoteBtn_SetState(btn, hasNote)
        if hasNote then
            btn.tex:SetDesaturated(false)
            btn.tex:SetVertexColor(1, 0.82, 0, 1)
            btn:SetAlpha(1)
        else
            btn.tex:SetDesaturated(true)
            btn.tex:SetVertexColor(1, 1, 1, 1)
            btn:SetAlpha(0.40)
        end
    end

    local function NoteBtn_OnClick(self)
        local row = self.row
        if row and row.run then
            OpenNoteEditor(row.delveKey, row.run, row.niceName)
        end
    end

    local function NoteBtn_OnEnter(self)
        self:SetAlpha(1)
        local row = self.row
        local note = row and row.run and row.run.note
        if note and note ~= "" then
            E:ShowTooltip(self, "Run Note", note)
        else
            E:ShowTooltip(self, "Add a Note",
                "Click to attach a free-form note to this run.")
        end
    end

    local function NoteBtn_OnLeave(self)
        NoteBtn_SetState(self, self.row and self.row.run and self.row.run.note
                              and self.row.run.note ~= "")
        E:HideTooltip()
    end

    -- E:DeleteRun also subtracts the run's contribution from lifetime stats.
    StaticPopupDialogs["EVERYTHINGDELVES_DELETE_RUN"] = {
        text = "Delete this %s run?\n\n%s\n\nIts time, deaths, and key"
            .. " usage are removed from the delve's lifetime stats."
            .. " This cannot be undone.",
        button1 = "Delete",
        button2 = "Cancel",
        OnAccept = function(_, data)
            if data and E:DeleteRun(data.key, data.timestamp) then
                Refresh()
            end
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }

    local function DelBtn_OnClick(self)
        local row = self.row
        local run = row and row.run
        if not (run and run.timestamp) then return end
        local desc = "T" .. (run.tier or 0) .. "  -  "
            .. FormatDateTime(run.timestamp)
        StaticPopup_Show("EVERYTHINGDELVES_DELETE_RUN",
            row.niceName or row.delveKey, desc,
            { key = row.delveKey, timestamp = run.timestamp })
    end

    local function DelBtn_OnEnter(self)
        self:SetAlpha(1)
        E:ShowTooltip(self, "Delete Run",
            "Permanently remove this run and its\ncontribution to lifetime stats.")
    end

    local function DelBtn_OnLeave(self)
        self:SetAlpha(0.40)
        E:HideTooltip()
    end

    -- The lone "B" glyph is ambiguous (Bountiful? Boss? Bonus?); give it a legend.
    local function BountBadge_OnEnter(self)
        local row = self.row
        if row and row.run and row.run.wasBountiful then
            E:ShowTooltip(self, E.CC.gold .. "B" .. E.CC.close .. " = Bountiful",
                "This run was in a Bountiful Delve.")
        end
    end

    local function BountBadge_OnLeave()
        E:HideTooltip()
    end

    local function AcquireNoteLine(i)
        local fs = noteLinePool[i]
        if not fs then
            fs = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            fs:SetFont(fs:GetFont(), 10)
            fs:SetJustifyH("LEFT")
            fs:SetSpacing(2)
            noteLinePool[i] = fs
        end
        fs:ClearAllPoints()
        return fs
    end

    local function CreateHeaderRow()
        local row = CreateFrame("Button", nil, sc)
        row:SetHeight(HEADER_ROW_HEIGHT)
        row:SetPoint("LEFT",  sc, "LEFT",  8,  0)
        row:SetPoint("RIGHT", sc, "RIGHT", -8, 0)

        local arrowFS = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        arrowFS:SetPoint("LEFT", row, "LEFT", 2, 0)
        arrowFS:SetFont(arrowFS:GetFont(), 11, "OUTLINE")
        row.arrowFS = arrowFS

        local nameFS = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        nameFS:SetPoint("LEFT", arrowFS, "RIGHT", 6, 0)
        nameFS:SetFont(nameFS:GetFont(), 11, "OUTLINE")
        nameFS:SetJustifyH("LEFT")
        nameFS:SetWidth(170)
        row.nameFS = nameFS

        local function statCol(x, w)
            local fs = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            fs:SetPoint("LEFT", row, "LEFT", x, 0)
            fs:SetFont(fs:GetFont(), 10)
            fs:SetWidth(w)
            fs:SetJustifyH("LEFT")
            fs:SetWordWrap(false)
            return fs
        end
        row.runsFS   = statCol(186, 56)
        row.btierFS  = statCol(244, 86)
        row.avgFS    = statCol(332, 92)
        row.fastFS   = statCol(426, 104)

        local hdeathsFS = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        hdeathsFS:SetPoint("RIGHT", row, "RIGHT", -2, 0)
        hdeathsFS:SetFont(hdeathsFS:GetFont(), 10)
        hdeathsFS:SetWidth(104)
        hdeathsFS:SetJustifyH("LEFT")
        hdeathsFS:SetWordWrap(false)
        row.hdeathsFS = hdeathsFS

        -- Blank when no keys were ever used, so non-key delves stay uncluttered.
        local keysFS = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        keysFS:SetPoint("RIGHT", hdeathsFS, "LEFT", -10, 0)
        keysFS:SetFont(keysFS:GetFont(), 10)
        keysFS:SetWidth(92)
        keysFS:SetJustifyH("LEFT")
        keysFS:SetWordWrap(false)
        row.keysFS = keysFS

        local latestFS = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        latestFS:SetPoint("LEFT",  row, "LEFT", 534, 0)
        latestFS:SetPoint("RIGHT", keysFS, "LEFT", -8, 0)
        latestFS:SetFont(latestFS:GetFont(), 10)
        latestFS:SetJustifyH("LEFT")
        latestFS:SetWordWrap(false)
        row.latestFS = latestFS

        row:SetScript("OnClick", HeaderRow_OnClick)
        return row
    end

    local function SetHeaderStats(row, life, latest)
        local avg = (life.totalRuns and life.totalRuns > 0)
            and math_floor(life.totalDuration / life.totalRuns) or 0
        row.runsFS:SetText(
            E.CC.muted .. "Runs: " .. E.CC.close
            .. E.CC.body .. (life.totalRuns or 0) .. E.CC.close)
        row.btierFS:SetText(
            E.CC.muted .. "Best Tier: " .. E.CC.close
            .. E.CC.body .. "T" .. (life.highestTier or 0) .. E.CC.close)
        row.avgFS:SetText(
            E.CC.muted .. "Avg: " .. E.CC.close
            .. E.CC.body .. FormatDuration(avg) .. E.CC.close)
        row.fastFS:SetText(
            E.CC.muted .. "Fastest: " .. E.CC.close
            .. E.CC.body .. FormatDuration(life.fastestTime) .. E.CC.close)
        if latest then
            row.latestFS:SetText(
                E.CC.muted .. "Latest: " .. E.CC.close
                .. E.CC.body .. FormatDuration(latest.duration) .. E.CC.close
                .. E.CC.muted .. " on " .. FormatDateTime(latest.timestamp)
                .. E.CC.close)
        else
            row.latestFS:SetText("")
        end
        local keysUsed = life.totalKeysUsed or 0
        row.keysFS:SetText(keysUsed > 0
            and (E.CC.muted .. "Keys used: " .. E.CC.close
                 .. E.CC.gold .. string_format("%d", keysUsed) .. E.CC.close)
            or "")
        row.hdeathsFS:SetText(
            E.CC.muted .. "Total Deaths: " .. E.CC.close
            .. E.CC.body .. string_format("%d", life.totalDeaths or 0) .. E.CC.close)
    end

    local function CreateRunRow()
        local row = CreateFrame("Frame", nil, sc)
        row:SetHeight(RUN_ROW_HEIGHT)
        row:SetPoint("LEFT",  sc, "LEFT",  32, 0)
        row:SetPoint("RIGHT", sc, "RIGHT", -8, 0)

        local noteBtn = CreateFrame("Button", nil, row)
        noteBtn:SetSize(15, 15)
        noteBtn:SetPoint("RIGHT", row, "RIGHT", -2, 0)
        local tex = noteBtn:CreateTexture(nil, "ARTWORK")
        tex:SetAllPoints()
        tex:SetTexture("Interface\\Buttons\\UI-GuildButton-PublicNote-Up")
        noteBtn.tex = tex
        noteBtn.row = row
        noteBtn:SetScript("OnClick", NoteBtn_OnClick)
        noteBtn:SetScript("OnEnter", NoteBtn_OnEnter)
        noteBtn:SetScript("OnLeave", NoteBtn_OnLeave)
        row.noteBtn = noteBtn

        local delBtn = CreateFrame("Button", nil, row)
        delBtn:SetSize(15, 15)
        delBtn:SetPoint("RIGHT", noteBtn, "LEFT", -4, 0)
        local dtex = delBtn:CreateTexture(nil, "ARTWORK")
        dtex:SetAllPoints()
        dtex:SetTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up")
        delBtn.tex = dtex
        delBtn.row = row
        delBtn:SetAlpha(0.40)
        delBtn:SetScript("OnClick", DelBtn_OnClick)
        delBtn:SetScript("OnEnter", DelBtn_OnEnter)
        delBtn:SetScript("OnLeave", DelBtn_OnLeave)
        row.delBtn = delBtn

        -- Fixed-position columns so rows align into a grid despite the proportional font.
        local function col(x, w, justify)
            local fs = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            fs:SetPoint("LEFT", row, "LEFT", x, 0)
            fs:SetFont(fs:GetFont(), 10)
            fs:SetWidth(w)
            fs:SetJustifyH(justify or "LEFT")
            fs:SetWordWrap(false)
            return fs
        end
        row.bountFS  = col(0,   12)
        local bountHover = CreateFrame("Frame", nil, row)
        bountHover:SetPoint("LEFT", row, "LEFT", 0, 0)
        bountHover:SetSize(14, RUN_ROW_HEIGHT)
        bountHover:EnableMouse(true)
        bountHover.row = row
        bountHover:SetScript("OnEnter", BountBadge_OnEnter)
        bountHover:SetScript("OnLeave", BountBadge_OnLeave)
        row.bountHover = bountHover
        row.tierFS   = col(14,  32)
        row.durFS    = col(48,  66)
        row.deathsFS = col(116, 74)
        row.keyFS    = col(192, 30)
        row.storyFS  = col(224, 150)
        row.bossFS   = col(378, 158)
        row.dateFS   = col(540, 170)
        return row
    end

    local function AcquireHeaderRow(i)
        local row = headerRowPool[i]
        if not row then
            row = CreateHeaderRow()
            headerRowPool[i] = row
        end
        row:ClearAllPoints()
        return row
    end

    local function AcquireRunRow(i)
        local row = runRowPool[i]
        if not row then
            row = CreateRunRow()
            runRowPool[i] = row
        end
        row:ClearAllPoints()
        return row
    end

    -- Reused every refresh, wiped instead of reallocated.
    local nemesisKeys  = {}
    local midnightKeys = {}

    local function CollectKeys(history)
        for i = #nemesisKeys,  1, -1 do nemesisKeys[i]  = nil end
        for i = #midnightKeys, 1, -1 do midnightKeys[i] = nil end
        if not history then return end
        local nameMap = E.LoggableDelveNames
        for name, entry in pairs(history) do
            if entry and entry.lifetime and (entry.lifetime.totalRuns or 0) > 0 then
                local kind = nameMap and nameMap[name]
                if kind == "nemesis" then
                    table_insert(nemesisKeys, name)
                elseif kind == "regular" then
                    table_insert(midnightKeys, name)
                end
            end
        end
        table_sort(nemesisKeys)
        table_sort(midnightKeys)
    end

    local LEFT_X = 8
    local INDENT = 0

    function Refresh()
        local history = E.db and E.db.delveHistory or nil
        CollectKeys(history)

        local totalRuns, totalDeaths, totalDur = 0, 0, 0
        if history then
            for _, entry in pairs(history) do
                local l = entry and entry.lifetime
                if l then
                    totalRuns   = totalRuns   + (l.totalRuns     or 0)
                    totalDeaths = totalDeaths + (l.totalDeaths   or 0)
                    totalDur    = totalDur    + (l.totalDuration or 0)
                end
            end
        end
        summaryFS:SetFormattedText(
            "%sTotal Runs:%s %s%d%s   %s||%s   %sTotal Deaths:%s %s%d%s   %s||%s   %sTotal Time:%s %s%s%s",
            E.CC.muted, E.CC.close, E.CC.gold, totalRuns, E.CC.close,
            E.CC.muted, E.CC.close,
            E.CC.muted, E.CC.close, E.CC.gold, totalDeaths, E.CC.close,
            E.CC.muted, E.CC.close,
            E.CC.muted, E.CC.close, E.CC.gold, FormatDuration(totalDur), E.CC.close
        )

        -- Hide all pool rows up front; we re-anchor the used ones fresh.
        for _, r in ipairs(headerRowPool) do r:Hide() end
        for _, r in ipairs(runRowPool)    do r:Hide() end
        for _, r in ipairs(noteLinePool)  do r:Hide() end

        nemesisEmptyFS:Hide()
        midnightEmptyFS:Hide()

        local hUsed, rUsed, nUsed = 0, 0, 0
        -- Every widget anchors directly to sc TOPLEFT at a fixed X with -yCur as
        -- its Y; no chained sibling anchors, so rows can't X-drift.
        local yCur = 4
        local X_PARENT = 0
        local X_CHILD  = 16

        local function PlaceAt(widget, x, h)
            widget:ClearAllPoints()
            widget:SetPoint("TOPLEFT", sc, "TOPLEFT", x, -yCur)
            widget:Show()
            yCur = yCur + h
        end

        local function PlaceRow(row, x, h)
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", sc, "TOPLEFT", x, -yCur)
            row:SetPoint("RIGHT",   sc, "RIGHT",  -8, 0)
            row:Show()
            yCur = yCur + h
        end

        local function EmitRun(run, key, niceName)
            rUsed = rUsed + 1
            local rrow = AcquireRunRow(rUsed)
            rrow:SetParent(sc)
            rrow.run      = run
            rrow.delveKey = key
            rrow.niceName = niceName

            local hasNote = run.note and run.note ~= ""
            if rrow.noteBtn then
                NoteBtn_SetState(rrow.noteBtn, hasNote)
            end

            rrow.bountFS:SetText(run.wasBountiful
                and (E.CC.gold .. "B" .. E.CC.close) or "")
            rrow.tierFS:SetText(E:GetTierCC(run.tier or 0)
                .. "T" .. (run.tier or 0) .. E.CC.close)
            rrow.durFS:SetText(E.CC.body .. FormatDuration(run.duration) .. E.CC.close)
            rrow.deathsFS:SetText(
                E.CC.muted .. "Deaths: " .. E.CC.close
                .. E.CC.body .. string_format("%d", run.deaths or 0) .. E.CC.close)
            rrow.keyFS:SetText(run.keyUsed
                and (E.CC.gold .. "Key" .. E.CC.close) or "")

            local storyTxt = ResolveRunStory(run, key)
            rrow.storyFS:SetText(storyTxt
                and (E.CC.body .. storyTxt .. E.CC.close)
                or  (E.CC.muted .. "--" .. E.CC.close))

            -- Map legacy live encounter names (e.g. "Spinshroom" -> "Gyrospore").
            local bossName = run.boss and E:NormalizeLiveBoss(key, run.boss)
            rrow.bossFS:SetText(bossName
                and (E.CC.body .. bossName .. E.CC.close) or "")

            rrow.dateFS:SetText(E.CC.muted .. FormatDateTime(run.timestamp) .. E.CC.close)

            PlaceRow(rrow, X_CHILD, RUN_ROW_HEIGHT + 1)

            if hasNote then
                nUsed = nUsed + 1
                local nl = AcquireNoteLine(nUsed)
                nl:SetParent(sc)
                local w = math_max(120, (sc:GetWidth() or 420) - 48)
                nl:SetWidth(w)
                nl:SetText(E.CC.muted .. "\226\128\156" .. run.note
                    .. "\226\128\157" .. E.CC.close)
                local h = (nl:GetStringHeight() or 12) + 6
                PlaceAt(nl, X_CHILD + 8, h)
            end
        end

        -- Section: Seasonal Nemesis
        PlaceAt(nemesisHeader, X_PARENT, 20)

        if #nemesisKeys == 0 then
            PlaceAt(nemesisEmptyFS, X_PARENT, 16)
        else
            for _, key in ipairs(nemesisKeys) do
                hUsed = hUsed + 1
                local row = AcquireHeaderRow(hUsed)
                row:SetParent(sc)
                row.delveKey = key

                local entry   = history[key]
                local life    = entry.lifetime
                local expanded = expandedByKey[key] and true or false
                local arrow    = expanded and "|cFFFFD700v|r" or "|cFFFFD700>|r"
                row.arrowFS:SetText(arrow)

                local nem = E.NemesisDelve
                local niceName = key
                if nem and nem.boss then
                    niceName = key .. " (" .. nem.boss .. ")"
                end
                row.nameFS:SetText(E.CC.gold .. niceName .. E.CC.close)

                SetHeaderStats(row, life, entry.recentRuns and entry.recentRuns[1])

                PlaceRow(row, X_PARENT, HEADER_ROW_HEIGHT + 2)

                if expanded then
                    local recent = entry.recentRuns
                    if recent then
                        for _, run in ipairs(recent) do
                            EmitRun(run, key, niceName)
                        end
                    end
                end
            end
        end

        -- Section: Midnight Delves
        yCur = yCur + 32

        nemesisDivider:ClearAllPoints()
        nemesisDivider:SetPoint("TOPLEFT",  sc, "TOPLEFT",   8, -yCur)
        nemesisDivider:SetPoint("TOPRIGHT", sc, "TOPRIGHT", -8, -yCur)
        nemesisDivider:SetHeight(1)
        nemesisDivider:Show()
        yCur = yCur + 32

        PlaceAt(midnightHeader, X_PARENT, 24)

        midnightDivider:ClearAllPoints()
        midnightDivider:SetPoint("TOPLEFT",  sc, "TOPLEFT",   8, -yCur + 4)
        midnightDivider:SetPoint("TOPRIGHT", sc, "TOPRIGHT", -8, -yCur + 4)
        midnightDivider:SetHeight(1)
        midnightDivider:Show()
        yCur = yCur + 8

        if #midnightKeys == 0 then
            PlaceAt(midnightEmptyFS, X_PARENT, 16)
        else
            for _, key in ipairs(midnightKeys) do
                hUsed = hUsed + 1
                local row = AcquireHeaderRow(hUsed)
                row:SetParent(sc)
                row.delveKey = key

                local entry   = history[key]
                local life    = entry.lifetime
                local expanded = expandedByKey[key] and true or false
                local arrow    = expanded and "|cFFFF4444v|r" or "|cFFFF4444>|r"
                row.arrowFS:SetText(arrow)
                row.nameFS:SetText(E.CC.white .. key .. E.CC.close)

                SetHeaderStats(row, life, entry.recentRuns and entry.recentRuns[1])

                PlaceRow(row, X_PARENT, HEADER_ROW_HEIGHT + 2)

                if expanded then
                    local recent = entry.recentRuns
                    if recent then
                        for _, run in ipairs(recent) do
                            EmitRun(run, key, key)
                        end
                    end
                end
            end
        end

        sc:SetHeight(yCur + 20)
        UpdateScrollRange()
    end

    -- Called by the delve logger when a run is recorded, or when history is cleared.
    function E:RefreshDelveHistoryTab()
        if frame:IsShown() then
            Refresh()
        end
    end

    frame:SetScript("OnShow", function()
        Refresh()
        scrollFrame:SetVerticalScroll(0)
        tabScrollBar:SetValue(0)
        if frame.SyncHistoryCap then frame.SyncHistoryCap() end
    end)

    E:RegisterTab(6, frame)
end)
