--[[
The base class of the chassis. It works in a module system allowing you to add extra components to the mechanics
for different type of cars.
]]--

-------------------------------SERVICES-------------------------------

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")

--------------------------------IMPORTS-------------------------------

local Enums = require(script.utils.enums)
local Signal = require(script.utils.Signal)

local HUD = require(script.internal_objects.hud)
local Input = require(script.internal_objects.input)
local Camera = require(script.internal_objects.camera)

--local create_vehicle_model = require(script.utils.create_vehicle_model)

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

function BaseComponent.get_health(self: BaseComponent): number
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
	_engine_inertia: number,
	_idle_throttle: number,
	_rpm: number,
	_min_rpm: number,
	_max_rpm: number,
	_max_torque_rpm: number,
	_torque: number,
	_min_torque: number,
	_max_torque: number,
	_redline_torque: number,
	_horsepower: number,

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
		_engine_inertia = config.engine_inertia,
		_idle_throttle = config.idle_throttle,
		_rpm = 0,
		_min_rpm = config.min_rpm, -- Idle RPM
		_max_rpm = config.max_rpm, -- Redline
		_max_torque_rpm = config.peak_torque_rpm,
		_torque = 0,
		_min_torque = config.min_torque, -- Idle torque
		_max_torque = config.max_torque, -- Peak torque
		_redline_torque = config.redline_torque,
		_horsepower = 0,
	}), Engine)
end

-- Returns torque in Newton-meter (Nm)
function Engine.get_torque(self: Engine): number
	return self._torque
end

function Engine.get_rpm(self: Engine): number
	return self._rpm
end

--- Calculate Quadratic Bezier Curve
-- rpm: number, to be converted to t (time) between 0-1
-- p0: number, start point
-- p1: number, control point, defines the curve
-- p2: number, end point
local function calculate_quadratic_bezier_curve(rpm: number, max_rpm: number, p0: {x: number, y: number}, curve_peak: {x: number, y: number}, p2: {x: number, y: number}): number
	-- Calculate p1 based off of p0, p2, and t
	local p1 = {x = nil, y = nil}
	
	local curve_peak_t = curve_peak.x / max_rpm
	local denominator = 2*curve_peak_t*(1 - curve_peak_t)
	p1.x = (curve_peak.x - (1 - curve_peak_t)^2 * p0.x - curve_peak_t^2 * p2.x) / denominator
	p1.y = (curve_peak.y - (1 - curve_peak_t)^2 * p0.y - curve_peak_t^2 * p2.y) / denominator

	local t = rpm / max_rpm
	-- Torque corresponding to the y axis, so use y-coordinates of points to calculate
	return (1 - t)^2 * p0.y + 2*(1 - t)*t * p1.y + t^2 * p2.y
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

	local target_rpm = 0
	if throttle == 0 then
		target_rpm = 0
	elseif throttle > 0 or throttle < 0 then
		target_rpm = self._max_rpm
	end
	
	-- Some random formula ChatGPT gave me for semi-realistic RPM delta. 9.55 is the result of 60/(2pi)
	self._rpm = math.clamp(
		(self._rpm + ((self._torque * math.abs(throttle)) / self._engine_inertia) * dt * 9.55),
		self._min_rpm,
		self._max_rpm
	)
	self._torque = math.clamp(
		calculate_quadratic_bezier_curve(
			self._rpm,
			self._max_rpm,
			{x = 0, y = 0},
			{x = self._max_torque_rpm, y = self._max_torque},
			{x = self._max_rpm, y = self._redline_torque}
		) * (self._health / 100),
		0,
		self._max_torque
	)
	self._horsepower = (self._rpm * self._torque) / 7217
	return self._rpm, self._torque
end

-------------------------ELECTRIC MOTOR CLASS-------------------------

local ElectricMotor = setmetatable({}, BaseComponent)
ElectricMotor.__index = ElectricMotor

