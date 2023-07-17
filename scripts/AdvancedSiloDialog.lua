AdvancedSiloDialog = {}

function AdvancedSiloDialog:setFillLevels(superFunc, fillLevels, hasInfiniteCapacity)
	self.fillLevels = fillLevels
	self.fillTypeMapping = {}
	local fillTypesTable = {}
	local selectedId = 1
	local numFillLevels = 1

	for fillTypeIndex, _ in pairs(fillLevels) do
		local fillType = g_fillTypeManager:getFillTypeByIndex(fillTypeIndex)
		local level = Utils.getNoNil(fillLevels[fillTypeIndex], 0)
		local name = nil

		if hasInfiniteCapacity then
			name = string.format("%s", fillType.title)
		else
			name = string.format("%s %s", fillType.title, g_i18n:formatFluid(level))
		end
		
		if level > 0 then
			table.insert(fillTypesTable, name)
			table.insert(self.fillTypeMapping, fillTypeIndex)
			numFillLevels = numFillLevels + 1
		end	
		

		if fillTypeIndex == self.lastSelectedFillType then
			selectedId = numFillLevels
		end

		
	end

	self.fillTypesElement:setTexts(fillTypesTable)
	self.fillTypesElement:setState(selectedId, true)
end

SiloDialog.setFillLevels = Utils.overwrittenFunction(SiloDialog.setFillLevels, AdvancedSiloDialog.setFillLevels)