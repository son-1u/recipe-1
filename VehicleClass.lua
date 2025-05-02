--[[
The base class of the chassis. It works in a module system allowing you to add extra components to the mechanics
for different type of cars.
]]--

--------------------------------IMPORTS-------------------------------

local Enums = require(script.Enums)

---------------------------INTERNAL CLASSES---------------------------

-- A bunch of small component classes I couldn't bother organizing Java-style so I shoved them all in here

-----------------------------ENGINE CLASS-----------------------------

type Config = {
	components: {
		generator: boolean,
		turbocharger: boolean,
	},
	engine: {
		minRPM: number,
		maxRPM: number,
		horsepower: number,
		maxTorque: number,
	},
	generator: {
		maxEnergy: number,
		chargeRate: number,
		dischargeRate: number,
	}?,
	gearbox: {
		gearRatios: {number},
		finalDrive: number,
		transmission: Enums.Transmission
	},
	steeringColumn: {
		maxSteeringAngle: number,
	},
	wheel: {
		defaultTireCompound: Enums.TireCompound,
		defaultTraction: number,
	},
}

local Engine = {}
Engine.__index = Engine

type Engine = {
	_vehicle: Vehicle,
	_rpm: number,
	_minRPM: number,
	_maxRPM: number,
	_horsepower: number,
	_health: number,
	_maxTorque: number,

	new: (vehicle: Vehicle, config: Config.engine) -> Engine,
	getTorque: (self: Engine) -> number,
	getRPM: (self: Engine) -> number,
	getHealth: (self: Engine) -> number,
	changeHealth: (self: Engine, amount: number) -> (),
	update: (self: Engine, throttle: number, engineBoost: number?, dt: number) -> number, number,
}

local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

function Engine.new(vehicle: Vehicle, config: Config.engine): Engine
	local self = setmetatable({}, Engine) :: Engine
	self._vehicle = vehicle
	self._rpm = 0
	self._minRPM = config.minRPM
	self._maxRPM = config.maxRPM
	self._horsepower = config.horsepower
	self._health = 100
	self._maxTorque = config.maxTorque

	return self
end

function Engine:getTorque(): number
	return (self._rpm * 5252) / self._rpm
end

function Engine:getRPM(): number
	return self._rpm
end

function Engine:getHealth(): number
	return self._health
end

function Engine:changeHealth(amount: number): ()
	self._health += amount
end

function Engine:update(throttle: number, engineBoost, number?, dt: number): number, number
	self._rpm = (self._vehicle:getCurrentSpeed()
		* self._vehicle.gearbox:getGearRatio(self._vehicle.gearbox:getGear())
		* 336) / self._vehicle.wheels[1]:getTireSize()
	self._rpm = math.clamp(self._rpm, self._minRPM, self._maxRPM)
	
	if self._health <= 0 then
		return self._rpm
	end
	
	if throttle ~= 0 then
		
	else
		
	end
	
	return self._rpm, (self._horsepower * 5252) / self._rpm
end

---------------------------GENERATOR CLASS----------------------------

local Generator = {}
Generator.__index = Generator

type Generator = {
	_vehicle: Vehicle,
	_active: boolean,
	_energyStored: number,
	_maxEnergy: number,
	_chargeRate: number,
	_dischargeRate: number,
	_output: number,
	_health: number,

	new: (vehicle: Vehicle, config: Config.generator) -> Generator,
	activate: (self: Generator, value: boolean) -> (),
	isActive: (self: Generator) -> boolean,
	getHealth: (self: Generator) -> number,
	changeHealth: (self: Generator, amount: number) -> (),
}

function Generator.new(vehicle: Vehicle, config: Config.generator): Generator
	local self = setmetatable({}, Generator) :: Generator
	self._vehicle = vehicle
	self._active = false
	self._energyStored = 4000 -- in kJ
	self._maxEnergy = config.maxEnergy or 4000
	self._chargeRate = config.chargeRate or 50
	self._dischargeRate = config.dischargeRate or 120
	self._output = 0 -- in kJ
	self._health = 100

	return self
