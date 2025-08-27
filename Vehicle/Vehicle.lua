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

-------------------------BASE COMPONENT CLASS-------------------------

local BaseComponent = {}
BaseComponent.__index = BaseComponent

type BaseComponent = typeof(setmetatable({} :: {
	_vehicle: Vehicle,
	_health: number,
	health_changed: Signal,
	
	new: (vehicle: Vehicle, component_properties: {}) -> BaseComponent,
	get_health: (self: BaseComponent) -> number,
	change_health: (self: BaseComponent, amount: number) -> (),
	destroy: (self: BaseComponent) -> (),
}, BaseComponent))

function BaseComponent.new(vehicle: Vehicle, component_properties: {}): BaseComponent
	local self = {
		_vehicle = vehicle,
		_health = 100,
		health_changed = Signal.new(),
	}
	
	for k, v in pairs(component_properties) do
		self[k] = v
	end
	
	return self
end

function BaseComponent.get_health(self: BaseComponent): number,
	return self._health
end

function BaseComponent.change_health(self: BaseComponent, amount: number): ()
	self._health = math.clamp(self._health + amount, 0, 100)
end

function BaseComponent.destroy(self: BaseComponent): ()
	for k, v in pairs(self) do
		if getmetatable(v) == Signal then
			v:DisconnectAll()
		end
		
		self[k] = nil
	end
end

-----------------------------ENGINE CLASS-----------------------------

local Engine = setmetatable({}, BaseComponent)
Engine.__index = Engine

type Engine = BaseComponent & typeof(setmetatable({} :: {
	_idle_throttle: number,
	_rpm: number,
	_min_rpm: number,
	_max_rpm: number,
	_torque: number,
	_min_torque: number,
	_max_torque: number,
	_horsepower: number,
	_max_horsepower: number,

	new: (vehicle: Vehicle, config: {}) -> Engine,
	get_torque: (self: Engine) -> number,
	get_rpm: (self: Engine) -> number,
	update: (self: Engine, throttle: number, engine_boost: number?, dt: number) -> (number, number),
}, Engine))

local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

function Engine.new(vehicle: Vehicle, config: {}): Engine
	return setmetatable(BaseComponent.new(vehicle, {
		_idle_throttle = config.idle_throttle,
		_rpm = 0,
		_min_rpm = config.min_rpm, -- Idle RPM
		_max_rpm = config.max_rpm, -- Redline
		_torque = 0,
		_min_torque = config.min_torque, -- Idle torque
		_max_torque = config.max_torque, -- Peak torque
		_horsepower = 0,
		_max_horsepower = config.max_horsepower,
	}), Engine)
end

-- Returns torque in Newton-meter (Nm)
function Engine.get_torque(self: Engine): number
	return self._torque
end

function Engine.get_rpm(self: Engine): number
	return self._rpm
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

-------------------------ELECTRIC MOTOR CLASS-------------------------

local ElectricMotor = setmetatable({}, BaseComponent)
ElectricMotor.__index = ElectricMotor

type ElectricMotor = BaseComponent & typeof(setmetatable({} :: {
	_rpm: number,
	_max_rpm: number,
	_torque: number,
	_min_torque: number,
	_max_torque: number,
	_kilowatts: number,
	_max_kilowatts: number,
	
	new: (vehicle: Vehicle, config: {}) -> ElectricMotor,
	get_torque: (self: ElectricMotor) -> number,
	get_rpm: (self: ElectricMotor) -> number,
	update: (self: ElectricMotor, throttle: number, dt: number) -> (number, number),
}, ElectricMotor))

function ElectricMotor.new(vehicle: Vehicle, config: {}): ()
	return setmetatable(BaseComponent.new(vehicle, {
		_rpm = 0,
		_max_rpm = config.max_rpm,
		_torque = 0,
		_min_torque = config.min_torque,
		_max_torque = config.max_torque,
		_kilowatts = 0,
		_max_kilowatts = config.max_kilowatts,
	}), ElectricMotor)
end

-- Returns torque in Newton-meter (Nm)
function ElectricMotor.get_torque(self: ElectricMotor): number
	return self._torque
end

function ElectricMotor.get_rpm(self: ElectricMotor): number
	return self._rpm
end

function ElectricMotor.update(self: ElectricMotor, dt: number): (number, number)
	
end

--------------------------TURBOCHARGER CLASS--------------------------

local Turbocharger = setmetatable({}, BaseComponent)
Turbocharger.__index = Turbocharger

type Turbocharger = BaseComponent & typeof(setmetatable({} :: {
	_rpm: number,
	_max_rpm: number,

	new: (vehicle: Vehicle) -> Turbocharger,
	update: (self: Turbocharger, dt: number) -> (),
}, Turbocharger))

function Turbocharger.new(vehicle: Vehicle, config): Turbocharger
	return setmetatable(BaseComponent.new(vehicle, {
		_rpm = 0,
		_max_rpm = config.max_rpm,
	}), Turbocharger)
end

function Turbocharger.get_boost(self: Turbocharger): number
	return self._boost
end

function Turbocharger.update(self: Turbocharger, dt: number): ()
	
end

-----------------------------GEARBOX CLASS----------------------------

local Gearbox = setmetatable({}, BaseComponent)
Gearbox.__index = Gearbox

type Gearbox = BaseComponent & typeof(setmetatable({} :: {
	_gear: number,
	_gear_ratios: {number},
	_final_drive: number,
	_transmission: number,
	_max_gear_rpms: {number},
	_shift_time: number,

	new: (vehicle: Vehicle, config: {}) -> Gearbox,
	shift: (self: Gearbox, direction: Enums.GearShiftDirection) -> (),
	get_gear: (self: Gearbox) -> number,
	update: (self: Gearbox, engine_rpm: number, engine_torque: number) -> (number, number),
}, Gearbox))

