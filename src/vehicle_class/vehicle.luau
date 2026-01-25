--!native

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
local Signal = require(script.utils.signal)

--local HUD = require(script.internal_objects.hud)
local Input = require(script.internal_objects.input)
--local Camera = require(script.internal_objects.camera)
local Curve = require(script.internal_objects.curve)

--local create_vehicle_model = require(script.utils.create_vehicle_model)

---------------------------INTERNAL CLASSES---------------------------

-- A bunch of small component classes that helps with the physics simulation of the vehicle

-------------------------BASE COMPONENT CLASS-------------------------

local N_TO_ROWTONS = 0.163
local NM_TO_ROWTON_STUDS = 0.581

local BaseComponent = {}
BaseComponent.__index = BaseComponent

type BaseComponent = typeof(setmetatable({} :: {
	_health: number,
	_health_changed: typeof(Signal),
	health_changed: {["Connect"]: (_: any, () -> ()) -> Signal.Connection},
	
	new: (vehicle: Vehicle, component_properties: {}) -> BaseComponent,
	get_health: (self: BaseComponent) -> number,
	set_health: (self: BaseComponent, health: number) -> (),
	destroy: (self: BaseComponent) -> (),
}, BaseComponent))

function BaseComponent.new(component_properties: {}): BaseComponent
	local self = setmetatable({
		_health = 100,
		_health_changed = Signal.new(),
	}, BaseComponent)
	
	self.health_changed = {
		Connect = function(fn)
			self._health_changed:Connect(fn)
		end,
	}
	
	for k, v in pairs(component_properties) do
		self[k] = v
	end
	
	return self
end

function BaseComponent.get_health(self: BaseComponent): number
	return self._health
end

function BaseComponent.set_health(self: BaseComponent, health: number): ()
	self._health = math.clamp(health, 0, 100)
	self._health_changed:Fire(self._health)
end

function BaseComponent.destroy(self: BaseComponent): ()
	for k, v in pairs(self) do
		if typeof(v) == "table" and getmetatable(v) == Signal then
			v:DisconnectAll()
		end
		
		self[k] = nil
	end
end

setmetatable(BaseComponent, {
	__index = function(tbl, key)
		error(`Attempt to get {tbl}.{key} (not a valid member)`, 2)
	end,
	__newindex = function(tbl, key, value)
		error(`Attempt to set {tbl}.{key} (not a valid operation)`, 2)
	end,
})

-----------------------------ENGINE CLASS-----------------------------

local Engine = setmetatable({}, BaseComponent)
Engine.__index = Engine

type Engine = BaseComponent & typeof(setmetatable({} :: {
	_engine_inertia: number,
	_idle_throttle: number,
	_rpm: number,
	_min_rpm: number,
	_max_rpm: number,
	_torque: number,
	_torque_curve: typeof(Curve),
	_horsepower: number,

	new: (config: {}) -> Engine,
	get_torque: (self: Engine) -> number,
	get_rpm: (self: Engine) -> number,
	get_horsepower: (self: Engine) -> number,
	update: (self: Engine, throttle: number, engine_boost: number?, dt: number) -> (number, number),
}, Engine))

local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

function Engine.new(config: {}): Engine
	local self = setmetatable(BaseComponent.new({
		_engine_inertia = config.engine_inertia,
		_idle_throttle = config.idle_throttle,
		_rpm = 0,
		_min_rpm = config.min_rpm, -- Idle RPM
		_max_rpm = config.max_rpm, -- Redline
		_torque = 0,
		_torque_curve = Curve.new(config.torque_curve.points, config.torque_curve.type),
		_horsepower = 0,
	}), Engine)
	
	self.health_changed:Connect(function(health: number)
		if health > 0 then
			return
		end
		
		self._rpm = 0
		self._torque = 0
		self._horsepower = 0
	end)
	
	return self
end

-- Returns torque in Newton-meter (Nm)
function Engine.get_torque(self: Engine): number
	return self._torque
end

function Engine.get_rpm(self: Engine): number
	return self._rpm
end

function Engine.get_horsepower(self: Engine): number
	return self._horsepower
end

