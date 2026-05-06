--[[
    FS25_SaveUnitProfiles
    ModVersion: 0.1.0.0
    BuildTag: 20260506.1

    Purpose:
      Apply money/unit display preferences from a per-save XML profile.

    Notes:
      - moneyUnit: 1 = Euro, 2 = Dollar, 3 = Pounds
      - Settings are global FS profile settings, so this mod applies them when a save is loaded.
      - Runtime UI refresh behaviour depends on how FS25 caches unit displays in each screen.
]]

SaveUnitProfiles = {}
SaveUnitProfiles.MOD_NAME = g_currentModName or "FS25_SaveUnitProfiles"
SaveUnitProfiles.VERSION = "0.1.0.0"
SaveUnitProfiles.BUILD_TAG = "20260506.1"
SaveUnitProfiles.config = nil
SaveUnitProfiles.activeSlot = nil
SaveUnitProfiles.activeProfileName = nil
SaveUnitProfiles.lastApplyOk = false
SaveUnitProfiles.hasApplied = false
SaveUnitProfiles.applyDelayMs = 1500
SaveUnitProfiles.elapsedMs = 0
SaveUnitProfiles.debug = true

local function suBoolToString(value)
    if value == nil then
        return "nil"
    end
    return tostring(value)
end

local function suTrim(value)
    if value == nil then
        return nil
    end
    return string.match(tostring(value), "^%s*(.-)%s*$")
end

function SaveUnitProfiles:log(message)
    print(string.format("[SaveUnitProfiles] %s", tostring(message)))
end

function SaveUnitProfiles:debugLog(message)
    if self.debug then
        self:log(message)
    end
end

function SaveUnitProfiles:getConfigDir()
    return getUserProfileAppPath() .. "modSettings/FS25_SaveUnitProfiles/"
end

function SaveUnitProfiles:getConfigPath()
    return self:getConfigDir() .. "saveUnitProfiles.xml"
end

function SaveUnitProfiles:moneyName(value)
    value = tonumber(value)
    if value == 1 then
        return "Euro"
    elseif value == 2 then
        return "Dollar"
    elseif value == 3 then
        return "Pounds"
    end
    return "Unknown"
end

function SaveUnitProfiles:ensureDefaultConfig()
    local dir = self:getConfigDir()
    createFolder(dir)

    local path = self:getConfigPath()
    if fileExists(path) then
        return
    end

    local xml = createXMLFile("saveUnitProfiles", path, "saveUnitProfiles")
    if xml == 0 or xml == nil then
        self:log("ERROR: Could not create default config at " .. tostring(path))
        return
    end

    setXMLString(xml, "saveUnitProfiles.profiles.profile(0)#name", "US")
    setXMLInt(xml,    "saveUnitProfiles.profiles.profile(0).money", 2)
    setXMLBool(xml,   "saveUnitProfiles.profiles.profile(0).miles", true)
    setXMLBool(xml,   "saveUnitProfiles.profiles.profile(0).fahrenheit", true)
    setXMLBool(xml,   "saveUnitProfiles.profiles.profile(0).acre", true)
    setXMLBool(xml,   "saveUnitProfiles.profiles.profile(0).use24HourTime", false)

    setXMLString(xml, "saveUnitProfiles.profiles.profile(1)#name", "UK")
    setXMLInt(xml,    "saveUnitProfiles.profiles.profile(1).money", 3)
    setXMLBool(xml,   "saveUnitProfiles.profiles.profile(1).miles", true)
    setXMLBool(xml,   "saveUnitProfiles.profiles.profile(1).fahrenheit", false)
    setXMLBool(xml,   "saveUnitProfiles.profiles.profile(1).acre", true)
    setXMLBool(xml,   "saveUnitProfiles.profiles.profile(1).use24HourTime", true)

    setXMLString(xml, "saveUnitProfiles.profiles.profile(2)#name", "EU")
    setXMLInt(xml,    "saveUnitProfiles.profiles.profile(2).money", 1)
    setXMLBool(xml,   "saveUnitProfiles.profiles.profile(2).miles", false)
    setXMLBool(xml,   "saveUnitProfiles.profiles.profile(2).fahrenheit", false)
    setXMLBool(xml,   "saveUnitProfiles.profiles.profile(2).acre", false)
    setXMLBool(xml,   "saveUnitProfiles.profiles.profile(2).use24HourTime", true)

    setXMLInt(xml,    "saveUnitProfiles.savegames.savegame(0)#slot", 1)
    setXMLString(xml, "saveUnitProfiles.savegames.savegame(0)#profile", "UK")

    saveXMLFile(xml)
    delete(xml)

    self:log("Created default config: " .. path)
