-- List of enums for use with Vehicle objects

export type Drivetrain = {
	FWD: number,
	RWD: number,
	AWD: number,
}

export type TireCompound = {
	Soft: number,
	Medium: number,
	Hard: number,
	Intermediate: number,
	Wet: number,
}

return {
	Drivetrain = {
		FWD = 1,
		RWD = 2,
		AWD = 3,
	},
	TireCompound = {
		SOFT = 1,
		MEDIUM = 2,
		HARD = 3,
		INTERMEDIATE = 4,
		WET = 5,
	},
}
