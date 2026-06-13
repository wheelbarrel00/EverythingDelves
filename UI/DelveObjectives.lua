------------------------------------------------------------------------
-- UI/DelveObjectives.lua — "Bonus Spoils" tracker
-- Optional (off by default) on-screen window that tracks ONLY the two
-- bonus-chest mechanics a player sets up during a delve and collects
-- after the boss:
--   1. Nemesis Strongbox — kill all the Pactsworn "Nullaeus' Minions"
--      packs (counted via their map vignettes) to max the strongbox.
--   2. Sanctified Banner — find/click the banner (bountiful delves) for
--      bonus Sanctified Spoils, upgraded to Grand Spoils if its elite
--      (Voidfused Rager) is slain.
-- Each gets a checkbox line; a green footer ("Bonus loot secured") shows
-- the moment both are done, so a player knows they can safely pull the
-- boss. Regular scenario objectives are intentionally NOT listed.
-- Toggled in Options -> Display or via /ed obj; position saved on drag.
-- Detection is lockdown-safe (no combat log / no enemy nameplates — see
-- the banner/nemesis notes below) and fully pcall-guarded.
-- /ed objdump dumps the raw scenario/widget/vignette data for diagnosis.
------------------------------------------------------------------------
local E = EverythingDelves

------------------------------------------------------------------------
-- Tunables
------------------------------------------------------------------------
local WIN_W      = 290
local PAD        = 10
local MAX_LINES  = 40
local MAX_CRIT   = 25   -- criteria iteration cap per step (safety)
local MAX_BONUS  = 15   -- criteria cap per bonus step

-- The weekly Gilded Stash spell-display widget (already captured by the
-- core file). Skipped in the generic widget pass and rendered as its
-- own clearly-labeled weekly line instead.
local GILDED_WIDGET_ID = 7591

------------------------------------------------------------------------
-- Researched IDs — client build 12.0.5.67823 (wago.tools SpellName +
-- UiWidget tables). Do not trim "duplicate" spell IDs: each mechanic
-- ships trigger/aura pairs and either one may be what the combat log
-- carries on the live realm.
------------------------------------------------------------------------

-- Nemesis Strongbox affix (Tier 4+): defeating Pactsworn packs upgrades
-- the strongbox at the end of the delve (1 pack at T4-5, 2 at T6-7, 3
-- at T8-9, 4 at T10+). There is NO in-delve progress widget — the
-- Nemesis spell-display widgets (spellIDs 1239535 / 1270179 / 472952)
-- live ONLY on the entrance picker. In-delve, progress is read by
-- counting the "Nullaeus' Minions" map vignettes (NEMESIS_PACK_VIGNETTE
-- below).

