AnimalMoveProductionEvent = {
    MOVE_SUCCESS = 0,
    MOVE_ERROR_NO_PERMISSION = 1,
    MOVE_ERROR_SOURCE_OBJECT_DOES_NOT_EXIST = 2,
    MOVE_ERROR_TARGET_OBJECT_DOES_NOT_EXIST = 3,
    MOVE_ERROR_INVALID_CLUSTER = 4,
    MOVE_ERROR_ANIMAL_NOT_SUPPORTED = 5,
    MOVE_ERROR_NOT_ENOUGH_SPACE = 6,
    MOVE_ERROR_NOT_ENOUGH_ANIMALS = 7,
    MOVE_ERROR_NOT_ENOUGH_MONEY = 2,
    MOVE_ERROR_ANIMAL_NOT_SUPPORTED_AGE = 8,
    MOVE_ERROR_ANIMAL_NOT_SUPPORTED_HEALTH = 9
}
local AnimalMoveProductionEvent_mt = Class(AnimalMoveProductionEvent, Event)

InitEventClass(AnimalMoveProductionEvent, "AnimalMoveProductionEvent")

function AnimalMoveProductionEvent.emptyNew()
    local self = Event.new(AnimalMoveProductionEvent_mt)

    return self
end

function AnimalMoveProductionEvent.new(sourceObject, targetObject, clusterId, numAnimals)
    local self = AnimalMoveProductionEvent.emptyNew()
    self.sourceObject = sourceObject
    self.targetObject = targetObject
    self.clusterId = clusterId
    self.numAnimals = numAnimals

    return self
end

function AnimalMoveProductionEvent.newServerToClient(errorCode)
    local self = AnimalMoveProductionEvent.emptyNew()
    self.errorCode = errorCode

    return self
end

function AnimalMoveProductionEvent:readStream(streamId, connection)
    if not connection:getIsServer() then
        self.sourceObject = NetworkUtil.readNodeObject(streamId)
        self.targetObject = NetworkUtil.readNodeObject(streamId)
        self.clusterId = streamReadInt32(streamId)
        self.numAnimals = streamReadUInt8(streamId)
    else
        self.errorCode = streamReadUIntN(streamId, 3)
    end

    self:run(connection)
end

function AnimalMoveProductionEvent:writeStream(streamId, connection)
    if connection:getIsServer() then
        NetworkUtil.writeNodeObject(streamId, self.sourceObject)
        NetworkUtil.writeNodeObject(streamId, self.targetObject)
        streamWriteInt32(streamId, self.clusterId)
        streamWriteUInt8(streamId, self.numAnimals)
    else
        streamWriteUIntN(streamId, self.errorCode, 3)
    end
end

function AnimalMoveProductionEvent:run(connection)
    if not connection:getIsServer() then
        local uniqueUserId = g_currentMission.userManager:getUniqueUserIdByConnection(connection)
        local farm = g_farmManager:getFarmForUniqueUserId(uniqueUserId)
        local farmId = farm.farmId
        local errorCode = AnimalMoveProductionEvent.validate(self.sourceObject, self.targetObject, self.clusterId, self.numAnimals, farmId)

        if errorCode ~= nil then
            connection:sendEvent(AnimalMoveProductionEvent.newServerToClient(errorCode))

            return
        end

        local cluster = self.sourceObject:getClusterById(self.clusterId)
        local subType = g_currentMission.animalSystem:getSubTypeByIndex(cluster:getSubTypeIndex())
        local fillType = self.targetObject.supportedAnimalSubTypes[subType.fillTypeIndex].fillType
        local fillTypeRatio = self.targetObject.supportedAnimalSubTypes[subType.fillTypeIndex].fillTypeRatio
        local deltaFillLevel = fillTypeRatio * self.numAnimals
        local fillLevel = self.targetObject.storage:getFillLevel(fillType.index)
        self.targetObject.storage:setFillLevel(fillLevel + deltaFillLevel, fillType.index)

        local clusterSystem = self.sourceObject:getClusterSystem()
        cluster:changeNumAnimals(-self.numAnimals)
        clusterSystem:updateNow()
        connection:sendEvent(AnimalMoveProductionEvent.newServerToClient(AnimalMoveProductionEvent.MOVE_SUCCESS))
    else
        g_messageCenter:publish(AnimalMoveProductionEvent, self.errorCode)
    end
end

function AnimalMoveProductionEvent.validate(sourceObject, targetObject, clusterId, numAnimals, farmId)
    if sourceObject == nil then
        return AnimalMoveProductionEvent.MOVE_ERROR_SOURCE_OBJECT_DOES_NOT_EXIST
    end

    if targetObject == nil then
        return AnimalMoveProductionEvent.MOVE_ERROR_TARGET_OBJECT_DOES_NOT_EXIST
    end

    if not g_currentMission.accessHandler:canFarmAccess(farmId, sourceObject) then
        return AnimalMoveProductionEvent.MOVE_ERROR_NO_PERMISSION
    end

    if not g_currentMission.accessHandler:canFarmAccess(farmId, targetObject) then
        return AnimalMoveProductionEvent.MOVE_ERROR_NO_PERMISSION
    end

    local cluster = sourceObject:getClusterById(clusterId)

    if cluster == nil then
        return AnimalMoveProductionEvent.MOVE_ERROR_INVALID_CLUSTER
    end

    if cluster:getNumAnimals() < numAnimals then
        return AnimalMoveProductionEvent.MOVE_ERROR_NOT_ENOUGH_ANIMALS
    end

    local clusterValid = true
    local subType = g_currentMission.animalSystem:getSubTypeByIndex(cluster:getSubTypeIndex())
    local fillType = targetObject.supportedAnimalSubTypes[subType.fillTypeIndex].fillType


    if fillType == nil then
        clusterValid = false
        return AnimalMoveProductionEvent.MOVE_ERROR_ANIMAL_NOT_SUPPORTED
    end

    if fillType ~= nil then
        local animalAgeFactor = targetObject.supportedAnimalSubTypes[subType.fillTypeIndex].animalMinAge
        local animalHealthFactor = targetObject.supportedAnimalSubTypes[subType.fillTypeIndex].animalMinHealth

        if cluster:getAge() < animalAgeFactor then
            clusterValid = false
            return AnimalMoveProductionEvent.MOVE_ERROR_ANIMAL_NOT_SUPPORTED_AGE
        end
        if cluster:getHealthFactor() < animalHealthFactor then
            clusterValid = false
            return AnimalMoveProductionEvent.MOVE_ERROR_ANIMAL_NOT_SUPPORTED_HEALTH
        end
    end

    if clusterValid then
        local freeCapacity = targetObject.storage:getFreeCapacity(fillType.index)
        local fillTypeRatio = targetObject.animalSubTypeToFillTypeRatio[subType.fillTypeIndex]
        --local fillLevel = numAnimals * fillTypeRatio * cluster:getAgeFactor() * math.max(cluster:getHealthFactor(), 0.1)
        local fillLevel = numAnimals * fillTypeRatio
        if freeCapacity < fillLevel then
            return AnimalMoveProductionEvent.MOVE_ERROR_NOT_ENOUGH_SPACE
        end
    end
end
