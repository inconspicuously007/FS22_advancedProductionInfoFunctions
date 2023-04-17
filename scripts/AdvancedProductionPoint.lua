AdvancedProductionPoint = {}
AdvancedProductionPoint.WAIT_AFTER_TOGGLE = 1300

--ProductionPoint.OUTPUT_MODE.SPAWN_PALLET = 4
ProductionPoint.PROD_STATUS.PAUSED = 4
ProductionPoint.PROD_STATUS_TO_L10N[ProductionPoint.PROD_STATUS.PAUSED] = "advprod_ui_production_status_paused"


local function registerProductionPointOutputMode(name, value)
	name = name:upper()

	if ProductionPoint.OUTPUT_MODE[name] == nil then
		if value == nil then
			value = 0

			for _, mode in pairs(ProductionPoint.OUTPUT_MODE) do
				if value < mode then
					value = mode
				end
			end

			value = value + 1
		end

		ProductionPoint.OUTPUT_MODE[name] = value

		if value >= 2^ProductionPoint.OUTPUT_MODE_NUM_BITS - 1 then
			ProductionPoint.OUTPUT_MODE_NUM_BITS = ProductionPoint.OUTPUT_MODE_NUM_BITS + 1
		end
	end
end

registerProductionPointOutputMode("SPAWN_PALLET")

--print("Debug: ProductionPoint.OUTPUT_MODE")
--DebugUtil.printTableRecursively(ProductionPoint.OUTPUT_MODE,"_",0,2)

function AdvancedProductionPoint.registerXMLPaths(schema, basePath)
	schema:register(XMLValueType.STRING, basePath .. "#openingHour", "Productions start to work at this time", nil, false)
	schema:register(XMLValueType.STRING, basePath .. "#closingHour", "Productions end to work at this time", nil, false)
	schema:register(XMLValueType.NODE_INDEX, basePath .. ".animalInputTrigger#node", "", "")
	schema:register(XMLValueType.STRING, basePath .. ".animalInputTrigger.animal(?)#subType", "", "")
	schema:register(XMLValueType.STRING, basePath .. ".animalInputTrigger.animal(?)#targetFillType", "", "")
	schema:register(XMLValueType.FLOAT, basePath .. ".animalInputTrigger.animal(?)#targetRatio", "", 1.0)
	schema:register(XMLValueType.INT, basePath .. ".animalInputTrigger.animal(?)#minAgeMonth", "", 36)
	schema:register(XMLValueType.FLOAT, basePath .. ".animalInputTrigger.animal(?)#minHealthFactor", "", 0.75)
end

function AdvancedProductionPoint.registerSavegameXMLPaths(schema, basePath)
  schema:register(XMLValueType.STRING, basePath .. ".spawnPalletFillType(?)", "fillType currently configured to spawn pallets")
end

