AdvancedProductionPointPalletSpawner = {}

function AdvancedProductionPointPalletSpawner:updateMenuButtons(superFunc)
	local isProductionListActive = self.productionList == FocusManager:getFocusedElement()
	if not isProductionListActive then
		local production, productionPoint = self:getSelectedProduction()
		local fillType, isInput = self:getSelectedStorageFillType()
		if productionPoint.palletSpawner ~= nil and fillType ~= FillType.UNKNOWN and productionPoint.outputFillTypeIdsToPallets[fillType] ~= nil then
			self.spawnPalletButton = {
				profile = "buttonOK",
				inputAction = InputAction.MENU_EXTRA_2,
				text = g_i18n:getText("advprod_ui_production_spawnPallet"),
				callback = function ()
					AdvancedProductionPointPalletSpawner:outputSelected(productionPoint, fillType)
				end
			}
			table.insert(self.menuButtonInfo, self.spawnPalletButton)			
		end
	end
	self:setMenuButtonInfoDirty()
end

function AdvancedProductionPointPalletSpawner:outputSelected(productionPoint, fillTypeId)
		
	local fillLevelPerPallet = productionPoint.palletSpawner.fillTypeIdToPallet[fillTypeId].capacity
	local fillLevel = productionPoint.storage:getFillLevel(fillTypeId)
	local fillType = g_fillTypeManager:getFillTypeByIndex(fillTypeId)
	local maxPallets = math.ceil(fillLevel / fillLevelPerPallet)
	
	if maxPallets == 0 then return end
	
	local dialogArgs = {}
	local dialogOpts = {}
	
	for x=1, maxPallets do 
		local palletText = g_i18n:getText("advprod_ui_production_pallets")
		if x == 1 then palletText = g_i18n:getText("advprod_ui_production_pallet") end
		table.insert(dialogArgs, {count=x, fillLevelPerPallet=fillLevelPerPallet, fillTypeId=fillTypeId, productionPoint=productionPoint, fillLevel=math.min((fillLevelPerPallet*x), fillLevel)})
		table.insert(dialogOpts, x .. " " .. palletText .. " [ " .. g_i18n:formatVolume(math.min((fillLevelPerPallet*x), fillLevel), 0) .. " ]")
	end	
	
    local dialogValues = {        
		text = g_i18n:getText("advprod_ui_production_amount"),
        title = productionPoint:getName() .. " - " .. fillType.title,
        options = dialogOpts,
        target = self,
        args = dialogArgs,
        callback = AdvancedProductionPointPalletSpawner.palletsSelected
    }
    
    if g_gui.guis["OptionDialog"] ~= nil then
        g_gui.guis["OptionDialog"].target:setOptions({""})
    end
    g_gui:showOptionDialog(dialogValues)	
end

function AdvancedProductionPointPalletSpawner:palletsSelected(selectedOption, selectedArgs)
	local selectedValue = selectedArgs[selectedOption]
	if selectedValue ~= nil then		
		AdvancedProductionPointPalletSpawnerEvent.sendEvent(selectedValue.productionPoint, selectedValue.fillTypeId, selectedValue.fillLevel, selectedValue.count)
	else
		return
	end
end



AdvancedProductionPointPalletSpawnerEvent = {}
local AdvancedProductionPointPalletSpawnerEvent_mt = Class(AdvancedProductionPointPalletSpawnerEvent, Event)
InitEventClass(AdvancedProductionPointPalletSpawnerEvent, "AdvancedProductionPointPalletSpawnerEvent")

function AdvancedProductionPointPalletSpawnerEvent.emptyNew()
  local self = Event.new(AdvancedProductionPointPalletSpawnerEvent_mt)
  return self
end

function AdvancedProductionPointPalletSpawnerEvent.new(productionPoint, fillTypeId, fillLevel, palletCount)
  local self = AdvancedProductionPointPalletSpawnerEvent.emptyNew()
  self.productionPoint = productionPoint  
  self.fillTypeId = fillTypeId
  self.fillLevel = fillLevel
  self.palletCount = palletCount
  return self
end

function AdvancedProductionPointPalletSpawnerEvent:readStream(streamId, connection)
  self.productionPoint = NetworkUtil.readNodeObject(streamId)  
  self.fillTypeId = streamReadInt32(streamId)
  self.fillLevel = streamReadFloat32(streamId)
  self.palletCount = streamReadInt32(streamId)
  self:run(connection)
end

function AdvancedProductionPointPalletSpawnerEvent:writeStream(streamId, connection)
  NetworkUtil.writeNodeObject(streamId, self.productionPoint)   
  streamWriteInt32(streamId, self.fillTypeId)
  streamWriteFloat32(streamId, self.fillLevel)
  streamWriteInt32(streamId, self.palletCount)
end

function AdvancedProductionPointPalletSpawnerEvent:run(connection)
  self.productionPoint:manualSpawnPallets(self.fillTypeId, self.fillLevel, self.palletCount)
  --self.productionPoint.palletSpawner:spawnPallet(self.productionPoint:getOwnerFarmId(), self.fillTypeId, self.productionPoint.palletSpawnRequestCallback, self.productionPoint)
end

function AdvancedProductionPointPalletSpawnerEvent.sendEvent(productionPoint, fillTypeId, fillLevel, palletCount)
  g_client:getServerConnection():sendEvent(AdvancedProductionPointPalletSpawnerEvent.new(productionPoint, fillTypeId, fillLevel, palletCount))
end


--- update menu buttons
InGameMenuProductionFrame.updateMenuButtons = Utils.appendedFunction(InGameMenuProductionFrame.updateMenuButtons, AdvancedProductionPointPalletSpawner.updateMenuButtons)