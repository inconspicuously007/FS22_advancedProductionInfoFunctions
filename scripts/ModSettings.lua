ModSettings = {}
ModSettings.name = g_currentModName
ModSettings.modDir = g_currentModDirectory

source(g_currentModDirectory .. "scripts/ModSettingsEvents.lua")

function ModSettings.init()
	ModSettings.localDir = getUserProfileAppPath() .. "modSettings/" .. ModSettings.name ..  "/"	
	createFolder(ModSettings.localDir)	
	ModSettings.localFilePath = ModSettings.localDir.."settings.xml"
	ModSettings.userFilePath = ModSettings.localDir.."userSettings.xml"
	ModSettings.globalFilePath = ModSettings.localDir.."globalSettings.xml"
	ModSettings.settingsFilePath = ModSettings.modDir.."settings/settings.xml"
	ModSettings.globalSettings = {}
	ModSettings.userSettings = {}
	ModSettings.defaultSettings = {}
	ModSettings.checkIsGameHost = true
	ModSettings.defaultSettings.palletLimitMin = 300
	ModSettings.defaultSettings.palletLimitMax = 9999
	ModSettings.defaultSettings.prodPointLimitMin = 60
	ModSettings.defaultSettings.prodPointLimitMax = 120
	ModSettings.defaultSettings.husbandryLimitMin = 10
	ModSettings.defaultSettings.husbandryLimitMax = 32
	
	--- set defaults to prevent issues with saving without changing values before
	ModSettings.globalSettings.palletLimit = 300
	ModSettings.globalSettings.productionPointLimit = 60
	ModSettings.globalSettings.husbandryLimit = 10	
	ModSettings.userSettings.fillLevelColored = 2
	ModSettings.userSettings.productionListState = 3
	
	ModSettings:checkIsHost()
	
	--- load globalSettings	 
	ModSettings:loadGlobalSettingsXML()
	
	--- load userSettings ---
	Mission00.loadMission00Finished = Utils.appendedFunction(Mission00.loadMission00Finished, ModSettings.loadUserSettings)
	--- load globalSettings on join
	FSBaseMission.onConnectionFinishedLoading = Utils.appendedFunction(FSBaseMission.onConnectionFinishedLoading, ModSettings.loadSettingsFromServer)	
	--- init gui
	InGameMenuGeneralSettingsFrame.onFrameOpen = Utils.appendedFunction(InGameMenuGeneralSettingsFrame.onFrameOpen, ModSettings.initGuiGeneralSettings)
	--- save userSettings
	InGameMenuGeneralSettingsFrame.onFrameClose = Utils.appendedFunction(InGameMenuGeneralSettingsFrame.onFrameClose, ModSettings.saveUserSettings)	
	
	--FSCareerMissionInfo.saveToXMLFile = Utils.appendedFunction(FSCareerMissionInfo.saveToXMLFile, ModSettings.saveSettings)
	--InGameMenuGameSettingsFrame.onFrameOpen = Utils.appendedFunction(InGameMenuGameSettingsFrame.onFrameOpen, ModSettings.initGui)
	
	--SP start: 		g_server = table, g_client = table, g_dedicatedServer = nil, g_server.netIsRunning = false
	--HMP start:		g_server = table, g_client = table, g_dedicatedServer = nil, g_server.netIsRunning = true
	--Dedicated start: 	g_server = table, g_client = table, g_dedicatedServer = table
	--JMP:				g_server = nil, g_client = table, g_dedicatedServer = nil
	
	--printf("Debug: g_server: '%s' -- g_client: '%s' -- g_dedicatedServer: '%s'", g_server, g_client, g_dedicatedServer)
	--DebugUtil.printTableRecursively(g_server,"_",0,9)
end

function ModSettings:checkIsHost()	
	if g_server == nil and g_client ~= nil and g_dedicatedServer == nil then
		ModSettings.checkIsGameHost = false	 		
	end
end

function ModSettings:loadUserSettings()	
	--print("loadUserSettings")
	local xmlFile = XMLFile.loadIfExists("localXmlFile", ModSettings.userFilePath, ModSettings.name)
	if xmlFile ~= nil then
		ModSettings.userSettings.fillLevelColored = xmlFile:getInt(ModSettings.name .. ".userSettings.fillLevelColored", 2)
		ModSettings.userSettings.productionListState = xmlFile:getInt(ModSettings.name .. ".userSettings.productionListState", 3)		
		xmlFile:delete()		
	end
	ModSettings:saveUserSettings()
	--DebugUtil.printTableRecursively(ModSettings.globalSettings,"_",0,2)	
