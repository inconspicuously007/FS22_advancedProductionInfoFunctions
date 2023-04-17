---@class ChangeModSettingsEvent
ChangeModSettingsEvent = {}
ChangeModSettingsEvent_mt = Class(ChangeModSettingsEvent, Event)
InitEventClass(ChangeModSettingsEvent, "ChangeModSettingsEvent")

ChangeModSettingsEvent.NUM_BITS_SETTINGS_ID = 1
ChangeModSettingsEvent.NUM_BITS_STATE = 2

---Create instance of Event class
-- @return table self instance of class event
function ChangeModSettingsEvent.emptyNew()
    local self = Event.new(ChangeModSettingsEvent_mt)
    return self
end


---Create new instance of event
-- @param table object object
-- @param boolean isBlocked is blocked
function ChangeModSettingsEvent.new(settingsId, state)
    local self = ChangeModSettingsEvent.emptyNew()
    self.settingsId = settingsId
    self.state = state
    return self
end


---Called on client side on join
-- @param integer streamId streamId
-- @param integer connection connection
function ChangeModSettingsEvent:readStream(streamId, connection)
    self.settingsId = streamReadString(streamId, ChangeModSettingsEvent.NUM_BITS_SETTINGS_ID)
    self.state = streamReadInt8(streamId, ChangeModSettingsEvent.NUM_BITS_STATE)
    self:run(connection)
end


---Called on server side on join
-- @param integer streamId streamId
-- @param integer connection connection
function ChangeModSettingsEvent:writeStream(streamId, connection)
    streamWriteString(streamId, self.settingsId, ChangeModSettingsEvent.NUM_BITS_SETTINGS_ID)
    streamWriteInt8(streamId, self.state, ChangeModSettingsEvent.NUM_BITS_STATE)
end


---Run action on receiving side
-- @param integer connection connection
function ChangeModSettingsEvent:run(connection)
	ModSettings.settings[self.settingsId] = self.state	
    if g_server ~= nil and table.hasElement(ModSettings.globalSettings, self.settingsId) then
        g_server:broadcastEvent(self, false)
    end
end

---@class GlobalModSettingsEvent
GlobalModSettingsEvent = {}
local GlobalModSettingsEvent_mt = Class(GlobalModSettingsEvent, Event)

InitEventClass(GlobalModSettingsEvent, "GlobalModSettingsEvent")

function GlobalModSettingsEvent.emptyNew()
	local self = Event.new(GlobalModSettingsEvent_mt)
	return self
end

--- Creates a new Event
function GlobalModSettingsEvent.new(settings)
	local self = GlobalModSettingsEvent.emptyNew()
	self.settings = settings
	return self
end

--- Reads the serialized data on the receiving end of the event.
function GlobalModSettingsEvent:readStream(streamId, connection) -- wird aufgerufen wenn mich ein Event erreicht
	if g_server == nil then	
		self.settings = {}
		self.settings.palletLimit = streamReadUInt16(streamId)
		self.settings.productionPointLimit = streamReadUInt16(streamId)
		self.settings.husbandryLimit = streamReadUInt16(streamId)
        self:run(connection)
	end
end

--- Writes the serialized data from the sender.
function GlobalModSettingsEvent:writeStream(streamId, connection)  -- Wird aufgrufen wenn ich ein event verschicke (merke: reihenfolge der Daten muss mit der bei readStream uebereinstimmen 	
	streamWriteUInt16(streamId, self.settings.palletLimit)
	streamWriteUInt16(streamId, self.settings.productionPointLimit)
	streamWriteUInt16(streamId, self.settings.husbandryLimit)
end

--- Runs the event on the receiving end of the event.
function GlobalModSettingsEvent:run(connection) -- wir fuehren das empfangene event aus
	--- If the receiver was the client make sure every clients gets also updated.
	if g_server ~= nil then		
		g_server:broadcastEvent(GlobalModSettingsEvent.new(ModSettings.globalSettings),false)
		return
	end
	if self.settings ~= nil then
		ModSettings.globalSettings = self.settings
		ProductionChainManager.NUM_MAX_PRODUCTION_POINTS = ModSettings.globalSettings.productionPointLimit
		HusbandrySystem.GAME_LIMIT = ModSettings.globalSettings.husbandryLimit
		SlotSystem.NUM_OBJECT_LIMITS = {
			[SlotSystem.LIMITED_OBJECT_BALE] = {
				[PlatformId.WIN] = math.huge,
				[PlatformId.MAC] = math.huge,
				[PlatformId.PS4] = 200,
				[PlatformId.PS5] = 200,
				[PlatformId.XBOX_ONE] = 200,
				[PlatformId.XBOX_SERIES] = 200,
				[PlatformId.IOS] = 100,
				[PlatformId.ANDROID] = 100,
				[PlatformId.SWITCH] = 100,
				[PlatformId.GGP] = 200
			},
			[SlotSystem.LIMITED_OBJECT_PALLET] = {
				[PlatformId.WIN] = ModSettings.globalSettings.palletLimit,
				[PlatformId.MAC] = ModSettings.globalSettings.palletLimit,
				[PlatformId.PS4] = 75,
				[PlatformId.PS5] = 150,
				[PlatformId.XBOX_ONE] = 75,
				[PlatformId.XBOX_SERIES] = 150,
				[PlatformId.IOS] = 50,
				[PlatformId.ANDROID] = 50,
				[PlatformId.SWITCH] = 50,
				[PlatformId.GGP] = 50
			}
		}
	end
end

--function GlobalModSettingsEvent.sendEvent(setting)
--	if g_server ~= nil then
--		
--		g_server:broadcastEvent(GlobalModSettingsEvent.new(setting), nil, nil, nil)
--	else
--		g_client:getServerConnection():sendEvent(GlobalModSettingsEvent.new(setting))
--	end
--end
