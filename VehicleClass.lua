--[[
The base class of the chassis. It works in a module system allowing you to add extra components to the mechanics
for different type of cars.
]]--

--------------------------------IMPORTS-------------------------------

local Enums = require(script.Enums)
local Signal = require(script.Signal)

---------------------------INTERNAL CLASSES---------------------------

-- A bunch of small component classes I couldn't bother organizing Java-style so I shoved them all in here

-----------------------------ENGINE CLASS-----------------------------

type Config = {
	components: {
		generator: boolean,
		turbocharger: boolean,
	},
	engine: {
		min_rpm: number,
		max_rpm: number,
		horsepower: number,
		max_torque: number,
	},
	generator: {
		max_energy: number,
		charge_rate: number,
		discharge_rate: number,
	}?,
	gearbox: {
		gear_ratios: {number},
		final_drive: number,
		transmission: Enums.Transmission,
		shift_time: number,
	},
	steering_column: {
		max_steering_angle: number,
	},
	wheels: {
		defaul_tire_compound: Enums.TireCompound,
		default_traction: number,
	},
}

local Engine = {}
Engine.__index = Engine

type Engine = {
	_vehicle: Vehicle,
	_rpm: number,
	_min_rpm: number,
	_max_rpm: number,
	_torque: number,
	_max_torque: number,
	_horsepower: number,
	_health: number,

	new: (vehicle: Vehicle, config: Config.engine) -> Engine,
	get_torque: (self: Engine) -> number,
	get_rpm: (self: Engine) -> number,
	get_health: (self: Engine) -> number,
	change_health: (self: Engine, amount: number) -> (),
	update: (self: Engine, throttle: number, engine_boost: number?, dt: number) -> (number, number)
}

--[[local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end]]

function Engine.new(vehicle: Vehicle, config: Config.engine): Engine
	local self = setmetatable({}, Engine) :: Engine
	self._vehicle = vehicle
	self._rpm = 0
	self._min_rpm = config.min_rpm
	self._max_rpm = config.max_rpm
	self._torque = 0
	self._max_torque = config.max_torque
	self._horsepower = config.horsepower
	self._health = 100

	return self
end

function Engine:get_torque(): number
	return self._torque -- Returns torque in Newton-meter (Nm)
end

function Engine:get_rpm(): number
	return self._rpm
end

function Engine:get_health(): number
	return self._health
end

function Engine:change_health(amount: number): ()
	self._health += amount
end

function Engine:update(throttle: number, engine_boost: number?, dt: number): (number, number)
	self._rpm = (self._vehicle:get_current_speed()
		* self._vehicle.gearbox:get_gear_ratio(self._vehicle.gearbox:get_gear())
		* 336) / self._vehicle.wheels[1]:get_tire_size()
	self._rpm = math.clamp(self._rpm, self._min_rpm, self._max_rpm)
	
	self._torque = (self._horsepower * 7127) / self._rpm
	
	if self._health <= 0 then
		return self._rpm
	end

	if throttle ~= 0 then

	else

	end

	return self._rpm, self._torque
end

---------------------------GENERATOR CLASS----------------------------

local Generator = {}
Generator.__index = Generator

type Generator = {
	_vehicle: Vehicle,
	_active: boolean,
	_energy_stored: number,
	_max_energy: number,
	_charge_rate: number,
	_discharge_rate: number,
	_output: number,
	_health: number,

	new: (vehicle: Vehicle, config: Config.generator) -> Generator,
	activate: (self: Generator, value: boolean) -> (),
	is_active: (self: Generator) -> boolean,
	get_health: (self: Generator) -> number,
	change_health: (self: Generator, amount: number) -> (),
}

function Generator.new(vehicle: Vehicle, config: Config.generator): Generator
	local self = setmetatable({}, Generator) :: Generator
	self._vehicle = vehicle
	self._active = false
	self._energy_stored = 4000 -- in kJ
	self._max_energy = config.max_energy or 4000
	self._charge_rate = config.charge_rate or 50
	self._discharge_rate = config.discharge_rate or 120
	self._output = 0 -- in kJ
	self._health = 100

	return self
end

function Generator:activate(value: boolean): ()
	self._active = value
end

function Generator:is_active(): boolean
	return self._active
end

function Generator:get_health(): number
	return self._health
end

function Generator:change_health(amount: number): ()
	self._health += amount
end

function Generator:update(dt: number): number
	if self:is_active() then
		local discharge = math.min(self._energy_stored, self._discharge_rate)
		self._output = discharge
		self._energy_stored -= discharge
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
	is_active: (self: Turbocharger) -> boolean,
	get_boost: (self: Turbocharger) -> number,
	get_health: (self: Turbocharger) -> number,
	change_health: (self: Turbocharger, amount: number) -> (),
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

function Turbocharger:is_active(): boolean
	return self._active
end

function Turbocharger:get_boost(): number
	return self._boost
end

function Turbocharger:get_health(): number
	return self._health
end

function Turbocharger:change_health(amount: number): ()
	self._health += amount
end

-----------------------------GEARBOX CLASS----------------------------

local Gearbox = {}
Gearbox.__index = Gearbox

