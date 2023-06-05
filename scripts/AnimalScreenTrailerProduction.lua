AnimalScreenTrailerProduction = {}
local AnimalScreenTrailerProduction_mt = Class(AnimalScreenTrailerProduction, AnimalScreenBase)

function AnimalScreenTrailerProduction.new(production, trailer, customMt)
    local self = AnimalScreenBase.new(customMt or AnimalScreenTrailerProduction_mt)
    self.production = production
    self.trailer = trailer

    return self
end

function AnimalScreenTrailerProduction:initSourceItems()
    self.sourceItems = {}
    local clusters = self.trailer:getClusters()

    if clusters ~= nil then
        for _, cluster in ipairs(clusters) do
            local item = AnimalItemStock.new(cluster)

            table.insert(self.sourceItems, item)
        end
    end
end

function AnimalScreenTrailerProduction:initTargetItems()
    self.targetItems = {}
    --[[local clusters = {}
    for key, animalSubType in pairs(self.production.supportedAnimalSubTypes) do
        local cluster = g_currentMission.animalSystem:createClusterFromSubTypeIndex(animalSubType.subTypeIndex)
        cluster.numAnimals = 10
        cluster.age = 36
        table.insert(clusters, cluster)
        print("Debug: AnimalScreenTrailerProduction:initTargetItems")
        DebugUtil.printTableRecursively(cluster,"_",0,2)
    end

    if clusters ~= nil then
        for _, cluster in ipairs(clusters) do
            local item = AnimalItemStock.new(cluster)

            table.insert(self.targetItems, item)
        end
    end]]

    --[[local clusters = self.husbandry:getClusters()

    if clusters ~= nil then
        for _, cluster in ipairs(clusters) do
            local item = AnimalItemStock.new(cluster)

            table.insert(self.targetItems, item)
        end
    end]]
    --TODO
end

function AnimalScreenTrailerProduction:getSourceName()
    local name = self.trailer:getName()
    local currentAnimalType = self.trailer:getCurrentAnimalType()

    if currentAnimalType == nil then
        return name
    end

    local used = self.trailer:getNumOfAnimals()
    local total = self.trailer:getMaxNumOfAnimals(currentAnimalType)

    return string.format("%s (%d / %d)", name, used, total)
end

function AnimalScreenTrailerProduction:getTargetName()
    local name = self.production.name or AnimalScreenTrailerProduction.L10N_SYMBOL.FARM
    local clusters = self.trailer:getClusters()
    if #clusters > 0 and #clusters == 1 then
        local cluster = clusters[1]
        local subType = g_currentMission.animalSystem:getSubTypeByIndex(cluster:getSubTypeIndex())
        local fillType = self.production.animalSubTypeToFillType[subType.fillTypeIndex]
        local used = self.production.storage:getFillLevel(fillType.index)
        local total = self.production.storage:getCapacity(fillType.index) or 0

        return string.format("%s (%d / %d)", name, used, total)
    end

    return name
end

function AnimalScreenTrailerProduction:getSourceActionText()
    return g_i18n:getText(AnimalScreenTrailerProduction.L10N_SYMBOL.MOVE_TO_FARM)
end

function AnimalScreenTrailerProduction:getTargetActionText()
    return g_i18n:getText(AnimalScreenTrailerProduction.L10N_SYMBOL.MOVE_TO_TRAILER)
end

function AnimalScreenTrailerProduction:getApplySourceConfirmationText(itemIndex, numItems)
    local text = g_i18n:getText(AnimalScreenTrailerProduction.L10N_SYMBOL.CONFIRM_MOVE_TO_FARM)
    local item = self.sourceItems[itemIndex]

    return string.format(text, numItems, item:getName())
end

function AnimalScreenTrailerProduction:getApplyTargetConfirmationText(itemIndex, numItems)
    local text = g_i18n:getText(AnimalScreenTrailerProduction.L10N_SYMBOL.CONFIRM_MOVE_TO_TRAILER)
    local item = self.targetItems[itemIndex]

    return string.format(text, numItems, item:getName())
end

function AnimalScreenTrailerProduction:getSourcePrice(itemIndex, numItems)
    return false, 0, 0, 0
end

function AnimalScreenTrailerProduction:getTargetPrice(itemIndex, numItems)
    return false, 0, 0, 0
end

function AnimalScreenTrailerProduction:getSourceMaxNumAnimals(itemIndex)
    local item = self.sourceItems[itemIndex]
    local maxNumAnimals = self:getMaxNumAnimals()

    return math.min(maxNumAnimals, item:getNumAnimals(), self:getNumOfFreeAnimalSlotsProduction(itemIndex))
