AdvancedHusbandryInfo = {}

function AdvancedHusbandryInfo:setTextColor(textElement, value, highIsDanger)
	if ModSettings.userSettings.fillLevelColored ~= nil and ModSettings.userSettings.fillLevelColored == 2 then
		if not highIsDanger then
			if value >= InGameMenuAnimalsFrame.STATUS_BAR_HIGH then
				textElement:setTextColor(0.3763, 0.6038, 0.0782, 1)
			elseif value < InGameMenuAnimalsFrame.STATUS_BAR_MEDIUM then
				textElement:setTextColor(0.8069, 0.0097, 0.0097, 1)
			else
				textElement:setTextColor(0.98, 0.42, 0, 1)
			end
		else
			if value >= InGameMenuAnimalsFrame.STATUS_BAR_HIGH then
				textElement:setTextColor(0.8069, 0.0097, 0.0097, 1)
			elseif value < InGameMenuAnimalsFrame.STATUS_BAR_MEDIUM then
				textElement:setTextColor(0.3763, 0.6038, 0.0782, 1)
			else
				textElement:setTextColor(0.98, 0.42, 0, 1)
			end
		end
	else
		textElement:setTextColor(1, 1, 1, 1)
	end
end

function AdvancedHusbandryInfo:getFoodInfos(superFunc, superFunc)
	local foodInfos = superFunc(self)
	local spec = self.spec_husbandryFood
	local animalFood = g_currentMission.animalFoodSystem:getAnimalFood(spec.animalTypeIndex)

	if animalFood ~= nil then
		for _, foodGroup in pairs(animalFood.groups) do
			local title = foodGroup.title
			local fillLevel = 0
			local capacity = spec.capacity			 
			local foodGroupCapacity = 0
			
			for _, fillTypeIndex in pairs(foodGroup.fillTypes) do
				if spec.fillLevels[fillTypeIndex] ~= nil then
					fillLevel = fillLevel + spec.fillLevels[fillTypeIndex]
				end
			end
			
			local info = {
				title = string.format("%s (%d%%)", title, MathUtil.round(foodGroup.productionWeight * 100)),
				value = fillLevel,
				capacity = capacity,
				ratio = 0,
				consumpt = animalFood.consumptionType,
				groupCapacity = 0,
				groupRatio = 0
			}

			if capacity > 0 then
				info.ratio = fillLevel / capacity
			end
			
			if animalFood.consumptionType == AnimalFoodSystem.FOOD_CONSUME_TYPE_PARALLEL then
				foodGroupCapacity = MathUtil.round(foodGroup.productionWeight * capacity) 
			else
				foodGroupCapacity = capacity
			end
			
			info.groupCapacity = foodGroupCapacity
			
			if foodGroupCapacity > 0 then
				info.groupRatio = fillLevel / foodGroupCapacity
			end
			
			table.insert(foodInfos, info)
		end
	end

	return foodInfos
end

function AdvancedHusbandryInfo:getAnimalInfos(superFunc, superFunc, cluster)
	local infos = superFunc(self)

	cluster:addInfos(infos)
	
	local animalTypeIndex = self:getAnimalTypeIndex()
	local animalFood = g_currentMission.animalFoodSystem:getAnimalFood(animalTypeIndex)
	local infoConsumption = {
		title = g_i18n:getText("advhusbandry_ui_consumption"),
		valueText = g_i18n:getText("advhusbandry_ui_consume_serial"),
		ratio = 0,
		invertedBar = false,
		disabled = true,
		showStatusBar = false
	}
	if animalFood.consumptionType == AnimalFoodSystem.FOOD_CONSUME_TYPE_PARALLEL then infoConsumption.valueText = g_i18n:getText("advhusbandry_ui_consume_parallel") end
	table.insert(infos, infoConsumption)
	
	return infos
end