function AdvancedProductionPoint:load(superFunc, components, xmlFile, key, customEnv, i3dMappings)		
	
	if g_modIsLoaded.pdlc_pumpsAndHosesPack and self.owningPlaceable.isSandboxPlaceable ~= nil and self.owningPlaceable:isSandboxPlaceable() then
		return superFunc(self, components, xmlFile, key, customEnv, i3dMappings)
	end
	
	--if self:isa(SandboxProductionPoint) then
		--return superFunc(self, outputFillTypeId, mode, noEventSend);
		--print("Debug: self:isa(SandboxProductionPoint")
	--end
	
	--printf("Debug: AdvancedProductionPoint.load: self:isa(SandboxPlaceableProductionPoint): '%s'", self:isa(SandboxPlaceableProductionPoint))
	
	
	self.node = components[1].node
	local name = xmlFile:getValue(key .. "#name")
	self.name = name and g_i18n:convertText(name, customEnv)
	self.productions = {}
	self.productionsIdToObj = {}
	self.inputFillTypeIds = {}
	self.inputFillTypeIdsArray = {}
	self.outputFillTypeIds = {}
	self.outputFillTypeIdsArray = {}
	self.outputFillTypeIdsDirectSell = {}
	self.outputFillTypeIdsAutoDeliver = {}
	self.outputFillTypeIdsToPallets = {}
	self.outputFillTypeIdsSpawnPallet = {}	
	self.inputTypeToProduction = {}	
	self.sharedThroughputCapacity = xmlFile:getValue(key .. ".productions#sharedThroughputCapacity", true)	
	
	self.waitToSpawnAfterToggle = {}
	
	self.manualSpawnPalletPending = {}
	
	self.openingHour = xmlFile:getValue(key .. "#openingHour", "00:00")
	self.closingHour = xmlFile:getValue(key .. "#closingHour", "24:00")
		
	self.helperProductions = {}
	
	local function calcTime(timeString, defaultNum)
		local timeNumber = defaultNum
		if timeString ~= nil then
			t = timeString:split(":")
			timeNumber = tonumber(t[1]) + (tonumber(t[2]) / 60)
		end
		return timeNumber
	end
	
	self.openingTime = calcTime(self.openingHour, 0)
	self.closingTime = calcTime(self.closingHour, 24)
	
	if self.openingTime < 0 or self.openingTime > 24 then
		self.openingTime = calcTime(nil, 0)
		Logging.xmlError(xmlFile, "Error: opening hour '%s' is not valid", self.openingHour)
	end
	if self.closingTime < 0 or self.closingTime > 24 then
		self.closingTime = calcTime(nil, 24)
		Logging.xmlError(xmlFile, "Error: closing hour '%s' is not valid", self.closingHour)
	end
	if self.closingTime < self.openingTime then
		self.openingTime = calcTime(nil, 0)
		self.closingTime = calcTime(nil, 24)
		Logging.xmlError(xmlFile, "Error: opening hour must before closing hour")
	end
	
	local usedProdIds = {}	

	xmlFile:iterate(key .. ".productions.production", function (index, productionKey)
		local production = {
			id = xmlFile:getValue(productionKey .. "#id"),
			name = xmlFile:getValue(productionKey .. "#name", nil, customEnv, false)
		}
		local params = xmlFile:getValue(productionKey .. "#params")

		if params ~= nil then
			params = params:split("|")

			for i = 1, #params do
				params[i] = g_i18n:convertText(params[i], customEnv)
			end

			production.name = string.format(production.name, unpack(params))
		end

		if not production.id then
			Logging.xmlError(xmlFile, "missing id for production '%s'", production.name or index)

			return false
		end

		for i = 1, #usedProdIds do
			if usedProdIds[i] == production.id then
				Logging.xmlError(xmlFile, "production id '%s' already in use", production.id)

				return false
			end
		end

		table.insert(usedProdIds, production.id)
		
		
		local cyclesPerMonth = xmlFile:getValue(productionKey .. "#cyclesPerMonth")
		local cyclesPerHour = xmlFile:getValue(productionKey .. "#cyclesPerHour")
		local cyclesPerMinute = xmlFile:getValue(productionKey .. "#cyclesPerMinute")
		production.cyclesPerMinute = cyclesPerMonth and cyclesPerMonth / 60 / 24 or cyclesPerHour and cyclesPerHour / 60 or cyclesPerMinute or 1
		production.cyclesPerHour = cyclesPerHour or production.cyclesPerMinute * 60
		production.cyclesPerMonth = cyclesPerMonth or production.cyclesPerHour * 24
		local costsPerActiveMinute = xmlFile:getValue(productionKey .. "#costsPerActiveMinute")
		local costsPerActiveHour = xmlFile:getValue(productionKey .. "#costsPerActiveHour")
		local costsPerActiveMonth = xmlFile:getValue(productionKey .. "#costsPerActiveMonth")
		production.costsPerActiveMinute = costsPerActiveMonth and costsPerActiveMonth / 60 / 24 or costsPerActiveHour and costsPerActiveHour / 60 or costsPerActiveMinute or 1
		production.costsPerActiveHour = costsPerActiveHour or production.costsPerActiveMinute * 60
		production.costsPerActiveMonth = costsPerActiveMonth or production.costsPerActiveHour * 24
		production.status = ProductionPoint.PROD_STATUS.INACTIVE
		production.inputs = {}

		xmlFile:iterate(productionKey .. ".inputs.input", function (inputIndex, inputKey)
			local input = {}
			local fillTypeString = xmlFile:getValue(inputKey .. "#fillType")
			input.type = g_fillTypeManager:getFillTypeIndexByName(fillTypeString)

			if input.type == nil then
				Logging.xmlError(xmlFile, "Unable to load fillType '%s' for '%s'", fillTypeString, inputKey)
			else
				self.inputFillTypeIds[input.type] = true

				table.addElement(self.inputFillTypeIdsArray, input.type)

				input.amount = xmlFile:getValue(inputKey .. "#amount", 1)

				table.insert(production.inputs, input)
				
				--- add for better determination of productions in chain ---				
				if self.inputTypeToProduction[input.type] == nil then
					self.inputTypeToProduction[input.type] = {}
				end				
				table.addElement(self.inputTypeToProduction[input.type], production)				
			end
		end)

		if #production.inputs == 0 then
			Logging.xmlError(xmlFile, "No inputs for production '%s'", productionKey)

			return
		end

		production.outputs = {}
		production.primaryProductFillType = nil
		local maxOutputAmount = 0

		xmlFile:iterate(productionKey .. ".outputs.output", function (outputIndex, outputKey)
			local output = {}
			local fillTypeString = xmlFile:getValue(outputKey .. "#fillType")
			output.type = g_fillTypeManager:getFillTypeIndexByName(fillTypeString)

			if output.type == nil then
				Logging.xmlError(xmlFile, "Unable to load fillType '%s' for '%s'", fillTypeString, outputKey)
			else
				output.sellDirectly = xmlFile:getValue(outputKey .. "#sellDirectly", false)

				if not output.sellDirectly then
					self.outputFillTypeIds[output.type] = true

					table.addElement(self.outputFillTypeIdsArray, output.type)
				else
					self.soldFillTypesToPayOut[output.type] = 0
				end

				output.amount = xmlFile:getValue(outputKey .. "#amount", 1)

				table.insert(production.outputs, output)

				if maxOutputAmount < output.amount then
					production.primaryProductFillType = output.type
					maxOutputAmount = output.amount
				end
			end
		end)

		if #production.outputs == 0 then
			Logging.xmlError(xmlFile, "No outputs for production '%s'", productionKey)
		end

		if self.isClient then
			production.samples = {
				active = g_soundManager:loadSampleFromXML(xmlFile, productionKey .. ".sounds", "active", self.baseDirectory, components, 1, AudioGroup.ENVIRONMENT, i3dMappings, nil)
			}
			production.animationNodes = g_animationManager:loadAnimations(xmlFile, productionKey .. ".animationNodes", components, self, i3dMappings)
			production.effects = g_effectManager:loadEffect(xmlFile, productionKey .. ".effectNodes", components, self, i3dMappings)
		end

		if self.productionsIdToObj[production.id] ~= nil then
			Logging.xmlError(xmlFile, "Error: production id '%s' already used", production.id)

			return false
		end

		self.productionsIdToObj[production.id] = production

		table.insert(self.productions, production)
		table.insert(self.helperProductions, production)
		
	end)	

	if #self.productions == 0 then
		Logging.xmlError(xmlFile, "No valid productions defined")
	end

	if self.owningPlaceable == nil then
		print("Error: ProductionPoint.owningPlaceable was not set before load()")

		return false
	end

	self.interactionTriggerNode = xmlFile:getValue(key .. ".playerTrigger#node", nil, components, i3dMappings)

	if self.interactionTriggerNode ~= nil then
		addTrigger(self.interactionTriggerNode, "interactionTriggerCallback", self)
	end

	if self.isClient then
		self.samples = {
			idle = g_soundManager:loadSampleFromXML(xmlFile, key .. ".sounds", "idle", self.baseDirectory, components, 1, AudioGroup.ENVIRONMENT, i3dMappings, nil),
			active = g_soundManager:loadSampleFromXML(xmlFile, key .. ".sounds", "active", self.baseDirectory, components, 1, AudioGroup.ENVIRONMENT, i3dMappings, nil)
		}
		self.animationNodes = g_animationManager:loadAnimations(xmlFile, key .. ".animationNodes", components, self, i3dMappings)
		self.effects = g_effectManager:loadEffect(xmlFile, key .. ".effectNodes", components, self, i3dMappings)
	end

	self.unloadingStation = SellingStation.new(self.isServer, self.isClient)

	self.unloadingStation:load(components, xmlFile, key .. ".sellingStation", self.customEnvironment, i3dMappings, components[1].node)

	self.unloadingStation.storeSoldGoods = true
	self.unloadingStation.skipSell = self.owningPlaceable:getOwnerFarmId() ~= AccessHandler.EVERYONE

	function self.unloadingStation.getIsFillAllowedFromFarm(_, farmId)
		return g_currentMission.accessHandler:canFarmAccess(farmId, self.owningPlaceable)
	end

	self.unloadingStation:register(true)

	local loadingStationKey = key .. ".loadingStation"

	if xmlFile:hasProperty(loadingStationKey) then
		self.loadingStation = LoadingStation.new(self.isServer, self.isClient)

		if not self.loadingStation:load(components, xmlFile, loadingStationKey, self.customEnvironment, i3dMappings, components[1].node) then
			Logging.xmlError(xmlFile, "Unable to load loading station %s", loadingStationKey)

			return false
		end

		function self.loadingStation.hasFarmAccessToStorage(_, farmId)
			return farmId == self.owningPlaceable:getOwnerFarmId()
		end

		self.loadingStation.owningPlaceable = self.owningPlaceable

		self.loadingStation:register(true)
	end

	local palletSpawnerKey = key .. ".palletSpawner"

	if xmlFile:hasProperty(palletSpawnerKey) then
		self.palletSpawner = PalletSpawner.new(self.baseDirectory)

		if not self.palletSpawner:load(components, xmlFile, key .. ".palletSpawner", self.customEnvironment, i3dMappings) then
			Logging.xmlError(xmlFile, "Unable to load pallet spawner %s", palletSpawnerKey)

			return false
		end
	end

	if self.loadingStation == nil and self.palletSpawner == nil then
		Logging.xmlError(xmlFile, "No loading station or pallet spawner for production point")

		return false
	end

	if self.palletSpawner ~= nil then
		for fillTypeId, pallet in pairs(self.palletSpawner:getSupportedFillTypes()) do
			if self.outputFillTypeIds[fillTypeId] then
				self.outputFillTypeIdsToPallets[fillTypeId] = pallet
			end
		end
	end

	self.storage = Storage.new(self.isServer, self.isClient)

	self.storage:load(components, xmlFile, key .. ".storage", i3dMappings)
	self.storage:register(true)

	if self.loadingStation ~= nil then
		if not self.loadingStation:addSourceStorage(self.storage) then
			Logging.xmlWarning(xmlFile, "Unable to add source storage ")
		end

		g_currentMission.storageSystem:addLoadingStation(self.loadingStation, self.owningPlaceable)
	end

	self.unloadingStation:addTargetStorage(self.storage)

	for inputFillTypeIndex in pairs(self.inputFillTypeIds) do
		if not self.unloadingStation:getIsFillTypeSupported(inputFillTypeIndex) then
			local fillTypeName = g_fillTypeManager:getFillTypeNameByIndex(inputFillTypeIndex)

			Logging.xmlWarning(xmlFile, "Input filltype '%s' is not supported by unloading station", fillTypeName)
		end
	end

	for outputFillTypeIndex in pairs(self.outputFillTypeIds) do
		if (self.loadingStation == nil or not self.loadingStation:getIsFillTypeSupported(outputFillTypeIndex)) and self.outputFillTypeIdsToPallets[outputFillTypeIndex] == nil then
			local fillTypeName = g_fillTypeManager:getFillTypeNameByIndex(outputFillTypeIndex)

			Logging.xmlWarning(xmlFile, "Output filltype '%s' is not supported by loading station or pallet spawner", fillTypeName)
		end		
	end

	self.unloadingStation.owningPlaceable = self.owningPlaceable

	g_currentMission.storageSystem:addUnloadingStation(self.unloadingStation, self.owningPlaceable)
	g_currentMission.economyManager:addSellingStation(self.unloadingStation)

	for i = 1, #self.productions do
		local production = self.productions[i]

		for x = 1, #production.inputs do
			local input = production.inputs[x]

			if not self.storage:getIsFillTypeSupported(input.type) then
				Logging.xmlError(xmlFile, "production point storage does not support fillType '%s' used as in input in production '%s'", g_fillTypeManager:getFillTypeNameByIndex(input.type), production.name)

				return false
			end
		end

		for x = 1, #production.outputs do
			local output = production.outputs[x]

			if not output.sellDirectly and not self.storage:getIsFillTypeSupported(output.type) then
				Logging.xmlError(xmlFile, "production point storage does not support fillType '%s' used as an output in production '%s'", g_fillTypeManager:getFillTypeNameByIndex(output.type), production.name)

				return false
			end
		end
	end

	for supportedFillType, _ in pairs(self.storage:getSupportedFillTypes()) do
		if not self.inputFillTypeIds[supportedFillType] and not self.outputFillTypeIds[supportedFillType] then
			Logging.xmlWarning(xmlFile, "storage fillType '%s' not used as a production input or ouput", g_fillTypeManager:getFillTypeNameByIndex(supportedFillType))
		end
	end

	--animal input
	local animalInputTriggerKey = key .. ".animalInputTrigger"

	if xmlFile:hasProperty(animalInputTriggerKey) then
		local animalInputTriggerNode = xmlFile:getValue(key .. ".animalInputTrigger#node", nil, components, i3dMappings)
		if animalInputTriggerNode ~= nil then
			local addTrigger = false
			self.supportedAnimalSubTypes = {}
			self.animalSubTypeToFillType = {}
			self.animalSubTypeToFillTypeRatio = {}
			xmlFile:iterate(key .. ".animalInputTrigger.animal", function(_, animalKey)
				local animalSubTypeName = xmlFile:getString(animalKey .. "#subType")
				local animalSubType = g_currentMission.animalSystem:getSubTypeByName(animalSubTypeName)
				if animalSubType ~= nil then
					if self.supportedAnimalSubTypes[animalSubType.fillTypeIndex] == nil then
						local animalTargetFillTypeName = xmlFile:getString(animalKey .. "#targetFillType")
						local animalTargetFillType = g_fillTypeManager:getFillTypeByName(animalTargetFillTypeName)
						if animalTargetFillType ~= nil and self.storage:getIsFillTypeSupported(animalTargetFillType.index) then
							local animalTargetFillTypeRatio = xmlFile:getValue(animalKey .. "#targetRatio", 1)
							local animalSourceMinAge = xmlFile:getValue(animalKey .. "#minAgeMonth", 18)
							local animalSourceMinHealth = xmlFile:getValue(animalKey .. "#minHealthFactor", 0.75)
							self.supportedAnimalSubTypes[animalSubType.fillTypeIndex] = {
								subType = animalSubType,
								fillType = animalTargetFillType,
								fillTypeRatio = animalTargetFillTypeRatio,
								animalMinAge = animalSourceMinAge,
								animalMinHealth = animalSourceMinHealth
							}
							self.animalSubTypeToFillType[animalSubType.fillTypeIndex] = animalTargetFillType
							self.animalSubTypeToFillTypeRatio[animalSubType.fillTypeIndex] = animalTargetFillTypeRatio
							addTrigger = true
						else
							Logging.xmlError(xmlFile, "Productionpoint storage does not support fillType with name '%s' or fillType is invalid for 'animalInputTrigger' type '%s'.", animalTargetFillTypeName, animalSubTypeName)
						end
					else
						Logging.xmlWarning(xmlFile, "AnimalType with name '%s' already defined for 'animalInputTrigger'. Ignoring this definition.", animalSubTypeName)
					end
				else
					Logging.xmlError(xmlFile, "Animal subType '%s' invalid!", animalSubTypeName)
				end
			end)
			if addTrigger then
				self.animalToProductionTrigger = AnimalToProductionTrigger.new(self.isServer, self.isClient)
				self.animalToProductionTrigger:load(animalInputTriggerNode, self)
			end
		end
	end

	return true
