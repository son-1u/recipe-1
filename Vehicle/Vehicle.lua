--[[
The base class of the chassis. It works in a module system allowing you to add extra components to the mechanics
for different type of cars.
]]--

-------------------------------SERVICES-------------------------------

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

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
	_idle_throttle: number,
	_rpm: number,
	_min_rpm: number,
	_max_rpm: number,
	_torque: number,
	_min_torque: number,
	_max_torque: number,
	_horsepower: number,
	_max_horsepower: number,
	_health: number,
	health_changed: Signal,

	new: (vehicle: Vehicle, config: Config.engine) -> Engine,
	get_torque: (self: Engine) -> number,
	get_rpm: (self: Engine) -> number,
	get_health: (self: Engine) -> number,
	change_health: (self: Engine, amount: number) -> (),
	update: (self: Engine, throttle: number, engine_boost: number?, dt: number) -> (number, number),
	destroy: (self: Engine) -> (),
}, Engine))

local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

function Engine.new(vehicle: Vehicle, config: Config.engine): Engine
	local self = setmetatable({}, Engine)
	self._vehicle = vehicle
	self._idle_throttle = config.idle_throttle
	self._rpm = 0
	self._min_rpm = config.min_rpm -- Idle RPM
	self._max_rpm = config.max_rpm -- Redline
	self._torque = 0
	self._min_torque = config.min_torque -- Idle torque
	self._max_torque = config.max_torque -- Peak torque
	self._horsepower = 0
	self._max_horsepower = config.max_horsepower
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

function Engine.update(self: Engine, throttle: number, engine_boost: number?, dt: number): (number, number)
	if self._health <= 0 then
		if self._rpm > 0 then
			self._rpm = lerp(self._rpm, 0, 0.25 * dt)
		end
		if self._torque > 0 then
			self._torque = lerp(self._torque, 0.25 * dt) -- I honestly don't know how long inertia is gonna carry the engine so I just put an arbitrary value
		end
		return self._rpm, self._torque
	end
	
	--- Redline
	-- This is done here because we lower the throttle to simulate fuel flow being lowered (because im not coding an entire engine simulation into here)
	if self._rpm >= self._max_rpm then
		if throttle > self._idle_throttle then
			throttle = self._idle_throttle
		end
	end

	--- RPM Calculation
	-- Uses an exponential curve (faster rise near min rpm, tapers off near max rpm)
	-- Formula: min + (max - min) * (throttle ^ power)
	-- Power is the sharpness of the rpm rise
	-- Power = 1 (linear rise)
	-- Power < 1 (faster early rise, slower near the top)
	-- Power > 1 (slower early rise, faster near the top)
	local target_rpm = 0
	if throttle == 0 then
		target_rpm = 0
	elseif throttle > 0 or throttle < 0 then
		target_rpm = self._max_rpm
	end
	
	--- Smoothing the RPM
	-- For the third argument, the numerical value multiplied by deltatime is the rpm acceleration rate from min rpm to max rpm
	-- The smaller the number, the longer it takes
	-- 0.5 = two seconds, 1 = one second, 2 = half a second
	self._rpm = math.clamp(lerp(self._rpm, target_rpm, 0.45 * dt), 0, self._max_rpm)
	
	self._torque = math.clamp(self._rpm <= 7000 and (0.03 * self._rpm) + 90 or (-0.025 * self._rpm) + 475, self._min_torque, self._max_torque)
	return self._rpm, self._torque
end

function Engine.destroy(self: Engine): ()
	self._vehicle = nil
	self._idle_throttle = nil
	self._rpm = nil
	self._min_rpm = nil
	self._max_rpm = nil
	self._torque = nil
	self._min_torque = nil
	self._max_torque = nil
	self._horsepower = nil
	self._max_horsepower = nil
	self._health = nil
	self.health_changed:DisconnectAll()
	self.health_changed = nil
end

---------------------------GENERATOR CLASS----------------------------

local Generator = {}
Generator.__index = Generator

type Generator = typeof(setmetatable({} :: {
	_vehicle: Vehicle,
	_rpm: number,
	_min_rpm: number,
	_max_rpm: number,
	--_active: boolean,
	--_energy_stored: number,
	--_max_energy: number,
	--_charge_rate: number,
	--_discharge_rate: number,
	_max_output: number,
	_health: number,
	health_changed: Signal,

	new: (vehicle: Vehicle, config: Config.generator) -> Generator,
	--activate: (self: Generator, value: boolean) -> (),
	--is_active: (self: Generator) -> boolean,
	get_health: (self: Generator) -> number,
	change_health: (self: Generator, amount: number) -> (),
	destroy: (self: Generator) -> (),
}, Generator))

