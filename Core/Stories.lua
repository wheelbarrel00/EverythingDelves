local E = EverythingDelves
local L = E.L

local GRADE_ORDER = { S = 1, A = 2, B = 3, C = 4, D = 5, F = 6 }
local WIDE_COLON = "\239\188\154"

-- Keyed by map tooltip widget ID (UiWidgetStringSource, build 12.1.5.70448), the same in every language.
-- Grades from Moleman's Delve Compendium (Midnight S2), best Tier 1 times: S under 1:00, one grade per 15 s, F over 2:00.
E.Stories = {
    [7428] = { delve = "The Gulf of Memory", grade = "S", name = "Sporasaur Special", also = { "Sporasaurus Surprise" },
               note = L["Kite dinos and kick spores back to break their shields for bonus damage."] },
    [7427] = { delve = "The Gulf of Memory", grade = "D", name = "Alnmoth Munchies",
               note = L["Same quick route as Sporasaur Special but extra objectives slow it down."] },
    [7426] = { delve = "The Gulf of Memory", grade = "F", name = "Descent of the Haranir",
               note = L["Same quick pathing as Sporasaur but extra objectives add considerable time."] },
    [7437] = { delve = "The Darkway", grade = "A", name = "Ogre Powered",
               note = L["Straight shot to boss. Kill Unstable Aberrations before moving on."] },
    [8268] = { delve = "The Darkway", grade = "B", name = "Eggsplosive Growth",
               note = L["Destroy the Children of Ula'tek eggs nesting in the tunnels using the Venom-Clogged Leyline pylons."] },
    [7435] = { delve = "The Darkway", grade = "C", name = "Focusers Under Pressure",
               note = L["Large crystal collection loop adds time compared to Ogre Powered."] },
    [7436] = { delve = "The Darkway", grade = "F", name = "Leyline Technician",
               note = L["Inspecting every leyline adds a lot of time."] },
    [7986] = { delve = "The Ring of Glory", grade = "A", name = "Adopt-a-thon",
               note = L["Rescue the small animals caught in the middle of the gladiator fights."] },
    [7987] = { delve = "The Ring of Glory", grade = "C", name = "Game Day",
               note = L["Ghostly Headball - collect skulls from your kills and kick them at the pillars to score."] },
    [7988] = { delve = "The Ring of Glory", grade = "C", name = "Open Night",
               note = L["An arena gauntlet - clear the floor, then the champions, then Drakta."] },
    [7411] = { delve = "Parhelion Plaza", grade = "A", name = "Holding the Line",
               note = L["Head down the staircase; kill enemies (not heal allies) for the fastest route."] },
    [7413] = { delve = "Parhelion Plaza", grade = "F", name = "Bombing Run",
               note = L["Destroying void portals makes for one of the slowest clears."] },
    [7412] = { delve = "Parhelion Plaza", grade = "F", name = "March of the Arcane Brigade", also = { "March of the Arcane Parade" },
               note = L["Activating sentinels is slow with no direct path to the boss."] },
    [7753] = { delve = "Parhelion Plaza", grade = "F", name = "Caustic Crush",
               note = L["Stop the Children of Ula'tek summoning slimes, using Fungal Pharmacon and dodging the caustic waves."] },
    [7423] = { delve = "Collegiate Calamity", grade = "A", name = "Invasive Glow",
               note = L["Bomb DoT scales with tier — keep it rolling and the clear is trivial."] },
    [7424] = { delve = "Collegiate Calamity", grade = "B", name = "Academy Under Siege",
               note = L["Scattered powerful items help, but it can't match Invasive Glow."] },
    [7425] = { delve = "Collegiate Calamity", grade = "D", name = "Faculty of Fear",
               note = L["Revelation mechanic requires revealing many NPCs, adding significant time."] },
    [7773] = { delve = "Collegiate Calamity", grade = "D", name = "An Elementary Antidote", also = { "Academic Antitoxin" },
               note = L["Brew an antidote with Sir Finley - cleanse poison patches and heal students. No final boss."] },
    [7432] = { delve = "Twilight Crypt", grade = "B", name = "Party Crasher",
               note = L["Hit levers to disable traps while defeating 4 Twilight Summoners."] },
    [7433] = { delve = "Twilight Crypt", grade = "C", name = "Trapped!", also = { "Trapped" },
               note = L["Teleported inside — must rescue hostages on the way back to the entrance."] },
    [7434] = { delve = "Twilight Crypt", grade = "D", name = "Loosed Loa", also = { "Loose Loa" },
               note = L["Use Evasive Elixir before the patrolling loa attacks to avoid a big stun."] },
    [7677] = { delve = "Twilight Crypt", grade = "F", name = "Why Did it Have to Be Snakes?", also = { "Why'd It Have to Be Snakes?" },
               note = L["Hunt snake relics through the crypts, clearing poison patches with Fungal Pharmacon."] },
    [7414] = { delve = "Sunkiller Sanctum", grade = "B", name = "Core of the Problem",
               note = L["Use portals to shortcut around the map. Kill enemies and collect orbs."] },
    [7416] = { delve = "Sunkiller Sanctum", grade = "D", name = "Not What I Expected",
               note = L["Click Lightbloom crates and activate security. Displacement Portal clones help in combat."] },
    [7415] = { delve = "Sunkiller Sanctum", grade = "F", name = "The Gravitational Effect",
               note = L["Flying to collect Singularity Coils breaks the route significantly."] },
    [7422] = { delve = "Atal'Aman", grade = "C", name = "Toadly Unbecoming",
               note = L["Decurse frogs to spawn the boss. Open layout adds traverse time even when mounted."] },
    [8165] = { delve = "Atal'Aman", grade = "D", name = "Venomous Vapors",
               note = L["Escort Marla and clear the Children of Ula'tek poison contamination. Ends on Disciple of Vash'nik."] },
    [7420] = { delve = "Atal'Aman", grade = "D", name = "Totem Annihilation",
               note = L["Take the bird north. Avoid the captured loa's lightning — it hits hard."] },
    [7421] = { delve = "Atal'Aman", grade = "D", name = "Ritual Interrupted",
               note = L["Navigate south freeing furbolgs. Haunted weapons deal decent bonus damage."] },
    [7429] = { delve = "The Shadow Enclave", grade = "C", name = "Traitor's Due",
               note = L["Large unwalkable map. Defeat void foci and elites with the Eye of Antenorian buff."] },
    [7431] = { delve = "The Shadow Enclave", grade = "F", name = "Mirror Shine",
               note = L["Repositioning mirrors to reflect light is tedious. Mind positioning to avoid debuffs."] },
    [7430] = { delve = "The Shadow Enclave", grade = "F", name = "Shadowy Supplies",
               note = L["Collecting 30 supplies from enemies and the floor is very slow."] },
    [7782] = { delve = "The Shadow Enclave", grade = "F", name = "Infiltrate and Ameliorate",
               note = L["Sabotage the summoning - kick summoners into the abyss and spike the cauldrons with the wrong ingredients."] },
    [7418] = { delve = "Shadowguard Point", grade = "C", name = "Calamitous",
               note = L["Enormous mountable map with required secondary objectives in all three variants."] },
    [8173] = { delve = "Shadowguard Point", grade = "D", name = "Basalisk Blitz", also = { "Basilisk Blitz" },
               note = L["Divert the shields, then kill the basilisks channeling energy to the boss."] },
    [7419] = { delve = "Shadowguard Point", grade = "F", name = "Captured Wildlife", also = { "Captured Wild", "Captured Widlife" },
               note = L["Free caged wildlife; use worm bait on Void Researchers to spawn the boss."] },
    [7417] = { delve = "Shadowguard Point", grade = "F", name = "Stolen Mana",
               note = L["Use the Galvanic Rifle on mana barrels and free 8 prisoners from Mana Siphoners."] },
    [7334] = { delve = "The Grudge Pit", grade = "D", name = "Arena Champion",
               note = L["Defeat two named enemies then collect mold samples from Moldering Fighters."] },
    [7335] = { delve = "The Grudge Pit", grade = "F", name = "Lightbloom Invasion",
               note = L["Free fighters and defend barricades against Thornmaws using nearby barrels."] },
    [7333] = { delve = "The Grudge Pit", grade = "F", name = "Dastardly Rotstalk", also = { "Dastardly Rootstalks" },
               note = L["Taunt the crowd, click dirt piles, defeat spawns carefully to avoid being overwhelmed."] },
    [7701] = { delve = "The Grudge Pit", grade = "F", name = "Fungal Pharmacon",
               note = L["Loot Fungal Pharmacon from around the pit and break the four pillars the Children of Ula'tek burrow through."] },
    [7976] = { delve = "Gnarldor Isle", grade = "F", name = "Speaking Their Language",
               note = L["Rescue the turtles and the supplies the Djaradin stole, then send the siege-trained turtles in as tanks."] },
    [7980] = { delve = "Gnarldor Isle", grade = "F", name = "Olds and Ends",
               note = L["Ally with the Tortollan Tormunda to rescue the elders the Djaradin captured, and recover their relics."] },
    [7979] = { delve = "Gnarldor Isle", grade = "F", name = "Minchi's Osseous Adventure", also = { "Minchi's Osseous Adventurer" },
               note = L["Search the bone piles and take hearts from the Gnarldor Djaradin to summon the Osseous Amalgamation."] },
}