end

function AdvancedProductionPoint:updateProduction(superFunc)
	if g_modIsLoaded.pdlc_pumpsAndHosesPack and self.owningPlaceable.isSandboxPlaceable ~= nil and self.owningPlaceable:isSandboxPlaceable() then
		return superFunc(self)
	end

	if self.lastUpdatedTime == nil then
		self.lastUpdatedTime = g_time

		return
	end
	
	local dt = MathUtil.clamp(g_time - self.lastUpdatedTime, 0, 30000)
	local timeAdjust = g_currentMission.environment.timeAdjustment
	local numActiveProductions = #self.activeProductions
	
	local isOpen = false
	local currentTime = g_currentMission.environment.dayTime / 3600000
	if self.openingTime ~= nil and self.closingTime ~= nil then
		isOpen = (currentTime >= self.openingTime) and (currentTime <= self.closingTime)
	else
		isOpen = true
	end
	
	if numActiveProductions > 0 and isOpen then
		local minuteFactorTimescaledDt = dt * self.minuteFactorTimescaled * timeAdjust
		local minuteFactorDt = dt / 60000 * timeAdjust

		for n = 1, numActiveProductions do
			local production = self.activeProductions[n]
			local cyclesPerMinuteMinuteFactor = production.cyclesPerMinute * minuteFactorTimescaledDt
			local cyclesPerMinuteFactorNoTimescale = production.cyclesPerMinute * minuteFactorDt
			local enoughInputResources = true
			local enoughOutputSpace = true

			for x = 1, #production.inputs do
				local input = production.inputs[x]
				local fillLevel = self:getFillLevel(input.type)
				self.inputFillLevels[input] = fillLevel

				if self.isOwned and fillLevel < input.amount * cyclesPerMinuteFactorNoTimescale then
					enoughInputResources = false

					if production.status ~= ProductionPoint.PROD_STATUS.MISSING_INPUTS then
						production.status = ProductionPoint.PROD_STATUS.MISSING_INPUTS

						self.owningPlaceable:productionStatusChanged(production, ProductionPoint.PROD_STATUS.MISSING_INPUTS)
						self:setProductionStatus(production.id, production.status)
					end

					break
				end
			end

			if enoughInputResources and self.isOwned then
				for x = 1, #production.outputs do
					local output = production.outputs[x]

					if not output.sellDirectly then
						local freeCapacity = self.storage:getFreeCapacity(output.type)

						if freeCapacity < output.amount * cyclesPerMinuteMinuteFactor then
							enoughOutputSpace = false

							if production.status ~= ProductionPoint.PROD_STATUS.NO_OUTPUT_SPACE then
								production.status = ProductionPoint.PROD_STATUS.NO_OUTPUT_SPACE

								self:setProductionStatus(production.id, production.status)
							end

							break
						end
					end
				end
			end

			if self.isOwned then
				self.productionCostsToClaim = self.productionCostsToClaim + production.costsPerActiveMinute * minuteFactorTimescaledDt
			end

			if not self.isOwned or enoughInputResources and enoughOutputSpace then
				local factor = cyclesPerMinuteMinuteFactor / (self.sharedThroughputCapacity and numActiveProductions or 1)

				for y = 1, #production.inputs do
					local input = production.inputs[y]

					if self.loadingStation ~= nil then
						self.loadingStation:removeFillLevel(input.type, input.amount * factor, self.ownerFarmId)
					else
						local fillLevel = self.inputFillLevels[input]

						if fillLevel and fillLevel > 0 then
							self.storage:setFillLevel(fillLevel - input.amount * factor, input.type)
						end
					end
				end

				if self.isOwned then
					for y = 1, #production.outputs do
						local output = production.outputs[y]

						if output.sellDirectly then
							if self.isServer then
								self.soldFillTypesToPayOut[output.type] = self.soldFillTypesToPayOut[output.type] + output.amount * factor
							end
						else
							local fillLevel = self.storage:getFillLevel(output.type)

							self.storage:setFillLevel(fillLevel + output.amount * factor, output.type)
						end
					end
				end

				if production.status ~= ProductionPoint.PROD_STATUS.RUNNING then
					production.status = ProductionPoint.PROD_STATUS.RUNNING

					self.owningPlaceable:productionStatusChanged(production, production.status)
					ProductionPointProductionStatusEvent.sendEvent(self, production.id, production.status)
				end

				table.clear(self.inputFillLevels)
			end
		end
	end
	
	if self.isServer and self.isOwned and self.palletSpawnCooldown < g_time then		
		for fillTypeId, pallet in pairs(self.outputFillTypeIdsToPallets) do
			if self.outputFillTypeIdsSpawnPallet[fillTypeId] ~= nil and self.outputFillTypeIdsSpawnPallet[fillTypeId] and ( self.waitToSpawnAfterToggle[fillTypeId] == nil or self.waitToSpawnAfterToggle[fillTypeId] < g_time ) then			
				local fillLevel = self.storage:getFillLevel(fillTypeId)
				if fillLevel > 0 and pallet and pallet.capacity <= fillLevel and not self.waitingForPalletToSpawn then
					self.waitingForPalletToSpawn = true					
					self.palletSpawner:spawnPallet(self:getOwnerFarmId(), fillTypeId, self.palletSpawnRequestCallback, self)					
				end
				self.waitToSpawnAfterToggle[fillTypeId] = nil
			end
		end
	end
	
	if numActiveProductions > 0 and not isOpen then
		for n = 1, numActiveProductions do
			local production = self.activeProductions[n]
			if production.status == ProductionPoint.PROD_STATUS.RUNNING then
				production.status = ProductionPoint.PROD_STATUS.PAUSED

				self.owningPlaceable:productionStatusChanged(production, production.status)
				ProductionPointProductionStatusEvent.sendEvent(self, production.id, production.status)
			end
		end
	end
	
	self.lastUpdatedTime = g_time
