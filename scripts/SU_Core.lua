--[[
    FS25_SaveUnitProfiles
    ModVersion: 1.2.0.0
    BuildTag: 20260527.31

    Purpose:
      Apply money/unit display preferences from a per-save XML profile.

    Notes:
      - moneyUnit: 1 = Euro, 2 = Dollar, 3 = Pounds
      - Settings are global FS profile settings, so this mod applies them when a save is loaded.
      - Runtime UI refresh behaviour depends on how FS25 caches unit displays in each screen.
]]

SaveUnitProfiles = {}
SaveUnitProfiles.MOD_NAME = g_currentModName or "FS25_SaveUnitProfiles"
SaveUnitProfiles.MOD_DIR = g_currentModDirectory or ""
SaveUnitProfiles.VERSION = "1.2.0.0"
SaveUnitProfiles.BUILD_TAG = "20260527.34"
SaveUnitProfiles.config = nil
SaveUnitProfiles.activeSlot = nil
SaveUnitProfiles.activeProfileName = nil
SaveUnitProfiles.lastApplyOk = false
SaveUnitProfiles.hasApplied = false
SaveUnitProfiles.applyDelayMs = 1500
SaveUnitProfiles.elapsedMs = 0
SaveUnitProfiles.debug = false

SaveUnitProfiles.MONEY_UNITS = {
    [1]  = { name = "Euro",                symbol = "€",   prefix = false, isDefault = true  },
    [2]  = { name = "Dollar",              symbol = "$",   prefix = true,  isDefault = true  },
    [3]  = { name = "Pounds",              symbol = "£",   prefix = true,  isDefault = true  },
    [4]  = { name = "Brazilian Real",      symbol = "R$",  prefix = true,  iconSymbol = "R$"  },
    [5]  = { name = "Chinese Yuan",        symbol = "CN¥", prefix = true,  iconSymbol = "CN¥" },
    [6]  = { name = "Czech Koruna",        symbol = "Kč",  prefix = false, iconSymbol = "Kč"  },
    [7]  = { name = "Hungarian Forint",    symbol = "Ft",  prefix = false, iconSymbol = "Ft"  },
    [8]  = { name = "Japanese Yen",        symbol = "¥",   prefix = true,  iconSymbol = "¥"   },
    [9]  = { name = "Norwegian Krone",     symbol = "kr",  prefix = false, iconSymbol = "kr"  },
    [10] = { name = "Polish Złoty",        symbol = "zł",  prefix = false, iconSymbol = "PLN" },
    [11] = { name = "Romanian Leu",        symbol = "lei", prefix = false, iconSymbol = "lei" },
    [12] = { name = "Russian Ruble",       symbol = "руб", prefix = false, iconSymbol = "руб" },
    [13] = { name = "South Korean Won",    symbol = "₩",   prefix = true,  iconSymbol = "₩"   },
    [14] = { name = "Swiss Franc",         symbol = "CHF", prefix = true,  iconSymbol = "CHF" },
    [15] = { name = "Turkish Lira",        symbol = "TL",  prefix = true,  iconSymbol = "TL"  },
    [16] = { name = "Ukrainian Hryvnia",   symbol = "грн", prefix = false, iconSymbol = "грн" }
}

SaveUnitProfiles.BUILT_IN_PROFILES = {
    { name = "US", label = "United States", money = 2, miles = true,  fahrenheit = true,  acre = true,  use24HourTime = false },
    { name = "UK", label = "United Kingdom", money = 3, miles = true,  fahrenheit = false, acre = true,  use24HourTime = true  },
    { name = "EU", label = "European Union", money = 1, miles = false, fahrenheit = false, acre = false, use24HourTime = true  },
    { name = "CA", label = "Canada", money = 2, miles = false, fahrenheit = false, acre = true,  use24HourTime = true  },
    { name = "BR", label = "Brazil", money = 4, miles = false, fahrenheit = false, acre = false, use24HourTime = true },
    { name = "CN", label = "China", money = 5, miles = false, fahrenheit = false, acre = false, use24HourTime = true },
    { name = "CZ", label = "Czechia", money = 6, miles = false, fahrenheit = false, acre = false, use24HourTime = true },
    { name = "HU", label = "Hungary", money = 7, miles = false, fahrenheit = false, acre = false, use24HourTime = true },
    { name = "JP", label = "Japan", money = 8, miles = false, fahrenheit = false, acre = false, use24HourTime = true },
    { name = "NO", label = "Norway", money = 9, miles = false, fahrenheit = false, acre = false, use24HourTime = true },
    { name = "PL", label = "Poland", money = 10, miles = false, fahrenheit = false, acre = false, use24HourTime = true },
    { name = "RO", label = "Romania", money = 11, miles = false, fahrenheit = false, acre = false, use24HourTime = true },
    { name = "RU", label = "Russia", money = 12, miles = false, fahrenheit = false, acre = false, use24HourTime = true },
    { name = "KR", label = "South Korea", money = 13, miles = false, fahrenheit = false, acre = false, use24HourTime = true },
    { name = "CH", label = "Switzerland", money = 14, miles = false, fahrenheit = false, acre = false, use24HourTime = true },
    { name = "TR", label = "Turkey", money = 15, miles = false, fahrenheit = false, acre = false, use24HourTime = true },
    { name = "UA", label = "Ukraine", money = 16, miles = false, fahrenheit = false, acre = false, use24HourTime = true }
}

function SaveUnitProfiles:getBuiltInProfileLabel(profileName)
    profileName = tostring(profileName or "")
    for _, builtIn in ipairs(self.BUILT_IN_PROFILES or {}) do
        if tostring(builtIn.name or "") == profileName then
            return builtIn.label
        end
    end
    return nil
end

function SaveUnitProfiles:getProfileFriendlyNameByName(profileName)
    profileName = tostring(profileName or "")

    local builtInLabel = self:getBuiltInProfileLabel(profileName)
    if builtInLabel ~= nil and tostring(builtInLabel) ~= "" then
        return string.format("%s - %s", profileName, tostring(builtInLabel))
    end

    if self:isSavegameGeneratedProfileName(profileName) then
        local slot = string.match(profileName, "^SAVEGAME_(%d+)$")
        if slot ~= nil then
            return string.format("%s - custom profile for savegame%s", profileName, tostring(slot))
        end
    end

    return profileName
end


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
    local unit = self:getMoneyUnitDefinition(value)
    if unit ~= nil then
        return unit.name or unit.symbol or tostring(value)
    end
    return "Unknown"
end

function SaveUnitProfiles:getMoneyUnitDefinition(value)
    value = tonumber(value) or 1
    return self.MONEY_UNITS[value]
end

function SaveUnitProfiles:showNotification(message, isWarning)
    message = tostring(message or "")
    if message == "" then
        return
    end

    -- FS22/FS25 normally exposes addIngameNotification on the active mission.
    -- Keep this defensive so the mod still works if the notification API is unavailable.
    if g_currentMission ~= nil and g_currentMission.addIngameNotification ~= nil and FSBaseMission ~= nil then
        local notificationType = FSBaseMission.INGAME_NOTIFICATION_INFO
        if isWarning and FSBaseMission.INGAME_NOTIFICATION_CRITICAL ~= nil then
            notificationType = FSBaseMission.INGAME_NOTIFICATION_CRITICAL
        elseif isWarning and FSBaseMission.INGAME_NOTIFICATION_WARNING ~= nil then
            notificationType = FSBaseMission.INGAME_NOTIFICATION_WARNING
        end
        g_currentMission:addIngameNotification(notificationType, message)
    else
        self:debugLog("Notification unavailable: " .. message)
    end
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

    for i, profile in ipairs(self.BUILT_IN_PROFILES) do
        self:writeProfileValues(xml, i - 1, profile)
    end

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
        label = self:getBuiltInProfileLabel(name),
        money = getXMLInt(xml, base .. ".money"),
        miles = getXMLBool(xml, base .. ".miles"),
        fahrenheit = getXMLBool(xml, base .. ".fahrenheit"),
        acre = getXMLBool(xml, base .. ".acre"),
        use24HourTime = getXMLBool(xml, base .. ".use24HourTime")
    }
end


function SaveUnitProfiles:ensureBuiltInProfilesInConfig()
    self:ensureDefaultConfig()

    local path = self:getConfigPath()
    local xml = loadXMLFile("saveUnitProfiles", path)
    if xml == 0 or xml == nil then
        self:log("ERROR: Could not open config to check built-in profiles: " .. tostring(path))
        return false
    end

    local changed = false
    for _, builtIn in ipairs(self.BUILT_IN_PROFILES) do
        local index, nextIndex = self:findProfileIndex(xml, builtIn.name)
        if index == nil then
            self:writeProfileValues(xml, nextIndex or 0, builtIn)
            self:log("Added missing built-in unit profile: " .. tostring(builtIn.name))
            changed = true
        end
    end

    if changed then
        saveXMLFile(xml)
    end
    delete(xml)
    return true
end

function SaveUnitProfiles:loadConfig()
    self:ensureBuiltInProfilesInConfig()

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

