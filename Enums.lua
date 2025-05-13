-- List of enums for use with Vehicle objects

local Enums = {}

export type Drivetrain = {
	FWD: number,
	RWD: number,
	AWD: number,
}

export type Transmission = {
	Manual: number,
	Automatic: number,
}

export type GearShiftDirection = {
	Up: number,
	Down: number,
}

export type AxleType = {
	Front: number,
	Rear: number,
}

export type TireCompound = {
	Soft: number,
	Medium: number,
	Hard: number,
	Intermediate: number,
	Wet: number,
}

Enums.Drivetrain = {
	FWD = 1,
	RWD = 2,
	AWD = 3,
}

Enums.Transmission = {
	Manual = 1,
	Automatic = 2,
}

Enums.GearShiftDirection = {
	Up = 1,
	Down = -1,
}

Enums.AxleType = {
	Front = 1,
	Rear = 2,
}

Enums.TireCompound = {
	Soft = 1,
	Medium = 2,
	Hard = 3,
	Intermediate = 4,
	Wet = 5,
}

return Enums