type ElectricMotor = BaseComponent & typeof(setmetatable({} :: {
	_motor_inertia: number,
	_rpm: number,
	_max_rpm: number,
	_torque: number,
	_min_torque: number,
	_max_torque: number,
	_torque_curve_coefficient: number,
	_kilowatts: number,
	
	new: (vehicle: Vehicle, config: {}) -> ElectricMotor,
	get_torque: (self: ElectricMotor) -> number,
	get_rpm: (self: ElectricMotor) -> number,
	update: (self: ElectricMotor, throttle: number, dt: number) -> (number, number),
}, ElectricMotor))

function ElectricMotor.new(vehicle: Vehicle, config: {}): ()
	return setmetatable(BaseComponent.new(vehicle, {
		_motor_inertia = config.motor_inertia,
		_rpm = 0,
		_max_rpm = config.max_rpm,
		_torque = 0,
		_min_torque = config.min_torque,
		_max_torque = config.max_torque,
		_torque_curve_coefficient = config.torque_curve_coefficient,
		_kilowatts = 0,
	}), ElectricMotor)
end

-- Returns torque in Newton-meter (Nm)
function ElectricMotor.get_torque(self: ElectricMotor): number
	return self._torque
end

function ElectricMotor.get_rpm(self: ElectricMotor): number
	return self._rpm
end

function ElectricMotor.update(self: ElectricMotor, throttle: number, dt: number): (number, number)
	if self._health <= 0 then
		if self._rpm > 0 then
			self._rpm = 0
		end
		if self._torque > 0 then
			self._torque = 0
		end
		return self._rpm, self._torque
	end
	
	-- Some random formula ChatGPT gave me for semi-realistic RPM delta. 9.55 is the result of 60/(2pi)
	self._rpm = math.clamp(
		(self._rpm + ((self._torque * math.abs(throttle)) / self._motor_inertia) * dt * 9.55),
		self._min_rpm,
		self._max_rpm
	)
	self._torque = math.min(
		self._torque_curve_coefficient * (self._rpm - self._max_rpm)^2 + self._min_torque,
		self._max_torque
	)
	self._kilowatts = (self._rpm * self._torque) / 9549
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

function Turbocharger.update(self: Turbocharger, dt: number): ()
	
end

-----------------------------GEARBOX CLASS----------------------------

local Gearbox = setmetatable({}, BaseComponent)
Gearbox.__index = Gearbox

type Gearbox = BaseComponent & typeof(setmetatable({} :: {
	_gear: number,
	_gear_ratios: {number},
	_final_drive_ratio: number,
	_max_gear_rpms: {number},
	_shift_time: number,
	gear_changed_event: Signal,

	new: (vehicle: Vehicle, config: {}) -> Gearbox,
	shift: (self: Gearbox, direction: Enums.GearShiftDirection) -> (),
	get_gear: (self: Gearbox) -> number,
	update: (self: Gearbox, engine_rpm: number, engine_torque: number) -> (number, number),
}, Gearbox))

function Gearbox.new(vehicle: Vehicle, config: {}): Gearbox
	return setmetatable(BaseComponent.new(vehicle, {
		_gear = 1,
		_gear_ratios = config.gear_ratios,
		_final_drive_ratio = config.final_drive_ratio,
		_max_gear_rpms = config.max_gear_rpms,
		_shift_time = config.shift_time,
		gear_changed_event = Signal.new()
	}), Gearbox)
end

function Gearbox.shift(self: Gearbox, direction: Enums.GearShiftDirection): ()
	if self._health <= 0 then
		return
	end
	if self._gear == 0 or self._gear == #self._gear_ratios then
		return
	end
	
	local shift_delay = self._shift_time * (1 + (1 - (self:get_health() / 100)))
	task.delay(shift_delay, function()
		if direction ~= Enums.GearShiftDirection.Down then
			return
		end
		
		local engine_rpm = self._vehicle.engine:get_rpm()
		if engine_rpm > self._max_gear_rpms[self._gear - 1] then
			local difference = engine_rpm - self._max_gear_rpms
			self._health = math.min(0.002 * difference, 20)
		end
	end)
	
	self._gear += direction
	self.gear_changed_event:Fire(self._gear)
end

function Gearbox.get_gear(self: Gearbox): number
	return self._gear
end