end

function Generator:activate(value: boolean): ()
	self._active = value
end

function Generator:isActive(): boolean
	return self._active
end

function Generator:getHealth(): number
	return self._health
end

function Generator:changeHealth(amount: number): ()
	self._health += amount
end

function Generator:update(dt: number): number
	if self:isActive() then
		local discharge = math.min(self._energyStored, self._dischargeRate)
		self._output = discharge
		self._energyStored -= discharge
	else
		self._output = 0 -- take in brake power and charge. chargeRate * dt * throttleFloat?
	end

	return self._output
end

--------------------------TURBOCHARGER CLASS--------------------------

local Turbocharger = {}
Turbocharger.__index = Turbocharger

type Turbocharger = {
	_vehicle: Vehicle,
	_active: boolean,
	_boost: number,
	_health: number,

	new: (vehicle: Vehicle) -> Turbocharger,
	activate: (self: Turbocharger, value: boolean) -> (),
	isActive: (self: Turbocharger) -> boolean,
	getBoost: (self: Turbocharger) -> number,
	getHealth: (self: Turbocharger) -> number,
	changeHealth: (self: Turbocharger, amount: number) -> (),
}

function Turbocharger.new(vehicle: Vehicle): Turbocharger
	local self = setmetatable({}, Turbocharger) :: Turbocharger
	self._vehicle = vehicle
	self._active = false
	self._boost = 0
	self._health = 100

	return self
end

function Turbocharger:activate(value: boolean): ()
	self._active = value
end

function Turbocharger:isActive(): boolean
	return self._active
end

function Turbocharger:getBoost(): number
	return self._boost
end

function Turbocharger:getHealth(): number
	return self._health
end

function Turbocharger:changeHealth(amount: number): ()
	self._health += amount
end

-----------------------------GEARBOX CLASS----------------------------

local Gearbox = {}
Gearbox.__index = Gearbox

type Gearbox = {
	_vehicle: Vehicle,
	_gear: number,
	_gearRatios: {number},
	_finalDrive: number,
	_transmission: number,
	_maxGearRPMs: {number},
	_health: number,

	new: (vehicle: Vehicle, config: Config.gearbox) -> Gearbox,
	shiftUp: (self: Gearbox) -> (),
	shiftDown: (self: Gearbox) -> (),
	getGear: (self: Gearbox) -> number,
	getTorque: (self: Gearbox) -> number,
	getHealth: (self: Gearbox) -> number,
	changeHealth: (self: Gearbox, amount: number) -> (),
	update: (self: Gearbox, engineRPM: number, engineTorque: number) -> number, number,
}

function Gearbox.new(vehicle: Vehicle, config: Config.gearbox): Gearbox
	local self = setmetatable({}, Gearbox) :: Gearbox
	self._vehicle = vehicle
	self._gear = 1
	self._gearRatios = config.gearRatios
	self._finalDrive = config.finalDrive
	self._transmission = config.transmission
	self._maxGearRPMs = {}
	self._health = 100
end

function Gearbox:shiftUp(): ()
	if self._health <= 0 then
		return
	end

	self._gear += 1
	if self._vehicle.engine:getRPM() >= self._maxGearRPMs[self._gear - 1] + 250 then
		self:changeHealth(-0.5)
	end
end

function Gearbox:shiftDown(): ()
	if self._health <= 0 then
		return
	end

	self._gear -= 1
	if self._vehicle.engine:getRPM() > self._maxGearRPMs[self._gear] then
		self:changeHealth(-2)
	end
end

function Gearbox:getGear(): number
	return self._gear
end

-- Input engine torque
function Gearbox:getTorque(torque: number): number
	return torque * self._gearRatios[self._gear] -- Isn't this the formula for calculating gearbox rpm?, need to come back to this