function Generator.new(vehicle: Vehicle, config: Config.generator): Generator
	local self = setmetatable({}, Generator)
	self._vehicle = vehicle
	self._rpm = 0
	self._min_rpm = config.min_rpm
	self._max_rpm = config.max_rpm
	--self._active = false
	--self._energy_stored = 4000 -- in kJ
	--self._max_energy = config.max_energy or 4000
	--self._charge_rate = config.charge_rate or 50
	--self._discharge_rate = config.discharge_rate or 120
	self._max_output = 0 -- in kJ
	self._health = 100
	self.health_changed = Signal.new()

	return self
end

--function Generator.activate(self: Generator, value: boolean): ()
--	self._active = value
--end

--function Generator.is_active(self: Generator): boolean
--	return self._active
--end

function Generator.get_health(self: Generator): number
	return self._health
end

function Generator.change_health(self: Generator, amount: number): ()
	self._health += amount
end

function Generator.update(self: Generator, dt: number): number
	if self._health <= 0 then
		return 0
	end

	return self._output
end

function Generator.destroy(self: Generator): ()
	self._vehicle = nil
	self._rpm = nil
	self._min_rpm = nil
	self._max_rpm = nil
	self._max_output = nil
	self._health = nil
	self.health_changed:DisconnectAll()
	self.health_changed = nil
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
	destroy: (self: Turbocharger) -> (),
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

function Turbocharger.destroy(self: Turbocharger): ()
	self._vehicle = nil
	self._active = nil
	self._boost = nil
	self._health = nil
	self.health_changed:DisconnectAll()
	self.health_changed = nil
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
	update: (self: Gearbox, engine_rpm: number, engine_torque: number) -> (number, number),
	destroy: (self: Gearbox) -> (),
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

function Gearbox.destroy(self: Gearbox): ()
	self._vehicle = nil
	self._gear = nil
	self._gear_ratios = nil
	self._final_drive = nil
	self._transmission = nil
	self._max_gear_rpms = nil
	self._shift_time = nil
	self._health = nil
	self.health_changed:DisconnectAll()
	self.health_changed = nil
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
	destroy: (self: Axle) -> (),
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

function Axle.destroy(self: Axle): ()
	self._vehicle = nil
	self._axle_type = nil
	self._connected_wheels = nil
	self._health = nil
	self.health_changed:DisconnectAll()
	self.health_changed = nil
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
	destroy: (self: SteeringColumn) -> (),
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

function SteeringColumn.destroy(self: SteeringColumn): ()
	self._vehicle = nil
	self._steering_angle = nil
	self._max_steering_angle = nil
	self._health = nil
	self.health_changed:DisconnectAll()
	self.health_changed = nil
end

-----------------------------WHEEL CLASS------------------------------

local Wheel = {}
Wheel.__index = Wheel

type Wheel = typeof(setmetatable({} :: {
	_vehicle: Vehicle,
	wheel: BasePart,
	is_front: boolean,
	_tire_compound: number,
	_traction: number,
	_temperature: number,
	_stress: number,
	_health: number,
	health_changed: Signal,

	new: (vehicle: Vehicle, chassis_part: BasePart, wheel: BasePart, powered: boolean, config: Config.wheels) -> Wheel,
	get_traction: (self: Wheel) -> number,
	update_traction: (self: Wheel, traction: number) -> (),
	change_wheel: (self: Wheel, compound: Enums.TireCompound) -> (),
	get_wheel_speed: (self: Wheel) -> number,
	get_tire_diameter: (self: Wheel) -> number,
	get_health: (self: Wheel) -> number,
	change_health: (self: Wheel, amount: number) -> (),
	update: (self: Wheel, dt: number) -> {number},
	destroy: (self: Wheel) -> (),
}, Wheel))

function Wheel.new(vehicle: Vehicle, chassis_part: BasePart, wheel: BasePart, config: Config.wheels): Wheel
	local self = setmetatable({}, Wheel)
	self._vehicle = vehicle
	self.wheel = wheel
	self.is_front = -chassis_part.CFrame:PointToObjectSpace(wheel.Position).Z > 0
	self.tire_model = 0 -- TODO: REPLACE THIS WITH MODEL
	self.tire_compound = config.default_tire_compound
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