end

function ModSettings:loadGlobalSettingsXML()
	--if (g_server ~= nil and g_server.netIsRunning) or g_dedicatedServer ~= nil then
	if ModSettings.checkIsGameHost then
		--print("ModSettings:loadGlobalSettingsXML()")
		local palletLimit = nil
		local productionPointLimit = nil
		local loadDefaults = true
		
		local xmlFile = XMLFile.loadIfExists("localXmlFile", ModSettings.globalFilePath, ModSettings.name)
		
		if xmlFile ~= nil then			
			if xmlFile:hasProperty(ModSettings.name .. ".globalSettings.palletLimit") and xmlFile:hasProperty(ModSettings.name .. ".globalSettings.productionPointLimit") then
				ModSettings.globalSettings.palletLimit = xmlFile:getInt(ModSettings.name .. ".globalSettings.palletLimit", ModSettings.defaultSettings.palletLimitMin)
				ModSettings.globalSettings.productionPointLimit = xmlFile:getInt(ModSettings.name .. ".globalSettings.productionPointLimit", ModSettings.defaultSettings.prodPointLimitMin)				
				ModSettings.globalSettings.husbandryLimit = xmlFile:getInt(ModSettings.name .. ".globalSettings.husbandryLimit", ModSettings.defaultSettings.husbandryLimitMin)
				loadDefaults = false
			end		
		end
		
		if loadDefaults then			
			local xmlDefaultsFile = XMLFile.loadIfExists("settingsDefaultsXmlFile", ModSettings.settingsFilePath, "globalSettings")			
			if xmlDefaultsFile ~= nil then
				ModSettings.globalSettings.palletLimit = xmlDefaultsFile:getInt("globalSettings.palletLimit", ModSettings.defaultSettings.palletLimitMin)
				ModSettings.globalSettings.productionPointLimit = xmlDefaultsFile:getInt("globalSettings.productionPointLimit", ModSettings.defaultSettings.prodPointLimitMin)				
				ModSettings.globalSettings.husbandryLimit = xmlDefaultsFile:getInt("globalSettings.husbandryLimit", ModSettings.defaultSettings.husbandryLimitMin)
				xmlDefaultsFile:delete()				
			end
		end
		
		if ModSettings.globalSettings.palletLimit ~= nil and ModSettings.globalSettings.palletLimit > ModSettings.defaultSettings.palletLimitMin then			
			if ModSettings.globalSettings.palletLimit >= ModSettings.defaultSettings.palletLimitMax then 
				ModSettings.globalSettings.palletLimit = math.huge 
			end
			SlotSystem.NUM_OBJECT_LIMITS = {
				[SlotSystem.LIMITED_OBJECT_BALE] = {
					[PlatformId.WIN] = math.huge,
					[PlatformId.MAC] = math.huge,
					[PlatformId.PS4] = 200,
					[PlatformId.PS5] = 200,
					[PlatformId.XBOX_ONE] = 200,
					[PlatformId.XBOX_SERIES] = 200,
					[PlatformId.IOS] = 100,
					[PlatformId.ANDROID] = 100,
					[PlatformId.SWITCH] = 100,
					[PlatformId.GGP] = 200
				},
				[SlotSystem.LIMITED_OBJECT_PALLET] = {
					[PlatformId.WIN] = ModSettings.globalSettings.palletLimit,
					[PlatformId.MAC] = ModSettings.globalSettings.palletLimit,
					[PlatformId.PS4] = 75,
					[PlatformId.PS5] = 150,
					[PlatformId.XBOX_ONE] = 75,
					[PlatformId.XBOX_SERIES] = 150,
					[PlatformId.IOS] = 50,
					[PlatformId.ANDROID] = 50,
					[PlatformId.SWITCH] = 50,
					[PlatformId.GGP] = 50
				}
			}		
		end
		
		if ModSettings.globalSettings.productionPointLimit ~= nil and ModSettings.globalSettings.productionPointLimit > ModSettings.defaultSettings.prodPointLimitMin then			
			if ModSettings.globalSettings.productionPointLimit > ModSettings.defaultSettings.prodPointLimitMax then 
				ModSettings.globalSettings.productionPointLimit = ModSettings.defaultSettings.prodPointLimitMax 
			end	
			ProductionChainManager.NUM_MAX_PRODUCTION_POINTS = ModSettings.globalSettings.productionPointLimit
		end
		
		if ModSettings.globalSettings.husbandryLimit ~= nil and ModSettings.globalSettings.husbandryLimit > ModSettings.defaultSettings.husbandryLimitMin then			
			if ModSettings.globalSettings.husbandryLimit > ModSettings.defaultSettings.husbandryLimitMax then 
				ModSettings.globalSettings.husbandryLimit = ModSettings.defaultSettings.husbandryLimitMax 
			end	
			HusbandrySystem.GAME_LIMIT = ModSettings.globalSettings.husbandryLimit
		end		
		ModSettings:saveGlobalSettings()		
	end	
