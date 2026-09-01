-- Achievement IDs verified against the live achievement DB (build 12.1.0).
-- Criteria names and completion are read live each hover so they self-correct.
local E = EverythingDelves
local L = E.L

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
    ["Gnarldor Isle"]       = { stories = 63437, discoveries = 63170 },
    ["The Ring of Glory"]   = { stories = 63436, discoveries = 63171 },
}

-- Each series entry lists every delve as criteria. Ordered easiest-to-hardest
-- so the tooltip surfaces the next step first.
E.DelveDepthsSeries = {
    { id = 61707, label = L["any tier"] },
    { id = 61708, label = L["Tier 4+"]  },
    { id = 61709, label = L["Tier 8+"]  },
    { id = 61710, label = L["Tier 11"]  },
}

-- The achievement DB and POI widgets disagree on some spellings (e.g.
-- "Twilight Crypts" vs "Twilight Crypt", "Sporasaurus Surprise" vs
-- "Sporasaur Special"), so all name comparisons normalize + alias-map.
--  Why Blizzard, why??
local function Normalize(s)
    if type(s) ~= "string" then return "" end
    s = s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    -- %a is ASCII-only under the client's C locale, so an "[^%a%d]" allowlist
    -- erased every byte of a Cyrillic, Hangul or Han name. Strip by denylist.
    s = s:lower():gsub("[%s%p]", "")
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

-- Delve tables are keyed by the ENGLISH name while the game hands back localized
-- strings (POI names, picker headers, achievement criteria). This bridges the
-- two by learning each delve's live POI name. The remote-map POI cache is cold
-- until a zone has been visited, so the index is rebuilt while any delve is
-- still unknown.
local localizedIndex = {}
local localizedCovered = {}
local localizedKnown = 0
local localizedNextScan = 0

local function LearnPOIName(mapID, poiID, delveName)
    if not (mapID and poiID) then return false end
    local ok, info = pcall(C_AreaPoiInfo.GetAreaPOIInfo, mapID, poiID)
    if not (ok and type(info) == "table") then return false end
    local name = info.name
    if type(name) ~= "string" or name == "" then return false end
    localizedIndex[Canon(name)] = delveName
    return true
end

local function IndexLocalizedNames()
    if not (C_AreaPoiInfo and C_AreaPoiInfo.GetAreaPOIInfo) then return end
    for _, d in ipairs(E.DelveData or {}) do
        if not localizedCovered[d.name] then
            -- Only whichever entrance is live today resolves, so try both.
            local got = LearnPOIName(d.mapID, d.poiID, d.name)
            if LearnPOIName(d.mapID, d.normalPoiID, d.name) then got = true end
            if got then
                localizedCovered[d.name] = true
                localizedKnown = localizedKnown + 1
            end
        end
    end
end

function E:ResolveDelveByDisplayName(text)
    if type(text) ~= "string" or text == "" then return nil end
    local key = Canon(text)
    if key == "" then return nil end
    if localizedIndex[key] then return localizedIndex[key] end
    -- Throttled: this runs once per achievement criterion on a tooltip hover and
    -- a full pass is 24 API calls.
    local now = GetTime()
    if localizedKnown < #(self.DelveData or {}) and now >= localizedNextScan then
        localizedNextScan = now + 10
        IndexLocalizedNames()
        if localizedIndex[key] then return localizedIndex[key] end
    end
    -- An exact key miss still needs the prefix match, because the criterion and
    -- the POI disagree on some spellings in every language, not just English.
    for indexed, name in pairs(localizedIndex) do
        if NamesMatch(key, indexed) then return name end
    end
    for name in pairs(self.DelveAchievements) do
        if NamesMatch(text, name) then return name end
    end
    return nil
end

local function ResolveDelve(delveName)
    if not delveName then return nil, nil end
    local entry = E.DelveAchievements[delveName]
    if entry then return delveName, entry end
    local name = E:ResolveDelveByDisplayName(delveName)
    local e = name and E.DelveAchievements[name]
    if e then return name, e end
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
    local depthsUnknown = false
    for _, series in ipairs(E.DelveDepthsSeries) do
        local seriesDone = AchievementCompleted(series.id)
        local critDone
        if seriesDone then
            critDone = true   -- whole series earned implies this delve's tier is too
        elseif seriesDone == false then
            local crit = ReadCriteria(series.id)
            if crit then
                local named, resolved = 0, 0
                for _, c in ipairs(crit) do
                    if c.name ~= "" then
                        named = named + 1
                        local cd = E:ResolveDelveByDisplayName(c.name)
                        if cd then resolved = resolved + 1 end
                        if cd == canonical then
                            critDone = c.completed and true or false
                            break
                        end
                    end
                end
                -- Only conclude this delve is absent from the series when every
                -- criterion in it was identifiable. One unreadable name and the
                -- answer is unknown, which must never render as done.
                if critDone == nil and resolved < named then
                    depthsUnknown = true
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
    status.depthsUnknown = depthsUnknown
    if #status.depthsMissing > 0 then
        status.summaryCount = status.summaryCount + 1
    end

    -- Unknown depths deliberately do not raise summaryCount: there would be
    -- nothing behind the count. They only forbid the claim that all is done.
    status.allDone = status.summaryCount == 0 and not status.depthsUnknown
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
