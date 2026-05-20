--[[
    FS25_SaveUnitProfiles
    ModVersion: 1.1.0.0
    BuildTag: 20260520.6

    Purpose:
      Apply money/unit display preferences from a per-save XML profile.

    Notes:
      - moneyUnit: 1 = Euro, 2 = Dollar, 3 = Pounds
      - Settings are global FS profile settings, so this mod applies them when a save is loaded.
      - Runtime UI refresh behaviour depends on how FS25 caches unit displays in each screen.
]]

SaveUnitProfiles = {}
SaveUnitProfiles.MOD_NAME = g_currentModName or "FS25_SaveUnitProfiles"
SaveUnitProfiles.VERSION = "1.1.0.0"
SaveUnitProfiles.BUILD_TAG = "20260520.6"
SaveUnitProfiles.config = nil
SaveUnitProfiles.activeSlot = nil
SaveUnitProfiles.activeProfileName = nil
SaveUnitProfiles.lastApplyOk = false
SaveUnitProfiles.hasApplied = false
SaveUnitProfiles.applyDelayMs = 1500
SaveUnitProfiles.elapsedMs = 0
SaveUnitProfiles.debug = false

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

function SaveUnitProfiles:getCurrentUnitsAsProfile(profileName)
    if g_gameSettings == nil or g_gameSettings.getValue == nil then
        self:log("ERROR: g_gameSettings is unavailable; cannot read current unit settings.")
        return nil
    end

    return {
        name = profileName,
        money = tonumber(g_gameSettings:getValue("moneyUnit")),
        miles = g_gameSettings:getValue("useMiles"),
        fahrenheit = g_gameSettings:getValue("useFahrenheit"),
        acre = g_gameSettings:getValue("useAcre"),
        use24HourTime = g_gameSettings:getValue("use24HourTime")
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

function SaveUnitProfiles:saveCurrentUnitsForActiveSave(reason)
    local slot = self:getCurrentSaveSlot()
    if slot == nil then
        self:log("ERROR: Could not detect active savegame slot; current unit settings were not saved.")
        self:showNotification("Could not save unit profile: no savegame slot detected", true)
        return false
    end

    local profileName = string.format("SAVEGAME_%d", tonumber(slot))
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
        self:showNotification(string.format("Unit profile saved for savegame%d", tonumber(slot)), false)
        return true
    end

    self:showNotification("Could not save unit profile", true)
    return false
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
    local action = nil
    if InputAction ~= nil then
        action = InputAction.MENU_EXTRA_1 or InputAction.MENU_EXTRA_2 or InputAction.MENU_ACTIVATE
    end

    if action == nil then
        return nil
    end

    return {
        inputAction = action,
        text = "SAVE UNITS",
        callback = function()
            SaveUnitProfiles:saveCurrentUnitsForActiveSave("general-settings-button")
        end,
        suSaveUnitProfilesButton = true
    }
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

    if allOk then
        self:showNotification(string.format("Unit profile applied: %s", tostring(self.activeProfileName)), false)
    else
        self:log("WARNING: One or more settings did not report success. Check whether FS25 recognises all setting names in this build.")
        self:showNotification(string.format("Unit profile partly applied: %s", tostring(self.activeProfileName)), true)
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
    self:installUiHooks()
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
    addConsoleCommand("suDebug", "SaveUnitProfiles: toggle debug logging: suDebug on|off", "consoleDebug", self)
    addConsoleCommand("suSaveCurrent", "SaveUnitProfiles: save current game unit settings for this savegame", "consoleSaveCurrent", self)

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

function SaveUnitProfiles:consoleSaveCurrent()
    self:saveCurrentUnitsForActiveSave("manual-console")
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
