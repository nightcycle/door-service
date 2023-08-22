--!strict
local _Package = script.Parent
local _Packages = _Package.Parent
-- Services
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
-- Packages
local Maid = require(_Packages:WaitForChild("Maid"))
local Signal = require(_Packages:WaitForChild("Signal"))
local NetworkUtil = require(_Packages:WaitForChild("NetworkUtil"))

-- Modules
local Config = require(_Package:WaitForChild("Config"))

-- Types
type Maid = Maid.Maid
type Signal = Signal.Signal
type ReplicationData = Config.ReplicationData
export type DoorInstance = BasePart | Model
export type OnTriggerFunction = (character: Model) -> boolean
export type TargetData = {
	Inward: CFrame,
	Outward: CFrame,
}
export type Door = {
	__index: Door,
	_Maid: Maid,
	_IsAlive: boolean,
	_OnDestroying: Signal,
	_OnRequestInvoke: OnTriggerFunction,
	_IsOpen: boolean,
	_IsInward: boolean,
	_CensorRange: number,
	_AnimationTargets: {
		[DoorInstance]: TargetData
	},
	_LastOpener: Model?,
	OpeningDampingRatio: number,
	OpeningFrequency: number,
	ClosingDampingRatio: number,
	ClosingFrequency: number,
	AutoCloseDelay: number,
	AutoCloseEnabled: boolean,

	OpenLoopSound: Sound?,
	OpenStartSound: Sound?,
	OpenFinishSound: Sound?,
	CloseLoopSound: Sound?,
	CloseStartSound: Sound?,
	CloseFinishSound: Sound?,

	Censor: Part,
	Instance: Model,
	Boundary: BasePart,
	InverseAnimationOvershoot: boolean,
	ProximityPrompt: ProximityPrompt,
	Open: (self: Door) -> (),
	Close: (self: Door) -> (),
	GetIfOpen: (self: Door) -> boolean,
	SetOnRequestInvoke: (self: Door, onTriggerInvoke: OnTriggerFunction) -> (),
	SetCensorRange: (self: Door, range: number) -> (),
	SetPromptVisibility: (self: Door, isVisible: boolean) -> (),
	SetAnimationTarget: (self: Door, prop: DoorInstance, inwardTarget: CFrame, outwardTarget: CFrame?) -> (),
	Destroy: (self: Door) -> (),
	new: (inst: Model) -> Door,
}

-- Constants
local DEFAULT_DAMPING = 1
local DEFAULT_FREQUENCY = 1
local UPDATE_DOOR_PROP_REMOTE_EVENT_KEY = Config.Remotes.Events.UpdateDoorProp
local GET_DOOR_PROP_INFO_REMOTE_FUNCTION_KEY = Config.Remotes.Functions.GetDoorPropInfo
local DOOR_PROP_TAG = Config.Tags.DoorProp
local DEBUG_ENABLED = false

-- Variables
-- References
-- Private Functions

-- Class
local Door = {} :: Door
Door.__index = Door

function Door:Destroy()
	if not self._IsAlive then return end
	self._IsAlive = false
	task.wait()
	self._OnDestroying:Fire()
	self._Maid:Destroy()
	local t: any = self
	for k, v in pairs(t) do
		t[k] = nil
	end
	setmetatable(t, nil)
end

function Door:SetOnRequestInvoke(onTriggerInvoke: OnTriggerFunction)
	self._OnRequestInvoke = onTriggerInvoke
end

function Door:SetCensorRange(range: number)
	self._CensorRange = range
	self.Censor.Size = Vector3.new(0,1,1) * self._CensorRange * 2
end