-- Sanctified Banner (bountiful delves): clicking the banner grants a
-- Light buff and/or spawns a Voidfused Rager elite; either way bonus
-- Sanctified Spoils drop at the end — Grand Sanctified Spoils if the
-- Rager is killed. Blizzard ships NO tracker for it; this is ours.
-- MIDNIGHT LOCKDOWN NOTES (both confirmed live 2026-06-10):
--   * COMBAT_LOG_EVENT_UNFILTERED registration is a PROTECTED action
--     (ADDON_ACTION_FORBIDDEN).
--   * UnitName() on enemy units in delves returns a SECRET string —
--     any string method on it errors ("secret string value, while
--     execution tainted").
-- So banner detection runs entirely on APIs proven unrestricted:
-- player auras (UNIT_AURA + GetPlayerAuraBySpellID) and VIGNETTES
-- (C_VignetteInfo names print clean in delves — the gray-helm pack
-- icons, rares and treasures are all vignettes).
local BANNER_INTERACT_SPELLS = {
    [1269411] = true, [1269412] = true, [1269416] = true,  -- Sanctified Banner
}
local RAGER_SPAWN_SPELL = 1271184  -- "Voidfused Rager Spawn" (aura sweep only)
local RAGER_SPELL       = 1271189  -- "Voidfused Rager" (aura sweep only)
-- The Rager is spotted via its vignette name for now (EN clients); its
-- vignetteID isn't known yet — /ed objdump prints every vignette's
-- vignetteID so it can be hardcoded (localization-free) next pass.
local RAGER_NAME_MATCH = "Voidfused"

-- Nemesis pack map vignette ("Nullaeus' Minions", the gray helm icons):
-- one vignette per REMAINING pack, gone when the pack dies. Confirmed
-- live on a T11 (objdump 2026-06-10): 4 at entry -> 3 -> 2 after each
-- kill. No widget exposes this — vignette counting IS the data source.
-- vignetteID is localization-free. NOTE: the Nullaeus delve reuses the
-- same vignette for its own minions; the counter is suppressed there.
local NEMESIS_PACK_VIGNETTE = 7531
local BANNER_BUFFS = {             -- any of these on the player = banner used
    1271918, 1271945,                      -- Sanctified Touch
    1272609, 1272666,                      -- Holy Fervor
    1272756, 1272769,                      -- Ward of Light
    1272809, 1272810, 1272813, 1272814,    -- Light's Judgement
    1273058, 1273066,                      -- Holy Reinforcements
}

-- Delve scenario-header icon widgets (the 'delveDifficultyScaling' /
-- VisID 2350 family). These turned out to be ENTRANCE-ONLY — gone once
-- inside a delve — so they no longer drive the window; kept solely for
-- the /ed objdump probe section.
local DELVE_TRACKER_WIDGETS = { 7526, 7592, 7624, 7761, 7764, 7861 }

-- Message events that can carry delve broadcast text ("A Sanctified
-- Banner has manifested within."). The exact carrier event is captured
-- live via the /ed objdump message log.
local MSG_EVENTS = {
    CHAT_MSG_RAID_BOSS_EMOTE = true,
    CHAT_MSG_MONSTER_YELL    = true,
    CHAT_MSG_MONSTER_EMOTE   = true,
    CHAT_MSG_MONSTER_SAY     = true,
    UI_INFO_MESSAGE          = true,
    CHAT_MSG_SYSTEM          = true,
}

-- Inline status icons (texture escapes render in any font)
local ICON_DONE = "|TInterface\\RaidFrame\\ReadyCheck-Ready:11:11:0:-1|t "
local ICON_FAIL = "|TInterface\\RaidFrame\\ReadyCheck-NotReady:11:11:0:-1|t "
local ICON_TODO = "|TInterface\\Buttons\\UI-CheckBox-Up:13:13:-1:-1|t "

------------------------------------------------------------------------
-- Small helpers
------------------------------------------------------------------------

--- Strip color / texture / atlas escapes so our own line coloring isn't
--- broken by codes embedded in widget text.
local function StripEscapes(s)
    if not s then return nil end
    return (s:gsub("|c%x%x%x%x%x%x%x%x", "")
             :gsub("|r", "")
             :gsub("|T.-|t", "")
             :gsub("|A.-|a", ""))
end

--- True only while the player is PHYSICALLY inside a delve instance
--- (difficulty 208 = Delves). This is the live, authoritative test:
--- GetInstanceInfo flips the moment the player zones out, so the window
--- disappears on exit instead of lingering until the next /reload. It
--- deliberately does NOT consult runState.inDelve — that tracked-run
--- flag can be left stale on some exit paths, and OR-ing it in kept the
--- window up until a reload cleared it. The difficulty check already
--- spans the entire time the player is inside: the whole tracked run AND
--- the post-SCENARIO_COMPLETED looting window (still 208 while looting
--- chests), so nothing is lost by dropping the runState term.
local function PlayerInDelve()
    return select(3, GetInstanceInfo()) == 208
end

------------------------------------------------------------------------
-- MODULE INIT
------------------------------------------------------------------------
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

    -- Saved (or default) position
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
        GameTooltip:AddLine("Bonus Spoils", 1, 1, 1)
        GameTooltip:AddLine("Nemesis Strongbox packs + the Sanctified"
            .. " Banner — the bonus loot to grab before the boss."
            .. " Drag to move; toggle in Options or with /ed obj.",
            0.7, 0.7, 0.7, true)
        GameTooltip:Show()
    end)
    win:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- Title + divider
    local titleFS = win:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    titleFS:SetPoint("TOPLEFT", win, "TOPLEFT", PAD, -8)
    titleFS:SetWidth(WIN_W - 2 * PAD)
    titleFS:SetJustifyH("LEFT")
    titleFS:SetWordWrap(false)
    titleFS:SetFont(titleFS:GetFont(), 12, "OUTLINE")

    local titleDiv = win:CreateTexture(nil, "ARTWORK")
    titleDiv:SetHeight(1)
    titleDiv:SetPoint("TOPLEFT",  win, "TOPLEFT",  1, -26)
    titleDiv:SetPoint("TOPRIGHT", win, "TOPRIGHT", -1, -26)
    E:StyleAccentDivider(titleDiv)

    --------------------------------------------------------------------
    -- Sanctified Banner state machine (module-local, mirrored into
    -- E.db.activeRun so a mid-run /reload doesn't lose it — the same
    -- pattern the core uses for deaths/tier). States only move forward:
    --   announced -> clicked -> buffed -> eliteUp -> grand
    -- "announced" = the manifest broadcast was seen; "clicked" = a
    -- lingering banner-interact aura on the player; "buffed" = a banner
    -- Light buff landed on the player; "eliteUp" = the Voidfused
    -- Rager's nameplate appeared; "grand" = its plate went away with
    -- the unit dead (Grand Sanctified Spoils earned).
    --------------------------------------------------------------------
    local bannerState = nil
    local ragerGUID   = nil  -- the Rager's VIGNETTE guid once spotted
    local lastRunKey  = nil
    local msgLog      = {}   -- rolling delve broadcast log (diagnostics)
    local stickyMsgs  = {}   -- keyword-matched messages, never rotated out
    local ScanVignettes      -- defined after SetBannerState; called from
                             -- RefreshContent via this forward local
    -- Nemesis pack counting (vignette 7531 instances = packs remaining).
    -- Packs can spawn/appear ONE AT A TIME (kill one, the next shows), so the
    -- most-seen-at-once count undercounts kills — it stays at 1 and renders
    -- "1/3" even after all three die. Instead accumulate the DISTINCT pack-
    -- vignette GUIDs ever seen this run; killed = seenCount - remaining. The
    -- line renders only after a pack has actually been seen, which avoids a
    -- false "done" before vignettes load and self-hides in delves without the
    -- affix.
    local nemesisRemaining = nil
    local nemesisSeen      = {}   -- vguid -> true (distinct packs seen this run)
    local nemesisSeenCount = 0
    -- Recent player casts (spell IDs, newest last). The banner interact
    -- is expected to surface here even when it grants no buff and
    -- spawns no elite — and the ring doubles as an objdump diagnostic.
    local castLog = {}

    --------------------------------------------------------------------
    -- Line pool + streaming layout state (reset every refresh).
    -- FontStrings are created once and reused; SetText only fires when
    -- a line actually changed, keeping per-update garbage near zero.
    --------------------------------------------------------------------
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

    --- Section headers are lazy: only written when the section turns
    --- out to have at least one line.
    local function SetSection(title)
        pendingHeader = title
    end
    local function FlushHeader()
        if pendingHeader then
            AddLine(E.CC.muted .. pendingHeader .. E.CC.close, true)
            pendingHeader = nil
        end
    end

    --- Emit one objective line with check state + progress, and count
    --- it toward the everything-done footer.
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

    --- Read the live delve tier from the scenario-header widget
    --- (ScenarioHeaderDelves, e.g. 6183) — its tierText is more reliable
    --- than runState.tier (the core's entry latch can hold the previous
    --- delve's tier until completion re-reads it).
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

    --------------------------------------------------------------------
    -- Content refresh
    --------------------------------------------------------------------
    local function RefreshContent()
        wipe(seen)
        lineIdx, yOff = 0, -32
        objDone, objTotal = 0, 0
        pendingHeader = nil

        local rs = E.delveRunState

        -- New tracked run: reset the banner machine, then restore the
        -- persisted state when this is a /reload-resumed run (the saved
        -- activeRun carries the same startTime). After SCENARIO_COMPLETED
        -- rs.inDelve goes false but the player is still inside looting —
        -- deliberately no reset on that path, so "Grand Spoils earned!"
        -- survives until the next real run begins.
        if rs and rs.inDelve then
            local runKey = (rs.delveName or "?") .. "#" .. tostring(rs.startTime or 0)
            if runKey ~= lastRunKey then
                lastRunKey = runKey
                bannerState, ragerGUID = nil, nil
                nemesisRemaining, nemesisSeenCount = nil, 0
                wipe(nemesisSeen)
                wipe(msgLog)
                wipe(stickyMsgs)
                wipe(castLog)
                local ar = E.db and E.db.activeRun
                if ar and ar.startTime == rs.startTime then
                    bannerState = ar.bannerState
                    ragerGUID   = ar.bannerRagerGUID
                end
            end
        end

        -- Fresh vignette pass before any line renders: feeds both the
        -- nemesis pack counter and the banner state machine.
        if ScanVignettes then pcall(ScanVignettes) end

        local name = (rs and rs.delveName) or GetRealZoneText() or "Delve"
        local stepInfo
        if C_ScenarioInfo and C_ScenarioInfo.GetScenarioStepInfo then
            local ok, si = pcall(C_ScenarioInfo.GetScenarioStepInfo)
            if ok then stepInfo = si end
        end
        -- Live tier for the title (beats the core's entry latch).
        local liveTier = ReadLiveTier(stepInfo)

        -- (1) Nemesis Strongbox packs, counted via their map vignettes
        --     (one vignette per remaining pack; killed = peak - left).
        --     Total = max(tier table, most packs seen at once); renders
        --     only after a pack has been SEEN this run, so no false
        --     "done" before vignettes load and nothing in delves
        --     without the affix. Every standard delve (incl. The Shadow
        --     Enclave) is delveKind "regular" and counts normally. The
        --     seasonal Nullaeus delve (Torment's Rise, delveKind
        --     "nemesis") is excluded by design: user-confirmed it's a
        --     straight-to-boss fight with NO Pactsworn packs / no
        --     strongbox, so the counter must never appear there.
        SetSection(nil)
        if rs and rs.inDelve and rs.delveKind ~= "nemesis"
                and nemesisSeenCount > 0 then
            local tierNow = liveTier or (rs.tier or 0)
            local expected = 0
            if     tierNow >= 10 then expected = 4
            elseif tierNow >= 8  then expected = 3
            elseif tierNow >= 6  then expected = 2
            elseif tierNow >= 4  then expected = 1
            end
            -- killed = (distinct packs ever seen) - (currently remaining).
            -- Counting distinct GUIDs rather than the peak seen at once means
            -- packs that appear one-at-a-time still tally: each is added to the
            -- seen set when its vignette shows, and counted as killed once that
            -- vignette is gone. Total is the tier's expected count, raised to
            -- seenCount only if more packs somehow appear than the table predicts.
            local total  = math.max(expected, nemesisSeenCount)
            local killed = math.max(0, nemesisSeenCount - (nemesisRemaining or 0))
            EmitObjective(
                "Nemesis Strongbox: " .. killed .. "/" .. total .. " packs",
                killed >= total, false, nil)
        end

        -- (2) Sanctified Banner (bountiful delves; Blizzard ships no
        --     tracker). State from the aura/cast/vignette machine.
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

        -- Footer: the one-glance answer for the two bonus objectives.
        if objTotal > 0 and objDone >= objTotal then
            AddLine(ICON_DONE .. E.CC.green
                .. "Bonus loot secured - go get the boss!" .. E.CC.close, true)
        elseif objTotal == 0 then
            -- Shown both when a delve has no bonus-spoils mechanics at all
            -- AND after the boss is down / rewards collected (the tracked
            -- objectives drop off once the run ends). Phrased to fit both.
            AddLine(ICON_DONE .. E.CC.green
                .. "All bonus loot accounted for." .. E.CC.close)
        end

        -- Title (rendered last so the live widget tier can win)
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
        win:SetHeight(math.max(64, -yOff + 8))
    end

    --------------------------------------------------------------------
    -- Visibility + throttled refresh
    --------------------------------------------------------------------
    local refreshPending = false
    local ef = CreateFrame("Frame")  -- event frame; handlers wired below

    local function DoRefresh()
        refreshPending = false
        local shouldShow = E.db and E.db.showDelveObjectives and PlayerInDelve()
        if shouldShow then
            -- Banner buff watcher only while active in a delve — zero
            -- cost in raids/dungeons/world. (COMBAT_LOG_EVENT_UNFILTERED
            -- and enemy nameplates are deliberately NOT used: the former
            -- is a protected registration in Midnight, the latter's
            -- UnitName returns a secret string.)
            ef:RegisterUnitEvent("UNIT_AURA", "player")
            ef:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
            -- pcall so one bad API read can't error out of an event
            -- handler and kill the window for the rest of the session.
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

    --------------------------------------------------------------------
    -- Banner state transitions (forward-only, persisted into activeRun)
    --------------------------------------------------------------------
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

    --- Player-aura driven detection (UNIT_AURA, "player"-filtered):
    --- any banner Light buff = "buffed"; a lingering banner interact
    --- aura (if one exists — the objdump sweep confirms) = "clicked".
    --- Early-outs keep this cheap during combat aura churn.
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

    --- Player-cast driven detection (UNIT_SPELLCAST_SUCCEEDED, player-
    --- filtered): interacting with the banner is expected to fire one
    --- of the Sanctified Banner spells as a player cast — the only
    --- signal that covers the no-buff/no-elite outcome. Every cast is
    --- also ring-logged for the objdump diagnostic.
    local function HandlePlayerCast(spellID)
        if not spellID or not PlayerInDelve() then return end
        -- 60 deep: an elite fight right after a banner click can burn
        -- 25+ GCDs, and the interact cast must survive until a safe
        -- post-fight /ed objdump.
        if #castLog >= 60 then table.remove(castLog, 1) end
        castLog[#castLog + 1] = spellID
        if BANNER_INTERACT_SPELLS[spellID] then
            SetBannerState("clicked")
        end
    end

    --- Vignette-driven detection (UnitName on delve enemies returns a
    --- SECRET string in Midnight, so nameplates are unusable — vignette
    --- names are proven clean). The Rager, the banner, and the Spoils
    --- chests all surface as vignettes when relevant. A Rager vignette
    --- that vanishes after being seen = killed (vignettes in a delve
    --- are zone-wide in GetVignettes, so disappearance isn't a range
    --- artifact). Name matching is EN-only until vignetteIDs are
    --- captured via /ed objdump and hardcoded.
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
                -- Accumulate distinct pack GUIDs (one per pack) so kills are
                -- counted even when packs are never all on the map at once.
                if not nemesisSeen[vguid] then
                    nemesisSeen[vguid] = true
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
    end

    --- Broadcast/system text: catches the banner manifest announcement
    --- and feeds the diagnostic message log for /ed objdump.
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

    -- Safety-net ticker while shown: catches widget tooltip changes
    -- that arrive without a scenario event.
    local ticker
    win:SetScript("OnShow", function()
        if not ticker then
            ticker = C_Timer.NewTicker(3, QueueRefresh)
        end
    end)
    win:SetScript("OnHide", function()
        if ticker then
            ticker:Cancel()
            ticker = nil
        end
    end)

    -- Event wiring (the core dispatcher is single-handler-per-event,
    -- and the delve lifecycle frame already owns these events; frames
    -- receive events in registration order, so the core handlers have
    -- already updated E.delveRunState by the time these fire).
    -- UNIT_AURA (player) and the nameplate events are registered
    -- dynamically in DoRefresh, only while the window is active inside
    -- a delve.
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
            -- pcall: chat/system text could be a Midnight secret string
            -- in some future context; never let that kill the handler.
            pcall(HandleMessage, event, ...)
            return
        end
        -- High-frequency world events: only react while the window is
        -- actually up (vignette updates fire constantly in the world).
        if (event == "UPDATE_UI_WIDGET"
                or event == "VIGNETTE_MINIMAP_UPDATED"
                or event == "VIGNETTES_UPDATED")
                and not win:IsShown() then
            -- Keep the nemesis pack tally accurate even while the window is
            -- hidden, so opening it mid-run shows the right count (packs can be
            -- killed before the window is ever shown). ScanVignettes self-gates
            -- to PlayerInDelve(), so this is cheap; no redraw needed when hidden.
            if (event == "VIGNETTE_MINIMAP_UPDATED" or event == "VIGNETTES_UPDATED")
                    and ScanVignettes then
                pcall(ScanVignettes)
            end
            return
        end
        QueueRefresh()
    end)

    --------------------------------------------------------------------
    -- Public: re-evaluate visibility now (Options checkbox / slash)
    --------------------------------------------------------------------
    function E:UpdateDelveObjectivesWindow()
        DoRefresh()
    end

    --------------------------------------------------------------------
    -- Public: /ed objdump — raw dump of every objective-ish data source
    -- so unknown counters (strongboxes, flags) can be located on the
    -- live client and wired into the window precisely.
    --------------------------------------------------------------------
    function E:DumpDelveObjectiveData()
        local function out(s) print("|cFFFFD700[ED obj]|r " .. s) end
        local function esc(v)
            local s = tostring(v)
            if #s > 90 then s = s:sub(1, 90) .. "..." end
            return (s:gsub("|", "||"))
        end
        --- Flatten a viz-info table's scalar fields to one sorted line.
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

        -- Widget sweep: the step's widget set plus the two standalone
        -- HUD sets. Tries every known getter until one returns data.
        local GETTERS = {
            "GetTextWithStateWidgetVisualizationInfo",
            "GetIconAndTextWidgetVisualizationInfo",
            "GetStatusBarWidgetVisualizationInfo",
            "GetSpellDisplayVisualizationInfo",
            "GetDoubleStatusBarWidgetVisualizationInfo",
            "GetDiscreteProgressStepsVisualizationInfo",
            "GetTextureAndTextWidgetVisualizationInfo",
            "GetTextureAndTextRowVisualizationInfo",
            "GetIconTextAndBackgroundWidgetVisualizationInfo",
            "GetTextColumnRowVisualizationInfo",
            "GetBulletTextListWidgetVisualizationInfo",
            "GetScenarioHeaderCurrenciesAndBackgroundWidgetVisualizationInfo",
            "GetScenarioHeaderDelvesWidgetVisualizationInfo",
            "GetItemDisplayVisualizationInfo",
            "GetTextWithSubtextWidgetVisualizationInfo",
        }
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
                    -- shownState is a real field on widget vis-info
                    -- structs; the IDE's API stubs just omit it.
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
                            .. " atlas=" .. esc(v.atlasName)
                            .. " onMinimap=" .. tostring(v.onMinimap))
                    end
                end
            else
                out("  none")
            end
        else
            out("  API unavailable")
        end

        -- Delve entrance picker: the modifier tooltips here state the
        -- exact "Enemy groups affected: N" (authoritative nemesis total)
        -- and whether a Sanctified Banner is present. Run /ed objdump
        -- while the entrance screen is OPEN to capture it.
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
            -- Fallback: scan for any shown frame named like the picker.
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

        -- Whatever tooltip is up right now (hover the modifier icon and
        -- run this if the FontString walk didn't surface the count).
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

    -- Initial state (handles enabling the option, then /reload inside
    -- a delve: PLAYER_ENTERING_WORLD also fires after login, but this
    -- costs nothing and covers every path).
    QueueRefresh()
end)