function Gearbox.new(vehicle: Vehicle, config: {}): Gearbox
	return setmetatable(BaseComponent.new(vehicle, {
		_gear = 1,
		_gear_ratios = config.gear_ratios,
		_final_drive = config.final_drive,
		_transmission = config.transmission,
		_max_gear_rpms = {},
		_shift_time = config.shift_time,
	}), Gearbox)
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

local Axle = setmetatable({}, BaseComponent)
Axle.__index = Axle

type Axle = BaseComponent & typeof(setmetatable({} :: {
	_connected_wheels: {Wheel},

	new: (vehicle: Vehicle, connected_wheels: {Wheel}) -> Axle,
}, Axle))

function Axle.new(vehicle: Vehicle, connected_wheels: {Wheel}): Axle	
	local self = setmetatable(BaseComponent.new(vehicle, {
		_vehicle = vehicle,
		_connected_wheels = connected_wheels,
		_health = 100,
		health_changed = Signal.new(),
	}), Axle)
	
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

------------------------STEERING COLUMN CLASS-------------------------

local SteeringColumn = setmetatable({}, BaseComponent)
SteeringColumn.__index = SteeringColumn

type SteeringColumn = BaseComponent & typeof(setmetatable({} :: {
	_steering_angle: number,
	_max_steering_angle: number,

	new: (vehicle: Vehicle, config: {}) -> SteeringColumn,
	update: (self: SteeringColumn, steer_float: number, dt: number) -> number,
}, SteeringColumn))

function SteeringColumn.new(vehicle: Vehicle, config: {}): SteeringColumn
	return setmetatable(BaseComponent.new(vehicle, {
		_steering_angle = 0,
		_max_steering_angle = config.max_steering_angle,
	}), SteeringColumn)
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

local Wheel = setmetatable({}, BaseComponent)
Wheel.__index = Wheel

type Wheel = BaseComponent & typeof(setmetatable({} :: {
	wheel: BasePart,
	is_front: boolean,
	_tire_compound: number,
	_traction: number,
	_temperature: number,
	_stress: number,

	new: (vehicle: Vehicle, chassis_part: BasePart, wheel_part: BasePart, config: {}) -> Wheel,
	get_traction: (self: Wheel) -> number,
	update_traction: (self: Wheel, traction: number) -> (),
	change_wheel: (self: Wheel, compound: Enums.TireCompound) -> (),
	get_wheel_speed: (self: Wheel) -> number,
	get_tire_diameter: (self: Wheel) -> number,
	update: (self: Wheel, dt: number) -> {number},
}, Wheel))

function Wheel.new(vehicle: Vehicle, chassis_part: BasePart, wheel_part: BasePart, config: {}): Wheel	
	return setmetatable(BaseComponent.new(vehicle, {
		wheel = wheel_part,
		is_front = -chassis_part.CFrame:PointToObjectSpace(wheel_part.Position).Z > 0,
		tire_model = config.tire_model,
		tire_compound = config.default_tire_compound,
		_traction = config.default_traction,
		_temperature = workspace:GetAttribute("GlobalTemperature") or 20,
		_stress = 0,
	}), Wheel)
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

	new: (prefab: Model, spawn_position: CFrame, config: {}) -> Vehicle,
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

function Vehicle.new(prefab: Model, spawn_position: CFrame, config: {}): Vehicle
	local self = setmetatable({
		model = create_vehicle_model(prefab),
		_drivetrain = config.drivetrain,
		_chassis = nil,

		_input_object = Input.new(),
		_camera_object = Camera.new(), --TODO: PASS IN CAMERA ATTACHMENTS

		_max_downforce = config, -- TODO: GET CONFIG INDEX IN NEWTONS
		_downforce_percentage = config, -- TODO: ABOVE
	}, Vehicle)
	
	self._chassis = self.model.chassis:FindFirstChild("chassis_part")
	
	self.engine = Engine.new(self, config.engine)
	self.electric_motor = config.electric_motor and Engine.new(self, config.electric_motor) or nil
	self.turbocharger = config.turbocharger and Turbocharger.new(self, config.turbocharger) or nil
	self.gearbox = Gearbox.new(self, config.gearbox)
	self.front_axle = Axle.new(self, config.axle)
	self.rear_axle = Axle.new(self, config.axle)
	self.steering_column = SteeringColumn.new(self, config.steering_column)
	self.wheels = {}
	
	for _, wheel_part in pairs(self.model:WaitForChild("chassis").wheels) do
		self.wheels[wheel_part.Name] = Wheel.new(self, wheel_part, config.wheels)
	end

	self:bind_objects(self._input_object, self._camera_object)
	return self
end

function Vehicle.bind_objects(self: Vehicle, input_object: Input.Input, camera_object: Camera.Camera): ()
	local vehicle_seat = self.model:FindFirstDescendant("driver_seat")
	
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
	
	local function clear_object(object: {}): ()
		if object.destroy() then
			object:destroy()
		end
	end
	
	for k, v in pairs(self) do
		if typeof(v) == "Model" then
			v:Destroy()
		end
		if typeof(v) == "table" then
			clear_object(v)
		end
		if v == self.wheels then
			for _, wheel in pairs(self.wheels) do
				clear_object(wheel)
			end
		end
		
		self[k] = nil
	end
end

return Vehicle