function Gearbox.update(self: Gearbox, engine_rpm: number, engine_torque: number): (number, number)
	if self._gear == 0 then
		return 0, 0
	end
	
	local gearbox_rpm = engine_rpm / self._gear_ratios[self._gear]
	local gearbox_torque = engine_torque * self._gear_ratios[self._gear] -- Newton-meter (Nm)
	return gearbox_rpm, gearbox_torque
end

------------------------------AXLE CLASS------------------------------

local Axle = setmetatable({}, BaseComponent)
Axle.__index = Axle

type Axle = BaseComponent & typeof(setmetatable({} :: {
	_connected_wheels: {Wheel},

	new: (vehicle: Vehicle, connected_wheels: {Wheel}) -> Axle,
}, Axle))

local function break_joints(part: BasePart): ()
	for _, joint: WeldConstraint in pairs(part:GetJoints()) do
		if joint.Part1 ~= part then
			return
		end
		
		joint:Destroy()
	end
end

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
		
		for _, wheel: Wheel in pairs(self._connected_wheels) do
			break_joints(wheel.wheel)
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
	_steering_speed: number,

	new: (vehicle: Vehicle, config: {}) -> SteeringColumn,
	update: (self: SteeringColumn, steer_float: number, dt: number) -> number,
}, SteeringColumn))

function SteeringColumn.new(vehicle: Vehicle, config: {}): SteeringColumn
	return setmetatable(BaseComponent.new(vehicle, {
		_steering_angle = 0,
		_max_steering_angle = config.max_steering_angle,
		_steering_speed = config.steering_speed,
	}), SteeringColumn)
end

function SteeringColumn.update(self: SteeringColumn, steer_float: number, dt: number): number
	if self._health <= 0 then
		return self._steering_angle
	end

	local target_angle = steer_float * 0.5 -- TODO: REPLACE THIS WITH ACTUAL TARGETLIMIT --* self._max_steering_angle
	self._steering_angle = lerp(self._steering_angle, target_angle, self._steering_speed * dt)
	return self._steering_angle
end

-----------------------------WHEEL CLASS------------------------------

local Wheel = setmetatable({
	_AMBIENT_TEMPERATURE = workspace:GetAttribute("GlobalTemperature"),
}, BaseComponent)
Wheel.__index = Wheel

local temperature_change = ReplicatedStorage.RemoteEvents.temperature_change
temperature_change.OnClientEvent:Connect(function(temperature: number)
	Wheel._AMBIENT_TEMPERATURE = temperature
end)

type Wheel = BaseComponent & typeof(setmetatable({} :: {
	wheel: BasePart,
	is_front: boolean,
	_tire_compound: number,
	_tractions: {[Enum.Material]: number},
	_temperature: number,
	_overheating_temperature: number,
	_heating_rate: number,
	_cooling_rate: number,
	_stress: number,
	_base_wear_rate: number,

	new: (vehicle: Vehicle, chassis_part: BasePart, wheel_part: BasePart, config: {}) -> Wheel,
	change_wheel: (self: Wheel, compound: Enums.TireCompound) -> (),
	get_wheel_speed: (self: Wheel) -> number,
	get_wheel_radius: (self: Wheel) -> number,
	get_stress: (self: Wheel) -> number,
	update: (self: Wheel, dt: number) -> (),
}, Wheel))

function Wheel.new(vehicle: Vehicle, chassis_part: BasePart, wheel_part: BasePart, config: {}): Wheel	
	return setmetatable(BaseComponent.new(vehicle, {
		wheel = wheel_part,
		is_front = -chassis_part.CFrame:PointToObjectSpace(wheel_part.Position).Z > 0,
		tire_model = config.tire_model,
		tire_compound = config.default_tire_compound,
		_temperature = Wheel._AMBIENT_TEMPERATURE or 20,
		_overheating_temperature = config.overheating_temperature,
		_heating_rate = config.heating_rate,
		_cooling_rate = config.cooling_rate,
		_stress = 0,
		_base_wear_rate = config.base_wear_rate,
	}), Wheel)
end