function SaveUnitProfiles:addCandidate(candidates, value)
    if value == nil then
        return
    end

    for _, existing in ipairs(candidates) do
        if existing == value then
            return
        end
    end

    candidates[#candidates + 1] = value
end

function SaveUnitProfiles:getSettingCandidates(settingName)
    local candidates = {}
    local setting = GameSettings ~= nil and GameSettings.SETTING or nil

    if setting ~= nil then
        if settingName == "moneyUnit" then
            self:addCandidate(candidates, setting.MONEY_UNIT)
            self:addCandidate(candidates, setting.MONEY)
        elseif settingName == "useMiles" then
            self:addCandidate(candidates, setting.USE_MILES)
            self:addCandidate(candidates, setting.MILES)
        elseif settingName == "useFahrenheit" then
            self:addCandidate(candidates, setting.USE_FAHRENHEIT)
            self:addCandidate(candidates, setting.FAHRENHEIT)
        elseif settingName == "useAcre" then
            self:addCandidate(candidates, setting.USE_ACRE)
            self:addCandidate(candidates, setting.ACRE)
        elseif settingName == "use24HourTime" then
            self:addCandidate(candidates, setting.USE_24_HOUR_TIME)
            self:addCandidate(candidates, setting.USE_24H_TIME)
            self:addCandidate(candidates, setting.USE_24_HOUR)
            self:addCandidate(candidates, setting.TIME_FORMAT_24H)
        end
    end

    self:addCandidate(candidates, settingName)
    return candidates
end


function SaveUnitProfiles:getCurrentMoneyUnit()
    return tonumber(self:getGameSetting("moneyUnit")) or tonumber(self.currentRuntimeMoneyUnit) or 1
end

function SaveUnitProfiles:getIntegratedCurrency(value)
    value = tonumber(value) or self:getCurrentMoneyUnit()
    return self.MONEY_UNITS[value]
end

function SaveUnitProfiles:getIntegratedCurrencySymbol(value, useShort, superFunc, i18n)
    local currency = self:getIntegratedCurrency(value)
    if currency == nil then
        if superFunc ~= nil then
            return superFunc(i18n, useShort)
        end
        return "?"
    end

    if currency.isDefault and superFunc ~= nil then
        return superFunc(i18n, useShort)
    end

    if useShort and currency.iconSymbol ~= nil then
        return currency.iconSymbol
    end

    return currency.symbol or currency.name or "?"
end

function SaveUnitProfiles:installIntegratedCurrencySupport()
    if self.currencySupportInstalled then
        return
    end

    self.currencySupportInstalled = true

    self.usingIntegratedCurrencySupport = true
    self:extendMoneyUnitSelectorTexts()
    self:patchCurrencyFormatting()
    self:log("Integrated extended currencies registered.")
end

function SaveUnitProfiles:getMoneyUnitTexts()
    local texts = {}
    local i = 1
    while self.MONEY_UNITS[i] ~= nil do
        texts[i] = self.MONEY_UNITS[i].name or tostring(i)
        i = i + 1
    end
    return texts
end

function SaveUnitProfiles:installMoneyUnitClickCallback(element)
    if element == nil or element.suMoneyUnitCallbackInstalled == true then
        return false
    end

    element.suOriginalOnClickCallback = element.onClickCallback
    element.onClickCallback = function(optionElement, state, ...)
        SaveUnitProfiles:onMoneyUnitClicked(optionElement, state, ...)
    end
    element.suMoneyUnitCallbackInstalled = true
    return true
end

function SaveUnitProfiles:onMoneyUnitClicked(optionElement, state, ...)
    local money = tonumber(state) or 1
    self.currentRuntimeMoneyUnit = money

    if g_gameSettings ~= nil then
        local candidates = self:getSettingCandidates("moneyUnit")
        for _, key in ipairs(candidates or {}) do
            if type(key) == "string" then
                pcall(function()
                    g_gameSettings[key] = money
                end)
            end
        end
    end

    if g_i18n ~= nil and g_i18n.setMoneyUnit ~= nil then
        pcall(function() g_i18n:setMoneyUnit(money) end)
    end

    if g_currentMission ~= nil and g_currentMission.setMoneyUnit ~= nil then
        pcall(function() g_currentMission:setMoneyUnit(money) end)
    end
end

function SaveUnitProfiles:extendMoneyUnitElement(element, label)
    if element == nil then
        return false
    end

    local texts = self:getMoneyUnitTexts()
    if element.setTexts ~= nil then
        local ok, err = pcall(function()
            element:setTexts(texts)
        end)
        if not ok then
            self:debugLog("Could not set money unit texts on " .. tostring(label) .. ": " .. tostring(err))
            return false
        end
    else
        element.texts = texts
    end

    self:installMoneyUnitClickCallback(element)
    return true
end

function SaveUnitProfiles:extendMoneyUnitSelectorTexts()
    if g_inGameMenu ~= nil then
        self:extendMoneyUnitElement(g_inGameMenu.multiMoneyUnit, "g_inGameMenu.multiMoneyUnit")
        self:extendMoneyUnitElement(g_inGameMenu.moneyElement, "g_inGameMenu.moneyElement")
    end

    local pageSettings = self:getPageSettings()
    if pageSettings ~= nil then
        self:extendMoneyUnitElement(pageSettings.multiMoneyUnit, "pageSettings.multiMoneyUnit")
        self:extendMoneyUnitElement(pageSettings.moneyElement, "pageSettings.moneyElement")

        -- The base settings page maps option controls back to GameSettings keys.
        -- For extended currencies, direct assignment and runtime refresh are safer,
        -- so remove the mapping if present and let our callback handle money unit changes.
        if pageSettings.optionMapping ~= nil and pageSettings.multiMoneyUnit ~= nil then
            pageSettings.optionMapping[pageSettings.multiMoneyUnit] = nil
        end
    end
end

function SaveUnitProfiles:patchCurrencyFormatting()
    if g_i18n == nil then
        return false
    end

    local mt = getmetatable(g_i18n)
    if mt == nil or mt.__index == nil then
        return false
    end

    local envI18n = mt.__index

    if envI18n.suOriginalGetCurrencySymbol == nil and envI18n.getCurrencySymbol ~= nil then
        envI18n.suOriginalGetCurrencySymbol = envI18n.getCurrencySymbol
        envI18n.getCurrencySymbol = function(i18n, useShort)
            local money = SaveUnitProfiles.currentRuntimeMoneyUnit or SaveUnitProfiles:getCurrentMoneyUnit()
            return SaveUnitProfiles:getIntegratedCurrencySymbol(money, useShort, envI18n.suOriginalGetCurrencySymbol, i18n)
        end
    end

    if envI18n.suOriginalFormatMoney == nil and envI18n.formatMoney ~= nil then
        envI18n.suOriginalFormatMoney = envI18n.formatMoney
        envI18n.formatMoney = function(i18n, number, precision, addCurrency, prefixCurrencySymbol)
            local money = SaveUnitProfiles.currentRuntimeMoneyUnit or SaveUnitProfiles:getCurrentMoneyUnit()
            local currency = SaveUnitProfiles:getIntegratedCurrency(money)
            if currency ~= nil and not currency.isDefault and (addCurrency == nil or addCurrency == true) then
                prefixCurrencySymbol = currency.prefix == true
            end
            return envI18n.suOriginalFormatMoney(i18n, number, precision, addCurrency, prefixCurrencySymbol)
        end
    end

    return true
end

function SaveUnitProfiles:getGameSetting(settingName)
    if g_gameSettings == nil then
        return nil
    end

    local candidates = self:getSettingCandidates(settingName)

    if g_gameSettings.getValue ~= nil then
        for _, key in ipairs(candidates) do
            local ok, result = pcall(function()
                return g_gameSettings:getValue(key)
            end)
            if ok and result ~= nil then
                return result
            end
        end
    end

    for _, key in ipairs(candidates) do
        if type(key) == "string" then
            local ok, result = pcall(function()
                return g_gameSettings[key]
            end)
            if ok and result ~= nil then
                return result
            end
        end
    end

    return nil
end

function SaveUnitProfiles:settingsValueMatches(actual, expected)
    if expected == nil then
        return true
    end

    if type(expected) == "boolean" then
        return actual == expected
    end

    if type(expected) == "number" then
        return tonumber(actual) == tonumber(expected)
    end

    return tostring(actual) == tostring(expected)
end

function SaveUnitProfiles:setGameSetting(settingName, value)
    if value == nil then
        return true, "skipped:nil"
    end

    if g_gameSettings == nil then
        return false, "g_gameSettings unavailable"
    end

    local details = {}
    local setValueOk = false
    local candidates = self:getSettingCandidates(settingName)

    -- Use the real GameSettings setter first. This is the path FS25 expects when
    -- Settings menu values need to become the active game values after the menu
    -- closes. Direct assignment alone can be overwritten by the Settings UI.
    if g_gameSettings.setValue ~= nil then
        for _, key in ipairs(candidates) do
            local callOk, result = pcall(function()
                return g_gameSettings:setValue(key, value, true)
            end)

            details[#details + 1] = string.format("setValue(%s)=%s", tostring(key), tostring(callOk and result or ("error:" .. tostring(result))))

            if callOk and result == true then
                setValueOk = true
            end

            local current = self:getGameSetting(settingName)
            if self:settingsValueMatches(current, value) then
                details[#details + 1] = "verifiedAfterSetValue=" .. tostring(current)
                return true, table.concat(details, ",")
            end
        end
    else
        details[#details + 1] = "setValue=unavailable"
    end

    -- Fallback for keys that FS25 exposes as direct fields.
    local anyDirectOk = false
    for _, key in ipairs(candidates) do
        if type(key) == "string" then
            local directOk, directErr = pcall(function()
                g_gameSettings[key] = value
            end)
            details[#details + 1] = string.format("direct(%s)=%s", tostring(key), tostring(directOk and "ok" or ("error:" .. tostring(directErr))))
            anyDirectOk = anyDirectOk or directOk

            local current = self:getGameSetting(settingName)
            if self:settingsValueMatches(current, value) then
                details[#details + 1] = "verifiedAfterDirect=" .. tostring(current)
                return true, table.concat(details, ",")
            end
        end
    end

    local after = self:getGameSetting(settingName)
    local verified = self:settingsValueMatches(after, value)
    details[#details + 1] = "after=" .. tostring(after)
    details[#details + 1] = "verified=" .. tostring(verified)

    return verified or setValueOk == true or anyDirectOk == true, table.concat(details, ",")
end

function SaveUnitProfiles:getCurrentUnitsAsProfile(profileName)
    if g_gameSettings == nil or g_gameSettings.getValue == nil then
        self:log("ERROR: g_gameSettings is unavailable; cannot read current unit settings.")
        return nil
    end

    return {
        name = profileName,
        money = tonumber(self:getGameSetting("moneyUnit")),
        miles = self:getGameSetting("useMiles"),
        fahrenheit = self:getGameSetting("useFahrenheit"),
        acre = self:getGameSetting("useAcre"),
        use24HourTime = self:getGameSetting("use24HourTime")
    }
end

function SaveUnitProfiles:writeProfileValues(xml, index, profile)
    local base = string.format("saveUnitProfiles.profiles.profile(%d)", index)
    setXMLString(xml, base .. "#name", tostring(profile.name))
    setXMLInt(xml,    base .. ".money", tonumber(profile.money) or 1)
    setXMLBool(xml,   base .. ".miles", profile.miles == true)
    setXMLBool(xml,   base .. ".fahrenheit", profile.fahrenheit == true)
    setXMLBool(xml,   base .. ".acre", profile.acre == true)
    setXMLBool(xml,   base .. ".use24HourTime", profile.use24HourTime == true)
end

function SaveUnitProfiles:findProfileIndex(xml, profileName)
    local i = 0
    while true do
        local base = string.format("saveUnitProfiles.profiles.profile(%d)", i)
        local name = suTrim(getXMLString(xml, base .. "#name"))
        if name == nil or name == "" then
            return nil, i
        end
        if name == profileName then
            return i, i + 1
        end
        i = i + 1
    end
end

function SaveUnitProfiles:findSavegameIndex(xml, slot)
    slot = tonumber(slot)
    local i = 0
    while true do
        local base = string.format("saveUnitProfiles.savegames.savegame(%d)", i)
        local mappedSlot = getXMLInt(xml, base .. "#slot")
        if mappedSlot == nil then
            return nil, i
        end
        if tonumber(mappedSlot) == slot then
            return i, i + 1
        end
        i = i + 1
    end
end

function SaveUnitProfiles:saveProfileForSlot(slot, profile)
    if slot == nil or profile == nil or profile.name == nil then
        return false
    end

    self:ensureDefaultConfig()

    local path = self:getConfigPath()
    local xml = loadXMLFile("saveUnitProfiles", path)
    if xml == 0 or xml == nil then
        self:log("ERROR: Could not open config for writing: " .. tostring(path))
        return false
    end

    local profileIndex, nextProfileIndex = self:findProfileIndex(xml, profile.name)
    if profileIndex == nil then
        profileIndex = nextProfileIndex or 0
    end
    self:writeProfileValues(xml, profileIndex, profile)

    local savegameIndex, nextSavegameIndex = self:findSavegameIndex(xml, slot)
    if savegameIndex == nil then
        savegameIndex = nextSavegameIndex or 0
    end

    local base = string.format("saveUnitProfiles.savegames.savegame(%d)", savegameIndex)
    setXMLInt(xml, base .. "#slot", tonumber(slot))
    setXMLString(xml, base .. "#profile", tostring(profile.name))

    saveXMLFile(xml)
    delete(xml)

    self:loadConfig()
    return true
end


function SaveUnitProfiles:saveMappingForSlot(slot, profileName)
    if slot == nil or profileName == nil or tostring(profileName) == "" then
        return false
    end

    self:ensureDefaultConfig()

    local path = self:getConfigPath()
    local xml = loadXMLFile("saveUnitProfiles", path)
    if xml == 0 or xml == nil then
        self:log("ERROR: Could not open config for mapping write: " .. tostring(path))
        return false
    end

    local savegameIndex, nextSavegameIndex = self:findSavegameIndex(xml, slot)
    if savegameIndex == nil then
        savegameIndex = nextSavegameIndex or 0
    end

    local base = string.format("saveUnitProfiles.savegames.savegame(%d)", savegameIndex)
    setXMLInt(xml, base .. "#slot", tonumber(slot))
    setXMLString(xml, base .. "#profile", tostring(profileName))

    saveXMLFile(xml)
    delete(xml)

    self:loadConfig()
    return true
end

function SaveUnitProfiles:applyNamedProfileToActiveSave(profileName, reason)
    if self.config == nil then
        self:loadConfig()
    end

    profileName = suTrim(profileName)
    if profileName == nil or profileName == "" then
        self:showNotification("No unit profile selected", true)
        return false
    end

    local profile = self.config ~= nil and self.config.profiles[profileName] or nil
    if profile == nil then
        self:log("ERROR: No profile named '" .. tostring(profileName) .. "'.")
        self:showNotification("Unit profile not found: " .. tostring(profileName), true)
        return false
    end

    local slot = self:getCurrentSaveSlot()
    if slot == nil then
        self:log("ERROR: Could not detect active savegame slot; profile was not assigned.")
        self:showNotification("Could not assign unit profile: no savegame slot detected", true)
        return false
    end

    local saved = self:saveMappingForSlot(slot, profileName)
    if not saved then
        self:showNotification("Could not save unit profile mapping", true)
        return false
    end

    self.activeSlot = slot
    self.activeProfileName = profileName
    self:log(string.format("Assigned profile '%s' to savegame%d (%s)", tostring(profileName), tonumber(slot), tostring(reason or "manual")))

    -- Apply immediately so console/status/HUD reflect the selected preset at once,
    -- then apply again after the dialog/settings UI has finished its event cycle.
    self:applyProfile(profile, profileName, tostring(reason or "profile-dialog") .. "-immediate")
    self:scheduleProfileApply(profile, profileName, reason or "profile-dialog")
    return true
end

function SaveUnitProfiles:scheduleProfileApply(profile, profileName, reason)
    if profile == nil then
        return false
    end

    self.pendingApplyProfile = profile
    self.pendingApplyProfileName = profileName
    self.pendingApplyReason = reason or "deferred-profile-dialog"
    self.pendingApplyMs = 500
    -- Keep one delayed pass as a safety net after the Settings menu event cycle.
    -- Repeated passes created duplicate HUD messages and did not improve reliability.
    self.pendingApplyPasses = 1

    self:debugLog(string.format("Scheduled deferred apply for profile '%s' (%s)", tostring(profileName), tostring(reason)))
    return true
end

function SaveUnitProfiles:saveCurrentUnitsForActiveSave(reason, customProfileName)
    local slot = self:getCurrentSaveSlot()
    if slot == nil then
        self:log("ERROR: Could not detect active savegame slot; current unit settings were not saved.")
        self:showNotification("Could not save unit profile: no savegame slot detected", true)
        return false
    end

    local profileName = suTrim(customProfileName)
    if profileName == nil or profileName == "" then
        profileName = string.format("SAVEGAME_%d", tonumber(slot))
    end
    local profile = self:getCurrentUnitsAsProfile(profileName)
    if profile == nil then
        self:showNotification("Could not save unit profile: settings unavailable", true)
        return false
    end

    local ok = self:saveProfileForSlot(slot, profile)
    if ok then
        self.activeSlot = slot
        self.activeProfileName = profileName
        self.lastApplyOk = true

        -- Keep the in-memory config and native Units selector in sync immediately.
        -- Without this, the XML is correct but the selector can remain on the
        -- previously selected predefined profile until the next reload.
        self.config = self.config or { profiles = {}, savegames = {} }
        self.config.profiles = self.config.profiles or {}
        self.config.savegames = self.config.savegames or {}
        self.config.profiles[profileName] = profile
        self.config.savegames[tonumber(slot)] = profileName
        self:log(string.format("Saved current unit settings as profile '%s' for savegame%d (%s): money=%s (%s), miles=%s, fahrenheit=%s, acre=%s, use24HourTime=%s",
            profileName,
            tonumber(slot),
            tostring(reason or "manual"),
            tostring(profile.money),
            self:moneyName(profile.money),
            suBoolToString(profile.miles),
            suBoolToString(profile.fahrenheit),
            suBoolToString(profile.acre),
            suBoolToString(profile.use24HourTime)
        ))
        if self.settingsProfileSelector ~= nil then
            pcall(function() self:refreshSettingsRows() end)
        end
        self.applySelectedProfileAfterSettingsClose = true
        self:scheduleProfileApply(profile, profileName, "save-current-units")

        self:showNotification(string.format("Unit profile saved for savegame%d", tonumber(slot)), false)
        return true
    end

    self:showNotification("Could not save unit profile", true)
    return false
end



function SaveUnitProfiles:getProfileDisplayLabel(profile)
    if profile == nil then
        return "Unknown"
    end

    local currency = self:getCurrencyLabel(profile.money)

    local speed = profile.miles and "mph" or "km/h"
    local temp = profile.fahrenheit and "°F" or "°C"
    local area = profile.acre and "ac" or "ha"
    local clock = profile.use24HourTime and "24h" or "12h"

    return string.format("%s - %s, %s, %s, %s, %s", tostring(profile.name), currency, speed, temp, area, clock)
end

function SaveUnitProfiles:getSortedProfileNames()
    if self.config == nil then
        self:loadConfig()
    end

    local names = {}
    if self.config ~= nil and self.config.profiles ~= nil then
        for name, _ in pairs(self.config.profiles) do
            names[#names + 1] = name
        end
    end

    table.sort(names, function(a, b)
        local order = {US = 1, UK = 2, EU = 3, CA = 4}
        local oa = order[a] or 1000
        local ob = order[b] or 1000
        if oa == ob then
            return tostring(a) < tostring(b)
        end
        return oa < ob
    end)

    return names
end

function SaveUnitProfiles:getBuiltInProfileOrderMap()
    local order = {}
    for i, profile in ipairs(self.BUILT_IN_PROFILES or {}) do
        order[profile.name] = i
    end
    return order
end

function SaveUnitProfiles:getMaxMoneyUnit()
    local count = 0
    while self.MONEY_UNITS[count + 1] ~= nil do
        count = count + 1
    end
    return math.max(count, 3)
end

function SaveUnitProfiles:isProfileSupported(profile)
    if profile == nil then
        return false
    end

    local money = tonumber(profile.money) or 1
    return money >= 1 and money <= self:getMaxMoneyUnit()
end

function SaveUnitProfiles:isSavegameGeneratedProfileName(name)
    return string.match(tostring(name or ""), "^SAVEGAME_%d+$") ~= nil
end

function SaveUnitProfiles:getSelectableProfileNames()
    if self.config == nil then
        self:loadConfig()
    end

    local names = {}
    if self.config ~= nil and self.config.profiles ~= nil then
        for name, profile in pairs(self.config.profiles) do
            local profileName = tostring(name or "")
            local isGenerated = self:isSavegameGeneratedProfileName(profileName)
            if not isGenerated and self:isProfileSupported(profile) then
                names[#names + 1] = profileName
            end
        end

        -- Savegame-specific custom profiles are intentionally scoped to their own
        -- save slot. Show only the current savegame's generated profile, e.g.
        -- SAVEGAME_17, and hide generated profiles for other saves.
        local slot = self:getCurrentSaveSlot()
        if slot ~= nil then
            local currentGeneratedName = string.format("SAVEGAME_%d", tonumber(slot))
            local currentGeneratedProfile = self.config.profiles[currentGeneratedName]
            if currentGeneratedProfile ~= nil and self:isProfileSupported(currentGeneratedProfile) then
                names[#names + 1] = currentGeneratedName
            end
        end
    end

    local order = self:getBuiltInProfileOrderMap()
    table.sort(names, function(a, b)
        local aGenerated = self:isSavegameGeneratedProfileName(a)
        local bGenerated = self:isSavegameGeneratedProfileName(b)
        if aGenerated ~= bGenerated then
            return not aGenerated
        end

        local oa = order[a] or 10000
        local ob = order[b] or 10000
        if oa == ob then
            return tostring(a) < tostring(b)
        end
        return oa < ob
    end)

    return names
end

function SaveUnitProfiles:getCurrencyLabel(value)
    value = tonumber(value) or 1
    local unit = self:getMoneyUnitDefinition(value)
    if unit ~= nil then
        return unit.symbol or unit.iconSymbol or unit.name or tostring(value)
    end
    return self:moneyName(value)
end

function SaveUnitProfiles:getProfileFriendlyName(profile)
    if profile == nil then
        return "Unknown"
    end

    return self:getProfileFriendlyNameByName(profile.name)
end

function SaveUnitProfiles:getProfilePreviewText(profile, profileNameOverride)
    if profile == nil then
        return "No profile selected."
    end

    local friendlyProfileName = self:getProfileFriendlyNameByName(profileNameOverride or profile.name)

    local lines = {
        string.format("Profile: %s", friendlyProfileName),
        string.format("Currency: %s", self:getCurrencyLabel(profile.money)),
        string.format("Speed / distance: %s", profile.miles and "miles / mph" or "kilometres / km/h"),
        string.format("Temperature: %s", profile.fahrenheit and "Fahrenheit" or "Celsius"),
        string.format("Field area: %s", profile.acre and "acres" or "hectares"),
        string.format("Time format: %s", profile.use24HourTime and "24-hour" or "12-hour")
    }

    return table.concat(lines, "\n")
end

function SaveUnitProfiles:getProfileSelectorLabels(profileNames)
    local labels = {}
    for _, name in ipairs(profileNames or {}) do
        local profile = self.config ~= nil and self.config.profiles ~= nil and self.config.profiles[name] or nil
        labels[#labels + 1] = self:getProfileDisplayLabel(profile)
    end
    return labels
end

function SaveUnitProfiles:ensureProfileDialogLoaded()
    -- 1.2.0.0 build15: custom XML dialog path disabled.
    -- Builds 9 and 14 demonstrated that an incorrectly owned custom dialog can hard-hang FS25
    -- when opened from the Settings buttonbar. Keep the stable selector path active until
    -- the custom dialog can be rebuilt from a known-safe FS25 GUI pattern.
    self.profileDialogLoaded = true
    self:debugLog("Custom unit profile GUI disabled in this build; using safe selector fallback.")
    return false
end

function SaveUnitProfiles:openUnitProfileSelectorDialog()
    if self.config == nil then
        self:loadConfig()
    end

    local slot = self:getCurrentSaveSlot()
    if slot == nil then
        self:showNotification("Could not open unit profiles: no savegame slot detected", true)
        return false
    end

    local names = self:getSelectableProfileNames()
    if #names == 0 then
        self:showNotification("No supported unit profiles are available", true)
        return false
    end

    local selectedIndex = 1
    local currentName = self.config ~= nil and self.config.savegames ~= nil and self.config.savegames[slot] or nil
    if currentName ~= nil then
        for i, name in ipairs(names) do
            if name == currentName then
                selectedIndex = i
                break
            end
        end
    end

    if self:ensureProfileDialogLoaded() and SUProfileDialog ~= nil and SUProfileDialog.INSTANCE ~= nil then
        SUProfileDialog.INSTANCE:show(self, names, selectedIndex, slot)
        return true
    end

    self:openUnitProfileSelectorFallback(names, selectedIndex)
    return true
end

function SaveUnitProfiles:openUnitProfileSelectorFallback(profileNames, selectedIndex)
    selectedIndex = tonumber(selectedIndex or 1) or 1
    if selectedIndex < 1 then selectedIndex = 1 end
    if selectedIndex > #profileNames then selectedIndex = #profileNames end

    local name = profileNames[selectedIndex]
    local profile = self.config.profiles[name]
    local slot = self:getCurrentSaveSlot()
    local text = string.format("savegame%d\n\n%s", tonumber(slot or 0), self:getProfilePreviewText(profile))
    local buttons = {
        { label = "APPLY", action = "APPLY" },
        { label = "CUSTOM", action = "CUSTOM" },
        { label = "NEXT", action = "NEXT" },
        { label = "CANCEL", action = "CANCEL" }
    }

    local ok = self:showMultiActionDialog("Unit Profile", text, buttons, function(index, button)
        if button == nil or button.action == "CANCEL" then
            return
        elseif button.action == "APPLY" then
            SaveUnitProfiles:applyNamedProfileToActiveSave(name, "profile-selector-fallback")
        elseif button.action == "CUSTOM" then
            SaveUnitProfiles:openCustomProfileNameDialog()
        elseif button.action == "NEXT" then
            local nextIndex = selectedIndex + 1
            if nextIndex > #profileNames then nextIndex = 1 end
            SaveUnitProfiles:openUnitProfileSelectorFallback(profileNames, nextIndex)
        end
    end)

    if not ok then
        self:showNotification("Profile selector unavailable", true)
    end
end

function SaveUnitProfiles:parseDialogSelection(options, ...)
    local args = {...}
    local clickedOk = true
    local selectedIndex = nil
    local selectedText = nil

    for _, value in ipairs(args) do
        if type(value) == "boolean" then
            clickedOk = value
        elseif type(value) == "number" and selectedIndex == nil then
            selectedIndex = value
        elseif type(value) == "string" and selectedText == nil then
            selectedText = value
        end
    end

    if clickedOk == false then
        return nil, false
    end

    if selectedIndex ~= nil then
        selectedIndex = tonumber(selectedIndex)
        if selectedIndex == 0 and options[1] ~= nil then
            selectedIndex = 1
        end
        if selectedIndex ~= nil and options[selectedIndex] ~= nil then
            return selectedIndex, true
        end
        if selectedIndex ~= nil and options[selectedIndex + 1] ~= nil then
            return selectedIndex + 1, true
        end
    end

    if selectedText ~= nil then
        for i, label in ipairs(options) do
            if tostring(label) == tostring(selectedText) then
                return i, true
            end
        end
    end

    return 1, true
end

function SaveUnitProfiles:describeDialogArgs(...)
    local parts = {}
    local args = {...}
    for i, value in ipairs(args) do
        parts[#parts + 1] = string.format("%d:%s=%s", i, type(value), tostring(value))
    end
    return table.concat(parts, ", ")
end

function SaveUnitProfiles:parseMultiActionDialogResult(buttons, ...)
    local args = {...}
    local selectedIndex = nil
    local sawCancel = false

    for _, value in ipairs(args) do
        local valueType = type(value)
        if valueType == "number" then
            local numberValue = tonumber(value)
            if numberValue ~= nil then
                if buttons[numberValue] ~= nil then
                    selectedIndex = numberValue
                elseif buttons[numberValue + 1] ~= nil then
                    selectedIndex = numberValue + 1
                end
            end
        elseif valueType == "string" then
            local textValue = tostring(value)
            local textLower = string.lower(textValue)
            for i, button in ipairs(buttons) do
                if tostring(button.label) == textValue or tostring(button.action) == textValue then
                    selectedIndex = i
                    break
                end
            end

            if textLower == "cancel" or textLower == "back" or textLower == "no" or textLower == "menu_cancel" or textLower == "menu_back" then
                sawCancel = true
            end
        elseif valueType == "boolean" then
            if value == false then
                sawCancel = true
            end
        end
    end

    if selectedIndex ~= nil then
        return selectedIndex, true
    end

    if sawCancel then
        return nil, false
    end

    return nil, true
end

function SaveUnitProfiles:showMultiActionDialog(title, text, buttons, callback)
    if type(buttons) ~= "table" or #buttons == 0 then
        return false
    end

    -- Some FS25 builds/mod contexts do not expose g_gui:showMultiOptionDialog().
    -- Use the basegame MultiOptionDialog singleton directly, which is the actual dialog class.
    local dialog = nil
    if MultiOptionDialog ~= nil and MultiOptionDialog.INSTANCE ~= nil then
        dialog = MultiOptionDialog.INSTANCE
    end

    if dialog == nil then
        self:log("MultiOptionDialog.INSTANCE unavailable.")
        return false
    end

    if g_gui == nil or g_gui.showDialog == nil then
        self:log("g_gui:showDialog unavailable for MultiOptionDialog.")
        return false
    end

    if dialog.setText == nil or dialog.setButtonTexts == nil or dialog.setCallback == nil then
        self:log("MultiOptionDialog methods unavailable: setText=" .. tostring(dialog.setText ~= nil) .. ", setButtonTexts=" .. tostring(dialog.setButtonTexts ~= nil) .. ", setCallback=" .. tostring(dialog.setCallback ~= nil))
        return false
    end

    local b1 = buttons[1] ~= nil and buttons[1].label or nil
    local b2 = buttons[2] ~= nil and buttons[2].label or nil
    local b3 = buttons[3] ~= nil and buttons[3].label or nil
    local b4 = buttons[4] ~= nil and buttons[4].label or nil

    self.suPendingDialogButtons = buttons
    self.suPendingDialogCallback = callback

    dialog:setCallback(function(...)
        local pendingButtons = SaveUnitProfiles.suPendingDialogButtons or buttons
        local selectedIndex, accepted = SaveUnitProfiles:parseMultiActionDialogResult(pendingButtons, ...)
        SaveUnitProfiles:debugLog("MultiOptionDialog callback args: " .. SaveUnitProfiles:describeDialogArgs(...))

        if selectedIndex == nil and accepted then
            SaveUnitProfiles:log("MultiOptionDialog returned no usable selection; args=" .. SaveUnitProfiles:describeDialogArgs(...))
            SaveUnitProfiles:showNotification("Could not read profile dialog selection", true)
            return
        end

        if not accepted then
            SaveUnitProfiles:debugLog("Unit profile dialog cancelled.")
            return
        end

        if SaveUnitProfiles.suPendingDialogCallback ~= nil then
            SaveUnitProfiles.suPendingDialogCallback(selectedIndex, pendingButtons[selectedIndex])
        end
    end)

    if dialog.setDialogType ~= nil and DialogElement ~= nil and DialogElement.TYPE_INFO ~= nil then
        dialog:setDialogType(DialogElement.TYPE_INFO)
    end

    if dialog.setTitle ~= nil then
        dialog:setTitle(tostring(title or "Unit Profile"))
    end

    if dialog.setButtonTexts ~= nil then
        dialog:setButtonTexts(b1, b2, b3, b4)
    end

    if dialog.setButtonActions ~= nil then
        dialog:setButtonActions(InputAction.MENU_ACTIVATE, InputAction.MENU_ACCEPT, InputAction.MENU_BACK, InputAction.MENU_CANCEL)
    end

    if dialog.setText ~= nil then
        dialog:setText(tostring(text or ""))
    end

    if dialog.setDisableOpenSound ~= nil then
        dialog:setDisableOpenSound(false)
    end

    g_gui:showDialog("MultiOptionDialog")
    return true
end

function SaveUnitProfiles:openUnitProfileDialog()
    if self.config == nil then
        self:loadConfig()
    end

    local slot = self:getCurrentSaveSlot()
    if slot == nil then
        self:showNotification("Could not open unit profiles: no savegame slot detected", true)
        return
    end

    local text = string.format("Choose a preset unit profile for savegame%d, or open More for Canada and custom options.", tonumber(slot))
    local buttons = {
        { label = "UK", action = "UK" },
        { label = "US", action = "US" },
        { label = "EU", action = "EU" },
        { label = "MORE", action = "MORE" }
    }

    local ok = self:showMultiActionDialog("Unit Profile", text, buttons, function(index, button)
        if button == nil then
            return
        end
        if button.action == "MORE" then
            SaveUnitProfiles:openUnitProfileMoreDialog()
        else
            SaveUnitProfiles:applyNamedProfileToActiveSave(button.action, "profile-dialog")
        end
    end)

    if not ok then
        self:log("MultiOptionDialog unavailable; saving current units with default savegame profile name.")
        self:showNotification("Profile dialog unavailable; saved current units instead", true)
        self:saveCurrentUnitsForActiveSave("dialog-fallback")
    end
end

function SaveUnitProfiles:openUnitProfileMoreDialog()
    local slot = self:getCurrentSaveSlot()
    if slot == nil then
        self:showNotification("Could not open unit profiles: no savegame slot detected", true)
        return
    end

    local text = string.format("Additional unit profile options for savegame%d.", tonumber(slot))
    local buttons = {
        { label = "CA", action = "CA" },
        { label = "CUSTOM", action = "CUSTOM" },
        { label = "CURRENT", action = "CURRENT" },
        { label = "BACK", action = "BACK" }
    }

    local ok = self:showMultiActionDialog("Unit Profile", text, buttons, function(index, button)
        if button == nil then
            return
        end
        if button.action == "CA" then
            SaveUnitProfiles:applyNamedProfileToActiveSave("CA", "profile-dialog")
        elseif button.action == "CUSTOM" then
            SaveUnitProfiles:openCustomProfileNameDialog()
        elseif button.action == "CURRENT" then
            SaveUnitProfiles:saveCurrentUnitsForActiveSave("profile-dialog-current")
        elseif button.action == "BACK" then
            SaveUnitProfiles:openUnitProfileDialog()
        end
    end)

    if not ok then
        self:saveCurrentUnitsForActiveSave("dialog-fallback")
    end
end


-- 1.2.0.0 build25: Unit Profile selection is injected directly into the native
-- Settings UI. The old dialog entry point now just nudges the player to the
-- settings row rather than opening a separate dialog.
function SaveUnitProfiles:openUnitProfileDialog()
    self:injectSettingsRows()
    self:refreshSettingsRows()
    self:showNotification("Use the Unit Profile row in Settings to choose and apply a profile", false)
end

function SaveUnitProfiles:onUnitProfileDialogClosed(profileNames, options, ...)
    -- Kept for compatibility with earlier 1.2.0.0 test builds.
    local selectedIndex, clickedOk = self:parseDialogSelection(options, ...)
    if not clickedOk or selectedIndex == nil then
        self:debugLog("Unit profile dialog cancelled.")
        return
    end

    if selectedIndex > #profileNames then
        self:openCustomProfileNameDialog()
        return
    end

    local profileName = profileNames[selectedIndex]
    self:applyNamedProfileToActiveSave(profileName, "profile-dialog")
end

function SaveUnitProfiles:parseTextDialogValue(defaultValue, ...)
    local args = {...}
    local clickedOk = true
    local textValue = nil

    for _, value in ipairs(args) do
        if type(value) == "boolean" then
            clickedOk = value
        elseif type(value) == "string" and textValue == nil then
            textValue = value
        end
    end

    if clickedOk == false then
        return nil, false
    end

    textValue = suTrim(textValue)
    if textValue == nil or textValue == "" then
        textValue = defaultValue
    end

    return textValue, true
end

function SaveUnitProfiles:openCustomProfileNameDialog()
    local slot = self:getCurrentSaveSlot()
    if slot == nil then
        self:showNotification("Could not save custom profile: no savegame slot detected", true)
        return
    end

    -- Custom profiles are intentionally deterministic and savegame-specific.
    -- Do not ask the player for a global custom name; use SAVEGAME_## so the
    -- profile belongs unambiguously to the active save slot.
    local defaultName = string.format("SAVEGAME_%d", tonumber(slot))
    self:saveCurrentUnitsForActiveSave("save-current-units-row", defaultName)
end

function SaveUnitProfiles:onCustomProfileNameDialogClosed(defaultName, ...)
    local profileName, clickedOk = self:parseTextDialogValue(defaultName, ...)
    if not clickedOk or profileName == nil or profileName == "" then
        self:debugLog("Custom unit profile name dialog cancelled.")
        return
    end

    self:saveCurrentUnitsForActiveSave("custom-profile-dialog", profileName)
end

function SaveUnitProfiles:uiDescribeButtonInfo(buttonInfo)
    if type(buttonInfo) ~= "table" then
        return tostring(type(buttonInfo))
    end

    local parts = {}
    for i, info in ipairs(buttonInfo) do
        if type(info) == "table" then
            parts[#parts + 1] = string.format("%d:%s/%s", i, tostring(info.text), tostring(info.inputAction))
        else
            parts[#parts + 1] = string.format("%d:%s", i, tostring(info))
        end
    end

    return string.format("table count=%d [%s]", #buttonInfo, table.concat(parts, ", "))
end

function SaveUnitProfiles:uiObjectClassHint(obj)
    if obj == nil or type(obj) ~= "table" then
        return tostring(type(obj))
    end

    local hints = {
        rawget(obj, "className"),
        rawget(obj, "profile"),
        rawget(obj, "name"),
        rawget(obj, "id"),
        rawget(obj, "pageName"),
        rawget(obj, "screenName")
    }

    for _, value in ipairs(hints) do
        if value ~= nil then
            return tostring(value)
        end
    end

    local mt = getmetatable(obj)
    if mt ~= nil then
        if mt.__name ~= nil then
            return tostring(mt.__name)
        end
        if mt.__index ~= nil and type(mt.__index) == "table" then
            local idx = mt.__index
            for _, value in ipairs({rawget(idx, "className"), rawget(idx, "name"), rawget(idx, "profile")}) do
                if value ~= nil then
                    return tostring(value)
                end
            end
        end
    end

    return "table"
end

function SaveUnitProfiles:uiContainsGeneralHint(value, depth, visited)
    if value == nil or depth > 3 then
        return false, nil
    end

    local valueType = type(value)
    if valueType == "string" then
        local lower = string.lower(value)
        if string.find(lower, "general") ~= nil or string.find(lower, "settingsgeneral") ~= nil then
            return true, value
        end
        return false, nil
    elseif valueType ~= "table" then
        return false, nil
    end

    visited = visited or {}
    if visited[value] then
        return false, nil
    end
    visited[value] = true

    local hint = self:uiObjectClassHint(value)
    if hint ~= nil then
        local lower = string.lower(tostring(hint))
        if string.find(lower, "general") ~= nil or string.find(lower, "settingsgeneral") ~= nil then
            return true, tostring(hint)
        end
    end

    local fields = {
        "currentPage", "currentPageName", "selectedPage", "selectedPageName", "activeFrame", "currentFrame",
        "pageFrame", "pageName", "name", "id", "className", "profile", "target", "parent"
    }

    for _, fieldName in ipairs(fields) do
        local ok, child = pcall(function()
            return value[fieldName]
        end)
        if ok and child ~= nil then
            local found, foundHint = self:uiContainsGeneralHint(child, depth + 1, visited)
            if found then
                return true, string.format("%s.%s", tostring(fieldName), tostring(foundHint))
            end
        end
    end

    return false, nil
end


function SaveUnitProfiles:getProfileSelectorSimpleLabels(profileNames)
    local labels = {}
    for _, name in ipairs(profileNames or {}) do
        -- Built-in profiles use their compact two-character operational code.
        -- Savegame-specific custom profiles use their deterministic generated name,
        -- e.g. SAVEGAME_17, so the player can see that the profile belongs to this save.
        labels[#labels + 1] = tostring(name)
    end
    return labels
end

function SaveUnitProfiles:getCurrentMappedProfileIndex(profileNames)
    local slot = self:getCurrentSaveSlot()
    local currentName = nil
    if slot ~= nil and self.config ~= nil and self.config.savegames ~= nil then
        currentName = self.config.savegames[slot]
    end
    if currentName == nil then
        currentName = self.activeProfileName
    end
    for i, name in ipairs(profileNames or {}) do
        if name == currentName then
            return i
        end
    end
    return 1
end

function SaveUnitProfiles:findSettingsTemplateElements(scrollPanel)
    local sectionHeader, multiOptionElement, buttonElement = nil, nil, nil
    if scrollPanel == nil or type(scrollPanel.elements) ~= "table" then
        return nil, nil, nil
    end
    for _, element in pairs(scrollPanel.elements) do
        if element ~= nil then
            if element.name == "sectionHeader" and sectionHeader == nil and element.clone ~= nil then
                sectionHeader = element
            end
            if element.typeName == "Bitmap" and type(element.elements) == "table" then
                local child = element.elements[1]
                if child ~= nil then
                    if child.typeName == "MultiTextOption" and multiOptionElement == nil and element.clone ~= nil then
                        multiOptionElement = element
                    elseif child.typeName == "Button" and buttonElement == nil and element.clone ~= nil then
                        buttonElement = element
                    end
                end
            end
        end
        if sectionHeader ~= nil and multiOptionElement ~= nil and buttonElement ~= nil then
            break
        end
    end
    return sectionHeader, multiOptionElement, buttonElement
end

function SaveUnitProfiles:setSettingsRowLabel(row, label)
    if row == nil or type(row.elements) ~= "table" then
        return
    end
    for _, element in pairs(row.elements) do
        if element ~= nil and element.typeName == "Text" and element.setText ~= nil then
            element:setText(tostring(label or ""))
            element.id = nil
            return
        end
    end
end

function SaveUnitProfiles:findChildByType(row, typeName)
    if row == nil or type(row.elements) ~= "table" then
        return nil
    end
    for _, element in pairs(row.elements) do
        if element ~= nil and element.typeName == typeName then
            return element
        end
    end
    return nil
end

function SaveUnitProfiles:insertClonedSettingsRowBefore(row, parent, beforeElement)
    if row == nil or parent == nil or type(parent.elements) ~= "table" then
        return false
    end

    if row.parent ~= nil and row.parent.removeElement ~= nil then
        pcall(function() row.parent:removeElement(row) end)
    end

    local insertIndex = nil
    for i, element in ipairs(parent.elements) do
        if element == beforeElement then
            insertIndex = i
            break
        end
    end

    if insertIndex == nil then
        table.insert(parent.elements, row)
    else
        table.insert(parent.elements, insertIndex, row)
    end
    row.parent = parent
    return true
end

function SaveUnitProfiles:getNativeMoneyUnitElement(settingsPage)
    if settingsPage ~= nil then
        return settingsPage.multiMoneyUnit or settingsPage.moneyElement
    end
    if g_inGameMenu ~= nil then
        return g_inGameMenu.multiMoneyUnit or g_inGameMenu.moneyElement
    end
    return nil
end

function SaveUnitProfiles:updateProfileSelectorTooltip(profileName)
    if self.settingsProfileSelector == nil then
        return false
    end
    local profile = nil
    if self.config ~= nil and self.config.profiles ~= nil then
        profile = self.config.profiles[profileName]
    end

    local text = self:getProfilePreviewText(profile, profileName)

    -- FS25 settings controls use their first child text element as the right-hand
    -- help/tooltip pane source. Also keep common tooltip fields updated in case
    -- the focused control refreshes from them rather than the child text element.
    local updated = false
    self.settingsProfileSelector.toolTipText = text
    self.settingsProfileSelector.tooltipText = text
    self.settingsProfileSelector.helpText = text

    if self.settingsProfileSelector.elements ~= nil and self.settingsProfileSelector.elements[1] ~= nil and self.settingsProfileSelector.elements[1].setText ~= nil then
        self.settingsProfileSelector.elements[1]:setText(text)
        updated = true
    end
    return updated
end

function SaveUnitProfiles:injectSettingsRows()
    if self.settingsRowsInjected == true then
        return true
    end

    if self.config == nil then
        self:loadConfig()
    end

    local settingsPage = self:getPageSettings()
    if settingsPage == nil then
        return false
    end

    -- Build28: inject directly into General Settings > Units by cloning the native
    -- Money Unit row. This keeps SaveUnitProfiles standalone and native-looking.
    local moneyElement = self:getNativeMoneyUnitElement(settingsPage)
    local moneyRow = moneyElement ~= nil and moneyElement.parent or nil
    local unitsParent = moneyRow ~= nil and moneyRow.parent or nil

    if moneyElement == nil or moneyRow == nil or unitsParent == nil then
        self:log("Unit Profile settings row injection skipped: native Money Unit row not found")
        return false
    end

    local profileRow = moneyRow:clone(settingsPage)
    if profileRow == nil then
        self:log("Unit Profile settings row injection skipped: could not clone Money Unit row")
        return false
    end

    profileRow.id = "sup_unitProfileRow"
    self:setSettingsRowLabel(profileRow, "Unit Profile")

    local profileSelector = self:findChildByType(profileRow, "MultiTextOption")
    if profileSelector == nil then
        profileSelector = self:findChildByType(profileRow, "CheckedOptionElement")
    end
    if profileSelector == nil then
        self:log("Unit Profile settings row injection skipped: profile selector control not found")
        return false
    end

    profileSelector.id = "sup_unitProfileSelector"
    profileSelector.focusId = nil
    profileSelector.onClickCallback = function(_, state, button)
        SaveUnitProfiles:onSettingsProfileSelectorChanged(state, button)
    end

    self:insertClonedSettingsRowBefore(profileRow, unitsParent, moneyRow)

    self.settingsProfileRow = profileRow
    self.settingsProfileSelector = profileSelector

    -- Optional native button row for custom profiles. Use a known button template from
    -- Game Settings if available, but keep the selector itself independent of this.
    local buttonTemplate = nil
    local gameLayout = settingsPage.gameSettingsLayout
    if gameLayout ~= nil then
        local _, _, foundButtonTemplate = self:findSettingsTemplateElements(gameLayout)
        buttonTemplate = foundButtonTemplate
    end

    if buttonTemplate ~= nil then
        local customRow = buttonTemplate:clone(settingsPage)
        if customRow ~= nil then
            customRow.id = "sup_saveCustomProfileRow"
            self:setSettingsRowLabel(customRow, "Save Current Units")
            local button = self:findChildByType(customRow, "Button")
            if button ~= nil then
                button.id = "sup_saveCustomProfileButton"
                if button.setText ~= nil then button:setText("SAVE CUSTOM") end
                if button.applyProfile ~= nil then button:applyProfile("settingsButton") end
                button.onClickCallback = function()
                    SaveUnitProfiles:openCustomProfileNameDialog()
                end
                if button.elements ~= nil and button.elements[1] ~= nil and button.elements[1].setText ~= nil then
                    button.elements[1]:setText("Save the current currency and unit settings as a custom profile for this savegame.")
                end
                self.settingsCustomButton = button
            end
            self:insertClonedSettingsRowBefore(customRow, unitsParent, moneyRow)
            self.settingsCustomRow = customRow
        end
    else
        self:debugLog("Unit Profile custom save row skipped: no native button template found")
    end

    self.settingsRowsInjected = true
    self:refreshSettingsRows()

    if unitsParent.invalidateLayout ~= nil then
        pcall(function() unitsParent:invalidateLayout() end)
    end
    if unitsParent.updateAbsolutePosition ~= nil then
        pcall(function() unitsParent:updateAbsolutePosition() end)
    end
    if unitsParent.invalidateChildren ~= nil then
        pcall(function() unitsParent:invalidateChildren() end)
    end

    local currentGui = FocusManager ~= nil and FocusManager.currentGui or nil
    if FocusManager ~= nil then
        pcall(function()
            FocusManager:setGui("ingameMenuSettings")
            FocusManager:loadElementFromCustomValues(profileSelector)
            if self.settingsCustomButton ~= nil then
                FocusManager:loadElementFromCustomValues(self.settingsCustomButton)
            end
            if currentGui ~= nil then
                FocusManager:setGui(currentGui)
            end
        end)
    end

    self:log("Unit Profile selector injected into General Settings > Units.")
    return true
end

function SaveUnitProfiles:refreshSettingsRows()
    if self.settingsProfileSelector == nil then
        return false
    end
    if self.config == nil then
        self:loadConfig()
    end

    local names = self:getSelectableProfileNames()
    if #names == 0 then
        names = {"US"}
    end
    local labels = self:getProfileSelectorSimpleLabels(names)
    local index = self:getCurrentMappedProfileIndex(names)

    self.settingsProfileNames = names
    self.settingsSelectedProfileIndex = index

    if self.settingsProfileSelector.setTexts ~= nil then
        self.settingsProfileSelector:setTexts(labels)
    end
    if self.settingsProfileSelector.setState ~= nil then
        pcall(function() self.settingsProfileSelector:setState(index, false) end)
    end

    self:updateProfileSelectorTooltip(names[index])
    return true
end

function SaveUnitProfiles:onSettingsProfileSelectorChanged(state, button)
    local newState = tonumber(state)
    if newState == nil and type(button) == "number" then
        newState = tonumber(button)
    end
    if newState == nil and button ~= nil and type(button.state) == "number" then
        newState = tonumber(button.state)
    end
    if newState == nil then
        newState = self.settingsSelectedProfileIndex or 1
    end

    local names = self.settingsProfileNames or self:getSelectableProfileNames()
    if newState < 1 then newState = 1 end
    if newState > #names then newState = #names end
    self.settingsSelectedProfileIndex = newState

    local name = names[newState]
    self:updateProfileSelectorTooltip(name)

    if name == nil then
        self:showNotification("No unit profile selected", true)
        return false
    end

    -- Selecting a profile is the apply action. No separate APPLY row is needed.
    local ok = self:applyNamedProfileToActiveSave(name, "settings-units-profile-selector")
    if ok then
        self.applySelectedProfileAfterSettingsClose = true
    end
    self:refreshSettingsRows()
    return ok
end

function SaveUnitProfiles:applySettingsSelectedProfile()
    -- Kept as a console/internal compatibility wrapper. The native Units selector
    -- now applies immediately when the profile is selected.
    return self:onSettingsProfileSelectorChanged(self.settingsSelectedProfileIndex or 1)
end

function SaveUnitProfiles:shouldAddSaveUnitsButton(frame, className)
    -- SettingsGeneralFrame is the actual General Settings subframe when it is directly queried.
    if tostring(className) == "SettingsGeneralFrame" then
        return true, "direct SettingsGeneralFrame"
    end

    -- InGameMenuSettingsFrame owns the visible shared settings buttonbar in FS25.
    -- FS25 exposes the settings screen as one shared settings frame, so this button is intentionally
    -- available from the settings interface rather than trying to bind it to a hidden subpage.
    if tostring(className) == "InGameMenuSettingsFrame" then
        return true, "shared settings frame"
    end

    -- Keep the older defensive hooks enabled, but log their context in debug mode.
    return true, "defensive settings hook"
end

function SaveUnitProfiles:debugFrameContext(className, frame, buttonInfo)
    if not self.debug then
        return
    end

    self:log(string.format("Buttonbar context for %s: frameHint=%s, buttonInfo=%s",
        tostring(className),
        tostring(self:uiObjectClassHint(frame)),
        tostring(self:uiDescribeButtonInfo(buttonInfo))
    ))

    local fields = {
        "currentPage", "currentPageId", "currentPageName", "currentPageElement",
        "selectedPage", "selectedPageId", "selectedPageName", "activeFrame", "currentFrame", "pageFrame",
        "currentPageIndex", "selectedPageIndex", "pageIndex", "selectedIndex", "tabIndex", "currentTab", "selectedTab",
        "generalSettingsFrame", "settingsGeneralFrame", "pageFrames", "pages", "frames", "target", "parent"
    }

    for _, fieldName in ipairs(fields) do
        local ok, value = pcall(function()
            if frame ~= nil then
                return frame[fieldName]
            end
            return nil
        end)
        if ok and value ~= nil then
            if type(value) == "table" then
                self:log(string.format("  %s.%s = %s", tostring(className), tostring(fieldName), tostring(self:uiObjectClassHint(value))))
            else
                self:log(string.format("  %s.%s = %s", tostring(className), tostring(fieldName), tostring(value)))
            end
        end
    end

    local found, hint = self:uiContainsGeneralHint(frame, 0, {})
    self:log(string.format("  %s general-page hint: %s (%s)", tostring(className), tostring(found), tostring(hint)))
end

function SaveUnitProfiles:getSaveUnitsButtonInfo()
    -- Build25 injects native settings rows instead of adding a bottom buttonbar action.
    -- Keep this function for compatibility with older hook code, but do not add a button.
    return nil
end

function SaveUnitProfiles:appendSaveUnitsButtonInfo(buttonInfo)
    if buttonInfo == nil then
        return buttonInfo
    end

    for _, info in pairs(buttonInfo) do
        if info ~= nil and info.suSaveUnitProfilesButton == true then
            return buttonInfo
        end
    end

    local saveButton = self:getSaveUnitsButtonInfo()
    if saveButton ~= nil then
        table.insert(buttonInfo, saveButton)
    end

    return buttonInfo
end

function SaveUnitProfiles:tryInjectSettingsFrameButton(frame)
    if frame == nil then
        return
    end

    -- Build25: rows are injected into the native Settings layout.
    self:injectSettingsRows()
    self:refreshSettingsRows()

    if type(frame.menuButtonInfo) == "table" then
        self:appendSaveUnitsButtonInfo(frame.menuButtonInfo)
    end

    if frame.setMenuButtonInfoDirty ~= nil then
        frame:setMenuButtonInfoDirty()
    elseif frame.parent ~= nil and frame.parent.setMenuButtonInfoDirty ~= nil then
        frame.parent:setMenuButtonInfoDirty()
    elseif frame.target ~= nil and frame.target.setMenuButtonInfoDirty ~= nil then
        frame.target:setMenuButtonInfoDirty()
    end
end

function SaveUnitProfiles:patchSettingsFrameClass(classRef, className)
    if classRef == nil then
        return false
    end

    local patched = false

    if classRef.getMenuButtonInfo ~= nil and classRef.suOriginalGetMenuButtonInfo == nil then
        classRef.suOriginalGetMenuButtonInfo = classRef.getMenuButtonInfo
        classRef.getMenuButtonInfo = function(frame, ...)
            local info = classRef.suOriginalGetMenuButtonInfo(frame, ...)
            local shouldAdd, reason = SaveUnitProfiles:shouldAddSaveUnitsButton(frame, className)
            SaveUnitProfiles:debugLog("getMenuButtonInfo called for " .. tostring(className) .. "; shouldAdd=" .. tostring(shouldAdd) .. "; reason=" .. tostring(reason) .. "; info=" .. tostring(type(info)) .. "; count=" .. tostring(type(info) == "table" and #info or "n/a"))
            SaveUnitProfiles:debugFrameContext(className, frame, info)
            if shouldAdd then
                return SaveUnitProfiles:appendSaveUnitsButtonInfo(info)
            end
            return info
        end
        patched = true
        self:debugLog("Patched getMenuButtonInfo for " .. tostring(className))
    end

    if Utils ~= nil and Utils.appendedFunction ~= nil and classRef.onFrameOpen ~= nil and classRef.suOnFrameOpenPatched ~= true then
        classRef.onFrameOpen = Utils.appendedFunction(classRef.onFrameOpen, function(frame)
            SaveUnitProfiles:tryInjectSettingsFrameButton(frame)
        end)
        classRef.suOnFrameOpenPatched = true
        patched = true
        self:debugLog("Patched onFrameOpen for " .. tostring(className))
    end

    return patched
end

function SaveUnitProfiles:onSettingsFrameOpenForRows(frame)
    self.settingsRowsInjected = self.settingsRowsInjected or false
    if self.settingsRowsInjected ~= true then
        self:injectSettingsRows()
    else
        self:refreshSettingsRows()
    end
end

function SaveUnitProfiles:installUiHooks()
    if self.uiHooksInstalled then
        return
    end

    local patched = false

    -- The exact class name is kept defensive across FS25 builds and UI changes.
    patched = self:patchSettingsFrameClass(_G.InGameMenuGeneralSettingsFrame, "InGameMenuGeneralSettingsFrame") or patched
    patched = self:patchSettingsFrameClass(_G.GeneralSettingsFrame, "GeneralSettingsFrame") or patched
    patched = self:patchSettingsFrameClass(_G.SettingsGeneralFrame, "SettingsGeneralFrame") or patched
    patched = self:patchSettingsFrameClass(_G.InGameMenuSettingsFrame, "InGameMenuSettingsFrame") or patched

    if patched then
        self:log("Settings save button hook installed.")
    else
        self:log("Settings save button hook not installed; use suSaveCurrent as a fallback.")
    end

    self.uiHooksInstalled = true
end

function SaveUnitProfiles:getPageSettings()
    if g_inGameMenu ~= nil and g_inGameMenu.pageSettings ~= nil then
        return g_inGameMenu.pageSettings
    end

    if g_gui ~= nil and g_gui.currentGui ~= nil then
        local gui = g_gui.currentGui
        if gui.target ~= nil and gui.target.pageSettings ~= nil then
            return gui.target.pageSettings
        end
    end

    return nil
end

function SaveUnitProfiles:setCheckedElement(element, checked, label)
    if element == nil then
        return false, tostring(label or "element") .. "=nil"
    end

    local ok = false
    local detail = {}

    if element.setIsChecked ~= nil then
        local callOk, err = pcall(function()
            element:setIsChecked(checked == true, true)
        end)
        detail[#detail + 1] = "setIsChecked=" .. tostring(callOk and "ok" or ("error:" .. tostring(err)))
        ok = ok or callOk
    end

    if element.setState ~= nil and CheckedOptionElement ~= nil then
        local state = checked == true and CheckedOptionElement.STATE_CHECKED or CheckedOptionElement.STATE_UNCHECKED
        if state ~= nil then
            local callOk, err = pcall(function()
                element:setState(state, true)
            end)
            detail[#detail + 1] = "setState=" .. tostring(callOk and tostring(state) or ("error:" .. tostring(err)))
            ok = ok or callOk
        end
    end

    return ok, tostring(label or "element") .. "[" .. table.concat(detail, ",") .. "]"
end

function SaveUnitProfiles:setMoneyUiElement(element, money)
    if element == nil then
        return false, "moneyElement=nil"
    end

    if element.setState ~= nil then
        local ok, err = pcall(function()
            element:setState(tonumber(money) or 1, true)
        end)
        return ok, "moneyElement.setState=" .. tostring(ok and tostring(money) or ("error:" .. tostring(err)))
    end

    return false, "moneyElement.setState=unavailable"
end

function SaveUnitProfiles:refreshRuntimeAndSettingsUi(profile, profileName, reason)
    if profile == nil then
        return "runtimeRefresh=skipped:nil-profile"
    end

    local details = {}
    local money = tonumber(profile.money) or 1

    self.currentRuntimeMoneyUnit = money
    self:extendMoneyUnitSelectorTexts()

    if g_i18n ~= nil then
        if g_i18n.setMoneyUnit ~= nil then
            local ok, err = pcall(function()
                g_i18n:setMoneyUnit(money)
            end)
            details[#details + 1] = "g_i18n.setMoneyUnit=" .. tostring(ok and "ok" or ("error:" .. tostring(err)))
        end

        local mt = getmetatable(g_i18n)
        if mt ~= nil and mt.__index ~= nil and mt.__index.setMoneyUnit ~= nil then
            local ok, err = pcall(function()
                mt.__index.setMoneyUnit(g_i18n, money)
            end)
            details[#details + 1] = "g_i18n.__index.setMoneyUnit=" .. tostring(ok and "ok" or ("error:" .. tostring(err)))
        end
    end

    if g_currentMission ~= nil and g_currentMission.setMoneyUnit ~= nil then
        local ok, err = pcall(function()
            g_currentMission:setMoneyUnit(money)
        end)
        details[#details + 1] = "g_currentMission.setMoneyUnit=" .. tostring(ok and "ok" or ("error:" .. tostring(err)))
    end

    if g_inGameMenu ~= nil then
        if g_inGameMenu.multiMoneyUnit ~= nil then
            local ok, detail = self:setMoneyUiElement(g_inGameMenu.multiMoneyUnit, money)
            details[#details + 1] = "g_inGameMenu." .. detail
        end
    end

    local pageSettings = self:getPageSettings()
    if pageSettings ~= nil then
        if pageSettings.multiMoneyUnit ~= nil then
            local ok, detail = self:setMoneyUiElement(pageSettings.multiMoneyUnit, money)
            details[#details + 1] = "pageSettings." .. detail
        end

        local ok1, detail1 = self:setCheckedElement(pageSettings.checkUseMiles, profile.miles, "checkUseMiles")
        local ok2, detail2 = self:setCheckedElement(pageSettings.checkUseFahrenheit, profile.fahrenheit, "checkUseFahrenheit")
        local ok3, detail3 = self:setCheckedElement(pageSettings.checkUseAcre, profile.acre, "checkUseAcre")
        details[#details + 1] = detail1
        details[#details + 1] = detail2
        details[#details + 1] = detail3

        if pageSettings.checkTimeFormat ~= nil then
            local ok4, detail4 = self:setCheckedElement(pageSettings.checkTimeFormat, profile.use24HourTime, "checkTimeFormat")
            details[#details + 1] = detail4
        end

        if pageSettings.checkHourFormat ~= nil then
            local ok5, detail5 = self:setCheckedElement(pageSettings.checkHourFormat, profile.use24HourTime, "checkHourFormat")
            details[#details + 1] = detail5
        end

        if pageSettings.setMenuButtonInfoDirty ~= nil then
            local ok, err = pcall(function()
                pageSettings:setMenuButtonInfoDirty()
            end)
            details[#details + 1] = "pageSettings.setMenuButtonInfoDirty=" .. tostring(ok and "ok" or ("error:" .. tostring(err)))
        end
    else
        details[#details + 1] = "pageSettings=nil"
    end

    return table.concat(details, ";")
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

    local runtimeDetail = self:refreshRuntimeAndSettingsUi(profile, profileName, reason)
    results[#results + 1] = "runtime/UI [" .. tostring(runtimeDetail) .. "]"

    -- The live game/UI refresh path is authoritative for visible currency and unit changes.
    -- Some GameSettings keys do not return true from setValue even when the setting is valid,
    -- so verify one more time after the runtime refresh before deciding whether to warn.
    local verifiedAfterRuntime = true
    verifiedAfterRuntime = verifiedAfterRuntime and self:settingsValueMatches(self:getGameSetting("moneyUnit"), tonumber(profile.money))
    verifiedAfterRuntime = verifiedAfterRuntime and self:settingsValueMatches(self:getGameSetting("useMiles"), profile.miles)
    verifiedAfterRuntime = verifiedAfterRuntime and self:settingsValueMatches(self:getGameSetting("useFahrenheit"), profile.fahrenheit)
    verifiedAfterRuntime = verifiedAfterRuntime and self:settingsValueMatches(self:getGameSetting("useAcre"), profile.acre)
    verifiedAfterRuntime = verifiedAfterRuntime and self:settingsValueMatches(self:getGameSetting("use24HourTime"), profile.use24HourTime)

    if verifiedAfterRuntime then
        allOk = true
    end

    self.activeProfileName = profileName or profile.name
    self.lastApplyOk = allOk

    self:log(string.format("Applied profile '%s' for savegame%s (%s): %s",
        tostring(self.activeProfileName),
        self.activeSlot ~= nil and tostring(self.activeSlot) or "?",
        tostring(reason or "manual"),
        table.concat(results, "; ")
    ))

    -- Quiet apply behaviour for the native Settings selector.
    -- Successful profile changes are already visible in the Settings UI and persisted to XML,
    -- so do not show HUD notifications while cycling profiles or when the Settings UI closes.
    -- Keep a warning notification only if the apply path reports a genuine problem.
    local reasonText = tostring(reason or "")
    local suppressNotification = string.find(reasonText, "deferred", 1, true) ~= nil
        or string.find(reasonText, "reapply", 1, true) ~= nil
        or string.find(reasonText, "settings%-close", 1, false) ~= nil
        or string.find(reasonText, "settings", 1, true) ~= nil

    if not allOk then
        self:log("WARNING: One or more settings did not report success. Check whether FS25 recognises all setting names in this build.")
        if not suppressNotification then
            self:showNotification(string.format("Unit profile partly applied: %s", tostring(self.activeProfileName)), true)
        end
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
    self:installIntegratedCurrencySupport()
    self.activeSlot = self:getCurrentSaveSlot()
    self.elapsedMs = 0
    self.hasApplied = false
    self:registerConsoleCommands()
    self.settingsRowsInjected = false
    self.settingsProfileSelector = nil
    self:installUiHooks()
end

function SaveUnitProfiles:isSettingsGuiActive()
    if g_gui == nil then
        return false
    end

    local currentGui = g_gui.currentGui
    local function containsSettings(value)
        value = tostring(value or ""):lower()
        return string.find(value, "settings", 1, true) ~= nil or string.find(value, "ingamemenu", 1, true) ~= nil
    end

    if currentGui ~= nil then
        if containsSettings(currentGui.name) or containsSettings(currentGui.id) or containsSettings(currentGui.profile) then
            return true
        end
        local target = currentGui.target
        if target ~= nil then
            if containsSettings(target.name) or containsSettings(target.id) or containsSettings(target.profile) or containsSettings(target.className) then
                return true
            end
            if target.pageSettings ~= nil or target.pageSettingsGeneral ~= nil then
                return true
            end
        end
    end

    if FocusManager ~= nil then
        if containsSettings(FocusManager.currentGui) or containsSettings(FocusManager.currentGuiName) then
            return true
        end
    end

    return false
end

function SaveUnitProfiles:scheduleMappedProfileApply(reason)
    if self.config == nil then
        self:loadConfig()
    end

    local slot = self:getCurrentSaveSlot()
    if slot == nil or self.config == nil or self.config.savegames == nil then
        return false
    end

    local profileName = self.config.savegames[tonumber(slot)]
    local profile = profileName ~= nil and self.config.profiles ~= nil and self.config.profiles[profileName] or nil
    if profile == nil then
        return false
    end

    self:scheduleProfileApply(profile, profileName, reason or "post-settings-close")
    return true
end

function SaveUnitProfiles:update(dt)
    local settingsActiveNow = self:isSettingsGuiActive()
    if self.wasSettingsGuiActive == true and settingsActiveNow == false and self.applySelectedProfileAfterSettingsClose == true then
        self.applySelectedProfileAfterSettingsClose = false
        self:scheduleMappedProfileApply("settings-close-reapply")
        self:debugLog("Settings UI closed after profile selection; scheduled mapped profile reapply")
    end
    self.wasSettingsGuiActive = settingsActiveNow

    if self.settingsRowsInjected ~= true then
        self:injectSettingsRows()
    end

    if self.pendingApplyProfile ~= nil then
        self.pendingApplyMs = (self.pendingApplyMs or 0) - dt
        if self.pendingApplyMs <= 0 then
            local profile = self.pendingApplyProfile
            local profileName = self.pendingApplyProfileName
            local reason = self.pendingApplyReason or "deferred-profile-dialog"
            local passes = tonumber(self.pendingApplyPasses or 1) or 1

            self:applyProfile(profile, profileName, reason)

            passes = passes - 1
            if passes > 0 then
                self.pendingApplyPasses = passes
                self.pendingApplyMs = 700
                self:debugLog(string.format("Queued one more deferred apply pass for profile '%s'", tostring(profileName)))
            else
                self.pendingApplyProfile = nil
                self.pendingApplyProfileName = nil
                self.pendingApplyReason = nil
                self.pendingApplyMs = nil
                self.pendingApplyPasses = nil
            end
        end
    end

    if not self.hasApplied then
        self.elapsedMs = self.elapsedMs + dt
        if self.elapsedMs >= self.applyDelayMs then
            self.hasApplied = true
            self:applyForCurrentSave("delayed-load")
        end
    end
end

function SaveUnitProfiles:deleteMap()
    self.hasApplied = false
    self.config = nil
    self.activeSlot = nil
    self.activeProfileName = nil
    self.settingsRowsInjected = false
    self.settingsProfileSelector = nil
    self.settingsProfileNames = nil
    self.settingsSelectedProfileIndex = nil
    self.wasSettingsGuiActive = false
    self.applySelectedProfileAfterSettingsClose = false
end


function SaveUnitProfiles:uiValueSummary(value)
    local valueType = type(value)
    if value == nil then
        return "nil"
    elseif valueType == "string" or valueType == "number" or valueType == "boolean" then
        return tostring(value)
    elseif valueType == "table" then
        local name = rawget(value, "name") or rawget(value, "id") or rawget(value, "className") or rawget(value, "profile")
        if name ~= nil then
            return string.format("table(%s)", tostring(name))
        end
        return "table"
    elseif valueType == "function" then
        return "function"
    end
    return valueType
end

function SaveUnitProfiles:uiProbeClass(className)
    local classRef = _G[className]
    if classRef == nil then
        self:log("  class " .. tostring(className) .. ": nil")
        return
    end

    self:log(string.format("  class %s: %s, getMenuButtonInfo=%s, onFrameOpen=%s, setMenuButtonInfoDirty=%s, menuButtonInfo=%s",
        tostring(className),
        type(classRef),
        tostring(classRef.getMenuButtonInfo ~= nil),
        tostring(classRef.onFrameOpen ~= nil),
        tostring(classRef.setMenuButtonInfoDirty ~= nil),
        tostring(type(classRef.menuButtonInfo))
    ))
end

function SaveUnitProfiles:uiProbeKnownFields(label, obj)
    if obj == nil then
        self:log("  " .. tostring(label) .. ": nil")
        return
    end

    self:log("  " .. tostring(label) .. ": " .. self:uiValueSummary(obj))

    local fields = {
        "name", "id", "className", "currentPage", "currentPageId", "currentPageName", "currentPageElement",
        "selectedPage", "selectedPageId", "selectedPageName", "activeFrame", "currentFrame", "pageFrame",
        "menuButtonInfo", "buttonInfo", "buttons", "pageFrames", "pages", "frames", "target", "parent"
    }

    for _, fieldName in ipairs(fields) do
        local ok, value = pcall(function()
            return obj[fieldName]
        end)
        if ok and value ~= nil then
            if type(value) == "table" and (fieldName == "menuButtonInfo" or fieldName == "buttonInfo" or fieldName == "buttons") then
                self:log(string.format("    .%s: table count=%d", tostring(fieldName), #value))
            else
                self:log(string.format("    .%s: %s", tostring(fieldName), self:uiValueSummary(value)))
            end
        end
    end
end

function SaveUnitProfiles:markButtonInfoDirty(owner)
    if owner == nil then
        return
    end

    local candidates = {}
    local function addCandidate(candidate)
        if candidate ~= nil then
            candidates[#candidates + 1] = candidate
        end
    end

    addCandidate(owner)
    addCandidate(owner.parent)
    addCandidate(owner.target)
    addCandidate(owner.rootElement)
    addCandidate(owner.pageController)
    if g_currentMission ~= nil then
        addCandidate(g_currentMission.inGameMenu)
    end

    for i = 1, #candidates do
        local candidate = candidates[i]
        if candidate ~= nil and candidate.setMenuButtonInfoDirty ~= nil then
            candidate:setMenuButtonInfoDirty()
            self:debugLog("setMenuButtonInfoDirty called on " .. self:uiValueSummary(candidate))
        end
    end
end

function SaveUnitProfiles:scanUiButtonTargets(root, path, depth, visited, results)
    if root == nil or type(root) ~= "table" or depth > 5 then
        return
    end

    visited = visited or {}
    results = results or {}

    if visited[root] then
        return
    end
    visited[root] = true

    local hasMenuButtonInfo = type(rawget(root, "menuButtonInfo")) == "table"
    local hasButtonInfo = type(rawget(root, "buttonInfo")) == "table"
    local hasGetMenuButtonInfo = rawget(root, "getMenuButtonInfo") ~= nil
    local hasDirty = rawget(root, "setMenuButtonInfoDirty") ~= nil

    if hasMenuButtonInfo or hasButtonInfo or hasGetMenuButtonInfo or hasDirty then
        results[#results + 1] = {
            object = root,
            path = path,
            hasMenuButtonInfo = hasMenuButtonInfo,
            menuButtonCount = hasMenuButtonInfo and #(root.menuButtonInfo) or nil,
            hasButtonInfo = hasButtonInfo,
            buttonInfoCount = hasButtonInfo and #(root.buttonInfo) or nil,
            hasGetMenuButtonInfo = hasGetMenuButtonInfo,
            hasDirty = hasDirty,
            summary = self:uiValueSummary(root)
        }
    end

    if #results > 120 then
        return
    end

    for key, value in pairs(root) do
        if type(value) == "table" then
            local keyText = tostring(key)
            if keyText ~= "__index" and keyText ~= "metatable" then
                self:scanUiButtonTargets(value, path .. "." .. keyText, depth + 1, visited, results)
                if #results > 120 then
                    return
                end
            end
        end
    end
end


function SaveUnitProfiles:probeSettingsMenuObject(label, obj)
    if obj == nil or type(obj) ~= "table" then
        return
    end

    self:log("  Settings menu candidate: " .. tostring(label) .. " summary=" .. tostring(self:uiValueSummary(obj)))

    local scalarKeys = {}
    local tableKeys = {}

    for key, value in pairs(obj) do
        local keyText = tostring(key)
        local valueType = type(value)
        if valueType == "string" or valueType == "number" or valueType == "boolean" then
            scalarKeys[#scalarKeys + 1] = keyText .. "=" .. tostring(value)
        elseif valueType == "table" then
            local countText = ""
            local okCount, countVal = pcall(function() return #value end)
            if okCount and countVal ~= nil and countVal > 0 then
                countText = ", #=" .. tostring(countVal)
            end
            tableKeys[#tableKeys + 1] = keyText .. "=" .. tostring(self:uiValueSummary(value)) .. countText
        elseif valueType == "function" then
            -- Skip functions to keep log readable.
        else
            scalarKeys[#scalarKeys + 1] = keyText .. "=" .. valueType
        end
    end

    table.sort(scalarKeys)
    table.sort(tableKeys)

    local maxScalar = math.min(#scalarKeys, 80)
    for i = 1, maxScalar do
        self:log("    scalar " .. scalarKeys[i])
    end
    if #scalarKeys > maxScalar then
        self:log("    ... " .. tostring(#scalarKeys - maxScalar) .. " additional scalar field(s) omitted")
    end

    local maxTables = math.min(#tableKeys, 120)
    for i = 1, maxTables do
        self:log("    table " .. tableKeys[i])
    end
    if #tableKeys > maxTables then
        self:log("    ... " .. tostring(#tableKeys - maxTables) .. " additional table field(s) omitted")
    end

    -- Focused known-field dump for likely page/tab owners.
    local focusedFields = {
        "currentPage", "currentPageId", "currentPageName", "currentPageElement", "currentPageIndex",
        "selectedPage", "selectedPageId", "selectedPageName", "selectedPageIndex",
        "activeFrame", "currentFrame", "pageFrame", "pageFrames", "pages", "frames",
        "currentTab", "selectedTab", "tabIndex", "selectedIndex", "settingsFrame", "generalSettingsFrame", "settingsGeneralFrame"
    }

    for _, fieldName in ipairs(focusedFields) do
        local ok, value = pcall(function() return obj[fieldName] end)
        if ok and value ~= nil then
            self:log("    focused ." .. tostring(fieldName) .. " = " .. tostring(self:uiValueSummary(value)))
            if type(value) == "table" then
                local subCount = 0
                for subKey, subValue in pairs(value) do
                    subCount = subCount + 1
                    if subCount <= 30 then
                        self:log("      ." .. tostring(fieldName) .. "." .. tostring(subKey) .. " = " .. tostring(self:uiValueSummary(subValue)))
                    end
                end
                if subCount > 30 then
                    self:log("      ... " .. tostring(subCount - 30) .. " additional subfield(s) omitted")
                end
            end
        end
    end
end

function SaveUnitProfiles:probeSettingsMenuCandidates(results)
    self:log("  Settings menu focused probe:")
    local found = 0

    if results ~= nil then
        for _, item in ipairs(results) do
            local summary = tostring(item.summary or "")
            local path = tostring(item.path or "")
            if string.find(summary, "ingameMenuSettings") ~= nil or string.find(path, "ingameMenuSettings") ~= nil or string.find(path, "lightsProfileElement") ~= nil then
                found = found + 1
                self:probeSettingsMenuObject(path, item.object)
            end
        end
    end

    if found == 0 and g_gui ~= nil and g_gui.currentGui ~= nil then
        -- Fallback: traverse shallowly for likely settings owner objects.
        local visited = {}
        local function walk(obj, path, depth)
            if obj == nil or type(obj) ~= "table" or depth > 5 or visited[obj] then
                return
            end
            visited[obj] = true
            local summary = tostring(SaveUnitProfiles:uiValueSummary(obj))
            if string.find(summary, "ingameMenuSettings") ~= nil or string.find(path, "lightsProfileElement") ~= nil then
                found = found + 1
                SaveUnitProfiles:probeSettingsMenuObject(path, obj)
                return
            end
            for key, value in pairs(obj) do
                if type(value) == "table" then
                    walk(value, path .. "." .. tostring(key), depth + 1)
                end
            end
        end
        walk(g_gui.currentGui, "g_gui.currentGui", 0)
    end

    if found == 0 then
        self:log("    No focused settings menu candidate found.")
    end
end

function SaveUnitProfiles:tryInjectButtonIntoUiObject(target)
    if target == nil or type(target) ~= "table" then
        return false
    end

    local injected = false

    if type(target.menuButtonInfo) == "table" then
        local before = #target.menuButtonInfo
        self:appendSaveUnitsButtonInfo(target.menuButtonInfo)
        injected = #target.menuButtonInfo > before or injected
    end

    if type(target.buttonInfo) == "table" then
        local before = #target.buttonInfo
        self:appendSaveUnitsButtonInfo(target.buttonInfo)
        injected = #target.buttonInfo > before or injected
    end

    if injected then
        self:markButtonInfoDirty(target)
    end

    return injected
end

function SaveUnitProfiles:consoleUiProbe(mode)
    mode = suTrim(mode)
    local doInject = mode == "inject" or mode == "button" or mode == "save"

    self:log("UI Probe" .. (doInject and " + injection attempt" or ""))
    self:log("  activeSlot: " .. tostring(self:getCurrentSaveSlot()))

    if InputAction ~= nil then
        self:log(string.format("  InputAction: MENU_EXTRA_1=%s, MENU_EXTRA_2=%s, MENU_ACTIVATE=%s, MENU_ACCEPT=%s, MENU_CANCEL=%s",
            tostring(InputAction.MENU_EXTRA_1),
            tostring(InputAction.MENU_EXTRA_2),
            tostring(InputAction.MENU_ACTIVATE),
            tostring(InputAction.MENU_ACCEPT),
            tostring(InputAction.MENU_CANCEL)
        ))
    else
        self:log("  InputAction: nil")
    end

    self:log("  Class checks:")
    self:uiProbeClass("InGameMenuGeneralSettingsFrame")
    self:uiProbeClass("GeneralSettingsFrame")
    self:uiProbeClass("SettingsGeneralFrame")
    self:uiProbeClass("InGameMenuSettingsFrame")
    self:uiProbeClass("TabbedMenu")
    self:uiProbeClass("InGameMenu")

    local menu = nil
    if g_currentMission ~= nil then
        menu = g_currentMission.inGameMenu
    end

    self:uiProbeKnownFields("g_currentMission.inGameMenu", menu)

    if g_gui ~= nil then
        self:uiProbeKnownFields("g_gui", g_gui)
        self:uiProbeKnownFields("g_gui.currentGui", g_gui.currentGui)
        self:uiProbeKnownFields("g_gui.currentGuiTarget", g_gui.currentGuiTarget)
        self:uiProbeKnownFields("g_gui.currentDialog", g_gui.currentDialog)
    else
        self:log("  g_gui: nil")
    end

    if menu ~= nil then
        self:uiProbeKnownFields("inGameMenu.currentPage", menu.currentPage)
        self:uiProbeKnownFields("inGameMenu.selectedPage", menu.selectedPage)
        self:uiProbeKnownFields("inGameMenu.activeFrame", menu.activeFrame)
        self:uiProbeKnownFields("inGameMenu.currentFrame", menu.currentFrame)
        self:uiProbeKnownFields("inGameMenu.pageFrame", menu.pageFrame)
    end

    local results = {}
    self:scanUiButtonTargets(menu, "inGameMenu", 0, {}, results)
    if g_gui ~= nil then
        self:scanUiButtonTargets(g_gui.currentGui, "g_gui.currentGui", 0, {}, results)
        self:scanUiButtonTargets(g_gui.currentGuiTarget, "g_gui.currentGuiTarget", 0, {}, results)
        self:scanUiButtonTargets(g_gui.currentDialog, "g_gui.currentDialog", 0, {}, results)
    end

    self:probeSettingsMenuCandidates(results)

    self:log(string.format("  Button target scan: %d candidate(s)", #results))
    local injectedCount = 0
    local maxLog = math.min(#results, 60)
    for i = 1, maxLog do
        local item = results[i]
        local didInject = false
        if doInject and (item.hasMenuButtonInfo or item.hasButtonInfo) then
            didInject = self:tryInjectButtonIntoUiObject(item.object)
            if didInject then
                injectedCount = injectedCount + 1
            end
        end
        self:log(string.format("    [%02d] %s summary=%s menuButtonInfo=%s(%s) buttonInfo=%s(%s) getMenuButtonInfo=%s dirty=%s injected=%s",
            i,
            tostring(item.path),
            tostring(item.summary),
            tostring(item.hasMenuButtonInfo),
            tostring(item.menuButtonCount),
            tostring(item.hasButtonInfo),
            tostring(item.buttonInfoCount),
            tostring(item.hasGetMenuButtonInfo),
            tostring(item.hasDirty),
            tostring(didInject)
        ))
    end

    if #results > maxLog then
        self:log(string.format("    ... %d additional candidate(s) omitted from log", #results - maxLog))
    end

    if doInject then
        self:log("  Injection attempts that changed a button table: " .. tostring(injectedCount))
        if injectedCount == 0 then
            self:log("  No live button table was changed. The active settings page may be using a generated/parent-owned buttonbar.")
        end
    else
        self:log("  Run suUiProbe inject while the General Settings page is open to try live button injection.")
    end
end

function SaveUnitProfiles:registerConsoleCommands()
    if self.consoleCommandsRegistered then
        return
    end

    addConsoleCommand("suStatus", "SaveUnitProfiles: print active save/profile and current game settings", "consoleStatus", self)
    addConsoleCommand("suReload", "SaveUnitProfiles: reload XML config", "consoleReload", self)
    addConsoleCommand("suApply", "SaveUnitProfiles: apply mapped profile, or named profile: suApply UK", "consoleApply", self)
    addConsoleCommand("suProfile", "SaveUnitProfiles: assign/apply profile to active savegame: suProfile UK", "consoleProfile", self)
    addConsoleCommand("suDebug", "SaveUnitProfiles: toggle debug logging: suDebug on|off", "consoleDebug", self)
    addConsoleCommand("suSaveCurrent", "SaveUnitProfiles: save current game unit settings for this savegame, optionally named: suSaveCurrent MyProfile", "consoleSaveCurrent", self)

    self.consoleCommandsRegistered = true
end

function SaveUnitProfiles:consoleStatus()
    local slot = self:getCurrentSaveSlot()
    self:log("Status")
    self:log("  config: " .. self:getConfigPath())
    self:log("  activeSlot: " .. tostring(slot))
    self:log("  activeProfile: " .. tostring(self.activeProfileName))
    self:log("  lastApplyOk: " .. tostring(self.lastApplyOk))

    if g_gameSettings ~= nil then
        local moneyUnit = self:getGameSetting("moneyUnit")
        self:log("  moneyUnit: " .. tostring(moneyUnit) .. " (" .. self:moneyName(moneyUnit) .. ")")
        self:log("  useMiles: " .. suBoolToString(self:getGameSetting("useMiles")))
        self:log("  useFahrenheit: " .. suBoolToString(self:getGameSetting("useFahrenheit")))
        self:log("  useAcre: " .. suBoolToString(self:getGameSetting("useAcre")))
        self:log("  use24HourTime: " .. suBoolToString(self:getGameSetting("use24HourTime")))
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

function SaveUnitProfiles:consoleProfile(profileName)
    profileName = suTrim(profileName)
    if profileName == nil or profileName == "" then
        self:log("Usage: suProfile <profileName>")
        return
    end
    self:applyNamedProfileToActiveSave(profileName, "manual-console-profile")
end

function SaveUnitProfiles:consoleSaveCurrent(profileName)
    self:saveCurrentUnitsForActiveSave("manual-console", profileName)
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