-- The game puts a label ending in a colon before the story (a fullwidth colon in Chinese), and no story name has one.
function E.CleanStoryText(text)
    local plain = E.StripColorEscapes(text or "")
    local wide = plain:find(WIDE_COLON, 1, true)
    if wide then
        plain = plain:sub(wide + #WIDE_COLON)
    else
        plain = plain:match("^[^:]*:(.*)$") or plain
    end
    return plain:match("^%s*(.-)%s*$") or plain
end

local index

local function BuildIndex()
    index = {}
    for id, st in pairs(E.Stories) do
        index[st.name:lower()] = id
        for _, alt in ipairs(st.also or {}) do index[alt:lower()] = id end
        local own = E.StoryNames and E.StoryNames[id]
        if own then index[own:lower()] = id end
    end
end

function E:StoryFor(text)
    if not text or text == "" then return nil end
    if not index then BuildIndex() end
    return index[self.CleanStoryText(text):lower()]
end

function E:StoryID(widgetID, text)
    if widgetID and self.Stories[widgetID] then return widgetID end
    return self:StoryFor(text)
end

function E:StoryName(id)
    local st = id and self.Stories[id]
    if not st then return nil end
    return (self.StoryNames and self.StoryNames[id]) or st.name
end

local function Mine(id)
    local own = E.db and E.db.storyGrades
    local v = own and own[id]
    if GRADE_ORDER[v] or v == "x" then return v end
    return nil
end

function E:StoryGrade(id)
    local st = id and self.Stories[id]
    if not st then return nil end
    local mine = Mine(id)
    if mine and mine ~= "x" then return mine, st.grade, mine end
    return st.grade, st.grade, mine
end

function E:SetStoryGrade(id, value)
    if not (self.Stories[id] and self.db) then return end
    if value ~= nil and not (GRADE_ORDER[value] or value == "x") then return end
    self.db.storyGrades = self.db.storyGrades or {}
    self.db.storyGrades[id] = value
    self:FireCallback("StoryGradesChanged")
end

function E:ResetStoryGrades()
    if self.db then self.db.storyGrades = {} end
    self:FireCallback("StoryGradesChanged")
end

-- Deliberately English: a bug-report dump, not UI.
function E:DumpStories()
    print("|cFFFF2222Everything Delves|r: today's stories")
    for _, d in ipairs(self.DelveData or {}) do
        local text, widget = self:GetDelveStoryVariant(d.name)
        local id = self:StoryID(widget, text)
        local shown, comp, mine = self:StoryGrade(id)
        print(("  %s: widget=%s text=%q -> %s (%s, compendium %s, yours %s)"):format(d.name, tostring(widget), tostring(text),
            tostring(id and self.Stories[id].name), tostring(shown), tostring(comp), tostring(mine)))
    end
end