function Door:SetAnimationTarget(prop: DoorInstance, inwardTarget: CFrame, outwardTarget: CFrame?)
	assert(self._AnimationTargets[prop] == nil, `animation target already set for {prop:GetFullName()}`)
	assert(prop ~= self.Instance.PrimaryPart, `Prop can't be primaryPart of door instance {prop:GetFullName()}`)
	assert(prop ~= self.Instance, `Prop can't be same as door instance {prop:GetFullName()}`)
	self._Maid:GiveTask(NetworkUtil.getRemoteEvent(UPDATE_DOOR_PROP_REMOTE_EVENT_KEY, prop))
	local remoteFunction = self._Maid:GiveTask(NetworkUtil.getRemoteFunction(GET_DOOR_PROP_INFO_REMOTE_FUNCTION_KEY, prop))
	remoteFunction.OnServerInvoke = function(plr: Player): ReplicationData
		local primaryPart = self.Instance.PrimaryPart
		assert(primaryPart)


		local anchorOffset = primaryPart.CFrame:Inverse() * prop:GetPivot()
		if self._IsOpen then
			return {
				IsOpen = self._IsOpen,
				IsInward = true,
				Goal = inwardTarget,
				DampingRatio = self.OpeningDampingRatio,
				Frequency = self.OpeningFrequency,
				StartSound = self.OpenStartSound,
				LoopingSound = self.OpenLoopSound,
				FinishSound = self.OpenFinishSound,
				InverseOvershoot = self.InverseAnimationOvershoot
			}, primaryPart, anchorOffset
		else
			return {
				IsOpen = self._IsOpen,
				IsInward = true,
				Goal = CFrame.new(0,0,0),
				DampingRatio = self.ClosingDampingRatio,
				Frequency = self.ClosingFrequency,
				StartSound = self.CloseStartSound,
				LoopingSound = self.CloseLoopSound,
				FinishSound = self.CloseFinishSound,
				InverseOvershoot = self.InverseAnimationOvershoot
			}, primaryPart, anchorOffset
		end
	end
	self._AnimationTargets[prop] = {
		Inward = inwardTarget,
		Outward = outwardTarget or inwardTarget,
	}
	CollectionService:AddTag(prop, DOOR_PROP_TAG)
end

function Door:Open()
	if self._IsOpen then return end
	self._IsOpen = true
	if DEBUG_ENABLED then
		print("Open")
		self.Boundary.Color = Color3.new(0,1,0)
		self.Boundary.Transparency = 0.8
	end
	self.Boundary.CanCollide = false
	if self.AutoCloseEnabled then
		self.ProximityPrompt.Enabled = false

		local function attemptClose()
			if self._IsAlive and self._IsOpen then
				local isHumanoidPresent = false

				if self._CensorRange > 0 then
					local overlapParams = OverlapParams.new()
					overlapParams.FilterDescendantsInstances = {}
					overlapParams.FilterType = Enum.RaycastFilterType.Exclude
					
					local overlapParts = workspace:GetPartsInPart(self.Censor, overlapParams)
					for i, part in ipairs(overlapParts) do
						local character = part.Parent
						if character and character:FindFirstChildOfClass("Humanoid") then
							isHumanoidPresent = true
						end
					end
				end
				
				if not isHumanoidPresent then
					self:Close()
				else
					task.wait(self.AutoCloseDelay*0.5)
					attemptClose()
				end
			end
		end

		task.delay(self.AutoCloseDelay, attemptClose)

	else
		self.ProximityPrompt.Enabled = true
		self.ProximityPrompt.ActionText = "Close"
	end
	for prop, targetData in pairs(self._AnimationTargets) do
		local remoteEvent = prop:FindFirstChild(UPDATE_DOOR_PROP_REMOTE_EVENT_KEY)
		assert(remoteEvent and remoteEvent:IsA("RemoteEvent"), `Bad DoorService prop remote event for {prop:GetFullName()}`)
	
		remoteEvent:FireAllClients({
			IsOpen = true,
			IsInward = self._IsInward,
			Origin = prop:GetPivot(),
			Goal = if self._IsInward then targetData.Inward else targetData.Outward,
			DampingRatio = self.OpeningDampingRatio,
			Frequency = self.OpeningFrequency,
			StartSound = self.OpenStartSound,
			LoopingSound = self.OpenLoopSound,
			FinishSound = self.OpenFinishSound,
			InverseOvershoot = self.InverseAnimationOvershoot
		})
	end
end

function Door:Close()
	if not self._IsOpen then return end
	self._IsOpen = false
	if DEBUG_ENABLED then
		print("Close")
		self.Boundary.Color = Color3.new(1,0,0)
		self.Boundary.Transparency = 0.5
	end
	self.Boundary.CanCollide = true
	self.ProximityPrompt.Enabled = true
	self.ProximityPrompt.ActionText = "Open"
	for prop, targetData in pairs(self._AnimationTargets) do
		local remoteEvent = prop:FindFirstChild(UPDATE_DOOR_PROP_REMOTE_EVENT_KEY)
		assert(remoteEvent and remoteEvent:IsA("RemoteEvent"), `Bad DoorService prop remote event for {prop:GetFullName()}`)
		remoteEvent:FireAllClients({
			IsOpen = false,
			IsInward = self._IsInward,
			Origin = prop:GetPivot(),
			Goal = CFrame.new(0,0,0),
			DampingRatio = self.ClosingDampingRatio,
			Frequency = self.ClosingFrequency,
			StartSound = self.CloseStartSound,
			LoopingSound = self.CloseLoopSound,
			FinishSound = self.CloseFinishSound,
			InverseOvershoot = self.InverseAnimationOvershoot
		})
	end
end