function AdvancedHusbandryInfo:updateFoodDisplay(superFunc, husbandry)
	local infos = husbandry:getFoodInfos()
	local totalCapacity = 0
	local totalValue = 0
	local groupCapacity = 0
	local consumptionType = 0
	
	for index, row in ipairs(self.foodRow) do
		local info = infos[index]		
		row:setVisible(info ~= nil)

		if info ~= nil then			
			local valueText = self.l10n:formatVolume(info.value, 0)
			totalCapacity = info.capacity
			groupCapacity = info.groupCapacity
			totalValue = totalValue + info.value
			
			self.foodLabel[index]:setText(info.title)
			---total food ---			
			self.foodValue[index]:setText(valueText .. " [ " .. self.l10n:formatVolume(groupCapacity, 0) .. " ]")
			AdvancedHusbandryInfo:setTextColor(self.foodValue[index], info.groupRatio, info.invertedBar)
			self:setStatusBarValue(self.foodStatusBar[index], info.groupRatio, info.invertedBar)
			if consumptionType == 0 then consumptionType = info.consumpt end
		end
	end

	local totalValueText = self.l10n:formatVolume(totalValue, 0)
	local totalRatio = 0

	if totalCapacity > 0 then
		totalRatio = totalValue / totalCapacity
	end	
	
	self.foodRowTotalValue:setText(totalValueText .. " [ " .. self.l10n:formatVolume(totalCapacity, 0) .. " ]")
	self:setStatusBarValue(self.foodRowTotalStatusBar, totalRatio, false)
	AdvancedHusbandryInfo:setTextColor(self.foodRowTotalValue, totalRatio, false)
	self.foodHeader:setText(string.format("%s (%s)", g_i18n:getText("ui_total"), g_i18n:getText("animals_foodMixEffectiveness")))	
end

function AdvancedHusbandryInfo:updateConditionDisplay(superFunc, husbandry)
	local infos = husbandry:getConditionInfos()	
	
	for index, row in ipairs(self.conditionRow) do
		local info = infos[index]

		row:setVisible(info ~= nil)

		if info ~= nil then
			local valueText = info.valueText or self.l10n:formatVolume(info.value, 0, info.customUnitText)
			local fillGrade = 0
			if info.palletcapacity ~= nil then
				--- set text for pallets ---				
				valueText = valueText .. " [ " .. self.l10n:formatVolume(math.floor((info.value / info.palletcapacity)), 0, "") .. " / " .. self.l10n:formatVolume(info.maxpallets, 0, "") .. g_i18n:getText("category_pallets") .. " ]"
				fillGrade = info.value / info.palletcapacity * 100
			elseif info.capacity ~= nil then
				--- set text for all other filltypes than productivity ---
				valueText = valueText .. " [ " .. self.l10n:formatVolume(info.capacity, 0) .. " ]"
				fillGrade = info.value / info.capacity *100				
			end
			self.conditionLabel[index]:setText(info.title)
			self.conditionValue[index]:setText(valueText)
			AdvancedHusbandryInfo:setTextColor(self.conditionValue[index], info.ratio, info.invertedBar)
			self:setStatusBarValue(self.conditionStatusBar[index], info.ratio, info.invertedBar)
		end
	end
end

function AdvancedHusbandryInfo:displayCluster(superFunc, cluster, husbandry)
	if not g_currentMission.isRunning then
		return
	end

	local subTypeIndex = cluster:getSubTypeIndex()
	local age = cluster:getAge()
	local visual = g_currentMission.animalSystem:getVisualByAge(subTypeIndex, age)

	if visual ~= nil then
		local name = visual.store.name

		if cluster.getName ~= nil then
			name = cluster:getName()
		end

		self.animalDetailTypeNameText:setText(name)
		self.animalDetailTypeImage:setImageFilename(visual.store.imageFilename)

		local value = cluster:getSellPrice()
		local priceText = self.l10n:formatMoney(value, 0, true, true)

		self.animalDetailTypeValueText:setText(priceText)

		local ageText = self.l10n:formatNumMonth(age)

		self.animalAgeText:setText(ageText)

		local infos = husbandry:getAnimalInfos(cluster)

		for index, row in ipairs(self.infoRow) do
			local info = infos[index]

			row:setVisible(info ~= nil)

			if info ~= nil then
				local valueText = info.valueText or self.l10n:formatVolume(info.value, 0, info.customUnitText)
				local showStatusBar = Utils.getNoNil(info.showStatusBar, true)	
				self.infoLabel[index]:setText(info.title)
				self.infoValue[index]:setText(valueText)
				
				self:setStatusBarValue(self.infoStatusBar[index], info.ratio, info.invertedBar, info.disabled)
				
				self.infoStatusBar[index]:setVisible(showStatusBar)
				if self.infoStatusBar[index].parent ~= nil then self.infoStatusBar[index].parent:setVisible(showStatusBar) end
					
			end
		end

		local animalDescriptionText = husbandry:getAnimalDescription(cluster)

		self.detailDescriptionText:setText(animalDescriptionText)
	end

	self:updateConditionDisplay(husbandry)
	self:updateFoodDisplay(husbandry)
