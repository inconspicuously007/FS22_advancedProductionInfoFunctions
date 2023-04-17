AdvancedProductionPointPalletSpawn = {}

function AdvancedProductionPointPalletSpawn:updateMenuButtons(superFunc)
	local isProductionListActive = self.productionList == FocusManager:getFocusedElement()
	if not isProductionListActive then
		local production, productionPoint = self:getSelectedProduction()
		local fillType, isInput = self:getSelectedStorageFillType()
		if productionPoint.palletSpawner ~= nil and fillType ~= FillType.UNKNOWN and productionPoint.outputFillTypeIdsToPallets[fillType] ~= nil then
			self.spawnPalletButton = {
				profile = "buttonOK",
				inputAction = InputAction.MENU_EXTRA_2,
				text = btnText,
				callback = function ()
					AdvancedProductionPointPalletSpawn:outputSelected(productionPoint, fillType)
				end
			}
			table.insert(self.menuButtonInfo, self.spawnPalletButton)			
		end
	end
	self:setMenuButtonInfoDirty()
end

function AdvancedProductionPointPalletSpawn:outputSelected(productionPoint, fillType)
	-- multiple choice dialog 
	local selectableOptions = {}
	local options = {};
			
	-- Auswahl erstellen
	for i, possibilitie in pairs (possibilities) do
		table.insert(selectableOptions, {fillLevel=selectedArg.fillLevel, possibilitie=possibilitie, fillType=currentFillType, productionPoint=rproductionPoint});
		table.insert(options, g_i18n:getText("Revamp_SpawnType_"..possibilitie));
	end

	-- Dialogbox erstellen
	local dialogArguments = {
		text = g_i18n:getText("Revamp_ChooseSpawnToPutOut") .. " - " .. currentFillType.title .. " (" .. RevampHelper:formatVolume(selectedArg.fillLevel, 0, currentFillType.unitShort) .. ")",
		title = rproductionPoint:getName(),
		options = options,
		target = self,
		args = selectableOptions,
		callback = self.spawnTypeSelected
	}

	--TODO: hack to reset the "remembered" option (i.e. solve a bug in the game engine)
	local dialog = g_gui.guis["OptionDialog"]
	if dialog ~= nil then
		dialog.target:setOptions({""}) -- Add fake option to force a "reset"
	end

	g_gui:showOptionDialog(dialogArguments)
	return
end


--- update menu buttons
InGameMenuProductionFrame.updateMenuButtons = Utils.appendedFunction(InGameMenuProductionFrame.updateMenuButtons, AdvancedProductionPointPalletSpawn.updateMenuButtons)