function Wheel.change_wheel(self: Wheel, compound: Enums.TireCompound): ()
	self._tire_compound = compound
	self._traction = 0 -- TODO: replace with a dictionary lookup of default tractions?
	self._health = 100
	self._stress = 0
	self._temperature = Wheel._AMBIENT_TEMPERATURE or 20 -- We could probably get the temperature from whatever weather control system nate has, convert to C

	-- I guess I should update the tire model in here?
end

function Wheel.get_wheel_speed(self: Wheel): number
	
	--- Wheel speed calculation
	-- Get the wheel's angular velocity (in radians per second)
	-- Compare it to the axis of rotation (to avoid change in camber affecting the speed)
	-- Multiply by the radius
	-- Return the absolute value to avoid a negative speed
	return math.abs(self.wheel.AssemblyAngularVelocity:Dot(self.wheel.CFrame.RightVector) * self:get_wheel_radius())
end

function Wheel.get_wheel_radius(self: Wheel): number
	return self.wheel.Size.Y / 2
end

function Wheel.get_stress(self: Wheel): number
	return self._stress
end

--[[
local pacejka_tire_slip_magic_constants = {
	["dry"] = {
		b = 10,
		c = 1.9,
		d = 1,
		e = 0.97,
	},
	["wet"] = {
		b = 12,
		c = 2.3,
		d = 0.82,
		e = 1
	},
}

local function calculate_tire_slip(self: Wheel, surface_normal: Vector3): number
	local vehicle_mass_on_tire = self._vehicle.chassis.AssemblyMass
		* (self.is_front and self._vehicle.mass_distribution or 1 - self._vehicle.mass_distribution) / 2 -- Only supports two tires ont he front, need to edit this if other types are wanted
	local normal_force = (vehicle_mass_on_tire + self._vehicle.downforce)
		* workspace.Gravity
		* math.cos(math.acos(surface_normal:Dot(Vector3.yAxis)))
	
	
	local f_x = normal_force * d * math.sin(c * math.atan(b - e * (b - math.atan(b))))
end
]]

local function measure_tire_stress(self: Wheel): number
	-- Calculate slip ratio (longitudinal slip)
	local vehicle_speed = self._vehicle:get_real_speed()
	
	local wheel_speed = self.get_wheel_speed()
	local slip_ratio = (vehicle_speed.Z - wheel_speed) / math.max(vehicle_speed.Z, wheel_speed, 0.001) -- Add in 0.001 to avoid dividing by 0
	
	-- Calculate slip angle (lateral slip)
	local wheel_local_space = self._vehicle.chassis.CFrame:VectorToObjectSpace(self.wheel.CFrame.LookVector)
	local steering_angle = math.atan2(wheel_local_space.X, wheel_local_space.Z + 0.001)
	local slip_angle = math.atan2(vehicle_speed.X, vehicle_speed.Z + 0.001) - steering_angle
	local normalized_slip_angle = 1 - math.exp(-math.abs(math.deg(slip_angle)) / 10)
	
	-- Range of 0-100
	return (math.sqrt((slip_ratio)^2 + (normalized_slip_angle)^2) / math.sqrt(2)) * 100
end

function Wheel.update(self: Wheel, dt: number): ()
	if self._health <= 0 then
		return
	end
	
	local result = workspace:Raycast(self.wheel.Position + (self.wheel.Size.Y / 2), Vector3.new(0, 1, 0))
	if not result then
		return
	end
	
	self.wheel.CustomPhysicalProperties.Friction = self._tractions[result.Material] * 2
	self._stress = measure_tire_stress(self)
	
	local stress_heat = (self._stress ^ 1.5) * self._tractions[Enum.Material] * self._heating_rate
	local heat_cooling = (self._temperature - Wheel._AMBIENT_TEMPERATURE) * self._cooling_rate
	self._temperature += (stress_heat - heat_cooling) * dt
	
	local stress_wear = (self._stress ^ 1.2) * self._base_wear_rate
	local temperature_wear = self._temperature > self._overheating_temperature
		and (self._temperature - self._overheating_temperature) * self._base_wear_rate
		or 0
	self._health = math.clamp(self._health - (stress_wear + temperature_wear), 0, 100)
	
	self.health_changed:Fire(self._health)
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
	_drivetrain: Enums.Drivetrain,
	
	model: Model,
	chassis: BasePart,
	_vehicle_mass: number,
	mass_distribution: number,
	
	_downforce_object: VectorForce?,
	downforce: number?,
	_max_downforce: number?,
	_downforce_coefficient: number?,
	_downforce_percentage: number?,
	
	_slipstream_object: VectorForce?,
	_slipstream_max_force: number,
	_slipstream_decay_rate: number,
	_slipstream_decay_midpoint: number,
	
	_input_object: Input.Input,
	_camera_object: Camera.Camera,

	new: (prefab: Model, spawn_position: CFrame, config: {}) -> Vehicle,
	get_wheel_speed: (self: Vehicle) -> number,
	get_real_speed: (self: Vehicle) -> Vector3,
	is_flipped: (self: Vehicle) -> boolean,
	update: (self: Vehicle, values: {number}, dt: number) -> (),
	destroy: (self: Vehicle) -> (),
}, Vehicle))

