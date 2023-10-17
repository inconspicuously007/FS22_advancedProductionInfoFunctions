AnimalToProductionTrigger = {}
local AnimalToProductionTrigger_mt = Class(AnimalToProductionTrigger)

InitObjectClass(AnimalToProductionTrigger, "AnimalToProductionTrigger")

function AnimalToProductionTrigger:onCreate(id)
    local trigger = AnimalToProductionTrigger.new(g_server ~= nil, g_client ~= nil)

    if trigger ~= nil then
        if trigger:load(id) then
            g_currentMission:addNonUpdateable(trigger)
        else
            trigger:delete()
        end
    end
end

function AnimalToProductionTrigger.new(isServer, isClient)
    local self = Object.new(isServer, isClient, AnimalToProductionTrigger_mt)
    self.customEnvironment = g_currentMission.loadingMapModName
    --self.isDealer = false
    self.triggerNode = nil
    self.title = g_i18n:getText("ui_farm")
    self.animals = nil
    self.activatable = AnimalToProductionTriggerActivatable.new(self)
    self.isPlayerInRange = false
    self.isEnabled = false
    self.loadingVehicle = nil
    self.activatedTarget = nil

    return self
end

function AnimalToProductionTrigger:load(node, production)
    self.production = production
    --self.isDealer = false

    self.triggerNode = node
    self.isEnabled = true
    self.title = self.production.title

    addTrigger(self.triggerNode, "triggerCallback", self)

    --self.title = g_i18n:getText(Utils.getNoNil(getUserAttribute(node, "title"), "ui_farm"), self.customEnvironment)
    self.isEnabled = true

    return true
end

function AnimalToProductionTrigger:delete()
    g_currentMission.activatableObjectsSystem:removeActivatable(self.activatable)

    if self.triggerNode ~= nil then
        removeTrigger(self.triggerNode)

        self.triggerNode = nil
    end

    self.production = nil
end

function AnimalToProductionTrigger:triggerCallback(triggerId, otherId, onEnter, onLeave, onStay)
    if self.isEnabled and (onEnter or onLeave) then
        local vehicle = g_currentMission.nodeToObject[otherId]

        if vehicle ~= nil and vehicle.getSupportsAnimalType ~= nil then
            if onEnter then
                self:setLoadingTrailer(vehicle)
            elseif onLeave then
                if vehicle == self.loadingVehicle then
                    self:setLoadingTrailer(nil)
                end

                if vehicle == self.activatedTarget then
                    g_animalScreen:onVehicleLeftTrigger()
                end
            end

            if GS_IS_MOBILE_VERSION and onEnter and self.activatable:getIsActivatable() then
                self:openAnimalMenu()

                local rootVehicle = vehicle.rootVehicle

                if rootVehicle.brakeToStop ~= nil then
                    rootVehicle:brakeToStop()
                end
            end
        elseif g_currentMission.player ~= nil and otherId == g_currentMission.player.rootNode then
            if onEnter then
                self.isPlayerInRange = true

                if GS_IS_MOBILE_VERSION then
                    self:openAnimalMenu()
                end
            else
                self.isPlayerInRange = false
            end

            self:updateActivatableObject()
        end
    end
end

function AnimalToProductionTrigger:updateActivatableObject()
    if self.loadingVehicle ~= nil or self.isPlayerInRange then
        g_currentMission.activatableObjectsSystem:addActivatable(self.activatable)
    elseif self.loadingVehicle == nil and not self.isPlayerInRange then
        g_currentMission.activatableObjectsSystem:removeActivatable(self.activatable)
    end
end

function AnimalToProductionTrigger:setLoadingTrailer(loadingVehicle)
    if self.loadingVehicle ~= nil and self.loadingVehicle.setLoadingTrigger ~= nil then
        self.loadingVehicle:setLoadingTrigger(nil)
    end

    self.loadingVehicle = loadingVehicle

    if self.loadingVehicle ~= nil and self.loadingVehicle.setLoadingTrigger ~= nil then
        self.loadingVehicle:setLoadingTrigger(self)
    end

    self:updateActivatableObject()
end

function AnimalToProductionTrigger:showAnimalScreen(production)
    if self.loadingVehicle == nil then
        g_gui:showInfoDialog({
            text = g_i18n:getText("advprod_ui_messageNoLoadingTrailer")
        })

        return
    end

    local controller = nil

    if self.loadingVehicle ~= nil then
        controller = AnimalScreenTrailerProduction.new(production, self.loadingVehicle)
    end

    if controller ~= nil then
        controller:init()
        --g_animalScreen:setController(controller)
        --g_gui:showGui("AnimalScreen")
		g_animalProductionScreen:setController(controller)
		g_gui:showGui("AnimalProductionScreen")
		g_animalProductionScreen.balanceElement:setValue(nil)
    end
end

function AnimalToProductionTrigger:onSelectedHusbandry(husbandry)
    if husbandry ~= nil then
        self:showAnimalScreen(husbandry)
    else
        self:updateActivatableObject()
    end
end

function AnimalToProductionTrigger:getAnimals()
    return self.animalTypes
end

function AnimalToProductionTrigger:openAnimalMenu()
    local husbandry = self.production

    self:showAnimalScreen(husbandry)

    self.activatedTarget = self.loadingVehicle
end

AnimalToProductionTriggerActivatable = {}
local AnimalToProductionTriggerActivatable_mt = Class(AnimalToProductionTriggerActivatable)

function AnimalToProductionTriggerActivatable.new(animalToProductionTrigger)
    local self = setmetatable({}, AnimalToProductionTriggerActivatable_mt)
    self.owner = animalToProductionTrigger
    self.activateText = g_i18n:getText("animals_openAnimalScreen", animalToProductionTrigger.customEnvironment)

    return self
end

function AnimalToProductionTriggerActivatable:getIsActivatable()
    local owner = self.owner

    if not owner.isEnabled then
        return false
    end

    if g_gui.currentGui ~= nil then
        return false
    end

    if not g_currentMission:getHasPlayerPermission("tradeAnimals") then
        return false
    end

    local canAccess = owner.production == nil or owner.production:getOwnerFarmId() == g_currentMission:getFarmId()

    if not canAccess then
        return false
    end

    local rootAttacherVehicle = nil

    if owner.loadingVehicle ~= nil then
        rootAttacherVehicle = owner.loadingVehicle.rootVehicle
    end

    return rootAttacherVehicle == g_currentMission.controlledVehicle
end

function AnimalToProductionTriggerActivatable:run()
    self.owner:openAnimalMenu()
end

function AnimalToProductionTriggerActivatable:getDistance(x, y, z)
    if self.owner.triggerNode ~= nil then
        local tx, ty, tz = getWorldTranslation(self.owner.triggerNode)

        return MathUtil.vector3Length(x - tx, y - ty, z - tz)
    end

    return math.huge
end
