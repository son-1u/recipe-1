--[[
The base class of the chassis. It works in a module system allowing you to add extra components to the mechanics
for different type of cars.
]]--

--------------------------------IMPORTS-------------------------------

local Enums = require(script.Enums)
local Signal = require(script.Signal)
local Input = require(script.Input)
local Camera = require(script.Camera)

---------------------------INTERNAL CLASSES---------------------------

-- A bunch of small component classes that helps with the physics simulation of the vehicle

-----------------------------ENGINE CLASS-----------------------------

type Config = {
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
		default_tire_compound: Enums.TireCompound,
		default_traction: number,
	},
}

local Engine = {}
Engine.__index = Engine

type Engine = typeof(setmetatable({} :: {
	_vehicle: Vehicle,
	_rpm: number,
	_min_rpm: number,
	_max_rpm: number,
	_torque: number,
	_max_torque: number,
	_horsepower: number,
	_health: number,
	health_changed: Signal,

	new: (vehicle: Vehicle, config: Config.engine) -> Engine,
	get_torque: (self: Engine) -> number,
	get_rpm: (self: Engine) -> number,
	get_health: (self: Engine) -> number,
	change_health: (self: Engine, amount: number) -> (),
	update: (self: Engine, throttle: number, engine_boost: number?, dt: number) -> (number, number)
}, Engine))

local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

function Engine.new(vehicle: Vehicle, config: Config.engine): Engine
	local self = setmetatable({}, Engine)
	self._vehicle = vehicle
	self._rpm = 0
	self._min_rpm = config.min_rpm
	self._max_rpm = config.max_rpm
	self._torque = 0
	self._max_torque = config.max_torque
	self._horsepower = config.horsepower
	self._health = 100
	self.health_changed = Signal.new()

	return self
end

function Engine.get_torque(self: Engine): number
	return self._torque -- Returns torque in Newton-meter (Nm)
end

function Engine.get_rpm(self: Engine): number
	return self._rpm
end

function Engine.get_health(self: Engine): number
	return self._health
end

function Engine.change_health(self: Engine, amount: number): ()
	self._health += amount
end