-- https://www.desmos.com/calculator/2m9taf3xz9
-- Returns downforce as a negative value to be inputted into the +Y axis of a force object
local function calculate_downforce(self: Vehicle): number
	local vehicle_velocity = self:get_real_speed().Z
	if vehicle_velocity <= 1 then
		return 0
	end
	
	local downforce = self._downforce_coefficient * (vehicle_velocity)^2
	
	--- Convert newtons to rowtons
	-- 1 newton = 0.163 rowtons
	return math.min((downforce * 0.163) * self._downforce_percentage, self._max_downforce)
end

-- https://www.desmos.com/calculator/p7nt9q6bya
-- Returns slipstream as a negative value to be inputted into the +Z axis of a force object
local slipstream_raycast_params = RaycastParams.new()
slipstream_raycast_params.CollisionGroup = "Car"
local function calculate_slipstream(self: Vehicle): number
	local result = workspace:Raycast(self.chassis.Position + (self.chassis.Size.Z / 2), Vector3.new(0, 0, -250), slipstream_raycast_params)
	if not result then
		return 0
	end
	
	local euler_value = math.exp(-self._slipstream_decay_rate * (result.Distance - self._slipstream_decay_midpoint))
	return -(self._slipstream_max_force - (self._slipstream_max_force / (1 + euler_value))) * 0.163
end

function Vehicle.new(prefab: Model, spawn_position: CFrame, config: {}): Vehicle
	local self = setmetatable({
		model = prefab, -- create_vehicle_model(prefab), -- temporary using prefab until i find out how to efficiently run client rendering
		_drivetrain = config.drivetrain,
		chassis = nil,
		_vehicle_mass = config.vehicle_mass,
		mass_distribution = config.mass_distribution,

		downforce = 0,
		_max_downforce = config.max_downforce or nil,
		_downforce_coefficient = config.downforce_coefficient or nil,
		_downforce_percentage = config.downforce_percentage or nil,
		
		_input_object = Input.new(),
	}, Vehicle)
	
	self.chassis = self.model:WaitForChild("chassis"):FindFirstChild("chassis_part")
	self._downforce_object = self.model.constraints.forces:FindFirstChild("downforce") or nil
	self._slipstream_object = self.model.constraints.forces:FindFirstChild("slipstream") or nil
	
	self.wheels = {}
	for _, wheel_part in pairs(self.model.chassis.wheels) do
		self.wheels[wheel_part.Name] = Wheel.new(self, wheel_part, config.wheels)
	end
	
	self.engine = Engine.new(self, config.engine)
	self.electric_motor = config.electric_motor and ElectricMotor.new(self, config.electric_motor) or nil
	self.turbocharger = config.turbocharger and Turbocharger.new(self, config.turbocharger) or nil
	self.gearbox = Gearbox.new(self, config.gearbox)
	self.front_axle = Axle.new(self, {self.wheels["fl"], self.wheels["fr"]})
	self.rear_axle = Axle.new(self, {self.wheels["rl"], self.wheels["rr"]}) -- TODO: do something about this hardcoding
	self.steering_column = SteeringColumn.new(self, config.steering_column)
	
	self._camera_object = Camera.new(self.model.extras.cameras:GetChildren())
	
	self:bind_objects(self._input_object, self._camera_object)
	return self
