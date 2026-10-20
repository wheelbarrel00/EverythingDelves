local E = EverythingDelves
local L = E.L

local ED_TEXTURES = "Interface\\AddOns\\EverythingDelves\\Media\\Textures\\"
local TROVE_ICON = 1064187

local builtTabs = {}

function E:ConfirmResetSettings()
    self:ShowDialog({
        text = L["Reset all Everything Delves settings to defaults?"],
        button1 = L["Yes"], button2 = L["Cancel"], danger = true,
        onAccept = function()
            E:ResetDB()
            print(E.CC.header .. "Everything Delves|r: " .. L["All settings reset."])
        end,
    })
end

function E:ConfirmClearDelveHistory()
    self:ShowDialog({
        text = L["Are you sure you want to clear all Delve History?\n\nThis will permanently erase all lifetime stats, run history, and personal bests for every delve on this character. This cannot be undone."],
        button1 = L["Yes, Erase Everything"], button2 = L["Cancel"], danger = true,
        onAccept = function()
            E:ClearDelveHistory()
            print(E.CC.header .. "Everything Delves|r: " .. L["Delve history cleared."])
        end,
    })
end

local function setting(key, after)
    return function() return E.db and E.db[key] == true end,
        function(v)
            if E.db then E.db[key] = v end
            if after then after(v) end
        end
end

-- Read as on unless saved off, the way the features behind these switches read them
local function settingOnByDefault(key, after)
    return function() return not (E.db and E.db[key] == false) end,
        function(v)
            if E.db then E.db[key] = v end
            if after then after(v) end
        end
end

local function updateHUD()
    if E.UpdateDelveObjectivesWindow then E:UpdateDelveObjectivesWindow() end
end

local function updateAudio()
    if E.ApplyCompanionAudio then E:ApplyCompanionAudio() end
end

-- A switch whose tooltip keeps the title it always had rather than taking its label
local function addCheckbox(ctx, content, card, label, get, set, tipTitle, tipBody)
    local cb = ctx:CreateCheckbox(content, label, get, set)
    if tipTitle then ctx:AttachTooltip(cb, tipTitle, tipBody) end
    card:Add(cb)
    return cb
end

local function pageOptions()
    local out = {}
    for i = 1, E.NUM_PAGES do out[i] = { value = i, label = E.TAB_NAMES[i] } end
    return out
end

local function accentOptions()
    local classHex = "|cFF" .. E:GetClassAccentColor().hex
    return {
        { value = "gold",     label = L["%s (default)"]:format("|cFFFFD100" .. L["Gold"] .. "|r") },
        { value = "red",      label = "|cFFFF2222" .. L["Red"] .. "|r" },
        { value = "purple",   label = "|cFFB280FF" .. L["Purple"] .. "|r" },
        { value = "green",    label = "|cFF4CD94C" .. L["Dark Green"] .. "|r" },
        { value = "darkblue", label = "|cFF3388FF" .. L["Dark Blue"] .. "|r" },
        { value = "class",    label = classHex .. L["Class Color"] .. "|r" },
    }
end

local function generalCard(self, content, stack)
    local card = stack(self:CreateGroup(content, L["General"]))

    card:Add(self:CreateDropdown(content, L["Default Tab (opens to this tab)"], pageOptions(),
        function()
            local v = E.db and E.db.defaultTab
            if type(v) ~= "number" or v < 1 or v > E.NUM_PAGES then return 1 end
            return v
        end,
        function(v) if E.db then E.db.defaultTab = v end end))

    local scale = self:CreateSlider(content, L["UI Scale"], 80, 150, 5,
        function() return math.floor(((E.db and E.db.uiScale) or 1) * 100 + 0.5) end,
        function(v) if E.db then E.db.uiScale = v / 100 end end,
        nil, function(v) return ("%d%%"):format(v) end)
    card:Add(scale)
    -- The slider sits inside a window it scales, so applying mid-drag would fight the drag
    scale.slider:HookScript("OnMouseUp", function() E:ApplyUIScale() end)

    card:Add(self:CreateSlider(content, L["History kept per delve"], E.HISTORY_CAP_MIN, E.HISTORY_CAP_MAX, 10,
        function() return (E.db and E.db.historyCap) or E.HISTORY_CAP_MIN end,
        function(v) if E.db then E.db.historyCap = v end end,
        L["How many recent runs to store for each delve (newest first)."] .. "\n\n"
            .. L["Default 20, up to %d. Raising it keeps more history from now on; runs already trimmed can't be recovered. Lowering it trims a delve's oldest runs the next time you run it."]:format(E.HISTORY_CAP_MAX)))

    card:Add(self:CreateCheckbox(content, L["Show Minimap / Broker Button"],
        function() return E.db and E.db.minimapButton and E.db.minimapButton.show end,
        function(v) if E.SetMinimapButtonVisible then E:SetMinimapButtonVisible(v) end end))

    local get, set = setting("showShardWeekly")
    addCheckbox(self, content, card, L["Show weekly earnable shards in button tooltip"], get, set,
        L["Weekly Shards in Tooltip"],
        L["On the minimap / broker button tooltip, shows your Coffer Key Shards as owned / still-earnable-this-week instead of just the owned count."])

    card:Add(self:CreateRadioGroup(content, L["After an update"], {
            { value = "popup", label = L["Popup window"] },
            { value = "chat",  label = L["Chat link"] },
            { value = "none",  label = L["Off"] },
        },
        function() return (E.db and E.db.whatsNewMode) or "popup" end,
        function(v) E:SetWhatsNewMode(v) end,
        nil, nil, L["What's New"],
        L["How Everything Delves tells you about a version that brings new features: a Popup window, a quiet clickable Chat link in your chat, or Off. Releases with only fixes stay quiet, and the next feature release shows them too. Reopen the notes any time from the About tab or with /ed whatsnew."]))

    get, set = settingOnByDefault("showTrovehunterReminder")
    local trove = self:CreateCheckbox(content, L["Show Trovehunter's Bounty reminder on Delve entry"], get, set, nil,
        "Interface\\Icons\\INV_Misc_QuestionMark")
    -- The library takes a texture path, and this icon is known here only by its file ID
    trove.icon:SetTexture(TROVE_ICON)
    card:Add(trove)