function Engine.update(self: Engine, throttle: number, turbocharger_boost: number?, dt: number): (number, number)
	if self._health <= 0 then
		return 0, 0
	end
	
	if self._rpm >= self._max_rpm then
		throttle = throttle > self._idle_throttle and self._idle_throttle or throttle
	end
	if throttle == 0 then
		throttle = self._idle_throttle
	end
	
	-- The magic number is the result of 60/2pi; the conversion from rads/s to rpm
	self._rpm = math.abs(math.clamp(
		self._rpm + (((self._torque * throttle) / self._engine_inertia) * dt * 9.55),
		self._min_rpm,
		self._max_rpm
	))
	self._torque = self._torque_curve:sample(self._rpm / self._max_rpm)
		* (self._health / 100)
		--* turbocharger_boost -- TODO: TURBOCHARGER BOOST!!!!
	self._horsepower = (self._rpm * self._torque) / 7217
	
	return self._rpm, self._torque
end

setmetatable(Engine, {
	__index = function(tbl, key)
		error(`Attempt to get {tbl}.{key} (not a valid member)`, 2)
	end,
	__newindex = function(tbl, key, value)
		error(`Attempt to set {tbl}.{key} (not a valid operation)`, 2)
	end,
})

-------------------------ELECTRIC MOTOR CLASS-------------------------

local ElectricMotor = setmetatable({}, BaseComponent)
ElectricMotor.__index = ElectricMotor

type ElectricMotor = BaseComponent & typeof(setmetatable({} :: {
	_motor_inertia: number,
	_idle_throttle: number,
	_rpm: number,
	_min_rpm: number,
	_max_rpm: number,
	_torque: number,
	_torque_curve: typeof(Curve),
	_kilowatts: number,
	
	new: (config: {}) -> ElectricMotor,
	get_torque: (self: ElectricMotor) -> number,
	get_rpm: (self: ElectricMotor) -> number,
	get_kilowatts: (self: ElectricMotor) -> number,
	update: (self: ElectricMotor, throttle: number, dt: number) -> (number, number),
}, ElectricMotor))

function ElectricMotor.new(config: {}): ()
	local self = setmetatable(BaseComponent.new({
		_motor_inertia = config.motor_inertia,
		_idle_throttle = config.idle_throttle,
		_rpm = 0,
		_min_rpm = config.min_rpm,
		_max_rpm = config.max_rpm,
		_torque = 0,
		_torque_curve = Curve.new(config.torque_curve.points, config.torque_curve.type),
		_kilowatts = 0,
	}), ElectricMotor)
	
	self.health_changed:Connect(function(health: number)
		if health > 0 then
			return
		end
		
		self._rpm = 0
		self._torque = 0
		self._kilowatts = 0
	end)
	
	return self
end

-- Returns torque in Newton-meter (Nm)
function ElectricMotor.get_torque(self: ElectricMotor): number
	return self._torque
end

function ElectricMotor.get_rpm(self: ElectricMotor): number
	return self._rpm
end

function ElectricMotor.get_kilowatts(self: ElectricMotor): number
	return self._kilowatts
end

function ElectricMotor.update(self: ElectricMotor, throttle: number, dt: number): (number, number)
	if self._health <= 0 then
		return 0, 0
	end
	
	if throttle == 0 then
		throttle = self._idle_throttle
	end
	
	-- The magic number is the result of 60/2pi; the conversion from rads/s to rpm
	self._rpm = math.abs(math.clamp(
		self._rpm + (((self._torque * throttle) / self._engine_inertia) * dt * 9.55),
		self._min_rpm,
		self._max_rpm
	))
	self._torque = math.min(
		self._torque_curve:sample(self._rpm / self._max_rpm),
		self._max_torque
	) * (self._health / 100)
	self._kilowatts = (self._rpm * self._torque) / 9549
	
	return self._rpm, self._torque
end

setmetatable(ElectricMotor, {
	__index = function(tbl, key)
		error(`Attempt to get {tbl}.{key} (not a valid member)`, 2)
	end,
	__newindex = function(tbl, key, value)
		error(`Attempt to set {tbl}.{key} (not a valid operation)`, 2)
	end,
})

--------------------------TURBOCHARGER CLASS--------------------------

local Turbocharger = setmetatable({}, BaseComponent)
Turbocharger.__index = Turbocharger

