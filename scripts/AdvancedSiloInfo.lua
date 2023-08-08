AdvancedSiloInfo = {}

PlaceableSilo.INFO_TRIGGER_NUM_DISPLAYED_FILLTYPES = 25

function AdvancedSiloInfo:updateInfoSilo(superFunc, superFunc, infoTable)

	superFunc(self, infoTable)

	local spec = self.spec_silo
	local farmId = g_currentMission:getFarmId()
	local sourceStorages = spec.loadingStation:getSourceStorages()
    local totalCapacity = 0;
	local totalExtensionCapacity = 0
	local sourceCapacity = 0
	local totalFillLevel = 0
	local totalExtensions = 0
	local storageTable = {}
	local extensionTable = {}
	
	table.clear(spec.fillTypesAndLevelsAuxiliary)
	table.clear(spec.infoTriggerFillTypesAndLevels)	
	
	for _, storage in pairs(sourceStorages) do
		
		if spec.loadingStation:hasFarmAccessToStorage(farmId, storage) then
			totalCapacity = totalCapacity + storage.capacity
			if storage.isExtension then
				totalExtensionCapacity = totalExtensionCapacity + storage.capacity
				totalExtensions = totalExtensions + 1
			else				
				local capacities = nil
				if table.size(storage.capacities) > 0 then
					capacities = storage.capacities
				end
				storageTable[storage.id] = storageTable[storage.id] or {
					capacity = storage.capacity,
					capacities = capacities,
					extension = storage.isExtension
				}
			end
			
			for _, unloadingStation in pairs(storage.unloadingStations) do
				if self:getName() ~= unloadingStation:getName() then
					extensionTable[unloadingStation:getName()] = unloadingStation:getName()
				end
			end
			
			for fillTypeID, fillLevel in pairs(storage.fillLevels) do
				if fillLevel > 0.1 then
					if spec.fillTypesAndLevelsAuxiliary[fillTypeID] ~= nil then
						local newFillLevel = 0
						local oldFillLevel = 0
						oldFillLevel = spec.fillTypesAndLevelsAuxiliary[fillTypeID].fillLevel or 0
						newFillLevel = oldFillLevel + fillLevel
						spec.fillTypesAndLevelsAuxiliary[fillTypeID].fillLevel = newFillLevel
					else
						local capacity = nil
						if storage.capacities ~= nil then capacity = storage.capacities[fillTypeID] or nil else capacity = storage.capacity end
						spec.fillTypesAndLevelsAuxiliary[fillTypeID] = {
							fillType = fillTypeID,
							fillLevel = fillLevel,
							capacity = capacity
						}
					end					
					totalFillLevel = totalFillLevel + fillLevel					
				end
			end
		end
	end
	
	
	for key, value in pairs(spec.fillTypesAndLevelsAuxiliary) do		
		table.insert(spec.infoTriggerFillTypesAndLevels, spec.fillTypesAndLevelsAuxiliary[key])
	end
	
	
	table.sort(spec.infoTriggerFillTypesAndLevels, function (a, b)		
		return b.fillLevel < a.fillLevel		
	end)
	
	table.sort(storageTable, function (a, b)		
		return b.extension < a.extension		
	end)
	
	local numEntries = math.min(#spec.infoTriggerFillTypesAndLevels, PlaceableSilo.INFO_TRIGGER_NUM_DISPLAYED_FILLTYPES)

	if numEntries > 0 then
		table.insert(infoTable, 
			{
				title = g_i18n:getText("advsilo_ui_fill_level"),
				accentuate = true 
			}
		)
		for i = 1, numEntries do
			local fillTypeAndLevel = spec.infoTriggerFillTypesAndLevels[i]
			local fillLevelText = g_i18n:formatVolume(fillTypeAndLevel.fillLevel, 0) 
			if fillTypeAndLevel.capacity ~= nil then
				fillLevelText = fillLevelText .. " [ " .. g_i18n:formatVolume(fillTypeAndLevel.capacity, 0) .. " ]"
			end
			table.insert(infoTable, {
				title = g_fillTypeManager:getFillTypeTitleByIndex(fillTypeAndLevel.fillType),
				text = fillLevelText
				
			})
		end
	else
		table.insert(infoTable, {
			text = "",
			title = g_i18n:getText("infohud_siloEmpty")
		})
	end
    
    table.insert(infoTable, 
        {
            title = g_i18n:getText("advsilo_ui_storage_capacities"), 
            accentuate = true 
        }
    )
    
    table.insert(infoTable,
        {
            title = g_i18n:getText("advsilo_ui_storage_used_capacity"),
            text = g_i18n:formatVolume(totalFillLevel, 0)
        }
    )
    
	local capacityText = nil
	local capacityTitle = nil
	for id, info in pairs(storageTable) do		
		sourceCapacity = sourceCapacity + info.capacity
		capacityText = g_i18n:formatVolume(sourceCapacity, 0)
		capacityTitle = g_i18n:getText("advsilo_ui_storage_source")
		if info.capacities ~= nil then
			capacityText = g_i18n:getText("advsilo_ui_storage_capacity_by_filltype")
		
		end				
	end
	--- total capcity ---
	if totalCapacity > 0 then
		table.insert(infoTable,
			{
				title = g_i18n:getText("advsilo_ui_storage_capacity_total"), 
				text = g_i18n:formatVolume(totalCapacity, 0)
			}
		)
	else
		table.insert(infoTable,
			{
				title = g_i18n:getText("advsilo_ui_storage_capacity_total"), 
				text = capacityText
			}
		)
	end
	
	
	--- extensions ---
	if totalExtensions > 0 then
		if capacityTitle ~= nil or capacityText ~= nil then
			table.insert(infoTable,
				{
					title = capacityTitle, 
					text = capacityText
				}
			)
		end
		table.insert(infoTable,
			{
				title = g_i18n:getText("advsilo_ui_storage_capacity_extensions"), 
				text = g_i18n:formatVolume(totalExtensionCapacity, 0)
			}
		) 
		
		--- connected placeables ---
		local count = 0
		for _, connectedPlaceableName in pairs(extensionTable) do
			if count == 0 then
				table.insert(infoTable, 
					{
						title = g_i18n:getText("advsilo_ui_connected_placeables"), 
						accentuate = true 
					}
				)
			end
			table.insert(infoTable,
				{
					title = "", 
					text = tostring(connectedPlaceableName)
				}
			)
			count = count + 1
		end			
	end	
end

PlaceableSilo.updateInfo = Utils.overwrittenFunction(PlaceableSilo.updateInfo, AdvancedSiloInfo.updateInfoSilo)