end

function AdvancedProductionPoint:loadFromXMLFile(superFunc, xmlFile, key)
	if g_modIsLoaded.pdlc_pumpsAndHosesPack and self.owningPlaceable.isSandboxPlaceable ~= nil and self.owningPlaceable:isSandboxPlaceable() then
		return superFunc(self, xmlFile, key)
	end

	local palletSpawnCooldown = xmlFile:getValue(key .. "#palletSpawnCooldown")

	if palletSpawnCooldown then
		self.palletSpawnCooldown = g_time + palletSpawnCooldown
	end

	self.productionCostsToClaim = xmlFile:getValue(key .. "#productionCostsToClaim") or self.productionCostsToClaim

	if self.owningPlaceable.ownerFarmId == AccessHandler.EVERYONE then
		for n = 1, #self.productions do
			self:setProductionState(self.productions[n].id, true)
		end
	end

	xmlFile:iterate(key .. ".production", function (index, productionKey)
		local prodId = xmlFile:getValue(productionKey .. "#id")
		local isEnabled = xmlFile:getValue(productionKey .. "#isEnabled")

		if self.productionsIdToObj[prodId] == nil then
			Logging.xmlWarning(xmlFile, "Unknown production id '%s'", prodId)
		else
			self:setProductionState(prodId, isEnabled)
		end
	end)
	xmlFile:iterate(key .. ".directSellFillType", function (index, directSellKey)
		local fillType = g_fillTypeManager:getFillTypeIndexByName(xmlFile:getValue(directSellKey))

		if fillType then
			self:setOutputDistributionMode(fillType, ProductionPoint.OUTPUT_MODE.DIRECT_SELL)
		end
	end)
	xmlFile:iterate(key .. ".autoDeliverFillType", function (index, autoDeliverKey)
		local fillType = g_fillTypeManager:getFillTypeIndexByName(xmlFile:getValue(autoDeliverKey))

		if fillType then
			self:setOutputDistributionMode(fillType, ProductionPoint.OUTPUT_MODE.AUTO_DELIVER)
		end
	end)
	
	xmlFile:iterate(key .. ".spawnPalletFillType", function (index, spawnPalletKey)
		local fillType = g_fillTypeManager:getFillTypeIndexByName(xmlFile:getValue(spawnPalletKey))

		if fillType then
			self:setOutputDistributionMode(fillType, ProductionPoint.OUTPUT_MODE.SPAWN_PALLET)
		end	
	end)
	
	if not self.storage:loadFromXMLFile(xmlFile, key .. ".storage") then
		return false
	end

	return true