type Turbocharger = BaseComponent & typeof(setmetatable({} :: {
	_turbine_inertia: number,
	_rpm: number,
	_max_rpm: number,
	_boost_curve: typeof(Curve),
	_boost: number,

	new: (config: {}) -> Turbocharger,
	get_rpm: (self: Turbocharger) -> number,
	get_boost: (self: Turbocharger) -> number,
	update: (self: Turbocharger, engine_rpm: number, throttle: number, dt: number) -> number,
}, Turbocharger))

function Turbocharger.new(config: {}): Turbocharger
	local self = setmetatable(BaseComponent.new({
		_turbine_inertia = config.turbine_inertia,
		_rpm = 0,
		_max_rpm = config.max_rpm,
		_boost_curve = Curve.new(config.boost_curve.points, config.boost_curve.type),
		_boost = 0,
	}), Turbocharger)
	
	self.health_changed:Connect(function(health: number)
		if health > 0 then
			return
		end
		
		self._rpm = 0
		self._boost = 0
	end)
	
	return self
end

function Turbocharger.get_rpm(self: Turbocharger): number
	return self._rpm
end

function Turbocharger.get_boost(self: Turbocharger): number
	return self._boost
end

function Turbocharger.update(self: Turbocharger, engine_rpm: number, exhaust_energy: number, throttle: number, dt: number): number
	if self._health <= 0 then
		return self._boost
	end
	
	-- The magic number is the result of 60/2pi; the conversion from rads/s to rpm
	self._rpm = math.abs(math.clamp(
		self._rpm + ((throttle) / self._turbine_inertia) * dt * 9.55,
		0,
		self._max_rpm
		))
	self._boost = self._boost_curve:sample(self._rpm / self._max_rpm) * (self._health / 100)
	
	return self._boost
end

setmetatable(Turbocharger, {
	__index = function(tbl, key)
		error(`Attempt to get {tbl}.{key} (not a valid member)`, 2)
	end,
	__newindex = function(tbl, key, value)
		error(`Attempt to set {tbl}.{key} (not a valid operation)`, 2)
	end,
})

-----------------------------GEARBOX CLASS----------------------------

local Gearbox = setmetatable({}, BaseComponent)
Gearbox.__index = Gearbox

type Gearbox = BaseComponent & typeof(setmetatable({} :: {
	_gear: number,
	_gear_ratios: {[number]: number},
	_final_drive_ratio: number,
	_shift_time: number,
	gear_changed_event: typeof(Signal),

	new: (config: {}) -> Gearbox,
	shift: (self: Gearbox, direction: number) -> (),
	get_gear: (self: Gearbox) -> number,
	update: (self: Gearbox, engine_rpm: number, engine_torque: number) -> (number, number),
}, Gearbox))

function Gearbox.new(config: {}): Gearbox
	return setmetatable(BaseComponent.new({
		_gear = 1,
		_gear_ratios = config.gear_ratios,
		_final_drive_ratio = config.final_drive_ratio,
		_shift_time = config.shift_time,
		gear_changed_event = Signal.new()
	}), Gearbox)
end

function Gearbox.shift(self: Gearbox, direction: number): ()
	if self._health <= 0 then
		return
	end
	if self._gear <= self._gear_ratios[1] or self._gear >= #self._gear_ratios then
		return
	end
	
	local shift_delay = self._shift_time * (1 + (1 - (self:get_health() / 100)))	
	task.delay(shift_delay, function()
		self._gear += math.sign(direction)
		self.gear_changed_event:Fire(self._gear)
	end)
end

function Gearbox.get_gear(self: Gearbox): number
	return self._gear
end

function Gearbox.update(self: Gearbox, engine_rpm: number, engine_torque: number): (number, number)
	if self._gear == 0 then
		return 0, 0
	end
	
	local total_ratio = self._gear_ratios[self._gear] * self._final_drive_ratio
	local gearbox_rpm = engine_rpm / total_ratio
	local gearbox_torque = engine_torque * total_ratio
	return gearbox_rpm, gearbox_torque
end

setmetatable(Gearbox, {
	__index = function(tbl, key)
		error(`Attempt to get {tbl}.{key} (not a valid member)`, 2)
	end,
	__newindex = function(tbl, key, value)
		error(`Attempt to set {tbl}.{key} (not a valid operation)`, 2)
	end,
})

