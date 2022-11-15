AdvancedProductionPointInfo = {}
AdvancedProductionPointInfo.modDir = g_currentModDirectory

InGameMenuProductionFrame.VIEW_STATUS = {
	ALL = 0,
	ACTIVE = 1,	
	INACTIVE = 2
}
InGameMenuProductionFrame.VIEW_STATUS_NUM_BITS = 2
InGameMenuProductionFrame.VIEW_STATUS_TO_L10N = {
	[InGameMenuProductionFrame.VIEW_STATUS.ACTIVE] = "advprod_ui_production_showInActiveProductionList",
	[InGameMenuProductionFrame.VIEW_STATUS.INACTIVE] = "advprod_ui_production_showProductionList",
	[InGameMenuProductionFrame.VIEW_STATUS.ALL] = "advprod_ui_production_showActiveProductionList"	
}

InGameMenuProductionFrame.VIEW_TITLE_TO_L10N = {
	[InGameMenuProductionFrame.VIEW_STATUS.ACTIVE] = "advprod_ui_ingameMenuFrameHeaderTitleActive",
	[InGameMenuProductionFrame.VIEW_STATUS.INACTIVE] = "advprod_ui_ingameMenuFrameHeaderTitleInActive",
	[InGameMenuProductionFrame.VIEW_STATUS.ALL] = "advprod_ui_ingameMenuFrameHeaderTitleAll"	
}

g_gui:loadProfiles(AdvancedProductionPointInfo.modDir .. "gui/guiProfiles.xml")

AdvancedProductionPointInfo.CONTROLS = {
	"frameHeaderPanel",
	"frameHeaderText"
}

AdvancedProductionPointInfo.sandbox_types = {		
	TYPE_UNKNOWN = 0,
	TYPE_FERMENTER = 1,
	TYPE_POWERPLANT = 2,
	TYPE_SILO = 3,
	TYPE_BUNKER = 4,
	TYPE_TORCH = 5
}

AdvancedProductionPointInfo.sandbox_type_names = {
	[AdvancedProductionPointInfo.sandbox_types.TYPE_UNKNOWN] = "UNKNOWN",
	[AdvancedProductionPointInfo.sandbox_types.TYPE_FERMENTER] = "FERMENTER",
	[AdvancedProductionPointInfo.sandbox_types.TYPE_POWERPLANT] = "POWERPLANT",
	[AdvancedProductionPointInfo.sandbox_types.TYPE_SILO] = "SILO",
	[AdvancedProductionPointInfo.sandbox_types.TYPE_BUNKER] = "BUNKER",
	[AdvancedProductionPointInfo.sandbox_types.TYPE_TORCH] = "TORCH"
}
AdvancedProductionPointInfo.sandbox_utilization_states = {
	UNKNOWN = 0,
	RUNNING_NOT = 1,
	RUNNING_LIMIT = 2,
	RUNNING_PERFECT = 3,
	RUNNING_OK = 4,
	RUNNING_BAD = 5
}

function AdvancedProductionPointInfo:setTextColor(textElement, value, lowIsDanger)
	if ModSettings.userSettings.fillLevelColored ~= nil and ModSettings.userSettings.fillLevelColored == 2 then
		if lowIsDanger then
			if value >= InGameMenuProductionFrame.STATUS_BAR_HIGH then
				textElement:setTextColor(0.3763, 0.6038, 0.0782, 1)
			elseif value < InGameMenuProductionFrame.STATUS_BAR_LOW then
				textElement:setTextColor(0.8069, 0.0097, 0.0097, 1)
			else
				textElement:setTextColor(0.98, 0.42, 0, 1)
			end
		else
			if value >= InGameMenuProductionFrame.STATUS_BAR_HIGH then
				textElement:setTextColor(0.8069, 0.0097, 0.0097, 1)
			elseif value < InGameMenuProductionFrame.STATUS_BAR_LOW then
				textElement:setTextColor(0.3763, 0.6038, 0.0782, 1)
			else
				textElement:setTextColor(0.98, 0.42, 0, 1)
			end
		end
	else
		textElement:setTextColor(1, 1, 1, 1)
	end