end

function Gearbox:getHealth(): number
	return self._health
end

function Gearbox:changeHealth(amount: number): ()
	self._health += amount
end

function Gearbox:update(engineRPM: number, engineTorque: number): number, number
	return engineRPM * self._gearRatios[self._gear]
end

------------------------------AXLE CLASS------------------------------

local Axle = {}
Axle.__index = Axle

type Axle = {
	_vehicle: Vehicle,
	_axleType: number,
	_health: number,

	new: (vehicle: Vehicle, axleType: Enums.AxleType) -> Axle,
	getHealth: (self: Axle) -> number,
	changeHealth: (self: Axle, amount: number) -> (),
}

function Axle.new(vehicle: Vehicle, axleType: Enums.AxleType): Axle
	local self = setmetatable({}, Axle) :: Axle
	self._vehicle = vehicle
	self._axleType = axleType
	self._health = 100

	return self
end

function Axle:getHealth(): number
	return self._health
end

function Axle:changeHealth(amount: number): ()
	self._health += amount
end

------------------------STEERING COLUMN CLASS-------------------------

local SteeringColumn = {}
SteeringColumn.__index = SteeringColumn


type SteeringColumn = {
	_steeringAngle: number,
	_maxSteeringAngle: number,
	_health: number,

	new: (vehicle: Vehicle, config: Config.steeringAngle) -> SteeringColumn,
	getHealth: (self: SteeringColumn) -> number,
	changeHealth: (self: SteeringColumn, amount: number) -> (),
	update: (self: SteeringColumn, steerFloat: number, dt: number) -> number,
}

function SteeringColumn.new(vehicle: Vehicle, config: Config.steeringAngle): SteeringColumn
	local self = setmetatable({}, SteeringColumn) :: SteeringColumn
	self._steeringAngle = 0
	self._maxSteeringAngle = config.maxSteeringAngle
	self._health = 100
	return self
end

function SteeringColumn:getHealth(): number
	return self._health
end

function SteeringColumn:changeHealth(amount: number): ()
	self._health += amount
end

function SteeringColumn:update(steerFloat: number, dt: number): number
	if self._health <= 0 then
		return 0
	end

	local newAngle = (steerFloat * self._maxSteeringAngle) - self._steeringAngle --lerp(self._steeringAngle, steerFloat, self._health / 100)
	self._steeringAngle = newAngle
	return newAngle
end

-----------------------------WHEEL CLASS------------------------------

local Wheel = {}
Wheel.__index = Wheel

type Wheel = {
	_vehicle: Vehicle,
	_wheel: BasePart,
	_tireCompound: number,
	_traction: number,
	_temperature: number,
	_stress: number,
	_powered: boolean,
	_health: number,

	new: (vehicle: Vehicle, wheel: BasePart, powered: boolean, config: Config.wheel) -> Wheel,
	getTraction: (self: Wheel) -> number,
	updateTraction: (self: Wheel, traction: number) -> (),
	changeWheel: (self: Wheel, compound: Enums.TireCompound) -> (),
	getTireSize: (self: Wheel) -> number,
	getHealth: (self: Wheel) -> number,
	changeHealth: (self: Wheel, amount: number) -> (),
	update: (self: Wheel, dt: number) -> {number},
}

function Wheel.new(vehicle: Vehicle, wheel: BasePart, powered: boolean, config: Config.wheel): Wheel
	local self = setmetatable({}, Wheel) :: Wheel
	self._vehicle = vehicle
	self._wheel = wheel
	self._tireCompound = config.defaultTireCompound
	self._traction = config.defaultTraction
	self._temperature = 15 -- in °C
	self._stress = 0
	self._powered = powered
	self._health = 100

	return self
end

function Wheel:getTraction(): number
	return self._traction
end

function Wheel:updateTraction(traction: number): ()
	self._traction = traction