------------------------------AXLE CLASS------------------------------

local Axle = setmetatable({}, BaseComponent)
Axle.__index = Axle

type Axle = BaseComponent & typeof(setmetatable({} :: {
	_connected_wheels: {Wheel},

	new: (vehicle: Vehicle, connected_wheels: {Wheel}) -> Axle,
}, Axle))

function Axle.new(connected_wheels: {Wheel}): Axle	
	return setmetatable(BaseComponent.new({
		_connected_wheels = connected_wheels,
	}), Axle)
end

setmetatable(Axle, {
	__index = function(tbl, key)
		error(`Attempt to get {tbl}.{key} (not a valid member)`, 2)
	end,
	__newindex = function(tbl, key, value)
		error(`Attempt to set {tbl}.{key} (not a valid operation)`, 2)
	end,
})

------------------------STEERING COLUMN CLASS-------------------------

local SteeringColumn = setmetatable({}, BaseComponent)
SteeringColumn.__index = SteeringColumn

type SteeringColumn = BaseComponent & typeof(setmetatable({} :: {
	_steering_angle: number,
	_max_steering_angle: number,
	_steering_speed: number,
	_steering_bias: number,

	new: (config: {}) -> SteeringColumn,
	update: (self: SteeringColumn, steer_float: number, dt: number) -> number,
}, SteeringColumn))

function SteeringColumn.new(config: {}): SteeringColumn
	return setmetatable(BaseComponent.new({
		_steering_angle = 0,
		_max_steering_angle = config.max_steering_angle,
		_steering_speed = config.steering_speed,
		_steering_bias = config.steering_bias,
	}), SteeringColumn)
end

function SteeringColumn.update(self: SteeringColumn, steer_float: number, dt: number): number
	if self._health <= 0 then
		return self._steering_angle
	end

	local target_angle = steer_float * self._max_steering_angle
	self._steering_angle = lerp(self._steering_angle, target_angle, self._steering_speed * dt) --TODO: gotta add in some different steering geometry calculations (ackermann, anti-ackermann)
	return self._steering_angle
end

setmetatable(SteeringColumn, {
	__index = function(tbl, key)
		error(`Attempt to get {tbl}.{key} (not a valid member)`, 2)
	end,
	__newindex = function(tbl, key, value)
		error(`Attempt to set {tbl}.{key} (not a valid operation)`, 2)
	end,
})

-----------------------------WHEEL CLASS------------------------------

local Wheel = setmetatable({}, BaseComponent)
Wheel.__index = Wheel

type Wheel = BaseComponent & typeof(setmetatable({} :: {
	_wheel_root: CFrame,
	_vehicle_root: BasePart,
	is_front: boolean,
	_position_relative_to_chassis: CFrame,
	_wheel_radius: number,
	_wheel_inertia: number,
	_angular_velocity: number,
	
	_long_slip_curve: typeof(Curve),
	_lat_slip_curve: typeof(Curve),
	
	_suspension_raycast_params: RaycastParams,
	_suspension_length: number,
	_suspension_stiffness: number,
	_suspension_damping: number,
	
	_stress: number,
	stress_changed: typeof(Signal),

	new: (chassis_part: BasePart, chassis_part: BasePart, root: CFrame, config: {}) -> Wheel,
	change_wheel: (self: Wheel, compound: Enums.TireCompound) -> (),
	get_wheel_speed: (self: Wheel) -> Vector3,
	get_wheel_radius: (self: Wheel) -> number,
	get_stress: (self: Wheel) -> number,
	update: (self: Wheel, torque: number, steering_angle: number, dt: number) -> (Vector3, Vector3),
}, Wheel))