end

function AdvancedProductionPointInfo:setUtilizationTextColor(textElement, value, lowIsDanger)
	if ModSettings.userSettings.fillLevelColored ~= nil and ModSettings.userSettings.fillLevelColored == 2 then		
		if value == AdvancedProductionPointInfo.sandbox_utilization_states.RUNNING_BAD or value == AdvancedProductionPointInfo.sandbox_utilization_states.RUNNING_LIMIT then
			textElement:setTextColor(0.8069, 0.0097, 0.0097, 1)
		elseif value == AdvancedProductionPointInfo.sandbox_utilization_states.RUNNING_PERFECT then
			textElement:setTextColor(0.3763, 0.6038, 0.0782, 1)
		else
			textElement:setTextColor(0.98, 0.42, 0, 1)
		end		
	else
		textElement:setTextColor(1, 1, 1, 1)
	end
end

function AdvancedProductionPointInfo:populateCellForItemInSection(superFunc, list, section, index, cell)
	
	--if g_modIsLoaded.pdlc_pumpsAndHosesPack then		
	--	local prodPoint = self:getProductionPoints()[section]		
	--	if prodPoint.owningPlaceable.isSandboxPlaceable ~= nil and prodPoint.owningPlaceable:isSandboxPlaceable() then				
	--		return superFunc(self, list, section, index, cell)	
	--	end	
	--end
	
	if list == self.productionList then
		local productionPoint = self:getProductionPoints()[section]
		
		--if g_modIsLoaded.pdlc_pumpsAndHosesPack then					
		--	if productionPoint.owningPlaceable.isSandboxPlaceable ~= nil and productionPoint.owningPlaceable:isSandboxPlaceable() then				
		--		return superFunc(self, list, section, index, cell)	
		--	end	
		--end
		
		
		
		local production = productionPoint.productions[index]
		if production ~= nil then
			local fillTypeDesc = g_fillTypeManager:getFillTypeByIndex(production.primaryProductFillType)

			if fillTypeDesc ~= nil then
				cell:getAttribute("icon"):setImageFilename(fillTypeDesc.hudOverlayFilename)
			end

			cell:getAttribute("icon"):setVisible(fillTypeDesc ~= nil)
			cell:getAttribute("name"):setText(production.name or fillTypeDesc.title)

			local status = production.status
			local activityElement = cell:getAttribute("activity")
		
			if status == ProductionPoint.PROD_STATUS.RUNNING then
				activityElement:applyProfile("adv_ingameMenuProductionProductionActivityActive")
			elseif status == ProductionPoint.PROD_STATUS.PAUSED then
				activityElement:applyProfile("adv_ingameMenuProductionProductionActivityPause")			
			elseif status == ProductionPoint.PROD_STATUS.MISSING_INPUTS or status == ProductionPoint.PROD_STATUS.NO_OUTPUT_SPACE then
				activityElement:applyProfile("adv_ingameMenuProductionProductionActivityIssue")
			else
				activityElement:applyProfile("adv_ingameMenuProductionProductionActivity")
			end
		end
	else
		local _, productionPoint = self:getSelectedProduction()
		
		--if g_modIsLoaded.pdlc_pumpsAndHosesPack then					
		--	if productionPoint.owningPlaceable.isSandboxPlaceable ~= nil and productionPoint.owningPlaceable:isSandboxPlaceable() then				
		--		return superFunc(self, list, section, index, cell)	
		--	end	
		--end
		
		local fillType, isInput = nil

		if section == 1 then
			fillType = self.selectedProductionPoint.inputFillTypeIdsArray[index]
			isInput = true
		else
			fillType = self.selectedProductionPoint.outputFillTypeIdsArray[index]
			isInput = false
		end

		if fillType ~= FillType.UNKNOWN then
			local fillLevel = self.selectedProductionPoint:getFillLevel(fillType)
			local capacity = self.selectedProductionPoint:getCapacity(fillType)
			local fillTypeDesc = g_fillTypeManager:getFillTypeByIndex(fillType)
			local fillGrade = fillLevel / capacity 
			local fillTypeTitle = fillTypeDesc.title
			if g_currentMission.animalSystem:getSubTypeByFillTypeIndex(fillType) ~= nil then				
				--titleInfo = "(" .. g_currentMission.animalSystem:getSubTypeByFillTypeIndex(fillType).visuals[1].store.name .. ")"
				--fillTypeTitle = fillTypeTitle .. " " .. titleInfo
				fillTypeTitle = g_currentMission.animalSystem:getSubTypeByFillTypeIndex(fillType).visuals[1].store.name
			end
			
			cell:getAttribute("icon"):setImageFilename(fillTypeDesc.hudOverlayFilename)
			cell:getAttribute("fillType"):setText(fillTypeTitle)
			cell:getAttribute("fillLevel"):setText(string.trim(self.i18n:formatVolume(fillLevel, 0, fillTypeDesc.unitShort)) .. " [ " .. string.trim(self.i18n:formatVolume(capacity, 0, fillTypeDesc.unitShort)) .. " ]")
						
			AdvancedProductionPointInfo:setTextColor(cell:getAttribute("fillLevel"), fillGrade, isInput)	
						
			if not isInput then
				local outputMode = productionPoint:getOutputDistributionMode(fillType)
				local outputModeText = g_i18n:getText("advprod_ui_production_output_storing")

				if outputMode == ProductionPoint.OUTPUT_MODE.DIRECT_SELL then
					outputModeText = g_i18n:getText("ui_production_output_selling")
				elseif outputMode == ProductionPoint.OUTPUT_MODE.AUTO_DELIVER then
					outputModeText = g_i18n:getText("ui_production_output_distributing")
				elseif outputMode == ProductionPoint.OUTPUT_MODE.SPAWN_PALLET then 
					outputModeText = g_i18n:getText("advprod_ui_production_output_spawn_pallets")	
				end

				cell:getAttribute("outputMode"):setText(outputModeText)
			end

			self:setStatusBarValue(cell:getAttribute("bar"), fillLevel / capacity, isInput)			
		end
	end	
