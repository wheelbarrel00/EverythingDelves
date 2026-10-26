-- Achievement IDs verified against the live achievement DB (build 12.1.0).
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
-- "Sporasaur Special"), so all name comparisons normalize and alias-map.
local function Normalize(s)
    if type(s) ~= "string" then return "" end
    s = E.StripColorEscapes(s)
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
    ["whydidithavetobesnakes"]  = "whydithavetobesnakes",
    ["anelementaryantidote"]    = "academicantitoxin",
    ["basaliskblitz"]           = "basiliskblitz",
    -- The live Shadow Enclave achievement names this story "Basilisk Blitz".
    ["infiltrateandameliorate"] = "basiliskblitz",
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
    local ok, _, name, _, completed, month, day, year =
        pcall(GetAchievementInfo, id)
    if not ok then return nil, nil end
    return completed, name, month, day, year
end

-- GetAchievementInfo returns a two-digit year.
local function FormatEarnedDate(month, day, year)
    if not (month and day and year) then return nil end
    if month < 1 or day < 1 then return nil end
    if year < 100 then year = year + 2000 end
    if type(FormatShortDate) == "function" then
        local ok, text = pcall(FormatShortDate, day, month, year)
        if ok and type(text) == "string" and text ~= "" then return text end
    end
    return ("%d/%d/%d"):format(month, day, year)
end

local function ReadCriteria(id)
    local okN, num = pcall(GetAchievementNumCriteria, id)
    if not okN or not num then return nil end
    local out = {}
    for i = 1, num do
        local ok, critName, critType, completed, quantity, reqQuantity,
              _, _, assetID = pcall(GetAchievementCriteriaInfo, id, i)
        if ok then
            out[#out + 1] = {
                name        = critName or "",
                critType    = tonumber(critType) or 0,
                assetID     = tonumber(assetID) or 0,
                completed   = completed and true or false,
                quantity    = tonumber(quantity) or 0,
                reqQuantity = tonumber(reqQuantity) or 0,
            }
        end
    end
    return out
end

-- The four tier series are account-wide with identical criteria, so reading
-- them per delve repeated one full pass twelve times. The TTL lets a cold
-- POI cache resolve on a later call.
local depthsSnapshot, depthsSnapshotAt = nil, 0
local DEPTHS_SNAPSHOT_TTL = 5

local function GetDepthsSnapshot()
    local now = GetTime()
    if depthsSnapshot and (now - depthsSnapshotAt) < DEPTHS_SNAPSHOT_TTL then
        return depthsSnapshot
    end
    local snap = {}
    for i, series in ipairs(E.DelveDepthsSeries or {}) do
        local done, _, eMonth, eDay, eYear = AchievementCompleted(series.id)
        local entry = {
            label      = series.label,
            seriesDone = done,
            earnedText = done and FormatEarnedDate(eMonth, eDay, eYear) or nil,
            byDelve    = {},
            unresolved = false,
        }
        if done == false then
            local crit = ReadCriteria(series.id)
            if crit then
                local named, resolved = 0, 0
                for _, c in ipairs(crit) do
                    if c.name ~= "" then
                        named = named + 1
                        local cd = E:ResolveDelveByDisplayName(c.name)
                        if cd then
                            resolved = resolved + 1
                            entry.byDelve[cd] = c.completed and true or false
                        end
                    end
                end
                entry.unresolved = resolved < named
            end
        end
        snap[i] = entry
    end
    depthsSnapshot, depthsSnapshotAt = snap, now
    return snap
end