end

local function audioCard(self, content, stack)
    local card = stack(self:CreateGroup(content, L["Companion Audio"]))
    local get, set = setting("muteValeera", updateAudio)
    addCheckbox(self, content, card, L["Mute Valeera voice lines"], get, set)
    get, set = setting("muteValeeraBubbles", updateAudio)
    addCheckbox(self, content, card, L["Suppress Valeera speech bubbles"], get, set)
    get, set = setting("muteDundun", updateAudio)
    addCheckbox(self, content, card, L["Mute Dundun (Abundance event rat) voice lines"], get, set,
        L["Who is Dundun?"],
        L["Dundun is the rat loa who hosts the Abundance cave events and repeats his voice lines endlessly. Muting only silences his audio - the event itself is unaffected."])
end

local function generalFooter(self, bar)
    local reset = self:CreateButton(bar, L["Reset All Settings"], nil,
        function() E:ConfirmResetSettings() end, nil, "danger")
    reset:SetPoint("RIGHT")
    self:AttachTooltip(reset, L["Reset Settings"],
        L["Restore the options to their default values. Your saved runs and the number of runs kept per delve are left alone."]
            .. "\n\n" .. L["This cannot be undone."])

    local clear = self:CreateButton(bar, L["Clear Delve History"], nil,
        function() E:ConfirmClearDelveHistory() end,
        L["Erase all recorded delve runs and lifetime stats for this character."] .. "\n\n" .. L["This cannot be undone."],
        "danger")
    clear:SetPoint("RIGHT", reset, "LEFT", -self:Spacing("buttonGap"), 0)
end

local function displayCard(self, content, stack)
    local card = stack(self:CreateGroup(content, L["Display"]))

    card:Add(self:CreateDropdown(content, L["Accent Color"], accentOptions,
        function() return (E.db and E.db.accentColor) or "gold" end,
        function(v)
            if E.db then E.db.accentColor = v end
            if E.ApplyAccentColor then E:ApplyAccentColor(v) end
        end,
        L["Colors the delve HUD, the curio and Trovehunter's Bounty reminders, and the panel beside a delve's difficulty picker."]))

    card:Add(self:CreateDropdown(content, L["Delve Achievements on Map Tooltips"], {
            { value = "summary", label = L["Summary line — hold Shift for details (default)"] },
            { value = "full",    label = L["Always show full details"] },
            { value = "off",     label = L["Off"] },
        },
        function() return (E.db and E.db.achievementTooltip) or "summary" end,
        function(v) if E.db then E.db.achievementTooltip = v end end))

    local get, set = settingOnByDefault("showPickerInfo")
    addCheckbox(self, content, card, L["Show Tier & Achievement Panel at Delve Entrance"], get, set,
        L["Tier & Achievement Panel"],
        L["When you open a delve's difficulty picker at its entrance, shows a panel with the loot and Great Vault item levels for every tier, plus your story, chest, and tier-goal achievement progress for that delve."])
end