end

function AdvancedProductionPointInfo:getProductionPoints_old(superFunc)
	local productionPoints = self.chainManager:getProductionPointsForFarmId(self.playerFarm.farmId)
	table.sort(productionPoints, function(a, b) return a:getName():upper() .. a.id < b:getName():upper() .. b.id end)
	for _, prodPoint in pairs(productionPoints) do
		table.sort(prodPoint.productions, function(a, b) return a.name:upper() .. a.id .. a.status < b.name:upper() .. b.id .. b.status end)
	end
	return productionPoints
end

function AdvancedProductionPointInfo:getProductionPoints(superFunc)
	local tmpProductionPoints = self.chainManager:getProductionPointsForFarmId(self.playerFarm.farmId)
	local filteredProductionPoints = {}	
	
	local numProductions = 0
	local numActiveProductions = 0
	
	local function filterProdPoints(prodPoints)
		local productionPoints = {}
		for _, prodPoint in ipairs(prodPoints) do
			local productionLines = {}
			if prodPoint.helperProductions == nil then
				prodPoint.helperProductions = prodPoint.productions
			end
			prodPoint.productions = prodPoint.helperProductions			 
			numProductions = numProductions + #prodPoint.productions
			numActiveProductions = numActiveProductions + #prodPoint.activeProductions
			if self.productionListState ~= nil then
				for _, production in ipairs(prodPoint.productions) do
					if self.productionListState == InGameMenuProductionFrame.VIEW_STATUS.ACTIVE then
						if production.status ~= ProductionPoint.PROD_STATUS.INACTIVE then 
							table.insert(productionLines, production)
						end
						
					elseif self.productionListState == InGameMenuProductionFrame.VIEW_STATUS.INACTIVE then
						if production.status == ProductionPoint.PROD_STATUS.INACTIVE then
							table.insert(productionLines, production)
						end
					elseif self.productionListState == InGameMenuProductionFrame.VIEW_STATUS.ALL then
						table.insert(productionLines, production)						
					end
				end
			else
				productionLines = prodPoint.helperProductions			
			end		
			
			if #productionLines > 0 then
				prodPoint.productions = productionLines		
				table.sort(prodPoint.productions, function(a, b) return a.name:upper() .. a.id .. a.status < b.name:upper() .. b.id .. b.status end)
				table.insert(productionPoints, prodPoint)
			end
		end
		return productionPoints
	end
	
	filteredProductionPoints = filterProdPoints(tmpProductionPoints)	
		
	if #filteredProductionPoints == 0 then		
		if self.productionListState == InGameMenuProductionFrame.VIEW_STATUS.ACTIVE then
			self.productionListState = InGameMenuProductionFrame.VIEW_STATUS.INACTIVE			
		elseif self.productionListState == InGameMenuProductionFrame.VIEW_STATUS.INACTIVE then
			self.productionListState = InGameMenuProductionFrame.VIEW_STATUS.ACTIVE			
		else
			self.productionListState = InGameMenuProductionFrame.VIEW_STATUS.ALL
		end
		filteredProductionPoints = filterProdPoints(tmpProductionPoints)
	end
	
	self.noActiveProdLines = false
	self.noInActiveProdLines = false
	
	if numProductions > 0 then
		if numActiveProductions == 0 then
			self.noActiveProdLines = true
		elseif numActiveProductions == numProductions then
			self.noInActiveProdLines = true
		end
	end
	
	table.sort(filteredProductionPoints, function(a, b) return a:getName():upper() .. a.id < b:getName():upper() .. b.id end)
	return filteredProductionPoints