E:RegisterCallback("AchievementUpdate", function() depthsSnapshot = nil end)

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

    -- Live clients implement discoveries as ONE progressive 0 to 3 criterion. Counting
    -- completed criteria is the fallback if a build ever splits them.
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
    for _, entry in ipairs(GetDepthsSnapshot()) do
        local critDone
        if entry.seriesDone then
            -- An earned series reports every criterion complete, including
            -- delves added to it afterwards, so reading them adds nothing.
            critDone = true
        elseif entry.seriesDone == false then
            critDone = entry.byDelve[canonical]
            -- Only conclude this delve is absent from the series when every
            -- criterion in it was identifiable. One unreadable name and the
            -- answer is unknown, which must never render as done.
            if critDone == nil and entry.unresolved then
                depthsUnknown = true
            end
        end
        if critDone ~= nil then
            -- seriesEarned marks a tick inherited from the earned series
            -- rather than observed for this delve.
            status.depths[#status.depths + 1] = {
                label        = entry.label,
                completed    = critDone,
                seriesEarned = entry.seriesDone and true or false,
                earnedText   = entry.earnedText,
            }
            if not critDone then
                status.depthsMissing[#status.depthsMissing + 1] = entry.label
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

function E:GetTodaysStoryCredit(delveName, status, variant)
    status = status or self:GetDelveAchievementStatus(delveName)
    if not (status and status.stories and not status.stories.done) then
        return nil
    end
    variant = variant or (self.GetDelveStoryVariant
        and self:GetDelveStoryVariant(status.delve))
    if not variant or variant == "" then return nil end
    for _, missing in ipairs(status.stories.missing) do
        if NamesMatch(missing, variant) then
            return variant
        end
    end
    return nil
end

function E:GetTodaysStoryCredits(statusByDelve)
    local out, variants = {}, {}
    for _, d in ipairs(self.DelveData or {}) do
        local st = statusByDelve and statusByDelve[d.name]
            or self:GetDelveAchievementStatus(d.name)
        local variant = self.GetDelveStoryVariant
            and self:GetDelveStoryVariant(d.name)
        if variant and variant ~= "" then variants[d.name] = variant end
        local credit = st and self:GetTodaysStoryCredit(d.name, st, variant)
        if credit then
            out[#out + 1] = { delve = d.name, variant = credit }
        end
    end
    return out, variants
end

E.GLORY_ACHIEVEMENT_ID = 61906

-- criteriaType 8 is "complete achievement" and puts the sub-achievement in
-- assetID, so the pillar IDs are read live rather than listed here.
local CRITERIA_TYPE_ACHIEVEMENT = 8

local function SubAchievementRemaining(id)
    local crit = ReadCriteria(id)
    if not crit or #crit == 0 then return nil, nil end
    if #crit == 1 and crit[1].reqQuantity > 1 then
        return math.max(0, crit[1].reqQuantity - crit[1].quantity), crit[1].reqQuantity
    end
    local left = 0
    for _, c in ipairs(crit) do
        if not c.completed then left = left + 1 end
    end
    return left, #crit
end

function E:GetGloryStatus()
    if not GetAchievementInfo then return nil end
    local ok, _, name, _, done, _, _, _, _, _, icon, rewardText =
        pcall(GetAchievementInfo, self.GLORY_ACHIEVEMENT_ID)
    if not ok or done == nil then return nil end

    local status = {
        id        = self.GLORY_ACHIEVEMENT_ID,
        name      = name,
        done      = done and true or false,
        icon      = icon,
        reward    = (type(rewardText) == "string" and rewardText ~= "")
                    and rewardText or nil,
        remaining = 0,
        pillars   = {},
    }

    for _, c in ipairs(ReadCriteria(self.GLORY_ACHIEVEMENT_ID) or {}) do
        local pillar = { name = c.name, done = c.completed }
        if c.critType == CRITERIA_TYPE_ACHIEVEMENT and c.assetID > 0 then
            pillar.id = c.assetID
            local subDone, subName = AchievementCompleted(c.assetID)
            if subName and subName ~= "" then pillar.name = subName end
            -- A meta criterion can lag its sub-achievement, so a false
            -- criterion defers to the sub-achievement's own state.
            if c.completed == false and subDone ~= nil then
                pillar.done = subDone
            end
            if not pillar.done then
                pillar.left, pillar.total = SubAchievementRemaining(c.assetID)
            end
        end
        if pillar.name ~= "" then
            if not pillar.done then
                status.remaining = status.remaining + 1
            end
            status.pillars[#status.pillars + 1] = pillar
        end
    end

    return status
end

function E:DebugPrintGlory()
    local header = E.CC.header .. "Everything Delves" .. E.CC.close
    local st = self:GetGloryStatus()
    if not st then
        print(header .. ": no data for achievement "
            .. tostring(self.GLORY_ACHIEVEMENT_ID)
            .. " - the ID is wrong or the API is unavailable.")
        return
    end
    print(header .. ": " .. tostring(st.name)
        .. " (" .. st.id .. ") - "
        .. (st.done and "|cFF33CC33complete|r"
            or ("|cFFFF3333" .. st.remaining .. " pillar(s) left|r")))
    for _, p in ipairs(st.pillars) do
        local bits = p.done and "|cFF33CC33done|r" or "|cFFFF3333incomplete|r"
        if p.left and p.total then
            bits = bits .. (" (%d of %d left)"):format(p.left, p.total)
        end
        print(("  [%s] %s: %s"):format(
            p.id and tostring(p.id) or "no id", tostring(p.name), bits))
    end
end

-- %q and byte counts, because two strings that render identically in chat can still differ.
function E:DebugPrintStoryMatch()
    print(E.CC.header .. "Everything Delves" .. E.CC.close
        .. ": story credit match test")
    for _, d in ipairs(self.DelveData or {}) do
        local st = self:GetDelveAchievementStatus(d.name)
        if st and st.stories and not st.stories.done
                and #st.stories.missing > 0 then
            print("  " .. d.name)
            print(("     status.delve = %q  (arg was %q)")
                :format(tostring(st.delve), d.name))
            local variant = self.GetDelveStoryVariant
                and self:GetDelveStoryVariant(st.delve)
            if type(variant) ~= "string" then
                print("     today = |cFFFF3333" .. tostring(variant) .. "|r")
            else
                print(("     today   = %q (%d bytes) -> canon %q")
                    :format(variant, #variant, Canon(variant)))
                for _, m in ipairs(st.stories.missing) do
                    print(("     missing = %q (%d bytes) -> canon %q  MATCH=%s")
                        :format(m, #m, Canon(m),
                            tostring(NamesMatch(m, variant))))
                end
                print("     credit returned: "
                    .. tostring(self:GetTodaysStoryCredit(d.name, st)))
            end
        end
    end
end

function E:DebugPrintDepths()
    print(E.CC.header .. "Everything Delves" .. E.CC.close
        .. ": Delver of the Depths series")
    for _, series in ipairs(self.DelveDepthsSeries or {}) do
        -- flags, icon, rewardText, isGuild sit between description and
        -- wasEarnedByMe. One placeholder short mislabels both trailing fields.
        local ok, _, name, _, completed, month, day, year, description,
              _, _, _, _, wasEarnedByMe, earnedBy =
            pcall(GetAchievementInfo, series.id)
        if not ok then
            print(("  [%d] no data"):format(series.id))
        else
            print(("  [%d] %s: %s"):format(series.id, tostring(name),
                completed and "|cFF33CC33EARNED|r" or "|cFFFF3333not earned|r"))
            print(("      ED calls this %q"):format(tostring(series.label)))
            print(("      Blizzard says: %s"):format(tostring(description)))
            if completed then
                print(("      earned %s/%s/%s  byMe=%s  earnedBy=%s"):format(
                    tostring(month), tostring(day), tostring(year),
                    tostring(wasEarnedByMe), tostring(earnedBy)))
            end
            local crit = ReadCriteria(series.id)
            if not crit or #crit == 0 then
                print("      no criteria readable")
            else
                local incomplete = {}
                for _, c in ipairs(crit) do
                    if not c.completed then
                        incomplete[#incomplete + 1] =
                            (c.name ~= "" and c.name or "<unnamed>")
                    end
                end
                if #incomplete == 0 then
                    print(("      %d criteria, all complete"):format(#crit))
                else
                    print(("      %d criteria, |cFFFFD100%d INCOMPLETE|r: %s")
                        :format(#crit, #incomplete, table.concat(incomplete, ", ")))
                end
            end
        end
    end
end

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
            local variant = self.GetDelveStoryVariant
                and self:GetDelveStoryVariant(d.name)
            bits[#bits + 1] = "today: "
                .. ((variant and variant ~= "") and variant or "|cFFFF3333<none read>|r")

            if st.stories then
                local unnamed = 0
                for _, c in ipairs(st.stories.criteria) do
                    if c.name == "" then unnamed = unnamed + 1 end
                end
                if unnamed > 0 then
                    bits[#bits + 1] = ("|cFFFFD100%d criterion name(s) EMPTY|r")
                        :format(unnamed)
                end
            end

            local credit = self:GetTodaysStoryCredit(d.name, st)
            if credit then
                bits[#bits + 1] = "|cFF33CC33today's story counts!|r"
            end
            print("  " .. d.name .. ": " .. table.concat(bits, " | "))
        end
    end
end
