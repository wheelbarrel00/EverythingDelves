------------------------------------------------------------------------
-- Core/Achievements.lua
-- Per-delve achievement lookups for the map-pin tooltip.
--
-- Only achievement IDs are hardcoded (verified against the live
-- achievement database, build 12.0.5). Criteria names and completion
-- states are read live via GetAchievementCriteriaInfo() at hover time,
-- so variant lists self-correct if Blizzard renames anything and
-- completion is never stale.
--
-- Per-delve achievement layout this season:
--   "<Delve> Stories"      — complete each of the delve's 3 story variants
--   "<Delve> Discoveries"  — open the delve's 3 hidden Sturdy Chests
--   "Delver of the Depths: Midnight" I–IV — complete every delve
--       (any tier / T4+ / T8+ / T11, with lives remaining); each delve
--       is one criterion of each series entry.
------------------------------------------------------------------------
local E = EverythingDelves

------------------------------------------------------------------------
-- Verified achievement IDs, keyed by the canonical E.DelveData name.
------------------------------------------------------------------------
E.DelveAchievements = {
    ["Parhelion Plaza"]     = { stories = 61725, discoveries = 61893 },
    ["The Shadow Enclave"]  = { stories = 61727, discoveries = 61892 },
    ["Atal'Aman"]           = { stories = 61729, discoveries = 61863 },
    ["Twilight Crypt"]      = { stories = 61730, discoveries = 61896 },
    ["Shadowguard Point"]   = { stories = 61733, discoveries = 61900 },
    ["Sunkiller Sanctum"]   = { stories = 61732, discoveries = 61899 },
    ["The Gulf of Memory"]  = { stories = 61731, discoveries = 61898 },
    ["The Grudge Pit"]      = { stories = 61724, discoveries = 61897 },
    ["Collegiate Calamity"] = { stories = 61726, discoveries = 61894 },
    ["The Darkway"]         = { stories = 61728, discoveries = 61895 },
}

-- "Delver of the Depths: Midnight" series. Each lists all 10 delves as
-- criteria; we surface only this delve's criterion. Ordered easiest
-- to hardest so the tooltip shows the next step first.
E.DelveDepthsSeries = {
    { id = 61707, label = "any tier" },
    { id = 61708, label = "Tier 4+"  },
    { id = 61709, label = "Tier 8+"  },
    { id = 61710, label = "Tier 11"  },
}

------------------------------------------------------------------------
-- Tolerant name matching.
-- The achievement DB and the POI widgets disagree on some spellings
-- ("Twilight Crypts" vs "Twilight Crypt", "Trapped!" vs "Trapped",
-- "Sporasaurus Surprise" vs "Sporasaur Special"), so all comparisons
-- go through a normalizer plus a small alias map of spellings the
-- game has been seen to use for the same variant.
------------------------------------------------------------------------
local function Normalize(s)
    if type(s) ~= "string" then return "" end
    s = s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    s = s:lower():gsub("[^%a%d]", "")
    s = s:gsub("^the", "")
    return s
end

-- normalized in-game spelling → normalized achievement-DB spelling
local VARIANT_ALIASES = {
    ["dastardlyrootstalks"] = "dastardlyrotstalk",
    ["sporasaurussurprise"] = "sporasaurspecial",
    ["looseloa"]            = "loosedloa",
    ["capturedwild"]        = "capturedwildlife",
    ["capturedwidlife"]     = "capturedwildlife",
}

local function Canon(s)
    local n = Normalize(s)
    return VARIANT_ALIASES[n] or n
end

--- True when two delve/variant/criteria names refer to the same thing.
--- Prefix matching absorbs singular/plural drift (crypt/crypts).
local function NamesMatch(a, b)
    local na, nb = Canon(a), Canon(b)
    if na == "" or nb == "" then return false end
    return na == nb
        or na:find(nb, 1, true) == 1
        or nb:find(na, 1, true) == 1
end
E.DelveNamesMatch = NamesMatch

--- Resolve any delve-name spelling to its E.DelveAchievements entry.
local function ResolveDelve(delveName)
    if not delveName then return nil, nil end
    local entry = E.DelveAchievements[delveName]
    if entry then return delveName, entry end
    for name, e in pairs(E.DelveAchievements) do
        if NamesMatch(name, delveName) then return name, e end
    end
    return nil, nil
end

------------------------------------------------------------------------
-- Live achievement reads (all pcall-guarded — a bad ID must never
-- propagate a Lua error into a tooltip hook).
------------------------------------------------------------------------
local function AchievementCompleted(id)
    local ok, _, name, _, completed = pcall(GetAchievementInfo, id)
    if not ok then return nil, nil end
    return completed, name
end

--- Iterate an achievement's criteria → { {name, completed, quantity,
--- reqQuantity}, ... }. quantity/reqQuantity matter for progressive
--- criteria (one bar counting 0→N) as opposed to per-item criteria.
local function ReadCriteria(id)
    local okN, num = pcall(GetAchievementNumCriteria, id)
    if not okN or not num then return nil end
    local out = {}
    for i = 1, num do
        local ok, critName, _, completed, quantity, reqQuantity =
            pcall(GetAchievementCriteriaInfo, id, i)
        if ok then
            out[#out + 1] = {
                name        = critName or "",
                completed   = completed and true or false,
                quantity    = tonumber(quantity) or 0,
                reqQuantity = tonumber(reqQuantity) or 0,
            }
        end
    end
    return out