end

function AdvancedProductionPointInfo:updateMenuButtons(superFunc)
	local isProductionListActive = self.productionList == FocusManager:getFocusedElement()	
	local btnText = g_i18n:getText(InGameMenuProductionFrame.VIEW_STATUS_TO_L10N[InGameMenuProductionFrame.VIEW_STATUS.ALL])
	
	if self.productionListState ~= nil then
		local curState = self.productionListState
		local nextState = curState + 1
		if table.hasElement(InGameMenuProductionFrame.VIEW_STATUS, nextState) and nextState == InGameMenuProductionFrame.VIEW_STATUS.ACTIVE and self.noActiveProdLines == true then
			btnText = g_i18n:getText(InGameMenuProductionFrame.VIEW_STATUS_TO_L10N[InGameMenuProductionFrame.VIEW_STATUS.ACTIVE])
		elseif table.hasElement(InGameMenuProductionFrame.VIEW_STATUS, nextState) and nextState == InGameMenuProductionFrame.VIEW_STATUS.INACTIVE and self.noInActiveProdLines == true then
			btnText = g_i18n:getText(InGameMenuProductionFrame.VIEW_STATUS_TO_L10N[InGameMenuProductionFrame.VIEW_STATUS.ALL])
		else
			btnText = g_i18n:getText(InGameMenuProductionFrame.VIEW_STATUS_TO_L10N[self.productionListState])
		end		
	end
	
	self.toggleProductionListViewButton = {
		profile = "buttonOK",
		inputAction = InputAction.MENU_EXTRA_1,
		text = btnText,
		callback = function ()
			self:toggleProductionList()
		end
	}	
	if isProductionListActive then		
		table.insert(self.menuButtonInfo, self.toggleProductionListViewButton)
	end
    self:setMenuButtonInfoDirty()
end