function Wheel.new(vehicle --[[Vehicle]], chassis_part: BasePart, root: CFrame, config: {}): Wheel	
	local self = setmetatable(BaseComponent.new({
		_wheel_root = root,
		_vehicle_root = chassis_part,
		is_front = chassis_part.CFrame:PointToObjectSpace(root.Position).Z > 0,
		_position_relative_to_chassis = chassis_part.CFrame:ToObjectSpace(root),
		_wheel_radius = config.wheel_radius,
		_wheel_inertia = config.wheel_inertia,
		_angular_velocity = 0,
		
		-- pacejka curves
		_long_slip_curve = Curve.new(config.long_slip_curve.points, config.long_slip_curve.type),
		_lat_slip_curve = Curve.new(config.lat_slip_curve.points, config.lat_slip_curve.type),
		
		_suspension_raycast_params = RaycastParams.new(),
		_suspension_length = config.suspension_length,
		_suspension_stiffness = config.suspension_stiffness,
		_suspension_damping = config.suspension_damping,

		_stress = 0,
		stress_changed = Signal.new(),
	}), Wheel)
	
	self._suspension_raycast_params.FilterType = Enum.RaycastFilterType.Exclude
	self._suspension_raycast_params.FilterDescendantsInstances = {chassis_part:FindFirstAncestorOfClass("Model")}
	
	return self
end

-- Returns the linear velocity of the wheel
function Wheel.get_wheel_speed(self: Wheel): number
	return self._angular_velocity * self._wheel_radius
end

function Wheel.get_stress(self: Wheel): number
	return self._stress
end

local function calculate_spring_force(self: Wheel, ray: RaycastResult?): Vector3	
	if ray == nil then
		return Vector3.zero
	end
	
	local spring_displacement = ray ~= nil and (ray.Distance - self._wheel_radius) or (self._suspension_length + self._wheel_radius)
	
	local spring_force = self._suspension_stiffness * spring_displacement
	local damping_force = self._suspension_damping * self._vehicle_root:GetVelocityAtPosition(ray.Position)
	local net_force = spring_force + damping_force
	
	-- Return the vector force
	return ray.Normal * net_force
end

local function calculate_slip_values(self: Wheel, ray: RaycastResult?, long_velocity: number, lat_velocity: number): (number, number)
	if ray == nil then
		return 0, 0
	end
	
	local slip_ratio = ((self._angular_velocity * self._wheel_radius) - long_velocity) / math.max(math.abs(long_velocity), 1e-3)
	local slip_angle = math.atan2(math.abs(lat_velocity), math.abs(long_velocity))
	
	--- Friction circle
	--[[Usually, the friction circle uses forces, however, I am using the raw slip values as a
	way to normalize them for input into the pacejka curves]]--
	local resultant_vector = math.sqrt(slip_ratio*slip_ratio + slip_angle*slip_angle)
	if resultant_vector > 1 then
		slip_ratio = slip_ratio / resultant_vector
		slip_angle = slip_angle / resultant_vector
	end
	
	local long_slip_value = self._long_slip_curve:sample(slip_ratio) * math.sign(slip_ratio)
	local lat_slip_value = self._lat_slip_curve:sample(slip_angle) * math.sign(slip_angle)
	return long_slip_value, lat_slip_value
end

local function get_rolling_resistance_coefficient(material: Enum.Material): number
	if material == nil then
		return 0
	end
	
	if material == Enum.Material.Grass then
		return 0.1
	elseif material == Enum.Material.Sand then
		return 0.3
	else
		return 0.012 -- coefficient for asphalt
	end
end

