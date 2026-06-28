-- "Bonus Spoils" tracker: optional, off-by-default window that tracks only
-- the two bonus-chest mechanics (Nemesis Strongbox packs, Sanctified Banner)
-- a player collects after the delve boss. Detection is lockdown-safe (no
-- combat log / no enemy nameplates — see banner/nemesis notes) and pcall-guarded.
local E = EverythingDelves

local WIN_W      = 290
local PAD        = 10
local MAX_LINES  = 40
local MAX_CRIT   = 25   -- criteria iteration cap per step (safety)
local MAX_BONUS  = 15

-- Already captured by the core file; skipped in the generic widget pass.
local GILDED_WIDGET_ID = 7591

-- Nemesis Strongbox affix (Tier 4+): no in-delve progress widget (the Nemesis
-- spell-display widgets live ONLY on the entrance picker), so in-delve progress
-- is read by counting "Nullaeus' Minions" map vignettes (NEMESIS_PACK_VIGNETTE).

-- Midnight lockdown (both confirmed live 2026-06-10): COMBAT_LOG_EVENT_UNFILTERED
-- registration is forbidden, and UnitName() on delve enemies returns a SECRET
-- string that errors on any string method. So banner detection runs only on
-- unrestricted APIs: player auras and vignettes (names print clean in delves).
local BANNER_INTERACT_SPELLS = {
    [1269411] = true, [1269412] = true, [1269416] = true,  -- Sanctified Banner
}
local RAGER_SPAWN_SPELL = 1271184  -- "Voidfused Rager Spawn" (aura sweep only)
local RAGER_SPELL       = 1271189  -- "Voidfused Rager" (aura sweep only)
-- Rager spotted via vignette name (EN clients); its vignetteID isn't known yet.
local RAGER_NAME_MATCH = "Voidfused"

-- Nemesis pack vignette ("Nullaeus' Minions"): one per REMAINING pack, gone when
-- the pack dies — vignette counting IS the only data source. The Nullaeus delve
-- reuses the same vignette for its own minions; the counter is suppressed there.
local NEMESIS_PACK_VIGNETTE = 7531
local BANNER_BUFFS = {             -- any of these on the player = banner used
    1271918, 1271945,                      -- Sanctified Touch
    1272609, 1272666,                      -- Holy Fervor
    1272756, 1272769,                      -- Ward of Light
    1272809, 1272810, 1272813, 1272814,    -- Light's Judgement
    1273058, 1273066,                      -- Holy Reinforcements
}

-- Entrance-only header widgets (gone once inside a delve); kept solely for
-- the /ed objdump probe section.
local DELVE_TRACKER_WIDGETS = { 7526, 7592, 7624, 7761, 7764, 7861 }

-- Events that can carry the banner-manifest broadcast; exact carrier captured
-- live via /ed objdump.
local MSG_EVENTS = {
    CHAT_MSG_RAID_BOSS_EMOTE = true,
    CHAT_MSG_MONSTER_YELL    = true,
    CHAT_MSG_MONSTER_EMOTE   = true,
    CHAT_MSG_MONSTER_SAY     = true,
    UI_INFO_MESSAGE          = true,
    CHAT_MSG_SYSTEM          = true,
}

local ICON_DONE = "|TInterface\\RaidFrame\\ReadyCheck-Ready:11:11:0:-1|t "
local ICON_FAIL = "|TInterface\\RaidFrame\\ReadyCheck-NotReady:11:11:0:-1|t "
local ICON_TODO = "|TInterface\\Buttons\\UI-CheckBox-Up:13:13:-1:-1|t "

-- Strip color/texture/atlas escapes so embedded codes don't break line coloring.
local function StripEscapes(s)
    if not s then return nil end
    return (s:gsub("|c%x%x%x%x%x%x%x%x", "")
             :gsub("|r", "")
             :gsub("|T.-|t", "")
             :gsub("|A.-|a", ""))
end

local function CurioLine(label, curio)
    if not curio then return nil end
    local icon = (C_Item and C_Item.GetItemIconByID)
        and C_Item.GetItemIconByID(curio.id)
    local iconStr = icon and ("|T" .. icon .. ":12:12:0:0|t ") or ""
    return E.CC.muted .. label .. E.CC.close .. " "
        .. iconStr .. E.CC.body .. curio.name .. E.CC.close
end

