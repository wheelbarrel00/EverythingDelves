------------------------------------------------------------------------
-- Core/SpeedRank.lua
-- Speed & value ranking engine for today's delves.
--
-- Answers three questions for any delve:
--   1. How fast can I clear it?          (E:GetDelveSpeed)
--   2. How quick is that, relatively?    (E:GetSpeedGrade)
--   3. What's the best reward-per-minute? (E:GetDelveValue)
--
-- "Speed" prefers the player's OWN average completion time from history.
-- For a delve they've never run, the estimate is calibrated to that
-- character's overall pace (so a geared main and a levelling alt each see
-- realistic numbers) and shaped by the delve's reward tier, which already
-- tracks how direct its route is. Speed grades are likewise relative to
-- the player's own pace, not a fixed scale.
------------------------------------------------------------------------
local E = EverythingDelves

local math_floor, math_huge = math.floor, math.huge

------------------------------------------------------------------------
-- Relative clear-time by reward tier (SHAPE only — the absolute scale
-- comes from the player's own pace, see GetPersonalPaceBaseline). The
-- reward tier already reflects route efficiency (direct path, mountable,
-- few detour objectives), so a higher tier maps to a faster clear.
-- Normalised so B = 1.0. Tune the spread here if estimates feel too
-- aggressive between tiers.
------------------------------------------------------------------------
local TIER_TIME_FACTOR = {
    S = 0.60,
    A = 0.80,
    B = 1.00,
    C = 1.25,
    D = 1.50,
    F = 1.85,
}

-- Neutral B-tier baseline (seconds) used ONLY for a character that has no
-- run history at all yet. The moment they finish their first delve, their
-- own pace takes over and this is never consulted again.
local FALLBACK_BASELINE = 360

-- Reward weight per tier, used for value-per-minute scoring. Higher tier =
-- more loot/efficiency value packed into the run.
local TIER_REWARD_WEIGHT = {
    S = 6, A = 5, B = 4, C = 3, D = 2, F = 1,
}

-- A bountiful delve drops noticeably better rewards, so it's worth more
-- per run; nudge its value score up without letting it dominate a much
-- faster non-bountiful pick.
local BOUNTIFUL_VALUE_MULT = 1.5

------------------------------------------------------------------------
-- Speed grade buckets, measured as a RATIO to the player's own pace
-- baseline (so a grade means "fast/slow for THIS character", not against
-- some fixed speedrun scale). 1.0 = a typical clear for you. Deliberately
-- worded (not lettered) with a green->red ramp so the speed read never
-- gets confused with the gold S/A/B/C/D/F reward-tier badge.
------------------------------------------------------------------------
local SPEED_GRADES = {
    { max = 0.75,     label = "Fast",    rgb = { 0.25, 0.90, 0.40 } },
    { max = 0.95,     label = "Brisk",   rgb = { 0.60, 0.85, 0.25 } },
    { max = 1.15,     label = "Average", rgb = { 0.95, 0.82, 0.25 } },
    { max = 1.50,     label = "Slow",    rgb = { 0.95, 0.55, 0.25 } },
    { max = math_huge,label = "Long",    rgb = { 0.88, 0.40, 0.34 } },
}

------------------------------------------------------------------------
-- Format a duration in seconds as "M:SS" (or "<1m" guard). Kept local so
-- the engine doesn't depend on a tab's private formatter.
------------------------------------------------------------------------
function E:FormatClock(sec)
    sec = sec or 0
    if sec <= 0 then return "--" end
    local m = math_floor(sec / 60)
    local s = sec % 60
    return string.format("%d:%02d", m, s)
end

------------------------------------------------------------------------
-- Resolve a delve's effective reward tier for TODAY: today's live story
-- variant tier if it's rated, otherwise the delve's signature tier.
-- Callers that already know today's tier (the Locations tab caches it)
-- can pass it as `tierOverride` to skip the POI re-read.
------------------------------------------------------------------------
function E:GetDelveTierLetter(delveName, tierOverride)
    if tierOverride then return tierOverride end
    -- Today's live variant tier wins.
    local story = self.GetDelveStoryVariant and self:GetDelveStoryVariant(delveName)
    if story and story ~= "" and self.GetStoryTier then
        local si = self:GetStoryTier(story)
        if si and si.tier then return si.tier end
    end
    -- Fall back to the delve's signature tier (published by the Locations
    -- tab from its per-delve notes table).
    local sig = self.DelveSignatureTier and self.DelveSignatureTier[delveName]
    return sig
end