local function hudCard(self, content, stack)
    local card = stack(self:CreateGroup(content, L["Delve HUD"]))

    local get, set = setting("showDelveObjectives", updateHUD)
    addCheckbox(self, content, card, L["Show Bonus Spoils Tracker"], get, set,
        L["Bonus Spoils Tracker"],
        L["While inside a delve, tracks the Nemesis Strongbox packs so you know you've cleared them all before pulling the boss."]
            .. "\n\n" .. L["Drag the tracker to move it."])

    get, set = settingOnByDefault("showRunTimer", updateHUD)
    addCheckbox(self, content, card, L["Show Run Timer"], get, set,
        L["Run Timer"],
        L["Shows your elapsed run time on a small on-screen display while you're inside a delve. Works on its own - you don't need the Bonus Spoils tracker."]
            .. "\n\n" .. L["Drag the display to move it."])

    get, set = settingOnByDefault("showDelveHUD", updateHUD)
    addCheckbox(self, content, card, L["Show Delve HUD"], get, set,
        L["Delve HUD"],
        L["An on-screen panel while inside a delve showing the story variant and its grade, the recommended curios and poison for your companion, your run timer, and your death count."]
            .. "\n\n" .. L["Shares the on-screen frame with the Run Timer and Bonus Spoils tracker - drag any of them to move it."])

    get, set = settingOnByDefault("showRunResult", updateHUD)
    addCheckbox(self, content, card, L["Show Best Time & keep timer after boss"], get, set,
        L["Best Time & Run Result"],
        L["Adds your fastest time for the current delve to the on-screen panel (your best at this tier, or your overall best labelled with its tier), and keeps the run timer up after you beat the boss - green if you beat your best time at this tier, red if not. Needs one previous run logged."])
end

local function alertsCard(self, content, stack)
    local card = stack(self:CreateGroup(content, L["Alerts & Tracking"]))
    local threshold
    local function sync() self:SetDependent(threshold, E.db and E.db.lowShardWarning == true) end
    content._sync = sync

    local get, set = setting("lowShardWarning", sync)
    addCheckbox(self, content, card, L["Low Shard Warning"], get, set)

    threshold = self:CreateSlider(content, L["Warning Threshold"], 50, 1000, 50,
        function() return (E.db and E.db.lowShardThreshold) or 100 end,
        function(v) if E.db then E.db.lowShardThreshold = v end end,
        nil, function(v) return L["%d shards"]:format(v) end)
    card:Add(threshold, { dependent = true })

    get, set = setting("alertNewBountiful")
    addCheckbox(self, content, card, L["Chat Alert When New Bountiful Delves Rotate In"], get, set)
    get, set = setting("alertSpecialAssignment")
    addCheckbox(self, content, card, L["Chat Alert for Special Assignments"], get, set)
    get, set = settingOnByDefault("alertCompanionRole")
    addCheckbox(self, content, card, L["Warn When Companion Has No Role Assigned"], get, set)
end

local function register(def, ...)
    local cards = { ... }
    def.build = function(self, content)
        builtTabs[#builtTabs + 1] = content
        local stack = E.CardStack(self)
        for _, build in ipairs(cards) do build(self, content, stack) end
    end
    def.refresh = function(_, content)
        if content._sync then content._sync() end
    end
    E.ui:RegisterTab(def)
end

register({ id = "general", title = L["General"], order = 10, icon = E.ui:Texture("icon-general"),
           footer = generalFooter }, generalCard, audioCard)
register({ id = "display", title = L["Display"], order = 20, icon = E.ui:Texture("icon-appearance") },
         displayCard, hudCard)
register({ id = "alerts", title = L["Alerts & Tracking"], order = 30, icon = ED_TEXTURES .. "icon-bell" },
         alertsCard)

local function settingsWindow()
    return E.ui:BuildSettings("EverythingDelvesOptionsFrame")
end

function E:ShowOptions(tabId)
    local f = settingsWindow()
    if tabId then self.ui:SelectTab(tabId) end
    if not f:IsShown() then self.ui:ToggleSettings() end
    f:Raise()
    -- The main window is toplevel, so left open it would cover this one and take its clicks
    if self.MainFrame and self.MainFrame:IsShown() then self.MainFrame:Hide() end
end

function E:ToggleOptions(tabId)
    local f = settingsWindow()
    if f:IsShown() then f:Hide() else self:ShowOptions(tabId) end
end

function E:ApplyUIScale()
    local f = self.MainFrame
    if f then
        f:SetScale((self.db and self.db.uiScale) or 1)
        f:Refit()
    end
    self.ui:ApplyWindowScale()
end

function E.RefreshOptionsWidgets()
    for _, content in ipairs(builtTabs) do
        for _, c in ipairs(content._controls) do
            if c.Refresh then c:Refresh() end
        end
        if content._sync then content._sync() end
    end
end
