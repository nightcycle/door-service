--!strict
local _Package = script.Parent
local _Packages = _Package.Parent
-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
-- Packages
local Maid = require(_Packages:WaitForChild("Maid"))
-- Modules
-- Types
-- Constants
-- Variables
-- References
local DoorTemplate: Model = ReplicatedStorage:WaitForChild("Door") :: any
local DoubleDoorTemplate: Model = ReplicatedStorage:WaitForChild("DoubleDoor") :: any
local GarageDoorTemplate: Model = ReplicatedStorage:WaitForChild("GarageDoor") :: any


-- Class
return function()
	local maid = Maid.new()
	task.spawn(function()
		local Module = require(_Package)
		Module.init(maid)

		local doorInst = maid:GiveTask(DoorTemplate:Clone())
		doorInst.Parent = workspace

		local doubleDoorInst = maid:GiveTask(DoubleDoorTemplate:Clone())
		doubleDoorInst.Parent = workspace

		local garageDoorInst = maid:GiveTask(GarageDoorTemplate:Clone())
		garageDoorInst.Parent = workspace

		local door = Module:RegisterDoor(doorInst)
		door.OpeningDampingRatio = 0.1
		door.OpeningFrequency = 1
		door.ClosingDampingRatio = 0.1
		door.ClosingFrequency = 0.2
		door.InverseAnimationOvershoot = true
		door.ProximityPrompt.HoldDuration = 2
		door:SetCensorRange(0)
		door:SetPromptVisibility(true)
		door:SetAnimationTarget(doorInst:WaitForChild("Door") :: Model, CFrame.Angles(0,math.rad(-120),0), CFrame.Angles(0,math.rad(120),0))
		door.AutoCloseEnabled = false

		local doubleDoor = Module:RegisterDoor(doubleDoorInst)
		doubleDoor.OpeningDampingRatio = 0.75
		doubleDoor.OpeningFrequency = 0.75
		doubleDoor.ClosingDampingRatio = 0.75
		doubleDoor.ClosingFrequency = 0.75
		doubleDoor:SetCensorRange(7.5)
		doubleDoor:SetPromptVisibility(false)
		doubleDoor:SetAnimationTarget(doubleDoorInst:WaitForChild("LDoor") :: Model, CFrame.Angles(0,math.rad(-120),0), CFrame.Angles(0,math.rad(120),0))
		doubleDoor:SetAnimationTarget(doubleDoorInst:WaitForChild("RDoor") :: Model, CFrame.Angles(0,math.rad(-120),0), CFrame.Angles(0,math.rad(120),0))
		doubleDoor.AutoCloseDelay = 1

		local garageDoor = Module:RegisterDoor(garageDoorInst)
		garageDoor.OpeningDampingRatio = 0.25
		garageDoor.OpeningFrequency = 1
		garageDoor.ClosingDampingRatio = 0.75
		garageDoor.ClosingFrequency = 0.75
		garageDoor:SetAnimationTarget(garageDoorInst:WaitForChild("Door") :: BasePart, CFrame.new(0,10,0))
		garageDoor:SetCensorRange(0)
		garageDoor.AutoCloseEnabled = false
		garageDoor.ProximityPrompt.Parent = garageDoorInst:WaitForChild("Button1")
		
	end)
	return function()
		task.spawn(function()
			maid:Destroy()
		end)
	end
end