function InGameMenuProductionFrame:toggleProductionList()
	local defaultState = 0
	local curState = self.productionListState
	
	if curState == nil then 
		curState = defaultState		
	end
	
	local nextState = curState + 1
	
	if table.hasElement(InGameMenuProductionFrame.VIEW_STATUS, nextState) and nextState == InGameMenuProductionFrame.VIEW_STATUS.ACTIVE and self.noActiveProdLines == true then
		self.productionListState = InGameMenuProductionFrame.VIEW_STATUS.INACTIVE	
	elseif table.hasElement(InGameMenuProductionFrame.VIEW_STATUS, nextState) and nextState == InGameMenuProductionFrame.VIEW_STATUS.INACTIVE and self.noInActiveProdLines == true then
		self.productionListState = InGameMenuProductionFrame.VIEW_STATUS.ACTIVE
	else
		self.productionListState = nextState
	end
	ModSettings.userSettings.productionListState = self.productionListState
	self.productionList:reloadData()	
end

function AdvancedProductionPointInfo:onFrameOpen(superFunc, productionPoint)
	self.productionListState = 0	
	if ModSettings.userSettings.productionListState ~= nil then
		self.productionListState = ModSettings.userSettings.productionListState
	end
end

function AdvancedProductionPointInfo:onFrameClose()
	ModSettings:saveUserSettings()
end