function Wheel.get_wheel_speed(self: Wheel): number
	
	--- Wheel speed calculation
	-- Get the wheel's angular velocity (in radians per second)
	-- Compare it to the axis of rotation (to avoid change in camber affecting the speed)
	-- Multiply by the radius
	-- Return the absolute value to avoid a negative speed
	return math.abs(self.wheel.AssemblyAngularVelocity:Dot(self.wheel.CFrame.RightVector) * (self:get_tire_diameter() / 2))
end

function Wheel.get_tire_diameter(self: Wheel): number
	return self.wheel.Size.Y
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
	local result = workspace:Raycast(self.wheel.Position, Vector3.new(0, -1, 0), params)
	if result.Material ~= Enum.Material.Concrete then
		self:change_health(-1 * dt) -- Update this to take into account tire compound
	end

	-- update stress
	-- update friction
	-- update wear
	-- update temperature
	-- update health
end

function Wheel.destroy(self: Wheel): ()
	self._vehicle = nil
	self.wheel = nil -- Don't need to destroy wheel part since Vehicle.destroy does it already
	self.is_front = nil
	self.tire_model = nil
	self.tire_compound = nil
	self._traction = nil
	self._temperature = nil
	self._stress = nil
	self._health = nil
	self.health_changed:DisconnectAll()
	self.health_changed = nil
end

------------------------------MAIN CLASS------------------------------

local Vehicle = {}
Vehicle.__index = Vehicle

export type Vehicle = typeof(setmetatable({} :: {
	components: {
		engine: Engine,
		generator: Generator?,
		turbocharger: Turbocharger?,
		gearbox: Gearbox,
		front_axle: Axle,
		rear_axle: Axle,
		steering_column: SteeringColumn,
		wheels: {Wheel},
	},
	_max_downforce: number,
	_downforce_percentage: number,
	model: Model,
	_drivetrain: Enums.Drivetrain,
	_chassis: BasePart,
	_input_object: Input.Input,
	_camera_object: Camera.Camera,

	new: (wheels: {[string]: BasePart}, config: Config) -> Vehicle,
	get_wheel_speed: (self: Vehicle) -> number,
	get_real_speed: (self: Vehicle) -> number,
	is_flipped: (self: Vehicle) -> boolean,
	update: (self: Vehicle, values: {number}, dt: number) -> (),
	destroy: (self: Vehicle) -> (),
}, Vehicle))