type Gearbox = {
	_vehicle: Vehicle,
	_gear: number,
	_gear_ratios: {number},
	_final_drive: number,
	_transmission: number,
	_max_gear_rpms: {number},
	_shift_time: number,
	_health: number,

	new: (vehicle: Vehicle, config: Config.gearbox) -> Gearbox,
	shift: (self: Gearbox, direction: Enums.GearShiftDirection) -> (),
	get_gear: (self: Gearbox) -> number,
	get_health: (self: Gearbox) -> number,
	change_health: (self: Gearbox, amount: number) -> (),
	update: (self: Gearbox, engine_rpm: number, engine_torque: number) -> (number, number)
}

function Gearbox.new(vehicle: Vehicle, config: Config.gearbox): Gearbox
	local self = setmetatable({}, Gearbox) :: Gearbox
	self._vehicle = vehicle
	self._gear = 1
	self._gear_ratios = config.gear_ratios
	self._final_drive = config.final_drive
	self._transmission = config.transmission
	self._max_gear_rpms = {}
	self._shift_time = config.shift_time
	self._health = 100
end

--[[
function Gearbox:shiftUp(): ()
	if self._health <= 0 then
		return
	end

	self._gear += 1
	if self._vehicle.engine:get_rpm() >= self._max_gear_rpms[self._gear - 1] + 250 then
		self:change_health(-0.5)
	end
end

function Gearbox:shiftDown(): ()
	if self._health <= 0 then
		return
	end

	self._gear -= 1
	if self._vehicle.engine:get_rpm() > self._max_gear_rpms[self._gear] then
		self:change_health(-2)
	end
end
]]

function Gearbox:shift(direction: Enums.GearShiftDirection): ()
	if self._health <= 0 then
		return
	end
	
	self._gear += direction
	local engine_rpm = self._vehicle.engine:get_rpm()
	if direction == Enums.GearShiftDirection.Up then
		if engine_rpm < self._max_gear_rpms[self._gear] then
			
		end
	elseif direction == Enums.GearShiftDirection.Down then
		if engine_rpm > self._max_gear_rpms[self._gear + 1] then
			
		end
		if self._vehicle.engine
	end
end

function Gearbox:get_gear(): number
	return self._gear
end

function Gearbox:get_health(): number
	return self._health
end

function Gearbox:change_health(amount: number): ()
	self._health += amount
end

function Gearbox:update(engine_rpm: number, engine_torque: number): (number, number)
	if self._health <= 0 then
		return -- Is this even valid? I'm pretty sure if a gearbox is broken, it just can't change gears
	end
	
	local shift_delay = self._shift_time * (1 + (1 - self:get_health()))
	-- Add in gear slip
	if self._transmission == Enums.Transmission.Automatic then
		
	elseif self._transmission == Enums.Transmission.Manual then
		local gearbox_rpm = engine_rpm / self._gear_ratios[self._gear]
		local gearbox_torque = engine_torque * self._gear_ratios[self._gear] -- Newton-meter (Nm)
		return gearbox_rpm, gearbox_torque
	end
end

------------------------------AXLE CLASS------------------------------

local Axle = {}
Axle.__index = Axle

type Axle = {
	_vehicle: Vehicle,
	_axle_type: number,
	_health: number,

	new: (vehicle: Vehicle, axle_type: Enums.AxleType) -> Axle,
	get_health: (self: Axle) -> number,
	change_health: (self: Axle, amount: number) -> (),
}

function Axle.new(vehicle: Vehicle, axle_type: Enums.AxleType): Axle
	local self = setmetatable({}, Axle) :: Axle
	self._vehicle = vehicle
	self._axle_type = axle_type
	self._health = 100

	return self
end

function Axle:get_health(): number
	return self._health
end

function Axle:change_health(amount: number): ()
	self._health += amount
end

------------------------STEERING COLUMN CLASS-------------------------

local SteeringColumn = {}
SteeringColumn.__index = SteeringColumn


type SteeringColumn = {
	_steering_angle: number,
	_max_steering_angle: number,
	_health: number,

	new: (vehicle: Vehicle, config: Config.steering_column) -> SteeringColumn,
	get_health: (self: SteeringColumn) -> number,
	change_health: (self: SteeringColumn, amount: number) -> (),
	update: (self: SteeringColumn, steer_float: number, dt: number) -> number,
}

function SteeringColumn.new(vehicle: Vehicle, config: Config.steering_column): SteeringColumn
	local self = setmetatable({}, SteeringColumn) :: SteeringColumn
	self._vehicle = vehicle
	self._steering_angle = 0
	self._max_steering_angle = config.max_steering_angle
	self._health = 100
	return self
end

function SteeringColumn:get_health(): number
	return self._health
end

function SteeringColumn:change_health(amount: number): ()
	self._health += amount
end

function SteeringColumn:update(steer_float: number, dt: number): number
	if self._health <= 0 then
		return self._steering_angle
	end

	local new_angle = (steer_float * self._max_steering_angle) - self._steering_angle --lerp(self._steering_angle, steerFloat, self._health / 100)
	self._steering_angle = new_angle
	return new_angle