end

function SaveUnitProfiles:readProfile(xml, index)
    local base = string.format("saveUnitProfiles.profiles.profile(%d)", index)
    local name = suTrim(getXMLString(xml, base .. "#name"))
    if name == nil or name == "" then
        return nil
    end

    return {
        name = name,
        money = getXMLInt(xml, base .. ".money"),
        miles = getXMLBool(xml, base .. ".miles"),
        fahrenheit = getXMLBool(xml, base .. ".fahrenheit"),
        acre = getXMLBool(xml, base .. ".acre"),
        use24HourTime = getXMLBool(xml, base .. ".use24HourTime")
    }
end

function SaveUnitProfiles:loadConfig()
    self:ensureDefaultConfig()

    local path = self:getConfigPath()
    local xml = loadXMLFile("saveUnitProfiles", path)
    if xml == 0 or xml == nil then
        self:log("ERROR: Could not load config: " .. tostring(path))
        return false
    end

    local config = {
        profiles = {},
        savegames = {}
    }

    local i = 0
    while true do
        local profile = self:readProfile(xml, i)
        if profile == nil then
            break
        end
        config.profiles[profile.name] = profile
        i = i + 1
    end

    i = 0
    while true do
        local base = string.format("saveUnitProfiles.savegames.savegame(%d)", i)
        local slot = getXMLInt(xml, base .. "#slot")
        local profileName = suTrim(getXMLString(xml, base .. "#profile"))
        if slot == nil then
            break
        end
        if profileName ~= nil and profileName ~= "" then
            config.savegames[tonumber(slot)] = profileName
        end
        i = i + 1
    end

    delete(xml)

    self.config = config
    self:debugLog(string.format("Loaded config: %d profile(s), %d savegame mapping(s)", self:countTable(config.profiles), self:countTable(config.savegames)))
    return true
end

function SaveUnitProfiles:countTable(tbl)
    local count = 0
    if tbl ~= nil then
        for _, _ in pairs(tbl) do
            count = count + 1
        end
    end
    return count
end

function SaveUnitProfiles:getCurrentSaveSlot()
    if g_currentMission ~= nil and g_currentMission.missionInfo ~= nil then
        local info = g_currentMission.missionInfo

        if info.savegameIndex ~= nil then
            local index = tonumber(info.savegameIndex)
            if index ~= nil then
                return index
            end
        end

        if info.savegameDirectory ~= nil then
            local match = string.match(tostring(info.savegameDirectory), "savegame(%d+)")
            if match ~= nil then
                return tonumber(match)
            end
        end
    end

    if g_savegameXML ~= nil and g_savegameXML.savegameIndex ~= nil then
        return tonumber(g_savegameXML.savegameIndex)
    end

    return nil
end

function SaveUnitProfiles:getProfileForSlot(slot)
    if self.config == nil then
        return nil, nil
    end

    local profileName = self.config.savegames[tonumber(slot)]
    if profileName == nil then
        return nil, nil
    end

    return self.config.profiles[profileName], profileName
end

function SaveUnitProfiles:setGameSetting(settingName, value)
    if value == nil then
        return true, "skipped:nil"
    end

    if g_gameSettings == nil or g_gameSettings.setValue == nil then
        return false, "g_gameSettings unavailable"
    end

    local ok = g_gameSettings:setValue(settingName, value, true)
    return ok == true, tostring(ok)
end