end

function AdvancedHusbandryInfo:getConditionInfosLiquidManure(superFunc, superFunc)
	local infos = superFunc(self)
	local spec = self.spec_husbandryLiquidManure
	local info = {}
	local fillType = g_fillTypeManager:getFillTypeByIndex(spec.fillType)
	info.title = fillType.title
	info.value = self:getHusbandryFillLevel(spec.fillType)
	info.isInput = false
	local capacity = self:getHusbandryCapacity(spec.fillType)
	local ratio = 0
	
	info.capacity = capacity or nil
	
	if capacity > 0 then
		ratio = info.value / capacity
	end

	info.ratio = MathUtil.clamp(ratio, 0, 1)
	info.invertedBar = true

	table.insert(infos, info)

	return infos
end

function AdvancedHusbandryInfo:getConditionInfosMilk(superFunc, superFunc)
	local spec = self.spec_husbandryMilk
	local infos = superFunc(self)
	local info = {}
	local fillType = g_fillTypeManager:getFillTypeByIndex(spec.fillType)
	info.title = fillType.title
	info.value = self:getHusbandryFillLevel(spec.fillType)
	info.isInput = false
	local capacity = self:getHusbandryCapacity(spec.fillType)
	local ratio = 0
	
	info.capacity = capacity or nil

	if capacity > 0 then
		ratio = info.value / capacity
	end

	info.ratio = MathUtil.clamp(ratio, 0, 1)
	info.invertedBar = true

	table.insert(infos, info)

	return infos
end

function AdvancedHusbandryInfo:getConditionInfosWater(superFunc, superFunc)
	local infos = superFunc(self)
	local spec = self.spec_husbandryWater

	if not spec.automaticWaterSupply then
		local info = {}
		local fillType = g_fillTypeManager:getFillTypeByIndex(spec.fillType)
		info.title = fillType.title
		info.value = self:getHusbandryFillLevel(spec.fillType)
		info.isInput= true
		local capacity = self:getHusbandryCapacity(spec.fillType)
		local ratio = 0
		
		info.capacity = capacity or nil
		
		if capacity > 0 then
			ratio = info.value / capacity
		end

		info.ratio = MathUtil.clamp(ratio, 0, 1)
		info.invertedBar = false

		table.insert(infos, info)
	end

	return infos
end

function AdvancedHusbandryInfo:getConditionInfosStraw(superFunc, superFunc)
	local infos = superFunc(self)
	local spec = self.spec_husbandryStraw
	local info = {}
	local fillType = g_fillTypeManager:getFillTypeByIndex(spec.inputFillType)
	info.title = fillType.title
	info.value = self:getHusbandryFillLevel(spec.inputFillType)
	info.isInput = true
	local capacity = self:getHusbandryCapacity(spec.inputFillType)
	local ratio = 0
	
	info.capacity = capacity or nil
	
	if capacity > 0 then
		ratio = info.value / capacity
	end

	info.ratio = MathUtil.clamp(ratio, 0, 1)
	info.invertedBar = false

	table.insert(infos, info)

	return infos
end