end

function AnimalScreenTrailerProduction:getNumOfFreeAnimalSlotsProduction(itemIndex)
    local item = self.sourceItems[itemIndex]
    local cluster = self.trailer:getClusterById(item:getClusterId())
    local subType = g_currentMission.animalSystem:getSubTypeByIndex(cluster:getSubTypeIndex())
    local fillType = self.production.animalSubTypeToFillType[subType.fillTypeIndex]
    local freeCapacity = self.production.storage:getFreeCapacity(fillType.index)
    local fillTypeRatio = self.production.animalSubTypeToFillTypeRatio[subType.fillTypeIndex]
    local fillLevelPerAnimal = fillTypeRatio * cluster:getAgeFactor() * math.max(cluster:getHealthFactor(), 0.1)

    return math.floor(freeCapacity/fillLevelPerAnimal)
end

function AnimalScreenTrailerProduction:getTargetMaxNumAnimals(itemIndex)
    local item = self.targetItems[itemIndex]
    local animalSystem = g_currentMission.animalSystem
    local subType = animalSystem:getSubTypeByIndex(item:getSubTypeIndex())
    local animalType = animalSystem:getTypeByIndex(subType.typeIndex)
    local used = self.trailer:getNumOfAnimals()
    local total = self.trailer:getMaxNumOfAnimals(animalType)
    local free = total - used
    local maxNumAnimals = self:getMaxNumAnimals()

    return math.min(maxNumAnimals, free, item:getNumAnimals())
end

function AnimalScreenTrailerProduction:applySource(itemIndex, numItems)
    local item = self.sourceItems[itemIndex]
    local clusterId = item:getClusterId()
    local errorCode = AnimalMoveProductionEvent.validate(self.trailer, self.production, clusterId, numItems, self.trailer:getOwnerFarmId())

    if errorCode ~= nil then
        local data = AnimalScreenTrailerProduction.MOVE_TO_PRODUCTION_ERROR_CODE_MAPPING[errorCode]

        self.errorCallback(g_i18n:getText(data.text))

        return false
    end

    local text = g_i18n:getText(AnimalScreenTrailerProduction.L10N_SYMBOL.MOVE_TO_FARM)

    self.actionTypeCallback(AnimalScreenBase.ACTION_TYPE_SOURCE, text)
    g_messageCenter:subscribe(AnimalMoveProductionEvent, self.onAnimalMovedToProduction, self)
    g_client:getServerConnection():sendEvent(AnimalMoveProductionEvent.new(self.trailer, self.production, clusterId, numItems))

    return true
end

function AnimalScreenTrailerProduction:onAnimalMovedToProduction(errorCode)
    g_messageCenter:unsubscribe(AnimalMoveProductionEvent, self)
    self.actionTypeCallback(AnimalScreenBase.ACTION_TYPE_NONE, nil)

    local data = AnimalScreenTrailerProduction.MOVE_TO_PRODUCTION_ERROR_CODE_MAPPING[errorCode]

    self.sourceActionFinished(data.isWarning, g_i18n:getText(data.text))
end

function AnimalScreenTrailerProduction:applyTarget(itemIndex, numItems)
    local item = self.targetItems[itemIndex]
    local clusterId = item:getClusterId()
    local errorCode = AnimalMoveProductionEvent.validate(self.production, self.trailer, clusterId, numItems, self.trailer:getOwnerFarmId())

    if errorCode ~= nil then
        local data = AnimalScreenTrailerProduction.MOVE_TO_PRODUCTION_ERROR_CODE_MAPPING[errorCode]

        self.errorCallback(g_i18n:getText(data.text))

        return false
    end

    local text = g_i18n:getText(AnimalScreenTrailerProduction.L10N_SYMBOL.MOVE_TO_TRAILER)

    self.actionTypeCallback(AnimalScreenBase.ACTION_TYPE_TARGET, text)
    g_messageCenter:subscribe(AnimalMoveProductionEvent, self.onAnimalMovedToTrailer, self)
    g_client:getServerConnection():sendEvent(AnimalMoveProductionEvent.new(self.production, self.trailer, clusterId, numItems))

    return true
end

function AnimalScreenTrailerProduction:onAnimalMovedToTrailer(errorCode)
    g_messageCenter:unsubscribe(AnimalMoveProductionEvent, self)
    self.actionTypeCallback(AnimalScreenBase.ACTION_TYPE_NONE, nil)

    local data = AnimalScreenTrailerProduction.MOVE_TO_PRODUCTION_ERROR_CODE_MAPPING[errorCode]

    self.targetActionFinished(data.isWarning, g_i18n:getText(data.text))
