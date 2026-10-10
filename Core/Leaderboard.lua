local E = EverythingDelves

local pairs, ipairs, tonumber, tostring, type = pairs, ipairs, tonumber, tostring, type
local select = select
local table_sort = table.sort

-- The old account-wide history, moved into a profile at 1.5.0. Its runs that carry
-- no character could be any character's, there or in a copy of that profile.
local MIGRATED_PROFILE = "Original"
-- v1.5.0's release. No per-character profile existed before it.
local PROFILES_SINCE = 1778982106
-- RepairAbsurdDurations zeroes longer runs, but only in the active profile
local MAX_DURATION = 6 * 3600

local function ClassOfSpec(specID)
    if not (specID and GetSpecializationInfoByID) then return nil end
    return (select(6, GetSpecializationInfoByID(specID)))
end

local function RunKey(delve, r, dur)
    return delve .. "\0" .. tostring(r.timestamp) .. "\0" .. dur
end

-- Worked out from run history each time rather than stored, so nothing is migrated at login
function E.CollectLeaderboardRuns()
    local out = {}
    local sv = EverythingDelvesDB
    if not (sv and type(sv.profiles) == "table") then return out end

    local owners, ownerOf = {}, {}
    for char, prof in pairs(sv.profileKeys or {}) do
        owners[prof] = (owners[prof] or 0) + 1
        ownerOf[prof] = char
    end
    local roster = sv.roster or {}
    local kinds = E.LoggableDelveNames or {}

    -- Duplicate Current copies the migrated runs, still without a character, into other profiles
    local migrated = {}
    local original = sv.profiles[MIGRATED_PROFILE]
    local originalHistory = type(original) == "table" and original.delveHistory
    for delve, entry in pairs(type(originalHistory) == "table" and originalHistory or {}) do
        for _, r in ipairs(type(entry) == "table" and entry.recentRuns or {}) do
            if not r.char then migrated[RunKey(delve, r, tonumber(r.duration) or 0)] = true end
        end
    end

    local seen = {}
    for prof, p in pairs(sv.profiles) do
        local history = type(p) == "table" and p.delveHistory
        local sole = owners[prof] == 1 and ownerOf[prof] or nil
        for delve, entry in pairs(type(history) == "table" and history or {}) do
            local kind = kinds[delve]
            for _, r in ipairs(kind and type(entry) == "table" and entry.recentRuns or {}) do
                local tier, dur = tonumber(r.tier) or 0, tonumber(r.duration) or 0
                local char = r.char
                if not char and sole and not migrated[RunKey(delve, r, dur)]
                        and (tonumber(r.timestamp) or 0) >= PROFILES_SINCE then
                    char = sole
                end
                if char and tier > 0 and dur > 0 and dur <= MAX_DURATION then
                    local key = char .. "\0" .. RunKey(delve, r, dur)
                    if not seen[key] then
                        seen[key] = true
                        local rec = roster[char]
                        out[#out + 1] = {
                            delve = delve, kind = kind, char = char, tier = tier, duration = dur,
                            story = r.story, deaths = tonumber(r.deaths) or 0,
                            timestamp = tonumber(r.timestamp) or 0, spec = r.spec,
                            class = ClassOfSpec(r.spec) or (rec and rec.class),
                        }
                    end
                end
            end
        end
    end
    return out
end

function E.RankLeaderboard(runs, delve, tier, classFile, specID)
    local best = {}
    for _, r in ipairs(runs) do
        if r.delve == delve and r.tier == tier
                and (not classFile or r.class == classFile)
                and (not specID or r.spec == specID) then
            local b = best[r.char]
            if not b or r.duration < b.duration
                    or (r.duration == b.duration and r.timestamp < b.timestamp) then
                best[r.char] = r
            end
        end
    end
    local list = {}
    for _, r in pairs(best) do list[#list + 1] = r end
    table_sort(list, function(a, b)
        if a.duration ~= b.duration then return a.duration < b.duration end
        if a.timestamp ~= b.timestamp then return a.timestamp < b.timestamp end
        return a.char < b.char
    end)
    return list
end

function E.MostRunTier(runs)
    local count, best = {}, nil
    for _, r in ipairs(runs) do
        count[r.tier] = (count[r.tier] or 0) + 1
    end
    for tier, n in pairs(count) do
        if not best or n > count[best] or (n == count[best] and tier > best) then
            best = tier
        end
    end
    return best
end