function AdvancedHusbandryInfo:getConditionInfosPallets(superFunc, superFunc)
	local infos = superFunc(self)
	local spec = self.spec_husbandryPallets
	local info = {}
	local fillType = g_fillTypeManager:getFillTypeByIndex(spec.fillTypeIndex)
	local ratio = 0
	
	info.title = fillType.title or nil
	info.value = spec.fillLevel	or 0
	info.palletcapacity = spec.palletSpawner.fillTypeIdToPallet[spec.fillTypeIndex].capacity or 0
	info.maxpallets = spec.maxNumPallets or 0
	info.isInput = false
	if spec.capacity > 0 then
		ratio = spec.fillLevel / spec.capacity
	end

	info.ratio = MathUtil.clamp(ratio, 0, 1)
	info.invertedBar = true
	info.customUnitText = spec.fillTypeUnit

	table.insert(infos, info)
	
	return infos
end

function AdvancedHusbandryInfo:updateInfoAnimals(superFunc, superFunc, infoTable)
	superFunc(self, infoTable)

	local spec = self.spec_husbandryAnimals
	local health = 0
	local numAnimals = 0
	local maxNumAnimals = spec:getMaxNumOfAnimals()
	local clusters = spec.clusterSystem:getClusters()
	local numClusters = #clusters

	if numClusters > 0 then
		for _, cluster in ipairs(clusters) do
			health = health + cluster.health
			numAnimals = numAnimals + cluster.numAnimals
		end

		health = health / numClusters
	end

	spec.infoNumAnimals.text = string.format("%d", numAnimals) .. " [ " .. string.format("%d", maxNumAnimals) .. " ]"
	spec.infoHealth.text = string.format("%d %%", health)

	table.insert(infoTable, spec.infoNumAnimals)
	table.insert(infoTable, spec.infoHealth)
end

function AdvancedHusbandryInfo:updateInfoFood(superFunc, superFunc, infoTable)
	superFunc(self, infoTable)

	local spec = self.spec_husbandryFood
	local fillLevel = self:getTotalFood()
	local maxFillLevel = self:getFoodCapacity()
	spec.info.text = g_i18n:formatVolume(fillLevel, 0) .. " [ " .. g_i18n:formatVolume(maxFillLevel, 0) .. " ]"

	table.insert(infoTable, spec.info)
end

function AdvancedHusbandryInfo:updateInfoLiquidManure(superFunc, superFunc, infoTable)
	superFunc(self, infoTable)

	local spec = self.spec_husbandryLiquidManure
	local fillLevel = self:getHusbandryFillLevel(spec.fillType)
	local maxFillLevel = self:getHusbandryCapacity(spec.fillType)
	spec.info.text = g_i18n:formatVolume(fillLevel, 0) .. " [ " .. g_i18n:formatVolume(maxFillLevel, 0) .. " ]"

	table.insert(infoTable, spec.info)
end

function AdvancedHusbandryInfo:updateInfoMilk(superFunc, superFunc, infoTable)
	local spec = self.spec_husbandryMilk

	superFunc(self, infoTable)

	local fillLevel = self:getHusbandryFillLevel(spec.fillType)
	local maxFillLevel = self:getHusbandryCapacity(spec.fillType)
	spec.info.text = g_i18n:formatVolume(fillLevel, 0) .. " [ " .. g_i18n:formatVolume(maxFillLevel, 0) .. " ]"

	table.insert(infoTable, spec.info)
end

function AdvancedHusbandryInfo:updateInfoStraw(superFunc, superFunc, infoTable)
	superFunc(self, infoTable)

	local spec = self.spec_husbandryStraw
	local fillLevel = self:getHusbandryFillLevel(spec.inputFillType)
	local maxFillLevel = self:getHusbandryCapacity(spec.inputFillType)	
	spec.info.text = g_i18n:formatVolume(fillLevel, 0) .. " [ " .. g_i18n:formatVolume(maxFillLevel, 0) .. " ]"	

	table.insert(infoTable, spec.info)
end