local function create_vehicle_model(prefab: Model, spawn_position: CFrame, config): Model
	local vehicle = prefab:Clone()
	local chassis_part = vehicle.chassis.chassis_part
	
	-- Weight
	local weight_brick_front = vehicle.chassis:FindFirstChild("weight_brick_front")
	weight_brick_front.CustomPhysicalProperties = true
	weight_brick_front.CustomPhysicalProperties.Density = config.vehicle_weight * config.weight_distribution
	local weight_brick_rear = vehicle.chassis:FindFirstChild("weight_brick_rear")
	weight_brick_rear.CustomPhysicalProperties = true
	weight_brick_rear.CustomPhysicalProperties.Density = config.vehicle_weight * (1 - config.weight_distribution)
	
	
	-- Wheels
	for _, wheel in pairs(vehicle.Chassis.Wheels:GetChildren()) do
		if not wheel:IsA("BasePart") then
			return
		end
		if wheel.Parent.Name ~= "Wheels" then -- bad hardcoding!! 
			return
		end

		-- TODO: is_front and wheel_side currently has no support for CFrames that have the same CFrame as ChassisPart
		local is_front: boolean = -chassis_part.CFrame:PointToObjectSpace(wheel.Position).Z > 0
		local wheel_side: number = chassis_part.CFrame:PointToObjectSpace(wheel.Position).X > 0 and 1 or -1 -- Right = 1, Left = -1
		local wheel_caster = is_front and config.WheelAlignment.FCaster or config.WheelAlignment.RCaster
		local wheel_toe = is_front and config.WheelAlignment.FToe or config.WheelAlignment.RToe
		local wheel_camber = is_front and config.WheelAlignment.FCamber or config.WheelAlignment.RCamber

		wheel.CFrame = wheel.CFrame * CFrame.Angles(
			math.rad(wheel_caster * wheel_side),
			math.rad(wheel_toe * -wheel_side),
			math.rad(wheel_caster)
		)
	end
	vehicle.Parent = workspace
	vehicle.PrimaryPart.CFrame = spawn_position
	
	-- Unanchor
	for _, descendant in pairs(vehicle:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = false
		end
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
	downforce_object.Force.Y = math.min((downforce / 0.163) * self._downforce_percentage, self._max_downforce)
end

function Vehicle.new(prefab: Model, spawn_position: CFrame, wheels: {[string]: BasePart}, config: Config): Vehicle
	local self = setmetatable({}, Vehicle)
	
	self.model = create_vehicle_model(prefab)
	self._drivetrain = config.drivetrain -- TODO: maybe remove
	self._chassis = self.model.chassis:FindFirstChild("chassis_part")
	
	self.components = {}
	for _, component in pairs(config.components) do
		if allowed_types[component.__type] ~= nil then
			self.components[component]
		end
	end

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
	
	self._input_object = Input.new()
	self._camera_object = Camera.new() --TODO: PASS IN CAMERA ATTACHMENTS
	
	self._max_downforce = config -- TODO: GET CONFIG INDEX IN NEWTONS
	self._downforce_percentage = config -- TODO: ABOVE
	
	self:bind_objects(self._input_object, self._camera_object)
	return self
end

function Vehicle.bind_objects(self: Vehicle, input_object: Input.Input, camera_object: Camera.Camera): ()
	local vehicle_seat = self.model:FindFirstDescendant("driver_seat") -- change this to driveseat maybe to allow for multiple seats?
	
	local connection
	vehicle_seat:GetPropertyChangedSignal("Occupant"):Connect(function()
		-- TODO: CAR ENTRY ANIMATION
		
		if vehicle_seat.Occupant ~= Players.LocalPlayer then
			return -- I don't know if this is redundant, since client is rendering each car and creating events for them, don't want to control another person car, right?
		end
		
		if vehicle_seat.Occupant ~= nil then
			connection = RunService.Stepped:Connect(function(_, dt: number)
				local throttle, steer = self._input_object, 1 -- TODO: GET INPUT FROM INPUT METHOD
				self:update({throttle, steer}, dt)
			end)
			
			camera_object:enable()
		else
			if connection ~= nil then connection:Disconnect() end
			camera_object:disable()
		end
	end)
end

function Vehicle.get_wheel_speed(self: Vehicle): number
	local total_wheel_speed = 0
	local wheel_count = 0
	if self._drivetrain == Enums.Drivetrain.FWD then
		
	elseif self._drivetrain == Enums.Drivetrain.RWD then
		
	elseif self._drivetrain == Enums.Drivetrain.AWD then
		
	end
	
	return total_wheel_speed / wheel_count
end

--- Vehicle.get_real_speed()
-- Returns the speed of vehicle in studs per second
-- Z axis faces backward so return the negative (forward speed)
function Vehicle.get_real_speed(self: Vehicle): number
	return -self._chassis.CFrame:PointToObjectSpace(self._chassis.AssemblyLinearVelocity).Z
end

function Vehicle.is_flipped(self: Vehicle): boolean
	return self._chassis.Position.Y > (self._chassis.Position + self._chassis.CFrame.UpVector).Y -- Check if this is correct
end

function Vehicle.update(self: Vehicle, input: {throttle: number, steer: number}, dt: number)
	local engine_boost = 0

	if self.generator then
		engine_boost += self.generator:update()
	end
	if self.turbocharger then
		engine_boost += self.turbocharger:update()
	end

	local engine_rpm, engine_torque = self.engine:update(input.throttle, engine_boost, dt)
	local gearbox_rpm, gearbox_torque = self.gearbox:update(engine_rpm, engine_torque)
	local steer = self.steering_column:update(input.steer, dt)
	
	for _, wheel in pairs(self.wheels) do
		wheel:update()
	end
end

function Vehicle.destroy(self: Vehicle): ()
	local occupant = self.model:FindFirstDescendant("driver_seat").Occupant ~= nil
	if occupant ~= nil then
		occupant.Parent:FindFirstChild("Humanoid").Jump = true
	end
	
	self.model:Destroy()
	self.model = nil
	self._drivetrain = nil
	self._chassis = nil
	
	self._max_downforce = nil
	self._downforce_percentage = nil
	
	for _, component in pairs(self.components) do
		component:destroy()
	end
	
	self._input_object:destroy()
	self._camera_object:destroy()
	self._input_object = nil
	self._camera_object = nil
end

return Vehicle