-- @torque, torque from the GEARBOX
-- @steering_angle, in degrees
-- @returns <Vector3, Vector3>, position to apply force, the net force vector
function Wheel.update(self: Wheel, drivetrain_torque: number, steering_angle: number, dt: number): (Vector3?, Vector3)
	if self._health <= 0 then
		return nil, Vector3.zero
	end
	
	local ray = workspace:Raycast(
		self._vehicle_root.CFrame:ToWorldSpace(self._position_relative_to_chassis).Position,
		-self._vehicle_root.CFrame.UpVector * (self._suspension_length + self._wheel_radius), 
		self._suspension_raycast_params
	)
	
	local ground_velocity = (ray ~= nil and ray.Instance ~= nil) and ray.Instance:GetVeloctyAtPosition(ray.Position) or Vector3.zero -- In case the vehicle is moving on a moving surface
	local contact_patch_velocity = ray ~= nil and self._vehicle_root:GetVelocityAtPosition(ray.Position) - ground_velocity or Vector3.zero
	local long_velocity = contact_patch_velocity:Dot(self._wheel_root.LookVector)
	local lat_velocity = contact_patch_velocity:Dot(self._wheel_root.RightVector)
	
	local suspension_force = calculate_spring_force(self, ray)
	local normal_force = suspension_force.Magnitude
	
	local long_slip, lat_slip = calculate_slip_values(self, ray)
	local long_force = self._wheel_root.LookVector * (long_slip * normal_force)
	local lat_force = self._wheel_root.RightVector * (lat_slip * normal_force)
	
	-- velocity mismatch torque, this should not be physically applied, only use to correct the angular velocity variable
	local velocity_corrective_torque = math.clamp(
		(self._angular_velocity - (long_velocity / self._wheel_radius)) * self._wheel_inertia * dt,
		-normal_force, 
		normal_force
	)
	local angular_acceleration = -velocity_corrective_torque / self._wheel_inertia
	self._angular_velocity += angular_acceleration * dt
	
	-- 0.012 is the rolling resistance coefficient of asphalt
	local wheel_torque_force = drivetrain_torque / self._wheel_radius
	local resistance_torque_force = -(get_rolling_resistance_coefficient(ray ~= nil and ray.Material or nil) * normal_force)
	angular_acceleration = ((wheel_torque_force + resistance_torque_force) * self._wheel_radius) / self._wheel_inertia
	self._angular_velocity += angular_acceleration * dt
	
	local wheel_rotation = 
		CFrame.lookAt(Vector3.zero, self._wheel_root.LookVector, self._wheel_root.UpVector) *
		CFrame.Angles(0, math.rad(steering_angle), 0)
	local net_wheel_torque_force = wheel_rotation.LookVector * wheel_torque_force
	
	if ray == nil then
		return nil, Vector3.zero
	end
	
	return ray.Position, suspension_force + long_force + lat_force + net_wheel_torque_force
end

setmetatable(Wheel, {
	__index = function(tbl, key)
		error(`Attempt to get {tbl}.{key} (not a valid member)`, 2)
	end,
	__newindex = function(tbl, key, value)
		error(`Attempt to set {tbl}.{key} (not a valid operation)`, 2)
	end,
})

------------------------------MAIN CLASS------------------------------

local Vehicle = {}
Vehicle.__index = Vehicle

export type Vehicle = typeof(setmetatable({} :: {
	--model: Model,
	_primary_part: BasePart,
	--_collision_enabled: boolean,
	
	_downforce_enabled: boolean,
	--downforce: number?,
	_downforce_percentage: number,
	_downforce_curve: typeof(Curve)?,

	_slipstream_enabled: boolean,
	_slipstream_raycast_params: RaycastParams,
	--slipstream: number?,
	_slipstream_curve: typeof(Curve)?,
	
	_engine: Engine,
	_electric_motor: ElectricMotor?,
	_turbocharger: Turbocharger?,
	_gearbox: Gearbox,
	_front_axle: Axle,
	_rear_axle: Axle,
	_steering_column: SteeringColumn,
	_wheels: {Wheel},
	drivetrain: Enums.Drivetrain,
	
	_input_object: Input.Input,
	
	_connections: {},
	
	throttle_changed: {["Connect"]: (_: any, () -> ()) -> Signal.Connection},
	steering_changed: {["Connect"]: (_: any, () -> ()) -> Signal.Connection},
	camera_change_triggered: {["Connect"]: (_: any, () -> ()) -> Signal.Connection},
	
	engine_health_changed: {["Connect"]: (_: any, () -> ()) -> Signal.Connection},
	electric_motor_health_changed: {["Connect"]: (_: any, () -> ()) -> Signal.Connection},
	turbocharger_health_changed: {["Connect"]: (_: any, () -> ()) -> Signal.Connection},
	gearbox_health_changed: {["Connect"]: (_: any, () -> ()) -> Signal.Connection},
	gearbox_gear_changed: {["Connect"]: (_: any, () -> ()) -> Signal.Connection},
	front_axle_health_changed: {["Connect"]: (_: any, () -> ()) -> Signal.Connection},
	rear_axle_health_changed: {["Connect"]: (_: any, () -> ()) -> Signal.Connection},
	steering_column_health_changed: {["Connect"]: (_: any, () -> ()) -> Signal.Connection},
	wheel_health_changed: {["Connect"]: (_: any, () -> ()) -> Signal.Connection},
	wheel_stress_changed: {["Connect"]: (_: any, () -> ()) -> Signal.Connection},

	new: (primary_part: BasePart, config: {}) -> Vehicle,
	get_wheel_speed: (self: Vehicle) -> number,
	get_real_speed: (self: Vehicle) -> Vector3,
	update: (self: Vehicle, dt: number) -> (number, number, number),
	destroy: (self: Vehicle) -> (),
}, Vehicle))