function AdvancedHusbandryInfo:updateInfoWater(superFunc, superFunc, infoTable)
	superFunc(self, infoTable)

	local spec = self.spec_husbandryWater

	if not spec.automaticWaterSupply then
		local fillLevel = self:getHusbandryFillLevel(spec.fillType)
		local maxFillLevel = self:getHusbandryCapacity(spec.fillType)
		spec.info.text = g_i18n:formatVolume(fillLevel, 0) .. " [ " .. g_i18n:formatVolume(maxFillLevel, 0) .. " ]"	

		table.insert(infoTable, spec.info)
	end
end

function AdvancedHusbandryInfo:updateInfoManureHeap(superFunc, superFunc, infoTable)
	superFunc(self, infoTable)

	local spec = self.spec_manureHeap

	if spec.manureHeap == nil then
		return
	end

	local fillLevel = spec.manureHeap:getFillLevel(spec.manureHeap.fillTypeIndex)
	local maxFillLevel = spec.manureHeap:getCapacity(spec.manureHeap.fillTypeIndex)
	spec.infoFillLevel.text = g_i18n:formatVolume(fillLevel, 0) .. " [ " .. g_i18n:formatVolume(maxFillLevel, 0) .. " ]"

	table.insert(infoTable, spec.infoFillLevel)
end

function AdvancedHusbandryInfo:updateInfoFeedingRobot(superFunc, infoTable)
	if self.infos ~= nil then
		for _, info in ipairs(self.infos) do			
			local fillLevel = 0
			local maxFillLevel = 0
			
			for _, fillType in ipairs(info.fillTypes) do
				--fillLevel = fillLevel + self:getFillLevel(fillType)
				local unloadingSpot = self.fillTypeToUnloadingSpot[fillType]				
				if unloadingSpot ~= nil then
					fillLevel = unloadingSpot.fillLevel or 0
					maxFillLevel = unloadingSpot.capacity or 0				
				end
			end

			info.text = g_i18n:formatVolume(fillLevel, 0) .. " [ " .. g_i18n:formatVolume(maxFillLevel, 0) .. " ]"	

			table.insert(infoTable, info)
		end
	end
end

function AdvancedHusbandryInfo:getTitleForSectionHeader(superFunc, list, section)
	local husbandry = self.sortedHusbandries[section]

	return husbandry:getName() .. " - " .. husbandry:getNumOfAnimals() .. " [ " .. husbandry:getMaxNumOfAnimals() .. " ]"	
end


function AdvancedHusbandryInfo:updateInfoPlaceableHusbandryBedding(superFunc, superFunc, infoTable)
	superFunc(self, infoTable)

	local spec = self.spec_husbandryBedding
	local fillLevel = self:getHusbandryFillLevel(spec.inputFillType)
	local maxFillLevel = self:getHusbandryCapacity(spec.inputFillType)
	spec.info.text = g_i18n:formatVolume(fillLevel, 0) .. " [ " .. g_i18n:formatVolume(maxFillLevel, 0) .. " ]"	
	table.insert(infoTable, spec.info)
end

function AdvancedHusbandryInfo:updateInfoManureSeparator(superFunc, superFunc, infoTable)
	superFunc(self, infoTable)

	local spec = self.spec_manureSeparator

	if spec.separator == nil then
		return
	end

	local fillLevel = spec.separator:getFillLevel(spec.separator.fillTypeIndex)
	local maxFillLevel = spec.separator:getCapacity(spec.separator.fillTypeIndex)
	spec.infoFillLevel.text = g_i18n:formatVolume(fillLevel, 0) .. " [ " .. g_i18n:formatVolume(maxFillLevel, 0) .. " ]"

	table.insert(infoTable, spec.infoFillLevel)
end


--- food display ---
InGameMenuAnimalsFrame.updateFoodDisplay = Utils.overwrittenFunction(InGameMenuAnimalsFrame.updateFoodDisplay, AdvancedHusbandryInfo.updateFoodDisplay)
PlaceableHusbandryFood.getFoodInfos = Utils.overwrittenFunction(PlaceableHusbandryFood.getFoodInfos, AdvancedHusbandryInfo.getFoodInfos)

PlaceableHusbandryAnimals.getAnimalInfos = Utils.overwrittenFunction(PlaceableHusbandryAnimals.getAnimalInfos, AdvancedHusbandryInfo.getAnimalInfos)

