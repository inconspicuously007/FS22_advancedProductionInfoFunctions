AdvancedSiloDialog = {}

function AdvancedSiloDialog:setFillLevels(superFunc, fillLevels, hasInfiniteCapacity)
	self.fillLevels = {}
	
	--print("Debug: self.fillLevels")
	--DebugUtil.printTableRecursively(self.fillLevels,"_",0,3)
	
	self.fillTypeMapping = {}
	local fillTypesTable = {}
	local fillTypesTableAll = {}
	local fillTypeMappingAll = {}
	local fillTypeMappingFill = {}
	local selectedId = 1
	local numFillLevels = 1

	for fillTypeIndex, fillLevel in pairs(fillLevels) do
		local fillType = g_fillTypeManager:getFillTypeByIndex(fillTypeIndex)
		local level = Utils.getNoNil(fillLevels[fillTypeIndex], 0)
		local name = nil

		if hasInfiniteCapacity then
			name = string.format("%s", fillType.title)
		else
			name = string.format("%s %s", fillType.title, g_i18n:formatFluid(level))
		end
		
		table.insert(fillTypeMappingAll, fillTypeIndex)	
		table.insert(fillTypesTableAll, name)	
		if level > 0 then
			self.fillLevels[fillTypeIndex] = fillLevel
			table.insert(fillTypesTable, name)	
			table.insert(fillTypeMappingFill, fillTypeIndex)			
			if fillTypeIndex == self.lastSelectedFillType then
				selectedId = numFillLevels
			end
			numFillLevels = numFillLevels + 1
		end		
	end
	if numFillLevels < 2 then
		self.fillLevels = fillLevels
		self.fillTypesElement:setTexts(fillTypesTableAll)
		self.fillTypeMapping = fillTypeMappingAll
	else
		self.fillTypesElement:setTexts(fillTypesTable)
		self.fillTypeMapping = fillTypeMappingFill
	end
	self.fillTypesElement:setState(selectedId, true)
end

SiloDialog.setFillLevels = Utils.overwrittenFunction(SiloDialog.setFillLevels, AdvancedSiloDialog.setFillLevels)