end

function AdvancedProductionPoint:saveToXMLFile(superFunc, xmlFile, key, usedModNames)
	if g_modIsLoaded.pdlc_pumpsAndHosesPack and self.owningPlaceable.isSandboxPlaceable ~= nil and self.owningPlaceable:isSandboxPlaceable() then
		return superFunc(self, xmlFile, key, usedModNames)
	end
	
	if g_time < self.palletSpawnCooldown then
		xmlFile:setValue(key .. "#palletSpawnCooldown", self.palletSpawnCooldown - g_time)
	end

	if self.productionCostsToClaim ~= 0 then
		xmlFile:setValue(key .. "#productionCostsToClaim", self.productionCostsToClaim)
	end

	local xmlIndex = 0

	for i = 1, #self.activeProductions do
		local production = self.activeProductions[i]
		local productionKey = string.format("%s.production(%i)", key, xmlIndex)

		xmlFile:setValue(productionKey .. "#id", production.id)
		xmlFile:setValue(productionKey .. "#isEnabled", true)

		xmlIndex = xmlIndex + 1
	end

	xmlFile:setTable(key .. ".directSellFillType", self.outputFillTypeIdsDirectSell, function (fillTypeKey, _, fillTypeId)
		local fillType = g_fillTypeManager:getFillTypeNameByIndex(fillTypeId)

		xmlFile:setValue(fillTypeKey, fillType)
	end)
	xmlFile:setTable(key .. ".autoDeliverFillType", self.outputFillTypeIdsAutoDeliver, function (fillTypeKey, _, fillTypeId)
		local fillType = g_fillTypeManager:getFillTypeNameByIndex(fillTypeId)

		xmlFile:setValue(fillTypeKey, fillType)
	end)
	
	xmlFile:setTable(key .. ".spawnPalletFillType", self.outputFillTypeIdsSpawnPallet, function (fillTypeKey, _, fillTypeId)
		local fillType = g_fillTypeManager:getFillTypeNameByIndex(fillTypeId)

		xmlFile:setValue(fillTypeKey, fillType)
	end)
	
	self.storage:saveToXMLFile(xmlFile, key .. ".storage", usedModNames)
end

function AdvancedProductionPoint:setOutputDistributionMode(superFunc, outputFillTypeId, mode, noEventSend)
	
	if g_modIsLoaded.pdlc_pumpsAndHosesPack and self.owningPlaceable.isSandboxPlaceable ~= nil and self.owningPlaceable:isSandboxPlaceable() then		
		return superFunc(self, outputFillTypeId, mode, noEventSend)
	end
	
	if self.outputFillTypeIds[outputFillTypeId] == nil then
		printf("Error: setOutputDistribution(): fillType '%s' is not an output fillType", g_fillTypeManager:getFillTypeNameByIndex(outputFillTypeId))
		return
	end	
	
	mode = tonumber(mode)
	self.outputFillTypeIdsDirectSell[outputFillTypeId] = nil
	self.outputFillTypeIdsAutoDeliver[outputFillTypeId] = nil	
	self.outputFillTypeIdsSpawnPallet[outputFillTypeId] = nil	
	
	if mode == ProductionPoint.OUTPUT_MODE.DIRECT_SELL then
		self.outputFillTypeIdsDirectSell[outputFillTypeId] = true
	elseif mode == ProductionPoint.OUTPUT_MODE.AUTO_DELIVER then
		self.outputFillTypeIdsAutoDeliver[outputFillTypeId] = true		
	elseif mode == ProductionPoint.OUTPUT_MODE.SPAWN_PALLET then
		self.outputFillTypeIdsSpawnPallet[outputFillTypeId] = true			
	elseif mode ~= ProductionPoint.OUTPUT_MODE.KEEP then
		printf("Error: setOutputDistribution(): Undefined mode '%s'", mode)
		return
	end

	ProductionPointOutputModeEvent.sendEvent(self, outputFillTypeId, mode, noEventSend)
end

function AdvancedProductionPoint:getOutputDistributionMode(superFunc, outputFillTypeId)
	if self.outputFillTypeIdsDirectSell ~= nil and self.outputFillTypeIdsDirectSell[outputFillTypeId] ~= nil then
		return ProductionPoint.OUTPUT_MODE.DIRECT_SELL
	elseif self.outputFillTypeIdsAutoDeliver ~= nil and self.outputFillTypeIdsAutoDeliver[outputFillTypeId] ~= nil then
		return ProductionPoint.OUTPUT_MODE.AUTO_DELIVER
	elseif self.outputFillTypeIdsSpawnPallet ~= nil and self.outputFillTypeIdsSpawnPallet[outputFillTypeId] ~= nil then
		return ProductionPoint.OUTPUT_MODE.SPAWN_PALLET
	end

	return ProductionPoint.OUTPUT_MODE.KEEP
