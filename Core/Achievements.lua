-- Achievement IDs verified against the live achievement DB (build 12.0.5);
-- criteria names/completion are read live each hover so they self-correct.
local E = EverythingDelves

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

-- Each series entry lists all 10 delves as criteria; ordered easiest-to-hardest
-- so the tooltip surfaces the next step first.
E.DelveDepthsSeries = {
    { id = 61707, label = "any tier" },
    { id = 61708, label = "Tier 4+"  },
    { id = 61709, label = "Tier 8+"  },
    { id = 61710, label = "Tier 11"  },
}

-- The achievement DB and POI widgets disagree on some spellings (e.g.
-- "Twilight Crypts" vs "Twilight Crypt", "Sporasaurus Surprise" vs
-- "Sporasaur Special"), so all name comparisons normalize + alias-map.
local function Normalize(s)
    if type(s) ~= "string" then return "" end
    s = s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    s = s:lower():gsub("[^%a%d]", "")
    s = s:gsub("^the", "")
    return s
end

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

-- Prefix matching absorbs singular/plural drift (crypt/crypts).
local function NamesMatch(a, b)
    local na, nb = Canon(a), Canon(b)
    if na == "" or nb == "" then return false end
    return na == nb
        or na:find(nb, 1, true) == 1
        or nb:find(na, 1, true) == 1
end
E.DelveNamesMatch = NamesMatch

local function ResolveDelve(delveName)
    if not delveName then return nil, nil end
    local entry = E.DelveAchievements[delveName]
    if entry then return delveName, entry end
    for name, e in pairs(E.DelveAchievements) do
        if NamesMatch(name, delveName) then return name, e end
    end
    return nil, nil
end

-- pcall-guarded: a bad ID must never propagate a Lua error into a tooltip hook.
local function AchievementCompleted(id)
    local ok, _, name, _, completed = pcall(GetAchievementInfo, id)
    if not ok then return nil, nil end
    return completed, name
end

-- quantity/reqQuantity matter for progressive criteria (one bar 0→N) vs per-item.
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

function E:GetDelveAchievementStatus(delveName)
    if not GetAchievementInfo then return nil end
    local canonical, ids = ResolveDelve(delveName)
    if not ids then return nil end

    local status = { delve = canonical, summaryCount = 0 }

    local done, name = AchievementCompleted(ids.stories)
    if done ~= nil then
        local s = { id = ids.stories, name = name, done = done, missing = {}, criteria = {} }
        -- Read criteria even when done, so the tooltip lists every variant green/red.
        local crit = ReadCriteria(ids.stories)
        if crit then
            s.criteria = crit
            for _, c in ipairs(crit) do
                if not c.completed and c.name ~= "" then
                    s.missing[#s.missing + 1] = c.name
                end
            end
        end
        if not done then
            status.summaryCount = status.summaryCount + 1
        end
        status.stories = s
    end

    -- Live clients implement discoveries as ONE progressive 0→3 criterion;
    -- fall back to counting completed criteria if a build ever splits them.
    done, name = AchievementCompleted(ids.discoveries)
    if done ~= nil then
        local d = { id = ids.discoveries, name = name, done = done, found = 0, total = 0, criteria = {} }
        local crit = ReadCriteria(ids.discoveries)
        if crit then
            d.criteria = crit
            if #crit == 1 and crit[1].reqQuantity > 1 then
                d.isProgressBar = true
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

    status.depthsMissing = {}
    status.depths = {}
    for _, series in ipairs(E.DelveDepthsSeries) do
        local seriesDone = AchievementCompleted(series.id)
        local critDone
        if seriesDone then
            critDone = true   -- whole series earned implies this delve's tier is too
        elseif seriesDone == false then
            local crit = ReadCriteria(series.id)
            if crit then
                for _, c in ipairs(crit) do
                    if NamesMatch(c.name, canonical) then
                        critDone = c.completed and true or false
                        break
                    end
                end
            end
        end
        if critDone ~= nil then
            status.depths[#status.depths + 1] =
                { label = series.label, completed = critDone }
            if not critDone then
                status.depthsMissing[#status.depthsMissing + 1] = series.label
            end
        end
    end
    if #status.depthsMissing > 0 then
        status.summaryCount = status.summaryCount + 1
    end

    status.allDone = status.summaryCount == 0
    return status
end

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

-- /ed ach — dump per-delve status to chat for live ID sanity checks.
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
