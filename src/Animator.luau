--!strict
--!native
local _Package = script.Parent
local _Packages = _Package.Parent
-- Services
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
-- Packages
local Maid = require(_Packages:WaitForChild("Maid"))
local NetworkUtil = require(_Packages:WaitForChild("NetworkUtil"))
local Spring = require(_Packages:WaitForChild("Spring"))
-- Modules
local Config = require(_Package:WaitForChild("Config"))
-- Types
-- Constants
local UPDATE_DOOR_PROP_REMOTE_EVENT_KEY = Config.Remotes.Events.UpdateDoorProp
local GET_DOOR_PROP_INFO_REMOTE_FUNCTION_KEY = Config.Remotes.Functions.GetDoorPropInfo
local DOOR_PROP_TAG = Config.Tags.DoorProp
local UPDATE_MAID_KEY = "_UPDATE"
local SMALL = 0.001
-- Variables
-- References
-- Private Functions
-- Class
-- Types
type Maid = Maid.Maid
type ReplicationData = Config.ReplicationData
type PropInstance = Model | BasePart
export type DoorAnimator = {
	__index: DoorAnimator,
	_Maid: Maid,
	_IsAlive: boolean,
	Instance: PropInstance,
	Destroy: (self: DoorAnimator) -> (),
	new: (inst: PropInstance) -> DoorAnimator,
	init: (maid: Maid) -> nil
}

-- Class
local DoorAnimator = {} :: DoorAnimator
DoorAnimator.__index = DoorAnimator

function DoorAnimator:Destroy()
	if not self._IsAlive then return end
	self._IsAlive = false
	self._Maid:Destroy()
	local t: any = self
	for k, v in pairs(t) do
		t[k] = nil
	end
	setmetatable(t, nil)
end

function DoorAnimator.new(inst: PropInstance)

	local self: DoorAnimator = setmetatable({}, DoorAnimator) :: any
	self._IsAlive = true
	self._Maid = Maid.new()
	self.Instance = inst
	
	task.wait()
	local anchor: BasePart
	local initialRepData: ReplicationData
	local anchorOffset: CFrame
	initialRepData, anchor, anchorOffset = NetworkUtil.invokeServerAt(GET_DOOR_PROP_INFO_REMOTE_FUNCTION_KEY, self.Instance)
	self.Instance:PivotTo(anchor.CFrame * anchorOffset * initialRepData.Goal)

	local function getGoalPosition(repData: ReplicationData): number
		return if repData.IsOpen then if repData.IsInward then 1 else -1 else 0
	end

	local currentGoal = initialRepData.Goal
	local currentPosition = getGoalPosition(initialRepData)

	local function update(repData: ReplicationData)
		local updateMaid = Maid.new()
		local goalPosition = getGoalPosition(repData)

		local priorGoal = currentGoal
		currentGoal = repData.Goal
			
		local spring = Spring.new(
			repData.DampingRatio,
			repData.Frequency,
			currentPosition
		)
		spring:Set(goalPosition)

		if repData.StartSound and math.abs(spring.Velocity) <= SMALL then
			local startSound = repData.StartSound:Clone()
			startSound.PlayOnRemove = true
			startSound.Parent = inst
			startSound:Destroy()
		end
		if repData.LoopingSound then
			local loopSound = repData.LoopingSound:Clone()
			loopSound.Looped = true
			loopSound.Parent = inst
			updateMaid:GiveTask(function()
				loopSound:Stop()
				loopSound:Destroy()
			end)
			loopSound:Play()
		end

		self._Maid[UPDATE_MAID_KEY] = updateMaid
		task.wait()
		if not self._IsAlive or currentGoal ~= repData.Goal then return end

		local hasPlayedFinishSound = false

		updateMaid:GiveTask(RunService.Stepped:Connect(function(time: number, deltaTime: number)
			spring:Step(deltaTime)
			currentPosition = spring:Get()
			local alpha = if goalPosition ~= 0 then 1 - ((goalPosition - currentPosition)/goalPosition) else 1-math.abs(currentPosition)
			-- print(`alpha {alpha} dT {deltaTime} pos {currentPosition} goal {goalPosition}`)

			if repData.InverseOvershoot then
				if alpha > 1 then
					alpha = 1-(alpha-1)
				end
			end

			-- print(`prior {priorGoal.Position} current {currentGoal.Position}`)
			self.Instance:PivotTo(anchor.CFrame * anchorOffset * priorGoal:Lerp(currentGoal, alpha))
			if alpha >= 1-SMALL then
				if repData.FinishSound and not hasPlayedFinishSound then
					local finishSound = repData.FinishSound:Clone()
					finishSound.PlayOnRemove = true
					finishSound.Parent = inst
					finishSound:Destroy()
				end
			end
			if math.abs(alpha - 1) <= SMALL and math.abs(spring.Velocity) <= SMALL then

				-- print(`reached prop goal {inst:GetFullName()}`)
				updateMaid:Destroy()
			end
		end))
	end

	self._Maid:GiveTask(NetworkUtil.onClientEventAt(UPDATE_DOOR_PROP_REMOTE_EVENT_KEY, self.Instance, update))

	return self
end

function DoorAnimator.init(maid: Maid)
	assert(RunService:IsClient())
	local function initDoorAnimator(doorProp: Instance)
		assert(doorProp:IsA("Model") or doorProp:IsA("BasePart"), `tagged instance {doorProp:GetFullName()} is not as Instance`)
		local doorPropMaid = maid:GiveTask(Maid.new())
		doorPropMaid:GiveTask(doorProp.Destroying:Connect(function()
			doorPropMaid:Destroy()
		end))
		doorPropMaid:GiveTask(DoorAnimator.new(doorProp))
	end
	
	maid:GiveTask(CollectionService:GetInstanceAddedSignal(DOOR_PROP_TAG):Connect(initDoorAnimator))
	for i, doorProp in ipairs(CollectionService:GetTagged(DOOR_PROP_TAG)) do
		initDoorAnimator(doorProp)
	end

	return nil
end

return DoorAnimator