InGameMenuAnimalsFrame.displayCluster = Utils.overwrittenFunction(InGameMenuAnimalsFrame.displayCluster, AdvancedHusbandryInfo.displayCluster)


--- husbandry frame section title
InGameMenuAnimalsFrame.getTitleForSectionHeader = Utils.overwrittenFunction(InGameMenuAnimalsFrame.getTitleForSectionHeader, AdvancedHusbandryInfo.getTitleForSectionHeader)

--- condition display ---
PlaceableHusbandryPallets.getConditionInfos = Utils.overwrittenFunction(PlaceableHusbandryPallets.getConditionInfos, AdvancedHusbandryInfo.getConditionInfosPallets)
PlaceableHusbandryStraw.getConditionInfos = Utils.overwrittenFunction(PlaceableHusbandryStraw.getConditionInfos, AdvancedHusbandryInfo.getConditionInfosStraw)
PlaceableHusbandryWater.getConditionInfos = Utils.overwrittenFunction(PlaceableHusbandryWater.getConditionInfos, AdvancedHusbandryInfo.getConditionInfosWater)
PlaceableHusbandryMilk.getConditionInfos = Utils.overwrittenFunction(PlaceableHusbandryMilk.getConditionInfos, AdvancedHusbandryInfo.getConditionInfosMilk)
PlaceableHusbandryLiquidManure.getConditionInfos = Utils.overwrittenFunction(PlaceableHusbandryLiquidManure.getConditionInfos, AdvancedHusbandryInfo.getConditionInfosLiquidManure)

InGameMenuAnimalsFrame.updateConditionDisplay = Utils.overwrittenFunction(InGameMenuAnimalsFrame.updateConditionDisplay, AdvancedHusbandryInfo.updateConditionDisplay)

--- info tables ---
PlaceableHusbandryAnimals.updateInfo = Utils.overwrittenFunction(PlaceableHusbandryAnimals.updateInfo, AdvancedHusbandryInfo.updateInfoAnimals)
PlaceableHusbandryFood.updateInfo = Utils.overwrittenFunction(PlaceableHusbandryFood.updateInfo, AdvancedHusbandryInfo.updateInfoFood)
PlaceableHusbandryLiquidManure.updateInfo = Utils.overwrittenFunction(PlaceableHusbandryLiquidManure.updateInfo, AdvancedHusbandryInfo.updateInfoLiquidManure)
PlaceableHusbandryMilk.updateInfo = Utils.overwrittenFunction(PlaceableHusbandryMilk.updateInfo, AdvancedHusbandryInfo.updateInfoMilk)
PlaceableHusbandryStraw.updateInfo = Utils.overwrittenFunction(PlaceableHusbandryStraw.updateInfo, AdvancedHusbandryInfo.updateInfoStraw)
PlaceableHusbandryWater.updateInfo = Utils.overwrittenFunction(PlaceableHusbandryWater.updateInfo, AdvancedHusbandryInfo.updateInfoWater)
PlaceableManureHeap.updateInfo = Utils.overwrittenFunction(PlaceableManureHeap.updateInfo, AdvancedHusbandryInfo.updateInfoManureHeap)

FeedingRobot.updateInfo = Utils.overwrittenFunction(FeedingRobot.updateInfo, AdvancedHusbandryInfo.updateInfoFeedingRobot)

if g_modIsLoaded.pdlc_pumpsAndHosesPack then
	pdlc_pumpsAndHosesPack.PlaceableHusbandryBedding.updateInfo = Utils.overwrittenFunction(pdlc_pumpsAndHosesPack.PlaceableHusbandryBedding.updateInfo, AdvancedHusbandryInfo.updateInfoPlaceableHusbandryBedding)
	pdlc_pumpsAndHosesPack.ManureSeparatorPlaceable.updateInfo = Utils.overwrittenFunction(pdlc_pumpsAndHosesPack.ManureSeparatorPlaceable.updateInfo, AdvancedHusbandryInfo.updateInfoManureSeparator)
end