end

function AnimalScreenTrailerProduction:onAnimalsChanged(obj, clusters)
    if obj == self.trailer or obj == self.production then
        self:initItems()
        self.animalsChangedCallback()
    end
end

AnimalScreenTrailerProduction.L10N_SYMBOL = {
    FARM = "advprod_ui_productionPoint",
    CONFIRM_MOVE_TO_TRAILER = "shop_doYouWantToMoveAnimalsToTrailer",
    MOVE_TO_FARM = "advprod_ui_moveToProduction",
    CONFIRM_MOVE_TO_FARM = "advprod_ui_confirmMoveToProduction",
    MOVE_TO_TRAILER = "shop_moveToTrailer"
}

AnimalScreenTrailerProduction.MOVE_TO_TRAILER_ERROR_CODE_MAPPING = {
    [AnimalMoveProductionEvent.MOVE_SUCCESS] = {
        text = "shop_movedToTrailer",
        warning = false
    },
    [AnimalMoveProductionEvent.MOVE_ERROR_NO_PERMISSION] = {
        text = "shop_messageNoPermissionToTradeAnimals",
        warning = true
    },
    [AnimalMoveProductionEvent.MOVE_ERROR_SOURCE_OBJECT_DOES_NOT_EXIST] = {
        text = "shop_messageHusbandryDoesNotExist",
        warning = true
    },
    [AnimalMoveProductionEvent.MOVE_ERROR_TARGET_OBJECT_DOES_NOT_EXIST] = {
        text = "shop_messageTrailerDoesNotExist",
        warning = true
    },
    [AnimalMoveProductionEvent.MOVE_ERROR_INVALID_CLUSTER] = {
        text = "shop_messageInvalidCluster",
        warning = true
    },
    [AnimalMoveProductionEvent.MOVE_ERROR_ANIMAL_NOT_SUPPORTED] = {
        text = "shop_messageAnimalTypeNotSupportedByTrailer",
        warning = true
    },
    [AnimalMoveProductionEvent.MOVE_ERROR_NOT_ENOUGH_SPACE] = {
        text = "shop_messageNotEnoughSpaceAnimalsTrailer",
        warning = true
    },
    [AnimalMoveProductionEvent.MOVE_ERROR_NOT_ENOUGH_ANIMALS] = {
        text = "shop_messageNotEnoughAnimals",
        warning = true
    }
}
AnimalScreenTrailerProduction.MOVE_TO_PRODUCTION_ERROR_CODE_MAPPING = {
    [AnimalMoveProductionEvent.MOVE_SUCCESS] = {
        text = "advprod_ui_movedToProduction",
        warning = false
    },
    [AnimalMoveProductionEvent.MOVE_ERROR_NO_PERMISSION] = {
        text = "shop_messageNoPermissionToTradeAnimals",
        warning = true
    },
    [AnimalMoveProductionEvent.MOVE_ERROR_SOURCE_OBJECT_DOES_NOT_EXIST] = {
        text = "shop_messageTrailerDoesNotExist",
        warning = true
    },
    [AnimalMoveProductionEvent.MOVE_ERROR_TARGET_OBJECT_DOES_NOT_EXIST] = {
        text = "advprod_ui_messageProductionDoesNotExist",
        warning = true
    },
    [AnimalMoveProductionEvent.MOVE_ERROR_INVALID_CLUSTER] = {
        text = "shop_messageInvalidCluster",
        warning = true
    },
    [AnimalMoveProductionEvent.MOVE_ERROR_ANIMAL_NOT_SUPPORTED] = {
        text = "shop_messageAnimalTypeNotSupported",
        warning = true
    },
    [AnimalMoveProductionEvent.MOVE_ERROR_NOT_ENOUGH_SPACE] = {
        text = "shop_messageNotEnoughSpaceAnimals",
        warning = true
    },
    [AnimalMoveProductionEvent.MOVE_ERROR_NOT_ENOUGH_ANIMALS] = {
        text = "shop_messageNotEnoughAnimals",
        warning = true
    },
    [AnimalMoveProductionEvent.MOVE_ERROR_ANIMAL_NOT_SUPPORTED_AGE] = {
        text = "advprod_ui_messageAnimalTypeNotSupportedAge",
        warning = true
    },
    [AnimalMoveProductionEvent.MOVE_ERROR_ANIMAL_NOT_SUPPORTED_HEALTH] = {
        text = "advprod_ui_messageAnimalTypeNotSupportedHealth",
        warning = true
    }
}