function Vehicle.new(primary_part: BasePart, wheel_roots: {Attachment}, config: {}): Vehicle
	local self = setmetatable({
		_primary_part = primary_part,
		drivetrain = config.drivetrain,
		
		_downforce_enabled = config.downforce_enabled,
		--downforce = 0 or nil,
		_downforce_percentage = config.downforce_percentage or 0.5,
		_downforce_curve = config.downforce_curve and Curve.new(
			config.downforce_curve.points,
			config.downforce_curve.type
		) or nil,
		_slipstream_enabled = config.slipstream_enabled,
		--slipstream = 0 or nil,
		_slipstream_raycast_params = RaycastParams.new(),
		_slipstream_curve = config.slipstream_curve and Curve.new(
			config.slipstream_curve.points,
			config.slipstream_curve.type
		) or nil,
		
		_engine = Engine.new(config.engine),
		_electric_motor = config.electric_motor and ElectricMotor.new(config.electric_motor) or nil,
		_turbocharger = config.turbocharger and Turbocharger.new(config.turbocharger) or nil,
		_gearbox = Gearbox.new(config.gearbox),
		_front_axle = Axle.new(),
		_rear_axle = Axle.new(),
		_steering_column = SteeringColumn.new(config.steering_column),
		_wheels = {},
		
		_input_object = Input.new(config.keybinds),
		
		_connections = {},
	}, Vehicle)
	
	for _, wheel: Attachment in pairs(wheel_roots) do
		table.insert(self._wheels, Wheel.new(self, self._primary_part, wheel.CFrame, config.wheel))
	end
	
	self._slipstream_raycast_params.CollisionGroup = "Car"
	self._slipstream_raycast_params.FilterType = Enum.RaycastFilterType.Exclude
	self._slipstream_raycast_params.FilterDescendantsInstances = {self._primary_part}
	
	-- Put _, as a filler for parameter one, since "self" is what will be passed in when using :Connect
	self.throttle_changed = {
		Connect = function(_, fn)
			return self._input_object.throttle_changed:Connect(fn)
		end,
	}
	self.steering_changed = {
		Connect = function(_, fn)
			return self._input_object.steering_changed:Connect(fn)
		end,
	}
	self.camera_change_triggered = {
		Connect = function(_, fn)
			return self._input_object.camera_change_triggered:Connect(fn)
		end,
	}

	self.engine_health_changed = {
		Connect = function(_, fn)
			return self._engine.health_changed:Connect(fn)
		end,
	}
	self.electric_motor_health_changed = self._electric_motor ~= nil and {
		Connect = function(_, fn)
			return self._electric_motor.health_changed:Connect(fn)
		end,
	} or nil
	self.turbocharger_health_changed = self._turbocharger ~= nil and {
		Connect = function(_, fn)
			return self._turbocharger.health_changed:Connect(fn)
		end,
	} or nil
	self.gearbox_health_changed = {
		Connect = function(_, fn)
			return self._gearbox.health_changed:Connect(fn)
		end,
	}
	self.gearbox_gear_changed = {
		Connect = function(_, fn)
			return self._gearbox.gear_changed_event:Connect(fn)
		end,
	}
	self.front_axle_health_changed = {
		Connect = function(_, fn)
			return self._front_axle.health_changed:Connect(fn)
		end,
	}
	self.rear_axle_health_changed = {
		Connect = function(_, fn)
			return self._rear_axle.health_changed:Connect(fn)
		end,
	}
	self.steering_column_health_changed = {
		Connect = function(_, fn)
			return self._steering_column.health_changed:Connect(fn)
		end,
	}
	self.wheel_health_changed = Signal.new()
	self.wheel_stress_changed = Signal.new()
	
	for _, wheel: Wheel in pairs(self._wheels) do
		wheel.health_changed:Connect(function(wheel: Wheel, health: number)
			self.wheel_health_changed:Fire(wheel, health)
		end)
		wheel.stress_changed:Connect(function(wheel: Wheel, stress: number)
			self.wheel_stress_changed:Fire(wheel, stress)
		end)
	end
	
	table.insert(self._connections, self._input_object.gear_shift_triggered:Connect(function(direction: number)
		self._gearbox:shift(direction)
	end))
	
	return self