function SaveUnitProfiles:applyProfile(profile, profileName, reason)
    if profile == nil then
        self:log("No profile to apply.")
        return false
    end

    local results = {}
    local allOk = true

    local function apply(settingName, value)
        local ok, detail = self:setGameSetting(settingName, value)
        results[#results + 1] = string.format("%s=%s [%s]", settingName, tostring(value), tostring(detail))
        if not ok then
            allOk = false
        end
    end

    apply("moneyUnit", tonumber(profile.money))
    apply("useMiles", profile.miles)
    apply("useFahrenheit", profile.fahrenheit)
    apply("useAcre", profile.acre)
    apply("use24HourTime", profile.use24HourTime)

    self.activeProfileName = profileName or profile.name
    self.lastApplyOk = allOk

    self:log(string.format("Applied profile '%s' for savegame%s (%s): %s",
        tostring(self.activeProfileName),
        self.activeSlot ~= nil and tostring(self.activeSlot) or "?",
        tostring(reason or "manual"),
        table.concat(results, "; ")
    ))

    if not allOk then
        self:log("WARNING: One or more settings did not report success. Check whether FS25 recognises all setting names in this build.")
    end

    return allOk
end

function SaveUnitProfiles:applyForCurrentSave(reason)
    if self.config == nil then
        self:loadConfig()
    end

    local slot = self:getCurrentSaveSlot()
    self.activeSlot = slot

    if slot == nil then
        self:log("Could not detect active savegame slot. Use suApply <profileName> to apply manually.")
        return false
    end

    local profile, profileName = self:getProfileForSlot(slot)
    if profile == nil then
        self:log(string.format("No unit profile mapped for savegame%d. Edit %s or use suApply <profileName>.", slot, self:getConfigPath()))
        return false
    end

    return self:applyProfile(profile, profileName, reason or "save-load")
end

function SaveUnitProfiles:loadMap(name)
    self:log(string.format("Loaded v%s (%s)", self.VERSION, self.BUILD_TAG))
    self:loadConfig()
    self.activeSlot = self:getCurrentSaveSlot()
    self.elapsedMs = 0
    self.hasApplied = false
    self:registerConsoleCommands()
end

function SaveUnitProfiles:update(dt)
    if self.hasApplied then
        return
    end

    self.elapsedMs = self.elapsedMs + dt
    if self.elapsedMs >= self.applyDelayMs then
        self.hasApplied = true
        self:applyForCurrentSave("delayed-load")
    end
end

function SaveUnitProfiles:deleteMap()
    self.hasApplied = false
    self.config = nil
    self.activeSlot = nil
    self.activeProfileName = nil
end

function SaveUnitProfiles:registerConsoleCommands()
    if self.consoleCommandsRegistered then
        return
    end

    addConsoleCommand("suStatus", "SaveUnitProfiles: print active save/profile and current game settings", "consoleStatus", self)
    addConsoleCommand("suReload", "SaveUnitProfiles: reload XML config", "consoleReload", self)
    addConsoleCommand("suApply", "SaveUnitProfiles: apply mapped profile, or named profile: suApply UK", "consoleApply", self)
    addConsoleCommand("suDebug", "SaveUnitProfiles: toggle debug logging: suDebug on|off", "consoleDebug", self)

    self.consoleCommandsRegistered = true
end

function SaveUnitProfiles:consoleStatus()
    local slot = self:getCurrentSaveSlot()
    self:log("Status")
    self:log("  config: " .. self:getConfigPath())
    self:log("  activeSlot: " .. tostring(slot))
    self:log("  activeProfile: " .. tostring(self.activeProfileName))
    self:log("  lastApplyOk: " .. tostring(self.lastApplyOk))

    if g_gameSettings ~= nil and g_gameSettings.getValue ~= nil then
        self:log("  moneyUnit: " .. tostring(g_gameSettings:getValue("moneyUnit")) .. " (" .. self:moneyName(g_gameSettings:getValue("moneyUnit")) .. ")")
        self:log("  useMiles: " .. suBoolToString(g_gameSettings:getValue("useMiles")))
        self:log("  useFahrenheit: " .. suBoolToString(g_gameSettings:getValue("useFahrenheit")))
        self:log("  useAcre: " .. suBoolToString(g_gameSettings:getValue("useAcre")))
        self:log("  use24HourTime: " .. suBoolToString(g_gameSettings:getValue("use24HourTime")))
    else
        self:log("  g_gameSettings unavailable")
    end
end

function SaveUnitProfiles:consoleReload()
    self:loadConfig()
    self:log("Config reloaded.")
end

function SaveUnitProfiles:consoleApply(profileName)
    if self.config == nil then
        self:loadConfig()
    end

    profileName = suTrim(profileName)
    if profileName ~= nil and profileName ~= "" then
        local profile = self.config.profiles[profileName]
        if profile == nil then
            self:log("No profile named '" .. tostring(profileName) .. "'.")
            return
        end
        self.activeSlot = self:getCurrentSaveSlot()
        self:applyProfile(profile, profileName, "manual-console")
        return
    end

    self:applyForCurrentSave("manual-console")
end

function SaveUnitProfiles:consoleDebug(value)
    value = suTrim(value)
    if value == "on" or value == "true" or value == "1" then
        self.debug = true
    elseif value == "off" or value == "false" or value == "0" then
        self.debug = false
    else
        self.debug = not self.debug
    end
    self:log("Debug " .. (self.debug and "enabled" or "disabled"))
end

addModEventListener(SaveUnitProfiles)
