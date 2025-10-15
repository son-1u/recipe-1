local ReplicatedStorage = game:GetService("ReplicatedStorage")

local enums = require(script.Parent.enums)

return {
	keybinds = {
		-- Keyboard
		kb_throttle = Enum.KeyCode.W,
		kb_brake = Enum.KeyCode.S,
		kb_steer_left = Enum.KeyCode.A,
		kb_steer_right = Enum.KeyCode.D,
		
		kb_throttle_alt = Enum.KeyCode.Up,
		kb_brake_alt = Enum.KeyCode.Down,
		kb_steer_left_alt = Enum.KeyCode.Left,
		kb_steer_right_alt = Enum.KeyCode.Right,
		kb_mouse_steer = Enum.KeyCode.MousePosition,
		
		kb_shift_up = Enum.KeyCode.E,
		kb_shift_down = Enum.KeyCode.Q,
		
		kb_camera_change = Enum.KeyCode.V,
		kb_camera_rearview = Enum.KeyCode.LeftShift,
		
		-- Controller
		gamepad_throttle = Enum.KeyCode.ButtonR2,
		gamepad_brake = Enum.KeyCode.ButtonL2,
		gamepad_steer = Enum.KeyCode.Thumbstick1,
		gamepad_button_steer_left = Enum.KeyCode.DPadLeft,
		gamepad_button_steer_right = Enum.KeyCode.DPadRight,
		
		gamepad_shift_up = Enum.KeyCode.ButtonY,
		gamepad_shift_down = Enum.KeyCode.ButtonX,
		
		gamepad_camera_change = Enum.KeyCode.ButtonL1,
		gamepad_camera_rearview = Enum.KeyCode.ButtonR1,
	
		-- Mouse
		mouse_toggle = Enum.KeyCode.P,
		mouse_throttle = Enum.UserInputType.MouseButton1,
		mouse_brake = Enum.UserInputType.MouseButton2,
		mouse_steer = Enum.UserInputType.MouseMovement,
	},
	vehicle = {
		drivetrain = enums.Drivetrain.RWD,
		vehicle_mass = 798, -- in kg
		mass_distribution = 0.45, -- front mass distribution
		max_downforce = 5040, -- in ROWTONS (1N = 0.168 ROWTONS)
		downforce_coefficient = -2.09475, -- https://www.desmos.com/calculator/2m9taf3xz9
		downforce_percentage = 1, -- percentage of total downforce
		
		engine = {
			engine_inertia = 0.05, -- in kg_m^2, average range between 0.1-0.3 for general road cars
			idle_throttle = 0.05, -- used to simulate fuel flow cut off, use a low number
			min_rpm = 4000,
			max_rpm = 13600,
			peak_torque_rpm = 7240,
			min_torque = 0, -- in Newton-meters
			max_torque = 625, -- in Newton-meters
			redline_torque = 200, -- in Newton-meters
			
		},
		electric_motor = {
			motor_inertia = 0.1, -- TODO: GET REAL VALUE
			max_rpm = 125000,
			min_torque = 75, -- in Newton-meters
			max_torque = 275, -- in Newton-meters
			torque_curve_coefficient = 0.0000001225,
		},
		turbocharger = {
			_turbine_inertia: number,
			_max_rpm = 125000,
			_spool_rate: number,
			_decay_rate: number,
			_peak_boost_rpm: number,
			_max_boost = 3.5, -- in BAR
		},
		gearbox = {
			gear_ratios = {
				
			},
			final_drive_ratio = 3.78,
			max_gear_rpms = {1, 2, 3, 4, 5, 6, 7, 8},
			shift_time = 0.05,
		},
		steering_column = {
			max_steering_angle = 90, -- in degrees, honestly this dont work yet
			_steering_speed = 1, -- TODO: get a real value
		},
		wheels = {
			tire_model = ReplicatedStorage, -- TODO: GET TIRE MODEL
			default_tire_compound = enums.TireCompound.Medium,
			overheating_temperature = 100, -- in Celcius
			heating_rate = 0,
			cooling_rate = 0,
			base_wear_rate = 0.01,
		},
	},
}