--[[ --- Calculates RPM from wheel speed (does not use roblox units)
	self._rpm = (self._vehicle:get_current_speed()
		* self._vehicle.gearbox:get_gear_ratio(self._vehicle.gearbox:get_gear())
		* 336) / self._vehicle.wheels[1]:get_tire_size()
	self._rpm = math.clamp(self._rpm, self._min_rpm, self._max_rpm)
]]
function Engine.update(self: Engine, throttle: number, engine_boost: number?, dt: number): (number, number)
	if self._health <= 0 then
		return self._rpm, self._torque -- Gotta write a scenario where engine dies while its still at a high rpm (use the engine braking code??)
	end

	--- RPM Calculation
	-- Uses an exponential curve (faster rise near min rpm, tapers off near max rpm)
	-- Formula: min + (max - min) * (throttle ^ power)
	-- Power is the sharpness of the rpm rise
	-- Power = 1 (linear rise)
	-- Power < 1 (faster early rise, slower near the top)
	-- Power > 1 (slower early rise, faster near the top)
	local target_rpm = 0
	if throttle ~= 0 then
		target_rpm = math.clamp(
			self._min_rpm + (self._max_rpm - self._min_rpm) * (throttle ^ 0.5), -- This doesn't work for backing up. Maybe have it go back up if throttle is negative and it reaches min rpm?
			self._min_rpm, -- lmao this shit is useless, just replace with max_rpm and reverse_rpm (whatever it'll be)
			self._max_rpm
		)
		--- Smoothing the RPM
		-- For the third argument, the numerical value multiplied by deltatime is the rpm acceleration rate from min rpm to max rpm
		-- The smaller the number, the longer it takes
		-- 0.5 = two seconds, 1 = one second, 2 = half a second
	else
		target_rpm = 0
	end
	self._rpm = lerp(self._rpm, target_rpm, 0.45 * dt)
	
	if self._rpm >= self._max_rpm then
		self._rpm -= math.random(250, 500)
	end
	
	self._torque = self._rpm <= 7000 and (0.03 * self._rpm) + 90 or (-0.025 * self._rpm) + 475
	return self._rpm, self._torque
end

---------------------------GENERATOR CLASS----------------------------

local Generator = {}
Generator.__index = Generator

type Generator = typeof(setmetatable({} :: {
	_vehicle: Vehicle,
	_active: boolean,
	_energy_stored: number,
	_max_energy: number,
	_charge_rate: number,
	_discharge_rate: number,
	_output: number,
	_health: number,
	health_changed: Signal,

	new: (vehicle: Vehicle, config: Config.generator) -> Generator,
	activate: (self: Generator, value: boolean) -> (),
	is_active: (self: Generator) -> boolean,
	get_health: (self: Generator) -> number,
	change_health: (self: Generator, amount: number) -> (),
}, Generator))

function Generator.new(vehicle: Vehicle, config: Config.generator): Generator
	local self = setmetatable({}, Generator)
	self._vehicle = vehicle
	self._active = false
	self._energy_stored = 4000 -- in kJ
	self._max_energy = config.max_energy or 4000
	self._charge_rate = config.charge_rate or 50
	self._discharge_rate = config.discharge_rate or 120
	self._output = 0 -- in kJ
	self._health = 100
	self.health_changed = Signal.new()

	return self
end

function Generator.activate(self: Generator, value: boolean): ()
	self._active = value
end

function Generator.is_active(self: Generator): boolean
	return self._active
end

function Generator.get_health(self: Generator): number
	return self._health
end

function Generator.change_health(self: Generator, amount: number): ()
	self._health += amount
end

function Generator.update(self: Generator, dt: number): number
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

type Turbocharger = typeof(setmetatable({} :: {
	_vehicle: Vehicle,
	_active: boolean,
	_boost: number,
	_health: number,
	health_changed: Signal,

	new: (vehicle: Vehicle) -> Turbocharger,
	activate: (self: Turbocharger, value: boolean) -> (),
	is_active: (self: Turbocharger) -> boolean,
	get_boost: (self: Turbocharger) -> number,
	get_health: (self: Turbocharger) -> number,
	change_health: (self: Turbocharger, amount: number) -> (),
}, Turbocharger))

function Turbocharger.new(vehicle: Vehicle): Turbocharger
	local self = setmetatable({}, Turbocharger)
	self._vehicle = vehicle
	self._active = false
	self._boost = 0
	self._health = 100
	self.health_changed = Signal.new()

	return self
end

function Turbocharger.activate(self: Turbocharger, value: boolean): ()
	self._active = value
end

function Turbocharger.is_active(self: Turbocharger): boolean
	return self._active
end

function Turbocharger.get_boost(self: Turbocharger): number
	return self._boost
end

function Turbocharger.get_health(self: Turbocharger): number
	return self._health
end

function Turbocharger.change_health(self: Turbocharger, amount: number): ()
	self._health += amount
end

-----------------------------GEARBOX CLASS----------------------------

local Gearbox = {}
Gearbox.__index = Gearbox

type Gearbox = typeof(setmetatable({} :: {
	_vehicle: Vehicle,
	_gear: number,
	_gear_ratios: {number},
	_final_drive: number,
	_transmission: number,
	_max_gear_rpms: {number},
	_shift_time: number,
	_health: number,
	health_changed: Signal,

	new: (vehicle: Vehicle, config: Config.gearbox) -> Gearbox,
	shift: (self: Gearbox, direction: Enums.GearShiftDirection) -> (),
	get_gear: (self: Gearbox) -> number,
	get_health: (self: Gearbox) -> number,
	change_health: (self: Gearbox, amount: number) -> (),
	update: (self: Gearbox, engine_rpm: number, engine_torque: number) -> (number, number)
}, Gearbox))

function Gearbox.new(vehicle: Vehicle, config: Config.gearbox): Gearbox
	local self = setmetatable({}, Gearbox)
	self._vehicle = vehicle
	self._gear = 1
	self._gear_ratios = config.gear_ratios
	self._final_drive = config.final_drive
	self._transmission = config.transmission
	self._max_gear_rpms = {}
	self._shift_time = config.shift_time
	self._health = 100
	self.health_changed = Signal.new()
	
	return self
end

function Gearbox.shift(self: Gearbox, direction: Enums.GearShiftDirection): ()
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
		--if self._vehicle.engine
	end
end

function Gearbox.get_gear(self: Gearbox): number
	return self._gear
end

function Gearbox.get_health(self: Gearbox): number
	return self._health
end

function Gearbox.change_health(self: Gearbox, amount: number): ()
	self._health += amount
end

function Gearbox.update(self: Gearbox, engine_rpm: number, engine_torque: number): (number, number)
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

type Axle = typeof(setmetatable({} :: {
	_vehicle: Vehicle,
	_axle_type: number,
	_connected_wheels: {Wheel},
	_health: number,
	health_changed: Signal,

	new: (vehicle: Vehicle, axle_type: Enums.AxleType) -> Axle,
	get_health: (self: Axle) -> number,
	change_health: (self: Axle, amount: number) -> (),	
}, Axle))

function Axle.new(vehicle: Vehicle, axle_type: Enums.AxleType, connected_wheels: {Wheel}): Axle
	local self = setmetatable({}, Axle)
	self._vehicle = vehicle
	self._axle_type = axle_type
	self._connected_wheels = connected_wheels
	self._health = 100
	self.health_changed = Signal.new()
	
	self.health_changed:Connect(function()
		if self._health >= 0 then
			return
		end
		
		for _, wheel in pairs(self._connected_wheels) do
			-- TODO: BREAK WHEEL CONNECTION
		end
	end)
	
	return self
end

function Axle.get_health(self: Axle): number
	return self._health
end

function Axle.change_health(self: Axle, amount: number): ()
	self._health += amount
end

------------------------STEERING COLUMN CLASS-------------------------

local SteeringColumn = {}
SteeringColumn.__index = SteeringColumn

type SteeringColumn = typeof(setmetatable({} :: {
	_steering_angle: number,
	_max_steering_angle: number,
	_health: number,
	health_changed: Signal,

	new: (vehicle: Vehicle, config: Config.steering_column) -> SteeringColumn,
	get_health: (self: SteeringColumn) -> number,
	change_health: (self: SteeringColumn, amount: number) -> (),
	update: (self: SteeringColumn, steer_float: number, dt: number) -> number,
}, SteeringColumn))

function SteeringColumn.new(vehicle: Vehicle, config: Config.steering_column): SteeringColumn
	local self = setmetatable({}, SteeringColumn)
	self._vehicle = vehicle
	self._steering_angle = 0
	self._max_steering_angle = config.max_steering_angle
	self._health = 100
	self.health_changed = Signal.new()
	
	return self
end

function SteeringColumn.get_health(self: SteeringColumn): number
	return self._health
end

function SteeringColumn.change_health(self: SteeringColumn, amount: number): ()
	self._health += amount
end

function SteeringColumn.update(self: SteeringColumn, steer_float: number, dt: number): number
	if self._health <= 0 then
		return self._steering_angle
	end

	local target_angle = steer_float * self._max_steering_angle
	self._steering_angle = lerp(self._steering_angle, target_angle, 0.2 * dt)
	return self._steering_angle
end

-----------------------------WHEEL CLASS------------------------------

local Wheel = {}
Wheel.__index = Wheel

type Wheel = typeof(setmetatable({} :: {
	_vehicle: Vehicle,
	_wheel: BasePart,
	_tire_compound: number,
	_traction: number,
	_temperature: number,
	_stress: number,
	_health: number,
	health_changed: Signal,

	new: (vehicle: Vehicle, wheel: BasePart, powered: boolean, config: Config.wheels) -> Wheel,
	get_traction: (self: Wheel) -> number,
	update_traction: (self: Wheel, traction: number) -> (),
	change_wheel: (self: Wheel, compound: Enums.TireCompound) -> (),
	get_tire_size: (self: Wheel) -> number,
	get_health: (self: Wheel) -> number,
	change_health: (self: Wheel, amount: number) -> (),
	update: (self: Wheel, dt: number) -> {number},
}, Wheel))

function Wheel.new(vehicle: Vehicle, wheel: BasePart, config: Config.wheels): Wheel
	local self = setmetatable({}, Wheel)
	self._vehicle = vehicle
	self._wheel = wheel
	self._tire_model = 0 -- TODO: REPLACE THIS WITH MODEL
	self._tire_compound = config.default_tire_compound
	self._traction = config.default_traction
	self._temperature = 15 -- in °C
	self._stress = 0
	self._health = 100
	self.health_changed = Signal.new()

	return self
end

function Wheel.get_traction(self: Wheel): number
	return self._traction
end

function Wheel.update_traction(self: Wheel, traction: number): ()
	self._traction = traction
end

function Wheel.change_wheel(self: Wheel, compound: Enums.TireCompound)
	self._tire_compound = compound
	self._traction = 0 -- TODO: replace with a dictionary lookup of default tractions?
	self._health = 100
	self._stress = 0
	self._temperature = 15 -- We could probably get the temperature from whatever weather control system nate has, convert to C

	-- I guess I should update the tire model in here?
end

function Wheel.get_tire_size(self: Wheel): number
	return self._wheel.Size.Y
end

function Wheel.get_health(self: Wheel): number
	return self._health
end

function Wheel.change_health(self: Wheel, amount: number): ()
	self._health += amount
end

local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Include
params.CollisionGroup = "Car"
function Wheel.update(self: Wheel, dt: number): {number}
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

export type Vehicle = typeof(setmetatable({} :: {
	engine: Engine,
	generator: Generator?,
	turbocharger: Turbocharger?,
	gearbox: Gearbox,
	front_axle: Axle,
	rear_axle: Axle,
	steering_column: SteeringColumn,
	wheels: {Wheel},
	_max_downforce: number,
	_downforce_percentage: number,
	_drivetrain: Enums.Drivetrain,
	_chassis: BasePart,
	model: Model,
	_input_object: Input,
	_camera_object: Camera,

	new: (wheels: {[string]: BasePart}, config: Config) -> Vehicle,
	get_wheel_speed: (self: Vehicle) -> number,
	get_real_speed: (self: Vehicle) -> number,
	is_flipped: (self: Vehicle) -> boolean,
	update: (self: Vehicle, values: {number}, dt: number) -> {number},
}, Vehicle))

local function create_vehicle_model(prefab: Model, cframe: CFrame, config): Model
	local vehicle = prefab:Clone()
	local chassis_part = vehicle.Chassis.ChassisPart
	
	for _, wheel in pairs(vehicle.Chassis.Wheels:GetChildren()) do
		if not wheel:IsA("BasePart") then
			return
		end
		if wheel.Parent.Name ~= "Wheels" then -- bad hardcoding!! 
			return
		end

		-- TODO: is_front and wheel_side currently has no support for CFrames that have the same CFrame as ChassisPart
		local is_front: boolean = chassis_part.CFrame:PointToObjectSpace(wheel.Position).Z > 0
		local wheel_side: number = chassis_part.CFrame:PointToObjectSpace(wheel.Position).X > 0 and 1 or -1 -- Right = 1, Left = -1
		local wheel_caster = is_front and config.WheelAlignment.FCaster or config.WheelAlignment.RCaster
		local wheel_toe = is_front and config.WheelAlignment.FToe or config.WheelAlignment.RToe
		local wheel_camber = is_front and config.WheelAlignment.FCamber or config.WheelAlignment.RCamber

		wheel.CFrame = wheel.CFrame * CFrame.Angles(
			math.rad(wheel_caster * wheel_side),
			math.rad(wheel_toe * -wheel_side),
			math.rad(wheel_caster)
		) -- Thanks A-Chassis
	end 
end

local function update_downforce(self: Vehicle, chassis_part: Part, downforce_object: VectorForce): ()
	local normalized_velocity = chassis_part.AssemblyLinearVelocity.Unit
	local downforce_factor = normalized_velocity:Dot(chassis_part.CFrame.RightVector.Unit)
	local downforce = 0
	if downforce_factor ~= -1 then -- Going forward
		local downforce_mapped_to_speed = chassis_part.AssemblyLinearVelocity.Magnitude * downforce_curve_value
		downforce = downforce_mapped_to_speed * self._max_downforce * -chassis_part.CFrame.UpVector
	end
	
	--- Convert newtons to rowtons
	-- 1 newton = 0.163 rowtons
	downforce_object.Force.Y = (downforce / 0.163) * self._downforce_percentage
end

function Vehicle.new(prefab: Model, cframe: CFrame, wheels: {[string]: BasePart}, config: Config): Vehicle
	local self = setmetatable({}, Vehicle)
	self.engine = Engine.new(self, config.engine)
	self.generator = config.generator and Generator.new(self, config.generator) or nil
	self.turbocharger = config.turbocharger and Turbocharger.new(self, config.turbocharger) or nil
	self.gearbox = Gearbox.new(self, config.gearbox)
	self.front_axle = Axle.new(self, Enums.AxleType.Front)
	self.rear_axle = Axle.new(self, Enums.AxleType.Rear)
	self.steering_column = SteeringColumn.new(self, config.steering_column)
	self.wheels = {}
	for wheel_name, wheel_part in pairs(wheels) do
		self.wheels[wheel_name] = Wheel.new(self, wheel_part, config.wheels)
	end
	
	self._max_downforce = config -- TODO: GET CONFIG INDEX IN NEWTONS
	self._downforce_percentage = config -- TODO: ABOVE
	
	self._drivetrain = config.drivetrain -- TODO: maybe remove
	self._chassis = config.chassis -- TODO: maybe remove
	
	self.model = create_vehicle_model(prefab)
	self._input_object = Input.new()
	self._camera_object = Camera.new() --TODO: PASS IN CAMERA ATTACHMENTS
	return self
end

function Vehicle.bind_objects(self: Vehicle, camera_object: Camera, input_object: Input.Input): ()
	local vehicle_seat = self.model:FindFirstDescendant("VehicleSeat") -- change this to driveseat maybe to allow for multiple seats?
	
	-- TODO: add events here
end

function Vehicle.get_wheel_speed(self: Vehicle): number
	local average_wheel_speed = 0
	for _, wheel in pairs(self.wheels) do
		average_wheel_speed += wheel._wheel.AssemblyAngularVelocity -- This doesn't take into account when a tyre is detached
	end
	
	return average_wheel_speed
end

--- Vehicle.get_real_speed()
-- Returns the speed of vehicle in studs per second
function Vehicle.get_real_speed(self: Vehicle): number
	return -self._chassis.CFrame:PointToObjectSpace(self._chassis.AssemblyLinearVelocity).Z
end

function Vehicle.is_flipped(self: Vehicle): boolean
	local up_cframe = self._chassis.CFrame.UpVector
	local position = self._chassis.Position -- get model equivalent -- TODO: REWRITE THIS INTO A ONE LINER
	return position.Y > (position + up_cframe).Y
end

function Vehicle.update(self: Vehicle, values: {throttle: number, steer: number}, dt: number): {number}
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