------------------------------------------------------------------------
-- The player's personal pace, expressed as a "B-tier-equivalent" clear
-- time in seconds. We take every delve they've actually run, divide its
-- average clear time by that delve's tier factor to normalise it to a
-- common B-tier scale, then average those. The result captures how fast
-- THIS character clears delves (gear + skill) independent of which tiers
-- they happened to run. Returns nil if they have no usable history yet.
------------------------------------------------------------------------
function E:GetPersonalPaceBaseline()
    if not (self.db and self.db.delveHistory) then return nil end
    local sum, n = 0, 0
    for name, entry in pairs(self.db.delveHistory) do
        local life = entry.lifetime
        if life and (life.totalRuns or 0) > 0 and (life.totalDuration or 0) > 0 then
            local avg = life.totalDuration / life.totalRuns
            -- Normalise by the delve's signature tier (stable, unlike the
            -- daily-rotating variant tier).
            local tier = self.DelveSignatureTier and self.DelveSignatureTier[name]
            local factor = tier and TIER_TIME_FACTOR[tier]
            if factor and avg > 0 then
                sum = sum + (avg / factor)
                n = n + 1
            end
        end
    end
    if n == 0 then return nil end
    return sum / n
end

------------------------------------------------------------------------
-- Expected clear time for a delve, in seconds.
-- Returns: seconds, source, tierLetter
--   source = "personal" (your own logged average for THIS delve) or
--            "estimate"  (calibrated to your overall pace, shaped by the
--                         delve's tier; marked * when shown).
-- Returns nil if we can't form any estimate (unknown tier).
------------------------------------------------------------------------
function E:GetDelveSpeed(delveName, tierOverride)
    if not delveName then return nil end

    -- 1) Personal average from logged history (most accurate — it's the
    --    player's real pace at their own gear/skill level).
    local hist = self.GetDelveHistory and self:GetDelveHistory(delveName)
    local life = hist and hist.lifetime
    if life and (life.totalRuns or 0) > 0 and (life.totalDuration or 0) > 0 then
        local avg = math_floor(life.totalDuration / life.totalRuns)
        if avg > 0 then
            return avg, "personal", self:GetDelveTierLetter(delveName, tierOverride)
        end
    end

    -- 2) Pace-calibrated estimate: scale the player's own baseline by the
    --    target delve's tier factor. Falls back to a neutral baseline only
    --    when the character has no run history anywhere yet.
    local tier = self:GetDelveTierLetter(delveName, tierOverride)
    local factor = tier and TIER_TIME_FACTOR[tier]
    if not factor then return nil end
    local baseline = self:GetPersonalPaceBaseline() or FALLBACK_BASELINE
    return math_floor(baseline * factor), "estimate", tier
end

------------------------------------------------------------------------
-- Map a clear time to a speed grade, relative to the player's own pace.
-- Returns: label, r, g, b.
------------------------------------------------------------------------
function E:GetSpeedGrade(seconds)
    local last = SPEED_GRADES[#SPEED_GRADES]
    if not seconds or seconds <= 0 then
        return last.label, last.rgb[1], last.rgb[2], last.rgb[3]
    end
    local baseline = self:GetPersonalPaceBaseline() or FALLBACK_BASELINE
    local ratio = seconds / baseline
    for _, g in ipairs(SPEED_GRADES) do
        if ratio <= g.max then
            return g.label, g.rgb[1], g.rgb[2], g.rgb[3]
        end
    end
    return last.label, last.rgb[1], last.rgb[2], last.rgb[3]
end

-- Convenience: a "|cFFRRGGBB" colour escape for a clear time.
function E:SpeedColorCode(seconds)
    local _, r, g, b = self:GetSpeedGrade(seconds)
    return string.format("|cFF%02X%02X%02X",
        math_floor(r * 255), math_floor(g * 255), math_floor(b * 255))
end

------------------------------------------------------------------------
-- Value-per-minute score for a delve today. Higher is better.
-- Returns: score, seconds, tierLetter, source   (nil if unrankable).
-- score = rewardWeight(tier) / minutes, x1.5 if it's bountiful today.
------------------------------------------------------------------------
function E:GetDelveValue(delveName, tierOverride)
    local seconds, source, tier = self:GetDelveSpeed(delveName, tierOverride)
    if not (seconds and seconds > 0 and tier) then return nil end
    local weight = TIER_REWARD_WEIGHT[tier]
    if not weight then return nil end

    local minutes = seconds / 60
    local score = weight / minutes

    -- Bountiful delves are worth more per run.
    local isBountiful = self.currentBountifulNames
        and (self.currentBountifulNames[delveName]
            or self.currentBountifulNames[delveName:lower()])
    if isBountiful then
        score = score * BOUNTIFUL_VALUE_MULT
    end

    return score, seconds, tier, source
end