function Door:SetPromptVisibility(visible: boolean): ()
	if visible then
		if self.Instance:IsA("BasePart") then
			self.ProximityPrompt.Parent = self.Instance
		elseif self.Instance.PrimaryPart then
			self.ProximityPrompt.Parent = self.Instance.PrimaryPart
		else
			error(`no primaryPart set for door model {self.Instance:GetFullName()}`)
		end
	else
		self.ProximityPrompt.Parent = nil
	end
end

function Door:GetIfOpen(): boolean
	return self._IsOpen
end

function Door.new(inst: Model): Door

	assert(RunService:IsServer(), `Door must be constructed on server`)
	assert(inst.ModelStreamingMode == Enum.ModelStreamingMode.Atomic, `Door ModelStreamingMode must be atomic {inst:GetFullName()}`)

	local self: Door = setmetatable({}, Door) :: any
	self._IsAlive = true
	self._Maid = Maid.new()
	self.Instance = inst
	self._Maid.bind(inst)
	self._OnDestroying = self._Maid:GiveTask(Signal.new())
	self.OpeningDampingRatio = DEFAULT_DAMPING
	self.OpeningFrequency = DEFAULT_FREQUENCY
	self.ClosingDampingRatio = DEFAULT_DAMPING
	self.ClosingFrequency = DEFAULT_FREQUENCY
	self.AutoCloseDelay = 2
	self.AutoCloseEnabled = true
	self.InverseAnimationOvershoot = false

	self._CensorRange = 0
	self._IsOpen = false
	self._IsInward = true
	self._AnimationTargets = {}

	self.Censor = self._Maid:GiveTask(Instance.new("Part"))
	self.Censor.Name = "DoorCensor"
	self.Censor.Anchored = true
	self.Censor.Shape = Enum.PartType.Cylinder
	self.Censor.Archivable = false
	self.Censor.Parent = workspace
	self.Censor.CanCollide = false
	self.Censor.CanQuery = false
	self.Censor.CanTouch = true
	if DEBUG_ENABLED then
		self.Censor.Transparency = 0.5
		self.Censor.Color = Color3.new(0,0,1)
	else
		self.Censor.Transparency = 1
	end

	self.Boundary = self._Maid:GiveTask(Instance.new("Part"))
	self.Boundary.Anchored = true
	self.Boundary.Archivable = true
	self.Boundary.CanCollide = true
	if DEBUG_ENABLED then
		self.Boundary.Transparency = 0.5
		self.Boundary.Color = Color3.new(1,0,0)
	else
		self.Boundary.Transparency = 1
	end

	local origin = self.Instance:GetPivot()
	local function updateIsInward(character: Model)
		local cf = character:GetPivot()
		local charDirNorm = (cf.Position - origin.Position).Unit
		if charDirNorm == charDirNorm then
			if origin.LookVector:Dot(charDirNorm) < 0 then
				self._IsInward = true
			else
				self._IsInward = false
			end
		end
	end

	local cf, size = self.Instance:GetBoundingBox()
	self.Censor.CFrame = CFrame.new(cf.Position) * CFrame.Angles(0,0,math.rad(90)) + Vector3.new(0,4 - size.Y/2,0)
	self.Boundary.Size = size
	self.Boundary.CFrame = cf

	-- self.Censor.CFrame = self.Instance:GetPivot()

	self.ProximityPrompt = self._Maid:GiveTask(Instance.new("ProximityPrompt"))
	self.ProximityPrompt.Archivable = false
	self.ProximityPrompt.RequiresLineOfSight = false
	self.ProximityPrompt.ObjectText = "Door"
	self.ProximityPrompt.ActionText = "Open"
	self.ProximityPrompt.ClickablePrompt = true
	self:SetPromptVisibility(true)

	self.Censor.Parent = self.Instance
	self.Boundary.Parent = self.Instance

	self:SetCensorRange(self._CensorRange)

	self._Maid:GiveTask(self.Censor.Touched:Connect(function(part: BasePart)
		if self._IsOpen then return end
		local character = part.Parent
		if character and character:FindFirstChildOfClass("Humanoid") then
			assert(character:IsA("Model"))
			updateIsInward(character)
			if self._OnRequestInvoke(character) then
				self:Open()
			end

		end
	end))

	self._OnRequestInvoke = function(character: Model)
		return true
	end

	self._Maid:GiveTask(self.ProximityPrompt.Triggered:Connect(function(player: Player)
		local character = player.Character
		if character then
			updateIsInward(character)
			if self._OnRequestInvoke(character) then
				if self._IsOpen then
					self:Close()
				else
					self:Open()
				end
			end
		end
	end))
	
	return self
end

return Door