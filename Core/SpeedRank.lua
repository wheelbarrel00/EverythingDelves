local E = EverythingDelves

local math_floor, math_huge, math_min = math.floor, math.huge, math.min

-- Relative clear-time shape by reward tier; absolute scale comes from the
-- player's own pace (GetPersonalPaceBaseline). Normalised so B = 1.0.
local TIER_TIME_FACTOR = {
    S = 0.60,
    A = 0.80,
    B = 1.00,
    C = 1.25,
    D = 1.50,
    F = 1.85,
}

-- B-tier baseline (seconds) for a delve-geared character; the pre-history
-- estimate is this stretched by gear deficit (GetFallbackBaseline). Anchored
-- to E.TierData recGear: ref 210 = no stretch, T1 floor (170) = 1.5x, cap 2.5x.
local FALLBACK_BASELINE = 360
local BASELINE_REF_ILVL = 210
local BASELINE_PER_ILVL = 0.0125
local BASELINE_MAX_MULT = 2.5

local TIER_REWARD_WEIGHT = {
    S = 6, A = 5, B = 4, C = 3, D = 2, F = 1,
}

local BOUNTIFUL_VALUE_MULT = 1.5

-- Speed grade buckets, measured as a ratio to the player's own pace baseline
-- (1.0 = a typical clear for you).
local SPEED_GRADES = {
    { max = 0.75,     label = "Fast",    rgb = { 0.25, 0.90, 0.40 } },
    { max = 0.95,     label = "Brisk",   rgb = { 0.60, 0.85, 0.25 } },
    { max = 1.15,     label = "Average", rgb = { 0.95, 0.82, 0.25 } },
    { max = 1.50,     label = "Slow",    rgb = { 0.95, 0.55, 0.25 } },
    { max = math_huge,label = "Long",    rgb = { 0.88, 0.40, 0.34 } },
}

function E:FormatClock(sec)
    sec = sec or 0
    if sec <= 0 then return "--" end
    local m = math_floor(sec / 60)
    local s = sec % 60
    return string.format("%d:%02d", m, s)
end

-- Today's live story-variant tier wins; otherwise the delve's signature tier.
function E:GetDelveTierLetter(delveName, tierOverride)
    if tierOverride then return tierOverride end
    local story = self.GetDelveStoryVariant and self:GetDelveStoryVariant(delveName)
    if story and story ~= "" and self.GetStoryTier then
        local si = self:GetStoryTier(story)
        if si and si.tier then return si.tier end
    end
    local sig = self.DelveSignatureTier and self.DelveSignatureTier[delveName]
    return sig
end

-- Player's pace as a B-tier-equivalent clear time: average each run's
-- clear time normalised by its tier factor. nil if no usable history.
function E:GetPersonalPaceBaseline()
    if not (self.db and self.db.delveHistory) then return nil end
    local sum, n = 0, 0
    for name, entry in pairs(self.db.delveHistory) do
        local life = entry.lifetime
        if life and (life.totalRuns or 0) > 0 and (life.totalDuration or 0) > 0 then
            local avg = life.totalDuration / life.totalRuns
            -- Signature tier is stable, unlike the daily-rotating variant tier.
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

-- Gear-scaled pre-history baseline: an undergeared character clears slower, so
-- the estimate stretches below BASELINE_REF_ILVL. Never returns less than
-- FALLBACK_BASELINE (low gear is never faster). GetSpeedGrade uses the same
-- value so the speed-colour ratio stays equal to the tier factor.
function E:GetFallbackBaseline()
    local equipped = GetAverageItemLevel and select(2, GetAverageItemLevel())
    local ilvl = math_floor(equipped or 0)
    local deficit = BASELINE_REF_ILVL - ilvl
    if ilvl <= 0 or deficit <= 0 then return FALLBACK_BASELINE end
    local mult = math_min(BASELINE_MAX_MULT, 1 + deficit * BASELINE_PER_ILVL)
    return math_floor(FALLBACK_BASELINE * mult)
end

-- Returns seconds, source ("personal" logged average | "estimate"),
-- tierLetter. nil if no tier is known.
function E:GetDelveSpeed(delveName, tierOverride)
    if not delveName then return nil end

    local hist = self.GetDelveHistory and self:GetDelveHistory(delveName)
    local life = hist and hist.lifetime
    if life and (life.totalRuns or 0) > 0 and (life.totalDuration or 0) > 0 then
        local avg = math_floor(life.totalDuration / life.totalRuns)
        if avg > 0 then
            return avg, "personal", self:GetDelveTierLetter(delveName, tierOverride)
        end
    end

    local tier = self:GetDelveTierLetter(delveName, tierOverride)
    local factor = tier and TIER_TIME_FACTOR[tier]
    if not factor then return nil end
    local baseline = self:GetPersonalPaceBaseline() or self:GetFallbackBaseline()
    return math_floor(baseline * factor), "estimate", tier
end

function E:GetSpeedGrade(seconds)
    local last = SPEED_GRADES[#SPEED_GRADES]
    if not seconds or seconds <= 0 then
        return last.label, last.rgb[1], last.rgb[2], last.rgb[3]
    end
    local baseline = self:GetPersonalPaceBaseline() or self:GetFallbackBaseline()
    local ratio = seconds / baseline
    for _, g in ipairs(SPEED_GRADES) do
        if ratio <= g.max then
            return g.label, g.rgb[1], g.rgb[2], g.rgb[3]
        end
    end
    return last.label, last.rgb[1], last.rgb[2], last.rgb[3]
end

function E:SpeedColorCode(seconds)
    local _, r, g, b = self:GetSpeedGrade(seconds)
    return string.format("|cFF%02X%02X%02X",
        math_floor(r * 255), math_floor(g * 255), math_floor(b * 255))
end

-- Value-per-minute: rewardWeight(tier) / minutes, x1.5 if bountiful today.
-- Returns score, seconds, tierLetter, source. nil if unrankable.
function E:GetDelveValue(delveName, tierOverride)
    local seconds, source, tier = self:GetDelveSpeed(delveName, tierOverride)
    if not (seconds and seconds > 0 and tier) then return nil end
    local weight = TIER_REWARD_WEIGHT[tier]
    if not weight then return nil end

    local minutes = seconds / 60
    local score = weight / minutes

    local isBountiful = self.currentBountifulNames
        and (self.currentBountifulNames[delveName]
            or self.currentBountifulNames[delveName:lower()])
    if isBountiful then
        score = score * BOUNTIFUL_VALUE_MULT
    end

    return score, seconds, tier, source
end
