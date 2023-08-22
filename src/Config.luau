--!strict
-- Services
-- Packages
-- Modules
-- Types
export type ReplicationData = {
	IsOpen: boolean,
	IsInward: boolean,
	Goal: CFrame,
	DampingRatio: number,
	Frequency: number,
	StartSound: Sound?,
	LoopingSound: Sound?,
	FinishSound: Sound?,
	InverseOvershoot: boolean,
}
-- Constants
-- Variables
-- References
-- Private Functions
-- Class
return {
	Tags = {
		DoorProp = "DoorServiceDoorProp",
	},
	Remotes = {
		Events = {
			UpdateDoorProp = "DoorServiceUpdateDoorProp",
		},
		Functions = {
			GetDoorPropInfo = "DoorServiceGetDoorPropInfo",
		},
	}
}