end

function Wheel:changeWheel(compound: Enums.TireCompound)
	self._tireCompound = compound
	self._traction = 0 -- TODO: replace with a dictionary lookup of default tractions?
	self._health = 100
	self._stress = 0
	self._temperature = 15 -- We could probably get the temperature from whatever weather control system nate has, convert to C
	
	-- I guess I should update the tire model in here?
end

function Wheel:getTireSize(): number
	return self._wheel.Size.Y
end

function Wheel:getHealth(): number
	return self._health
end

function Wheel:changeHealth(amount: number): ()
	self._health += amount
end

local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Include
params.CollisionGroup = "Car"
function Wheel:update(dt: number): {number}
	local result = workspace:Raycast(self._wheel.Position, Vector3.new(0, -1, 0), params)
	if result.Material ~= Enum.Material.Concrete then
		self:changeHealth(-1 * dt) -- Update this to take into account tire compound
	end

	-- update stress
	-- update friction
	-- update wear
	-- update temperature
	-- update health
end

------------------------------MAIN CLASS------------------------------

local Vehicle = {}
Vehicle.__index = Vehicle

type Vehicle = {
	engine: Engine,
	generator: Generator?,
	turbocharger: Turbocharger?,
	gearbox: Gearbox,
	frontAxle: Axle,
	rearAxle: Axle,
	steeringColumn: SteeringColumn,
	wheels: {Wheel},
	_chassis: BasePart,

	new: (wheels: {[string]: BasePart}, config: Config) -> Vehicle,
	getCurrentSpeed: (self: Vehicle) -> number,
	isFlipped: (self: Vehicle) -> boolean,
	update: (self: Vehicle, values: {number}, dt: number) -> {any},
}

function Vehicle.new(wheels: {[string]: BasePart}, config: Config): Vehicle
	local self = setmetatable({}, Vehicle) :: Vehicle
	self.engine = Engine.new(self, config.engine)
	self.generator = config.components.generator and Generator.new(self, config.generator) or nil
	self.turbocharger = config.components.turbocharger and Turbocharger.new(self, config.turbocharger) or nil
	self.gearbox = Gearbox.new(self, config.gearbox)
	self.frontAxle = Axle.new(self, 1)
	self.rearAxle = Axle.new(self, -1)
	self.steeringColumn = SteeringColumn.new(self, config.steeringColumn)
	self.wheels = { -- Find a better way to do this than hardcoding the wheels
		FL = Wheel.new(self, wheels.FL, false, config.wheel),
		FR = Wheel.new(self, wheels.FR, false, config.wheel),
		RL = Wheel.new(self, wheels.RL, true, config.wheel),
		RR = Wheel.new(self, wheels.RR, true, config.wheel),
	}
	self._chassis = config.chassis
	return self
end

function Vehicle:getCurrentSpeed(): number
	return self._chassis.AssemblyLinearVelocity.Magnitude
end

function Vehicle:isFlipped(): boolean
	local upCFrame = self._chassis.CFrame.UpVector
	local position = self._chassis.Position -- get model equivalent
	return position.Y > (position + upCFrame).Y
end

function Vehicle:update(values: {throttle: number, steer: number}, dt: number): {any}
	local engineBoost = 0
	
	if self.generator then
		engineBoost += self.generator:update()
	end
	if self.turbocharger then
		engineBoost += self.turbocharger:update()
	end

	local engineRPM, engineTorque = self.engine:update(values.throttle, engineBoost, dt)
	local gearboxRPM, gearboxTorque = self.gearbox:update(engineRPM, engineTorque)
	local steer = self.steeringColumn:update(values.steer, dt)
	
	return {
	angularVelocity = self.engine:update(),
	motorMaxTorque = self.gearbox:update(), --  FINISH THIS
	newSteeringAngle = self.steeringColumn:update(),
	
	}
end

return Vehicle