end

-----------------------------WHEEL CLASS------------------------------

local Wheel = {}
Wheel.__index = Wheel

type Wheel = {
	_vehicle: Vehicle,
	_wheel: BasePart,
	_tire_compound: number,
	_traction: number,
	_temperature: number,
	_stress: number,
	_powered: boolean,
	_health: number,

	new: (vehicle: Vehicle, wheel: BasePart, powered: boolean, config: Config.wheels) -> Wheel,
	get_traction: (self: Wheel) -> number,
	update_traction: (self: Wheel, traction: number) -> (),
	change_wheel: (self: Wheel, compound: Enums.TireCompound) -> (),
	get_tire_size: (self: Wheel) -> number,
	get_health: (self: Wheel) -> number,
	change_health: (self: Wheel, amount: number) -> (),
	update: (self: Wheel, dt: number) -> {number},
}

function Wheel.new(vehicle: Vehicle, wheel: BasePart, powered: boolean, config: Config.wheels): Wheel
	local self = setmetatable({}, Wheel) :: Wheel
	self._vehicle = vehicle
	self._wheel = wheel
	self._tire_compound = config.default_tire_compound
	self._traction = config.default_traction
	self._temperature = 15 -- in °C
	self._stress = 0
	self._powered = powered
	self._health = 100

	return self
end

function Wheel:get_traction(): number
	return self._traction
end

function Wheel:update_traction(traction: number): ()
	self._traction = traction
end

function Wheel:change_wheel(compound: Enums.TireCompound)
	self._tire_compound = compound
	self._traction = 0 -- TODO: replace with a dictionary lookup of default tractions?
	self._health = 100
	self._stress = 0
	self._temperature = 15 -- We could probably get the temperature from whatever weather control system nate has, convert to C

	-- I guess I should update the tire model in here?
end

function Wheel:get_tire_size(): number
	return self._wheel.Size.Y
end

function Wheel:get_health(): number
	return self._health
end

function Wheel:change_health(amount: number): ()
	self._health += amount
end

local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Include
params.CollisionGroup = "Car"
function Wheel:update(dt: number): {number}
	local result = workspace:Raycast(self._wheel.Position, Vector3.new(0, -1, 0), params)
	if result.Material ~= Enum.Material.Concrete then
		self:change_health(-1 * dt) -- Update this to take into account tire compound
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
	front_axle: Axle,
	rear_axle: Axle,
	steering_column: SteeringColumn,
	wheels: {Wheel},
	_drivetrain: Enums.Drivetrain,
	_chassis: BasePart,

	new: (wheels: {[string]: BasePart}, config: Config) -> Vehicle,
	get_current_speed: (self: Vehicle) -> number,
	is_flipped: (self: Vehicle) -> boolean,
	update: (self: Vehicle, values: {number}, dt: number) -> {number},
}

function Vehicle.new(wheels: {[string]: BasePart}, config: Config): Vehicle
	local self = setmetatable({}, Vehicle) :: Vehicle
	self.engine = Engine.new(self, config.engine)
	self.generator = config.components.generator and Generator.new(self, config.generator) or nil
	self.turbocharger = config.components.turbocharger and Turbocharger.new(self, config.turbocharger) or nil
	self.gearbox = Gearbox.new(self, config.gearbox)
	self.front_axle = Axle.new(self, Enums.AxleType.Front)
	self.rear_axle = Axle.new(self, Enums.AxleType.Rear)
	self.steering_column = SteeringColumn.new(self, config.steering_column)
	self.wheels = { -- Find a better way to do this than hardcoding the wheels
		FL = Wheel.new(self, wheels.FL, false, config.wheels),
		FR = Wheel.new(self, wheels.FR, false, config.wheels),
		RL = Wheel.new(self, wheels.RL, true, config.wheels),
		RR = Wheel.new(self, wheels.RR, true, config.wheels),
	}
	self._drivetrain = config.drivetrain
	self._chassis = config.chassis
	
	self.gear_shift = Signal.new()
	return self
end

function Vehicle:get_current_speed(): number
	return self._chassis.AssemblyLinearVelocity.Magnitude
end

function Vehicle:is_flipped(): boolean
	local up_CFrame = self._chassis.CFrame.UpVector
	local position = self._chassis.Position -- get model equivalent
	return position.Y > (position + up_CFrame).Y
end

function Vehicle:update(values: {throttle: number, steer: number}, dt: number): {number}
	local engine_boost = 0

	if self.generator then
		engine_boost += self.generator:update()
	end
	if self.turbocharger then
		engine_boost += self.turbocharger:update()
	end

	local engine_rpm, engine_torque = self.engine:update(values.throttle, engine_boost, dt)
	local gearbox_rpm, gearbox_torque = self.gearbox:update(engine_rpm, engine_torque)
	local steer = self.steering_column:update(values.steer, dt)
	
	for wheel, _ in pairs(self.wheels) do
		
	end
	
	return {
		angular_velocity = gearbox_rpm, -- Is this correct?
		motor_max_torque = gearbox_torque,
		new_steering_angle = steer,
	}
end

return Vehicle