end

function AdvancedProductionPoint:toggleOutputDistributionMode(superFunc, outputFillTypeId)
	
	if self.outputFillTypeIds[outputFillTypeId] ~= nil then
		local curMode = self:getOutputDistributionMode(outputFillTypeId)
		if g_modIsLoaded.pdlc_pumpsAndHosesPack and self.owningPlaceable.isSandboxPlaceable ~= nil and self.owningPlaceable:isSandboxPlaceable() then		
			
			if table.hasElement(ProductionPoint.OUTPUT_MODE, curMode + 1) then
				self:setOutputDistributionMode(outputFillTypeId, curMode + 1)
			else
				self:setOutputDistributionMode(outputFillTypeId, 0)
			end
		else			
			local nextMode = 0
			local defaultMode = 0
			self.waitToSpawnAfterToggle[outputFillTypeId] = nil
			
			if curMode == ProductionPoint.OUTPUT_MODE.KEEP then 
				nextMode = ProductionPoint.OUTPUT_MODE.DIRECT_SELL
			elseif curMode == ProductionPoint.OUTPUT_MODE.DIRECT_SELL then 
				nextMode = ProductionPoint.OUTPUT_MODE.AUTO_DELIVER
			elseif curMode == ProductionPoint.OUTPUT_MODE.AUTO_DELIVER then 
				nextMode = ProductionPoint.OUTPUT_MODE.SPAWN_PALLET
			end		
			
			if nextMode == ProductionPoint.OUTPUT_MODE.SPAWN_PALLET and self.outputFillTypeIdsToPallets[outputFillTypeId] == nil then
				nextMode = defaultMode			
			end		
			
			if nextMode == ProductionPoint.OUTPUT_MODE.SPAWN_PALLET then
				self.waitToSpawnAfterToggle[outputFillTypeId] = g_time + AdvancedProductionPoint.WAIT_AFTER_TOGGLE
			end
			
			if table.hasElement(ProductionPoint.OUTPUT_MODE, nextMode) then
				self:setOutputDistributionMode(outputFillTypeId, nextMode)
			else
				self:setOutputDistributionMode(outputFillTypeId, defaultMode)
			end
		end
	end
end

function AdvancedProductionPoint:readStream(superFunc, streamId, connection)	
	if g_modIsLoaded.pdlc_pumpsAndHosesPack and self.owningPlaceable.isSandboxPlaceable ~= nil and self.owningPlaceable:isSandboxPlaceable() then
		return superFunc(self, streamId, connection)
	end
	
	ProductionPoint:superClass().readStream(self, streamId, connection)
	
	if connection:getIsServer() then
		for i = 1, streamReadUInt8(streamId) do
			self:setOutputDistributionMode(streamReadUIntN(streamId, FillTypeManager.SEND_NUM_BITS), ProductionPoint.OUTPUT_MODE.DIRECT_SELL)
		end

		for i = 1, streamReadUInt8(streamId) do
			self:setOutputDistributionMode(streamReadUIntN(streamId, FillTypeManager.SEND_NUM_BITS), ProductionPoint.OUTPUT_MODE.AUTO_DELIVER)
		end
		
		for i = 1, streamReadUInt8(streamId) do
			self:setOutputDistributionMode(streamReadUIntN(streamId, FillTypeManager.SEND_NUM_BITS), ProductionPoint.OUTPUT_MODE.SPAWN_PALLET)
		end

		local unloadingStationId = NetworkUtil.readNodeObjectId(streamId)

		self.unloadingStation:readStream(streamId, connection)
		g_client:finishRegisterObject(self.unloadingStation, unloadingStationId)

		if self.loadingStation ~= nil then
			local loadingStationId = NetworkUtil.readNodeObjectId(streamId)

			self.loadingStation:readStream(streamId, connection)
			g_client:finishRegisterObject(self.loadingStation, loadingStationId)
		end

		local storageId = NetworkUtil.readNodeObjectId(streamId)

		self.storage:readStream(streamId, connection)
		g_client:finishRegisterObject(self.storage, storageId)

		for i = 1, streamReadUInt8(streamId) do
			local productionId = streamReadString(streamId)

			self:setProductionState(productionId, true)
			self:setProductionStatus(productionId, streamReadUIntN(streamId, ProductionPoint.PROD_STATUS_NUM_BITS))
		end

		self.palletLimitReached = streamReadBool(streamId)
	end
end