-- Lives aren't in any widget/criterion (the header carries only the tier); they
-- render as a standalone digit right after the tier in the scenario tracker.
-- Anchor on the known tier and take the next digit; stop before Challenges/Wave.
local function ReadDelveLives(knownTier)
    local tracker = _G.ScenarioObjectiveTracker or _G.ObjectiveTrackerFrame
    if not tracker then return nil end
    local digits, stop = {}, false
    local function walk(f, depth)
        if stop or not f or depth > 8 then return end
        if f.IsForbidden and f:IsForbidden() then return end
        local okR, regs = pcall(function() return { f:GetRegions() } end)
        if okR then
            for _, r in ipairs(regs) do
                if r.GetObjectType and r:GetObjectType() == "FontString"
                        and r:IsShown() then
                    local t = r:GetText()
                    if t and t ~= "" then
                        local clean = t:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
                        if clean:find("Challenge", 1, true)
                                or clean:find("Wave", 1, true) then
                            stop = true
                            return
                        end
                        local n = clean:match("^%s*(%d+)%s*$")
                        if n then digits[#digits + 1] = tonumber(n) end
                    end
                end
            end
        end
        local okC, kids = pcall(function() return { f:GetChildren() } end)
        if okC then
            for _, c in ipairs(kids) do
                walk(c, depth + 1)
                if stop then return end
            end
        end
    end
    pcall(walk, tracker, 0)
    if knownTier then
        for i = 1, #digits - 1 do
            if digits[i] == knownTier then return digits[i + 1] end
        end
    end
    if #digits == 2 then return digits[2] end
    return nil
end

-- Difficulty 208 = Delves. Live, authoritative test that flips the moment the
-- player zones out; deliberately ignores runState.inDelve (can be left stale on
-- some exit paths). Spans the whole run plus the post-completion looting window.
local function PlayerInDelve()
    return select(3, GetInstanceInfo()) == 208
end

E:RegisterModule(function()
    local win = CreateFrame("Frame", "EverythingDelvesObjectivesWindow",
        UIParent, "BackdropTemplate")
    win:SetSize(WIN_W, 64)
    win:SetFrameStrata("MEDIUM")
    win:SetClampedToScreen(true)
    win:SetMovable(true)
    win:EnableMouse(true)
    win:RegisterForDrag("LeftButton")
    win:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    local bg = E.Colors.background
    win:SetBackdropColor(bg.r, bg.g, bg.b, 0.90)
    E:RegisterThemed(function(p)
        win:SetBackdropBorderColor(p.border.r, p.border.g, p.border.b, p.border.a)
    end)
    win:Hide()

    local pos = E.db and E.db.delveObjectivesPos
    if pos and pos.point then
        win:SetPoint(pos.point, UIParent, pos.relPoint or pos.point,
            pos.x or 0, pos.y or 0)
    else
        win:SetPoint("CENTER", UIParent, "CENTER", 350, 40)
    end

    win:SetScript("OnDragStart", win.StartMoving)
    win:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relPoint, x, y = self:GetPoint(1)
        if E.db then
            E.db.delveObjectivesPos =
                { point = point, relPoint = relPoint, x = x, y = y }
        end
    end)
    win:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOPRIGHT")
        GameTooltip:AddLine("Everything Delves", 1, 1, 1)
        if E.db and E.db.showDelveObjectives then
            GameTooltip:AddLine("Bonus Spoils: Nemesis Strongbox packs"
                .. " + the Sanctified Banner — the bonus loot to grab"
                .. " before the boss.", 0.7, 0.7, 0.7, true)
        end
        if E.db and E.db.showDelveHUD then
            GameTooltip:AddLine("Delve HUD: variant, grade, recommended"
                .. " curios and deaths for this run.", 0.7, 0.7, 0.7, true)
        end
        if E.db and E.db.showRunTimer then
            GameTooltip:AddLine("The clock shows your elapsed run time.",
                0.7, 0.7, 0.7, true)
        end
        GameTooltip:AddLine("Drag to move; toggle in Options.",
            0.7, 0.7, 0.7, true)
        GameTooltip:Show()
    end)
    win:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local titleFS = win:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    titleFS:SetPoint("TOPLEFT", win, "TOPLEFT", PAD, -8)
    titleFS:SetWidth(WIN_W - 2 * PAD - 48)
    titleFS:SetJustifyH("LEFT")
    titleFS:SetWordWrap(false)
    titleFS:SetFont(titleFS:GetFont(), 12, "OUTLINE")

    local titleDiv = win:CreateTexture(nil, "ARTWORK")
    titleDiv:SetHeight(1)
    titleDiv:SetPoint("TOPLEFT",  win, "TOPLEFT",  1, -26)
    titleDiv:SetPoint("TOPRIGHT", win, "TOPRIGHT", -1, -26)
    E:StyleAccentDivider(titleDiv)

    local timerFS = win:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    timerFS:SetPoint("TOPRIGHT", win, "TOPRIGHT", -PAD, -8)
    timerFS:SetJustifyH("RIGHT")
    timerFS:SetFont(timerFS:GetFont(), 12, "OUTLINE")
    timerFS:Hide()

    -- elapsed must use GetTime() to match runState.startTime's base (not time()).
    local function UpdateRunTimer()
        local rs = E.delveRunState
        local timerOn = E.db and (E.db.showRunTimer or E.db.showDelveHUD)
        if timerOn and rs and rs.inDelve
                and rs.startTime and rs.startTime > 0 then
            local secs = math.max(0, math.floor(GetTime() - rs.startTime))
            local txt = E.CC.gold
                .. (secs > 0 and E:FormatClock(secs) or "0:00")
                .. E.CC.close
            if timerFS.cachedText ~= txt then
                timerFS:SetText(txt)
                timerFS.cachedText = txt
            end
            timerFS.frozenFor = nil
            timerFS:Show()
        elseif timerOn and E.db.showRunResult and rs and rs.lastResult
                and PlayerInDelve() then
            -- Rebuild only on a new result; avoids per-second string churn.
            local lr = rs.lastResult
            if timerFS.frozenFor ~= lr then
                local cc = lr.beat and E.CC.green or E.CC.red
                timerFS:SetText(cc .. E:FormatClock(lr.duration) .. E.CC.close)
                timerFS.frozenFor = lr
                timerFS.cachedText = nil
            end
            timerFS:Show()
        else
            timerFS:Hide()
        end
    end

    local timerAccum = 0
    win:SetScript("OnUpdate", function(_, elapsed)
        timerAccum = timerAccum + elapsed
        if timerAccum < 1 then return end
        timerAccum = 0
        UpdateRunTimer()
    end)

    -- Sanctified Banner state machine, mirrored into E.db.activeRun so a mid-run
    -- /reload doesn't lose it. Forward-only: announced -> clicked -> buffed ->
    -- eliteUp -> grand (Grand Sanctified Spoils earned).
    local bannerState = nil
    local ragerGUID   = nil  -- the Rager's VIGNETTE guid once spotted
    local lastRunKey  = nil
    local msgLog      = {}   -- rolling delve broadcast log (diagnostics)
    local stickyMsgs  = {}   -- keyword-matched messages, never rotated out
    local ScanVignettes      -- forward local; defined after SetBannerState
    -- Packs can appear ONE AT A TIME, so the peak-seen-at-once count undercounts
    -- kills. Instead accumulate distinct pack creature/object GUIDs ever seen this
    -- run; killed = seenCount - remaining. Rendering waits for a pack to be seen to
    -- avoid a false "done" before vignettes load / in delves without the affix.
    local nemesisRemaining = nil
    local nemesisSeen      = {}   -- objectGUID -> true (distinct packs seen this run)
    local nemesisSeenCount = 0
    local nemesisKilledBase = 0   -- packs killed before a mid-run /reload (persisted)
    local castLog = {}            -- recent player casts (newest last); objdump diag

    -- FontStrings created once and reused; SetText only fires on change.
    local linePool = {}
    local seen     = {}    -- dedupe across data sources, wiped per refresh
    local lineIdx  = 0
    local yOff     = 0
    local objDone, objTotal = 0, 0
    local pendingHeader = nil

    local function AcquireLine(i)
        local fs = linePool[i]
        if not fs then
            fs = win:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            fs:SetFont(fs:GetFont(), 11)
            fs:SetWidth(WIN_W - 2 * PAD)
            fs:SetJustifyH("LEFT")
            fs:SetWordWrap(true)
            linePool[i] = fs
        end
        return fs
    end

    local function AddLine(text, extraGap)
        if lineIdx >= MAX_LINES then return end
        lineIdx = lineIdx + 1
        if extraGap then yOff = yOff - 4 end
        local fs = AcquireLine(lineIdx)
        if fs.cachedText ~= text then
            fs:SetText(text)
            fs.cachedText = text
        end
        fs:ClearAllPoints()
        fs:SetPoint("TOPLEFT", win, "TOPLEFT", PAD, yOff)
        fs:Show()
        yOff = yOff - math.max(13, (fs:GetStringHeight() or 11) + 4)
    end

    -- Lazy: only written once the section has at least one line.
    local function SetSection(title)
        pendingHeader = title
    end
    local function FlushHeader()
        if pendingHeader then
            AddLine(E.CC.muted .. pendingHeader .. E.CC.close, true)
            pendingHeader = nil
        end
    end

    local function EmitObjective(desc, done, failed, progress)
        desc = StripEscapes(desc)
        if not desc or desc == "" then return end
        local key = desc:lower()
        if seen[key] then return end
        seen[key] = true

        FlushHeader()
        objTotal = objTotal + 1
        if done then objDone = objDone + 1 end

        local text
        if done then
            text = ICON_DONE .. E.CC.green .. desc
                .. (progress and (" " .. progress) or "") .. E.CC.close
        elseif failed then
            text = ICON_FAIL .. E.CC.red .. desc
                .. (progress and (" " .. progress) or "") .. E.CC.close
        else
            text = ICON_TODO .. E.CC.body .. desc .. E.CC.close
                .. (progress and ("  " .. E.CC.gold .. progress .. E.CC.close) or "")
        end
        AddLine(text)
    end

    -- ScenarioHeaderDelves tierText is more reliable than runState.tier (the
    -- core's entry latch can hold the previous delve's tier until completion).
    local function ReadLiveTier(stepInfo)
        if not (stepInfo and stepInfo.widgetSetID and C_UIWidgetManager
                and C_UIWidgetManager.GetAllWidgetsBySetID) then return nil end
        local VT = Enum and Enum.UIWidgetVisualizationType
        local getter = C_UIWidgetManager
            .GetScenarioHeaderDelvesWidgetVisualizationInfo
        if not (VT and VT.ScenarioHeaderDelves and getter) then return nil end
        local ok, widgets = pcall(
            C_UIWidgetManager.GetAllWidgetsBySetID, stepInfo.widgetSetID)
        if not ok or type(widgets) ~= "table" then return nil end
        for _, w in ipairs(widgets) do
            if w.widgetType == VT.ScenarioHeaderDelves then
                local ok2, hv = pcall(getter, w.widgetID)
                local tt = ok2 and hv and tonumber(hv.tierText)
                if tt then return tt end
            end
        end
        return nil
    end

    local function RefreshContent()
        wipe(seen)
        lineIdx, yOff = 0, -32
        objDone, objTotal = 0, 0
        pendingHeader = nil

        local rs = E.delveRunState

        -- New tracked run: reset the banner machine, then restore persisted state
        -- on a /reload-resumed run (same startTime). After SCENARIO_COMPLETED
        -- rs.inDelve is false but the player is still looting — no reset on that
        -- path, so "Grand Spoils earned!" survives until the next real run.
        if rs and rs.inDelve then
            local runKey = (rs.delveName or "?") .. "#" .. tostring(rs.startTime or 0)
            if runKey ~= lastRunKey then
                lastRunKey = runKey
                bannerState, ragerGUID = nil, nil
                nemesisRemaining, nemesisSeenCount = nil, 0
                nemesisKilledBase = 0
                wipe(nemesisSeen)
                wipe(msgLog)
                wipe(stickyMsgs)
                wipe(castLog)
                local ar = E.db and E.db.activeRun
                if ar and ar.startTime == rs.startTime then
                    bannerState = ar.bannerState
                    ragerGUID   = ar.bannerRagerGUID
                    nemesisKilledBase = ar.nemesisKilled or 0
                end
            end
        end

        -- Fresh vignette pass before rendering: feeds nemesis counter + banner.
        if ScanVignettes then pcall(ScanVignettes) end

        local name = (rs and rs.delveName) or GetRealZoneText() or "Delve"
        local stepInfo
        if C_ScenarioInfo and C_ScenarioInfo.GetScenarioStepInfo then
            local ok, si = pcall(C_ScenarioInfo.GetScenarioStepInfo)
            if ok then stepInfo = si end
        end
        local liveTier = ReadLiveTier(stepInfo)

        if E.db and E.db.showDelveHUD and rs and rs.inDelve then
            local variant = rs.story
            if (not variant or variant == "") and E.GetDelveStoryVariant then
                variant = E:GetDelveStoryVariant(name)
            end
            if variant and variant ~= "" then
                local si = E.GetStoryTier and E:GetStoryTier(variant)
                local grade = ""
                if si and si.tier then
                    grade = "  " .. E:GetGradeCC(si.tier)
                        .. "(" .. si.tier .. ")" .. E.CC.close
                end
                AddLine(E.CC.muted .. "Variant:" .. E.CC.close .. " "
                    .. E.CC.body .. variant .. E.CC.close .. grade)
            end
            local role = E.GetPlayerCurioRole and E:GetPlayerCurioRole() or "Damage"
            local combat, utility
            if E.GetRecommendedCurios then
                combat, utility = E:GetRecommendedCurios(
                    E.lastKnownCompanion or "Valeera", role)
            end
            local cl = CurioLine("Combat:", combat)
            local ul = CurioLine("Utility:", utility)
            if cl then AddLine(cl) end
            if ul then AddLine(ul) end
            local knownTier = liveTier or (rs.tier or 0)
            local lives = ReadDelveLives(knownTier > 0 and knownTier or nil)
            local statLine = ""
            if lives then
                local livesCC = (lives <= 1 and E.CC.red)
                    or (lives <= 2 and E.CC.yellow) or E.CC.green
                statLine = E.CC.muted .. "Lives:" .. E.CC.close .. " "
                    .. livesCC .. lives .. E.CC.close .. "   "
            end
            statLine = statLine .. E.CC.muted .. "Deaths:" .. E.CC.close .. " "
                .. E.CC.gold .. tostring(rs.deaths or 0) .. E.CC.close
            AddLine(statLine)
        end

        if E.db and E.db.showRunResult and rs and rs.inDelve
                and E.GetBestRunTime then
            local curTier = liveTier or (rs.tier or 0)
            local best, bestTier
            if curTier > 0 then best = E:GetBestRunTime(name, curTier) end
            if not best then best, bestTier = E:GetBestRunTime(name) end
            if best and best > 0 then
                local line = E.CC.muted .. "Best:" .. E.CC.close .. " "
                    .. E.CC.gold .. E:FormatClock(best) .. E.CC.close
                if bestTier and bestTier ~= curTier then
                    line = line .. E.CC.muted .. " (T" .. bestTier .. ")" .. E.CC.close
                end
                AddLine(line)
            end
        end

        -- The seasonal Nullaeus delve (delveKind "nemesis") is excluded: it's a
        -- straight-to-boss fight with no Pactsworn packs / no strongbox.
        SetSection(nil)
        if E.db and E.db.showDelveObjectives then
            if rs and rs.inDelve and rs.delveKind ~= "nemesis"
                    and (nemesisSeenCount > 0 or nemesisKilledBase > 0) then
                local tierNow = liveTier or (rs.tier or 0)
                local expected = 0
                if     tierNow >= 10 then expected = 4
                elseif tierNow >= 8  then expected = 3
                elseif tierNow >= 6  then expected = 2
                elseif tierNow >= 4  then expected = 1
                end
                local total  = math.max(expected, nemesisKilledBase + nemesisSeenCount)
                local killed = nemesisKilledBase + math.max(0, nemesisSeenCount - (nemesisRemaining or 0))
                EmitObjective(
                    "Nemesis Strongbox: " .. killed .. "/" .. total .. " packs",
                    killed >= total, false, nil)
            end

            if bannerState == "grand" then
                EmitObjective("Sanctified Banner - Grand Spoils earned!",
                    true, false, nil)
            elseif bannerState == "buffed" or bannerState == "clicked" then
                EmitObjective("Sanctified Banner found - bonus Spoils secured",
                    true, false, nil)
            elseif bannerState == "eliteUp" then
                EmitObjective("Sanctified Banner - kill the Voidfused Rager!",
                    false, false, nil)
            elseif rs and rs.inDelve
                    and (rs.wasBountiful or bannerState == "announced") then
                EmitObjective("Sanctified Banner - find it for bonus loot",
                    false, false, nil)
            end

            if objTotal > 0 and objDone >= objTotal then
                AddLine(ICON_DONE .. E.CC.green
                    .. "Bonus loot secured - go get the boss!" .. E.CC.close, true)
            elseif objTotal == 0 then
                -- Phrased to fit both "no bonus mechanics" and "run already ended".
                AddLine(ICON_DONE .. E.CC.green
                    .. "All bonus loot accounted for." .. E.CC.close)
            end
        end

        -- Rendered last so the live widget tier can win.
        local tier = liveTier or (rs and rs.tier) or 0
        local title = E.CC.header .. name .. E.CC.close
        if tier > 0 then
            title = title .. "  " .. E:GetTierCC(tier) .. "T" .. tier .. E.CC.close
        end
        if titleFS.cachedText ~= title then
            titleFS:SetText(title)
            titleFS.cachedText = title
        end

        for i = lineIdx + 1, #linePool do
            linePool[i]:Hide()
        end
        -- No content lines = timer-only mode: collapse to a compact title bar.
        if lineIdx == 0 then
            win:SetHeight(32)
        else
            win:SetHeight(math.max(64, -yOff + 8))
        end
    end

    local refreshPending = false
    local ef = CreateFrame("Frame")

    local function DoRefresh()
        refreshPending = false
        -- Gate on the LIVE in-delve test, not rs.inDelve: the run-state is false
        -- in the post-boss loot room and on a not-yet-begun login entry, yet the
        -- HUD/timer (which self-gate on the run state) should still be available.
        local shouldShow = E.db and PlayerInDelve()
            and (E.db.showDelveObjectives or E.db.showRunTimer or E.db.showDelveHUD)
        if shouldShow then
            -- Banner/cast watchers only while the Bonus Spoils tracker is on.
            if E.db.showDelveObjectives then
                ef:RegisterUnitEvent("UNIT_AURA", "player")
                ef:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
            else
                ef:UnregisterEvent("UNIT_AURA")
                ef:UnregisterEvent("UNIT_SPELLCAST_SUCCEEDED")
            end
            -- pcall so one bad API read can't kill the window for the session.
            local ok, err = pcall(RefreshContent)
            if not ok and E.db and E.db.debugTier then
                print("|cFFFFD700[ED obj]|r refresh error: " .. tostring(err))
            end
            win:Show()
        else
            ef:UnregisterEvent("UNIT_AURA")
            ef:UnregisterEvent("UNIT_SPELLCAST_SUCCEEDED")
            win:Hide()
        end
    end

    local function QueueRefresh()
        if refreshPending then return end
        refreshPending = true
        C_Timer.After(0.25, DoRefresh)
    end

    local BANNER_RANK = {
        announced = 1, clicked = 2, buffed = 3, eliteUp = 4, grand = 5,
    }

    local function SetBannerState(s)
        if not BANNER_RANK[s] then return end
        if bannerState and BANNER_RANK[s] <= BANNER_RANK[bannerState] then
            return
        end
        bannerState = s
        local ar = E.db and E.db.activeRun
        if ar then
            ar.bannerState     = bannerState
            ar.bannerRagerGUID = ragerGUID
        end
        QueueRefresh()
    end

    local function HandleUnitAura()
        if not PlayerInDelve() then return end
        if bannerState and BANNER_RANK[bannerState] >= BANNER_RANK.buffed then
            return
        end
        if not (C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID) then
            return
        end
        for _, sid in ipairs(BANNER_BUFFS) do
            local ok, aura = pcall(C_UnitAuras.GetPlayerAuraBySpellID, sid)
            if ok and aura then
                SetBannerState("buffed")
                return
            end
        end
        for sid in pairs(BANNER_INTERACT_SPELLS) do
            local ok, aura = pcall(C_UnitAuras.GetPlayerAuraBySpellID, sid)
            if ok and aura then
                SetBannerState("clicked")
                return
            end
        end
    end

    -- The banner interact fires one of the Sanctified Banner spells as a player
    -- cast — the only signal covering the no-buff/no-elite outcome.
    local function HandlePlayerCast(spellID)
        if not spellID or not PlayerInDelve() then return end
        -- 60 deep: a post-click elite fight can burn 25+ GCDs and the interact
        -- cast must survive until a post-fight /ed objdump.
        if #castLog >= 60 then table.remove(castLog, 1) end
        castLog[#castLog + 1] = spellID
        if BANNER_INTERACT_SPELLS[spellID] then
            SetBannerState("clicked")
        end
    end

    -- Vignette-driven (nameplates unusable: UnitName on delve enemies is secret).
    -- Vignettes in a delve are zone-wide, so a Rager vignette that vanishes after
    -- being seen = killed, not out of range. Name matching is EN-only for now.
    ScanVignettes = function()
        if not PlayerInDelve() then return end
        if not (C_VignetteInfo and C_VignetteInfo.GetVignettes) then return end
        local ok, vigs = pcall(C_VignetteInfo.GetVignettes)
        if not ok or type(vigs) ~= "table" then return end
        local ragerSeen = false
        local packCount = 0
        for _, vguid in ipairs(vigs) do
            local ok2, v = pcall(C_VignetteInfo.GetVignetteInfo, vguid)
            if ok2 and v and v.vignetteID == NEMESIS_PACK_VIGNETTE then
                packCount = packCount + 1
                -- Key on the creature GUID; the vignette GUID regenerates and double-counts.
                local key = v.objectGUID
                if key and not nemesisSeen[key] then
                    nemesisSeen[key] = true
                    nemesisSeenCount = nemesisSeenCount + 1
                end
            end
            local nm = ok2 and v and v.name
            if type(nm) == "string" then
                local ln = nm:lower()
                if ln:find(RAGER_NAME_MATCH:lower(), 1, true) then
                    ragerSeen = true
                    if ragerGUID ~= vguid then
                        ragerGUID = vguid
                        local ar = E.db and E.db.activeRun
                        if ar then ar.bannerRagerGUID = ragerGUID end
                    end
                    SetBannerState("eliteUp")
                elseif ln:find("grand sanctified", 1, true) then
                    SetBannerState("grand")
                elseif ln:find("sanctified spoils", 1, true) then
                    SetBannerState("clicked")  -- bonus chest confirmed
                elseif ln:find("sanctified banner", 1, true) then
                    SetBannerState("announced")
                end
            end
        end
        if ragerGUID and not ragerSeen and bannerState == "eliteUp" then
            SetBannerState("grand")
        end
        nemesisRemaining = packCount
        -- Persist the kill count: a /reload resets the vignette GUIDs, so seenCount
        -- rebuilds from live packs only and would drop already-killed ones. max()
        -- guards against a scan that runs before the resume restores the base.
        local ar = E.db and E.db.activeRun
        if ar then
            local killed = nemesisKilledBase + math.max(0, nemesisSeenCount - packCount)
            ar.nemesisKilled = math.max(ar.nemesisKilled or 0, killed)
        end
    end

    local function HandleMessage(event, a1, a2)
        if not PlayerInDelve() then return end
        local text = (event == "UI_INFO_MESSAGE") and a2 or a1
        if type(text) ~= "string" or text == "" then return end
        if #msgLog >= 10 then table.remove(msgLog, 1) end
        msgLog[#msgLog + 1] = event .. ": " .. text
        local lt = text:lower()
        if lt:find("sanctified", 1, true) or lt:find("banner", 1, true)
                or lt:find("strongbox", 1, true)
                or lt:find("nemesis", 1, true)
                or lt:find("spoils", 1, true) then
            if #stickyMsgs < 10 then
                stickyMsgs[#stickyMsgs + 1] = event .. ": " .. text
            end
            if lt:find("sanctified banner", 1, true) then
                SetBannerState("announced")
            end
        end
    end

    -- Safety net: catches widget tooltip changes that arrive with no event.
    local ticker
    win:SetScript("OnShow", function()
        if not ticker then
            ticker = C_Timer.NewTicker(3, QueueRefresh)
        end
        timerAccum = 0
        UpdateRunTimer()
    end)
    win:SetScript("OnHide", function()
        if ticker then
            ticker:Cancel()
            ticker = nil
        end
    end)

    -- Frames receive events in registration order, so the core handlers have
    -- already updated E.delveRunState by the time these fire. UNIT_AURA and the
    -- cast event are registered dynamically in DoRefresh, only while shown.
    for _, ev in ipairs({
        "PLAYER_ENTERING_WORLD",
        "ZONE_CHANGED_NEW_AREA",
        "SCENARIO_UPDATE",
        "SCENARIO_CRITERIA_UPDATE",
        "CRITERIA_COMPLETE",
        "SCENARIO_COMPLETED",
        "UPDATE_UI_WIDGET",
        "CHAT_MSG_RAID_BOSS_EMOTE",
        "CHAT_MSG_MONSTER_YELL",
        "CHAT_MSG_MONSTER_EMOTE",
        "CHAT_MSG_MONSTER_SAY",
        "UI_INFO_MESSAGE",
        "CHAT_MSG_SYSTEM",
        "VIGNETTE_MINIMAP_UPDATED",
        "VIGNETTES_UPDATED",
    }) do
        pcall(ef.RegisterEvent, ef, ev)
    end
    ef:SetScript("OnEvent", function(_, event, ...)
        if event == "UNIT_AURA" then
            HandleUnitAura()
            return
        end
        if event == "UNIT_SPELLCAST_SUCCEEDED" then
            local _, _, spellID = ...
            HandlePlayerCast(spellID)
            return
        end
        if MSG_EVENTS[event] then
            -- pcall: chat/system text could be a Midnight secret string.
            pcall(HandleMessage, event, ...)
            return
        end
        -- High-frequency world events fire constantly; only react while shown.
        if (event == "UPDATE_UI_WIDGET"
                or event == "VIGNETTE_MINIMAP_UPDATED"
                or event == "VIGNETTES_UPDATED")
                and not win:IsShown() then
            -- Still keep the nemesis tally accurate while hidden (packs can die
            -- before the window is shown). ScanVignettes self-gates and is cheap.
            if (event == "VIGNETTE_MINIMAP_UPDATED" or event == "VIGNETTES_UPDATED")
                    and ScanVignettes then
                pcall(ScanVignettes)
            end
            return
        end
        QueueRefresh()
    end)

    function E:UpdateDelveObjectivesWindow()
        DoRefresh()
    end

    -- /ed objdump — raw dump of every objective-ish data source so unknown
    -- counters can be located on the live client and wired in precisely.
    function E:DumpDelveObjectiveData()
        local function out(s) print("|cFFFFD700[ED obj]|r " .. s) end
        local function esc(v)
            local s = tostring(v)
            if #s > 90 then s = s:sub(1, 90) .. "..." end
            return (s:gsub("|", "||"))
        end
        local function sniff(t)
            local keys = {}
            for k, v in pairs(t) do
                local tv = type(v)
                if tv == "string" or tv == "number" or tv == "boolean" then
                    keys[#keys + 1] = k
                end
            end
            table.sort(keys)
            local parts = {}
            for _, k in ipairs(keys) do
                parts[#parts + 1] = k .. "=" .. esc(t[k])
            end
            return table.concat(parts, " ")
        end

        out("=== scenario ===")
        local scen = (C_ScenarioInfo and C_ScenarioInfo.GetScenarioInfo)
            and C_ScenarioInfo.GetScenarioInfo() or nil
        out(scen and sniff(scen) or "GetScenarioInfo: nil")

        local stepInfo
        if C_ScenarioInfo and C_ScenarioInfo.GetScenarioStepInfo then
            local ok, si = pcall(C_ScenarioInfo.GetScenarioStepInfo)
            if ok then stepInfo = si end
        end
        out("=== step ===")
        out(stepInfo and sniff(stepInfo) or "GetScenarioStepInfo: nil")

        out("=== main criteria ===")
        if stepInfo and C_ScenarioInfo.GetCriteriaInfo then
            for i = 1, math.min(stepInfo.numCriteria or 0, MAX_CRIT) do
                local ok, c = pcall(C_ScenarioInfo.GetCriteriaInfo, i)
                if ok and c then out("  [" .. i .. "] " .. sniff(c)) end
            end
        end

        out("=== bonus steps ===")
        if C_Scenario and C_Scenario.GetBonusSteps
                and C_ScenarioInfo and C_ScenarioInfo.GetCriteriaInfoByStep then
            local ok, bonusSteps = pcall(C_Scenario.GetBonusSteps)
            if ok and type(bonusSteps) == "table" and #bonusSteps > 0 then
                for _, stepIdx in ipairs(bonusSteps) do
                    out("  bonus step " .. tostring(stepIdx))
                    for i = 1, MAX_BONUS do
                        local ok2, c = pcall(
                            C_ScenarioInfo.GetCriteriaInfoByStep, stepIdx, i)
                        if not ok2 or not c then break end
                        out("    [" .. i .. "] " .. sniff(c))
                    end
                end
            else
                out("  none")
            end
        end

        -- Every widget-viz getter on C_UIWidgetManager, so unknown widget
        -- types (e.g. the delve lives display, type 30) still decode.
        local GETTERS = {}
        for k, v in pairs(C_UIWidgetManager) do
            if type(v) == "function" and k:find("VisualizationInfo", 1, true) then
                GETTERS[#GETTERS + 1] = k
            end
        end
        table.sort(GETTERS)
        local function dumpWidgetSet(label, setID)
            out("=== widget set: " .. label .. " ("
                .. tostring(setID) .. ") ===")
            if not (setID and C_UIWidgetManager
                    and C_UIWidgetManager.GetAllWidgetsBySetID) then
                out("  unavailable")
                return
            end
            local ok, widgets = pcall(
                C_UIWidgetManager.GetAllWidgetsBySetID, setID)
            if not ok or type(widgets) ~= "table" or #widgets == 0 then
                out("  empty")
                return
            end
            for n, w in ipairs(widgets) do
                if n > 40 then out("  ... (truncated)"); break end
                local line = "  id=" .. tostring(w.widgetID)
                    .. " type=" .. tostring(w.widgetType)
                local got = false
                for _, gname in ipairs(GETTERS) do
                    local getter = C_UIWidgetManager[gname]
                    if getter then
                        local ok2, viz = pcall(getter, w.widgetID)
                        if ok2 and type(viz) == "table" then
                            line = line .. " [" .. gname:gsub(
                                "WidgetVisualizationInfo", ""):gsub(
                                "VisualizationInfo", "") .. "] " .. sniff(viz)
                            if viz.spellInfo and viz.spellInfo.tooltip then
                                line = line .. " spellTooltip="
                                    .. esc(viz.spellInfo.tooltip)
                            end
                            got = true
                            break
                        end
                    end
                end
                if not got then line = line .. " (no getter matched)" end
                out(line)
            end
        end

        dumpWidgetSet("scenario step",
            stepInfo and stepInfo.widgetSetID or nil)
        if C_UIWidgetManager and C_UIWidgetManager.GetTopCenterWidgetSetID then
            dumpWidgetSet("top center",
                C_UIWidgetManager.GetTopCenterWidgetSetID())
        end
        if C_UIWidgetManager and C_UIWidgetManager.GetBelowMinimapWidgetSetID then
            dumpWidgetSet("below minimap",
                C_UIWidgetManager.GetBelowMinimapWidgetSetID())
        end

        out("=== objective tracker text (lives hunt) ===")
        local trkPrinted = 0
        local function walkText(f, d)
            if not f or d > 8 or trkPrinted > 80 then return end
            if f.IsForbidden and f:IsForbidden() then return end
            local okR, regs = pcall(function() return { f:GetRegions() } end)
            if okR then
                for _, r in ipairs(regs) do
                    if r.GetObjectType and r:GetObjectType() == "FontString"
                            and r:IsShown() then
                        local t = r:GetText()
                        if t and t ~= "" then
                            trkPrinted = trkPrinted + 1
                            out("  \"" .. esc(t) .. "\"")
                        end
                    end
                end
            end
            local okC, kids = pcall(function() return { f:GetChildren() } end)
            if okC then for _, c in ipairs(kids) do walkText(c, d + 1) end end
        end
        for _, tn in ipairs({ "ObjectiveTrackerFrame", "ScenarioObjectiveTracker" }) do
            local tf = _G[tn]
            if tf then out("  [" .. tn .. "]"); pcall(walkText, tf, 0) end
        end
        if trkPrinted == 0 then out("  no tracker text found") end

        out("=== delve tracker widget probe (gilded + siblings) ===")
        if C_UIWidgetManager
                and C_UIWidgetManager.GetSpellDisplayVisualizationInfo then
            local probeIDs = { GILDED_WIDGET_ID }
            for _, id in ipairs(DELVE_TRACKER_WIDGETS) do
                probeIDs[#probeIDs + 1] = id
            end
            for _, wid in ipairs(probeIDs) do
                local ok, viz = pcall(
                    C_UIWidgetManager.GetSpellDisplayVisualizationInfo, wid)
                if ok and viz and viz.spellInfo then
                    ---@diagnostic disable-next-line: undefined-field
                    local shown = tostring(viz.shownState)
                    out("  widget " .. wid
                        .. " shownState=" .. shown
                        .. " spellID=" .. tostring(viz.spellInfo.spellID)
                        .. " tooltip=" .. esc(viz.spellInfo.tooltip))
                else
                    out("  widget " .. wid .. ": nil")
                end
            end
        end

        out("=== spell-display sweep 7000-8200 (widgets with data) ===")
        if C_UIWidgetManager
                and C_UIWidgetManager.GetSpellDisplayVisualizationInfo then
            local hits = 0
            for wid = 7000, 8200 do
                local ok, viz = pcall(
                    C_UIWidgetManager.GetSpellDisplayVisualizationInfo, wid)
                if ok and viz and viz.spellInfo
                        and (viz.spellInfo.tooltip or viz.spellInfo.spellID) then
                    hits = hits + 1
                    out("  widget " .. wid
                        .. " spellID=" .. tostring(viz.spellInfo.spellID)
                        .. " tooltip=" .. esc(viz.spellInfo.tooltip))
                end
            end
            out("  sweep done - " .. hits .. " widget(s) with data")
        end

        out("=== nemesis/banner player auras ===")
        if C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID then
            local auraIDs = {
                1239535, 1270179, 472952,           -- Nemesis Strongbox
                RAGER_SPAWN_SPELL, RAGER_SPELL,     -- Voidfused Rager pair
            }
            for sid in pairs(BANNER_INTERACT_SPELLS) do
                auraIDs[#auraIDs + 1] = sid
            end
            for _, id in ipairs(BANNER_BUFFS) do
                auraIDs[#auraIDs + 1] = id
            end
            local found = 0
            for _, sid in ipairs(auraIDs) do
                local ok, aura = pcall(C_UnitAuras.GetPlayerAuraBySpellID, sid)
                if ok and aura then
                    found = found + 1
                    out("  aura " .. sid .. " '" .. tostring(aura.name)
                        .. "' stacks=" .. tostring(aura.applications))
                end
            end
            if found == 0 then out("  none of the tracked auras present") end
        end

        out("=== current player buffs (name + live spellID) ===")
        if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
            local n = 0
            for i = 1, 60 do
                local ok, aura = pcall(
                    C_UnitAuras.GetAuraDataByIndex, "player", i, "HELPFUL")
                if not ok or not aura then break end
                n = n + 1
                out("  " .. tostring(aura.spellId) .. " " .. esc(aura.name)
                    .. ((aura.applications and aura.applications > 1)
                        and (" x" .. aura.applications) or ""))
            end
            if n == 0 then out("  none") end
        else
            out("  aura API unavailable")
        end

        out("=== recent player casts (newest last) ===")
        if #castLog == 0 then out("  none recorded") end
        for _, sid in ipairs(castLog) do
            local nm = C_Spell and C_Spell.GetSpellName
                and C_Spell.GetSpellName(sid) or "?"
            out("  " .. tostring(sid) .. " " .. esc(nm))
        end

        out("=== banner state machine ===")
        local ragerNpcID = ragerGUID
            and select(6, strsplit("-", ragerGUID)) or nil
        out("  state=" .. tostring(bannerState)
            .. " ragerGUID=" .. tostring(ragerGUID)
            .. " ragerNpcID=" .. tostring(ragerNpcID))
        out("  nemesisPacksRemaining=" .. tostring(nemesisRemaining)
            .. " seenCount=" .. tostring(nemesisSeenCount))
        out("=== keyword-matched delve messages ===")
        if #stickyMsgs == 0 then out("  none captured") end
        for _, m in ipairs(stickyMsgs) do out("  " .. esc(m)) end
        out("=== last delve broadcast messages ===")
        if #msgLog == 0 then out("  none captured") end
        for _, m in ipairs(msgLog) do out("  " .. esc(m)) end

        out("=== vignettes (nearby collectibles/rares) ===")
        if C_VignetteInfo and C_VignetteInfo.GetVignettes then
            local ok, vigs = pcall(C_VignetteInfo.GetVignettes)
            if ok and type(vigs) == "table" and #vigs > 0 then
                for _, guid in ipairs(vigs) do
                    local ok2, v = pcall(C_VignetteInfo.GetVignetteInfo, guid)
                    if ok2 and v then
                        local npcID
                        if v.objectGUID then
                            local okN, n = pcall(function()
                                return select(6, strsplit("-", v.objectGUID))
                            end)
                            if okN then npcID = n end
                        end
                        out("  " .. esc(v.name)
                            .. " vignetteID=" .. tostring(v.vignetteID)
                            .. " npcID=" .. tostring(npcID)
                            .. " vguid=" .. esc(guid)
                            .. " objGUID=" .. esc(v.objectGUID)
                            .. " onMinimap=" .. tostring(v.onMinimap))
                    end
                end
            else
                out("  none")
            end
        else
            out("  API unavailable")
        end

        -- The entrance picker's modifier tooltips state the authoritative nemesis
        -- total ("Enemy groups affected: N"); dump with the entrance screen OPEN.
        out("=== C_DelvesUI API + no-arg Get* returns ===")
        if C_DelvesUI then
            local duiNames = {}
            for k, v in pairs(C_DelvesUI) do
                if type(v) == "function" then duiNames[#duiNames + 1] = k end
            end
            table.sort(duiNames)
            out("  fns: " .. esc(table.concat(duiNames, ", ")))
            for _, fname in ipairs(duiNames) do
                if fname:find("^Get") then
                    local ok, r1 = pcall(C_DelvesUI[fname])
                    if ok and r1 ~= nil then
                        if type(r1) == "table" then
                            out("    " .. fname .. "() -> {" .. sniff(r1) .. "}")
                        else
                            out("    " .. fname .. "() -> " .. esc(r1))
                        end
                    end
                end
            end
        else
            out("  C_DelvesUI: absent")
        end

        out("=== delve entrance picker (open the entrance, then dump) ===")
        local picker = _G.DelvesDifficultyPickerFrame
        local pShown = false
        if picker and picker.IsShown then
            local okS, s = pcall(picker.IsShown, picker)
            pShown = okS and s
        end
        if not pShown then
            picker = nil
            -- Fallback: any shown frame named like the picker.
            for nm, f in pairs(_G) do
                if type(nm) == "string" and nm:find("Delve", 1, true)
                        and nm:find("Picker", 1, true)
                        and type(f) == "table" and f.IsShown then
                    local okS, s = pcall(f.IsShown, f)
                    if okS and s then picker = f; pShown = true; break end
                end
            end
        end
        if picker and pShown then
            out("  picker: " .. (picker.GetName and picker:GetName() or "?"))
            local seenT, nT = {}, 0
            local function walk(f, d)
                if not f or d > 7 or nT > 150 then return end
                if f.IsForbidden and f:IsForbidden() then return end
                local okR, regs = pcall(function() return { f:GetRegions() } end)
                if okR then
                    for _, r in ipairs(regs) do
                        if r.GetObjectType and r:GetObjectType() == "FontString" then
                            local okT, t = pcall(r.GetText, r)
                            if okT and type(t) == "string" and t ~= ""
                                    and not seenT[t] then
                                seenT[t] = true; nT = nT + 1
                                out("    \"" .. esc(t) .. "\"")
                            end
                        end
                    end
                end
                local okC, kids = pcall(function() return { f:GetChildren() } end)
                if okC then for _, c in ipairs(kids) do walk(c, d + 1) end end
            end
            pcall(walk, picker, 0)
            for _, fld in ipairs({ "widgetSetID", "widgetSet", "uiWidgetSetID" }) do
                local sid = picker[fld]
                if type(sid) == "number" then
                    dumpWidgetSet("picker." .. fld, sid)
                end
            end
        else
            out("  picker not shown — open a delve entrance, then /ed objdump")
        end

        -- Whatever tooltip is up now (hover the modifier icon if the FontString
        -- walk didn't surface the count).
        if GameTooltip and GameTooltip.IsShown and GameTooltip:IsShown()
                and GameTooltip.NumLines then
            out("=== GameTooltip currently shown ===")
            for i = 1, GameTooltip:NumLines() do
                local fs = _G["GameTooltipTextLeft" .. i]
                local t = fs and fs.GetText and fs:GetText()
                if t and t ~= "" then out("  " .. esc(t)) end
            end
        end

        out("=== end — screenshot/paste me everything above ===")
    end

    -- Covers enabling the option, then /reload inside a delve.
    QueueRefresh()
end)