end

function Vehicle.bind_objects(self: Vehicle, input_object: Input.Input, camera_object: Camera.Camera): ()
	local vehicle_seat = self.model:FindFirstDescendant("driver_seat")
	
	local hud
	local mobile_controls
	local stepped_connection
	local render_stepped_connection
	vehicle_seat:GetPropertyChangedSignal("Occupant"):Connect(function()
		-- TODO: CAR ENTRY ANIMATION
		
		if vehicle_seat.Occupant ~= Players.LocalPlayer then
			return -- I don't know if this is redundant, since client is rendering each car and creating events for them, don't want to control another person car, right?
		end
		
		local speed, rpm, tachometer_bar_progress
		if vehicle_seat.Occupant ~= nil then
			hud = HUD.new(Players.LocalPlayer, self.gearbox.gear_changed_event)
			
			--if UserInputService:GetLastInputType() == Enum.UserInputType.Touch then
			--	mobile_controls = ReplicatedStorage.user_interface.mobile_controls:Clone()
			--	mobile_controls.Parent = Players.LocalPlayer.PlayerGui
			--end
			
			stepped_connection = RunService.Stepped:Connect(function(_, dt: number)
				local throttle, steer = self._input_object:get_movement_vector()
				speed, rpm, tachometer_bar_progress = self:update({throttle, steer}, dt)
			end)
			
			render_stepped_connection = RunService.RenderStepped:Connect(function(dt: number)
				hud:update(speed, rpm, tachometer_bar_progress, dt)
			end)
			
			input_object:enable()
			camera_object:enable()
		else
			if hud then hud:destroy() end
			--if mobile_controls then mobile_controls:destroy() end
			
			if stepped_connection then stepped_connection:Disconnect() end
			if render_stepped_connection then render_stepped_connection:Disconnect() end
			input_object:disable()
			camera_object:disable()
		end
	end)
end

function Vehicle.get_wheel_speed(self: Vehicle): number
	local total_wheel_speed = 0
	local wheel_count = 0
	
	for _, wheel: Wheel in pairs(self.wheels) do
		local include = false	
		
		if self._drivetrain == Enums.Drivetrain.FWD then
			include = wheel.is_front
		elseif self._drivetrain == Enums.Drivetrain.RWD then
			include = not wheel.is_front
		elseif self._drivetrain == Enums.Drivetrain.AWD then
			include = true
		end
		
		if include then
			total_wheel_speed = wheel:get_wheel_speed()
			wheel_count += 1
		end
	end
	
	return total_wheel_speed / wheel_count + 0.001
end

--- Vehicle.get_real_speed()
-- Returns the speed of vehicle in studs per second
-- Z axis faces backward so return the negative (forward speed)
function Vehicle.get_real_speed(self: Vehicle): Vector3
	local vehicle_speed = self.chassis.CFrame:PointToObjectSpace(self.chassis.AssemblyLinearVelocity)
	
	return Vector3.new(vehicle_speed.X, vehicle_speed.Y, -vehicle_speed.Z)
end

function Vehicle.is_flipped(self: Vehicle): boolean
	return self.chassis.Position.Y > (self.chassis.Position + self.chassis.CFrame.UpVector).Y -- Check if this is correct
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
	local gearbox_rpm, gearbox_torque, tachometer_bar_progress = self.gearbox:update(engine_rpm, engine_torque)
	local steer = self.steering_column:update(input.steer, dt)
	
	for _, wheel: Wheel in pairs(self.wheels) do
		wheel:update()
	end
	
	if self._downforce_object then
		self._downforce_object.Force.Y = calculate_downforce(self)
	end
	if self._slipstream_object then
		self._slipstream_object.Force.Z = calculate_slipstream(self)
	end
	
	return self:get_wheel_speed(), gearbox_rpm, tachometer_bar_progress 
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
			for _, wheel: Wheel in pairs(self.wheels) do
				clear_object(wheel)
			end
		end
		
		self[k] = nil
	end
end

return Vehicle