end

function Vehicle.get_wheel_speed(self: Vehicle): number
	local total_wheel_speed = 0
	local wheel_count = 0
	
	for _, wheel: Wheel in pairs(self._wheels) do
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
	
	return total_wheel_speed / math.max(wheel_count, 1e-3)
end

--- Vehicle.get_real_speed()
-- Returns the speed of vehicle in studs per second
function Vehicle.get_real_speed(self: Vehicle): Vector3
	return self._primary_part.CFrame:VectorToObjectSpace(self._primary_part.AssemblyLinearVelocity)
end

-- https://www.desmos.com/calculator/p7nt9q6bya
local function calculate_downforce(self: Vehicle): Vector3
	local vehicle_speed = self:get_real_speed().Magnitude
	
	return self._downforce_curve:sample(math.clamp(vehicle_speed / 500, 0, 1)) * self._downforce_percentage * self._primary_part.CFrame.UpVector --TODO: STOP HARDCODING THE MAX VALUE
end

-- https://www.desmos.com/calculator/p7nt9q6bya
local function calculate_slipstream(self: Vehicle): Vector3
	local ray = workspace:Raycast(
		self._primary_part.Position,
		self._primary_part.CFrame.LookVector * self:get_real_speed().Magnitude,
		self._slipstream_raycast_params
	)
	if ray ~= nil then
		return self._slipstream_curve:sample(math.clamp(ray.Distance / 300, 0, 1)) * self._primary_part.CFrame.LookVector --TODO: STOP HARDCODING THE MAX VALUE
	end
	
	return Vector3.zero
end

local drivetrain_functions = {
	[Enums.Drivetrain.FWD] = function(wheel: Wheel, torque: number, steer: number)
		return wheel.is_front and torque or 0,
			   wheel.is_front and steer or 0
	end,
	[Enums.Drivetrain.RWD] = function(wheel: Wheel, torque: number, steer: number)
		return not wheel.is_front and torque or 0,
			   wheel.is_front and steer or 0
	end,
	[Enums.Drivetrain.AWD] = function(wheel: Wheel, torque: number, steer: number)
		return torque,
			   wheel.is_front and steer or 0
	end,
}

function Vehicle.update(self: Vehicle, dt: number): ()
	local throttle, steer = self._input_object:get_movement_values()
	
	local engine_rpm, engine_torque = self._engine:update(throttle, nil, dt)
	local gearbox_rpm, gearbox_torque = self._gearbox:update(engine_rpm, engine_torque)
	
	local steering_angle = self._steering_column:update(steer, dt)
	
	local wheel_forces = table.create(#self._wheels)
	for _, wheel: Wheel in pairs(self._wheels) do
		local specific_wheel_torque, specific_steering_angle = drivetrain_functions[self.drivetrain](wheel, gearbox_torque, steering_angle)
		
		local position, net_force = wheel:update(specific_wheel_torque, specific_steering_angle, dt)
		if position ~= nil then
			wheel_forces[position] = net_force
		end
	end
	
	local downforce, slipstream = Vector3.zero, Vector3.zero
	if self._downforce_enabled then
		downforce = calculate_downforce(self)
	end
	if self._slipstream_enabled then
		slipstream = calculate_slipstream(self)
	end
	
	return self:get_real_speed(), gearbox_rpm, wheel_forces, downforce, slipstream
end

function Vehicle.destroy(self: Vehicle): ()
	for _, connection in pairs(self._connections) do
		connection:Disconnect()
	end
	for _, wheel: Wheel in pairs(self._wheels) do
		if wheel.destroy() then
			wheel:destroy()
		end
	end
	
	for k, v in pairs(self) do
		self[k] = nil
	end
end

setmetatable(Vehicle, {
	__index = function(tbl, key)
		error(`Attempt to get {tbl}.{key} (not a valid member)`, 2)
	end,
	__newindex = function(tbl, key, value)
		error(`Attempt to set {tbl}.{key} (not a valid operation)`, 2)
	end,
})

return Vehicle