function AdvancedProductionPointInfo:updateDetails(superFunc)
	local production, prodPoint = self:getSelectedProduction()	
	
	-- remove existing elements
	for i = #self.detailRecipeInputLayout.elements, 1, -1 do
		self.detailRecipeInputLayout.elements[i]:delete()
	end
	for i = #self.detailRecipeOutputLayout.elements, 1, -1 do
		self.detailRecipeOutputLayout.elements[i]:delete()
	end
	
	-- remove additional elements
	for i = #self.detailsBox.elements, 1, -1 do
		if self.detailsBox.elements[i] ~= nil and self.detailsBox.elements[i].additionalLine ~= nil and self.detailsBox.elements[i].additionalLine then
			self.detailsBox.elements[i]:delete()
		end
	end
	
	-- adjust arrow position to default
	self.detailsBox.elements[10].position[2] = self.detailRecipeInputLayout.position[2] - self.detailRecipeInputLayout.size[2] - (self.detailsBox.elements[10].size[2] / 2)	

	if g_modIsLoaded.pdlc_pumpsAndHosesPack and prodPoint.owningPlaceable.isSandboxPlaceable ~= nil and prodPoint.owningPlaceable:isSandboxPlaceable() then			
		return superFunc(self)					
	end	
	
	local status = production.status
	local statusKey = ProductionPoint.PROD_STATUS_TO_L10N[production.status] or "unknown"
	local statusProfile = "ingameMenuProductionDetailValue"

	if status == ProductionPoint.PROD_STATUS.MISSING_INPUTS then
		statusProfile = "ingameMenuProductionDetailValueError"
	elseif status == ProductionPoint.PROD_STATUS.NO_OUTPUT_SPACE then
		statusProfile = "ingameMenuProductionDetailValueError"
	end

	self.detailProductionStatus:applyProfile(statusProfile)	
	self.detailProductionStatus:setText(g_i18n:getText(ProductionPoint.PROD_STATUS_TO_L10N[production.status]))
	self.detailCyclesPerMonth:setText(MathUtil.round(production.cyclesPerMonth, 2))
	self.detailCostsPerMonth:setValue(production.costsPerActiveMonth)

	--add opening hours
	local myTxtElement = TextElement.new()
	local myTxtElement2 = TextElement.new()
	
	myTxtElement:copyAttributes(self.productionCostsDesc)	
	myTxtElement.text=g_i18n:getText("advprod_ui_production_opening")	
	--myTxtElement.absPosition[2] = self.productionCostsDesc.absPosition[2] + ((self.productionCostsDesc.absPosition[2] - self.productionCyclesDesc.absPosition[2]) - 0.2)		
	myTxtElement.position[2] = self.productionCostsDesc.position[2] + ((self.productionCostsDesc.position[2] - self.productionCyclesDesc.position[2]))		
	myTxtElement.additionalLine = true
	
	
	myTxtElement2:copyAttributes(self.detailCostsPerMonth)	
	myTxtElement2.text = string.format("%s - %s", self.selectedProductionPoint.openingHour, self.selectedProductionPoint.closingHour)	
	--myTxtElement2.absPosition[2] = self.detailCostsPerMonth.absPosition[2] + ((self.detailCostsPerMonth.absPosition[2] - self.detailCyclesPerMonth.absPosition[2]) - 0.2)	
	myTxtElement2.position[2] = self.detailCostsPerMonth.position[2] + ((self.detailCostsPerMonth.position[2] - self.detailCyclesPerMonth.position[2]))	
	myTxtElement2.additionalLine = true
	
	self.detailsBox:addElement(myTxtElement)
	self.detailsBox:addElement(myTxtElement2)
	
	myTxtElement:updateAbsolutePosition()
	myTxtElement2:updateAbsolutePosition()
	

	local function addIcons(list, layout)
		for i = 1, #layout.elements do
			layout.elements[1]:delete()
		end

		for index, item in ipairs(list) do
			
			if index > 1 then
				self.recipePlus:clone(layout)
			end

			if item.amount ~= 1 then
				local count = self.recipeText:clone(layout)

				count:setText(g_i18n:formatNumber(item.amount, 2))
			end

			local fillType = g_fillTypeManager:getFillTypeByIndex(item.type)
			local icon = self.recipeFillIcon:clone(layout)
			
			icon:setImageFilename(fillType.hudOverlayFilename)
		end

		layout:invalidateLayout()
	end
	
	local function addCustomIcons(list, layout)
		for i = 1, #layout.elements do
			layout.elements[1]:delete()
		end

		for index, item in ipairs(list) do
			
			if index > 1 then
				self.recipePlus:clone(layout)
			end

			if item.amount ~= 1 then
				local count = self.recipeText:clone(layout)

				count:setText(g_i18n:formatNumber(item.amount, 2))
			end

			local fillType = g_fillTypeManager:getFillTypeByIndex(item.type)
			local icon = self.recipeFillIcon:clone(layout)			
			icon:setImageFilename(fillType.hudOverlayFilename)
		end

		--layout:invalidateLayout()
	end
	
	--reset detailsBox
	--for i = #self.detailsBox.elements, 1, -1 do		
	--	if i >= 12 then
	--		if self.detailsBox.elements[i] ~= nil then
	--			self.detailsBox.elements[i]:delete()
	--		end
	--	end
	--end
	
	local myList = {}
	local listIndex = 1
	local inputsInRow = 3
	for index, item in ipairs(production.inputs) do			
		if myList[listIndex] == nil then
			myList[listIndex] = {}
		end
		
		table.insert(myList[listIndex], item)
		
		if index % inputsInRow == 0 then
			listIndex = listIndex + 1
		end
	end	
	
	--create recipe
	local lineCounter = 0
	for _, list in ipairs(myList) do
		if list ~= nil and #list ~= 0 then 
			--add plus between inputs
			if lineCounter ~= 0 then
				local myElement = FlowLayoutElement.new();
				myElement:copyAttributes(self.detailRecipeInputLayout);
				--myElement.absPosition[2] = self.detailRecipeInputLayout.absPosition[2] - (self.detailRecipeInputLayout.absSize[2] * (lineCounter))
				myElement.position[2] = self.detailRecipeInputLayout.position[2] - (self.detailRecipeInputLayout.size[2] * (lineCounter))
				myElement.additionalLine = true
				lineCounter = lineCounter + 1
				self.recipePlus:clone(myElement)
				self.detailsBox:addElement(myElement)
				myElement:updateAbsolutePosition()
				myElement:invalidateLayout()
			end
			
			local myElement = FlowLayoutElement.new();
			myElement:copyAttributes(self.detailRecipeInputLayout);
			--myElement.absPosition[2] = self.detailRecipeInputLayout.absPosition[2] - (self.detailRecipeInputLayout.absSize[2] * (lineCounter))
			myElement.position[2] = self.detailRecipeInputLayout.position[2] - (self.detailRecipeInputLayout.size[2] * (lineCounter))
			myElement.additionalLine = true
			
			lineCounter = lineCounter + 1
			--addCustomIcons(list, myElement)
			addIcons(list, myElement)
			self.detailsBox:addElement(myElement);
			myElement:updateAbsolutePosition()
			myElement:invalidateLayout()
		end
	end		
	
	--move arrow
	--self.detailsBox.elements[10].position[2] = self.detailRecipeInputLayout.position[2] - (self.detailRecipeInputLayout.size[2] * (lineCounter))
	self.detailsBox.elements[10].position[2] = self.detailRecipeInputLayout.position[2] - (self.detailRecipeInputLayout.size[2] * lineCounter) - (self.detailsBox.elements[10].size[2] / 2)
	self.detailsBox.elements[10]:updateAbsolutePosition()
	printf("self.detailsBox.elements[10].position[2].before: '%s'", self.detailsBox.elements[10].position[2])
	--move result list
	--self.detailRecipeOutputLayout.absPosition[2] = self.detailRecipeInputLayout.absPosition[2] - (self.detailRecipeInputLayout.absSize[2] * (lineCounter + 1))
	self.detailRecipeOutputLayout.position[2] = self.detailRecipeInputLayout.position[2] - (self.detailRecipeInputLayout.size[2] * (lineCounter + 1))
	self.detailRecipeOutputLayout:updateAbsolutePosition()
	
	--addIcons(production.inputs, self.detailRecipeInputLayout)
	addIcons(production.outputs, self.detailRecipeOutputLayout)
	self.storageList:reloadData()
