--!strict
local _Package = script
local _Packages = _Package.Parent
-- Services
local RunService = game:GetService("RunService")
-- Packages
local Maid = require(_Packages:WaitForChild("Maid"))
local ServiceProxy = require(_Packages:WaitForChild("ServiceProxy"))
-- Modules
local Door = require(script:WaitForChild("Door"))
local Animator = require(script:WaitForChild("Animator"))
-- Types
export type Door = Door.Door
type Maid = Maid.Maid
export type DoorService = {
	__index: DoorService,
	_Maid: Maid,
	_IsAlive: boolean,
	_Registry: {[Model]: Door},
	RegisterDoor: (self: DoorService, inst: Model) -> Door,
	GetDoor: (self: DoorService, door: Model) -> Door?,
	_RemoveDoor: (self: DoorService, door: Model) -> (),
	Destroy: (self: DoorService) -> (),
	new: () -> DoorService,
	init: (maid: Maid) -> nil
}
-- Constants

-- Variables
-- References
-- Private Functions
-- Class
local CurrentDoorService: DoorService = nil :: any
local DoorService = {} :: DoorService
DoorService.__index = DoorService

function DoorService:Destroy()
	if not self._IsAlive then return end
	self._IsAlive = false
	if CurrentDoorService == self then
		CurrentDoorService = nil :: any
	end
	self._Maid:Destroy()
	local t: any = self
	for k, v in pairs(t) do
		t[k] = nil
	end
	setmetatable(t, nil)
end

function DoorService:GetDoor(inst: Model): Door?
	assert(RunService:IsServer())
	return self._Registry[inst]
end

function DoorService:RegisterDoor(inst: Model): Door
	assert(RunService:IsServer())
	assert(self:GetDoor(inst) == nil, `Door already registered for {inst:GetFullName()}`)
	local doorMaid = self._Maid:GiveTask(Maid.new())

	local door = self._Maid:GiveTask(Door.new(inst))
	self._Registry[inst] = door

	doorMaid:GiveTask(door._OnDestroying:Connect(function()
		self._Registry[inst] = nil
		doorMaid:Destroy()
	end))

	return door
end

function DoorService:_RemoveDoor(inst: Model): ()
	assert(RunService:IsServer())
	local door = self:GetDoor(inst)
	if door then
		door:Destroy()
		self._Registry[inst] = nil
	end
end

function DoorService.new()

	local self: DoorService = setmetatable({}, DoorService) :: any
	self._IsAlive = true
	self._Maid = Maid.new()
	self._Registry = {}

	if RunService:IsClient() then
		Animator.init(self._Maid)
	end

	if CurrentDoorService ~= nil then
		 CurrentDoorService:Destroy()
		 CurrentDoorService = nil :: any
	end
	CurrentDoorService = self

	return self
end

function DoorService.init(maid: Maid)
	maid:GiveTask(DoorService.new())
	return nil
end

return ServiceProxy(function()
	return CurrentDoorService or DoorService
end)