function AdvancedProductionPoint:writeStream(superFunc, streamId, connection)	
	if g_modIsLoaded.pdlc_pumpsAndHosesPack and self.owningPlaceable.isSandboxPlaceable ~= nil and self.owningPlaceable:isSandboxPlaceable() then
		return superFunc(self, streamId, connection)
	end
	
	ProductionPoint:superClass().writeStream(self, streamId, connection)
	
	if not connection:getIsServer() then
		streamWriteUInt8(streamId, table.size(self.outputFillTypeIdsDirectSell))

		for directSellFillTypeId in pairs(self.outputFillTypeIdsDirectSell) do
			streamWriteUIntN(streamId, directSellFillTypeId, FillTypeManager.SEND_NUM_BITS)
		end

		streamWriteUInt8(streamId, table.size(self.outputFillTypeIdsAutoDeliver))

		for autoDeliverFillTypeId in pairs(self.outputFillTypeIdsAutoDeliver) do
			streamWriteUIntN(streamId, autoDeliverFillTypeId, FillTypeManager.SEND_NUM_BITS)
		end
		
		streamWriteUInt8(streamId, table.size(self.outputFillTypeIdsSpawnPallet))
		
		for spawnPalletFillTypeId in pairs(self.outputFillTypeIdsSpawnPallet) do
			streamWriteUIntN(streamId, spawnPalletFillTypeId, FillTypeManager.SEND_NUM_BITS)
		end

		NetworkUtil.writeNodeObjectId(streamId, NetworkUtil.getObjectId(self.unloadingStation))
		self.unloadingStation:writeStream(streamId, connection)
		g_server:registerObjectInStream(connection, self.unloadingStation)

		if self.loadingStation ~= nil then
			NetworkUtil.writeNodeObjectId(streamId, NetworkUtil.getObjectId(self.loadingStation))
			self.loadingStation:writeStream(streamId, connection)
			g_server:registerObjectInStream(connection, self.loadingStation)
		end

		NetworkUtil.writeNodeObjectId(streamId, NetworkUtil.getObjectId(self.storage))
		self.storage:writeStream(streamId, connection)
		g_server:registerObjectInStream(connection, self.storage)
		streamWriteUInt8(streamId, #self.activeProductions)

		for i = 1, #self.activeProductions do
			local production = self.activeProductions[i]

			streamWriteString(streamId, production.id)
			streamWriteUIntN(streamId, production.status, ProductionPoint.PROD_STATUS_NUM_BITS)
		end

		streamWriteBool(streamId, self.palletLimitReached)
	end
end

function AdvancedProductionPoint:setProductionState(superFunc, productionId, state, noEventSend)
	local production = self.productionsIdToObj[productionId]

	if production ~= nil then
		local isOpen = false
		local currentTime = g_currentMission.environment.dayTime / 3600000
		if self.openingTime ~= nil and self.closingTime ~= nil then
			isOpen = (currentTime >= self.openingTime) and (currentTime <= self.closingTime)
		else
			isOpen = true
		end
		if state then
			if not table.hasElement(self.activeProductions, production) then
				production.status = ProductionPoint.PROD_STATUS.RUNNING

				table.insert(self.activeProductions, production)
			end
			
			if not isOpen and production.status == ProductionPoint.PROD_STATUS.RUNNING then
				production.status = ProductionPoint.PROD_STATUS.PAUSED
			end
			
			if self.isClient then
				g_soundManager:playSamples(production.samples)
				g_animationManager:startAnimations(production.animationNodes)
				g_effectManager:startEffects(production.effects)
			end
		else
			table.removeElement(self.activeProductions, production)

			production.status = ProductionPoint.PROD_STATUS.INACTIVE

			if self.isClient then
				g_soundManager:stopSamples(production.samples)
				g_animationManager:stopAnimations(production.animationNodes)
				g_effectManager:stopEffects(production.effects)
			end
		end

		self.owningPlaceable:outputsChanged(production.outputs, state)
		ProductionPointProductionStateEvent.sendEvent(self, productionId, state, noEventSend)
	else
		log(string.format("Error: setProductionState(): unknown productionId '%s'", productionId))
	end

	if self.isClient then
		self:updateFxState()
	end
end

function AdvancedProductionPoint:updateInfo(superFunc, superFunc, infoTable)
	superFunc(self, infoTable)

	local owningFarm = g_farmManager:getFarmById(self:getOwnerFarmId())
	local activeOutputs = {}
	local activeInputs = {}
	local missingInputs = {}
	local fillType, fillLevel = nil
	local fillTypesDisplayed, activeOutputsDisplayed, missingInputsDisplayed = false


	table.insert(infoTable, {
		title = g_i18n:getText("fieldInfo_ownedBy"),
		text = owningFarm.name
	})

	if #self.activeProductions > 0 then
		table.insert(infoTable, self.infoTables.activeProds)

		local activeProduction = nil

		for i = 1, #self.activeProductions do
			activeProduction = self.activeProductions[i]
			local productionName = activeProduction.name or g_fillTypeManager:getFillTypeTitleByIndex(activeProduction.primaryProductFillType)
			
			table.insert(infoTable, {
				title = productionName,
				text = g_i18n:getText(ProductionPoint.PROD_STATUS_TO_L10N[self:getProductionStatus(activeProduction.id)])
			})
			
			for x = 1, #activeProduction.outputs do
				local output = activeProduction.outputs[x]
				activeOutputs[output.type] = true
				activeOutputsDisplayed = true
			end
			for y = 1, #activeProduction.inputs do
				local input = activeProduction.inputs[y]
				activeInputs[input.type] = true				
			end
		end
	else
		table.insert(infoTable, self.infoTables.noActiveProd)
	end
	
	table.insert(infoTable, self.infoTables.storage)

	for i = 1, #self.inputFillTypeIdsArray do
		fillType = self.inputFillTypeIdsArray[i]
		fillLevel = self:getFillLevel(fillType)

		if fillLevel > 1 then
			fillTypesDisplayed = true
			local fillTypeTitle = g_fillTypeManager:getFillTypeTitleByIndex(fillType)
			local fillTypeDesc = g_fillTypeManager:getFillTypeByIndex(fillType)			
			
			if g_currentMission.animalSystem:getSubTypeByFillTypeIndex(fillType) ~= nil then
				fillTypeTitle = g_currentMission.animalSystem:getSubTypeByFillTypeIndex(fillType).visuals[1].store.name
			end
			table.insert(infoTable, {
				title = fillTypeTitle, 
				--text = g_i18n:formatVolume(fillLevel, 0) .. " [ " .. g_i18n:formatVolume(self:getCapacity(fillType), 0) .. " ]"
				text = string.trim(g_i18n:formatVolume(fillLevel, 0, fillTypeDesc.unitShort)) .. " [ " .. string.trim(g_i18n:formatVolume(self:getCapacity(fillType), 0, fillTypeDesc.unitShort)) .. " ]"

			})
		else			
			if activeInputs ~= nil and activeInputs[fillType] == true and not table.hasElement(missingInputs, fillType) then				
				table.addElement(missingInputs, fillType)
				missingInputsDisplayed = true
			end	
		end
			
	end

	for i = 1, #self.outputFillTypeIdsArray do
		fillType = self.outputFillTypeIdsArray[i]
		fillLevel = self:getFillLevel(fillType)
		
		if not self.inputFillTypeIds[fillType] and fillLevel > 1 then
			local fillTypeDesc = g_fillTypeManager:getFillTypeByIndex(fillType)	
			fillTypesDisplayed = true			 
			
			table.insert(infoTable, {
				title = g_fillTypeManager:getFillTypeTitleByIndex(fillType),
				--text = g_i18n:formatVolume(fillLevel, 0) .. " [ " .. g_i18n:formatVolume(self:getCapacity(fillType), 0) .. " ]"
				text = string.trim(g_i18n:formatVolume(fillLevel, 0, fillTypeDesc.unitShort)) .. " [ " .. string.trim(g_i18n:formatVolume(self:getCapacity(fillType), 0, fillTypeDesc.unitShort)) .. " ]"
			})
		end
	end

	if not fillTypesDisplayed then
		table.insert(infoTable, self.infoTables.storageEmpty)
	end
	
	local distOutputs = {
		accentuate = true,
		title = g_i18n:getText("advprod_ui_production_outputMode")
	}
	if activeOutputsDisplayed and #self.activeProductions > 0 then
		table.insert(infoTable, distOutputs)		
		for outputFillType in pairs(activeOutputs) do
			local distMode = self:getOutputDistributionMode(outputFillType)
			local distModeText = g_i18n:getText("advprod_ui_production_output_storing")
			if distMode == ProductionPoint.OUTPUT_MODE.DIRECT_SELL then
				distModeText = g_i18n:getText("ui_production_output_selling")
			elseif distMode == ProductionPoint.OUTPUT_MODE.AUTO_DELIVER then
				distModeText = g_i18n:getText("ui_production_output_distributing")
			elseif distMode == ProductionPoint.OUTPUT_MODE.SPAWN_PALLET then 
				distModeText = g_i18n:getText("advprod_ui_production_output_spawn_pallets")	
			end		
			
			table.insert(infoTable, {
				title = g_fillTypeManager:getFillTypeTitleByIndex(outputFillType),
				text = distModeText
			})
		end		
	end
	
	if missingInputsDisplayed and #self.activeProductions > 0 then
		local missed = {
			accentuate = true,
			title = g_i18n:getText("advprod_ui_production_missingInputs")
		}
		table.insert(infoTable, missed)
		for _, missFillType in pairs(missingInputs) do
			table.insert(infoTable, {
				title = g_fillTypeManager:getFillTypeTitleByIndex(missFillType),
				text = ""
			})
		end
	end
	
end

function ProductionPoint:manualSpawnPallets(fillTypeId, fillLevel, palletCount)
	self.manualSpawnPalletPending[fillTypeId] = {
		fillLevel = fillLevel,
		palletCount = palletCount
	}
	self.palletSpawner:spawnPallet(self.ownerFarmId, fillTypeId, ProductionPoint.manualSpawnPalletsCallback, self)
end

function ProductionPoint:manualSpawnPalletsCallback(pallet, status, fillTypeId)
	self.waitingForPalletToSpawnManual = false
	
	if status == PalletSpawner.RESULT_NO_SPACE then
		self.waitingForPalletToSpawnManualTimer = Timer.new(500)		
		self.waitingForPalletToSpawnManualTimer:setFinishCallback(
			function()
				self.palletSpawner:spawnPallet(self.ownerFarmId, fillTypeId, ProductionPoint.manualSpawnPalletsCallback, self)
			end
		)
		self.waitingForPalletToSpawnManualTimer:start(true)
	end
	
	if pallet ~= nil and fillTypeId ~= nil then --and pallet.addFillUnitFillLevel 
		if self.palletLimitReached then
			self.palletLimitReached = false

			self:raiseDirtyFlags(self.dirtyFlag)
		end

		local fillUnitIndex = pallet:getFirstValidFillUnitToFill(fillTypeId)

		if fillUnitIndex then
			if status == PalletSpawner.RESULT_SUCCESS then
				pallet:emptyAllFillUnits(true)
			end
			local delta = pallet:addFillUnitFillLevel(self.ownerFarmId, fillUnitIndex, self.manualSpawnPalletPending[fillTypeId].fillLevel, fillTypeId, ToolType.UNDEFINED)

			if delta > 0 then
				self.storage:setFillLevel(self.storage:getFillLevel(fillTypeId) - delta, fillTypeId)
				self.manualSpawnPalletPending[fillTypeId].fillLevel = math.max(self.manualSpawnPalletPending[fillTypeId].fillLevel - delta, 0)
				self.manualSpawnPalletPending[fillTypeId].palletCount = math.max(self.manualSpawnPalletPending[fillTypeId].palletCount - 1, 0)
			end
		else
			printf("Error: No fillUnitIndex for fillTypeId %s found, pallet:", g_fillTypeManager:getFillTypeNameByIndex(fillTypeId), pallet.xmlFile.filename)
		end	
		
		if self.isServer and self.manualSpawnPalletPending[fillTypeId].fillLevel > 100 and not self.waitingForPalletToSpawnManual then
			self.waitingForPalletToSpawnManual = true
			self.waitingForPalletToSpawnManualTimer = Timer.new(150)		
			self.waitingForPalletToSpawnManualTimer:setFinishCallback(
				function()
					self.palletSpawner:spawnPallet(self.ownerFarmId, fillTypeId, ProductionPoint.manualSpawnPalletsCallback, self)
				end
			)
			self.waitingForPalletToSpawnManualTimer:start(true)		
		end	
	end
end

function AdvancedProductionPoint:delete()
	if self.animalToProductionTrigger then
        self.animalToProductionTrigger:delete()
    end
end

ProductionPoint.registerXMLPaths 				= Utils.prependedFunction(ProductionPoint.registerXMLPaths, AdvancedProductionPoint.registerXMLPaths)
ProductionPoint.registerSavegameXMLPaths 		= Utils.prependedFunction(ProductionPoint.registerSavegameXMLPaths, AdvancedProductionPoint.registerSavegameXMLPaths)
ProductionPoint.load 							= Utils.overwrittenFunction(ProductionPoint.load, AdvancedProductionPoint.load)
ProductionPoint.getOutputDistributionMode 		= Utils.overwrittenFunction(ProductionPoint.getOutputDistributionMode, AdvancedProductionPoint.getOutputDistributionMode)
ProductionPoint.updateProduction 				= Utils.overwrittenFunction(ProductionPoint.updateProduction, AdvancedProductionPoint.updateProduction)
ProductionPoint.setOutputDistributionMode 		= Utils.overwrittenFunction(ProductionPoint.setOutputDistributionMode, AdvancedProductionPoint.setOutputDistributionMode)
ProductionPoint.toggleOutputDistributionMode 	= Utils.overwrittenFunction(ProductionPoint.toggleOutputDistributionMode, AdvancedProductionPoint.toggleOutputDistributionMode)
ProductionPoint.loadFromXMLFile 				= Utils.overwrittenFunction(ProductionPoint.loadFromXMLFile, AdvancedProductionPoint.loadFromXMLFile)
ProductionPoint.saveToXMLFile 					= Utils.overwrittenFunction(ProductionPoint.saveToXMLFile, AdvancedProductionPoint.saveToXMLFile)
ProductionPoint.readStream 						= Utils.overwrittenFunction(ProductionPoint.readStream, AdvancedProductionPoint.readStream)
ProductionPoint.writeStream 					= Utils.overwrittenFunction(ProductionPoint.writeStream, AdvancedProductionPoint.writeStream)
ProductionPoint.setProductionState				= Utils.overwrittenFunction(ProductionPoint.setProductionState, AdvancedProductionPoint.setProductionState)
ProductionPoint.updateInfo 						= Utils.overwrittenFunction(ProductionPoint.updateInfo, AdvancedProductionPoint.updateInfo)
ProductionPoint.delete 							= Utils.prependedFunction(ProductionPoint.delete, AdvancedProductionPoint.delete)