end

function AdvancedProductionPointInfo:updateUtilizationOverviews(superFunc)
	local production, prodPoint = self:getSelectedProduction()	
	local status = production.status
	local statusKey = ProductionPoint.PROD_STATUS_TO_L10N[production.status] or "unknown"
	local statusProfile = "ingameMenuProductionDetailValue"

	if status == ProductionPoint.PROD_STATUS.MISSING_INPUTS then
		statusProfile = "ingameMenuProductionDetailValueError"
	elseif status == ProductionPoint.PROD_STATUS.NO_OUTPUT_SPACE then
		statusProfile = "ingameMenuProductionDetailValueError"
	end

	self.detailProductionStatus:applyProfile(statusProfile)	
	
	for _, utilizationBox in ipairs(self.utilizationTypes) do
		if utilizationBox.id ~= nil and self.selectedProductionPoint ~= nil and self.selectedProductionPoint.owningPlaceable ~= nil and self.selectedProductionPoint.owningPlaceable.getUtilizationPercentage ~= nil then
			local productionPointPlaceable = self.selectedProductionPoint.owningPlaceable

			if not productionPointPlaceable:isSandboxRoot() then
				productionPointPlaceable = productionPointPlaceable:getSandboxRootPlaceable()
			end

			local sandboxType = nil

			for type, name in pairs(AdvancedProductionPointInfo.sandbox_type_names) do
				if name == utilizationBox.id:upper() then
					sandboxType = type

					break
				end
			end

			if productionPointPlaceable ~= nil and sandboxType ~= nil then
				local mergedPlaceables = productionPointPlaceable:getMergedPlaceables()
				local mergedPlaceable = mergedPlaceables[sandboxType]
				local percentage = 0
				local specificMessage, forcedUtilizationState = nil

				if mergedPlaceable ~= nil then
					percentage, specificMessage, forcedUtilizationState = mergedPlaceable:getUtilizationPercentage()
				else
					specificMessage = g_i18n:getText("sandboxUtilization_typeRequired")
				end

				local utilizationState = AdvancedProductionPointInfo.sandbox_utilization_states.RUNNING_BAD

				if percentage > 1 then
					utilizationState = AdvancedProductionPointInfo.sandbox_utilization_states.RUNNING_LIMIT
				elseif percentage >= 0.75 and percentage <= 1 then
					utilizationState = AdvancedProductionPointInfo.sandbox_utilization_states.RUNNING_PERFECT
				elseif percentage > 0.25 and percentage < 0.75 then
					utilizationState = AdvancedProductionPointInfo.sandbox_utilization_states.RUNNING_OK
				end

				if forcedUtilizationState ~= nil then
					utilizationState = forcedUtilizationState
				end
				local percentageElement = self:getElementById(utilizationBox, "percentage", true)

				if percentageElement ~= nil then
					AdvancedProductionPointInfo:setUtilizationTextColor(percentageElement, utilizationState, true)
				end
			end
		end
	end
	--print("Debug: self.detailsBox.elements.utilizationBox")
	--DebugUtil.printTableRecursively(self.detailsBox.elements,"_",0,2)
	--local elm = self:getElementById(self.detailsBox, "utilizationBox", true)
	--DebugUtil.printTableRecursively(elm,"_",0,2)
