------------------------------------------------------------------------
-- Core/Data.lua
-- Static fallback data tables for delve locations and bountiful delves.
-- These serve as a baseline; live API data from C_AreaPoiInfo / C_Map
-- overlays or replaces these values when available at runtime.
------------------------------------------------------------------------
local E = EverythingDelves

------------------------------------------------------------------------
-- Zone list (display name → uiMapID mapping)
-- Confirmed map IDs from live Midnight 12.0 data
------------------------------------------------------------------------
E.Zones = {
    { name = "Eversong Woods",        mapID = 2395 },
    { name = "Harandar",              mapID = 2413 },
    { name = "Voidstorm",             mapID = 2405 },
    { name = "Zul'Aman",              mapID = 2437 },
    { name = "Silvermoon",            mapID = 2393 },
    { name = "Isle of Quel'Danas",    mapID = 2424 },
}

------------------------------------------------------------------------
-- Delve directory — confirmed live data from Midnight S1
--
-- Each entry:
--   name        string   Display name (from C_AreaPoiInfo)
--   zone        string   Zone name (must match E.Zones)
--   x, y        number   Map coordinates (percentage, zone-relative)
--   mapID       number   uiMapID for waypoint APIs
--   poiID       number   AreaPOI ID for live bountiful detection
--
-- Coordinates are in percentage form (e.g. 45.4 = 0.454 for waypoint
-- APIs; we convert when calling SetWaypoint).
------------------------------------------------------------------------
E.DelveData = {
    -- Isle of Quel'Danas
    {
        name  = "Parhelion Plaza",
        zone  = "Isle of Quel'Danas",
        x     = 46.3,  y = 41.62,
        mapID = 2424,
        poiID = 8428,  normalPoiID = 8427,
    },
    -- Eversong Woods
    {
        name  = "The Shadow Enclave",
        zone  = "Eversong Woods",
        x     = 45.4,  y = 86.0,
        mapID = 2395,
        poiID = 8438,  normalPoiID = 8437,
    },
    -- Zul'Aman
    {
        name  = "Atal'Aman",
        zone  = "Zul'Aman",
        x     = 24.8,  y = 53.0,
        mapID = 2437,
        poiID = 8444,  normalPoiID = 8443,
    },
    {
        name  = "Twilight Crypt",
        zone  = "Zul'Aman",
        x     = 25.4,  y = 84.3,
        mapID = 2437,
        poiID = 8442,  normalPoiID = 8441,
    },
    -- Voidstorm
    {
        name  = "Shadowguard Point",
        zone  = "Voidstorm",
        x     = 37.38, y = 47.7,
        mapID = 2405,
        poiID = 8432,  normalPoiID = 8431,
    },
    {
        name  = "Sunkiller Sanctum",
        zone  = "Voidstorm",
        x     = 54.8,  y = 47.0,
        mapID = 2405,
        poiID = 8430,  normalPoiID = 8429,
    },
    -- Harandar
    {
        name  = "The Gulf of Memory",
        zone  = "Harandar",
        x     = 36.3,  y = 49.2,
        mapID = 2413,
        poiID = 8436,  normalPoiID = 8435,
    },
    {
        name  = "The Grudge Pit",
        zone  = "Harandar",
        x     = 70.5,  y = 64.92,
        mapID = 2413,
        poiID = 8434,  normalPoiID = 8433,
    },
    -- Silvermoon
    {
        name  = "Collegiate Calamity",
        zone  = "Silvermoon",
        x     = 40.76, y = 54.06,
        mapID = 2393,
        poiID = 8426,  normalPoiID = 8425,
    },
    {
        name  = "The Darkway",
        zone  = "Silvermoon",
        x     = 39.3,  y = 31.8,
        mapID = 2393,
        poiID = 8440,  normalPoiID = 8439,
    },
}

E.TOTAL_DELVES = #E.DelveData

------------------------------------------------------------------------
-- Seasonal Nemesis Delve (Midnight S1)
-- Torment's Rise — boss: Nullaeus. Only two tiers offered: T8 and T11.
-- Kept separate from E.DelveData so location/bountiful iterators are
-- unaffected.
------------------------------------------------------------------------
E.NemesisDelve = {
    name  = "Torment's Rise",
    boss  = "Nullaeus",
    tiers = { 8, 11 },
}

------------------------------------------------------------------------
-- Loggable delve lookup — scenario name → "regular" | "nemesis".
-- Used by the SCENARIO_COMPLETED handler to filter out TWW / legacy
-- scenarios and only log Midnight delves.
------------------------------------------------------------------------
E.LoggableDelveNames = {}
for _, d in ipairs(E.DelveData) do
    E.LoggableDelveNames[d.name] = "regular"
end
E.LoggableDelveNames[E.NemesisDelve.name] = "nemesis"

------------------------------------------------------------------------
-- Delve uiMapID → canonical delve name. Used as a fallback identifier
-- when GetRealZoneText()/GetInstanceInfo() don't return a recognizable
-- delve name at SCENARIO_COMPLETED time.
------------------------------------------------------------------------
E.DelveZoneIDs = {
    [2933] = "Collegiate Calamity",
    [2952] = "The Shadow Enclave",
    [2953] = "Parhelion Plaza",
    [2961] = "Twilight Crypts",
    [2962] = "Atal'Aman",
    [2963] = "The Grudge Pit",
    [2964] = "The Gulf of Memory",
    [2965] = "Sunkiller Sanctum",
    [2966] = "Torment's Rise",
    [2979] = "Shadowguard Point",
    [3003] = "The Darkway",
}