end

function ModSettings:loadSettingsFromServer()
	--print("loadSettingsFromServer")
	g_client:getServerConnection():sendEvent(GlobalModSettingsEvent.new())
end

function ModSettings:saveGlobalSettings()	
	if ModSettings.checkIsGameHost then
		local xmlFile = XMLFile.create("localXmlFile", ModSettings.globalFilePath, ModSettings.name)	
		if xmlFile ~= nil then
			if ModSettings.globalSettings ~= nil then
				xmlFile:setInt(ModSettings.name .. ".globalSettings.palletLimit", ModSettings.globalSettings.palletLimit)
				xmlFile:setInt(ModSettings.name .. ".globalSettings.productionPointLimit", ModSettings.globalSettings.productionPointLimit)
				xmlFile:setInt(ModSettings.name .. ".globalSettings.husbandryLimit", ModSettings.globalSettings.husbandryLimit)
				xmlFile:save()
				xmlFile:delete()
			end
		end		
	end
end

function ModSettings:saveUserSettings()
	if g_dedicatedServer == nil then
		local xmlFile = XMLFile.create("localXmlFile", ModSettings.userFilePath, ModSettings.name)	
		if xmlFile ~= nil then
			if ModSettings.userSettings ~= nil then
				xmlFile:setInt(ModSettings.name .. ".userSettings.fillLevelColored", ModSettings.userSettings.fillLevelColored)
				xmlFile:setInt(ModSettings.name .. ".userSettings.productionListState", ModSettings.userSettings.productionListState)
				xmlFile:save()
				xmlFile:delete()
			end
		end
	end
end

function ModSettings:initGuiGeneralSettings()
	if self.modSettingsLoaded == nil or self.modSettingsLoaded == false then
		local txtElements = {}
		local menuTitle = TextElement.new()
		menuTitle:applyProfile("settingsMenuSubtitle", true)
		menuTitle:setText(g_i18n:getText("modsetting_ui_title"))

		self.boxLayout:addElement(menuTitle)
	
		local newElement = self.multiMoneyUnit:clone()
		newElement:setTexts(txtElements)
        newElement.target = ModSettings.userSettings
        newElement.id = "fillLevelColored"
        newElement.onClickCallback = ModSettings.onClickValueBox
        newElement.buttonLRChange = ModSettings.onClickValueBox
        newElement.texts[1] = g_i18n:getText("modsetting_ui_fillLevelColored_none")
        newElement.texts[2] = g_i18n:getText("modsetting_ui_fillLevelColored")      
		
		local elmTitle = newElement.elements[4]
        local elmTooltip = newElement.elements[6]

        elmTitle:setText(g_i18n:getText("modsetting_ui_fillLevelColoredTitle"))
        elmTooltip:setText(g_i18n:getText("modsetting_ui_fillLevelColoredTooltip"))
		
		newElement:setState(ModSettings.userSettings.fillLevelColored)
		
		self.boxLayout:addElement(newElement)
	
		self.modSettingsLoaded = true
	end
end

function ModSettings:onClickValueBox(state, element)  
	ModSettings.userSettings[element.id] = state	
    --g_client:getServerConnection():sendEvent(ChangeModSettingsEvent.new(element.id, state))
end

ModSettings.init()