end

function AdvancedProductionPointInfo:inject_populateCellForItemInSection(superFunc, superFunc, list, section, index, cell)
	--superFunc(self, list, section, index, cell)
	--print("Debug: inject_populateCellForItemInSection")
	--DebugUtil.printTableRecursively(self,"_",0,2)
	if list == self.productionList then
		local productionPoint = self:getProductionPoints()[section]
		local production = productionPoint.productions[index]
		local status = production.status
		local activityElement = cell:getAttribute("activity")
		
		if status == ProductionPoint.PROD_STATUS.RUNNING then
			activityElement:applyProfile("adv_ingameMenuProductionProductionActivityActive")
		elseif status == ProductionPoint.PROD_STATUS.PAUSED then
			activityElement:applyProfile("adv_ingameMenuProductionProductionActivityPause")			
		elseif status == ProductionPoint.PROD_STATUS.MISSING_INPUTS or status == ProductionPoint.PROD_STATUS.NO_OUTPUT_SPACE then
			activityElement:applyProfile("adv_ingameMenuProductionProductionActivityIssue")
		else
			activityElement:applyProfile("adv_ingameMenuProductionProductionActivity")
		end		
	end
end
--- update production list section ---
InGameMenuProductionFrame.getProductionPoints = Utils.overwrittenFunction(InGameMenuProductionFrame.getProductionPoints, AdvancedProductionPointInfo.getProductionPoints)
--- update menu buttons
InGameMenuProductionFrame.updateMenuButtons = Utils.appendedFunction(InGameMenuProductionFrame.updateMenuButtons, AdvancedProductionPointInfo.updateMenuButtons)

--- update fill level section ---
InGameMenuProductionFrame.populateCellForItemInSection = Utils.overwrittenFunction(InGameMenuProductionFrame.populateCellForItemInSection, AdvancedProductionPointInfo.populateCellForItemInSection)

--- set productionListState on frame open
InGameMenuProductionFrame.onFrameOpen = Utils.prependedFunction(InGameMenuProductionFrame.onFrameOpen, AdvancedProductionPointInfo.onFrameOpen)
--- set productionListState on frame open
InGameMenuProductionFrame.onFrameClose = Utils.prependedFunction(InGameMenuProductionFrame.onFrameClose, AdvancedProductionPointInfo.onFrameClose)
--- update production receipe section---
InGameMenuProductionFrame.updateDetails = Utils.overwrittenFunction(InGameMenuProductionFrame.updateDetails, AdvancedProductionPointInfo.updateDetails)

if g_modIsLoaded.pdlc_pumpsAndHosesPack then
	--print("Debug: g_modIsLoaded.pdlc_pumpsAndHosesPack")
	InGameMenuProductionFrame.updateUtilizationOverviews = Utils.appendedFunction(InGameMenuProductionFrame.updateUtilizationOverviews, AdvancedProductionPointInfo.updateUtilizationOverviews)
	InGameMenuProductionFrame.inject_populateCellForItemInSection = Utils.appendedFunction(InGameMenuProductionFrame.inject_populateCellForItemInSection, AdvancedProductionPointInfo.inject_populateCellForItemInSection)
end 

--print("Debug: g_modIsLoaded")
--DebugUtil.printTableRecursively(g_modIsLoaded,"_",0,2)