end

------------------------------------------------------------------------
-- Public API
------------------------------------------------------------------------

--- Full achievement status for one delve, or nil when the delve is
--- unknown or the achievement API is unavailable (e.g. mid-loading).
--- Returns:
---   {
---     delve        = canonical name,
---     allDone      = bool,
---     summaryCount = n,   -- incomplete groups (stories/discoveries/depths)
---     stories      = { id, name, done, missing = {variant, ...} },
---     discoveries  = { id, name, done, found, total },
---     depthsMissing = { "Tier 4+", ... },  -- tiers this delve still needs
---   }
function E:GetDelveAchievementStatus(delveName)
    if not GetAchievementInfo then return nil end
    local canonical, ids = ResolveDelve(delveName)
    if not ids then return nil end

    local status = { delve = canonical, summaryCount = 0 }

    -- Stories: which of the 3 variants are still missing
    local done, name = AchievementCompleted(ids.stories)
    if done ~= nil then
        local s = { id = ids.stories, name = name, done = done, missing = {} }
        if not done then
            local crit = ReadCriteria(ids.stories)
            if crit then
                for _, c in ipairs(crit) do
                    if not c.completed and c.name ~= "" then
                        s.missing[#s.missing + 1] = c.name
                    end
                end
            end
            status.summaryCount = status.summaryCount + 1
        end
        status.stories = s
    end

    -- Discoveries: chest count. Live clients implement this as ONE
    -- progressive criterion (a 0→3 counter), so prefer its
    -- quantity/reqQuantity; fall back to counting completed criteria
    -- if a build ever splits them into one criterion per chest.
    done, name = AchievementCompleted(ids.discoveries)
    if done ~= nil then
        local d = { id = ids.discoveries, name = name, done = done, found = 0, total = 0 }
        local crit = ReadCriteria(ids.discoveries)
        if crit then
            if #crit == 1 and crit[1].reqQuantity > 1 then
                d.found = crit[1].quantity
                d.total = crit[1].reqQuantity
            else
                d.total = #crit
                for _, c in ipairs(crit) do
                    if c.completed then d.found = d.found + 1 end
                end
            end
        end
        if not done then
            status.summaryCount = status.summaryCount + 1
        end
        status.discoveries = d
    end

    -- Delver of the Depths: this delve's criterion in each series entry
    status.depthsMissing = {}
    for _, series in ipairs(E.DelveDepthsSeries) do
        local seriesDone = AchievementCompleted(series.id)
        if seriesDone == false then
            local crit = ReadCriteria(series.id)
            if crit then
                for _, c in ipairs(crit) do
                    if NamesMatch(c.name, canonical) then
                        if not c.completed then
                            status.depthsMissing[#status.depthsMissing + 1] = series.label
                        end
                        break
                    end
                end
            end
        end
    end
    if #status.depthsMissing > 0 then
        status.summaryCount = status.summaryCount + 1
    end

    status.allDone = status.summaryCount == 0
    return status
end

--- If today's story variant for this delve is still an incomplete
--- Stories criterion, return the variant name — the "run it today and
--- it counts" signal. Accepts a precomputed status to avoid re-reading.
function E:GetTodaysStoryCredit(delveName, status)
    status = status or self:GetDelveAchievementStatus(delveName)
    if not (status and status.stories and not status.stories.done) then
        return nil
    end
    local variant = self.GetDelveStoryVariant
        and self:GetDelveStoryVariant(status.delve)
    if not variant or variant == "" then return nil end
    for _, missing in ipairs(status.stories.missing) do
        if NamesMatch(missing, variant) then
            return variant
        end
    end
    return nil
end

------------------------------------------------------------------------
-- Diagnostic: /ed ach — dump per-delve status to chat so the verified
-- IDs can be sanity-checked on a live client at a glance.
------------------------------------------------------------------------
function E:DebugPrintAchievements()
    print(E.CC.header .. "Everything Delves" .. E.CC.close
        .. ": delve achievement status")
    for _, d in ipairs(E.DelveData or {}) do
        local st = self:GetDelveAchievementStatus(d.name)
        if not st then
            print("  " .. d.name .. ": |cFFFF3333no data|r")
        elseif st.allDone then
            print("  " .. d.name .. ": |cFF33CC33complete|r")
        else
            local bits = {}
            if st.stories and not st.stories.done then
                bits[#bits + 1] = "stories missing: "
                    .. (#st.stories.missing > 0
                        and table.concat(st.stories.missing, ", ")
                        or "?")
            end
            if st.discoveries and not st.discoveries.done then
                bits[#bits + 1] = ("chests %d/%d")
                    :format(st.discoveries.found, st.discoveries.total)
            end
            if #st.depthsMissing > 0 then
                bits[#bits + 1] = "depths: "
                    .. table.concat(st.depthsMissing, ", ")
            end
            local credit = self:GetTodaysStoryCredit(d.name, st)
            if credit then
                bits[#bits + 1] = "|cFF33CC33today's story counts!|r"
            end
            print("  " .. d.name .. ": " .. table.concat(bits, " | "))
        end
    end
end
